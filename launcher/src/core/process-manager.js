'use strict';

const fs = require('fs');
const { spawn, spawnSync } = require('child_process');

const paths = require('./paths');

function readPidFile() {
  if (!fs.existsSync(paths.pidFile)) return null;
  try {
    return JSON.parse(fs.readFileSync(paths.pidFile, 'utf8'));
  } catch {
    return null;
  }
}

function isAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function readProcessIdentity(pid) {
  try {
    if (process.platform === 'linux') {
      const executable = fs.realpathSync(`/proc/${pid}/exe`);
      const commandLine = fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').split('\0').filter(Boolean);
      const stat = fs.readFileSync(`/proc/${pid}/stat`, 'utf8');
      const startTime = stat.slice(stat.lastIndexOf(')') + 2).split(' ')[19];
      return { executable, commandLine, startTime };
    }

    const result =
      process.platform === 'win32'
        ? spawnSync(
            'powershell.exe',
            [
              '-NoProfile',
              '-Command',
              `Get-CimInstance Win32_Process -Filter \"ProcessId = ${pid}\" | ` +
                'Select-Object ExecutablePath,CreationDate,CommandLine | ConvertTo-Json -Compress',
            ],
            { encoding: 'utf8' }
          )
        : spawnSync('ps', ['-p', String(pid), '-o', 'lstart=', '-o', 'command='], { encoding: 'utf8' });
    if (result.status !== 0 || !result.stdout.trim()) return null;
    return { command: result.stdout.trim() };
  } catch {
    return null;
  }
}

function isManagedProcess(info) {
  if (!info || !Number.isInteger(info.pid) || !info.identity || !isAlive(info.pid)) return false;
  const current = readProcessIdentity(info.pid);
  if (!current) return false;
  if (process.platform === 'linux') {
    return current.executable === info.identity.executable && current.startTime === info.identity.startTime;
  }
  return current.command === info.identity.command;
}

function isRunning() {
  const info = readPidFile();
  return isManagedProcess(info);
}

function getStatus() {
  const info = readPidFile();
  if (!info) return { running: false };
  if (!isManagedProcess(info)) return { running: false, stale: true };
  return { running: true, ...info };
}

/**
 * 校验刚 spawn 出来的子进程确实是 mihomo 本体，并返回可写入 pid 文件的身份信息。
 * 校验不通过时必须先杀掉子进程再抛错：否则（尤其是 detached 的后台模式）会留下
 * 一个既没有 pid 文件、stop/status 也管不到的孤儿进程。
 */
function verifyLaunchedProcess(pid) {
  let identity = null;
  let reason = null;
  try {
    identity = readProcessIdentity(pid);
    if (!identity) {
      reason = '无法确认刚启动的 mihomo 进程身份。';
    } else if (process.platform === 'linux' && identity.executable !== fs.realpathSync(paths.coreBinary)) {
      reason = `刚启动进程的可执行文件（${identity.executable}）与 ${paths.coreBinary} 不匹配。`;
    }
  } catch (err) {
    reason = `确认刚启动的 mihomo 进程身份失败：${err.message}`;
  }

  if (reason) {
    try {
      if (isAlive(pid)) process.kill(pid, 'SIGKILL');
    } catch {
      // 子进程可能已自行退出，忽略。
    }
    throw new Error(reason);
  }
  return identity;
}

/**
 * 启动 mihomo。后台模式脱离当前进程并将输出写入 .run/mihomo.log，
 * 同时写入 pid 文件供 stop/status 查询；前台模式继承标准 IO 并转发信号。
 */
function start({ homeDir = paths.root, configFile = paths.configFile, daemon = false } = {}) {
  if (isRunning()) {
    throw new Error('funclash is already running (see `funclash status`).');
  }
  if (!fs.existsSync(paths.coreBinary)) {
    throw new Error(`mihomo core not found at ${paths.coreBinary}. Run \`funclash install\` first.`);
  }

  fs.mkdirSync(paths.runDir, { recursive: true });
  // mihomo 的 SAFE_PATHS 要求 -f/external-ui 等路径位于 -d 下，因此这里使用根目录。
  const args = ['-d', homeDir, '-f', configFile];

  if (daemon) {
    const logFd = fs.openSync(paths.logFile, 'a');
    let child;
    let identity;
    try {
      child = spawn(paths.coreBinary, args, {
        detached: true,
        stdio: ['ignore', logFd, logFd],
      });
      child.unref();
      identity = verifyLaunchedProcess(child.pid);
    } finally {
      // 子进程已继承该 fd，父进程这边必须关掉，否则 CLI 每次启动都漏一个句柄。
      fs.closeSync(logFd);
    }

    fs.writeFileSync(
      paths.pidFile,
      JSON.stringify(
        { pid: child.pid, startedAt: new Date().toISOString(), configFile, daemon: true, identity },
        null,
        2
      )
    );
    return { pid: child.pid, daemon: true };
  }

  const child = spawn(paths.coreBinary, args, { stdio: 'inherit' });
  const identity = verifyLaunchedProcess(child.pid);
  fs.writeFileSync(
    paths.pidFile,
    JSON.stringify(
      { pid: child.pid, startedAt: new Date().toISOString(), configFile, daemon: false, identity },
      null,
      2
    )
  );

  const forward = (signal) => () => {
    if (isAlive(child.pid)) process.kill(child.pid, signal);
  };
  process.on('SIGINT', forward('SIGINT'));
  process.on('SIGTERM', forward('SIGTERM'));

  return new Promise((resolve) => {
    child.on('exit', (code) => {
      cleanupPidFile();
      resolve({ pid: child.pid, daemon: false, exitCode: code });
    });
  });
}

function cleanupPidFile() {
  fs.rmSync(paths.pidFile, { force: true });
}

async function stop({ timeoutMs = 5000 } = {}) {
  const info = readPidFile();
  if (!info) {
    return { wasRunning: false };
  }
  if (!isManagedProcess(info)) {
    cleanupPidFile();
    return { wasRunning: false, stale: true };
  }

  process.kill(info.pid, 'SIGTERM');
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (!isManagedProcess(info)) {
      cleanupPidFile();
      return { wasRunning: true, forced: false };
    }
    await new Promise((r) => setTimeout(r, 200));
  }

  if (isManagedProcess(info)) {
    process.kill(info.pid, 'SIGKILL');
  }
  cleanupPidFile();
  return { wasRunning: true, forced: true };
}

module.exports = {
  start,
  stop,
  isRunning,
  getStatus,
  readPidFile,
  cleanupPidFile,
  isManagedProcess,
  readProcessIdentity,
  verifyLaunchedProcess,
};

'use strict';

const fs = require('fs');
const { spawn } = require('child_process');

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

function isRunning() {
  const info = readPidFile();
  return Boolean(info && isAlive(info.pid));
}

function getStatus() {
  const info = readPidFile();
  if (!info) return { running: false };
  if (!isAlive(info.pid)) return { running: false, stale: true };
  return { running: true, ...info };
}

/**
 * 启动 mihomo。后台模式脱离当前进程并将输出写入 run/mihomo.log，
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
    const out = fs.openSync(paths.logFile, 'a');
    const err = fs.openSync(paths.logFile, 'a');
    const child = spawn(paths.coreBinary, args, {
      detached: true,
      stdio: ['ignore', out, err],
    });
    child.unref();

    fs.writeFileSync(
      paths.pidFile,
      JSON.stringify(
        { pid: child.pid, startedAt: new Date().toISOString(), configFile, daemon: true },
        null,
        2
      )
    );
    return { pid: child.pid, daemon: true };
  }

  const child = spawn(paths.coreBinary, args, { stdio: 'inherit' });
  fs.writeFileSync(
    paths.pidFile,
    JSON.stringify(
      { pid: child.pid, startedAt: new Date().toISOString(), configFile, daemon: false },
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
  if (!isAlive(info.pid)) {
    cleanupPidFile();
    return { wasRunning: false, stale: true };
  }

  process.kill(info.pid, 'SIGTERM');
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (!isAlive(info.pid)) {
      cleanupPidFile();
      return { wasRunning: true, forced: false };
    }
    await new Promise((r) => setTimeout(r, 200));
  }

  if (isAlive(info.pid)) {
    process.kill(info.pid, 'SIGKILL');
  }
  cleanupPidFile();
  return { wasRunning: true, forced: true };
}

module.exports = { start, stop, isRunning, getStatus, readPidFile, cleanupPidFile };

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
 * Start the mihomo core. In daemon mode it's detached and its stdout/stderr
 * are redirected to run/mihomo.log; a pidfile is written so stop/status can
 * find it later. In foreground mode it inherits this process's stdio and
 * SIGINT/SIGTERM are forwarded to it.
 */
function start({ homeDir = paths.root, configFile = paths.configFile, daemon = false } = {}) {
  if (isRunning()) {
    throw new Error('funclash is already running (see `funclash status`).');
  }
  if (!fs.existsSync(paths.coreBinary)) {
    throw new Error(`mihomo core not found at ${paths.coreBinary}. Run \`funclash install\` first.`);
  }

  fs.mkdirSync(paths.runDir, { recursive: true });
  // mihomo requires -f/external-ui/etc. to be subpaths of -d (its "SAFE_PATHS" check),
  // so the home dir must be the ~/.funclash root, not just the config subdirectory.
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

'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { spawn } = require('node:child_process');

// paths.js 在 require 时就固定了 ~/.funclash，所以必须先改 HOME 再 require。
const home = fs.mkdtempSync(path.join(os.tmpdir(), 'funclash-verify-test-'));
process.env.HOME = home;
process.env.USERPROFILE = home;
process.env.FUNCLASH_RUN_DIR = path.join(home, 'run');

const paths = require('../src/core/paths');
const processManager = require('../src/core/process-manager');

// 用一份真实 ELF（/bin/sleep）冒充 mihomo：shell 脚本的 /proc/<pid>/exe 指向解释器，
// 不能用来验证“可执行文件一致”这条规则。
const SLEEP = fs.existsSync('/usr/bin/sleep') ? '/usr/bin/sleep' : '/bin/sleep';
const linuxOnly = { skip: process.platform !== 'linux' };

test.before(() => {
  fs.mkdirSync(paths.binDir, { recursive: true });
  fs.copyFileSync(SLEEP, paths.coreBinary);
  fs.chmodSync(paths.coreBinary, 0o755);
});

test.after(() => fs.rmSync(home, { recursive: true, force: true }));

function spawnDetached(command) {
  const child = spawn(command, ['30'], { detached: true, stdio: 'ignore' });
  child.unref();
  return child;
}

function isAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

test('可执行文件匹配时返回身份信息并保留进程', linuxOnly, () => {
  const child = spawnDetached(paths.coreBinary);
  try {
    const identity = processManager.verifyLaunchedProcess(child.pid);
    assert.equal(identity.executable, fs.realpathSync(paths.coreBinary));
    assert.ok(identity.startTime);
    assert.equal(isAlive(child.pid), true);
  } finally {
    process.kill(child.pid, 'SIGKILL');
  }
});

test('可执行文件不匹配时抛错并杀掉刚启动的进程，不留孤儿', linuxOnly, async () => {
  const child = spawnDetached(SLEEP);
  let killed = false;
  try {
    assert.throws(() => processManager.verifyLaunchedProcess(child.pid), /不匹配/);

    // SIGKILL 后进程要先被父进程回收才会从 /proc 消失，给它一点时间。
    for (let i = 0; i < 50 && isAlive(child.pid); i += 1) {
      await new Promise((r) => setTimeout(r, 20));
    }
    killed = !isAlive(child.pid);
    assert.equal(killed, true, '身份校验失败的子进程必须被杀掉，否则会变成管不到的孤儿');
  } finally {
    if (!killed && isAlive(child.pid)) process.kill(child.pid, 'SIGKILL');
  }
});

test('核心二进制不存在时同样要杀掉子进程再抛错', linuxOnly, async () => {
  const stashed = `${paths.coreBinary}.stashed`;
  fs.renameSync(paths.coreBinary, stashed);
  const child = spawnDetached(SLEEP);
  try {
    assert.throws(() => processManager.verifyLaunchedProcess(child.pid), /身份/);
    for (let i = 0; i < 50 && isAlive(child.pid); i += 1) {
      await new Promise((r) => setTimeout(r, 20));
    }
    assert.equal(isAlive(child.pid), false);
  } finally {
    if (isAlive(child.pid)) process.kill(child.pid, 'SIGKILL');
    fs.renameSync(stashed, paths.coreBinary);
  }
});

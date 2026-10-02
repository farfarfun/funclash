'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const runDir = fs.mkdtempSync(path.join(os.tmpdir(), 'funclash-process-test-'));
process.env.FUNCLASH_RUN_DIR = runDir;

const paths = require('../src/core/paths');
const processManager = require('../src/core/process-manager');

test.after(() => fs.rmSync(runDir, { recursive: true, force: true }));

test('只将身份完全匹配的存活进程视为托管进程', { skip: process.platform !== 'linux' }, () => {
  const identity = processManager.readProcessIdentity(process.pid);
  assert.equal(processManager.isManagedProcess({ pid: process.pid, identity }), true);
  assert.equal(
    processManager.isManagedProcess({
      pid: process.pid,
      identity: { ...identity, startTime: `${identity.startTime}-stale` },
    }),
    false
  );
});

test('stop 清理指向其他进程的陈旧 PID 文件且不发送信号', async () => {
  const identity = processManager.readProcessIdentity(process.pid);
  fs.writeFileSync(
    paths.pidFile,
    JSON.stringify({ pid: process.pid, identity: { ...identity, startTime: 'stale' } })
  );

  const result = await processManager.stop({ timeoutMs: 1 });

  assert.deepEqual(result, { wasRunning: false, stale: true });
  assert.equal(fs.existsSync(paths.pidFile), false);
  assert.doesNotThrow(() => process.kill(process.pid, 0));
});

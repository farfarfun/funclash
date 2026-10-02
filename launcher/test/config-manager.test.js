'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

// paths.js 在 require 时就固定了 ~/.funclash，所以必须先改 HOME 再 require。
// node:test 每个测试文件跑在独立子进程里，这里改 HOME 不会影响其他测试文件。
const home = fs.mkdtempSync(path.join(os.tmpdir(), 'funclash-config-test-'));
process.env.HOME = home;
process.env.USERPROFILE = home;
delete process.env.FUNCLASH_SECRET;

const paths = require('../src/core/paths');
const configManager = require('../src/config/config-manager');

test.after(() => fs.rmSync(home, { recursive: true, force: true }));

test('ensureConfig 生成随机 secret 并把配置文件权限收紧到 0600', () => {
  const config = configManager.ensureConfig();

  assert.match(config.secret, /^[0-9a-f]{32}$/);
  assert.equal(config['external-controller'], '127.0.0.1:9090');
  if (process.platform !== 'win32') {
    assert.equal(fs.statSync(paths.configFile).mode & 0o777, 0o600);
  }
});

test('ensureConfig 复用已有 secret，不会每次启动都改掉控制器凭据', () => {
  const first = configManager.ensureConfig();
  const second = configManager.ensureConfig();
  assert.equal(second.secret, first.secret);
});

test('写入已存在的宽权限配置文件时会重新收紧权限', { skip: process.platform === 'win32' }, () => {
  configManager.ensureConfig();
  fs.chmodSync(paths.configFile, 0o644);

  configManager.writeConfig(configManager.readConfig());

  assert.equal(fs.statSync(paths.configFile).mode & 0o777, 0o600);
});

test('FUNCLASH_SECRET 优先于配置文件里的 secret', () => {
  const generated = configManager.ensureConfig().secret;
  process.env.FUNCLASH_SECRET = 'from-env';
  try {
    assert.equal(configManager.resolveSecret(generated), 'from-env');
    assert.equal(configManager.ensureConfig().secret, 'from-env');
  } finally {
    delete process.env.FUNCLASH_SECRET;
  }
  // 环境变量撤掉后不再生效，回到配置文件里的那份。
  assert.equal(configManager.resolveSecret('from-file'), 'from-file');
});

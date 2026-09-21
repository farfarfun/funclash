'use strict';

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const yaml = require('js-yaml');

const paths = require('../core/paths');
const logger = require('../utils/logger');

const TEMPLATE_PATH = path.join(__dirname, 'default-config.yaml');

// 订阅链接常常自带 token/secret 查询参数，日志只能打印脱敏后的主机+路径。
function redactUrl(url) {
  try {
    const u = new URL(url);
    return `${u.origin}${u.pathname}`;
  } catch {
    return '<invalid url>';
  }
}

function readConfig() {
  if (!fs.existsSync(paths.configFile)) {
    throw new Error(`No config found at ${paths.configFile}. Run \`funclash install\` first.`);
  }
  return yaml.load(fs.readFileSync(paths.configFile, 'utf8'));
}

function writeConfig(config) {
  fs.mkdirSync(paths.configDir, { recursive: true });
  fs.writeFileSync(paths.configFile, yaml.dump(config));
}

/**
 * 如果配置不存在，从内置模板创建 ~/.funclash/config/config.yaml。
 * 即使用户提供了配置，也确保控制器、控制台和 secret 字段存在。
 */
function ensureConfig({ force = false } = {}) {
  fs.mkdirSync(paths.configDir, { recursive: true });

  let config;
  if (!force && fs.existsSync(paths.configFile)) {
    config = yaml.load(fs.readFileSync(paths.configFile, 'utf8')) || {};
  } else {
    config = yaml.load(fs.readFileSync(TEMPLATE_PATH, 'utf8'));
    logger.info(`Wrote default config to ${paths.configFile}`);
  }

  config['external-controller'] = config['external-controller'] || '127.0.0.1:9090';
  config['external-ui'] = paths.dashboardDir;
  if (!config.secret) {
    config.secret = crypto.randomBytes(16).toString('hex');
  }

  writeConfig(config);
  return config;
}

/**
 * 从 URL 拉取订阅配置并设为当前配置，保留 funclash 管理的字段。
 */
async function pullConfig(url) {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Failed to fetch config from ${redactUrl(url)} (${res.status} ${res.statusText})`);
  }
  const text = await res.text();
  const incoming = yaml.load(text);

  const existing = fs.existsSync(paths.configFile)
    ? yaml.load(fs.readFileSync(paths.configFile, 'utf8')) || {}
    : {};

  const merged = {
    ...incoming,
    'external-controller': existing['external-controller'] || '127.0.0.1:9090',
    'external-ui': paths.dashboardDir,
    secret: existing.secret || crypto.randomBytes(16).toString('hex'),
  };

  writeConfig(merged);
  logger.info(`Pulled subscription config from ${redactUrl(url)} -> ${paths.configFile}`);
  return merged;
}

module.exports = { readConfig, writeConfig, ensureConfig, pullConfig };

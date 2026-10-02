'use strict';

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const yaml = require('js-yaml');

const paths = require('../core/paths');
const logger = require('../utils/logger');

const TEMPLATE_PATH = path.join(__dirname, 'default-config.yaml');

// mihomo 只能从它自己的 config.yaml 读取 external-controller 的 secret，这份凭据
// 无法做到完全不落盘。能做的是：允许用环境变量覆盖（优先级高于配置文件，见 SPEC §9.3），
// 并把配置文件权限收紧到仅本人可读写，避免同机其他账号直接读到控制器凭据。
const SECRET_ENV_VAR = 'FUNCLASH_SECRET';
const CONFIG_FILE_MODE = 0o600;

function secretFromEnv() {
  const value = process.env[SECRET_ENV_VAR];
  return value ? value : null;
}

// secret 取值优先级：环境变量 > 已有配置文件 > 随机生成。
function resolveSecret(existingSecret) {
  return secretFromEnv() || existingSecret || crypto.randomBytes(16).toString('hex');
}

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
  fs.mkdirSync(paths.configDir, { recursive: true, mode: 0o700 });
  fs.writeFileSync(paths.configFile, yaml.dump(config), { mode: CONFIG_FILE_MODE });
  // writeFileSync 的 mode 只在新建文件时生效，已存在的旧文件要显式收紧。
  if (process.platform !== 'win32') {
    fs.chmodSync(paths.configFile, CONFIG_FILE_MODE);
  }
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
  config.secret = resolveSecret(config.secret);

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
    secret: resolveSecret(existing.secret),
  };

  writeConfig(merged);
  logger.info(`Pulled subscription config from ${redactUrl(url)} -> ${paths.configFile}`);
  return merged;
}

module.exports = { readConfig, writeConfig, ensureConfig, pullConfig, resolveSecret, SECRET_ENV_VAR };

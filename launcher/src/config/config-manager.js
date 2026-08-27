'use strict';

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const yaml = require('js-yaml');

const paths = require('../core/paths');
const logger = require('../utils/logger');

const TEMPLATE_PATH = path.join(__dirname, 'default-config.yaml');

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
 * Seed ~/.funclash/config/config.yaml from the shipped template if it
 * doesn't exist yet. Always ensures external-controller/external-ui/secret
 * are set, even for a user-supplied config, so the dashboard keeps working.
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
 * Fetch a subscription config from a URL and install it as the active
 * config, preserving the funclash-managed fields (controller/ui/secret).
 */
async function pullConfig(url) {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Failed to fetch config from ${url} (${res.status} ${res.statusText})`);
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
  logger.info(`Pulled subscription config from ${url} -> ${paths.configFile}`);
  return merged;
}

module.exports = { readConfig, writeConfig, ensureConfig, pullConfig };

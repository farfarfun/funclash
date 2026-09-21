'use strict';

const configManager = require('../config/config-manager');
const logger = require('../utils/logger');

async function dashboard(opts = {}) {
  const config = configManager.readConfig();
  const controller = config['external-controller'];
  const secret = config.secret || '';
  const url = `http://${controller}/ui/${secret ? `?secret=${encodeURIComponent(secret)}` : ''}`;

  logger.info(`Dashboard: http://${controller}/ui/`);

  if (!opts.print) {
    const { default: open } = await import('open');
    await open(url);
  }
}

module.exports = dashboard;

'use strict';

const processManager = require('../core/process-manager');
const configManager = require('../config/config-manager');
const paths = require('../core/paths');
const logger = require('../utils/logger');

async function status() {
  const info = processManager.getStatus();
  if (!info.running) {
    logger.info(info.stale ? 'Not running (stale pidfile cleaned up on next start).' : 'Not running.');
    return;
  }

  logger.info(`Running (pid ${info.pid}, started ${info.startedAt}, daemon=${Boolean(info.daemon)})`);
  logger.info(`Config: ${paths.configFile}`);

  try {
    const config = configManager.readConfig();
    const controller = config['external-controller'];
    const secret = config.secret || '';
    const url = `http://${controller}/version`;
    const res = await fetch(url, { headers: secret ? { Authorization: `Bearer ${secret}` } : {} });
    if (res.ok) {
      const body = await res.json();
      logger.info(`Core API reachable at http://${controller} (version ${body.version || 'unknown'})`);
    } else {
      logger.warn(`Core API at http://${controller} responded ${res.status}`);
    }
  } catch (err) {
    logger.warn(`Could not reach core API: ${err.message}`);
  }
}

module.exports = status;

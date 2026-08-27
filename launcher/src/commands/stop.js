'use strict';

const processManager = require('../core/process-manager');
const logger = require('../utils/logger');

async function stop() {
  const result = await processManager.stop();
  if (!result.wasRunning) {
    logger.info(result.stale ? 'Cleaned up a stale pidfile; nothing was running.' : 'funclash is not running.');
    return;
  }
  logger.info(result.forced ? 'mihomo did not exit in time, force-killed.' : 'mihomo stopped.');
}

module.exports = stop;

'use strict';

const processManager = require('../core/process-manager');
const start = require('./start');
const logger = require('../utils/logger');

async function restart(opts = {}) {
  const wasRunning = processManager.isRunning();
  if (wasRunning) {
    await processManager.stop();
    logger.info('Stopped previous mihomo instance.');
  }
  await start(opts);
}

module.exports = restart;

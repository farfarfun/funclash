'use strict';

const fs = require('fs');

const processManager = require('../core/process-manager');
const paths = require('../core/paths');
const logger = require('../utils/logger');

async function uninstall(opts = {}) {
  if (processManager.isRunning()) {
    await processManager.stop();
    logger.info('Stopped running mihomo instance.');
  }

  if (opts.purge) {
    fs.rmSync(paths.root, { recursive: true, force: true });
    logger.info(`Removed ${paths.root}`);
  } else {
    logger.info('Stopped. Installed files left in place (use --purge to delete ~/.funclash).');
  }
}

module.exports = uninstall;

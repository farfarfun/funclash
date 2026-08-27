'use strict';

const path = require('path');

const processManager = require('../core/process-manager');
const paths = require('../core/paths');
const logger = require('../utils/logger');

async function start(opts = {}) {
  const configFile = opts.config ? path.resolve(opts.config) : paths.configFile;
  const result = await processManager.start({
    homeDir: paths.root,
    configFile,
    daemon: Boolean(opts.daemon),
  });

  if (result.daemon) {
    logger.info(`mihomo started in background (pid ${result.pid}). Logs: ${paths.logFile}`);
    logger.info('Run `funclash dashboard` to open the web UI, `funclash stop` to stop it.');
  } else if (result.exitCode !== undefined) {
    logger.info(`mihomo exited (code ${result.exitCode}).`);
  }
}

module.exports = start;

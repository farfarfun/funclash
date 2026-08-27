'use strict';

const download = require('../core/download');
const configManager = require('../config/config-manager');
const logger = require('../utils/logger');

const DEFAULT_WEB_REPO = 'farfarfun/funclash';

async function install(opts = {}) {
  await download.installMihomoCore({
    version: opts.coreVersion || 'latest',
    compatible: Boolean(opts.compatible),
    force: Boolean(opts.force),
  });

  try {
    await download.installWebDashboard({
      webDir: opts.webDir,
      repo: opts.webDir ? undefined : opts.webRepo || DEFAULT_WEB_REPO,
      force: Boolean(opts.force),
    });
  } catch (err) {
    logger.warn(`Web dashboard not installed: ${err.message}`);
    logger.warn('The proxy core will still work; you can install the dashboard later with:');
    logger.warn('  funclash install --web-dir app/build/web');
  }

  configManager.ensureConfig({ force: Boolean(opts.force) });
  logger.info('funclash install complete. Run `funclash start` to launch the core.');
}

module.exports = install;

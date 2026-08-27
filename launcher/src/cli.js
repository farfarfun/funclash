'use strict';

const fs = require('fs');

const { Command } = require('commander');

const pkg = require('../package.json');
const logger = require('./utils/logger');

const install = require('./commands/install');
const start = require('./commands/start');
const stop = require('./commands/stop');
const restart = require('./commands/restart');
const status = require('./commands/status');
const logs = require('./commands/logs');
const dashboard = require('./commands/dashboard');
const configCmd = require('./commands/config');
const uninstall = require('./commands/uninstall');
const paths = require('./core/paths');

function run(argv) {
  const program = new Command();

  program
    .name('funclash')
    .description('Command-line installer/launcher for the mihomo (Clash Meta) proxy core + web dashboard.')
    .version(pkg.version);

  program
    .command('install')
    .description('Download the mihomo core and web dashboard, write a default config.')
    .option('--force', 'reinstall even if already present')
    .option('--core-version <tag>', 'mihomo release tag to install', 'latest')
    .option('--compatible', 'use the -compatible mihomo build (older/virtualized CPUs)')
    .option('--web-dir <path>', 'install the dashboard from a local Flutter web build instead of downloading')
    .option('--web-repo <owner/name>', 'GitHub repo to download the funclash-web release from')
    .action(withErrorHandling(install));

  program
    .command('start')
    .description('Start the mihomo core.')
    .option('-d, --daemon', 'run in the background')
    .option('-c, --config <path>', 'explicit config file (defaults to ~/.funclash/config/config.yaml)')
    .action(withErrorHandling(start));

  program.command('stop').description('Stop the running mihomo core.').action(withErrorHandling(stop));

  program
    .command('restart')
    .description('Stop then start the mihomo core.')
    .option('-d, --daemon', 'run in the background')
    .option('-c, --config <path>', 'explicit config file')
    .action(withErrorHandling(restart));

  program.command('status').description('Show whether funclash is running.').action(withErrorHandling(status));

  program
    .command('logs')
    .description('Show mihomo core logs.')
    .option('-f, --follow', 'follow the log output')
    .option('-n, --lines <n>', 'number of lines to show', '100')
    .action(withErrorHandling(logs));

  program
    .command('dashboard')
    .description('Print (and open) the web dashboard URL.')
    .option('--print', 'only print the URL, do not open a browser')
    .action(withErrorHandling(dashboard));

  const config = program.command('config').description('Manage the mihomo config.');
  config.command('path').description('Print the active config file path.').action(withErrorHandling(configCmd.path));
  config
    .command('pull <url>')
    .description('Download a subscription config and install it as the active config.')
    .action(withErrorHandling(configCmd.pull));
  config.command('edit').description('Open the config file in $EDITOR.').action(withErrorHandling(configCmd.edit));

  program
    .command('uninstall')
    .description('Stop funclash and optionally remove ~/.funclash.')
    .option('--purge', 'also delete ~/.funclash entirely')
    .action(withErrorHandling(uninstall));

  program
    .command('version')
    .description('Show funclash and installed mihomo core versions.')
    .action(
      withErrorHandling(() => {
        logger.info(`funclash ${pkg.version}`);
        if (fs.existsSync(paths.coreVersionFile)) {
          const meta = JSON.parse(fs.readFileSync(paths.coreVersionFile, 'utf8'));
          logger.info(`mihomo ${meta.version} (${meta.os}/${meta.arch}, installed ${meta.downloadedAt})`);
        } else {
          logger.info('mihomo core not installed (run `funclash install`).');
        }
      })
    );

  program.parseAsync(argv);
}

function withErrorHandling(fn) {
  return async (...args) => {
    try {
      await fn(...args);
    } catch (err) {
      logger.error(err.message);
      process.exitCode = 1;
    }
  };
}

module.exports = { run };

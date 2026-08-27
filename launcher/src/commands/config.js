'use strict';

const { spawn } = require('child_process');

const paths = require('../core/paths');
const configManager = require('../config/config-manager');
const logger = require('../utils/logger');

function path() {
  logger.info(paths.configFile);
}

async function pull(url) {
  await configManager.pullConfig(url);
}

function edit() {
  const editor = process.env.EDITOR || (process.platform === 'win32' ? 'notepad' : 'vi');
  const child = spawn(editor, [paths.configFile], { stdio: 'inherit' });
  return new Promise((resolve, reject) => {
    child.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`${editor} exited with code ${code}`))));
  });
}

module.exports = { path, pull, edit };

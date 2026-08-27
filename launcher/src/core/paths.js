'use strict';

const os = require('os');
const path = require('path');

const ROOT = path.join(os.homedir(), '.funclash');

const paths = {
  root: ROOT,
  binDir: path.join(ROOT, 'bin'),
  coreBinary: path.join(ROOT, 'bin', process.platform === 'win32' ? 'mihomo.exe' : 'mihomo'),
  coreVersionFile: path.join(ROOT, 'bin', 'version.json'),
  configDir: path.join(ROOT, 'config'),
  configFile: path.join(ROOT, 'config', 'config.yaml'),
  dashboardDir: path.join(ROOT, 'dashboard'),
  runDir: path.join(ROOT, 'run'),
  pidFile: path.join(ROOT, 'run', 'funclash.pid'),
  logFile: path.join(ROOT, 'run', 'mihomo.log'),
  tmpDir: path.join(ROOT, 'tmp'),
};

module.exports = paths;

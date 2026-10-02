'use strict';

const os = require('os');
const path = require('path');

const ROOT = path.join(os.homedir(), '.funclash');
const RUN_DIR = process.env.FUNCLASH_RUN_DIR
  ? path.resolve(process.env.FUNCLASH_RUN_DIR)
  : path.join(ROOT, '.run');

const paths = {
  root: ROOT,
  binDir: path.join(ROOT, 'bin'),
  coreBinary: path.join(ROOT, 'bin', process.platform === 'win32' ? 'mihomo.exe' : 'mihomo'),
  coreVersionFile: path.join(ROOT, 'bin', 'version.json'),
  configDir: path.join(ROOT, 'config'),
  configFile: path.join(ROOT, 'config', 'config.yaml'),
  dashboardDir: path.join(ROOT, 'dashboard'),
  runDir: RUN_DIR,
  pidFile: path.join(RUN_DIR, 'funclash.pid'),
  logFile: path.join(RUN_DIR, 'mihomo.log'),
  tmpDir: path.join(ROOT, 'tmp'),
};

module.exports = paths;

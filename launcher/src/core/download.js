'use strict';

const fs = require('fs');
const zlib = require('zlib');
const path = require('path');
const { pipeline } = require('stream/promises');

const tar = require('tar');

const paths = require('./paths');
const platform = require('./platform');
const github = require('../utils/github');
const logger = require('../utils/logger');

const MIHOMO_REPO = 'MetaCubeX/mihomo';

function ensureDirs() {
  for (const dir of [paths.binDir, paths.configDir, paths.dashboardDir, paths.runDir, paths.tmpDir]) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

async function gunzipFile(srcPath, destPath) {
  await pipeline(fs.createReadStream(srcPath), zlib.createGunzip(), fs.createWriteStream(destPath));
}

/**
 * Download and install the mihomo core binary for the current platform into
 * ~/.funclash/bin/mihomo(.exe). Idempotent unless `force` is set.
 */
async function installMihomoCore({ version = 'latest', compatible = false, force = false } = {}) {
  ensureDirs();

  if (!force && fs.existsSync(paths.coreBinary)) {
    logger.info(`mihomo core already installed at ${paths.coreBinary} (use --force to reinstall)`);
    return JSON.parse(fs.readFileSync(paths.coreVersionFile, 'utf8'));
  }

  logger.info(`Fetching mihomo release metadata (${version})...`);
  const release = await github.getRelease(MIHOMO_REPO, version);
  const tag = release.tag_name;
  const assetName = platform.mihomoAssetName(tag, { compatible });
  const asset = github.findAsset(release, assetName);

  const tmpDownload = path.join(paths.tmpDir, asset.name);
  logger.info(`Downloading ${asset.name}...`);
  await github.downloadAsset(asset, tmpDownload);

  logger.info('Extracting mihomo binary...');
  if (asset.name.endsWith('.gz')) {
    await gunzipFile(tmpDownload, paths.coreBinary);
  } else if (asset.name.endsWith('.zip')) {
    const extractZip = require('./zip').extract;
    const outDir = path.join(paths.tmpDir, 'mihomo-zip');
    fs.rmSync(outDir, { recursive: true, force: true });
    await extractZip(tmpDownload, outDir);
    const [binName] = fs.readdirSync(outDir);
    fs.renameSync(path.join(outDir, binName), paths.coreBinary);
    fs.rmSync(outDir, { recursive: true, force: true });
  } else {
    throw new Error(`Unrecognized mihomo asset extension: ${asset.name}`);
  }

  fs.chmodSync(paths.coreBinary, 0o755);
  fs.rmSync(tmpDownload, { force: true });

  const meta = {
    version: tag,
    os: platform.detect().os,
    arch: platform.detect().arch,
    downloadedAt: new Date().toISOString(),
  };
  fs.writeFileSync(paths.coreVersionFile, JSON.stringify(meta, null, 2));
  logger.info(`mihomo ${tag} installed at ${paths.coreBinary}`);
  return meta;
}

/**
 * Install the funclash web dashboard (Flutter web build) into ~/.funclash/dashboard.
 * Prefers a local pre-built directory (`webDir`, e.g. app/build/web) since this
 * project has no published release assets yet; falls back to downloading a
 * `funclash-web-*.tar.gz` asset from `repo`'s releases if no local dir is given.
 */
async function installWebDashboard({ webDir, repo, version = 'latest', force = false } = {}) {
  ensureDirs();

  if (!force && fs.existsSync(path.join(paths.dashboardDir, 'index.html'))) {
    logger.info(`Web dashboard already installed at ${paths.dashboardDir} (use --force to reinstall)`);
    return;
  }

  if (webDir) {
    const resolved = path.resolve(webDir);
    if (!fs.existsSync(path.join(resolved, 'index.html'))) {
      throw new Error(
        `--web-dir ${resolved} does not look like a Flutter web build (no index.html found). ` +
          'Build it first with: cd app && flutter build web'
      );
    }
    logger.info(`Copying web dashboard from ${resolved}...`);
    fs.rmSync(paths.dashboardDir, { recursive: true, force: true });
    fs.cpSync(resolved, paths.dashboardDir, { recursive: true });
    logger.info(`Web dashboard installed at ${paths.dashboardDir}`);
    return;
  }

  if (!repo) {
    throw new Error(
      'No local web build found and no --repo given to download one from.\n' +
        'Either build the Flutter app locally (cd app && flutter build web) and run\n' +
        '  funclash install --web-dir app/build/web\n' +
        'or pass --repo <owner/name> once a funclash-web release has been published.'
    );
  }

  logger.info(`Fetching funclash-web release metadata from ${repo} (${version})...`);
  const release = await github.getRelease(repo, version);
  const asset = github.findAsset(release, (name) => /^funclash-web-.*\.tar\.gz$/.test(name));
  const tmpDownload = path.join(paths.tmpDir, asset.name);
  logger.info(`Downloading ${asset.name}...`);
  await github.downloadAsset(asset, tmpDownload);

  logger.info('Extracting web dashboard...');
  fs.rmSync(paths.dashboardDir, { recursive: true, force: true });
  fs.mkdirSync(paths.dashboardDir, { recursive: true });
  await tar.x({ file: tmpDownload, cwd: paths.dashboardDir });
  fs.rmSync(tmpDownload, { force: true });
  logger.info(`Web dashboard installed at ${paths.dashboardDir}`);
}

module.exports = { installMihomoCore, installWebDashboard, ensureDirs };

'use strict';

const extractZip = require('extract-zip');

async function extract(zipPath, destDir) {
  await extractZip(zipPath, { dir: destDir });
}

module.exports = { extract };

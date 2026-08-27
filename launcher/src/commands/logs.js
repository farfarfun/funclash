'use strict';

const fs = require('fs');

const paths = require('../core/paths');
const logger = require('../utils/logger');

function tailLines(text, n) {
  const lines = text.split('\n');
  return lines.slice(Math.max(0, lines.length - n)).join('\n');
}

async function logs(opts = {}) {
  if (!fs.existsSync(paths.logFile)) {
    logger.info(`No log file yet at ${paths.logFile} (start with \`funclash start -d\` first).`);
    return;
  }

  const n = Number(opts.lines) || 100;

  if (!opts.follow) {
    process.stdout.write(tailLines(fs.readFileSync(paths.logFile, 'utf8'), n));
    return;
  }

  process.stdout.write(tailLines(fs.readFileSync(paths.logFile, 'utf8'), n));
  let position = fs.statSync(paths.logFile).size;
  fs.watch(paths.logFile, { persistent: true }, (eventType) => {
    if (eventType !== 'change') return;
    const { size } = fs.statSync(paths.logFile);
    if (size < position) position = 0; // log rotated/truncated
    const stream = fs.createReadStream(paths.logFile, { start: position, end: size });
    stream.on('data', (chunk) => process.stdout.write(chunk));
    position = size;
  });
}

module.exports = logs;

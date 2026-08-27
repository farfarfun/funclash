'use strict';

const fs = require('fs');
const { pipeline } = require('stream/promises');

function authHeaders() {
  const headers = { 'User-Agent': 'funclash-cli' };
  if (process.env.GITHUB_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }
  return headers;
}

/**
 * Fetch release metadata (assets, tag_name) for a repo.
 * @param {string} repo - "owner/name"
 * @param {string} tag - "latest" or a specific tag like "v1.19.0"
 */
async function getRelease(repo, tag = 'latest') {
  const url =
    tag === 'latest'
      ? `https://api.github.com/repos/${repo}/releases/latest`
      : `https://api.github.com/repos/${repo}/releases/tags/${tag}`;
  const res = await fetch(url, { headers: authHeaders() });
  if (!res.ok) {
    throw new Error(`GitHub API request failed (${res.status} ${res.statusText}) for ${url}`);
  }
  return res.json();
}

function findAsset(release, matcher) {
  const asset = release.assets.find((a) =>
    typeof matcher === 'function' ? matcher(a.name) : a.name === matcher
  );
  if (!asset) {
    throw new Error(
      `No matching release asset found in ${release.html_url || release.tag_name}. ` +
        `Available assets: ${release.assets.map((a) => a.name).join(', ')}`
    );
  }
  return asset;
}

/**
 * Download a release asset (by browser_download_url) to a local file path.
 */
async function downloadAsset(asset, destPath) {
  const res = await fetch(asset.browser_download_url, { headers: authHeaders() });
  if (!res.ok || !res.body) {
    throw new Error(`Failed to download ${asset.name} (${res.status} ${res.statusText})`);
  }
  await pipeline(res.body, fs.createWriteStream(destPath));
}

module.exports = { getRelease, findAsset, downloadAsset };

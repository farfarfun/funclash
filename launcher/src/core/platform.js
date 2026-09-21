'use strict';

const OS_MAP = {
  linux: 'linux',
  darwin: 'darwin',
  win32: 'windows',
};

const ARCH_MAP = {
  x64: 'amd64',
  arm64: 'arm64',
  ia32: '386',
};

function detect() {
  const os = OS_MAP[process.platform];
  const arch = ARCH_MAP[process.arch];
  if (!os || !arch) {
    throw new Error(
      `Unsupported platform/arch: ${process.platform}/${process.arch}. ` +
        'funclash supports linux, macOS and Windows on amd64/arm64.'
    );
  }
  return { os, arch };
}

/** 构造当前平台对应的 mihomo release 资源文件名。 */
function mihomoAssetName(version, { compatible = false } = {}) {
  const { os, arch } = detect();
  const ext = os === 'windows' ? 'zip' : 'gz';
  const suffix = compatible ? '-compatible' : '';
  return `mihomo-${os}-${arch}${suffix}-${version}.${ext}`;
}

module.exports = { detect, mihomoAssetName };

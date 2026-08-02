#!/usr/bin/env bash
# Install ZCode desktop app from the official ARM64 .deb (zcode.z.ai CDN).
# Debian aarch64 proot/chroot. Electron GUI — needs a Graphical Desktop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=zcode"

ZCODE_VERSION="${ZCODE_VERSION:-3.5.3}"
ZCODE_CACHE="${ZCODE_CACHE:-/var/cache/nc-mp}"
ZCODE_DEB="$ZCODE_CACHE/ZCode-${ZCODE_VERSION}-linux-arm64.deb"
ZCODE_URL="${ZCODE_URL:-https://cdn-zcode.z.ai/zcode/electron/releases/${ZCODE_VERSION}/linux-arm64/ZCode-${ZCODE_VERSION}-linux-arm64.deb}"

if nc_mp_pkg_ok zcode && command -v zcode >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size_pkgs zcode
  nc_mp_emit_paths /opt/ZCode/zcode /usr/bin/zcode
  echo "NC_MP_STATUS=done id=zcode exit=0"
  exit 0
fi

if [ "$(uname -m)" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$(uname -m) need=aarch64"
  echo "ERROR: the zcode deb is built for arm64 only" >&2
  echo "NC_MP_STATUS=done id=zcode exit=1"
  exit 1
fi

# Runtime deps declared by the deb (libgtk-3-0, libnss3, xdg-utils, ...)
echo "NC_MP_STATUS=apt_deps"
nc_mp_apt_install \
  libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 \
  xdg-utils libatspi2.0-0 libuuid1 libsecret-1-0

if [ ! -f "$ZCODE_DEB" ]; then
  nc_mp_download "$ZCODE_URL" "$ZCODE_DEB"
fi

echo "NC_MP_STATUS=dpkg_install pkg=zcode version=$ZCODE_VERSION"
if ! dpkg -i "$ZCODE_DEB"; then
  echo "NC_MP_STATUS=dpkg_fix_deps"
  nc_mp_apt_update
  apt-get install -y -f
  dpkg -i "$ZCODE_DEB"
fi

if ! nc_mp_pkg_ok zcode || ! command -v zcode >/dev/null 2>&1; then
  echo "NC_MP_STATUS=error zcode_install_failed"
  echo "ERROR: zcode binary not found after install" >&2
  echo "NC_MP_STATUS=done id=zcode exit=1"
  exit 1
fi

nc_mp_emit_size_pkgs zcode
nc_mp_emit_paths /opt/ZCode/zcode /usr/bin/zcode
echo "NC_MP_STATUS=hint sandbox=no_sandbox"
echo "INFO: run 'zcode --no-sandbox' if the Chromium sandbox fails under proot/chroot."
echo "NC_MP_STATUS=done id=zcode exit=0"

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

# Verify the deb is complete by decompressing the full data.tar member.
# (dpkg-deb --info alone is not enough: control comes before data.tar,
# so a truncated data member can still pass the control check.)
verify_deb() {
  [ -s "$ZCODE_DEB" ] && dpkg-deb --fsys-tarfile "$ZCODE_DEB" >/dev/null 2>&1
}

download_zcode_deb() {
  echo "NC_MP_STATUS=download url=$ZCODE_URL"
  rm -f "$ZCODE_DEB"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 5 --retry-all-errors --retry-delay 2 -o "$ZCODE_DEB" "$ZCODE_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries 5 -O "$ZCODE_DEB" "$ZCODE_URL"
  else
    echo "NC_MP_STATUS=error no_curl_wget"
    echo "NC_MP_STATUS=done id=zcode exit=1"
    exit 1
  fi
}

# Download the deb; retry up to 3 times if it is truncated or otherwise invalid.
attempt=0
while [ "$attempt" -lt 3 ]; do
  if [ ! -f "$ZCODE_DEB" ] || ! verify_deb; then
    download_zcode_deb
  fi
  if verify_deb; then
    break
  fi
  attempt=$((attempt + 1))
  echo "NC_MP_STATUS=warn download_retry attempt=$attempt"
done

if ! verify_deb; then
  echo "NC_MP_STATUS=error corrupt_download url=$ZCODE_URL"
  echo "ERROR: downloaded deb failed verification — check network/disk and retry." >&2
  echo "NC_MP_STATUS=done id=zcode exit=1"
  exit 1
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

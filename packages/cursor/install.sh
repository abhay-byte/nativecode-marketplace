#!/usr/bin/env bash
# Install Cursor desktop app from the official ARM64 .deb (cursor.com).
# Debian aarch64 proot/chroot. Electron GUI — needs a Graphical Desktop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=cursor"

CURSOR_VERSION="${CURSOR_VERSION:-3.14}"
CURSOR_CACHE="${CURSOR_CACHE:-/var/cache/nc-mp}"
CURSOR_DEB="$CURSOR_CACHE/cursor-${CURSOR_VERSION}-arm64.deb"
CURSOR_URL="${CURSOR_URL:-https://api2.cursor.sh/updates/download/golden/linux-arm64-deb/cursor/${CURSOR_VERSION}}"

if nc_mp_pkg_ok cursor && command -v cursor >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size_pkgs cursor
  nc_mp_emit_paths /usr/share/cursor/cursor /usr/bin/cursor
  echo "NC_MP_STATUS=done id=cursor exit=0"
  exit 0
fi

if [ "$(uname -m)" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$(uname -m) need=aarch64"
  echo "ERROR: the cursor deb is built for arm64 only" >&2
  echo "NC_MP_STATUS=done id=cursor exit=1"
  exit 1
fi

# Verify the deb is complete by decompressing the full data.tar member.
# (dpkg-deb --info alone is not enough: control comes before data.tar.)
verify_deb() {
  [ -s "$CURSOR_DEB" ] && dpkg-deb --fsys-tarfile "$CURSOR_DEB" >/dev/null 2>&1
}

download_cursor_deb() {
  echo "NC_MP_STATUS=download url=$CURSOR_URL"
  rm -f "$CURSOR_DEB"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 5 --retry-all-errors --retry-delay 2 -o "$CURSOR_DEB" "$CURSOR_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries 5 -O "$CURSOR_DEB" "$CURSOR_URL"
  else
    echo "NC_MP_STATUS=error no_curl_wget"
    echo "NC_MP_STATUS=done id=cursor exit=1"
    exit 1
  fi
}

# Download the deb; retry up to 3 times if it is truncated or otherwise invalid.
attempt=0
while [ "$attempt" -lt 3 ]; do
  if [ ! -f "$CURSOR_DEB" ] || ! verify_deb; then
    download_cursor_deb
  fi
  if verify_deb; then
    break
  fi
  attempt=$((attempt + 1))
  echo "NC_MP_STATUS=warn download_retry attempt=$attempt"
done

if ! verify_deb; then
  echo "NC_MP_STATUS=error corrupt_download url=$CURSOR_URL"
  echo "ERROR: downloaded deb failed verification — check network/disk and retry." >&2
  echo "NC_MP_STATUS=done id=cursor exit=1"
  exit 1
fi

# Install via apt so all deb dependencies are resolved automatically.
# postinst creates /usr/bin/cursor and registers the cursor apt repo for updates.
echo "NC_MP_STATUS=apt_install pkg=cursor version=$CURSOR_VERSION"
if ! apt-get install -y "$CURSOR_DEB"; then
  echo "NC_MP_STATUS=apt_update_retry"
  nc_mp_apt_update
  apt-get install -y "$CURSOR_DEB"
fi

if ! nc_mp_pkg_ok cursor || ! command -v cursor >/dev/null 2>&1; then
  echo "NC_MP_STATUS=error cursor_install_failed"
  echo "ERROR: cursor binary not found after install" >&2
  echo "NC_MP_STATUS=done id=cursor exit=1"
  exit 1
fi

nc_mp_emit_size_pkgs cursor
nc_mp_emit_paths /usr/share/cursor/cursor /usr/bin/cursor
echo "NC_MP_STATUS=hint sandbox=no_sandbox"
echo "INFO: run 'cursor --no-sandbox' if the Chromium sandbox fails under proot/chroot."
echo "NC_MP_STATUS=done id=cursor exit=0"

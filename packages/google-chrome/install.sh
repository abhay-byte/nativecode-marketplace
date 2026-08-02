#!/usr/bin/env bash
# Install Google Chrome stable from the official ARM64 .deb (dl.google.com).
# Debian aarch64 proot/chroot. Chromium/Electron GUI — needs a Graphical Desktop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=google-chrome"

CHROME_CACHE="${CHROME_CACHE:-/var/cache/nc-mp}"
CHROME_DEB="$CHROME_CACHE/google-chrome-stable-arm64.deb"
CHROME_URL="${CHROME_URL:-https://dl.google.com/linux/direct/google-chrome-stable_current_arm64.deb}"

if nc_mp_pkg_ok google-chrome-stable && command -v google-chrome-stable >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size_pkgs google-chrome-stable
  nc_mp_emit_paths /opt/google/chrome/google-chrome /usr/bin/google-chrome-stable
  echo "NC_MP_STATUS=done id=google-chrome exit=0"
  exit 0
fi

if [ "$(uname -m)" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$(uname -m) need=aarch64"
  echo "ERROR: the google-chrome deb is built for arm64 only" >&2
  echo "NC_MP_STATUS=done id=google-chrome exit=1"
  exit 1
fi

# Verify the deb is complete by decompressing the full data.tar member.
# (dpkg-deb --info alone is not enough: control comes before data.tar.)
verify_deb() {
  [ -s "$CHROME_DEB" ] && dpkg-deb --fsys-tarfile "$CHROME_DEB" >/dev/null 2>&1
}

download_chrome_deb() {
  echo "NC_MP_STATUS=download url=$CHROME_URL"
  rm -f "$CHROME_DEB"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 5 --retry-all-errors --retry-delay 2 -o "$CHROME_DEB" "$CHROME_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries 5 -O "$CHROME_DEB" "$CHROME_URL"
  else
    echo "NC_MP_STATUS=error no_curl_wget"
    echo "NC_MP_STATUS=done id=google-chrome exit=1"
    exit 1
  fi
}

# Download the deb; retry up to 3 times if it is truncated or otherwise invalid.
attempt=0
while [ "$attempt" -lt 3 ]; do
  if [ ! -f "$CHROME_DEB" ] || ! verify_deb; then
    download_chrome_deb
  fi
  if verify_deb; then
    break
  fi
  attempt=$((attempt + 1))
  echo "NC_MP_STATUS=warn download_retry attempt=$attempt"
done

if ! verify_deb; then
  echo "NC_MP_STATUS=error corrupt_download url=$CHROME_URL"
  echo "ERROR: downloaded deb failed verification — check network/disk and retry." >&2
  echo "NC_MP_STATUS=done id=google-chrome exit=1"
  exit 1
fi

# Install via apt so all deb dependencies are resolved automatically.
echo "NC_MP_STATUS=apt_install pkg=google-chrome-stable"
if ! apt-get install -y "$CHROME_DEB"; then
  echo "NC_MP_STATUS=apt_update_retry"
  nc_mp_apt_update
  apt-get install -y "$CHROME_DEB"
fi

if ! nc_mp_pkg_ok google-chrome-stable || ! command -v google-chrome-stable >/dev/null 2>&1; then
  echo "NC_MP_STATUS=error chrome_install_failed"
  echo "ERROR: google-chrome-stable binary not found after install" >&2
  echo "NC_MP_STATUS=done id=google-chrome exit=1"
  exit 1
fi

nc_mp_emit_size_pkgs google-chrome-stable
nc_mp_emit_paths /opt/google/chrome/google-chrome /usr/bin/google-chrome-stable
echo "NC_MP_STATUS=hint sandbox=no_sandbox"
echo "INFO: run 'google-chrome-stable --no-sandbox' if the Chromium sandbox fails under proot/chroot."
echo "NC_MP_STATUS=done id=google-chrome exit=0"
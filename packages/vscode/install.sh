#!/usr/bin/env bash
# Install Visual Studio Code from the official ARM64 .deb (code.visualstudio.com).
# Debian aarch64 proot/chroot. Electron GUI — needs a Graphical Desktop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=vscode"

VSCODE_CACHE="${VSCODE_CACHE:-/var/cache/nc-mp}"
VSCODE_DEB="$VSCODE_CACHE/code-latest-arm64.deb"
VSCODE_URL="${VSCODE_URL:-https://update.code.visualstudio.com/latest/linux-deb-arm64/stable}"

if nc_mp_pkg_ok code && command -v code >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size_pkgs code
  nc_mp_emit_paths /usr/share/code/code /usr/bin/code
  echo "NC_MP_STATUS=done id=vscode exit=0"
  exit 0
fi

if [ "$(uname -m)" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$(uname -m) need=aarch64"
  echo "ERROR: the VS Code deb is built for arm64 only" >&2
  echo "NC_MP_STATUS=done id=vscode exit=1"
  exit 1
fi

# Verify the deb is complete by decompressing the full data.tar member.
# (dpkg-deb --info alone is not enough: control comes before data.tar.)
verify_deb() {
  [ -s "$VSCODE_DEB" ] && dpkg-deb --fsys-tarfile "$VSCODE_DEB" >/dev/null 2>&1
}

download_vscode_deb() {
  echo "NC_MP_STATUS=download url=$VSCODE_URL"
  rm -f "$VSCODE_DEB"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 5 --retry-all-errors --retry-delay 2 -o "$VSCODE_DEB" "$VSCODE_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries 5 -O "$VSCODE_DEB" "$VSCODE_URL"
  else
    echo "NC_MP_STATUS=error no_curl_wget"
    echo "NC_MP_STATUS=done id=vscode exit=1"
    exit 1
  fi
}

# Download the deb; retry up to 3 times if it is truncated or otherwise invalid.
attempt=0
while [ "$attempt" -lt 3 ]; do
  if [ ! -f "$VSCODE_DEB" ] || ! verify_deb; then
    download_vscode_deb
  fi
  if verify_deb; then
    break
  fi
  attempt=$((attempt + 1))
  echo "NC_MP_STATUS=warn download_retry attempt=$attempt"
done

if ! verify_deb; then
  echo "NC_MP_STATUS=error corrupt_download url=$VSCODE_URL"
  echo "ERROR: downloaded deb failed verification — check network/disk and retry." >&2
  echo "NC_MP_STATUS=done id=vscode exit=1"
  exit 1
fi

# Install via apt so all deb dependencies are resolved automatically.
# postinst creates /usr/bin/code and registers the VS Code apt repo for updates.
echo "NC_MP_STATUS=apt_install pkg=code"
if ! apt-get install -y "$VSCODE_DEB"; then
  echo "NC_MP_STATUS=apt_update_retry"
  nc_mp_apt_update
  apt-get install -y "$VSCODE_DEB"
fi

if ! nc_mp_pkg_ok code || ! command -v code >/dev/null 2>&1; then
  echo "NC_MP_STATUS=error vscode_install_failed"
  echo "ERROR: code binary not found after install" >&2
  echo "NC_MP_STATUS=done id=vscode exit=1"
  exit 1
fi

nc_mp_emit_size_pkgs code
nc_mp_emit_paths /usr/share/code/code /usr/bin/code
echo "NC_MP_STATUS=hint sandbox=no_sandbox"
echo "INFO: run 'code --no-sandbox' if the Chromium sandbox fails under proot/chroot."
echo "NC_MP_STATUS=done id=vscode exit=0"

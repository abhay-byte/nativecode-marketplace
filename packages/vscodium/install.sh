#!/usr/bin/env bash
# Install VSCodium from the community ARM64 .deb (github.com/VSCodium/vscodium).
# Debian aarch64 proot/chroot. Electron GUI — needs a Graphical Desktop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=vscodium"

VSCODIUM_VERSION="${VSCODIUM_VERSION:-1.126.04524}"
VSCODIUM_CACHE="${VSCODIUM_CACHE:-/var/cache/nc-mp}"
VSCODIUM_DEB="$VSCODIUM_CACHE/codium-${VSCODIUM_VERSION}-arm64.deb"
VSCODIUM_URL="${VSCODIUM_URL:-https://github.com/VSCodium/vscodium/releases/download/${VSCODIUM_VERSION}/codium_${VSCODIUM_VERSION}_arm64.deb}"

if nc_mp_pkg_ok codium && command -v codium >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size_pkgs codium
  nc_mp_emit_paths /usr/share/codium/codium /usr/bin/codium
  echo "NC_MP_STATUS=done id=vscodium exit=0"
  exit 0
fi

if [ "$(uname -m)" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$(uname -m) need=aarch64"
  echo "ERROR: the VSCodium deb is built for arm64 only" >&2
  echo "NC_MP_STATUS=done id=vscodium exit=1"
  exit 1
fi

# Verify the deb is complete by decompressing the full data.tar member.
# (dpkg-deb --info alone is not enough: control comes before data.tar.)
verify_deb() {
  [ -s "$VSCODIUM_DEB" ] && dpkg-deb --fsys-tarfile "$VSCODIUM_DEB" >/dev/null 2>&1
}

download_codium_deb() {
  echo "NC_MP_STATUS=download url=$VSCODIUM_URL"
  rm -f "$VSCODIUM_DEB"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 5 --retry-all-errors --retry-delay 2 -o "$VSCODIUM_DEB" "$VSCODIUM_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries 5 -O "$VSCODIUM_DEB" "$VSCODIUM_URL"
  else
    echo "NC_MP_STATUS=error no_curl_wget"
    echo "NC_MP_STATUS=done id=vscodium exit=1"
    exit 1
  fi
}

# Download the deb; retry up to 3 times if it is truncated or otherwise invalid.
attempt=0
while [ "$attempt" -lt 3 ]; do
  if [ ! -f "$VSCODIUM_DEB" ] || ! verify_deb; then
    download_codium_deb
  fi
  if verify_deb; then
    break
  fi
  attempt=$((attempt + 1))
  echo "NC_MP_STATUS=warn download_retry attempt=$attempt"
done

if ! verify_deb; then
  echo "NC_MP_STATUS=error corrupt_download url=$VSCODIUM_URL"
  echo "ERROR: downloaded deb failed verification — check network/disk and retry." >&2
  echo "NC_MP_STATUS=done id=vscodium exit=1"
  exit 1
fi

# Install via apt so all deb dependencies are resolved automatically.
# postinst creates /usr/bin/codium.
echo "NC_MP_STATUS=apt_install pkg=codium version=$VSCODIUM_VERSION"
if ! apt-get install -y "$VSCODIUM_DEB"; then
  echo "NC_MP_STATUS=apt_update_retry"
  nc_mp_apt_update
  apt-get install -y "$VSCODIUM_DEB"
fi

if ! nc_mp_pkg_ok codium || ! command -v codium >/dev/null 2>&1; then
  echo "NC_MP_STATUS=error vscodium_install_failed"
  echo "ERROR: codium binary not found after install" >&2
  echo "NC_MP_STATUS=done id=vscodium exit=1"
  exit 1
fi

nc_mp_emit_size_pkgs codium
nc_mp_emit_paths /usr/share/codium/codium /usr/bin/codium
echo "NC_MP_STATUS=hint sandbox=no_sandbox"
echo "INFO: run 'codium --no-sandbox' if the Chromium sandbox fails under proot/chroot."
echo "NC_MP_STATUS=done id=vscodium exit=0"
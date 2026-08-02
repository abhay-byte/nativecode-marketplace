#!/usr/bin/env bash
# Removes the Firefox install dir, launcher, desktop entry, and icon.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=firefox action=uninstall"
rm -rf /opt/firefox
rm -f /usr/local/bin/firefox
rm -f /usr/share/applications/firefox.desktop
rm -f /usr/share/icons/hicolor/128x128/apps/firefox.png
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
rm -f /var/cache/nc-mp/firefox-latest-linux-aarch64.tar.xz
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=firefox exit=0"
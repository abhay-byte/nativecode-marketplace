#!/usr/bin/env bash
# Removes the Antigravity IDE install dir, launcher, desktop entry, and icon.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=antigravity-ide action=uninstall"
rm -rf /opt/antigravity-ide
rm -f /usr/local/bin/antigravity-ide
rm -f /usr/share/applications/antigravity-ide.desktop
rm -f /usr/share/icons/hicolor/256x256/apps/antigravity-ide.png
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
rm -f /var/cache/nc-mp/antigravity-ide-*-linux-arm.tar.gz
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=antigravity-ide exit=0"

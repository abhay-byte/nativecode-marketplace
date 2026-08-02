#!/usr/bin/env bash
# Removes the VS Code (code) package only (postrm drops /usr/bin/code).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=vscode action=uninstall"
nc_mp_apt_remove code
rm -f /var/cache/nc-mp/code-latest-arm64.deb
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=vscode exit=0"

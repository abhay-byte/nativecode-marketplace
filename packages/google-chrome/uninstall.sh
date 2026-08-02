#!/usr/bin/env bash
# Removes the google-chrome-stable package only (postrm drops /usr/bin symlinks).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=google-chrome action=uninstall"
nc_mp_apt_remove google-chrome-stable
rm -f /var/cache/nc-mp/google-chrome-stable-arm64.deb
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=google-chrome exit=0"
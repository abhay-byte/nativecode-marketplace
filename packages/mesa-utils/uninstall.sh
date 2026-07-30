#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=mesa-utils action=uninstall"
nc_mp_apt_remove mesa-utils
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=mesa-utils exit=0"

#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=glmark2 action=uninstall"
# Do not remove mesa-utils (shared dep)
nc_mp_apt_remove glmark2
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=glmark2 exit=0"

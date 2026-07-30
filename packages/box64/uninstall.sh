#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=box64 action=uninstall"
nc_mp_apt_remove box64
# Do not rm random paths; only apt-owned
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=box64 exit=0"

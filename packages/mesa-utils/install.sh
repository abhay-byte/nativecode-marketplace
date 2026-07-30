#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../../lib/nc_mp_common.sh
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=mesa-utils"
nc_mp_apt_install mesa-utils
nc_mp_emit_size_pkgs mesa-utils
nc_mp_emit_paths /usr/bin/glxinfo
echo "NC_MP_STATUS=done id=mesa-utils exit=0"

#!/usr/bin/env bash
# Installs glmark2 only. mesa-utils is a marketplace dep installed by the runner first.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=glmark2"
nc_mp_apt_install glmark2
nc_mp_emit_size_pkgs glmark2
nc_mp_emit_paths /usr/bin/glmark2
echo "NC_MP_STATUS=done id=glmark2 exit=0"

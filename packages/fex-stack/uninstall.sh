#!/usr/bin/env bash
# Meta only — does not remove deps (uninstall fex-rootfs / fex-emu / fex-build-deps separately).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-stack action=uninstall"
echo "NC_MP_STATUS=meta no_files (uninstall fex-rootfs, fex-emu, fex-build-deps as needed)"
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=fex-stack exit=0"

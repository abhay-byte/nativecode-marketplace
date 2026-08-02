#!/usr/bin/env bash
# Install Debian Chromium from apt. Debian aarch64 proot/chroot.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=chromium"
nc_mp_apt_install chromium
nc_mp_emit_size_pkgs chromium
nc_mp_emit_paths /usr/bin/chromium
echo "NC_MP_STATUS=hint sandbox=no_sandbox"
echo "INFO: run 'chromium --no-sandbox' if the Chromium sandbox fails under proot/chroot."
echo "NC_MP_STATUS=done id=chromium exit=0"
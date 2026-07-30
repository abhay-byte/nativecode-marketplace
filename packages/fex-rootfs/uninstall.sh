#!/usr/bin/env bash
# Remove FEX RootFS data and profile. Leaves fex-emu binaries installed.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-rootfs action=uninstall"

FLUX_USER="${NC_MP_FLUX_USER:-flux}"
FLUX_HOME="/home/${FLUX_USER}"
[ -d "$FLUX_HOME" ] || FLUX_HOME="/root"

rm -f /etc/profile.d/fex-emu.sh

# Primary install location
rm -rf /opt/fex-emu

# Common alternate locations (fetcher defaults)
rm -rf /root/.local/share/fex-emu
rm -rf "${FLUX_HOME}/.local/share/fex-emu"
rm -rf /var/cache/nc-mp/fex-rootfs 2>/dev/null || true

# Strip FEX_ROOTFS lines we added (best-effort)
if [ -f "${FLUX_HOME}/.bashrc" ]; then
  sed -i '/NativeCode marketplace FEX RootFS/d' "${FLUX_HOME}/.bashrc" 2>/dev/null || true
  sed -i '/export FEX_ROOTFS=/d' "${FLUX_HOME}/.bashrc" 2>/dev/null || true
fi

echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=fex-rootfs exit=0"

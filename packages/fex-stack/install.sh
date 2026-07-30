#!/usr/bin/env bash
# Meta package: deps pull full FEX stack. Nothing else to install.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-stack"

if ! command -v FEX >/dev/null 2>&1; then
  echo "NC_MP_STATUS=error missing FEX (deps should have installed fex-emu)"
  echo "ERROR: FEX not on PATH after dependency install" >&2
  echo "NC_MP_STATUS=done id=fex-stack exit=1"
  exit 1
fi

ROOTFS=""
if [ -n "${FEX_ROOTFS:-}" ] && [ -d "${FEX_ROOTFS}" ]; then
  ROOTFS="$FEX_ROOTFS"
elif [ -f /etc/profile.d/fex-emu.sh ]; then
  # shellcheck disable=SC1091
  . /etc/profile.d/fex-emu.sh
  ROOTFS="${FEX_ROOTFS:-}"
fi

if [ -z "${ROOTFS}" ] || [ ! -d "${ROOTFS}" ]; then
  echo "NC_MP_STATUS=error missing_rootfs install=fex-rootfs"
  echo "ERROR: FEX_ROOTFS not configured — fex-rootfs may have failed" >&2
  echo "NC_MP_STATUS=done id=fex-stack exit=1"
  exit 1
fi

echo "NC_MP_STATUS=stack_ok fex=$(command -v FEX) rootfs=$ROOTFS"
nc_mp_emit_size /usr/bin/FEX "$ROOTFS"
nc_mp_emit_paths /usr/bin/FEX "$ROOTFS" /etc/profile.d/fex-emu.sh
echo "NC_MP_STATUS=done id=fex-stack exit=0"

#!/usr/bin/env bash
# Remove FEX build toolchain packages. Does not remove FEX binaries or RootFS.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-build-deps action=uninstall"

# Only packages installed solely for FEX build. Leave git/python if commonly shared —
# still remove the heavy / FEX-specific set; apt will keep packages other software needs
# only if they were marked manually elsewhere (best-effort remove).
PKGS=(
  ccache
  clang llvm lld
  libssl-dev
  python3-pip python3-setuptools python3-packaging
  squashfs-tools squashfuse erofs-utils erofsfuse
  g++-x86-64-linux-gnu nasm
  binfmt-support
  ninja-build
  cmake
  pkgconf
)

nc_mp_apt_remove "${PKGS[@]}" || true
echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=fex-build-deps exit=0"

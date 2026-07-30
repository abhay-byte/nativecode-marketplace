#!/usr/bin/env bash
# Remove FEX binaries/libs. Does not remove RootFS or fex-build-deps.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-emu action=uninstall"

# Apt packages if used
nc_mp_apt_remove fex-emu-armv8.4 fex-emu fex-emu-binfmt32 fex-emu-binfmt64 || true

FILES=(
  /usr/bin/FEX
  /usr/bin/FEXBash
  /usr/bin/FEXInterpreter
  /usr/bin/FEXServer
  /usr/bin/FEXRootFSFetcher
  /usr/bin/FEXGetConfig
  /usr/bin/FEXOfflineCompiler
  /usr/bin/FEXpidof
  /usr/lib/libFEXCore.so
  /usr/lib/aarch64-linux-gnu/libFEXCore.so
  /usr/lib/binfmt.d/FEX-x86.conf
  /usr/lib/binfmt.d/FEX-x86_64.conf
  /usr/share/fex-emu
  /usr/include/FEXCore
)

for f in "${FILES[@]}"; do
  if [ -e "$f" ]; then
    rm -rf "$f"
    echo "NC_MP_STATUS=removed path=$f"
  fi
done

# Best-effort binfmt cleanup (no-op under proot)
if [ -d /proc/sys/fs/binfmt_misc ]; then
  echo -1 >/proc/sys/fs/binfmt_misc/FEX-x86 2>/dev/null || true
  echo -1 >/proc/sys/fs/binfmt_misc/FEX-x86_64 2>/dev/null || true
  if command -v update-binfmts >/dev/null 2>&1; then
    update-binfmts --remove FEX-x86 2>/dev/null || true
    update-binfmts --remove FEX-x86_64 2>/dev/null || true
  fi
fi

rm -rf /var/cache/nc-mp/fex-build 2>/dev/null || true

echo "NC_MP_SIZE_BYTES=0"
echo "NC_MP_STATUS=done id=fex-emu exit=0"

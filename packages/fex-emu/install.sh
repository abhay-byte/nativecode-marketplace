#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-emu"

CANDIDATES=(fex-emu-armv8.4 fex-emu fex-emu-binfmt32 fex-emu-binfmt64)
INSTALLED=()
for p in "${CANDIDATES[@]}"; do
  if nc_mp_pkg_ok "$p"; then
    INSTALLED+=("$p")
  fi
done
if [ "${#INSTALLED[@]}" -gt 0 ]; then
  echo "NC_MP_STATUS=skip already_installed pkgs=${INSTALLED[*]}"
  nc_mp_emit_size_pkgs "${INSTALLED[@]}"
  echo "NC_MP_STATUS=done id=fex-emu exit=0"
  exit 0
fi

for p in fex-emu-armv8.4 fex-emu; do
  if apt-cache show "$p" >/dev/null 2>&1; then
    nc_mp_apt_install "$p"
    nc_mp_emit_size_pkgs "$p"
    echo "NC_MP_STATUS=done id=fex-emu exit=0"
    exit 0
  fi
done

echo "NC_MP_STATUS=error fex_not_in_apt experimental"
echo "ERROR: FEX packages not in apt for this guest (experimental)." >&2
echo "NC_MP_STATUS=done id=fex-emu exit=1"
exit 1

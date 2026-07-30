#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=box64"

if nc_mp_pkg_ok box64 || command -v box64 >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size_pkgs box64
  if command -v box64 >/dev/null 2>&1; then
    nc_mp_emit_paths "$(command -v box64)"
  fi
  echo "NC_MP_STATUS=done id=box64 exit=0"
  exit 0
fi

# Prefer apt if package exists in configured repos
if apt-cache show box64 >/dev/null 2>&1; then
  nc_mp_apt_install box64
  nc_mp_emit_size_pkgs box64
  nc_mp_emit_paths /usr/local/bin/box64 /usr/bin/box64
  echo "NC_MP_STATUS=done id=box64 exit=0"
  exit 0
fi

echo "NC_MP_STATUS=error box64_not_in_apt"
echo "ERROR: box64 not available via apt on this rootfs. Add a repo or install manually." >&2
echo "NC_MP_STATUS=done id=box64 exit=1"
exit 1

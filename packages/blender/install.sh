#!/usr/bin/env bash
# Blender only — experimental on aarch64 if apt has no package.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=blender"

if nc_mp_pkg_ok blender || command -v blender >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size_pkgs blender
  echo "NC_MP_STATUS=done id=blender exit=0"
  exit 0
fi

if ! apt-cache show blender >/dev/null 2>&1; then
  echo "NC_MP_STATUS=error blender_not_in_apt experimental"
  echo "ERROR: blender not available via apt on this arch/rootfs (experimental)." >&2
  echo "NC_MP_STATUS=done id=blender exit=1"
  exit 1
fi

nc_mp_apt_install blender
nc_mp_emit_size_pkgs blender
nc_mp_emit_paths /usr/bin/blender
echo "NC_MP_STATUS=done id=blender exit=0"

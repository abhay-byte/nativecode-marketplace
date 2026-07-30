#!/usr/bin/env bash
# Install toolchain packages needed to build FEX-Emu from source (proot/chroot Debian).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-build-deps"

ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$ARCH need=aarch64"
  echo "ERROR: FEX build deps target aarch64 hosts only (got $ARCH)" >&2
  echo "NC_MP_STATUS=done id=fex-build-deps exit=1"
  exit 1
fi

# Build + RootFS extract tools. FUSE packages are optional on proot (often unused).
PKGS=(
  git cmake ninja-build pkgconf ccache
  clang llvm lld
  libssl-dev
  python3-pip python3-setuptools python3-packaging
  squashfs-tools erofs-utils
  g++-x86-64-linux-gnu nasm
)

# Best-effort extras (may be missing on some mirrors)
OPTIONAL=(binfmt-support squashfuse erofsfuse)

echo "NC_MP_STATUS=check free_space"
if command -v df >/dev/null 2>&1; then
  free_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
  # ~400 MiB headroom for apt packages
  if [ -n "${free_kb:-}" ] && [ "$free_kb" -lt 400000 ]; then
    echo "NC_MP_STATUS=error low_disk free_kb=$free_kb need_kb=400000"
    echo "ERROR: need ~400 MiB free for FEX build dependencies (have ${free_kb} KiB)" >&2
    echo "NC_MP_STATUS=done id=fex-build-deps exit=1"
    exit 1
  fi
fi

nc_mp_apt_install "${PKGS[@]}"

for p in "${OPTIONAL[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then
    nc_mp_apt_install "$p" || true
  fi
done

# Verify critical tools exist
MISSING=()
for bin in clang cmake ninja git nasm; do
  command -v "$bin" >/dev/null 2>&1 || MISSING+=("$bin")
done
command -v x86_64-linux-gnu-g++ >/dev/null 2>&1 || MISSING+=("x86_64-linux-gnu-g++")
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "NC_MP_STATUS=error missing_tools ${MISSING[*]}"
  echo "ERROR: required tools missing after apt: ${MISSING[*]}" >&2
  echo "NC_MP_STATUS=done id=fex-build-deps exit=1"
  exit 1
fi

nc_mp_emit_size_pkgs "${PKGS[@]}"
echo "NC_MP_STATUS=done id=fex-build-deps exit=0"

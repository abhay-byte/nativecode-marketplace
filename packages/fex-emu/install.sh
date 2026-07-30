#!/usr/bin/env bash
# Install FEX-Emu binaries (apt preferred, else source build). No RootFS download.
# Proot/chroot Debian aarch64. Runner must install fex-build-deps first.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-emu"

FEX_BUILD_DIR="${FEX_BUILD_DIR:-/var/cache/nc-mp/fex-build}"
FEX_INSTALL_PREFIX="${FEX_INSTALL_PREFIX:-/usr}"
FEX_GIT_URL="${FEX_GIT_URL:-https://github.com/FEX-Emu/FEX.git}"

ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$ARCH need=aarch64"
  echo "ERROR: FEX requires aarch64 host (got $ARCH)" >&2
  echo "NC_MP_STATUS=done id=fex-emu exit=1"
  exit 1
fi

already_ok() {
  command -v FEX >/dev/null 2>&1 || [ -x "${FEX_INSTALL_PREFIX}/bin/FEX" ]
}

emit_fex_size() {
  local paths=(
    "${FEX_INSTALL_PREFIX}/bin/FEX"
    "${FEX_INSTALL_PREFIX}/bin/FEXBash"
    "${FEX_INSTALL_PREFIX}/bin/FEXInterpreter"
    "${FEX_INSTALL_PREFIX}/bin/FEXServer"
    "${FEX_INSTALL_PREFIX}/bin/FEXRootFSFetcher"
    "${FEX_INSTALL_PREFIX}/bin/FEXGetConfig"
    "${FEX_INSTALL_PREFIX}/bin/FEXOfflineCompiler"
    "${FEX_INSTALL_PREFIX}/bin/FEXpidof"
    "${FEX_INSTALL_PREFIX}/lib/libFEXCore.so"
    "${FEX_INSTALL_PREFIX}/lib/aarch64-linux-gnu/libFEXCore.so"
  )
  nc_mp_emit_size "${paths[@]}"
  nc_mp_emit_paths "${paths[@]}"
}

if already_ok; then
  echo "NC_MP_STATUS=skip already_installed"
  emit_fex_size
  echo "NC_MP_STATUS=done id=fex-emu exit=0"
  exit 0
fi

# --- Fast path: Debian packages when present ---
echo "NC_MP_STATUS=probe apt_fex"
for p in fex-emu-armv8.4 fex-emu; do
  if apt-cache show "$p" >/dev/null 2>&1; then
    echo "NC_MP_STATUS=apt_install pkgs=$p"
    nc_mp_apt_install "$p" || true
    if already_ok || nc_mp_pkg_ok "$p"; then
      nc_mp_emit_size_pkgs "$p"
      echo "NC_MP_STATUS=done id=fex-emu exit=0"
      exit 0
    fi
  fi
done

# --- Source build ---
echo "NC_MP_STATUS=source_build"

for bin in clang cmake ninja git; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "NC_MP_STATUS=error missing_dep tool=$bin install=fex-build-deps"
    echo "ERROR: missing $bin — install marketplace package fex-build-deps first" >&2
    echo "NC_MP_STATUS=done id=fex-emu exit=1"
    exit 1
  fi
done

if command -v df >/dev/null 2>&1; then
  free_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
  # ~3 GiB free recommended for clone+build
  if [ -n "${free_kb:-}" ] && [ "$free_kb" -lt 3000000 ]; then
    echo "NC_MP_STATUS=error low_disk free_kb=$free_kb need_kb=3000000"
    echo "ERROR: need ~3 GiB free for FEX source build (have ${free_kb} KiB)" >&2
    echo "NC_MP_STATUS=done id=fex-emu exit=1"
    exit 1
  fi
fi

cleanup_build() {
  if [ -d "$FEX_BUILD_DIR" ]; then
    echo "NC_MP_STATUS=cleanup build_dir=$FEX_BUILD_DIR"
    rm -rf "$FEX_BUILD_DIR"
  fi
}
trap cleanup_build EXIT

echo "NC_MP_STATUS=clone url=$FEX_GIT_URL"
rm -rf "$FEX_BUILD_DIR"
mkdir -p "$(dirname "$FEX_BUILD_DIR")"
git clone --depth=1 --recurse-submodules -j"$(nproc 2>/dev/null || echo 2)" \
  "$FEX_GIT_URL" "$FEX_BUILD_DIR"

echo "NC_MP_STATUS=cmake"
mkdir -p "$FEX_BUILD_DIR/Build"
cd "$FEX_BUILD_DIR/Build"

CC=clang CXX=clang++ cmake \
  -DCMAKE_INSTALL_PREFIX="$FEX_INSTALL_PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_LINKER=lld \
  -DENABLE_LTO=False \
  -DBUILD_TESTING=False \
  -DBUILD_FEXCONFIG=False \
  -DENABLE_ASSERTIONS=False \
  -G Ninja \
  ..

echo "NC_MP_STATUS=ninja build"
ninja

echo "NC_MP_STATUS=ninja install"
ninja install

# binfmt_misc: optional; almost never available under proot
echo "NC_MP_STATUS=binfmt"
if [ -d /proc/sys/fs/binfmt_misc ]; then
  ninja binfmt_misc 2>/dev/null || true
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart systemd-binfmt 2>/dev/null || true
  fi
  if command -v service >/dev/null 2>&1; then
    service binfmt-support restart 2>/dev/null || true
  fi
else
  echo "NC_MP_STATUS=binfmt skip reason=no_binfmt_misc (normal on proot)"
fi

if ! already_ok; then
  echo "NC_MP_STATUS=error fex_binary_missing"
  echo "ERROR: FEX binary not found after install" >&2
  echo "NC_MP_STATUS=done id=fex-emu exit=1"
  exit 1
fi

# Drop build tree immediately (trap also runs)
cleanup_build
trap - EXIT

emit_fex_size
echo "NC_MP_STATUS=hint next=fex-rootfs"
echo "INFO: FEX binaries installed. Install marketplace package fex-rootfs for x86 RootFS (required on ARM64)."
echo "NC_MP_STATUS=done id=fex-emu exit=0"

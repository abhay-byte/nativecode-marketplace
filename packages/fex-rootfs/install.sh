#!/usr/bin/env bash
# Download + extract FEX x86 RootFS and configure FEX_ROOTFS (proot: always extract).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=fex-rootfs"

FLUX_USER="${NC_MP_FLUX_USER:-flux}"
FLUX_HOME="/home/${FLUX_USER}"
if [ ! -d "$FLUX_HOME" ]; then
  FLUX_HOME="/root"
  FLUX_USER="root"
fi

# Stable system location (avoids root-only clutter; readable by flux)
FEX_DATA_ROOT="${FEX_DATA_ROOT:-/opt/fex-emu}"
ROOTFS_PARENT="${FEX_DATA_ROOT}/RootFS"
PROFILE_D="/etc/profile.d/fex-emu.sh"

if ! command -v FEXRootFSFetcher >/dev/null 2>&1 && [ ! -x /usr/bin/FEXRootFSFetcher ]; then
  echo "NC_MP_STATUS=error missing FEXRootFSFetcher install=fex-emu"
  echo "ERROR: FEXRootFSFetcher not found — install fex-emu first" >&2
  echo "NC_MP_STATUS=done id=fex-rootfs exit=1"
  exit 1
fi

# Extract tools (FUSE not required under proot)
if ! command -v fsck.erofs >/dev/null 2>&1; then
  echo "NC_MP_STATUS=apt_install pkgs=erofs-utils"
  nc_mp_apt_install erofs-utils || true
fi
if ! command -v fsck.erofs >/dev/null 2>&1; then
  echo "NC_MP_STATUS=error missing fsck.erofs"
  echo "ERROR: erofs-utils (fsck.erofs) required to extract RootFS without FUSE" >&2
  echo "NC_MP_STATUS=done id=fex-rootfs exit=1"
  exit 1
fi

if command -v df >/dev/null 2>&1; then
  free_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
  # ~4 GiB free for download + extract
  if [ -n "${free_kb:-}" ] && [ "$free_kb" -lt 4000000 ]; then
    echo "NC_MP_STATUS=error low_disk free_kb=$free_kb need_kb=4000000"
    echo "ERROR: need ~4 GiB free for FEX RootFS download+extract (have ${free_kb} KiB)" >&2
    echo "NC_MP_STATUS=done id=fex-rootfs exit=1"
    exit 1
  fi
fi

mkdir -p "$ROOTFS_PARENT"

# Prefer XDG path under /opt so FEXRootFSFetcher writes where we expect
export XDG_DATA_HOME="${FEX_DATA_ROOT}"
# Some FEX builds use ~/.local/share/fex-emu; force HOME for fetcher consistency
export HOME="${FEX_DATA_ROOT}/home"
mkdir -p "$HOME"

find_extracted_rootfs() {
  # Prefer a directory that looks extracted (has bin/ or usr/)
  local d
  for d in "$ROOTFS_PARENT"/*/ "$HOME/.local/share/fex-emu/RootFS"/*/ \
           "${FEX_DATA_ROOT}/fex-emu/RootFS"/*/ \
           /root/.local/share/fex-emu/RootFS/*/ \
           "${FLUX_HOME}/.local/share/fex-emu/RootFS"/*/; do
    [ -d "$d" ] || continue
    if [ -d "${d}usr" ] || [ -d "${d}bin" ] || [ -d "${d}lib" ] || [ -d "${d}etc" ]; then
      echo "${d%/}"
      return 0
    fi
  done
  return 1
}

find_ero() {
  local f
  for f in "$ROOTFS_PARENT"/*.ero \
           "$HOME/.local/share/fex-emu/RootFS"/*.ero \
           "${FEX_DATA_ROOT}/fex-emu/RootFS"/*.ero \
           /root/.local/share/fex-emu/RootFS/*.ero \
           "${FLUX_HOME}/.local/share/fex-emu/RootFS"/*.ero; do
    [ -f "$f" ] || continue
    echo "$f"
    return 0
  done
  return 1
}

EXISTING="$(find_extracted_rootfs 2>/dev/null || true)"
if [ -n "${EXISTING:-}" ]; then
  echo "NC_MP_STATUS=skip already_extracted path=$EXISTING"
  ROOTFS_DIR="$EXISTING"
else
  ERO="$(find_ero 2>/dev/null || true)"
  if [ -z "${ERO:-}" ]; then
    echo "NC_MP_STATUS=download rootfs via=FEXRootFSFetcher"
    # Non-interactive fetch; may print progress to stdout
    if ! FEXRootFSFetcher --assume-yes --distro-list-first; then
      echo "NC_MP_STATUS=warn FEXRootFSFetcher_exit_nonzero trying_locate"
    fi
    ERO="$(find_ero 2>/dev/null || true)"
  else
    echo "NC_MP_STATUS=skip download already_have_ero path=$ERO"
  fi

  if [ -z "${ERO:-}" ]; then
    echo "NC_MP_STATUS=error rootfs_download_failed"
    echo "ERROR: RootFS image not found after FEXRootFSFetcher. Run FEXRootFSFetcher manually." >&2
    echo "NC_MP_STATUS=done id=fex-rootfs exit=1"
    exit 1
  fi

  # Normalize: ensure .ero lives under ROOTFS_PARENT
  base="$(basename "$ERO" .ero)"
  if [ "$(dirname "$ERO")" != "$ROOTFS_PARENT" ]; then
    echo "NC_MP_STATUS=copy ero -> $ROOTFS_PARENT"
    mkdir -p "$ROOTFS_PARENT"
    cp -n "$ERO" "$ROOTFS_PARENT/" 2>/dev/null || cp "$ERO" "$ROOTFS_PARENT/"
    ERO="$ROOTFS_PARENT/$(basename "$ERO")"
  fi

  EXTRACT_DIR="${ROOTFS_PARENT}/${base}"
  if [ ! -d "$EXTRACT_DIR/usr" ] && [ ! -d "$EXTRACT_DIR/lib" ]; then
    echo "NC_MP_STATUS=extract ero=$ERO dest=$EXTRACT_DIR"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    fsck.erofs --extract="$EXTRACT_DIR" "$ERO"
  fi

  ROOTFS_DIR="$EXTRACT_DIR"
  if [ ! -d "$ROOTFS_DIR" ]; then
    echo "NC_MP_STATUS=error extract_failed"
    echo "ERROR: extract produced no directory at $EXTRACT_DIR" >&2
    echo "NC_MP_STATUS=done id=fex-rootfs exit=1"
    exit 1
  fi
fi

# World-readable so flux can use it
chmod -R a+rX "$FEX_DATA_ROOT" 2>/dev/null || true

# Profile for all shells
echo "NC_MP_STATUS=profile path=$PROFILE_D"
cat >"$PROFILE_D" <<EOF
# NativeCode marketplace: FEX-Emu RootFS (aarch64 host)
export FEX_ROOTFS="${ROOTFS_DIR}"
EOF
chmod 644 "$PROFILE_D"

# Also pin for flux interactive shells
if [ -d "$FLUX_HOME" ]; then
  BASHRC="${FLUX_HOME}/.bashrc"
  touch "$BASHRC"
  if ! grep -q 'FEX_ROOTFS=' "$BASHRC" 2>/dev/null; then
    {
      echo ""
      echo "# NativeCode marketplace FEX RootFS"
      echo "export FEX_ROOTFS=\"${ROOTFS_DIR}\""
    } >>"$BASHRC"
  else
    # Refresh line
    if grep -q 'NativeCode marketplace FEX RootFS' "$BASHRC" 2>/dev/null; then
      sed -i "s|export FEX_ROOTFS=.*|export FEX_ROOTFS=\"${ROOTFS_DIR}\"|" "$BASHRC" || true
    fi
  fi
  chown -R "${FLUX_USER}:${FLUX_USER}" "$BASHRC" 2>/dev/null || true
fi

# Symlink convenience for flux XDG path
mkdir -p "${FLUX_HOME}/.local/share/fex-emu"
ln -sfn "$ROOTFS_DIR" "${FLUX_HOME}/.local/share/fex-emu/RootFS-current" 2>/dev/null || true
chown -R "${FLUX_USER}:${FLUX_USER}" "${FLUX_HOME}/.local" 2>/dev/null || true

# Smoke test if FEX present
echo "NC_MP_STATUS=verify"
if command -v FEX >/dev/null 2>&1; then
  if FEX_ROOTFS="$ROOTFS_DIR" FEX /usr/bin/uname -m 2>/dev/null | grep -q x86_64; then
    echo "NC_MP_STATUS=verify ok uname=x86_64"
  else
    echo "NC_MP_STATUS=warn verify_uname_unexpected (RootFS installed; manual check later)"
  fi
fi

nc_mp_emit_size "$ROOTFS_DIR"
nc_mp_emit_paths "$ROOTFS_DIR" "$PROFILE_D"
echo "NC_MP_STATUS=done id=fex-rootfs exit=0"
echo "INFO: export FEX_ROOTFS=${ROOTFS_DIR}"
echo "INFO: example: FEX_ROOTFS=${ROOTFS_DIR} FEX /usr/bin/uname -m"

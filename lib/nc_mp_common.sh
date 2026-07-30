#!/usr/bin/env bash
# Shared helpers for NativeCode marketplace package scripts.
# shellcheck disable=SC2034

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

nc_mp_require_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "NC_MP_STATUS=error need_root"
    echo "ERROR: marketplace scripts must run as root inside guest" >&2
    exit 1
  fi
}

nc_mp_pkg_ok() {
  dpkg -s "$1" >/dev/null 2>&1
}

nc_mp_apt_update() {
  echo "NC_MP_STATUS=apt_update"
  apt-get update -qq
}

nc_mp_apt_install() {
  local need=() p
  for p in "$@"; do
    nc_mp_pkg_ok "$p" || need+=("$p")
  done
  if [ "${#need[@]}" -eq 0 ]; then
    echo "NC_MP_STATUS=skip already_installed pkgs=$*"
    return 0
  fi
  echo "NC_MP_STATUS=apt_install pkgs=${need[*]}"
  nc_mp_apt_update
  apt-get install -y --no-install-recommends "${need[@]}"
}

nc_mp_apt_remove() {
  local have=() p
  for p in "$@"; do
    nc_mp_pkg_ok "$p" && have+=("$p")
  done
  if [ "${#have[@]}" -eq 0 ]; then
    echo "NC_MP_STATUS=skip not_installed pkgs=$*"
    return 0
  fi
  echo "NC_MP_STATUS=apt_remove pkgs=${have[*]}"
  apt-get remove -y "${have[@]}" || true
  apt-get autoremove -y || true
}

nc_mp_download() {
  local url="$1" dest="$2"
  echo "NC_MP_STATUS=download url=$url"
  mkdir -p "$(dirname "$dest")"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$dest" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$dest" "$url"
  else
    echo "NC_MP_STATUS=error no_curl_wget"
    exit 1
  fi
}

nc_mp_emit_size() {
  local total=0 p s
  for p in "$@"; do
    if [ -e "$p" ]; then
      s=$(du -sb "$p" 2>/dev/null | awk '{print $1}')
      total=$((total + ${s:-0}))
    fi
  done
  if [ "$total" -eq 0 ]; then
    # fallback: sum dpkg Installed-Size for remaining args if they look like package names
    :
  fi
  echo "NC_MP_SIZE_BYTES=$total"
}

nc_mp_emit_size_pkgs() {
  local total=0 p kib
  for p in "$@"; do
    if nc_mp_pkg_ok "$p"; then
      kib=$(dpkg-query -W -f='${Installed-Size}' "$p" 2>/dev/null || echo 0)
      total=$((total + kib * 1024))
    fi
  done
  echo "NC_MP_SIZE_BYTES=$total"
}

nc_mp_emit_paths() {
  local IFS=':'
  echo "NC_MP_PATHS=$*"
}

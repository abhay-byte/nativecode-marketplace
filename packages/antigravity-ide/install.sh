#!/usr/bin/env bash
# Install Google Antigravity IDE from the official linux-arm tarball (antigravity.google).
# Debian aarch64 proot/chroot. Native AArch64 Electron — needs a Graphical Desktop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=antigravity-ide"

AG_BUILD="${AG_BUILD:-2.1.1-6123990880747520}"
AG_PREFIX="${AG_PREFIX:-/opt/antigravity-ide}"
AG_CACHE="${AG_CACHE:-/var/cache/nc-mp}"
AG_TARBALL="$AG_CACHE/antigravity-ide-${AG_BUILD}-linux-arm.tar.gz"
AG_URL="${AG_URL:-https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${AG_BUILD}/linux-arm/Antigravity%20IDE.tar.gz}"

if [ -x "$AG_PREFIX/antigravity-ide" ] || command -v antigravity-ide >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size "$AG_PREFIX"
  nc_mp_emit_paths "$AG_PREFIX/antigravity-ide" /usr/local/bin/antigravity-ide
  echo "NC_MP_STATUS=done id=antigravity-ide exit=0"
  exit 0
fi

if [ "$(uname -m)" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$(uname -m) need=aarch64"
  echo "ERROR: the Antigravity tarball is built for arm64 only" >&2
  echo "NC_MP_STATUS=done id=antigravity-ide exit=1"
  exit 1
fi

# Runtime libs required by the binary (readelf NEEDED on antigravity-ide).
echo "NC_MP_STATUS=apt_deps"
nc_mp_apt_install \
  libgtk-3-0 libnss3 libnspr4 libasound2 libatk-bridge2.0-0 libatk1.0-0 \
  libatspi2.0-0 libcairo2 libcups2 libdbus-1-3 libgbm1 libglib2.0-0 libpango-1.0-0 \
  libexpat1 libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 \
  libxkbcommon0 libudev1 libsecret-1-0 libxss1 libxtst6 libnotify4 xdg-utils

# Verify the gzip stream end-to-end (catches truncated downloads).
verify_tarball() {
  [ -s "$AG_TARBALL" ] && gzip -t "$AG_TARBALL" >/dev/null 2>&1
}

download_antigravity() {
  echo "NC_MP_STATUS=download url=$AG_URL"
  rm -f "$AG_TARBALL"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 5 --retry-all-errors --retry-delay 2 -o "$AG_TARBALL" "$AG_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries 5 -O "$AG_TARBALL" "$AG_URL"
  else
    echo "NC_MP_STATUS=error no_curl_wget"
    echo "NC_MP_STATUS=done id=antigravity-ide exit=1"
    exit 1
  fi
}

# Download the tarball; retry up to 3 times if it is truncated or otherwise invalid.
attempt=0
while [ "$attempt" -lt 3 ]; do
  if [ ! -f "$AG_TARBALL" ] || ! verify_tarball; then
    download_antigravity
  fi
  if verify_tarball; then
    break
  fi
  attempt=$((attempt + 1))
  echo "NC_MP_STATUS=warn download_retry attempt=$attempt"
done

if ! verify_tarball; then
  echo "NC_MP_STATUS=error corrupt_download url=$AG_URL"
  echo "ERROR: downloaded tarball failed verification — check network/disk and retry." >&2
  echo "NC_MP_STATUS=done id=antigravity-ide exit=1"
  exit 1
fi

echo "NC_MP_STATUS=extract dest=$AG_PREFIX"
rm -rf "$AG_PREFIX"
mkdir -p "$(dirname "$AG_PREFIX")" "$AG_PREFIX"
tar -xzf "$AG_TARBALL" -C "$AG_PREFIX" --strip-components=1

if [ ! -x "$AG_PREFIX/antigravity-ide" ]; then
  echo "NC_MP_STATUS=error extract_failed binary_missing"
  echo "ERROR: antigravity-ide binary not found after extraction" >&2
  echo "NC_MP_STATUS=done id=antigravity-ide exit=1"
  exit 1
fi

chmod 0755 "$AG_PREFIX/chrome-sandbox" 2>/dev/null || true
ln -sf "$AG_PREFIX/antigravity-ide" /usr/local/bin/antigravity-ide

# Desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/antigravity-ide.desktop <<'EOF'
[Desktop Entry]
Name=Antigravity IDE
Comment=Google Antigravity IDE
GenericName=Text Editor
Exec=/usr/local/bin/antigravity-ide %F
Icon=antigravity-ide
Type=Application
StartupNotify=false
StartupWMClass=Antigravity
Categories=Development;IDE;TextEditor;
MimeType=x-scheme-handler/antigravity;
EOF
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi

# Icon
if [ -f "$AG_PREFIX/resources/app/resources/linux/code.png" ]; then
  mkdir -p /usr/share/icons/hicolor/256x256/apps
  cp "$AG_PREFIX/resources/app/resources/linux/code.png" \
    /usr/share/icons/hicolor/256x256/apps/antigravity-ide.png
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
  fi
fi

nc_mp_emit_size "$AG_PREFIX"
nc_mp_emit_paths "$AG_PREFIX/antigravity-ide" /usr/local/bin/antigravity-ide
echo "NC_MP_STATUS=hint sandbox=no_sandbox"
echo "INFO: run 'antigravity-ide --no-sandbox' if the Chromium sandbox fails under proot/chroot."
echo "NC_MP_STATUS=done id=antigravity-ide exit=0"

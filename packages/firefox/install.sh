#!/usr/bin/env bash
# Install Mozilla Firefox from the official linux-aarch64 release tarball (download.mozilla.org).
# Debian aarch64 proot/chroot. Native AArch64 — needs a Graphical Desktop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../lib/nc_mp_common.sh" 2>/dev/null || . /tmp/nc-mp/lib/nc_mp_common.sh

nc_mp_require_root
echo "NC_MP_STATUS=start id=firefox"

FF_PREFIX="${FF_PREFIX:-/opt/firefox}"
FF_CACHE="${FF_CACHE:-/var/cache/nc-mp}"
FF_TARBALL="$FF_CACHE/firefox-latest-linux-aarch64.tar.xz"
FF_URL="${FF_URL:-https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64-aarch64&lang=en-US}"

if [ -x "$FF_PREFIX/firefox" ] || command -v firefox >/dev/null 2>&1; then
  echo "NC_MP_STATUS=skip already_installed"
  nc_mp_emit_size "$FF_PREFIX"
  nc_mp_emit_paths "$FF_PREFIX/firefox" /usr/local/bin/firefox
  echo "NC_MP_STATUS=done id=firefox exit=0"
  exit 0
fi

if [ "$(uname -m)" != "aarch64" ]; then
  echo "NC_MP_STATUS=error arch=$(uname -m) need=aarch64"
  echo "ERROR: the Firefox tarball is built for arm64 only" >&2
  echo "NC_MP_STATUS=done id=firefox exit=1"
  exit 1
fi

# Runtime libs required by Firefox on Debian.
echo "NC_MP_STATUS=apt_deps"
nc_mp_apt_install \
  libgtk-3-0 libglib2.0-0 libpango-1.0-0 libcairo2 libfreetype6 libfontconfig1 \
  libnspr4 libnss3 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxdamage1 libxext6 \
  libxfixes3 libxrandr2 libxrender1 libxcursor1 libxi6 libxt6 libxkbcommon0 libxtst6 \
  libxss1 libasound2 libpulse0 libgbm1 libcups2 libatspi2.0-0 libatk1.0-0 \
  libatk-bridge2.0-0 libsecret-1-0 libharfbuzz0b libudev1 xdg-utils

# Verify the xz stream end-to-end (catches truncated downloads).
verify_tarball() {
  [ -s "$FF_TARBALL" ] && xz -t "$FF_TARBALL" >/dev/null 2>&1
}

download_firefox() {
  echo "NC_MP_STATUS=download url=$FF_URL"
  rm -f "$FF_TARBALL"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 5 --retry-all-errors --retry-delay 2 -o "$FF_TARBALL" "$FF_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries 5 -O "$FF_TARBALL" "$FF_URL"
  else
    echo "NC_MP_STATUS=error no_curl_wget"
    echo "NC_MP_STATUS=done id=firefox exit=1"
    exit 1
  fi
}

# Download the tarball; retry up to 3 times if it is truncated or otherwise invalid.
attempt=0
while [ "$attempt" -lt 3 ]; do
  if [ ! -f "$FF_TARBALL" ] || ! verify_tarball; then
    download_firefox
  fi
  if verify_tarball; then
    break
  fi
  attempt=$((attempt + 1))
  echo "NC_MP_STATUS=warn download_retry attempt=$attempt"
done

if ! verify_tarball; then
  echo "NC_MP_STATUS=error corrupt_download url=$FF_URL"
  echo "ERROR: downloaded tarball failed verification — check network/disk and retry." >&2
  echo "NC_MP_STATUS=done id=firefox exit=1"
  exit 1
fi

echo "NC_MP_STATUS=extract dest=$FF_PREFIX"
rm -rf "$FF_PREFIX"
mkdir -p "$(dirname "$FF_PREFIX")" "$FF_PREFIX"
tar -xJf "$FF_TARBALL" -C "$FF_PREFIX" --strip-components=1

if [ ! -x "$FF_PREFIX/firefox-bin" ]; then
  echo "NC_MP_STATUS=error extract_failed binary_missing"
  echo "ERROR: firefox-bin not found after extraction" >&2
  echo "NC_MP_STATUS=done id=firefox exit=1"
  exit 1
fi

ln -sf "$FF_PREFIX/firefox" /usr/local/bin/firefox

# Desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/firefox.desktop <<'EOF'
[Desktop Entry]
Name=Firefox
Comment=Mozilla Firefox
GenericName=Web Browser
Exec=/usr/local/bin/firefox %U
Icon=firefox
Terminal=false
Type=Application
StartupNotify=true
Categories=Network;WebBrowser;Development;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi

# Icon
if [ -f "$FF_PREFIX/browser/chrome/icons/default/default128.png" ]; then
  mkdir -p /usr/share/icons/hicolor/128x128/apps
  cp "$FF_PREFIX/browser/chrome/icons/default/default128.png" \
    /usr/share/icons/hicolor/128x128/apps/firefox.png
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
  fi
fi

nc_mp_emit_size "$FF_PREFIX"
nc_mp_emit_paths "$FF_PREFIX/firefox" /usr/local/bin/firefox
echo "NC_MP_STATUS=done id=firefox exit=0"
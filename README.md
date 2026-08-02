# NativeCode Marketplace

Public catalog + install/uninstall scripts for [NativeCode](https://github.com/abhay-byte/nativecode-ai) Debian guests (**proot** and **chroot**).

## Layout

```text
catalog.json                 # App downloads this first
lib/nc_mp_common.sh          # Shared helpers (sourced by package scripts)
packages/<id>/
  package.json
  install.sh                 # Installs THIS package only
  uninstall.sh               # Removes THIS package only (not deps)
```

## Contract

1. One package = one install + one uninstall script.
2. **Never** install sibling marketplace products inside a script — declare `deps` in catalog; the app runner installs them first.
3. Scripts run as **root inside the guest**.
4. Idempotent: re-run is safe.
5. Emit progress lines:

```text
NC_MP_STATUS=start id=<id>
NC_MP_STATUS=done id=<id> exit=0
NC_MP_SIZE_BYTES=<n>
NC_MP_PATHS=/opt/foo:/usr/local/bin/foo
```

## Catalog URL

```text
https://raw.githubusercontent.com/abhay-byte/nativecode-marketplace/main/catalog.json
```

## Packages

| id | kind | notes |
|----|------|-------|
| mesa-utils | component | apt |
| box64 | component | apt or upstream |
| fex-build-deps | component | clang/cmake/ninja/cross tools for FEX source build |
| fex-emu | component | FEX binaries (apt or source); deps → fex-build-deps |
| fex-rootfs | component | x86 RootFS download+extract (proot-safe); deps → fex-emu |
| fex-stack | component | meta: full chain via fex-rootfs (recommended one-click) |
| glmark2 | app | X11; deps mesa-utils |
| blender | app | experimental on aarch64 |
| zcode | app | ZCode desktop (ARM64 deb); X11, `--no-sandbox` on proot |
| cursor | app | Cursor AI editor (ARM64 deb); X11, `--no-sandbox` on proot |
| antigravity-ide | app | Google Antigravity IDE (ARM64 tarball); X11, `--no-sandbox` on proot |

### FEX on proot (aarch64)

Install order (or install `fex-stack` once):

1. **fex-build-deps** — ~120 MiB toolchain  
2. **fex-emu** — apt if available, else source build (~hours, multi-GB peak)  
3. **fex-rootfs** — ~1.3 GiB download + extract to `/opt/fex-emu/RootFS`, sets `FEX_ROOTFS`

Proot notes: no FUSE → always extract; no binfmt → invoke `FEX` directly.

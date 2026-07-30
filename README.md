# NativeCode Marketplace

Public catalog + install/uninstall scripts for [NativeCode](https://github.com/abhay-byte) Debian guests (**proot** and **chroot**).

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

## Demo packages

| id | kind | notes |
|----|------|-------|
| mesa-utils | component | apt |
| box64 | component | apt or upstream |
| fex-emu | component | experimental |
| glmark2 | app | X11; deps mesa-utils |
| blender | app | experimental on aarch64 |

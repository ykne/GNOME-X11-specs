# GNOME-X11

Restores GNOME X11 (Xorg) session support into **current** GNOME (50.x),
for hardware or environments that can't run Wayland. Unlike other
X11-restoration Copr projects, this patches and rebuilds current GNOME
rather than freezing at the last X11-capable GNOME release.

## Install

```
sudo dnf copr enable ykner/GNOME-X11
sudo dnf install mutter gnome-shell gnome-control-center gnome-session gdm gnome-shell-extensions
```

If these packages are already installed from stock Fedora, `sudo dnf
upgrade` picks up the restored versions automatically once the repo is
enabled — no need to reinstall.

After installing, select **"GNOME on Xorg"** at the GDM login screen (or
set it as your account's default session) to get a real X11 session
instead of Wayland.

## What's restored

Six packages, patched against Fedora's GNOME 50.x baseline:

- `mutter`
- `gnome-shell`
- `gnome-control-center`
- `gnome-session` (restores the `xsession` subpackage)
- `gdm` (restores X11 greeter support)
- `gnome-shell-extensions`

## Repo layout

This repo hosts local/CI build tooling (`scripts/`, `.github/workflows/`)
for building all 6 packages into a single local repo. Each package's
actual patched source lives in its own fork, and each fork owns its own
spec + patches under `.copr/`:

- github.com/ykne/mutter
- github.com/ykne/gnome-shell
- github.com/ykne/gnome-control-center
- github.com/ykne/gnome-session
- github.com/ykne/gdm
- github.com/ykne/gnome-shell-extensions

The real [Copr project](https://copr.fedorainfracloud.org/coprs/ykner/GNOME-X11/)
builds directly from each fork's `.copr/` — any push there triggers an
automatic rebuild via Copr's native webhook. This repo's own `SPECS/`/
`SOURCES/` are kept only as a historical record of the original spec
fixes and are no longer the live source.

## Source

Fedora Copr project: https://copr.fedorainfracloud.org/coprs/ykner/GNOME-X11/

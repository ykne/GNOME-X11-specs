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

## Known limitations

### GTK4 apps can crash on software rendering (no GPU / no 3D acceleration)

On hardware or VMs without GPU acceleration, GTK4 apps render via Mesa's
software Vulkan driver (Lavapipe) under X11, and can crash there with a
segfault inside `libvulkan_lvp.so` (`util_fill_rect` / `rasterize_scene`),
usually triggered by a resize (maximize/unmaximize is a reliable trigger,
but not the only one). This has been observed across multiple unrelated
GTK4 apps (`gnome-text-editor`, `gnome-control-center`, `ptyxis`,
`simple-scan`) on multiple independent VMs — it is **not specific to any
one app**, and does **not** happen under Wayland on the same hardware.

This is a Mesa/Lavapipe bug, not something in this project's own patches
— it sits entirely outside the mutter/gnome-shell/X11 restoration code
this repo ships. If you hit it:

- **Workaround:** force GTK4 off the Vulkan renderer for the affected
  app: `GSK_RENDERER=gl <app>` (or `GSK_RENDERER=cairo <app>`).
- If you have real GPU acceleration available, this issue does not
  appear to reproduce — it's specific to the software (Lavapipe) path.

Not yet root-caused upstream in Mesa; tracked for follow-up.

### Clicking a window's own maximize button can briefly stop other clicks from working

Clicking certain window-decoration buttons (confirmed for GTK4's
header-bar maximize button) can leave clicks elsewhere on screen (the
top bar, right-click on the desktop, etc.) unresponsive for up to 2
seconds afterward, before recovering on their own with no action needed.
This is a real X11 protocol interaction, not a bug in the restored
code: GTK4 establishes its own device grab to track the click through to
release, which — correctly, per normal X11 grab rules — delivers that
release exclusively to the GTK4 app and never to the desktop itself.
Mutter has no way to know in advance that this will happen, so it
briefly treats the click as still "in progress" until a safety timeout
clears it.

If you hit this, just wait a couple of seconds and click again — no
restart or workaround needed. A window's own minimize button is
unaffected (recovers immediately).

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

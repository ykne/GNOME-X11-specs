#!/bin/bash
# One-time (idempotent) setup of the real ykner/GNOME-X11 Copr project:
# creates the project if missing, then registers each of the 6 packages
# as an SCM/make_srpm source pointed at its own fork, with Copr's native
# webhook auto-rebuild enabled. Each fork owns its own spec+patches under
# .copr/ (see .copr/Makefile in each fork) - no separate specs repo is
# consulted at build time, so every package gets full native webhook
# coverage with no external trigger and no extra secret.
#
# Usage: copr-setup.sh
# Requires: copr-cli authenticated as the project owner (~/.config/copr).

set -euo pipefail

PROJECT=GNOME-X11
CHROOT=fedora-44-x86_64

declare -A PKG_BRANCH=(
        [mutter]=x11-restore-50.4
        [gnome-shell]=x11-restore-50.4
        [gnome-control-center]=x11-restore-50.4
        [gnome-session]=x11-restore-50.1
        [gdm]=x11-restore-50.2
        [gnome-shell-extensions]=x11-restore-50.3
)

if ! copr-cli list "$(copr-cli whoami)" 2>/dev/null | grep -qx "$PROJECT"; then
        echo "=== creating project $PROJECT ==="
        copr-cli create "$PROJECT" \
                --chroot "$CHROOT" \
                --description "GNOME X11 session support restored into current GNOME (50.x)" \
                --instructions "dnf copr enable $(copr-cli whoami)/$PROJECT" \
                --enable-net on \
                --unlisted-on-hp on
else
        echo "=== project $PROJECT already exists, skipping create ==="
fi

for pkg in "${!PKG_BRANCH[@]}"; do
        echo "=== registering package $pkg (branch ${PKG_BRANCH[$pkg]}) ==="
        copr-cli add-package-scm "$PROJECT" \
                --name "$pkg" \
                --clone-url "https://github.com/ykne/$pkg.git" \
                --commit "${PKG_BRANCH[$pkg]}" \
                --method make_srpm \
                --spec ".copr/$pkg.spec" \
                --webhook-rebuild on
done

echo ""
echo "All 6 packages registered in $PROJECT. Next: populate each fork's"
echo ".copr/ (spec + patches + Makefile) before triggering the first build."

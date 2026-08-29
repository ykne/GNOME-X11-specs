#!/bin/bash
# Fetch each package's baseline Fedora packaging (spec + any local
# Source/Patch files it references, excluding Source0 - that's always
# the stock upstream tarball, which make-source-tarball.sh replaces with
# our own restored source) from the local dist-git clones' f44 branch.
#
# This is a genuine external input, not something build-all.sh or
# make-source-tarball.sh can regenerate on their own - run this once to
# bootstrap a fresh copr/ topdir (or after intentionally re-syncing to a
# newer Fedora spec revision).
#
# Usage: fetch-baseline-specs.sh [package ...]  (default: all 6)

set -euo pipefail

DISTGIT="${DISTGIT:-$HOME/gnome-x11-build/dist-git}"
TOPDIR="${TOPDIR:-$HOME/gnome-x11-build/copr}"
BRANCH=f44

ALL_PACKAGES=(mutter gnome-shell gnome-control-center gnome-session gdm gnome-shell-extensions)

if [[ $# -gt 0 ]]; then
        packages=("$@")
else
        packages=("${ALL_PACKAGES[@]}")
fi

mkdir -p "$TOPDIR"/{SPECS,SOURCES}

for pkg in "${packages[@]}"; do
        repo="$DISTGIT/$pkg"
        if [[ ! -d "$repo/.git" ]]; then
                echo "error: no dist-git clone at $repo" >&2
                exit 1
        fi

        echo "=== $pkg ==="
        git -C "$repo" show "$BRANCH:$pkg.spec" > "$TOPDIR/SPECS/$pkg.spec"

        # every Source1+/Patch entry that names a plain local file (not a
        # URL) - Source0 is always the stock upstream tarball, skipped
        # deliberately
        while read -r kind file; do
                [[ "$file" == http* ]] && continue
                [[ "$kind" == "Source0:" ]] && continue
                echo "  fetching $file"
                git -C "$repo" show "$BRANCH:$file" > "$TOPDIR/SOURCES/$file"
        done < <(grep -oE '^(Source[0-9]*|Patch[0-9]*): *\S+' "$TOPDIR/SPECS/$pkg.spec" \
                  | sed -E 's/^([A-Za-z0-9]+:) *(\S+)/\1 \2/')
done

echo ""
echo "Baseline specs + patches fetched into $TOPDIR/SPECS and $TOPDIR/SOURCES"

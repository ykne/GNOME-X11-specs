#!/bin/bash
# Build a git-archive source tarball for one of this project's restored
# packages, vendoring in any gitignored-but-required meson subprojects
# that `git archive` alone would silently drop.
#
# Usage: make-source-tarball.sh <package> [git-ref]
#   package  - one of: mutter gnome-shell gnome-control-center
#              gnome-session gdm gnome-shell-extensions
#   git-ref  - defaults to HEAD of the package's own x11-restore-50.x
#              branch (checked out in the rebase/<package> tree)
#
# Output: copr/SOURCES/<package>-<version>.tar.xz - a single shared
# rpmbuild %_topdir (copr/{SPECS,SOURCES,SRPMS,RPMS,BUILD}) covering all
# 6 restored packages, so RPMS/ can become one local multi-package repo.
# Same mechanism regardless of how the SRPM eventually gets built or
# published (manual rpmbuild+mock today, COPR SCM later) - see
# project_x11_restoration_fork_setup.md.

set -euo pipefail

REBASE_ROOT="${REBASE_ROOT:-$HOME/gnome-x11-build/rebase}"
TOPDIR="${TOPDIR:-$HOME/gnome-x11-build/copr}"
SCRATCH_ROOT=${TMPDIR:-/tmp}/gnome-x11-source-tarballs

# version used in the tarball's top-level directory name and filename -
# must match each package's own dist-git spec %{version}
declare -A PKG_VERSION=(
        [mutter]=50.4
        [gnome-shell]=50.4
        [gnome-control-center]=50.4
        [gnome-session]=50.1
        [gdm]=50.2
        [gnome-shell-extensions]=50.3
)

# subproject directories that are gitignored but required at build time
# (present on disk in the rebase tree, dropped by `git archive` unless
# copied in separately) - space-separated, empty if none needed
declare -A PKG_VENDOR_SUBPROJECTS=(
        [mutter]=""
        [gnome-shell]="gvc jasmine-gjs"
        [gnome-control-center]="gvc libgxdp"
        [gnome-session]=""
        [gdm]=""
        [gnome-shell-extensions]=""
)

pkg="${1:?usage: $0 <package> [git-ref]}"

if [[ -z "${PKG_VERSION[$pkg]+set}" ]]; then
        echo "error: unknown package '$pkg' - known packages: ${!PKG_VERSION[*]}" >&2
        exit 1
fi

version="${PKG_VERSION[$pkg]}"
src_repo="$REBASE_ROOT/$pkg"

if [[ ! -d "$src_repo/.git" ]]; then
        echo "error: $src_repo is not a git repo" >&2
        exit 1
fi

cd "$src_repo"
ref="${2:-HEAD}"
hash=$(git rev-parse --short=8 "$ref")

workdir="$SCRATCH_ROOT/$pkg-$hash"
rm -rf "$workdir"
mkdir -p "$workdir/$pkg-$version"

git archive "$ref" | tar -x -C "$workdir/$pkg-$version"

for sub in ${PKG_VENDOR_SUBPROJECTS[$pkg]}; do
        if [[ ! -d "subprojects/$sub" ]]; then
                echo "error: $pkg needs subprojects/$sub vendored but it's not present on disk in $src_repo - run 'meson subprojects download' there first" >&2
                exit 1
        fi
        cp -r "subprojects/$sub" "$workdir/$pkg-$version/subprojects/"
done

out_dir="$TOPDIR/SOURCES"
mkdir -p "$out_dir"
tarball="$out_dir/$pkg-$version.tar.xz"

tar -cJf "$tarball" -C "$workdir" "$pkg-$version"
rm -rf "$workdir"

echo "wrote $tarball (from $pkg @ $hash)"

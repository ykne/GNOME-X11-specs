#!/bin/bash
# End-to-end local rebuild of all 6 GNOME-X11-restoration packages into
# one shared rpmbuild %_topdir, producing a single installable local repo.
#
# For each package: regenerate its source tarball from the fork's current
# HEAD (make-source-tarball.sh), stamp the spec with a git-hash Release
# (per feedback_gnome_shell_build_gotchas.md's standing convention),
# `rpmbuild -bs`, then `mock --rebuild` into a scratch resultdir and copy
# the built RPMs into copr/RPMS/<arch>/. Once all 6 are done, runs
# `createrepo_c` over copr/RPMS so it's a real installable yum repo.
#
# Usage: build-all.sh [package ...]
#   No arguments: builds all 6 packages, in order.
#   One or more package names: builds only those (still runs createrepo_c
#   over the whole RPMS/ tree afterward, since it's a shared repo).
#
# Safe to re-run: each step is idempotent (regenerates its own inputs),
# and rpmbuild/mock overwrite same-named outputs cleanly.

set -euo pipefail

REBASE_ROOT="${REBASE_ROOT:-$HOME/gnome-x11-build/rebase}"
TOPDIR="${TOPDIR:-$HOME/gnome-x11-build/copr}"
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SCRATCH_ROOT=${TMPDIR:-/tmp}/gnome-x11-build-all
MOCK_CHROOT=fedora-44-x86_64

# physical core count, not nproc's logical thread count - see
# feedback_gnome_shell_build_gotchas.md gotcha 5
PHYSICAL_CORES=$(lscpu | awk -F: '/^Core\(s\) per socket/{c=$2} /^Socket\(s\)/{s=$2} END{gsub(/ /,"",c); gsub(/ /,"",s); print c*s}')

declare -A PKG_VERSION=(
        [mutter]=50.4
        [gnome-shell]=50.4
        [gnome-control-center]=50.4
        [gnome-session]=50.1
        [gdm]=50.2
        [gnome-shell-extensions]=50.3
)

ALL_PACKAGES=(mutter gnome-shell gnome-control-center gnome-session gdm gnome-shell-extensions)

if [[ $# -gt 0 ]]; then
        packages=("$@")
else
        packages=("${ALL_PACKAGES[@]}")
fi

mkdir -p "$TOPDIR"/{SPECS,SOURCES,SRPMS,RPMS/x86_64,RPMS/noarch,BUILD}

# --addrepo (added to every mock invocation below) needs valid repodata to
# exist from the very first package's build, even if RPMS/ is still empty -
# dnf5's chroot-init "upgrade" step fails hard on a configured repo with no
# repodata/repomd.xml at all, rather than skipping an empty one.
createrepo_c "$TOPDIR/RPMS" > /dev/null

for pkg in "${packages[@]}"; do
        if [[ -z "${PKG_VERSION[$pkg]+set}" ]]; then
                echo "error: unknown package '$pkg' - known: ${ALL_PACKAGES[*]}" >&2
                exit 1
        fi

        version="${PKG_VERSION[$pkg]}"
        echo ""
        echo "##### $pkg #####"

        echo "-- generating source tarball --"
        "$SCRIPT_DIR/make-source-tarball.sh" "$pkg"

        hash=$(git -C "$REBASE_ROOT/$pkg" rev-parse --short=8 HEAD)
        echo "-- stamping spec with git hash $hash --"
        sed "s/^Release:.*\$/Release:        1.g${hash}%{?dist}/" \
                "$TOPDIR/SPECS/$pkg.spec" > "$TOPDIR/SPECS/$pkg-gitrel.spec"

        echo "-- rpmbuild -bs --"
        rpmbuild -bs --define "_topdir $TOPDIR" "$TOPDIR/SPECS/$pkg-gitrel.spec"

        srpm=$(ls -t "$TOPDIR"/SRPMS/"$pkg"-"$version"-*.g"$hash"*.src.rpm | head -1)
        echo "-- srpm: $srpm --"

        resultdir="$SCRATCH_ROOT/$pkg-$hash"
        rm -rf "$resultdir"
        echo "-- mock --rebuild ($MOCK_CHROOT, -j$PHYSICAL_CORES, local repo addrepo'd) --"
        # --addrepo lets each package's builddep resolution prefer our own
        # already-built packages (e.g. gnome-shell needs mutter-devel) over
        # stock Fedora's same-version packages - Epoch: 1 (added to every
        # spec) is the primary tie-breaker, this is a second one for the
        # pkgconfig()-virtual-provide resolution path, which doesn't carry
        # epoch info in its capability version (see
        # feedback_gnome_shell_build_gotchas.md gotcha 2).
        mock -r "$MOCK_CHROOT" --define "_smp_mflags -j${PHYSICAL_CORES}" \
                --addrepo="file://$TOPDIR/RPMS" \
                --resultdir "$resultdir" --rebuild "$srpm"

        if grep -q "RPM build errors" "$resultdir/build.log" 2>/dev/null; then
                echo "error: $pkg build reported RPM build errors, see $resultdir/build.log" >&2
                exit 1
        fi

        echo "-- copying built RPMs into $TOPDIR/RPMS/<arch>/ --"
        shopt -s nullglob
        for rpm in "$resultdir"/*.x86_64.rpm; do
                cp -v "$rpm" "$TOPDIR/RPMS/x86_64/"
        done
        for rpm in "$resultdir"/*.noarch.rpm; do
                cp -v "$rpm" "$TOPDIR/RPMS/noarch/"
        done
        shopt -u nullglob

        echo "-- refreshing local repo metadata for subsequent packages --"
        createrepo_c "$TOPDIR/RPMS" > /dev/null

        echo "-- $pkg done --"
done

echo ""
echo "##### createrepo_c #####"
createrepo_c "$TOPDIR/RPMS"

echo ""
echo "All done. Local repo ready at $TOPDIR/RPMS"

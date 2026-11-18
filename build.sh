#!/bin/bash
# Build every package listed in PACKAGES, sign them, and make the signed repo db in out/.
# Runs as the build user on ArmchyOS (or the VM chroot). Builds in /tmp so no home paths end up in .BUILDINFO.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export GNUPGHOME=${GNUPGHOME:-$HOME/.armchy-signing}
KEY=${KEY:?set KEY to the signing key fingerprint}
export PACKAGER="ArmchyOS <noreply@armchyos.invalid>" GPGKEY=$KEY BUILDDIR=/tmp/armchy-build
out=$here/out; rm -rf "$out" "$BUILDDIR"; mkdir -p "$out" "$BUILDDIR/src"
# --nocheck: power-profiles-daemon's tests need python-dbusmock and umockdev on the builder
trap 'gpgconf --kill all 2>/dev/null || true' EXIT
for p in $(grep -v '^#' "$here/PACKAGES"); do
  cp -r "$here/$p" "$BUILDDIR/src/$p"
  (cd "$BUILDDIR/src/$p" && makepkg -f --sign --nocheck --noconfirm >"$BUILDDIR/$p.log" 2>&1) \
    || { echo "FAILED: $p"; tail -15 "$BUILDDIR/$p.log"; exit 1; }
  cp "$BUILDDIR/src/$p"/*.pkg.tar.*  "$out/"
done
rm -f "$out"/*-debug-*
# GitHub turns ':' in asset names into '.', so an epoch would break downloads
ls "$out" | grep -q : && { echo "FAILED: a filename has ':' (epoch); GitHub can't serve it"; exit 1; }
repo-add -q -s -k "$KEY" "$out/armchy.db.tar.gz" $(ls "$out"/*.pkg.tar.* | grep -v "\.sig$")
# pacman fetches armchy.db: replace repo-add's symlinks with real files for upload
for f in armchy.db armchy.files; do rm "$out/$f" "$out/$f.sig"; cp "$out/$f.tar.gz" "$out/$f"; cp "$out/$f.tar.gz.sig" "$out/$f.sig"; done
grep -l "$HOME" "$BUILDDIR"/*/pkg/*/.BUILDINFO 2>/dev/null && { echo "FAILED: home path in .BUILDINFO"; exit 1; }
ls -1 "$out"

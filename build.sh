#!/bin/bash
# Build every package listed in PACKAGES, sign them, and make the signed repo db in out/.
# Runs as the build user on ArmchyOS (or the VM chroot). Builds in /tmp so no home paths end up in .BUILDINFO.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export GNUPGHOME=${GNUPGHOME:-$HOME/.armchy-signing}
KEY=${KEY:?set KEY to the signing key fingerprint}
export PACKAGER="ArmchyOS <noreply@armchyos.invalid>" GPGKEY=$KEY BUILDDIR=/tmp/armchy-build
export CARGO_HOME=$BUILDDIR/cargo   # else Rust binaries embed ~/.cargo paths (the build user's name)
# Packages already in out/ at the same version are kept, not rebuilt: a published file must never change
out=$here/out; rm -rf "$BUILDDIR"; mkdir -p "$out" "$BUILDDIR/src"
# --nocheck: power-profiles-daemon's tests need python-dbusmock and umockdev on the builder
trap 'gpgconf --kill all 2>/dev/null || true' EXIT
for p in $(grep -v '^#' "$here/PACKAGES"); do
  cp -r "$here/$p" "$BUILDDIR/src/$p"
  want=$(cd "$BUILDDIR/src/$p" && PKGDEST=. makepkg --packagelist | grep -v -- '-debug-' | xargs -n1 basename)
  have=1; for w in $want; do [ -e "$out/${w//:/.}" ] || have=0; done
  if (( have )); then echo "kept: $p (already in out/)"; continue; fi
  (cd "$BUILDDIR/src/$p" && makepkg -f --sign --nocheck --noconfirm >"$BUILDDIR/$p.log" 2>&1) \
    || { echo "FAILED: $p"; tail -15 "$BUILDDIR/$p.log"; exit 1; }
  cp "$BUILDDIR/src/$p"/*.pkg.tar.*  "$out/"
done
rm -f "$out"/*-debug-*
# GitHub turns ':' in asset names into '.', so rename epoch files before repo-add (the db then names the
# '.' file; pacman reads name and version from inside the package, not from the filename)
for f in "$out"/*:*; do [ -e "$f" ] || continue; mv "$f" "${f//:/.}"; done
rm -f "$out"/armchy.{db,files}{,.sig,.tar.gz,.tar.gz.sig,.tar.gz.old,.tar.gz.old.sig}   # rebuilt from every package below; stale .old copies must not be published
repo-add -q -s -k "$KEY" "$out/armchy.db.tar.gz" $(ls "$out"/*.pkg.tar.* | grep -v "\.sig$")
# pacman fetches armchy.db: replace repo-add's symlinks with real files for upload
for f in armchy.db armchy.files; do rm "$out/$f" "$out/$f.sig"; cp "$out/$f.tar.gz" "$out/$f"; cp "$out/$f.tar.gz.sig" "$out/$f.sig"; done
grep -rla "$HOME" "$BUILDDIR"/*/pkg/ 2>/dev/null && { echo "FAILED: home path in a built package"; exit 1; }
ls -1 "$out"

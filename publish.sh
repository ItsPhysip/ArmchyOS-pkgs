#!/bin/bash
# Upload out/ to the rolling "aarch64" release and delete assets that are no longer built.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); repo=${REPO:-ItsPhysip/ArmchyOS-pkgs}; tag=aarch64
gh release view "$tag" -R "$repo" >/dev/null 2>&1 || gh release create "$tag" -R "$repo" -t "aarch64 packages" -n "pacman repo; see README."
gh release upload "$tag" -R "$repo" --clobber "$here"/out/*
for a in $(gh release view "$tag" -R "$repo" --json assets --jq '.assets[].name'); do
  [ -e "$here/out/$a" ] || gh release delete-asset "$tag" "$a" -R "$repo" -y
done

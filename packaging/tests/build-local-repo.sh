#!/usr/bin/env bash
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# build-local-repo.sh — build a local APT repository from the .deb files that
# THIS repository built (from source, including the Zig-built injector).
#
# Every scenario under packaging/tests/ installs opentelemetry-injector from
# this repository, never from a remote channel. The upstream packaging/tests get
# their injector deb from build/local-repo/apt after an nfpm build that wraps a
# libotelinject.so downloaded from GitHub Releases; here the deb is the one
# produced by this repo (dpkg-buildpackage), i.e. the injector binary comes from
# this repo's source tree.
#
# Usage:
#   packaging/tests/build-local-repo.sh
#
# Environment:
#   DEB_DIR   directory containing opentelemetry-*.deb (default: the repo's
#             parent directory, where dpkg-buildpackage drops its output)
#   ARCH      target architecture (default: host architecture)
#
# Output:
#   build/local-repo/apt/  an apt-compatible repository (dists/ + pool/)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEB_DIR="${DEB_DIR:-$(dirname "$REPO_ROOT")}"
REPO_DIR="$REPO_ROOT/build/local-repo/apt"
ARCH="${ARCH:-$(dpkg --print-architecture 2>/dev/null || echo amd64)}"

# The injector deb must be local. Fail loudly otherwise.
if ! ls "$DEB_DIR"/opentelemetry-injector_*.deb >/dev/null 2>&1; then
    echo "error: no opentelemetry-injector_*.deb found in $DEB_DIR" >&2
    echo "build it first with:  debian/scripts/get-orig-source.sh && dpkg-buildpackage -us -uc -b" >&2
    echo "or point DEB_DIR at the directory containing the built .deb files." >&2
    exit 1
fi

echo "Building local APT repository from local debs in $DEB_DIR"
echo "  injector deb: $(ls "$DEB_DIR"/opentelemetry-injector_*.deb)"

rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR/pool/main" "$REPO_DIR/dists/stable/main/binary-$ARCH"
cp "$DEB_DIR"/opentelemetry-*.deb "$REPO_DIR/pool/main/"

cd "$REPO_DIR"
dpkg-scanpackages pool/main > "dists/stable/main/binary-$ARCH/Packages" 2>/dev/null
gzip -c "dists/stable/main/binary-$ARCH/Packages" \
    > "dists/stable/main/binary-$ARCH/Packages.gz"

echo "Local APT repository created at $REPO_DIR (binary-$ARCH)"
echo "Container sources entries use:  deb [trusted=yes] file:///local-repo stable main"
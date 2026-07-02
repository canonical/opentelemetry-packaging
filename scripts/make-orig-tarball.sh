#!/bin/sh
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# make-orig-tarball.sh — generate the orig tarball required by the
# 3.0 (quilt) Debian source format.
#
# In 3.0 (quilt), the orig tarball represents the upstream source: everything
# in the repository except the debian/ directory.  The Debian packaging layer
# (debian/) is then applied on top as a diff/patch set.
#
# This script must be re-run whenever:
#   - The upstream version in debian/changelog changes (the part before the
#     first hyphen), OR
#   - Any non-debian/ file in the repository is added, removed, or modified.
#
# The tarball is written one directory above the repo root, which is where
# dpkg-buildpackage and dpkg-source look for it.
#
# Usage (from any directory):
#   scripts/make-orig-tarball.sh

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Extract upstream version (everything before the first hyphen).
VERSION="$(dpkg-parsechangelog -l "$REPO_ROOT/debian/changelog" -S Version \
           | sed 's/-.*//')"
TARBALL="$REPO_ROOT/../opentelemetry_${VERSION}.orig.tar.gz"
STUB_DIR="opentelemetry-${VERSION}"

printf 'Generating %s from non-debian/ tree at %s\n' "$TARBALL" "$REPO_ROOT"

# Pack everything except the debian/ directory and git metadata.
# The tarball root must be named <package>-<upstream-version>/ per policy.
tar -czf "$TARBALL" \
    --exclude='./.git' \
    --exclude='./debian' \
    --transform "s|^\.|$STUB_DIR|" \
    -C "$REPO_ROOT" \
    .

printf 'Done: %s (%s)\n' "$TARBALL" "$(du -sh "$TARBALL" | cut -f1)"

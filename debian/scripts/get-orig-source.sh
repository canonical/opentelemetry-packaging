#!/bin/sh
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# get-orig-source.sh — download the pinned injector source and assemble
# the orig tarball required by the 3.0 (quilt) Debian source format.
#
# This script is the equivalent of the "get-orig-source" target in older
# packaging workflows.  It must be run by the maintainer whenever the
# injector version changes in debian/changelog.
#
# The version is read from debian/changelog (the upstream version field,
# i.e. everything before the first "-" in the version column).
#
# The resulting tarball is:
#   ../opentelemetry-injector_<version>.orig.tar.gz
#
# Layout inside the tarball (what debian/rules will find at build time):
#   opentelemetry-injector-<version>/
#     upstream/
#       injector/
#         (source tree extracted from GitHub source tarball v<version>)
#         build.zig
#         build.zig.zon
#         Makefile
#         src/
#         ...
#
# Usage:
#   debian/scripts/get-orig-source.sh
#
# Required tools: curl (available on Ubuntu Noble)

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ---------------------------------------------------------------------------
# Determine the injector version from debian/changelog
# ---------------------------------------------------------------------------

# The first changelog line is:  opentelemetry-injector (<version>-<rev>) ...
# Extract the version field between "(" and ")", then drop its trailing
# Debian/Ubuntu revision (the part after the first "-").
VERSION="$(sed -n '1{ s/.*(//; s/).*//; p; }' "$REPO_ROOT/debian/changelog" | sed 's/-.*//')"
[ -n "$VERSION" ] || die "could not parse version from debian/changelog"

TARBALL="$REPO_ROOT/../opentelemetry-injector_${VERSION}.orig.tar.gz"
STUB="opentelemetry-injector-${VERSION}"

printf 'Building orig tarball: %s\n' "$TARBALL"
printf '  injector  %s\n' "$VERSION"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { printf 'get-orig-source: error: %s\n' "$*" >&2; exit 1; }

download() {
    printf '\n  Downloading %s\n' "$1"
    curl --silent --show-error --fail --location --output "$2" "$1"
}

# ---------------------------------------------------------------------------
# Working directory
# ---------------------------------------------------------------------------

WORKDIR="$(mktemp -d)"
UPSTREAM="$WORKDIR/$STUB/upstream"

mkdir -p "$UPSTREAM/injector"

# ---------------------------------------------------------------------------
# Injector — source tarball (built from source during package build)
# ---------------------------------------------------------------------------

printf '\n=== opentelemetry-injector %s (source) ===\n' "$VERSION"

INJECTOR_TARBALL="v${VERSION}.tar.gz"
URL="https://github.com/open-telemetry/opentelemetry-injector/archive/refs/tags/${INJECTOR_TARBALL}"
INJECTOR_TMP="$(mktemp -d)"
download "$URL" "$INJECTOR_TMP/$INJECTOR_TARBALL"

# Extract the source tarball; GitHub tarballs extract to <repo>-<version>/
tar -xzf "$INJECTOR_TMP/$INJECTOR_TARBALL" -C "$INJECTOR_TMP"
# Move contents from opentelemetry-injector-<version>/ to upstream/injector/
mv "$INJECTOR_TMP/opentelemetry-injector-${VERSION}"/* "$UPSTREAM/injector/"
rm -rf "$INJECTOR_TMP"

# ---------------------------------------------------------------------------
# Pack the tarball
# ---------------------------------------------------------------------------

printf '\nPacking %s ...\n' "$TARBALL"
tar -czf "$TARBALL" -C "$WORKDIR" "$STUB"
rm -rf "$WORKDIR"

printf 'Done: %s (%s)\n' "$TARBALL" "$(du -sh "$TARBALL" | cut -f1)"

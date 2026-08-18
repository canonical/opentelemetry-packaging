#!/bin/sh
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# get-orig-source.sh — download the pinned injector source and assemble
# the orig tarball required by the 3.0 (quilt) Debian source format.
#
# This script is the equivalent of the "get-orig-source" target in older
# packaging workflows.  It must be run by the maintainer whenever the
# injector version changes (i.e. when versions.mk is updated).
#
# The resulting tarball is:
#   ../opentelemetry-injector_<SUITE_VERSION>.orig.tar.gz
#
# Layout inside the tarball (what debian/rules will find at build time):
#   opentelemetry-injector-<SUITE_VERSION>/
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
# Load pinned versions from versions.mk
# ---------------------------------------------------------------------------

# Parse versions.mk with shell (no make required).
parse_version() {
    grep "^$1 :=" "$REPO_ROOT/debian/versions.mk" | sed 's/.*:= *//'
}

SUITE_VERSION="$(parse_version SUITE_VERSION)"
INJECTOR_VERSION="$(parse_version INJECTOR_VERSION)"

TARBALL="$REPO_ROOT/../opentelemetry-injector_${SUITE_VERSION}.orig.tar.gz"
STUB="opentelemetry-injector-${SUITE_VERSION}"

printf 'Building orig tarball: %s\n' "$TARBALL"
printf '  injector  %s\n' "$INJECTOR_VERSION"

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

printf '\n=== opentelemetry-injector %s (source) ===\n' "$INJECTOR_VERSION"

INJECTOR_TARBALL="v${INJECTOR_VERSION}.tar.gz"
URL="https://github.com/open-telemetry/opentelemetry-injector/archive/refs/tags/${INJECTOR_TARBALL}"
INJECTOR_TMP="$(mktemp -d)"
download "$URL" "$INJECTOR_TMP/$INJECTOR_TARBALL"

# Extract the source tarball; GitHub tarballs extract to <repo>-<version>/
tar -xzf "$INJECTOR_TMP/$INJECTOR_TARBALL" -C "$INJECTOR_TMP"
# Move contents from opentelemetry-injector-<version>/ to upstream/injector/
mv "$INJECTOR_TMP/opentelemetry-injector-${INJECTOR_VERSION}"/* "$UPSTREAM/injector/"
rm -rf "$INJECTOR_TMP"

# ---------------------------------------------------------------------------
# Pack the tarball
# ---------------------------------------------------------------------------

printf '\nPacking %s ...\n' "$TARBALL"
tar -czf "$TARBALL" -C "$WORKDIR" "$STUB"
rm -rf "$WORKDIR"

printf 'Done: %s (%s)\n' "$TARBALL" "$(du -sh "$TARBALL" | cut -f1)"

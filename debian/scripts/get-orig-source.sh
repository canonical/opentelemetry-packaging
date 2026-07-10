#!/bin/sh
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# get-orig-source.sh — download the pinned upstream artifacts and assemble
# the orig tarball required by the 3.0 (quilt) Debian source format.
#
# This script is the equivalent of the "get-orig-source" target in older
# packaging workflows.  It must be run by the maintainer whenever upstream
# component versions change (i.e. when versions.mk is updated).
#
# The resulting tarball is:
#   ../opentelemetry_<SUITE_VERSION>.orig.tar.gz
#
# Layout inside the tarball (what debian/rules will find at build time):
#   opentelemetry-<SUITE_VERSION>/
#     upstream/
#       injector/
#         (source tree extracted from GitHub source tarball v<version>)
#         build.zig
#         build.zig.zon
#         Makefile
#         src/
#         ...
#       java/
#         opentelemetry-javaagent.jar
#       nodejs/
#         auto-instrumentations-node-<version>.tgz   (npm tarball, unpacked by rules)
#       dotnet/
#         linux-x64/
#           OpenTelemetry.AutoInstrumentation.Native.so
#         linux-musl-x64/
#           OpenTelemetry.AutoInstrumentation.Native.so
#         linux-arm64/
#           OpenTelemetry.AutoInstrumentation.Native.so
#         linux-musl-arm64/
#           OpenTelemetry.AutoInstrumentation.Native.so
#         net/
#           (shared managed assemblies)
#
# Usage:
#   debian/scripts/get-orig-source.sh
#
# Required tools: curl, jq, unzip (all available on Ubuntu Noble)

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
JAVA_VERSION="$(parse_version JAVA_VERSION)"
NODEJS_VERSION="$(parse_version NODEJS_VERSION)"
DOTNET_VERSION="$(parse_version DOTNET_VERSION)"

TARBALL="$REPO_ROOT/../opentelemetry_${SUITE_VERSION}.orig.tar.gz"
STUB="opentelemetry-${SUITE_VERSION}"

printf 'Building orig tarball: %s\n' "$TARBALL"
printf '  injector  %s\n' "$INJECTOR_VERSION"
printf '  java      %s\n' "$JAVA_VERSION"
printf '  nodejs    %s\n' "$NODEJS_VERSION"
printf '  dotnet    %s\n' "$DOTNET_VERSION"

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

mkdir -p \
    "$UPSTREAM/injector" \
    "$UPSTREAM/java" \
    "$UPSTREAM/nodejs" \
    "$UPSTREAM/dotnet"

# ---------------------------------------------------------------------------
# 1. Injector — source tarball (built from source during package build)
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
# 2. Java agent — single fat JAR
# ---------------------------------------------------------------------------

printf '\n=== opentelemetry-java-instrumentation %s ===\n' "$JAVA_VERSION"

download \
    "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${JAVA_VERSION}/opentelemetry-javaagent.jar" \
    "$UPSTREAM/java/opentelemetry-javaagent.jar"

# ---------------------------------------------------------------------------
# 3. Node.js — npm tarball (kept as-is; unpacked by debian/rules)
# ---------------------------------------------------------------------------

printf '\n=== @opentelemetry/auto-instrumentations-node %s ===\n' "$NODEJS_VERSION"

download \
    "https://registry.npmjs.org/@opentelemetry/auto-instrumentations-node/-/auto-instrumentations-node-${NODEJS_VERSION}.tgz" \
    "$UPSTREAM/nodejs/auto-instrumentations-node-${NODEJS_VERSION}.tgz"

# ---------------------------------------------------------------------------
# 4. .NET — separate zips per arch/libc; extract only what we need
#    (skip *.debug files — they are large and not needed at runtime)
# ---------------------------------------------------------------------------

printf '\n=== opentelemetry-dotnet-instrumentation %s ===\n' "$DOTNET_VERSION"

# We need four zips: glibc/musl × amd64/arm64.
# The managed assemblies (net/) are identical across all four; we take them
# from the glibc-x64 zip and skip them in the other three.
MANAGED_DONE=0

for VARIANT in \
    "linux-glibc-x64:linux-x64" \
    "linux-musl-x64:linux-musl-x64" \
    "linux-glibc-arm64:linux-arm64" \
    "linux-musl-arm64:linux-musl-arm64"; do

    ZIP_SUFFIX="${VARIANT%%:*}"   # e.g. linux-glibc-x64
    DEST_SUBDIR="${VARIANT##*:}"  # e.g. linux-x64

    ASSET="opentelemetry-dotnet-instrumentation-${ZIP_SUFFIX}.zip"
    URL="https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/download/v${DOTNET_VERSION}/${ASSET}"

    ZIPTMP="$(mktemp -d)"
    download "$URL" "$ZIPTMP/$ASSET"
    unzip -q "$ZIPTMP/$ASSET" -d "$ZIPTMP/unpack"

    # Native .so (skip the .debug companion file)
    mkdir -p "$UPSTREAM/dotnet/$DEST_SUBDIR"
    find "$ZIPTMP/unpack/$DEST_SUBDIR" -name '*.so' ! -name '*.so.debug' \
        -exec install -m 0755 {} "$UPSTREAM/dotnet/$DEST_SUBDIR/" \;

    # Managed assemblies — only from the first zip
    if test "$MANAGED_DONE" -eq 0; then
        cp -a "$ZIPTMP/unpack/net" "$UPSTREAM/dotnet/net"
        MANAGED_DONE=1
    fi

    rm -rf "$ZIPTMP"
done

# ---------------------------------------------------------------------------
# Pack the tarball
# ---------------------------------------------------------------------------

printf '\nPacking %s ...\n' "$TARBALL"
tar -czf "$TARBALL" -C "$WORKDIR" "$STUB"
rm -rf "$WORKDIR"

printf 'Done: %s (%s)\n' "$TARBALL" "$(du -sh "$TARBALL" | cut -f1)"

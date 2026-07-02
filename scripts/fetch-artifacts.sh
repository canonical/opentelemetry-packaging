#!/bin/sh
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# fetch-artifacts.sh — download the latest pre-built upstream artefacts for
# every OpenTelemetry package component and place them under STAGING_DIR in
# the layout expected by the debian/*.install files.
#
# Called from debian/rules override_dh_auto_build.
#
# Required environment variables:
#   DEB_HOST_ARCH   dpkg architecture string, e.g. "amd64" or "arm64"
#   STAGING_DIR     destination root (typically $(CURDIR)/debian/tmp)
#
# Required tools: curl, jq (both declared in debian/control Build-Depends)
#
# Exit codes: non-zero on any failure (set -e).

set -eu

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
    printf 'fetch-artifacts.sh: error: %s\n' "$*" >&2
    exit 1
}

# latest_release_tag <github-owner/repo>
# Prints the tag_name of the latest GitHub release.
latest_release_tag() {
    curl --silent --show-error --fail \
        --header "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$1/releases/latest" \
    | jq --raw-output '.tag_name'
}

# download <url> <dest-path>
download() {
    printf 'Downloading %s\n' "$1"
    curl --silent --show-error --fail --location \
        --output "$2" \
        "$1"
}

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------

: "${DEB_HOST_ARCH:?DEB_HOST_ARCH must be set}"
: "${STAGING_DIR:?STAGING_DIR must be set}"

case "$DEB_HOST_ARCH" in
    amd64) UPSTREAM_ARCH="x86_64"  ; DOTNET_ARCH="x64"  ;;
    arm64) UPSTREAM_ARCH="aarch64" ; DOTNET_ARCH="arm64" ;;
    *)     die "Unsupported architecture: $DEB_HOST_ARCH" ;;
esac

# ---------------------------------------------------------------------------
# Directory layout (mirrors the filesystem paths in debian/*.install)
# ---------------------------------------------------------------------------

INJECTOR_DIR="$STAGING_DIR/usr/lib/opentelemetry/injector"
JAVA_DIR="$STAGING_DIR/usr/lib/opentelemetry/java"
NODEJS_DIR="$STAGING_DIR/usr/lib/opentelemetry/nodejs"
DOTNET_DIR="$STAGING_DIR/usr/lib/opentelemetry/dotnet"
META_DOC_DIR="$STAGING_DIR/usr/share/doc/opentelemetry"

mkdir -p \
    "$INJECTOR_DIR" \
    "$JAVA_DIR" \
    "$NODEJS_DIR" \
    "$DOTNET_DIR" \
    "$META_DOC_DIR"

# ---------------------------------------------------------------------------
# 1. opentelemetry-injector  (arch-specific .so)
# ---------------------------------------------------------------------------

printf '\n=== Fetching opentelemetry-injector ===\n'
INJECTOR_TAG="$(latest_release_tag open-telemetry/opentelemetry-injector)"
printf 'Latest injector release: %s\n' "$INJECTOR_TAG"

# The injector releases a tar.gz containing libotelinject.so per architecture.
# Asset name convention (from upstream releases):
#   opentelemetry-injector_<tag>_linux_<arch>.tar.gz
INJECTOR_TARBALL="opentelemetry-injector_${INJECTOR_TAG#v}_linux_${UPSTREAM_ARCH}.tar.gz"
INJECTOR_URL="https://github.com/open-telemetry/opentelemetry-injector/releases/download/${INJECTOR_TAG}/${INJECTOR_TARBALL}"

INJECTOR_TMP="$(mktemp -d)"
download "$INJECTOR_URL" "$INJECTOR_TMP/$INJECTOR_TARBALL"
tar -xzf "$INJECTOR_TMP/$INJECTOR_TARBALL" -C "$INJECTOR_TMP"
# The .so may be at the root of the tarball or in a subdirectory; find it.
SO_SRC="$(find "$INJECTOR_TMP" -name 'libotelinject.so' | head -1)"
test -n "$SO_SRC" || die "libotelinject.so not found in injector tarball"
install -m 0755 "$SO_SRC" "$INJECTOR_DIR/libotelinject.so"
rm -rf "$INJECTOR_TMP"

# ---------------------------------------------------------------------------
# 2. opentelemetry-java-autoinstrumentation  (arch-independent JAR)
# ---------------------------------------------------------------------------

printf '\n=== Fetching opentelemetry-java-autoinstrumentation ===\n'
JAVA_TAG="$(latest_release_tag open-telemetry/opentelemetry-java-instrumentation)"
printf 'Latest Java agent release: %s\n' "$JAVA_TAG"

# The Java agent is a single fat JAR released as:
#   opentelemetry-javaagent.jar
JAVA_JAR_URL="https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/${JAVA_TAG}/opentelemetry-javaagent.jar"
download "$JAVA_JAR_URL" "$JAVA_DIR/opentelemetry-javaagent.jar"
chmod 0644 "$JAVA_DIR/opentelemetry-javaagent.jar"

# ---------------------------------------------------------------------------
# 3. opentelemetry-nodejs-autoinstrumentation  (arch-independent npm bundle)
# ---------------------------------------------------------------------------

printf '\n=== Fetching opentelemetry-nodejs-autoinstrumentation ===\n'
NODEJS_TAG="$(latest_release_tag open-telemetry/opentelemetry-js)"
printf 'Latest opentelemetry-js release: %s\n' "$NODEJS_TAG"

# The Node.js auto-instrumentation package is published on npm as
# @opentelemetry/auto-instrumentations-node.  We download the tarball
# directly from the npm registry (no npm CLI needed; it is just a .tgz).
# The npm registry serves tarballs at a stable URL independent of the GitHub
# release tag, keyed by the npm package version.
#
# The npm package version is extracted from the GitHub release tag for the
# @opentelemetry/auto-instrumentations-node workspace package.
# GitHub releases for opentelemetry-js use tag names like:
#   experimental/packages/@opentelemetry/auto-instrumentations-node/v0.x.y
# We query the releases list and find the one matching that pattern.

NODEJS_NPM_VERSION="$(
    curl --silent --show-error --fail \
        --header "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/open-telemetry/opentelemetry-js/releases" \
    | jq --raw-output '
        [ .[] | select(.tag_name | contains("auto-instrumentations-node")) ]
        | first
        | .tag_name
        | split("/")
        | last
        | ltrimstr("v")
    '
)"
test -n "$NODEJS_NPM_VERSION" || die "Could not determine @opentelemetry/auto-instrumentations-node npm version"
printf 'Using @opentelemetry/auto-instrumentations-node version: %s\n' "$NODEJS_NPM_VERSION"

NODEJS_TARBALL_URL="https://registry.npmjs.org/@opentelemetry/auto-instrumentations-node/-/auto-instrumentations-node-${NODEJS_NPM_VERSION}.tgz"
NODEJS_TMP="$(mktemp -d)"
download "$NODEJS_TARBALL_URL" "$NODEJS_TMP/auto-instrumentations-node.tgz"

# npm tarballs unpack into a "package/" directory at the root.
mkdir -p "$NODEJS_TMP/unpack"
tar -xzf "$NODEJS_TMP/auto-instrumentations-node.tgz" -C "$NODEJS_TMP/unpack"

# Install the package and its bundled dependencies into the staging directory.
# npm tarballs include node_modules for bundled dependencies; we install the
# entire tree so the package is self-contained.
mkdir -p "$NODEJS_DIR/node_modules/@opentelemetry"
cp -a "$NODEJS_TMP/unpack/package" \
    "$NODEJS_DIR/node_modules/@opentelemetry/auto-instrumentations-node"
rm -rf "$NODEJS_TMP"

# ---------------------------------------------------------------------------
# 4. opentelemetry-dotnet-autoinstrumentation  (arch-specific native + managed)
# ---------------------------------------------------------------------------

printf '\n=== Fetching opentelemetry-dotnet-autoinstrumentation ===\n'
DOTNET_TAG="$(latest_release_tag open-telemetry/opentelemetry-dotnet-instrumentation)"
printf 'Latest .NET instrumentation release: %s\n' "$DOTNET_TAG"

# The .NET instrumentation releases a zip per OS/arch containing:
#   - Managed assemblies (shared across glibc/musl)
#   - linux-x64/    or linux-arm64/    (glibc native .so)
#   - linux-musl-x64/ or linux-musl-arm64/ (musl native .so)
#
# Asset convention: opentelemetry-dotnet-instrumentation-linux.zip
# (the single zip contains both glibc and musl subdirectories)
DOTNET_ZIP="opentelemetry-dotnet-instrumentation-linux.zip"
DOTNET_URL="https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/download/${DOTNET_TAG}/${DOTNET_ZIP}"

DOTNET_TMP="$(mktemp -d)"
download "$DOTNET_URL" "$DOTNET_TMP/$DOTNET_ZIP"
unzip -q "$DOTNET_TMP/$DOTNET_ZIP" -d "$DOTNET_TMP/unpack"

# The injector expects:
#   /usr/lib/opentelemetry/dotnet/              (managed assemblies)
#   /usr/lib/opentelemetry/dotnet/linux-x64/    (glibc native)
#   /usr/lib/opentelemetry/dotnet/linux-musl-x64/ (musl native)
#
# Adjust paths for arm64: linux-arm64 / linux-musl-arm64.
#
# Copy managed assemblies (everything except linux-* subdirectories).
find "$DOTNET_TMP/unpack" -maxdepth 1 -not -type d \
    | while read -r f; do
        install -m 0644 "$f" "$DOTNET_DIR/$(basename "$f")"
    done

# Copy architecture-specific native libraries preserving subdirectory names.
for SUBDIR in "linux-${DOTNET_ARCH}" "linux-musl-${DOTNET_ARCH}"; do
    if test -d "$DOTNET_TMP/unpack/$SUBDIR"; then
        cp -a "$DOTNET_TMP/unpack/$SUBDIR" "$DOTNET_DIR/$SUBDIR"
    else
        printf 'Warning: %s not found in .NET release zip\n' "$SUBDIR"
    fi
done

rm -rf "$DOTNET_TMP"

# ---------------------------------------------------------------------------
# 5. opentelemetry metapackage  (no files beyond the doc dir placeholder)
# ---------------------------------------------------------------------------

printf 'opentelemetry README placeholder\n' > "$META_DOC_DIR/README"

printf '\nAll artefacts fetched successfully.\n'

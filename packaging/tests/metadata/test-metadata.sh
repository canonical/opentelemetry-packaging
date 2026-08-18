#!/usr/bin/env bash
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# test-metadata.sh — host-side validation of the LOCAL opentelemetry-injector
# .deb package. No containers required.
#
# Asserts, for the local build:
#   - opentelemetry-injector Provides: opentelemetry-injector1
#   - injector ships libotelinject.so, injector.conf, default_env.conf, conf.d/
#
# Usage:
#   packaging/tests/metadata/test-metadata.sh
# Environment:
#   DEB_DIR   directory containing opentelemetry-injector_*.deb (default: repo parent)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEB_DIR="${DEB_DIR:-$(dirname "$REPO_ROOT")}"
command -v dpkg-deb >/dev/null || { echo "error: dpkg-deb not found"; exit 1; }

FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAIL=1; }

need_deb() {  # $1=glob pattern, returns the file or fails
    local f
    f=$(ls "$DEB_DIR"/$1 2>/dev/null | head -1) || true
    if [ -z "$f" ]; then fail "missing local deb: $DEB_DIR/$1"; return 1; fi
    echo "$f"
}

control_field() { # $1=deb file $2=field name
    dpkg-deb -I "$1" | awk -v k="$2" -F': *' '{gsub(/^[ \t]+/,"",$1); if($1==k){gsub(/[ \t]+$/,"",$2); print $2; exit}}'
}

has_file() { # $1=deb file $2=path within the package
    dpkg-deb -c "$1" | grep " $2$" >/dev/null
}

INJECTOR="$(need_deb opentelemetry-injector_*.deb)" || true

# --- metadata assertions ---------------------------------------------------
[ -n "$INJECTOR" ] && {
    case " $(control_field "$INJECTOR" Provides) " in
        *"opentelemetry-injector1"*) pass "injector Provides opentelemetry-injector1" ;;
        *) fail "injector does not Provides opentelemetry-injector1" ;;
    esac
}

# --- contents assertions ---------------------------------------------------
[ -n "$INJECTOR" ] && {
    has_file "$INJECTOR" ./usr/lib/opentelemetry/injector/libotelinject.so \
        || fail "injector missing libotelinject.so"
    has_file "$INJECTOR" ./etc/opentelemetry/injector/injector.conf \
        || fail "injector missing injector.conf"
    has_file "$INJECTOR" ./etc/opentelemetry/injector/default_env.conf \
        || fail "injector missing default_env.conf"
    has_file "$INJECTOR" ./etc/opentelemetry/injector/conf.d/ \
        || fail "injector missing conf.d/ drop-in directory"
    control_field "$INJECTOR" Architecture | grep -q '^amd64$' \
        && pass "injector deb is amd64" || true
}

echo
if [ "$FAIL" = 0 ]; then
    echo "=== metadata/content tests passed (local debs in $DEB_DIR) ==="
    exit 0
else
    echo "=== metadata/content tests FAILED ===" >&2
    exit 1
fi

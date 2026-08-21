#!/usr/bin/env bash
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# run-all.sh — run every packaging/tests scenario against the LOCAL debs built
# by this repository. The opentelemetry-injector deb is always the one produced
# here (debian/rules builds it from the vendored Zig source), never a remote
# download.
#
# Usage:
#   packaging/tests/run-all.sh [metadata|lifecycle|all]
# Environment:
#   DEB_DIR   directory containing opentelemetry-injector_*.deb (default: repo parent)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WHAT="${1:-all}"

status=0
run() {  # $1=label, rest=command...
    local label="$1"; shift
    echo
    echo "============================================================"
    echo "  $label"
    echo "============================================================"
    if "$@"; then
        echo
        echo "> $label: PASS"
    else
        echo
        echo "> $label: FAIL" >&2
        status=1
    fi
}

case "$WHAT" in
    metadata)  run "metadata (host-side, no containers)" \
                   "$REPO_ROOT/packaging/tests/metadata/test-metadata.sh" ;;
    lifecycle) run "lifecycle (container, local deb)" \
                   "$REPO_ROOT/packaging/tests/lifecycle/test-lifecycle-deb.sh" ;;
    all)
        "$REPO_ROOT/packaging/tests/build-local-repo.sh"
        run "metadata (host-side, no containers)" \
            "$REPO_ROOT/packaging/tests/metadata/test-metadata.sh"
        run "lifecycle (container, local deb)" \
            "$REPO_ROOT/packaging/tests/lifecycle/test-lifecycle-deb.sh"
        ;;
    *)
        echo "usage: $0 [metadata|lifecycle|all]" >&2
        exit 2
        ;;
esac

echo
if [ "$status" = 0 ]; then
    echo "=== all requested scenarios passed (using local injector deb) ==="
else
    echo "=== some scenarios FAILED ===" >&2
fi
exit "$status"

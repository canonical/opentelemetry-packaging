#!/usr/bin/env bash
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# test-lifecycle-deb.sh — run the injector DEB lifecycle tests against the
# LOCAL injector deb (this repo's build).
#
# Usage:
#   packaging/tests/lifecycle/test-lifecycle-deb.sh
# Environment:
#   DEB_DIR   directory containing opentelemetry-*.deb (default: repo parent)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
command -v docker >/dev/null || { echo "error: docker is required"; exit 1; }

"$REPO_ROOT/packaging/tests/build-local-repo.sh"

IMAGE=otel-local-lifecycle-deb
docker build \
    --build-arg BASE_IMAGE=ubuntu:26.10 \
    -f "$REPO_ROOT/packaging/tests/lifecycle/Dockerfile.deb" \
    -t "$IMAGE" \
    "$REPO_ROOT"

echo "--- running lifecycle tests ---"
docker run --rm "$IMAGE"
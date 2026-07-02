#!/bin/sh
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0
#
# postinstall-injector.sh — append libotelinject.so to /etc/ld.so.preload.
#
# Uses only POSIX shell builtins; no grep, sed, or other external commands.
# This avoids declaring grep or sed as package dependencies.

set -e

PRELOAD_FILE="/etc/ld.so.preload"
INJECT_LIB="/usr/lib/opentelemetry/injector/libotelinject.so"

# Check whether the library is already listed.
already_present() {
    test -f "$PRELOAD_FILE" || return 1
    while IFS= read -r line; do
        case "$line" in
            "$INJECT_LIB") return 0 ;;
        esac
    done < "$PRELOAD_FILE"
    return 1
}

if ! already_present; then
    printf '%s\n' "$INJECT_LIB" >> "$PRELOAD_FILE"
fi

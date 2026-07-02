#!/bin/sh
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0
#
# preuninstall-injector.sh — remove libotelinject.so from /etc/ld.so.preload.
#
# Uses only POSIX shell builtins; no grep, sed, or other external commands.

set -e

PRELOAD_FILE="/etc/ld.so.preload"
INJECT_LIB="/usr/lib/opentelemetry/injector/libotelinject.so"

# Nothing to do if the file does not exist.
test -f "$PRELOAD_FILE" || exit 0

# Rewrite the file, omitting lines that match the library path.
TMP_FILE="${PRELOAD_FILE}.tmp.$$"
while IFS= read -r line; do
    case "$line" in
        "$INJECT_LIB") ;;          # skip this line
        *) printf '%s\n' "$line" >> "$TMP_FILE" ;;
    esac
done < "$PRELOAD_FILE"

# Replace atomically.
if test -f "$TMP_FILE"; then
    mv "$TMP_FILE" "$PRELOAD_FILE"
else
    # All lines were removed; leave an empty file rather than deleting it,
    # so that other software that also writes to /etc/ld.so.preload is not
    # surprised.
    : > "$PRELOAD_FILE"
fi

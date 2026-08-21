#!/bin/sh
# Copyright 2026 Canonical Ltd.
# SPDX-License-Identifier: Apache-2.0
#
# test.sh — lifecycle assertions for the opentelemetry-injector DEB, mirroring
# upstream packaging/tests/lifecycle/{preload,config,install}_test.go.
# Runs inside the lifecycle test container where the injector was installed
# from the LOCAL apt repository.

set -eu

PRELOAD=/etc/ld.so.preload
INJECTOR=/usr/lib/opentelemetry/injector/libotelinject.so
CONF=/etc/opentelemetry/injector/injector.conf
ENV_CONF=/etc/opentelemetry/injector/default_env.conf

FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAIL=1; }

count_injector_entries() {
    if [ ! -f "$PRELOAD" ]; then echo 0; return; fi
    grep -cx "^${INJECTOR}$" "$PRELOAD" || echo 0
}

# --- install state ----------------------------------------------------------
[ -f "$INJECTOR" ] || fail "injector library not installed at $INJECTOR"
[ -f "$CONF" ] || fail "injector.conf not installed"
[ -f "$ENV_CONF" ] || fail "default_env.conf not installed"
[ -d /etc/opentelemetry/injector/conf.d ] || fail "conf.d/ directory missing"
[ "$(count_injector_entries)" -eq 1 ] || fail "expected exactly 1 entry in $PRELOAD"
case "$(apt-cache show opentelemetry-injector | sed -n 's/^Filename: //p')" in
    pool/*) pass "injector deb resolved from local repo (pool/)" ;;
    *) fail "injector did not resolve from the local repo: unexpected Filename" ;;
esac
pass "package installed from local repo; preload entry present"

# --- idempotent reinstall ---------------------------------------------------
apt-get -y install --reinstall opentelemetry-injector >/dev/null
[ "$(count_injector_entries)" -eq 1 ] || fail "reinstall duplicated the preload entry"
pass "reinstall is idempotent (no duplicate preload entry)"

# --- foreign entries preserved ----------------------------------------------
echo /opt/example/libexample.so >> "$PRELOAD"
apt-get -y install --reinstall opentelemetry-injector >/dev/null
grep -q '^/opt/example/libexample.so$' "$PRELOAD" || fail "foreign preload entry lost"
[ "$(count_injector_entries)" -eq 1 ] || fail "injector entry count wrong after foreign seed"
pass "reinstall preserves foreign preload entries"

# --- remove keeps conffiles, removes lib and preload entry ------------------
apt-get -y remove opentelemetry-injector >/dev/null
[ ! -f "$INJECTOR" ] || fail "library still present after remove"
[ -f "$CONF" ] || fail "injector.conf removed on remove (conffile should stay)"
[ -f "$ENV_CONF" ] || fail "default_env.conf removed on remove (conffile should stay)"
[ "$(count_injector_entries)" -eq 0 ] || fail "preload entry not removed"
grep -q '^/opt/example/libexample.so$' "$PRELOAD" || fail "foreign preload entry lost on remove"
pass "remove deletes library + preload entry, keeps conffiles and foreign entries"

# --- purge removes conffiles ------------------------------------------------
apt-get -y purge opentelemetry-injector >/dev/null
[ ! -f "$CONF" ] || fail "injector.conf still present after purge"
[ ! -f "$ENV_CONF" ] || fail "default_env.conf still present after purge"
pass "purge removes conffiles"

echo
if [ "$FAIL" = 0 ]; then
    echo "=== lifecycle tests passed ==="
    exit 0
else
    echo "=== lifecycle tests FAILED ===" >&2
    exit 1
fi
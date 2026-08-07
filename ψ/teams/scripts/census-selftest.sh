#!/usr/bin/env bash
# 3-arm self-test for model-tier-census.py — makes "the names!=rows warning works" a CURRENT
# claim instead of a dated one. [lucifer 2026-08-07: a dated proof still reads like present
# evidence after someone refactors tier() or _reach().]
#
# ARM 1 is NOT optional. With only ARM 2 we would have a guard that fires always, which reads
# exactly like a guard that passes always.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENSUS="$HERE/model-tier-census.py"
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/a" "$FIX/b"
fail=0
_arm() { printf '  %-34s ' "$1"; }

printf '{"commands":{"probe-alias":"codex --config model_reasoning_effort=high"}}\n' > "$FIX/a/maw.config.60.json"
cp "$FIX/a/maw.config.60.json" "$FIX/b/maw.config.60.json"
_arm "ARM1 negative control (silent)"
out=$(MAW_CENSUS_ROOTS="$FIX/*/maw.config.*.json" python3 "$CENSUS" 2>&1)
if grep -q 'names != rows' <<<"$out"; then echo "FAIL — fired when it must not"; fail=1
elif ! grep -q 'names       (distinct alias names)              : 1' <<<"$out"; then echo "FAIL — expected names=1"; fail=1
else echo "ok"; fi

printf '{"commands":{"probe-alias":"codex --config model_reasoning_effort=low"}}\n' > "$FIX/b/maw.config.60.json"
_arm "ARM2 positive (must fire)"
out=$(MAW_CENSUS_ROOTS="$FIX/*/maw.config.*.json" python3 "$CENSUS" 2>&1)
if ! grep -q 'names != rows' <<<"$out"; then echo "FAIL — silent when it must fire"; fail=1
elif ! grep -q 'probe-alias: 2 different commands' <<<"$out"; then echo "FAIL — fired without naming the files"; fail=1
else echo "ok"; fi

_arm "ARM3 regression (default roots)"
out=$(python3 "$CENSUS" 2>&1)
if grep -q 'MAW_CENSUS_ROOTS is set' <<<"$out"; then echo "FAIL — env leaked into default run"; fail=1
elif ! grep -qE 'names       \(distinct alias names\)              : [0-9]+' <<<"$out"; then echo "FAIL — no counts"; fail=1
else echo "ok"; fi

[ $fail -eq 0 ] && echo "CENSUS SELFTEST OK (3/3)" || echo "CENSUS SELFTEST FAILED"
exit $fail

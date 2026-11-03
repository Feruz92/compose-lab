#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:?usage: smoke-test.sh BASE_URL EXPECTED_VERSION}"
EXPECTED_VERSION="${2:?usage: smoke-test.sh BASE_URL EXPECTED_VERSION}"

get() { curl -fsS -m 5 "$BASE_URL$1"; }

health="$(get /health)"
[[ "$health" == "ok" ]] || { echo "FAIL: /health returned '$health'" >&2; exit 1; }

version="$(get /version)"
[[ "$version" == "$EXPECTED_VERSION" ]] || { echo "FAIL: version is '$version', expected '$EXPECTED_VERSION'" >&2; exit 1; }

# счётчик должен вырасти на 1: значит, запись в настоящий Redis работает
first="$(get /)"
second="$(get /)"
(( ${second#Visits: } == ${first#Visits: } + 1 )) || { echo "FAIL: counter went from '$first' to '$second'" >&2; exit 1; }

echo "Smoke test passed: version $version, $second"

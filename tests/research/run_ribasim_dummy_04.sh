#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="ad76b2c46530a40d9fb60973270d1f69708a695f"
fail() {
  echo "RIBASIM_DUMMY_04_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from preregistered DUMMY-04 base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_04_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_04_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_04_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_04_CONCEPT.md) ;;
    tests/research/dummy_trapezoid_exchange_iteration.py) ;;
    tests/research/test_dummy_trapezoid_exchange_iteration.py) ;;
    tests/research/run_ribasim_dummy_04.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-04 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_04_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_trapezoid_exchange_iteration.py   tests/research/test_dummy_trapezoid_exchange_iteration.py

python3 tests/research/test_dummy_trapezoid_exchange_iteration.py

echo "RIBASIM_DUMMY_04_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_04_GATE=PASS"

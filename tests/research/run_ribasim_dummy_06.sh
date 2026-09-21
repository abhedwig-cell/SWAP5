#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="9947713ddc3d526e7e0f184948c928eba6519dcb"
fail() {
  echo "RIBASIM_DUMMY_06_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from preregistered DUMMY-06 base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_06_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_06_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_06_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_06_CONCEPT.md) ;;
    tests/research/dummy_active_set_picard.py) ;;
    tests/research/test_dummy_active_set_picard.py) ;;
    tests/research/run_ribasim_dummy_06.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-06 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_06_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_trapezoid_exchange_iteration.py   tests/research/dummy_head_management_complementarity.py   tests/research/dummy_active_set_picard.py   tests/research/test_dummy_active_set_picard.py

python3 tests/research/test_dummy_active_set_picard.py

echo "RIBASIM_DUMMY_06_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_06_GATE=PASS"

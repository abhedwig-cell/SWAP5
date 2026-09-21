#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="5614799ff6930f2d049f2e04e8dd95a50647be3b"
fail() {
  echo "RIBASIM_DUMMY_07_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from preregistered DUMMY-07 base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_07_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_07_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_07_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_07_CONCEPT.md) ;;
    tests/research/dummy_active_set_stabilization.py) ;;
    tests/research/test_dummy_active_set_stabilization.py) ;;
    tests/research/run_ribasim_dummy_07.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-07 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_07_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_trapezoid_exchange_iteration.py   tests/research/dummy_head_management_complementarity.py   tests/research/dummy_active_set_picard.py   tests/research/dummy_active_set_stabilization.py   tests/research/test_dummy_active_set_stabilization.py

python3 tests/research/test_dummy_active_set_stabilization.py

echo "RIBASIM_DUMMY_07_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_07_GATE=PASS"

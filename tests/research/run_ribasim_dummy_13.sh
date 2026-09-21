#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="51bbc6d3375028b6604351b19f8806babac82721"
fail() {
  echo "RIBASIM_DUMMY_13_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from combined DUMMY-11/DUMMY-12 authority base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_13_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_13_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_13_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_13_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/dummy_three_store_internal_ledger.py) ;;
    tests/research/test_dummy_three_store_internal_ledger.py) ;;
    tests/research/run_ribasim_dummy_13.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-13 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_13_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_rootzone_demand.py   tests/research/dummy_two_store_exchange.py   tests/research/dummy_two_store_management.py   tests/research/dummy_three_store_internal_ledger.py   tests/research/test_dummy_three_store_internal_ledger.py

python3 tests/research/test_dummy_three_store_internal_ledger.py

echo "RIBASIM_DUMMY_13_LEDGER_TESTS=PASS"
echo "RIBASIM_DUMMY_13_GATE=PASS"

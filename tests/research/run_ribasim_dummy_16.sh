#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="ab2f44e0c40a2980432165fd60d4958ef60a96fe"
fail() {
  echo "RIBASIM_DUMMY_16_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-15B closeout base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_16_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_16_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_16_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_16_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/dummy_management_clock.py) ;;
    tests/research/test_dummy_management_clock.py) ;;
    tests/research/run_ribasim_dummy_16.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-16 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_16_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_rootzone_demand.py   tests/research/dummy_two_store_exchange.py   tests/research/dummy_two_store_management.py   tests/research/dummy_three_store_internal_ledger.py   tests/research/dummy_competing_claims.py   tests/research/dummy_management_clock.py   tests/research/test_dummy_management_clock.py

python3 tests/research/test_dummy_management_clock.py

echo "RIBASIM_DUMMY_16_CLOCK_TESTS=PASS"
echo "RIBASIM_DUMMY_16_GATE=PASS"

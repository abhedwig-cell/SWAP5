#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="8f5cbc493e4f94cb1edf5833e115c60cc8594f86"
fail() {
  echo "RIBASIM_DUMMY_15_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-14 closeout base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_15_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_15_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_15_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_15_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/dummy_competing_claims.py) ;;
    tests/research/test_dummy_competing_claims.py) ;;
    tests/research/run_ribasim_dummy_15.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-15 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_15_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_rootzone_demand.py   tests/research/dummy_two_store_exchange.py   tests/research/dummy_two_store_management.py   tests/research/dummy_three_store_internal_ledger.py   tests/research/dummy_competing_claims.py   tests/research/test_dummy_competing_claims.py

python3 tests/research/test_dummy_competing_claims.py

echo "RIBASIM_DUMMY_15_PRIORITY_TESTS=PASS"
echo "RIBASIM_DUMMY_15_GATE=PASS"

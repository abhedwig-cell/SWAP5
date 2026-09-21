#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="e46bc9c08769426e282df7f97213db2d50cb4c63"
fail() {
  echo "RIBASIM_DUMMY_14_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-13 closeout base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_14_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_14_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_14_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_14_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/dummy_three_store_forcing.py) ;;
    tests/research/test_dummy_three_store_forcing.py) ;;
    tests/research/run_ribasim_dummy_14.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-14 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_14_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_rootzone_demand.py   tests/research/dummy_two_store_exchange.py   tests/research/dummy_two_store_management.py   tests/research/dummy_three_store_internal_ledger.py   tests/research/dummy_three_store_forcing.py   tests/research/test_dummy_three_store_forcing.py

python3 tests/research/test_dummy_three_store_forcing.py

echo "RIBASIM_DUMMY_14_FORCING_TESTS=PASS"
echo "RIBASIM_DUMMY_14_GATE=PASS"

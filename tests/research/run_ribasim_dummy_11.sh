#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="be1af9f93eb444d676f2df77b0260f3e56f7870a"
fail() {
  echo "RIBASIM_DUMMY_11_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-10 closeout base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_11_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_11_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_11_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_11_CONCEPT.md) ;;
    tests/research/dummy_two_store_temporal.py) ;;
    tests/research/test_dummy_two_store_temporal.py) ;;
    tests/research/run_ribasim_dummy_11.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-11 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_11_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_temporal_partition.py   tests/research/dummy_two_store_exchange.py   tests/research/dummy_two_store_management.py   tests/research/dummy_two_store_temporal.py   tests/research/test_dummy_two_store_temporal.py

python3 tests/research/test_dummy_two_store_temporal.py

echo "RIBASIM_DUMMY_11_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_11_GATE=PASS"

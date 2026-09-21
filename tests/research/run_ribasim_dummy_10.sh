#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="269fbe65f7f8febf0baa1df73a6c749abf43534b"
fail() {
  echo "RIBASIM_DUMMY_10_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-09 implementation base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_10_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_10_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_10_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_10_CONCEPT.md) ;;
    tests/research/dummy_two_store_management.py) ;;
    tests/research/test_dummy_two_store_management.py) ;;
    tests/research/run_ribasim_dummy_10.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-10 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_10_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_head_management_complementarity.py   tests/research/dummy_two_store_exchange.py   tests/research/dummy_two_store_management.py   tests/research/test_dummy_two_store_management.py

python3 tests/research/test_dummy_two_store_management.py

echo "RIBASIM_DUMMY_10_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_10_GATE=PASS"

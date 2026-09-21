#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="fe05668d943121bc30358a7c52eed43aa7f60afb"
fail() {
  echo "RIBASIM_DUMMY_03_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from preregistered DUMMY-03 base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_03_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_03_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_03_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_03_CONCEPT.md) ;;
    tests/research/dummy_head_exchange_diagnostic.py) ;;
    tests/research/test_dummy_head_exchange_diagnostic.py) ;;
    tests/research/run_ribasim_dummy_03.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-03 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_03_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_ribasim_reservoir.py   tests/research/dummy_threeway_water_coupling.py   tests/research/dummy_head_exchange_diagnostic.py   tests/research/test_dummy_head_exchange_diagnostic.py

python3 tests/research/test_dummy_head_exchange_diagnostic.py

echo "RIBASIM_DUMMY_03_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_03_GATE=PASS"

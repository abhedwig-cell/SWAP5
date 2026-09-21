#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="1c38b4216df576570a62c11800b17af5ab77df91"
fail() {
  echo "RIBASIM_DUMMY_05_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from preregistered DUMMY-05 base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_05_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_05_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_05_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_05_CONCEPT.md) ;;
    tests/research/dummy_head_management_complementarity.py) ;;
    tests/research/test_dummy_head_management_complementarity.py) ;;
    tests/research/run_ribasim_dummy_05.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-05 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_05_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_trapezoid_exchange_iteration.py   tests/research/dummy_head_management_complementarity.py   tests/research/test_dummy_head_management_complementarity.py

python3 tests/research/test_dummy_head_management_complementarity.py

echo "RIBASIM_DUMMY_05_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_05_GATE=PASS"

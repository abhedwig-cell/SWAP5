#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5"
fail() {
  echo "RIBASIM_DUMMY_01_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from preregistered canonical base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_01_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_01_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_01_RESULT.json) ;;
    tests/research/dummy_ribasim_reservoir.py) ;;
    tests/research/test_dummy_ribasim_01.py) ;;
    tests/research/run_ribasim_dummy_01.sh) ;;
    "") ;;
    *) fail "unexpected branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_01_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_ribasim_reservoir.py   tests/research/test_dummy_ribasim_01.py

python3 tests/research/test_dummy_ribasim_01.py

echo "RIBASIM_DUMMY_01_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_01_GATE=PASS"

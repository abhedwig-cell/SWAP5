#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="0bfb2a38efff430b159b6b21c1d3eca9395aba3d"
fail() {
  echo "RIBASIM_DUMMY_02_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from preregistered DUMMY-02 base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_02_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_02_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_02_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_02_CONCEPT.md) ;;
    tests/research/dummy_threeway_water_coupling.py) ;;
    tests/research/test_dummy_threeway_water_coupling.py) ;;
    tests/research/run_ribasim_dummy_02.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-02 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_02_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_ribasim_reservoir.py   tests/research/dummy_threeway_water_coupling.py   tests/research/test_dummy_threeway_water_coupling.py

python3 tests/research/test_dummy_threeway_water_coupling.py

echo "RIBASIM_DUMMY_02_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_02_GATE=PASS"

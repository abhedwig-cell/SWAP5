#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="c0c5e32834582b4dc5e8534de6102374bfcdd77e"
fail() {
  echo "RIBASIM_DUMMY_17_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-16 closeout base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_17_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_17_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_17_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_17_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/dummy_two_basin_shared_groundwater.py) ;;
    tests/research/test_dummy_two_basin_shared_groundwater.py) ;;
    tests/research/run_ribasim_dummy_17.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-17 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_17_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_two_basin_shared_groundwater.py   tests/research/test_dummy_two_basin_shared_groundwater.py

python3 tests/research/test_dummy_two_basin_shared_groundwater.py

echo "RIBASIM_DUMMY_17_NETWORK_TESTS=PASS"
echo "RIBASIM_DUMMY_17_GATE=PASS"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="a6bdd05e8df3493625b99c78ba500af111dfd86e"
fail() {
  echo "RIBASIM_DUMMY_15D_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from DUMMY-15D implementation authority base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_15D_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_15D_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_15D_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_15D_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/dummy_canopy_irrigation_ledger.py) ;;
    tests/research/test_dummy_canopy_irrigation_ledger.py) ;;
    tests/research/run_ribasim_dummy_15d.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-15D branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_15D_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_canopy_irrigation_ledger.py   tests/research/test_dummy_canopy_irrigation_ledger.py

python3 tests/research/test_dummy_canopy_irrigation_ledger.py

echo "RIBASIM_DUMMY_15D_CANOPY_TESTS=PASS"
echo "RIBASIM_DUMMY_15D_GATE=PASS"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="a84405a24373818e3ca1f3851391300ed73e7240"
fail() {
  echo "RIBASIM_DUMMY_15C_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from DUMMY-15C implementation authority base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_15C_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_15C_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_15C_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_15C_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/dummy_irrigation_event_realization.py) ;;
    tests/research/test_dummy_irrigation_event_realization.py) ;;
    tests/research/run_ribasim_dummy_15c.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-15C branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_15C_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_irrigation_event_realization.py   tests/research/test_dummy_irrigation_event_realization.py

python3 tests/research/test_dummy_irrigation_event_realization.py

echo "RIBASIM_DUMMY_15C_EVENT_POLICY_TESTS=PASS"
echo "RIBASIM_DUMMY_15C_GATE=PASS"

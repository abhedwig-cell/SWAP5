#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="3a82ed3c79db1b4ff6c54ad68724067e95072e94"
fail() {
  echo "RIBASIM_DUMMY_12_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from DUMMY-12 preregistration base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_12_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_12_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_12_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_12_CONCEPT.md) ;;
    tests/research/dummy_rootzone_demand.py) ;;
    tests/research/test_dummy_rootzone_demand.py) ;;
    tests/research/run_ribasim_dummy_12.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-12 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_12_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_rootzone_demand.py   tests/research/test_dummy_rootzone_demand.py

python3 tests/research/test_dummy_rootzone_demand.py

echo "RIBASIM_DUMMY_12_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_12_GATE=PASS"

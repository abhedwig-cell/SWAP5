#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="7484b2d614ad752baaf7c2811471949748ab87f3"
fail() {
  echo "RIBASIM_DUMMY_09_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from preregistered DUMMY-09 base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_09_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_09_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_09_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_09_CONCEPT.md) ;;
    tests/research/dummy_two_store_exchange.py) ;;
    tests/research/test_dummy_two_store_exchange.py) ;;
    tests/research/run_ribasim_dummy_09.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-09 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_09_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_two_store_exchange.py   tests/research/test_dummy_two_store_exchange.py

python3 tests/research/test_dummy_two_store_exchange.py

echo "RIBASIM_DUMMY_09_ANALYTIC_TESTS=PASS"
echo "RIBASIM_DUMMY_09_GATE=PASS"

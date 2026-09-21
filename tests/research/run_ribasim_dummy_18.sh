#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="3a25ae6f03c7f4324b49468e0c01e1d0dd442106"
fail() {
  echo "RIBASIM_DUMMY_18_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from DUMMY-18 implementation authority base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_18_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_18_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_18_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_18_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_18_AUTHORITY_MAP.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/dummy_real_model_authority_map.py) ;;
    tests/research/test_dummy_real_model_authority_map.py) ;;
    tests/research/run_ribasim_dummy_18.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-18 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_18_SOURCE_SCOPE=PASS"

python3 -m py_compile   tests/research/dummy_real_model_authority_map.py   tests/research/test_dummy_real_model_authority_map.py

python3 tests/research/test_dummy_real_model_authority_map.py

echo "RIBASIM_DUMMY_18_AUTHORITY_TESTS=PASS"
echo "RIBASIM_DUMMY_18_GATE=PASS"

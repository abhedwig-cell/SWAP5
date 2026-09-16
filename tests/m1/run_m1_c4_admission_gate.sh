#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=bfbb466678249811afc6a0800fd32a367818660f
SERIALIZER=src/adapter/mod_canonical_result_text_adapter.f90
EXPECTED_SERIALIZER_BLOB=410d722fbd6e0bcf7ad3a5cc1fc6c133dd95403a
QUALIFIED_HEAD=114d9c6c1a74436d3e3596ef0a90e8f8324a1ea2
QUALIFICATION_RUN=35091439497
QUALIFICATION_JOB=104778442363
QUALIFICATION_OUTPUT_SHA256=76be23588e266eba4a1f2e8de28b01814dc4137bd5be41216835d99e5389bae3

fail(){ echo "M1_C4_ADMISSION_FAIL $*" >&2; exit 1; }

[[ "$(git merge-base HEAD "$BASE")" == "$BASE" ]] || fail 'branch is not based on qualified canonical preimage'
echo 'M1_C4_ADMISSION_CANONICAL_PREIMAGE=PASS'

actual_serializer_blob="$(git hash-object "$SERIALIZER")"
[[ "$actual_serializer_blob" == "$EXPECTED_SERIALIZER_BLOB" ]] || \
  fail "serializer blob mismatch expected=$EXPECTED_SERIALIZER_BLOB actual=$actual_serializer_blob"
echo 'M1_C4_ADMISSION_EXACT_QUALIFIED_BLOB=PASS'

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$SERIALIZER" ]] || {
  echo 'M1_C4_ADMISSION_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'M1_C4_ADMISSION_SINGLE_PRODUCTION_DELTA=PASS'

check_lock() {
  local path="$1" expected="$2" base_blob head_blob
  base_blob="$(git rev-parse "$BASE:$path")"
  head_blob="$(git rev-parse "HEAD:$path")"
  [[ "$base_blob" == "$expected" ]] || fail "base dependency mismatch $path expected=$expected actual=$base_blob"
  [[ "$head_blob" == "$expected" ]] || fail "head dependency mismatch $path expected=$expected actual=$head_blob"
}

check_lock src/solver/mod_soil_water_accepted_step_direction_contract.f90 52698b1ad2350bf787862a053a49c7c73c3358f0
check_lock src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 95381d3124b185aa0fbafd1ea3da6179a841deda
check_lock src/transaction/mod_accepted_trajectory_directional_publication.f90 31bc721f333a77c52f6530b357af44c627f44629
check_lock src/runtime/mod_canonical_contracts.f90 3962c270a7579b7403764674302445fe15ef5f72
echo 'M1_C4_ADMISSION_DEPENDENCY_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/adapter/mod_canonical_result_text_adapter.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in p.splitlines()).lower()
assert 'type(canonical_result_t), intent(in) :: result' in code
assert 'canonical_state_t' not in code
assert 'transaction_state_t' not in code
assert 'intent(inout) :: result' not in code
assert 'intent(out) :: result' not in code
for forbidden in ('open(', 'read(', 'close(', 'newunit=', 'file=', 'get_command_argument', 'get_environment_variable'):
    assert forbidden not in code, forbidden
uses = [line.strip() for line in code.splitlines() if line.strip().startswith('use ')]
assert uses and all('iso_fortran_env' in line or 'mod_canonical_contracts' in line for line in uses), uses
print('M1_C4_ADMISSION_TYPED_READONLY_SURFACE=PASS')
print('M1_C4_ADMISSION_NO_FILE_PARSER_STATE_AUTHORITY=PASS')
PY

git diff --check "$BASE" -- "$SERIALIZER" tests/m1/run_m1_c4_admission_gate.sh

printf 'M1_C4_ADMISSION_INHERITED_QUALIFIED_HEAD=%s\n' "$QUALIFIED_HEAD"
printf 'M1_C4_ADMISSION_INHERITED_RUN=%s\n' "$QUALIFICATION_RUN"
printf 'M1_C4_ADMISSION_INHERITED_JOB=%s\n' "$QUALIFICATION_JOB"
printf 'M1_C4_ADMISSION_INHERITED_OUTPUT_SHA256=%s\n' "$QUALIFICATION_OUTPUT_SHA256"
echo 'M1_C4_ADMISSION_EVIDENCE_INHERITANCE=PASS'
echo 'M1_C4_CANONICAL_ADMISSION_GATE=PASS'

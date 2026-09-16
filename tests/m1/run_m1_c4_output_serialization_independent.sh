#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-m1-c4-independent-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=bfbb466678249811afc6a0800fd32a367818660f
SERIALIZER=src/adapter/mod_canonical_result_text_adapter.f90
TEST=tests/m1/test_m1_c4_output_serialization_independent.f90
EXPECTED_SERIALIZER_BLOB=410d722fbd6e0bcf7ad3a5cc1fc6c133dd95403a
EXPECTED_CONTRACT_BLOB=3962c270a7579b7403764674302445fe15ef5f72

fail(){ echo "M1_C4_INDEPENDENT_GATE_FAIL $*" >&2; exit 1; }

actual_serializer_blob="$(git hash-object "$SERIALIZER")"
[[ "$actual_serializer_blob" == "$EXPECTED_SERIALIZER_BLOB" ]] || \
  fail "serializer blob mismatch expected=$EXPECTED_SERIALIZER_BLOB actual=$actual_serializer_blob"
echo 'M1_C4_INDEPENDENT_EXACT_OWNER_BLOB=PASS'

actual_contract_blob="$(git rev-parse "HEAD:src/runtime/mod_canonical_contracts.f90")"
[[ "$actual_contract_blob" == "$EXPECTED_CONTRACT_BLOB" ]] || \
  fail "canonical contract blob mismatch expected=$EXPECTED_CONTRACT_BLOB actual=$actual_contract_blob"
echo 'M1_C4_INDEPENDENT_CANONICAL_CONTRACT_LOCK=PASS'

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$SERIALIZER" ]] || {
  echo 'M1_C4_INDEPENDENT_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'M1_C4_INDEPENDENT_SINGLE_PRODUCTION_DELTA=PASS'

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
assert ' save ' not in f' {code} '
uses = [line.strip() for line in code.splitlines() if line.strip().startswith('use ')]
assert uses
assert all('iso_fortran_env' in line or 'mod_canonical_contracts' in line for line in uses), uses
writes = [line.strip() for line in code.splitlines() if 'write(' in line]
assert writes and all('write(buffer,' in line for line in writes), writes
print('M1_C4_INDEPENDENT_TYPED_RESULT_ONLY_API=PASS')
print('M1_C4_INDEPENDENT_NO_PHYSICAL_STATE_AUTHORITY_STATIC=PASS')
print('M1_C4_INDEPENDENT_NO_FILE_OR_PARSER_AUTHORITY=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  "$SERIALIZER"
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o" || fail "compile O$opt $TEST"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for marker in \
    'M1_C4_INDEPENDENT_REPEAT_DETERMINISM=PASS' \
    'M1_C4_INDEPENDENT_RESULT_IDENTITY=PASS' \
    'M1_C4_INDEPENDENT_TYPED_READONLY_BOUNDARY=PASS' \
    'M1_C4_INDEPENDENT_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  echo "M1_C4_INDEPENDENT_RUNTIME_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output drift'
}

git diff --check "$BASE" -- "$SERIALIZER" "$TEST" tests/m1/run_m1_c4_output_serialization_independent.sh
cat "$BUILD/o0/output.txt"
echo "M1_C4_INDEPENDENT_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'M1_C4_INDEPENDENT_RUNTIME_O0_O2_IDENTITY=PASS'
echo 'M1_C4_OUTPUT_SERIALIZATION_INDEPENDENT_GATE=PASS'

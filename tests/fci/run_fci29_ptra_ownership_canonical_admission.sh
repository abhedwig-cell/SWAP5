#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci29-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

ORIGINAL_FCI28=06658d0b83206008dcaefba3b8d7e5c7f0c77538
BASE=4a2b7a82287a209dc8150dcb70c6c2d6e459c592
FVQ41=e0d6c9993d46bb858d84524bb290f3bb12e82ce4
EXPECTED_PRE_SRC=3fe4ccff367479e54ab5db106e5faf8b480d8ec0
EXPECTED_POST_SRC=223c54d5fd309f86ef50f9efd28e2c511e175577
EXPECTED_REFERENCE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
EXPECTED_FVQ41_TEST_BLOB=dfd1ddb9f1a4ce1a919311645fb727f2994d2f22
EXPECTED_OUTPUT_SHA=a9707200f4cbb258a502baf45f1ac9aa5d9d5a78205a56efc54bb1b63694b78f

git diff --quiet "$ORIGINAL_FCI28" "$BASE" -- || {
  echo 'FCI29_CANONICAL_DRIFT_REVERT_NOT_NET_IDENTICAL' >&2
  git diff --name-status "$ORIGINAL_FCI28" "$BASE" -- >&2
  exit 1
}
test "$(git rev-parse "$BASE":src)" = "$EXPECTED_PRE_SRC"
test "$(git rev-parse "$BASE":reference)" = "$EXPECTED_REFERENCE"
echo 'FCI29_CANONICAL_DRIFT_REVERT_NET_CONTENT_IDENTITY=PASS'

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90" ]] || {
  echo 'FCI29_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}

test "$(git rev-parse HEAD:src)" = "$EXPECTED_POST_SRC"
test "$(git rev-parse HEAD:reference)" = "$EXPECTED_REFERENCE"
echo 'FCI29_EXACT_SINGLE_SOURCE_POSTIMAGE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FCI29_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 11ef6182414af4fbe67eebec3d6f14742df04aca
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
check_blob src/runtime/mod_fmr_committed_restart.f90 19ea410e0ed48e65b5d73887a8e1dba59c7c4f37
check_blob src/runtime/mod_fmr_restart_state_contract.f90 f1359f97d02408d8b700b0c93fe961a6ba46742c
echo 'FCI29_FCI27_AND_FCI28_AUTHORITIES_PRESERVED=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90').read_text().lower()
for required in ['reference_et_demand_result_t', 'crop_root_uptake_input_t', 'validate_crop_root_uptake_input',
                 'potential_transpiration_cm_per_day']:
    assert required in p, required
for forbidden in ['reference_et_mm_per_day', 'vegetation_cover_fraction', 'crop_factor',
                  'co2_transpiration_factor', 'fmr_evaluate_shared_crop_root_uptake',
                  'fmr_evaluate_committed_root_uptake', 'mass_accounting', 'total_in', 'total_out',
                  'open(', 'read(', 'write(', 'save', 'allocatable']:
    assert forbidden not in p, forbidden
assert 'mod_reference_et_transpiration_process' not in p
print('FCI29_PTRA_AUTHORITY_BOUNDARY_STATIC=PASS')
print('FCI29_NO_ET_RECOMPUTE_ROOT_EXECUTION_OR_MASS_BOOKING=PASS')
PY

git show "$FVQ41":tests/fvq/test_fvq41_fmr26_reference_et_ptra_root_input_qualification.f90 > "$BUILD/fvq41_test.f90"
test "$(git hash-object "$BUILD/fvq41_test.f90")" = "$EXPECTED_FVQ41_TEST_BLOB"
echo 'FCI29_FROZEN_FVQ41_TEST_EXACT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/transaction/mod_transaction_reference.f90 -o "$OUT/mod_transaction_reference.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_canonical_contracts.f90 -o "$OUT/mod_canonical_contracts.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/mod_crop_root_uptake_input_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_reference_et_demand_process.f90 -o "$OUT/mod_reference_et_demand_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_reference_et_demand_binding.f90 -o "$OUT/mod_fmr_reference_et_demand_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 -o "$OUT/mod_fmr_reference_et_ptra_root_input_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    "$BUILD/fvq41_test.f90" -o "$OUT/fvq41_test.o"

  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" \
    "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_crop_root_uptake_input_contract.o" \
    "$OUT/mod_reference_et_demand_process.o" \
    "$OUT/mod_fmr_reference_et_demand_binding.o" \
    "$OUT/mod_fmr_reference_et_ptra_root_input_binding.o" \
    "$OUT/fvq41_test.o" \
    -o "$OUT/fvq41_test"

  "$OUT/fvq41_test" > "$OUT/output.txt" 2>&1
  grep -Fq 'FVQ41_ACTIVE_GRID_CASES=2304' "$OUT/output.txt"
  grep -Fq 'FVQ41_REFERENCE_ET_PTRA_ROOT_INPUT_QUALIFICATION PASS' "$OUT/output.txt"
  test "$(sha256sum "$OUT/output.txt" | cut -d' ' -f1)" = "$EXPECTED_OUTPUT_SHA"
  echo "FCI29_FROZEN_FVQ41_REPLAY_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FCI29_FROZEN_FVQ41_O0_O2_IDENTITY=PASS'
echo "FCI29_FROZEN_FVQ41_OUTPUT_SHA256=$EXPECTED_OUTPUT_SHA"
echo 'FCI29_PTRA_OWNERSHIP_CANONICAL_ADMISSION_GATE PASS'

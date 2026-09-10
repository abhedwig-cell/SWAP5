#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr26-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=0aa4f7ca88a1cd2f3cf7333a35946c4415d9258d
EXPECTED_SRC=src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$EXPECTED_SRC" ]] || {
  echo "FMR26_UNEXPECTED_PRODUCTION_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FMR26_PRODUCTION_DELTA_SINGLE_STATELESS_BINDING=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR26_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
[[ "$(git rev-parse 025e014eaa1f3148ec4f3f8c003ad65928cd4edd:src/process/mod_reference_et_transpiration_process.f90)" == \
   "497b42f2450a003a070dbc4020573866d1ef93b0" ]]
echo 'FMR26_CANONICAL_ET_ROOT_CONTRACT_AND_FROZEN_FWO18_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90').read_text()
low = p.lower()

required = [
    'reference_et_demand_result_t',
    'fmr_reference_et_binding_diagnostics_t',
    'crop_root_uptake_input_t',
    'validate_crop_root_uptake_input',
    'et_result%potential_transpiration_cm_per_day',
    'bound_input%potential_transpiration',
    'geometry_input%potential_transpiration',
    'incoming_ptra_ignored',
]
for token in required:
    assert token.lower() in low, token

for forbidden in [
    'reference_et_mm_per_day',
    'vegetation_cover_fraction',
    'crop_factor',
    'co2_transpiration_factor',
    'evaluate_restricted_reference_et_demand',
    'root_water_uptake',
    'kernel_committed_state_t',
    'mass_accounting',
    'total_in',
    'total_out',
    'headcalc',
    'newton',
    'jacobian',
    'open(',
    'read(',
    'write(',
    'save',
    'allocatable',
]:
    assert forbidden not in low, forbidden

assert '0.1_real64' not in low
assert '0.1d0' not in low
assert 'et_result%potential_transpiration_cm_per_day' in low
print('FMR26_NO_ET_FORMULA_RECOMPUTATION=PASS')
print('FMR26_NO_ROOT_UPTAKE_OR_MASS_EXECUTION=PASS')
print('FMR26_NO_PERSISTENT_BINDING_STATE=PASS')
PY

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
    tests/fmr/test_fmr26_reference_et_ptra_root_input_binding.f90 -o "$OUT/test_fmr26_reference_et_ptra_root_input_binding.o"
  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" \
    "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_crop_root_uptake_input_contract.o" \
    "$OUT/mod_reference_et_demand_process.o" \
    "$OUT/mod_fmr_reference_et_demand_binding.o" \
    "$OUT/mod_fmr_reference_et_ptra_root_input_binding.o" \
    "$OUT/test_fmr26_reference_et_ptra_root_input_binding.o" \
    -o "$OUT/test_fmr26_reference_et_ptra_root_input_binding"
  "$OUT/test_fmr26_reference_et_ptra_root_input_binding" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FMR26_FMR23_PTRA_AUTHORITY=PASS' \
    'FMR26_NON_PTRA_FIELDS_PRESERVED=PASS' \
    'FMR26_INCOMING_PTRA_IGNORED=PASS' \
    'FMR26_UPSTREAM_REJECTION_FAIL_CLOSED=PASS' \
    'FMR26_INVALID_ROOT_GEOMETRY_FAIL_CLOSED=PASS' \
    'FMR26_NONEMERGED_SEMANTICS=PASS' \
    'FMR26_ASSEMBLED_CONTRACT_FAIL_CLOSED=PASS' \
    'FMR26_STATELESS_A_B_A_IDENTITY=PASS' \
    'FMR26_REFERENCE_ET_PTRA_ROOT_INPUT_BINDING_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FMR26_PTRA_ROOT_INPUT_BINDING_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR26_PTRA_ROOT_INPUT_BINDING_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FMR26_PTRA_ROOT_INPUT_BINDING_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FMR26_REFERENCE_ET_PTRA_ROOT_INPUT_BINDING_GATE PASS'

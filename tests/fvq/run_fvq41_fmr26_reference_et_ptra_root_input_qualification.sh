#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq41-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

OWNER=e99e144b4f2bedcbb93d06af578cb409dc76f6c7

changed_src="$(git diff --name-only "$OWNER" -- src)"
[[ -z "$changed_src" ]] || {
  echo "FVQ41_UNEXPECTED_SOURCE_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FVQ41_NO_QUALIFICATION_SOURCE_CHANGES=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ41_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 11ef6182414af4fbe67eebec3d6f14742df04aca
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
echo 'FVQ41_FROZEN_AUTHORITY_BLOBS=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90').read_text()
low = p.lower()

required = [
    'reference_et_demand_result_t',
    'fmr_reference_et_binding_diagnostics_t',
    'crop_root_uptake_input_t',
    'validate_crop_root_uptake_input',
    'potential_transpiration_cm_per_day',
]
for token in required:
    assert token.lower() in low, token

for forbidden in [
    'reference_et_mm_per_day',
    'vegetation_cover_fraction',
    'crop_factor',
    'co2_transpiration_factor',
    'root_water_uptake_flux_result_t',
    'fmr_evaluate_shared_crop_root_uptake',
    'fmr_evaluate_committed_root_uptake',
    'mass_accounting',
    'total_in',
    'total_out',
    'open(',
    'read(',
    'write(',
    'save',
    'allocatable',
]:
    assert forbidden not in low, forbidden

assert 'mod_reference_et_transpiration_process' not in low
print('FVQ41_CANDIDATE_CONSUMES_ET_RESULT_NOT_ET_INPUTS=PASS')
print('FVQ41_NO_FWO18_PRODUCTION_DEPENDENCY=PASS')
print('FVQ41_NO_ROOT_UPTAKE_OR_MASS_EXECUTION=PASS')
print('FVQ41_NO_PERSISTENT_BINDING_STATE=PASS')
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
    tests/fvq/test_fvq41_fmr26_reference_et_ptra_root_input_qualification.f90 \
    -o "$OUT/test_fvq41_fmr26_reference_et_ptra_root_input_qualification.o"

  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" \
    "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_crop_root_uptake_input_contract.o" \
    "$OUT/mod_reference_et_demand_process.o" \
    "$OUT/mod_fmr_reference_et_demand_binding.o" \
    "$OUT/mod_fmr_reference_et_ptra_root_input_binding.o" \
    "$OUT/test_fvq41_fmr26_reference_et_ptra_root_input_qualification.o" \
    -o "$OUT/test_fvq41_fmr26_reference_et_ptra_root_input_qualification"

  "$OUT/test_fvq41_fmr26_reference_et_ptra_root_input_qualification" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FVQ41_ACTIVE_GRID_CASES=4608' \
    'FVQ41_INDEPENDENT_FROZEN_FORMULA_ORACLE=PASS' \
    'FVQ41_FMR23_RESULT_MATCHES_ORACLE=PASS' \
    'FVQ41_FMR26_EXACT_PTRA_FORWARDING=PASS' \
    'FVQ41_INCOMING_PTRA_NONAUTHORITY=PASS' \
    'FVQ41_ROOT_GEOMETRY_EXACT_PRESERVATION=PASS' \
    'FVQ41_NONEMERGED_ZERO_PTRA=PASS' \
    'FVQ41_FAIL_CLOSED_MATRIX=PASS' \
    'FVQ41_REFERENCE_ET_PTRA_ROOT_INPUT_QUALIFICATION PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done

  echo "FVQ41_INDEPENDENT_QUALIFICATION_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ41_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ41_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FVQ41_FMR26_REFERENCE_ET_PTRA_ROOT_INPUT_QUALIFICATION_GATE PASS'

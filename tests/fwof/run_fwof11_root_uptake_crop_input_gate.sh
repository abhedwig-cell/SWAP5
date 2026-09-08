#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof11-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=6e4ddecb585833f42c3e27fb121345a40b5fa880
NEW_SRC=src/crop/mod_crop_root_uptake_input_contract.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF11_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF11_PRODUCTION_DELTA_SINGLE_CROP_CONTRACT=PASS'

protected=(
  src/process/mod_root_water_uptake_process.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/kernel/mod_kernel_transactions.f90
  tests/fvq/test_fvq22_root_uptake_scientific_oracle.f90
  tests/fvq/test_fvq22_root_uptake_runtime_oracle.f90
  tests/fmr/test_fmr10_root_uptake_process_binding.f90
  tests/fmr/test_fmr10_root_uptake_runtime_bridge.f90
)
for path in "${protected[@]}"; do
  expected="$(git rev-parse "$BASE:$path")"
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF11_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
done
echo 'FWOF11_FMR10_FVQ22_FMR09_PROTECTED_LINEAGE=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/crop/mod_crop_root_uptake_input_contract.f90').read_text().lower()
for forbidden in [
    'mod_fmr_', 'mod_soil_water_solver', 'mod_process_hydraulic_view',
    'reference_richards', 'headcalc', 'mod_meteo', 'mod_cropdevelopment',
    'plant_interface', 'open(', 'close(', 'inquire(', 'read('
]:
    assert forbidden not in p, forbidden
for required in [
    'crop_root_uptake_input_t', 'crop_root_uptake_input_provider_t',
    'canonicalize_crop_root_uptake_input', 'validate_crop_root_uptake_input',
    'evaluate_crop_root_uptake_input', 'intent(in) :: self'
]:
    assert required in p, required
assert 'use, intrinsic :: ieee_arithmetic' in p
print('FWOF11_RUNTIME_SOLVER_LEGACY_IO_BOUNDARY_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fwof/test_fwof11_root_uptake_crop_input_contract.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/test.o" -o "$OUT/test_fwof11"
  "$OUT/test_fwof11" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF11_INACTIVE_CROP_CANONICALIZATION=PASS' \
    'FWOF11_ACTIVE_ZERO_ROOT_CANONICALIZATION=PASS' \
    'FWOF11_ACTIVE_ROOTED_NORMALIZED_DISTRIBUTION=PASS' \
    'FWOF11_INVALID_INPUTS_FAIL_CLOSED=PASS' \
    'FWOF11_PROVIDER_INTERFACE_STATUS_AND_CANONICALIZATION=PASS' \
    'FWOF11_RUNTIME_AND_SOLVER_INDEPENDENT_CONTRACT=PASS' \
    'FWOF11_ROOT_UPTAKE_CROP_INPUT_CONTRACT_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FWOF11_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF11_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF11_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF11_ROOT_UPTAKE_CROP_INPUT_GATE PASS'

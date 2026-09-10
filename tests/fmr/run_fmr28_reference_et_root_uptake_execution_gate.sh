#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr28-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=b982d4d0c8686e5c5fcb965633d34a4e0ba46fcf
EXPECTED_SRC=src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$EXPECTED_SRC" ]] || {
  echo 'FMR28_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FMR28_PRODUCTION_DELTA_SINGLE_COMPOSITION=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR28_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 11ef6182414af4fbe67eebec3d6f14742df04aca
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
echo 'FMR28_CANONICAL_OWNER_BLOBS_LOCKED=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/runtime/mod_fmr_reference_et_root_uptake_composition.f90').read_text().lower()
for required in [
    'fmr_bind_reference_et_ptra_to_root_input',
    'fmr_evaluate_shared_crop_root_uptake',
    'root_water_uptake_flux_result_t',
    'kernel_committed_state_t',
]:
    assert required in p, required
for forbidden in [
    'evaluate_macro_feddes_drought_uptake',
    'reference_et_mm_per_day',
    'vegetation_cover_fraction',
    'crop_factor',
    'co2_transpiration_factor',
    'pressure_head',
    'headcalc',
    'newton',
    'jacobian',
    'mass_accounting',
    'total_in',
    'total_out',
    'open(',
    'read(',
    'write(',
    'save',
]:
    assert forbidden not in p, forbidden
assert '0.1_real64' not in p
assert '0.1d0' not in p
print('FMR28_NO_ET_OR_ROOT_PHYSICS_REIMPLEMENTATION=PASS')
print('FMR28_NO_HYDRAULIC_INTERNAL_OR_MASS_LEDGER_ACCESS=PASS')
print('FMR28_NO_PERSISTENT_COMPOSITION_STATE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
DEPENDENCY_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_root_water_uptake_process.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${DEPENDENCY_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  src=src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
  obj="$OUT/mod_fmr_reference_et_root_uptake_composition.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
  objects+=("$obj")
  echo "FMR28_NEW_SOURCE_STRICT_WARNINGS_O${opt}=PASS"

  test=tests/fmr/test_fmr28_reference_et_root_uptake_execution.f90
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$test" -o "$OUT/test_fmr28.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr28.o" -o "$OUT/test_fmr28"
  "$OUT/test_fmr28" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FMR28_EXPLICIT_FCI29_FMR12_FMR10_CHAIN_BITWISE_IDENTITY=PASS' \
    'FMR28_STALE_INCOMING_PTRA_CANNOT_AFFECT_ROOT_UPTAKE=PASS' \
    'FMR28_UPSTREAM_ET_REJECTION_BLOCKS_ROOT_EXECUTION=PASS' \
    'FMR28_INVALID_ROOT_GEOMETRY_BLOCKS_ROOT_EXECUTION=PASS' \
    'FMR28_INACTIVE_CROP_DEPENDENCY_FREE_ZERO_ROUTE=PASS' \
    'FMR28_COMMITTED_STATE_READ_ONLY=PASS' \
    'FMR28_STATELESS_A_B_A_IDENTITY=PASS' \
    'FMR28_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_COMPOSITION_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FMR28_REFERENCE_ET_ROOT_UPTAKE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR28_REFERENCE_ET_ROOT_UPTAKE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FMR28_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FMR28_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_GATE PASS'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr12-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=b6a667035d5e900a7e2209e76491c1817ffd2043
NEW_SRC=src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FMR12_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FMR12_PRODUCTION_DELTA_SINGLE_RUNTIME_ADAPTER=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR12_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 fe1c1cf19d3702114cf7598e227d56f7dbc1e267
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
echo 'FMR12_FWO11_FMR10_FPM05_PROTECTED_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90').read_text().lower()
for forbidden in [
    'headcalc', 'reference_richards', 'mod_soil_water_solver', 'mod_process_hydraulic_view',
    'mod_meteo', 'mod_cropdevelopment', 'plant_interface', 'total_in', 'total_out', 'mass%',
    'open(', 'close(', 'inquire(', 'read(', 'canonicalize_crop_root_uptake_input'
]:
    assert forbidden not in p, forbidden
for required in [
    'mod_crop_root_uptake_input_contract', 'validate_crop_root_uptake_input',
    'mod_fmr_root_uptake_process_binding', 'fmr_evaluate_committed_root_uptake',
    'intent(in) :: shared_input', 'fmr_adapt_crop_root_uptake_input'
]:
    assert required in p, required
print('FMR12_RUNTIME_ADAPTER_BOUNDARY_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
OLD_MODULE_SRC=(
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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${OLD_MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/mod_crop_root_uptake_input_contract.o"
  objects+=("$OUT/mod_crop_root_uptake_input_contract.o")

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 -o "$OUT/mod_fmr_crop_root_uptake_input_adapter.o"
  objects+=("$OUT/mod_fmr_crop_root_uptake_input_adapter.o")

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr12_crop_root_uptake_input_adapter.f90 -o "$OUT/test_fmr12.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr12.o" -o "$OUT/test_fmr12"
  "$OUT/test_fmr12" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FMR12_INACTIVE_SHARED_DTO_PRESERVES_FMR10_DEPENDENCY_FREE_ROUTE=PASS' \
    'FMR12_ACTIVE_ZERO_ROOT_EXACT_MAPPING=PASS' \
    'FMR12_ACTIVE_ROOTED_FIELD_FOR_FIELD_MAPPING=PASS' \
    'FMR12_WRAPPER_BITWISE_EQUIVALENT_TO_DIRECT_FMR10=PASS' \
    'FMR12_COMMITTED_AND_CROP_INPUT_READ_ONLY=PASS' \
    'FMR12_INVALID_SHARED_DTO_FAILS_BEFORE_FMR10=PASS' \
    'FMR12_A_B_A_DETERMINISM=PASS' \
    'FMR12_CROP_ROOT_UPTAKE_INPUT_ADAPTER_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FMR12_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR12_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FMR12_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FMR12_CROP_ROOT_UPTAKE_INPUT_ADAPTER_GATE PASS'

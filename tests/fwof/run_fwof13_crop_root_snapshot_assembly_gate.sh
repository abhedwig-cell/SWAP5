#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof13-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=9d4ce9336be3f4e6bc316bd580b359486d57fac6
NEW_SRC=src/crop/mod_crop_root_uptake_input_assembly.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF13_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF13_PRODUCTION_DELTA_SINGLE_CROP_ASSEMBLY=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF13_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 fe1c1cf19d3702114cf7598e227d56f7dbc1e267
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
echo 'FWOF13_FWO11_FMR12_FMR10_PROTECTED_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/crop/mod_crop_root_uptake_input_assembly.f90').read_text().lower()
for forbidden in [
    'mod_fmr_', 'mod_soil_water_solver', 'mod_process_hydraulic_view', 'reference_richards',
    'headcalc', 'mod_meteo', 'mod_cropdevelopment', 'plant_interface',
    'total_in', 'total_out', 'mass%', 'open(', 'close(', 'inquire(', 'read(',
    't1900', 'daystart', 'dayend', 'calendar_'
]:
    assert forbidden not in p, forbidden
for required in [
    'crop_root_state_view_t', 'root_uptake_et_result_t',
    'assemble_crop_root_uptake_input', 'validate_crop_root_state_view',
    'mod_crop_root_uptake_input_contract', 'validate_crop_root_uptake_input',
    'intent(in) :: snapshot', 'intent(in) :: et_result'
]:
    assert required in p, required
print('FWOF13_CROP_ET_DATA_SEPARATION_STATIC=PASS')
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

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/crop_contract.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/crop/mod_crop_root_uptake_input_assembly.f90 -o "$OUT/crop_assembly.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fwof/test_fwof13_crop_root_snapshot_assembly.f90 -o "$OUT/test_pure.o"
  gfortran -O"$opt" "$OUT/crop_contract.o" "$OUT/crop_assembly.o" "$OUT/test_pure.o" -o "$OUT/test_pure"
  "$OUT/test_pure" > "$OUT/pure.txt" 2>&1 || { cat "$OUT/pure.txt" >&2; exit 1; }

  for marker in \
    'FWOF13_INACTIVE_VIEW_IGNORES_INVALID_ET_AND_EMITS_CANONICAL_DTO=PASS' \
    'FWOF13_NONCANONICAL_INACTIVE_SNAPSHOT_FAILS_CLOSED=PASS' \
    'FWOF13_ACTIVE_ZERO_ROOT_EXACT_ASSEMBLY=PASS' \
    'FWOF13_ACTIVE_ROOTED_EXACT_ASSEMBLY=PASS' \
    'FWOF13_SNAPSHOT_AND_ET_RESULT_READ_ONLY=PASS' \
    'FWOF13_ACTIVE_INVALID_ET_FAILS_CLOSED=PASS' \
    'FWOF13_INVALID_ROOT_SNAPSHOT_FAILS_BEFORE_ET=PASS' \
    'FWOF13_A_B_A_ASSEMBLY_IDENTITY=PASS' \
    'FWOF13_CROP_ROOT_SNAPSHOT_ASSEMBLY_TEST PASS'; do
    grep -Fq "$marker" "$OUT/pure.txt"
  done

  BR="$OUT/bridge"
  mkdir -p "$BR"
  objects=()
  for src in "${OLD_MODULE_SRC[@]}"; do
    obj="$BR/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$BR" -I "$BR" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$BR" -I "$BR" \
    -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$BR/crop_contract.o"
  objects+=("$BR/crop_contract.o")
  gfortran "${STRICT[@]}" -O"$opt" -J "$BR" -I "$BR" \
    -c src/crop/mod_crop_root_uptake_input_assembly.f90 -o "$BR/crop_assembly.o"
  objects+=("$BR/crop_assembly.o")
  gfortran "${STRICT[@]}" -O"$opt" -J "$BR" -I "$BR" \
    -c src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 -o "$BR/fmr12_adapter.o"
  objects+=("$BR/fmr12_adapter.o")
  gfortran "${STRICT[@]}" -O"$opt" -J "$BR" -I "$BR" \
    -c tests/fwof/test_fwof13_fmr12_bridge.f90 -o "$BR/test_bridge.o"
  gfortran -O"$opt" "${objects[@]}" "$BR/test_bridge.o" -o "$BR/test_bridge"
  "$BR/test_bridge" > "$OUT/bridge.txt" 2>&1 || { cat "$OUT/bridge.txt" >&2; exit 1; }

  grep -Fq 'FWOF13_FMR12_TO_FMR10_BITWISE_IDENTITY=PASS' "$OUT/bridge.txt"
  grep -Fq 'FWOF13_DOWNSTREAM_COMMITTED_SNAPSHOT_ET_READ_ONLY=PASS' "$OUT/bridge.txt"
  grep -Fq 'FWOF13_FMR12_BRIDGE_TEST PASS' "$OUT/bridge.txt"

  cat "$OUT/pure.txt" "$OUT/bridge.txt" > "$OUT/output.txt"
  echo "FWOF13_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF13_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF13_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF13_CROP_ROOT_SNAPSHOT_ASSEMBLY_GATE PASS'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr10-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=1b94f3d1d57a8c2b5e5b44b72174b8a746d851ce
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/runtime/mod_fmr_root_uptake_process_binding.f90" ]] || {
  echo 'FMR10_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FMR10_PRODUCTION_DELTA_SINGLE_RUNTIME_BINDING=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR10_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/solver/mod_soil_water_solver_contract.f90 0a57b07712f93538cbfaf9130838682307cede09
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 fe1c1cf19d3702114cf7598e227d56f7dbc1e267
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/process/mod_irrigation_process.f90 c0755c1e0d0b7ca1a35e73cf26158c29e9940aec
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/legacy/b1_10_port/headcalc.f90 420fe2996199e6d3f162b7669957e1a95919f353
check_blob src/adapter/mod_b110_serialized_context_binding.f90 1818338d088ee61a3a1dd5220542e6650ba673ac

echo 'FMR10_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_root_uptake_process_binding.f90').read_text()
for forbidden in ['HeadCalc','headcalc','MOD_meteo','MOD_cropdevelopment','plant_interface','fmr_b110_physical_forcing_t','total_in','total_out','mass%']:
    assert forbidden not in p, forbidden
assert 'kernel_committed_state_t' in p
assert 'fmr_build_committed_process_hydraulic_view' in p
assert 'evaluate_macro_feddes_drought_uptake' in p
assert 'crop_emerged' in p
assert 'inactive_crop_zero_route' in p
print('FMR10_RUNTIME_BINDING_BOUNDARY_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
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
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  for test in \
    tests/fmr/test_fmr10_root_uptake_process_binding.f90 \
    tests/fmr/test_fmr10_root_uptake_runtime_bridge.f90 \
    tests/fvq/test_fvq22_root_uptake_scientific_oracle.f90 \
    tests/fvq/test_fvq22_root_uptake_runtime_oracle.f90; do
      name="$(basename "${test%.*}")"
      gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$test" -o "$OUT/$name.o"
      gfortran -O"$opt" "${objects[@]}" "$OUT/$name.o" -o "$OUT/$name"
      "$OUT/$name" > "$OUT/$name.txt" 2>&1 || { cat "$OUT/$name.txt" >&2; exit 1; }
  done

  for marker in \
    'FMR10_INACTIVE_CROP_NO_COMMITTED_VIEW_OR_DISTRIBUTION_DEPENDENCY=PASS' \
    'FMR10_ACTIVE_BINDING_DIRECT_PROCESS_BITWISE_IDENTITY=PASS' \
    'FMR10_DYNAMIC_ROOT_DISTRIBUTION_PASS_THROUGH=PASS' \
    'FMR10_COMMITTED_STATE_READ_ONLY=PASS' \
    'FMR10_INVALID_ACTIVE_CROP_INPUT_FAIL_CLOSED=PASS' \
    'FMR10_BINDING_A_B_A_IDENTITY=PASS' \
    'FMR10_ROOT_UPTAKE_PROCESS_BINDING_TEST PASS'; do
      grep -Fq "$marker" "$OUT/test_fmr10_root_uptake_process_binding.txt"
  done

  for marker in \
    'FMR10_BINDING_OUTPUT_TO_FMR09_ROOT_FORCING=PASS' \
    'FMR10_BINDING_AUTHORITATIVE_ROOT_MASS_EXACTLY_ONCE=PASS' \
    'FMR10_BINDING_BOOKS_NO_SEPARATE_MASS=PASS' \
    'FMR10_BINDING_BALANCED_HYDRAULIC_IDENTITY=PASS' \
    'FMR10_BINDING_HARD_MASS_CONSERVATION=PASS' \
    'FMR10_ROOT_UPTAKE_RUNTIME_BRIDGE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/test_fmr10_root_uptake_runtime_bridge.txt"
  done

  cat "$OUT/test_fmr10_root_uptake_process_binding.txt" "$OUT/test_fmr10_root_uptake_runtime_bridge.txt" > "$OUT/fmr10_output.txt"
  cat "$OUT/test_fvq22_root_uptake_scientific_oracle.txt" "$OUT/test_fvq22_root_uptake_runtime_oracle.txt" > "$OUT/fvq22_output.txt"
  echo "FMR10_O${opt}=PASS"
done

cmp "$BUILD/o0/fmr10_output.txt" "$BUILD/o2/fmr10_output.txt"
cmp "$BUILD/o0/fvq22_output.txt" "$BUILD/o2/fvq22_output.txt"
echo 'FMR10_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FMR10_FVQ22_O0_O2_OUTPUT_IDENTITY=PASS'

fvq22_hash="$(sha256sum "$BUILD/o0/fvq22_output.txt" | cut -d' ' -f1)"
[[ "$fvq22_hash" == "482f0e09bacaeb9428c322734a540ece0738f0c636e3b2db018df344cfff8c5a" ]] || {
  echo "FMR10_FVQ22_OUTPUT_HASH_MISMATCH $fvq22_hash" >&2
  exit 1
}
echo 'FMR10_FVQ22_SCIENTIFIC_OUTPUT_HASH=PASS'
cat "$BUILD/o0/fmr10_output.txt"
echo "FMR10_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/fmr10_output.txt" | cut -d' ' -f1)"
echo 'FMR10_ROOT_UPTAKE_PROCESS_BINDING_GATE PASS'

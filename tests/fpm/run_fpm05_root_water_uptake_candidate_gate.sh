#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm05-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=f7cdccf11d21c31494b328251b001d474170c0c7
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_root_water_uptake_process.f90" ]] || {
  echo "FPM05_UNEXPECTED_PRODUCTION_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM05_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM05_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/solver/mod_soil_water_solver_contract.f90 0a57b07712f93538cbfaf9130838682307cede09
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 fe1c1cf19d3702114cf7598e227d56f7dbc1e267
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/process/mod_irrigation_process.f90 c0755c1e0d0b7ca1a35e73cf26158c29e9940aec
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383

echo 'FPM05_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/process/mod_root_water_uptake_process.f90').read_text()
for forbidden in ['HeadCalc', 'headcalc', 'open(', 'read(', 'write(unit', 'MOD_rootextraction', 'legacy_qrot']:
    assert forbidden not in p, forbidden
assert 'process_hydraulic_view_t' in p
assert 'root_extraction_sink' in p
assert 'potential_transpiration' in p
assert 'hlim3 = parameters%hlim3h +' in p
assert 'alpdry = (hlim4 - pressure_head) / (hlim4 - hlim3)' in p
print('FPM05_PROCESS_BOUNDARY_STATIC=PASS')
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

  for test in tests/fpm/test_fpm05_macro_feddes_root_uptake.f90 tests/fpm/test_fpm05_root_uptake_runtime_bridge.f90; do
    name="$(basename "${test%.*}")"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$test" -o "$OUT/$name.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/$name.o" -o "$OUT/$name"
    "$OUT/$name" > "$OUT/$name.txt" 2>&1 || { cat "$OUT/$name.txt" >&2; exit 1; }
  done

  for marker in \
    'FPM05_MACRO_FEDDES_SOURCE_EQUATIONS=PASS' \
    'FPM05_HLIM3_BRANCH_BOUNDARIES=PASS' \
    'FPM05_LEGACY_EARLY_EXIT_ZERO_ROUTES=PASS' \
    'FPM05_INVALID_DOMAIN_FAIL_CLOSED=PASS' \
    'FPM05_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM05_MACRO_FEDDES_ROOT_UPTAKE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/test_fpm05_macro_feddes_root_uptake.txt"
  done

  for marker in \
    'FPM05_COMMITTED_HYDRAULIC_VIEW_PROCESS_READ=PASS' \
    'FPM05_PROCESS_QROT_RUNTIME_BRIDGE=PASS' \
    'FPM05_PROCESS_ROOT_MASS_EXACTLY_ONCE=PASS' \
    'FPM05_PROCESS_BRIDGE_HARD_MASS=PASS' \
    'FPM05_PROCESS_RUNTIME_BRIDGE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/test_fpm05_root_uptake_runtime_bridge.txt"
  done

  cat "$OUT/test_fpm05_macro_feddes_root_uptake.txt" "$OUT/test_fpm05_root_uptake_runtime_bridge.txt" > "$OUT/output.txt"
  echo "FPM05_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/test_fpm05_macro_feddes_root_uptake.txt" "$BUILD/o2/test_fpm05_macro_feddes_root_uptake.txt"
cmp "$BUILD/o0/test_fpm05_root_uptake_runtime_bridge.txt" "$BUILD/o2/test_fpm05_root_uptake_runtime_bridge.txt"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM05_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM05_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM05_ROOT_WATER_UPTAKE_CANDIDATE_GATE PASS'

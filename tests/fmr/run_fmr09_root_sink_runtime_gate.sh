#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr09-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || { echo "FMR09_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2; exit 1; }
}

# Exact F-SI11 owner-qualified solver seam.
check_blob src/solver/mod_soil_water_solver_contract.f90 0a57b07712f93538cbfaf9130838682307cede09
check_blob src/legacy/b1_10_port/headcalc.f90 420fe2996199e6d3f162b7669957e1a95919f353
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
# F-SI10 drainage/irrigation provider remains unchanged.
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
# Exact existing process/runtime contracts remain fixed except the F-MR09 backend owner edit.
check_blob src/process/mod_irrigation_process.f90 c0755c1e0d0b7ca1a35e73cf26158c29e9940aec
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 fe1c1cf19d3702114cf7598e227d56f7dbc1e267

echo 'FMR09_SOURCE_LOCKS PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
assert 'if (self%root_extraction_active .and. .not. associated(self%root_sink)) return' in p
assert 'if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return' in p
assert 'if (any(forcing%root_extraction_sink < 0.0_real64)) return' in p
assert 'if (any(abs(forcing%root_extraction_sink) > 0.0_real64)) return' in p
assert 'request%evaluation%root_sink => self%root_sink' in p
assert 'total_out = total_out + value' in p
print('FMR09_FAIL_CLOSED_SOURCE_POLICY PASS')
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
  src/process/mod_irrigation_process.f90
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
    tests/fmr/test_fmr09_root_sink_runtime.f90 \
    tests/fpm/test_fpm03_ssdi_runtime_mass.f90 \
    tests/fmr/test_fmr07_committed_process_hydraulic_view.f90 \
    tests/fmr/test_fmr06_snow_smoke.f90; do
      name="$(basename "${test%.*}")"
      gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$test" -o "$OUT/$name.o"
      gfortran -O"$opt" "${objects[@]}" "$OUT/$name.o" -o "$OUT/$name"
      "$OUT/$name" > "$OUT/$name.txt" 2>&1 || { cat "$OUT/$name.txt" >&2; exit 1; }
  done

  grep -Fq 'FMR09_ROOT_SINK_EXACTLY_ONCE=PASS' "$OUT/test_fmr09_root_sink_runtime.txt"
  grep -Fq 'FMR09_BALANCED_ROOT_SSDI_STATE_IDENTITY=PASS' "$OUT/test_fmr09_root_sink_runtime.txt"
  grep -Fq 'FMR09_HARD_MASS_BALANCE=PASS' "$OUT/test_fmr09_root_sink_runtime.txt"
  grep -Fq 'FMR09_ROOT_SINK_RUNTIME_TEST PASS' "$OUT/test_fmr09_root_sink_runtime.txt"
  grep -Fq 'FPM03_SSDI_AUTHORITATIVE_MASS_EXACTLY_ONCE=PASS' "$OUT/test_fpm03_ssdi_runtime_mass.txt"
  grep -Fq 'FMR07_COMMITTED_PROCESS_HYDRAULIC_VIEW PASS' "$OUT/test_fmr07_committed_process_hydraulic_view.txt"
  grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$OUT/test_fmr06_snow_smoke.txt"
  grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$OUT/test_fmr06_snow_smoke.txt"
  grep -Fq 'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' "$OUT/test_fmr06_snow_smoke.txt"

  cat "$OUT/test_fmr09_root_sink_runtime.txt" \
      "$OUT/test_fpm03_ssdi_runtime_mass.txt" \
      "$OUT/test_fmr07_committed_process_hydraulic_view.txt" \
      "$OUT/test_fmr06_snow_smoke.txt" > "$OUT/output.txt"
  echo "FMR09_O${opt}=PASS"
done

cmp "$BUILD/o0/test_fmr09_root_sink_runtime.txt" "$BUILD/o2/test_fmr09_root_sink_runtime.txt"
cmp "$BUILD/o0/test_fpm03_ssdi_runtime_mass.txt" "$BUILD/o2/test_fpm03_ssdi_runtime_mass.txt"
cmp "$BUILD/o0/test_fmr07_committed_process_hydraulic_view.txt" "$BUILD/o2/test_fmr07_committed_process_hydraulic_view.txt"
cmp "$BUILD/o0/test_fmr06_snow_smoke.txt" "$BUILD/o2/test_fmr06_snow_smoke.txt"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"

echo 'FMR09_ROOT_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FMR09_FIXED_IRRIGATION_REGRESSION=PASS'
echo 'FMR09_COMMITTED_HYDRAULIC_VIEW_REGRESSION=PASS'
echo 'FMR09_SNOW_REGRESSION=PASS'
echo 'FMR09_FULL_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FMR09_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FMR09_ROOT_SINK_RUNTIME_GATE PASS'

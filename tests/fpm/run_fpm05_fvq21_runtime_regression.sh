#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm05-fvq21-regression-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM05_FVQ21_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

# Downstream regression intentionally allows the new F-PM05 process module,
# but every production source file that defined the independently qualified
# F-VQ21 root-sink runtime remains immutable.
check_blob src/solver/mod_soil_water_solver_contract.f90 0a57b07712f93538cbfaf9130838682307cede09
check_blob src/legacy/b1_10_port/headcalc.f90 420fe2996199e6d3f162b7669957e1a95919f353
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 fe1c1cf19d3702114cf7598e227d56f7dbc1e267
check_blob src/adapter/mod_b110_serialized_context_binding.f90 1818338d088ee61a3a1dd5220542e6650ba673ac
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/process/mod_irrigation_process.f90 c0755c1e0d0b7ca1a35e73cf26158c29e9940aec
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf

echo 'FPM05_FVQ21_RUNTIME_SOURCE_LOCKS=PASS'

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fvq/test_fvq21_root_sink_runtime_oracle.f90 -o "$OUT/fvq21.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fvq21.o" -o "$OUT/fvq21"
  "$OUT/fvq21" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FVQ21_NODEWISE_ROOT_QSSDI_HYDRAULIC_CANCELLATION=PASS' \
    'FVQ21_ROOT_AUTHORITATIVE_TOTAL_OUT_EXACTLY_ONCE=PASS' \
    'FVQ21_QSSDI_AUTHORITATIVE_TOTAL_IN_EXACTLY_ONCE=PASS' \
    'FVQ21_HARD_MASS_CONSERVATION=PASS' \
    'FVQ21_ROOT_ROLLBACK_REPLAY=PASS' \
    'FVQ21_ROOT_A_B_A_IDENTITY=PASS' \
    'FVQ21_INACTIVE_NONZERO_ROOT_FAIL_CLOSED=PASS' \
    'FVQ21_NEGATIVE_ROOT_FAIL_CLOSED=PASS' \
    'FVQ21_ROOT_SINK_RUNTIME_SCIENTIFIC_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM05_FVQ21_RUNTIME_REGRESSION_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM05_FVQ21_RUNTIME_REGRESSION_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FPM05_FVQ21_RUNTIME_ORACLE_REGRESSION PASS'

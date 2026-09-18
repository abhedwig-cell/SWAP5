#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=15c1c527951a42aab3dd5919a28e0c78360c5558
PREREG=da411caaf262eee2fe0900ac5a93296bbba34351
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0ta3-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0TA3_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"
mapfile -t SRC_DELTA < <(git diff --name-only "$BASE"...HEAD -- src)
EXPECTED=(
  src/runtime/mod_canonical_interval_runtime.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/transaction/mod_transaction_reference.f90
)
if [[ "${SRC_DELTA[*]}" != "${EXPECTED[*]}" ]]; then
  printf 'observed source delta:\n%s\n' "${SRC_DELTA[*]}" >&2
  fail "source allowlist mismatch"
fi
git diff --quiet "$BASE"...HEAD -- reference || fail "reference tree changed"
grep -Fq 'TX_TEMPORAL_REFERENCE_FLOOR_FIXED_RESOLUTION = 3' src/transaction/mod_transaction_reference.f90 || fail "temporal mode missing"
grep -Fq 'TX_ROUTE_REFERENCE_FLOOR_FIXED = 3' src/transaction/mod_transaction_reference.f90 || fail "route missing"
grep -Fq 'procedure, public :: run_reference_floor_trial' src/runtime/mod_fmr_serialized_reference_backend.f90 || fail "dedicated FMR entrypoint missing"
grep -Fq '.not. self%model%reference_floor_qualification_active' src/runtime/mod_fmr_serialized_reference_backend.f90 || fail "ordinary activation guard missing"
grep -Fq 'self%model%soil_water_selection%uses_reference()' src/runtime/mod_fmr_serialized_reference_backend.f90 || fail "Reference-only guard missing"
echo 'F_ROM0TA3_SOURCE_SCOPE=PASS'
echo 'F_ROM0TA3_REFERENCE_TREE_IMMUTABLE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/tx-o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT"     src/transaction/mod_transaction_reference.f90     tests/rom/test_f_rom0ta3_reference_floor_transaction.f90     -o "$OUT/test"
  "$OUT/test" | tee "$OUT/output.txt"
  grep -Fq 'F_ROM0TA3_FIXED_SAMPLE_ACCEPT=PASS' "$OUT/output.txt" || fail "transaction accept marker O$opt"
  grep -Fq 'F_ROM0TA3_SOLVER_FAILURE_NO_DT_REDUCTION=PASS' "$OUT/output.txt" || fail "solver failure marker O$opt"
  grep -Fq 'F_ROM0TA3_MASS_FAILURE_NO_DT_REDUCTION=PASS' "$OUT/output.txt" || fail "mass failure marker O$opt"
  grep -Fq 'F_ROM0TA3_TRANSACTION_GATE=PASS' "$OUT/output.txt" || fail "transaction gate O$opt"
done
cmp "$BUILD/tx-o0/output.txt" "$BUILD/tx-o2/output.txt" || fail "transaction O0/O2 drift"
echo 'F_ROM0TA3_TRANSACTION_O0_O2_IDENTITY=PASS'

MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)

for opt in 0 2; do
  OUT="$BUILD/fmr-o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT"     -c tests/rom/test_f_rom0ta3_reference_floor_fmr_boundary.f90 -o "$OUT/floor_test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/floor_test.o" -o "$OUT/floor_test"
  "$OUT/floor_test" > "$OUT/floor_output.txt" 2>&1 || { cat "$OUT/floor_output.txt" >&2; fail "FMR floor runtime O$opt"; }
  cat "$OUT/floor_output.txt"
  for marker in     'F_ROM0TA3_ORDINARY_FMR_FAIL_CLOSED=PASS'     'F_ROM0TA3_DEDICATED_REFERENCE_FLOOR_COMMIT=PASS'     'F_ROM0TA3_QUALIFICATION_CONTEXT_EPHEMERAL=PASS'     'F_ROM0TA3_FMR_BOUNDARY_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/floor_output.txt" || fail "missing floor marker O$opt $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90 -o "$OUT/fmr44r.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr44r.o" -o "$OUT/fmr44r"
  "$OUT/fmr44r" > "$OUT/fmr44r_output.txt" 2>&1 || { cat "$OUT/fmr44r_output.txt" >&2; fail "FMR44R regression O$opt"; }
  grep -Fq 'FMR44R_MODE2_EQUILIBRIUM_TRANSACTION=PASS' "$OUT/fmr44r_output.txt" || fail "external full-half regression O$opt"
  grep -Fq 'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS' "$OUT/fmr44r_output.txt" || fail "model certificate regression O$opt"
  grep -Fq 'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS' "$OUT/fmr44r_output.txt" || fail "FMR44R gate O$opt"
  echo "F_ROM0TA3_EXISTING_TEMPORAL_MODES_REGRESSION_O${opt}=PASS"
done
cmp "$BUILD/fmr-o0/floor_output.txt" "$BUILD/fmr-o2/floor_output.txt" || fail "FMR floor O0/O2 drift"
cmp "$BUILD/fmr-o0/fmr44r_output.txt" "$BUILD/fmr-o2/fmr44r_output.txt" || fail "FMR44R O0/O2 drift"
echo 'F_ROM0TA3_FMR_O0_O2_IDENTITY=PASS'
echo 'F_ROM0TA3_EXISTING_TEMPORAL_MODES_PRESERVED=PASS'

git diff --check "$BASE"...HEAD
echo 'F_ROM0TA3_DIFF_CHECK=PASS'
echo 'F_ROM0TA3_CAPABILITY_GATE=PASS'

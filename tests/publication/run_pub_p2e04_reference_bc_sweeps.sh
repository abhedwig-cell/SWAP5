#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e04-bc-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail() { echo "PUB_P2E04_BC_GATE_FAIL $*" >&2; exit 1; }
TEST=tests/publication/test_pub_p2e04_reference_bc_sweeps.f90
PREREG=docs/publication/P2E04_REFERENCE_BALANCE_ADJUDICATION_PREREGISTRATION.json
TARGETS=docs/publication/P2E04_STAGE_BC_TARGET_CONSTRUCTION.json
[[ -f "$PREREG" && -f "$TARGETS" ]] || fail 'missing frozen Stage B/C authority'
grep -Fq '"max_iterations": [8, 16, 32, 64]' "$PREREG" || fail 'iteration ladder changed'
grep -Fq '"total_balance_tolerance_cm": [1e-12, 1.25e-12, 1.5e-12, 2e-12, 4e-12, 8e-12, 1.6e-11]' "$PREREG" || fail 'total tolerance ladder changed'
grep -Fq '"scope_boundary": "The Stage-A census result is not used to choose or alter these targets.' "$TARGETS" || fail 'post-census target firewall missing'
[[ -z "$(git diff --name-only -- src reference)" ]] || fail 'production/reference source dirty'
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
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
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
)
for forbidden in src/solver/mod_rossfast_d3r_table_kernel.f90 src/solver/mod_rossfast_d3r_table_provider.f90 src/solver/mod_rossfast_d3r_soil_water_solver.f90 src/runtime/mod_fmr_rossfast_solver_selection_binding.f90; do
  for source in "${MODULE_SRC[@]}"; do [[ "$source" != "$forbidden" ]] || fail "RossFast numerical source entered build: $forbidden"; done
done
for opt in 0 2; do
  OUT="$BUILD/o$opt"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"; extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt"
  for marker in 'PUB_P2E04_ROSSFAST_SOLVER_EXECUTED=FALSE' 'PUB_P2E04_PRODUCTION_TOLERANCE_CHANGED=FALSE' 'PUB_P2E04_ROSSFAST_THRESHOLD_FROZEN=FALSE' 'PUB_P2E04_STAGE_BC_SWEEPS=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  [[ "$(grep -c '^PUB_P2E04_TARGET_BEGIN=' "$OUT/output.txt")" -eq 5 ]] || fail "O$opt target count"
  [[ "$(grep -c '^PUB_P2E04_STAGE_B|' "$OUT/output.txt")" -eq 20 ]] || fail "O$opt Stage B count"
  [[ "$(grep -c '^PUB_P2E04_STAGE_C|' "$OUT/output.txt")" -eq 35 ]] || fail "O$opt Stage C count"
  cat "$OUT/output.txt"
  echo "PUB_P2E04_BC_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail 'O0/O2 Stage B/C drift'; }
echo "PUB_P2E04_BC_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E04_REFERENCE_BC_GATE=PASS'

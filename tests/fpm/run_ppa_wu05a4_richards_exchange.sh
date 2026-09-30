#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05a4-richards-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_WU05A4_RICHARDS_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/runtime/mod_macropore_continuation_state.f90
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
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  research/macropore/mod_ppa_wu05a4_fixed_exchange_provider.f90
  research/macropore/mod_ppa_wu05a4_r2_macropore_process.f90
  research/macropore/mod_ppa_wu05a4_outer_coupling_controller.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_outer_controller.f90 -o "$OUT/test_controller.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_controller.o" -o "$OUT/test_controller"
  "$OUT/test_controller" > "$OUT/controller.txt"
  cat "$OUT/controller.txt"
  grep -Fq 'PPA_WU05A4_OUTER_CONTROLLER=PASS' "$OUT/controller.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_outer_controller_richards.f90 -o "$OUT/test_controller_richards.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_controller_richards.o" -o "$OUT/test_controller_richards"
  "$OUT/test_controller_richards" > "$OUT/controller_richards.txt"
  cat "$OUT/controller_richards.txt"
  grep -Fq 'PPA_WU05A4_OUTER_CONTROLLER_RICHARDS=PASS' "$OUT/controller_richards.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_controller_crack_rapid.f90 -o "$OUT/test_crack_rapid.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_crack_rapid.o" -o "$OUT/test_crack_rapid"
  "$OUT/test_crack_rapid" > "$OUT/crack_rapid.txt"
  cat "$OUT/crack_rapid.txt"
  grep -Fq 'PPA_WU05A4_CONTROLLER_CRACK_RAPID=PASS' "$OUT/crack_rapid.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_controller_crack_rapid_trajectory.f90 -o "$OUT/test_crack_rapid_traj.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_crack_rapid_traj.o" -o "$OUT/test_crack_rapid_traj"
  "$OUT/test_crack_rapid_traj" > "$OUT/crack_rapid_traj.txt"
  cat "$OUT/crack_rapid_traj.txt"
  grep -Fq 'PPA_WU05A4_CONTROLLER_CRACK_RAPID_TRAJECTORY=PASS' "$OUT/crack_rapid_traj.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_richards_exchange.f90 -o "$OUT/test_fixed.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fixed.o" -o "$OUT/test_fixed"
  "$OUT/test_fixed" > "$OUT/fixed.txt"
  grep -Fq 'PPA_WU05A4_RICHARDS_FIXED_EXCHANGE=PASS' "$OUT/fixed.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_richards_predictor_corrector.f90 -o "$OUT/test_pc.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_pc.o" -o "$OUT/test_pc"
  "$OUT/test_pc" > "$OUT/pc.txt"
  cat "$OUT/pc.txt"
  grep -Fq 'PPA_WU05A4_RICHARDS_PREDICTOR_CORRECTOR=PASS' "$OUT/pc.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_richards_picard.f90 -o "$OUT/test_picard.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_picard.o" -o "$OUT/test_picard"
  "$OUT/test_picard" > "$OUT/picard.txt"
  cat "$OUT/picard.txt"
  grep -Fq 'PPA_WU05A4_RICHARDS_PICARD_CHARACTERIZATION=PASS' "$OUT/picard.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_richards_adversarial_picard.f90 -o "$OUT/test_adv.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_adv.o" -o "$OUT/test_adv"
  "$OUT/test_adv" > "$OUT/adv.txt"
  cat "$OUT/adv.txt"
  grep -Fq 'PPA_WU05A4_RICHARDS_ADVERSARIAL_CHARACTERIZATION=PASS' "$OUT/adv.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_richards_stabilization.f90 -o "$OUT/test_stab.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_stab.o" -o "$OUT/test_stab"
  "$OUT/test_stab" > "$OUT/stab.txt"
  cat "$OUT/stab.txt"
  grep -Fq 'PPA_WU05A4_RICHARDS_STABILIZATION_CHARACTERIZATION=PASS' "$OUT/stab.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a4_richards_trajectory.f90 -o "$OUT/test_traj.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_traj.o" -o "$OUT/test_traj"
  "$OUT/test_traj" > "$OUT/traj.txt"
  cat "$OUT/traj.txt"
  grep -Fq 'PPA_WU05A4_RICHARDS_TRAJECTORY=PASS' "$OUT/traj.txt"
done

cmp "$BUILD/o0/controller.txt" "$BUILD/o2/controller.txt"
cmp "$BUILD/o0/controller_richards.txt" "$BUILD/o2/controller_richards.txt"
cmp "$BUILD/o0/crack_rapid.txt" "$BUILD/o2/crack_rapid.txt"
cmp "$BUILD/o0/crack_rapid_traj.txt" "$BUILD/o2/crack_rapid_traj.txt"
cmp "$BUILD/o0/fixed.txt" "$BUILD/o2/fixed.txt"
cmp "$BUILD/o0/pc.txt" "$BUILD/o2/pc.txt"
cmp "$BUILD/o0/picard.txt" "$BUILD/o2/picard.txt"
cmp "$BUILD/o0/adv.txt" "$BUILD/o2/adv.txt"
cmp "$BUILD/o0/stab.txt" "$BUILD/o2/stab.txt"
cmp "$BUILD/o0/traj.txt" "$BUILD/o2/traj.txt"
echo "PPA_WU05A4_RICHARDS_GATE=PASS"

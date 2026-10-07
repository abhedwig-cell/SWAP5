#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05a9-top-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_WU05A7_REAL_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/adapter/mod_fmr_mode7_temporal_head_envelope.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
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
  src/runtime/mod_fmr_legacy_qgwl_bottom_boundary_provider.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/physics/oxygen/mod_oxygen_macro_zero_depth.f90
  src/physics/oxygen/mod_oxygen_scalar_bracket.f90
  src/physics/oxygen/mod_bartholomeus_micro.f90
  src/physics/oxygen/mod_bartholomeus_macro.f90
  src/physics/oxygen/mod_bartholomeus_response.f90
  src/physics/oxygen/mod_bartholomeus_profile_response.f90
  src/physics/oxygen/mod_bartholomeus_soil_diffusivity.f90
  src/physics/oxygen/mod_bartholomeus_temperature.f90
  src/physics/oxygen/mod_bartholomeus_microbial.f90
  src/physics/oxygen/mod_bartholomeus_waterfilm.f90
  src/physics/oxygen/mod_bartholomeus_waterfilm_independent.f90
  src/process/mod_bartholomeus_runtime_input.f90
  src/physics/oxygen/mod_bartholomeus_parameter_contract.f90
  src/physics/oxygen/mod_bartholomeus_waterfilm_provider.f90
  src/physics/oxygen/mod_bartholomeus_response_assembly.f90
  src/physics/oxygen/mod_bartholomeus_no_stress_gate.f90
  src/physics/oxygen/mod_bartholomeus_factor_provider.f90
  src/process/mod_root_water_uptake_process.f90
  src/process/mod_root_uptake_oxygen_composition.f90
  src/runtime/mod_fmr_bartholomeus_activation.f90
  src/runtime/mod_fmr_bartholomeus_contract.f90
  src/crop/mod_crop_bartholomeus_input.f90
  src/runtime/mod_fmr_bartholomeus_execution.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
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
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/process/macropore/mod_ppa_wu05a5_top_partition.f90
  src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90
  src/process/macropore/mod_macropore_dynamic_shrinkage.f90
  src/runtime/mod_fmr_macropore_top_input.f90
  src/process/macropore/mod_ppa_wu05a6_sorptivity_rate.f90
  src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90
  src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90
  src/process/macropore/mod_ppa_wu05a6_saturated_sources.f90
  src/process/macropore/mod_ppa_wu05a6_rapid_drain_rate.f90
  src/process/macropore/mod_ppa_wu05a6_top_inflow_limiter.f90
  src/process/macropore/mod_ppa_wu05a6_vertical_flux_reconstruction.f90
  src/process/macropore/mod_ppa_wu05a6_sorptivity_history.f90
  src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90
  src/process/macropore/mod_ppa_wu05a15_exchange_derivative.f90
  src/process/macropore/mod_ppa_wu05_perch19_reduction_controller.f90
  src/process/macropore/mod_macropore_standard_storage.f90
  src/runtime/mod_macropore_standard_rate_adapter.f90
  src/solver/mod_macropore_exchange_overlay_provider.f90
  src/process/macropore/mod_macropore_covering_layer_input.f90
  src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90
  src/runtime/mod_macropore_single_column_runtime.f90
  src/runtime/mod_fmr_macropore_configuration.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_committed_restart.f90
)
# Additive C3A backend prerequisites; existing gate semantics stay fixed.
mapfile -t MODULE_SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}")

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  if [[ "${WU05A9_ONLY:-0}" != 1 ]]; then
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a7_real_richards_runtime.f90 -o "$OUT/test.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
    "$OUT/test" | tee "$OUT/out.txt"
    grep -Fq 'PPA_WU05A7_REAL_RICHARDS_RUNTIME=PASS' "$OUT/out.txt"
  fi

  if [[ "${WU05A9_ONLY:-0}" != 1 ]]; then
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a8_fmr_macropore_trial.f90 -o "$OUT/test_fmr_macro.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr_macro.o" -o "$OUT/test_fmr_macro"
    "$OUT/test_fmr_macro" | tee "$OUT/fmr_macro.txt"
    grep -Fq 'PPA_WU05A8_FMR_MACRO_TRIAL=PASS' "$OUT/fmr_macro.txt"
  fi

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a9_top_input.f90 -o "$OUT/test_a9_unit.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_a9_unit.o" -o "$OUT/test_a9_unit"
  "$OUT/test_a9_unit" | tee "$OUT/a9_unit.txt"
  grep -Fq 'PPA_WU05A9_TOP_INPUT=PASS' "$OUT/a9_unit.txt"

  if [[ "${WU05A9_UNIT_ONLY:-0}" != 1 ]]; then
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a9_fmr_top_input_trial.f90 -o "$OUT/test_a9_fmr.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/test_a9_fmr.o" -o "$OUT/test_a9_fmr"
    "$OUT/test_a9_fmr" | tee "$OUT/a9_fmr.txt"
    grep -Fq 'PPA_WU05A9_FMR_MACRO_TRIAL=PASS' "$OUT/a9_fmr.txt"

    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05a9_fmr_top_input_replay.f90 -o "$OUT/test_a9_replay.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/test_a9_replay.o" -o "$OUT/test_a9_replay"
    "$OUT/test_a9_replay" | tee "$OUT/a9_replay.txt"
    grep -Fq 'PPA_WU05A9_FMR_TOP_INPUT_SERIALIZED=PASS' "$OUT/a9_replay.txt"
    grep -Fq 'PPA_WU05A9_FMR_TOP_INPUT_REJECT_REPLAY=PASS' "$OUT/a9_replay.txt"
    grep -Fq 'PPA_WU05A9_FMR_TOP_INPUT_RESTART=PASS' "$OUT/a9_replay.txt"
    grep -Fq 'PPA_WU05A9_FMR_TOP_INPUT_REPLAY_GATE=PASS' "$OUT/a9_replay.txt"
    if [[ "${WU05_MIGMAC02:-0}" == 1 ]]; then
      WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_fmr" | tee "$OUT/migmac02_fmr.txt"
      grep -Fq 'PPA_WU05_MIGMAC02_DYNAMIC_REFERENCE_TRANSACTION=PASS' "$OUT/migmac02_fmr.txt"
      WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/migmac02_replay.txt"
      for marker in DYNAMIC_REJECT_SMALLER_RETRY DYNAMIC_ABA DYNAMIC_ACCEPTED_RESTART; do
        grep -Fq "PPA_WU05_MIGMAC02_${marker}=PASS" "$OUT/migmac02_replay.txt"
      done
      WU05_MIGMAC02_DYNAMIC=2 "$OUT/test_a9_fmr" > "$OUT/migmac02_nochange.txt"
      WU05_MIGMAC02_DYNAMIC=3 "$OUT/test_a9_fmr" > "$OUT/migmac02_inner_static.txt"
      cmp "$OUT/migmac02_nochange.txt" "$OUT/migmac02_inner_static.txt"
      echo 'PPA_WU05_MIGMAC02_UNCHANGED_GEOMETRY_RUNTIME_IDENTITY=PASS'
      WU05_MIGMAC02_DYNAMIC=4 "$OUT/test_a9_fmr" | tee "$OUT/migmac02_shrinking.txt"
      grep -Fq 'PPA_WU05_MIGMAC02_WETTING_GEOMETRY_RETURN=PASS' "$OUT/migmac02_shrinking.txt"
      WU05_MIGMAC02_DYNAMIC=5 "$OUT/test_a9_fmr" | tee "$OUT/migmac02_two_domain.txt"
      grep -Fq 'PPA_WU05_MIGMAC02_TWO_DOMAIN_GEOMETRY_RAPID_DRAIN=PASS' "$OUT/migmac02_two_domain.txt"
    fi
    if [[ "${WU05_MIGMAC11_SUITE:-0}" == 1 ]]; then
  for case_name in active runon below partial replay; do
    cmp "$BUILD/o0/migmac11_${case_name}.txt" "$BUILD/o2/migmac11_${case_name}.txt"
  done
  echo 'PPA_WU05_MIGMAC11_O0_O2_IDENTITY=PASS'
fi

if [[ "${WU05_MIGMAC03:-0}" == 1 ]]; then
      for law in 1 2 3 4; do
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_fmr" | tee "$OUT/peat_${law}_trial.txt"
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/peat_${law}_replay.txt"
        for marker in DYNAMIC_REJECT_SMALLER_RETRY DYNAMIC_ABA DYNAMIC_ACCEPTED_RESTART; do
          grep -Fq "PPA_WU05_MIGMAC02_${marker}=PASS" "$OUT/peat_${law}_replay.txt"
        done
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=4 "$OUT/test_a9_fmr" | tee "$OUT/peat_${law}_wetting.txt"
        grep -Fq 'PPA_WU05_MIGMAC02_WETTING_GEOMETRY_RETURN=PASS' "$OUT/peat_${law}_wetting.txt"
      done
    fi
    if [[ "${WU05_MIGMAC04:-0}" == 1 ]]; then
      for fit in 1 2 3; do
        law=0
        if [[ "$fit" != 1 ]]; then law=1; fi
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC04_FIT="$fit" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_fmr" | tee "$OUT/fit_${fit}_trial.txt"
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC04_FIT="$fit" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/fit_${fit}_replay.txt"
        for receipt in DYNAMIC_REJECT_SMALLER_RETRY DYNAMIC_ABA DYNAMIC_ACCEPTED_RESTART; do
          grep -Fq "PPA_WU05_MIGMAC02_${receipt}=PASS" "$OUT/fit_${fit}_replay.txt"
        done
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC04_FIT="$fit" WU05_MIGMAC02_DYNAMIC=4 "$OUT/test_a9_fmr" | tee "$OUT/fit_${fit}_wetting.txt"
        grep -Fq 'PPA_WU05_MIGMAC02_WETTING_GEOMETRY_RETURN=PASS' "$OUT/fit_${fit}_wetting.txt"
      done
    fi
    if [[ "${WU05_MIGMAC08:-0}" == 1 ]]; then
      for law in 5 6 7; do
        for mode in 1 4 5; do
          WU05_MIGMAC08_COVER=1 WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC="$mode" "$OUT/test_a9_fmr" | tee "$OUT/cover_${law}_${mode}.txt"
          WU05_MIGMAC08_COVER=1 WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=2 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC="$mode" "$OUT/test_a9_fmr" > "$OUT/cover_${law}_${mode}_supplied.txt"
          cmp "$OUT/cover_${law}_${mode}.txt" "$OUT/cover_${law}_${mode}_supplied.txt"
        done
        WU05_MIGMAC08_COVER=1 WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/cover_${law}_replay.txt"
        grep -Fq 'PPA_WU05_MIGMAC08_COVERED_REFERENCE_RESTART=PASS' "$OUT/cover_${law}_replay.txt"
      done
      for fit in 1 2 3; do
        WU05_MIGMAC08_COVER=1 WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW=5 WU05_MIGMAC04_FIT="$fit" WU05_MIGMAC02_DYNAMIC=5 "$OUT/test_a9_fmr" | tee "$OUT/cover_fit_${fit}.txt"
      done
    fi
    if [[ "${WU05_MIGMAC09:-0}" == 1 ]]; then
      for law in 5 6 7; do
        for mode in 1 4 5; do
          WU05_MIGMAC08_COVER=2 WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC="$mode" "$OUT/test_a9_fmr" | tee "$OUT/nonrigid_cover_${law}_${mode}.txt"
          WU05_MIGMAC08_COVER=2 WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=2 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC="$mode" "$OUT/test_a9_fmr" > "$OUT/nonrigid_cover_${law}_${mode}_supplied.txt"
          cmp "$OUT/nonrigid_cover_${law}_${mode}.txt" "$OUT/nonrigid_cover_${law}_${mode}_supplied.txt"
        done
        WU05_MIGMAC08_COVER=2 WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/nonrigid_cover_${law}_replay.txt"
        grep -Fq 'PPA_WU05_MIGMAC08_COVERED_REFERENCE_RESTART=PASS' "$OUT/nonrigid_cover_${law}_replay.txt"
      done
      for fit in 1 2 3; do
        WU05_MIGMAC08_COVER=2 WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW=5 WU05_MIGMAC04_FIT="$fit" WU05_MIGMAC02_DYNAMIC=5 "$OUT/test_a9_fmr" | tee "$OUT/nonrigid_cover_fit_${fit}.txt"
      done
    fi
    if [[ "${WU05_MIGMAC10:-0}" == 1 ]]; then
      WU05_MIGMAC10_RUTTER=0 WU05_MIGMAC10=1 "$OUT/test_a9_fmr" | tee "$OUT/migmac10_trial.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_TRIAL=PASS' "$OUT/migmac10_trial.txt"
      WU05_MIGMAC10_RUTTER=0 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_fmr" | tee "$OUT/migmac10_shrink_trial.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_TRIAL=PASS' "$OUT/migmac10_shrink_trial.txt"
      WU05_MIGMAC10_RUTTER=0 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=3 "$OUT/test_a9_fmr" | tee "$OUT/migmac10_static_trial.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_TRIAL=PASS' "$OUT/migmac10_static_trial.txt"
      WU05_MIGMAC10_RUTTER=0 WU05_MIGMAC10=1 "$OUT/test_a9_replay" | tee "$OUT/migmac10_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_REJECT_REPLAY=PASS' "$OUT/migmac10_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_RESTART=PASS' "$OUT/migmac10_replay.txt"
      WU05_MIGMAC10_RUTTER=0 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/migmac10_shrink_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_REJECT_REPLAY=PASS' "$OUT/migmac10_shrink_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_RESTART=PASS' "$OUT/migmac10_shrink_replay.txt"
      WU05_MIGMAC10_RUTTER=0 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=3 "$OUT/test_a9_replay" | tee "$OUT/migmac10_static_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_REJECT_REPLAY=PASS' "$OUT/migmac10_static_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_RESTART=PASS' "$OUT/migmac10_static_replay.txt"
    fi
    if [[ "${WU05_MIGMAC10_RUTTER:-0}" == 1 ]]; then
      for mode in 2 1; do
        WU05_MIGMAC10=1 WU05_MIGMAC10_RUTTER=1 WU05_MIGMAC02_DYNAMIC="$mode" \
          "$OUT/test_a9_fmr" | tee "$OUT/migmac10_rutter_trial_${mode}.txt"
        grep -Fq 'PPA_WU05_MIGMAC10_RUTTER_BOESTEN_MACROPORE_TRIAL=PASS' \
          "$OUT/migmac10_rutter_trial_${mode}.txt"
        WU05_MIGMAC10=1 WU05_MIGMAC10_RUTTER=1 WU05_MIGMAC02_DYNAMIC="$mode" \
          "$OUT/test_a9_replay" | tee "$OUT/migmac10_rutter_replay_${mode}.txt"
        grep -Fq 'PPA_WU05_MIGMAC10_RUTTER_BOESTEN_MACROPORE_REJECT_REPLAY=PASS' \
          "$OUT/migmac10_rutter_replay_${mode}.txt"
        grep -Fq 'PPA_WU05_MIGMAC10_RUTTER_BOESTEN_MACROPORE_RESTART=PASS' \
          "$OUT/migmac10_rutter_replay_${mode}.txt"
        grep -Fq 'PPA_WU05_MIGMAC10_RUTTER_COMPETING_MACRO_SOURCE_REJECT=PASS' \
          "$OUT/migmac10_rutter_replay_${mode}.txt"
        grep -Fq 'PPA_WU05_MIGMAC10_RUTTER_UNSUPPORTED_ENVELOPE_10_REJECT=PASS' \
          "$OUT/migmac10_rutter_replay_${mode}.txt"
      done
    fi
    if [[ "${WU05_MIGMAC07:-0}" == 1 ]]; then
      for law in 5 6 7; do
        WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=5 "$OUT/test_a9_fmr" | tee "$OUT/partial_${law}_trial.txt"
        WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=2 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=5 "$OUT/test_a9_fmr" > "$OUT/partial_${law}_supplied.txt"
        cmp "$OUT/partial_${law}_trial.txt" "$OUT/partial_${law}_supplied.txt"
        WU05_MIGMAC07_PARTIAL=1 WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/partial_${law}_replay.txt"
        grep -Fq 'PPA_WU05_MIGMAC02_DYNAMIC_ACCEPTED_RESTART=PASS' "$OUT/partial_${law}_replay.txt"
      done
    fi
    if [[ "${WU05_MIGMAC06:-0}" == 1 ]]; then
      for law in 5 6 7; do
        for mode in 1 4 5; do
          WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC="$mode" "$OUT/test_a9_fmr" | tee "$OUT/kd_${law}_${mode}.txt"
          grep -Fq 'PPA_WU05_MIGMAC06_REFERENCE_KD=' "$OUT/kd_${law}_${mode}.txt"
          WU05_MIGMAC06_KD=2 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC="$mode" "$OUT/test_a9_fmr" > "$OUT/kd_${law}_${mode}_supplied.txt"
          cmp "$OUT/kd_${law}_${mode}.txt" "$OUT/kd_${law}_${mode}_supplied.txt"

        done
        WU05_MIGMAC06_KD=1 WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/kd_${law}_replay.txt"
        grep -Fq 'PPA_WU05_MIGMAC02_DYNAMIC_ACCEPTED_RESTART=PASS' "$OUT/kd_${law}_replay.txt"
      done
    fi
    if [[ "${WU05_MIGMAC11_SUITE:-0}" == 1 ]]; then
      WU05_MIGMAC11=1 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=3 \
        "$OUT/test_a9_fmr" | tee "$OUT/migmac11_active.txt"
      grep -Fq 'PPA_WU05_MIGMAC11_ACTIVE_POND=PASS' "$OUT/migmac11_active.txt"

      WU05_MIGMAC11=1 WU05_MIGMAC11_RUNON=1 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=3 \
        "$OUT/test_a9_fmr" | tee "$OUT/migmac11_runon.txt"
      grep -Fq 'PPA_WU05_MIGMAC11_RUNON=PASS' "$OUT/migmac11_runon.txt"

      WU05_MIGMAC11=1 WU05_MIGMAC11_BELOW=1 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=3 \
        "$OUT/test_a9_fmr" | tee "$OUT/migmac11_below.txt"
      grep -Fq 'PPA_WU05_MIGMAC11_BELOW_THRESHOLD=PASS' "$OUT/migmac11_below.txt"

      WU05_MIGMAC11=1 WU05_MIGMAC11_PARTIAL=1 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=3 \
        "$OUT/test_a9_fmr" | tee "$OUT/migmac11_partial.txt"
      grep -Fq 'PPA_WU05_MIGMAC11_PARTIAL_RETURN=PASS' "$OUT/migmac11_partial.txt"

      WU05_MIGMAC11=1 WU05_MIGMAC10=1 WU05_MIGMAC02_DYNAMIC=3 \
        "$OUT/test_a9_replay" | tee "$OUT/migmac11_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC11_REJECT_SMALLER_RETRY=PASS' "$OUT/migmac11_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC11_ROLLBACK_REPLAY=PASS' "$OUT/migmac11_replay.txt"
      grep -Fq 'PPA_WU05_MIGMAC11_RESTART_EQUIVALENCE=PASS' "$OUT/migmac11_replay.txt"

      base_req="$(sed -n 's/.*POND_REQUESTED=\([^|]*\).*/\1/p' "$OUT/migmac11_active.txt" | tail -1)"
      runon_req="$(sed -n 's/.*POND_REQUESTED=\([^|]*\).*/\1/p' "$OUT/migmac11_runon.txt" | tail -1)"
      python3 - "$base_req" "$runon_req" <<'PY'
import math, sys
base=float(sys.argv[1]); runon=float(sys.argv[2])
if not (math.isfinite(base) and math.isfinite(runon) and base > 0.0 and runon > base):
    raise SystemExit(f"MIGMAC11 runon pairing failed: base={base} runon={runon}")
print(f"PPA_WU05_MIGMAC11_RUNON_PAIR=PASS|BASE={base:.17g}|RUNON={runon:.17g}")
PY
    fi
    if [[ "${WU05_MIGMAC05:-0}" == 1 ]]; then
      for law in 5 6 7; do
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_fmr" | tee "$OUT/mixed_${law}_trial.txt"
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/mixed_${law}_replay.txt"
        for receipt in DYNAMIC_REJECT_SMALLER_RETRY DYNAMIC_ABA DYNAMIC_ACCEPTED_RESTART; do
          grep -Fq "PPA_WU05_MIGMAC02_${receipt}=PASS" "$OUT/mixed_${law}_replay.txt"
        done
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=4 "$OUT/test_a9_fmr" | tee "$OUT/mixed_${law}_wetting.txt"
        grep -Fq 'PPA_WU05_MIGMAC02_WETTING_GEOMETRY_RETURN=PASS' "$OUT/mixed_${law}_wetting.txt"
        WU05_MIGMAC03_LAW="$law" WU05_MIGMAC02_DYNAMIC=5 "$OUT/test_a9_fmr" | tee "$OUT/mixed_${law}_rapid.txt"
        grep -Fq 'PPA_WU05_MIGMAC02_TWO_DOMAIN_GEOMETRY_RAPID_DRAIN=PASS' "$OUT/mixed_${law}_rapid.txt"
      done
      for fit in 1 2 3; do
        WU05_MIGMAC03_LAW=5 WU05_MIGMAC04_FIT="$fit" WU05_MIGMAC02_DYNAMIC=1 "$OUT/test_a9_replay" | tee "$OUT/mixed_fit_${fit}_replay.txt"
        WU05_MIGMAC03_LAW=5 WU05_MIGMAC04_FIT="$fit" WU05_MIGMAC02_DYNAMIC=4 "$OUT/test_a9_fmr" | tee "$OUT/mixed_fit_${fit}_wetting.txt"
        grep -Fq 'PPA_WU05_MIGMAC02_DYNAMIC_ACCEPTED_RESTART=PASS' "$OUT/mixed_fit_${fit}_replay.txt"
        grep -Fq 'PPA_WU05_MIGMAC02_WETTING_GEOMETRY_RETURN=PASS' "$OUT/mixed_fit_${fit}_wetting.txt"
      done
    fi
  fi
done
if [[ "${WU05A9_ONLY:-0}" != 1 ]]; then
  cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
  cmp "$BUILD/o0/fmr_macro.txt" "$BUILD/o2/fmr_macro.txt"
fi
cmp "$BUILD/o0/a9_unit.txt" "$BUILD/o2/a9_unit.txt"
if [[ "${WU05A9_UNIT_ONLY:-0}" != 1 ]]; then
  cmp "$BUILD/o0/a9_fmr.txt" "$BUILD/o2/a9_fmr.txt"
  cmp "$BUILD/o0/a9_replay.txt" "$BUILD/o2/a9_replay.txt"
  if [[ "${WU05_MIGMAC02:-0}" == 1 ]]; then
    cmp "$BUILD/o0/migmac02_fmr.txt" "$BUILD/o2/migmac02_fmr.txt"
    cmp "$BUILD/o0/migmac02_replay.txt" "$BUILD/o2/migmac02_replay.txt"
    cmp "$BUILD/o0/migmac02_nochange.txt" "$BUILD/o2/migmac02_nochange.txt"
    cmp "$BUILD/o0/migmac02_shrinking.txt" "$BUILD/o2/migmac02_shrinking.txt"
    cmp "$BUILD/o0/migmac02_two_domain.txt" "$BUILD/o2/migmac02_two_domain.txt"
    echo 'PPA_WU05_MIGMAC02_DYNAMIC_RUNTIME_O0_O2_IDENTITY=PASS'
  fi
fi
if [[ "${WU05_MIGMAC03:-0}" == 1 ]]; then
  for law in 1 2 3 4; do
    for mode in trial replay wetting; do
      cmp "$BUILD/o0/peat_${law}_${mode}.txt" "$BUILD/o2/peat_${law}_${mode}.txt"
    done
  done
  echo 'PPA_WU05_MIGMAC03_REFERENCE_O0_O2_IDENTITY=PASS'
fi
if [[ "${WU05_MIGMAC04:-0}" == 1 ]]; then
  for fit in 1 2 3; do
    for mode in trial replay wetting; do
      cmp "$BUILD/o0/fit_${fit}_${mode}.txt" "$BUILD/o2/fit_${fit}_${mode}.txt"
    done
  done
  echo 'PPA_WU05_MIGMAC04_REFERENCE_O0_O2_IDENTITY=PASS'
fi
if [[ "${WU05_MIGMAC05:-0}" == 1 ]]; then
  for law in 5 6 7; do
    for mode in trial replay wetting rapid; do
      cmp "$BUILD/o0/mixed_${law}_${mode}.txt" "$BUILD/o2/mixed_${law}_${mode}.txt"
    done
  done
  for fit in 1 2 3; do
    for mode in replay wetting; do
      cmp "$BUILD/o0/mixed_fit_${fit}_${mode}.txt" "$BUILD/o2/mixed_fit_${fit}_${mode}.txt"
    done
  done
  echo 'PPA_WU05_MIGMAC05_MIXED_REFERENCE_O0_O2_IDENTITY=PASS'
fi
echo "PPA_WU05A9_TOP_INPUT_GATE=PASS"

if [[ "${WU05_MIGMAC06:-0}" == 1 ]]; then
  for law in 5 6 7; do
    for mode in 1 4 5 replay; do
      cmp "$BUILD/o0/kd_${law}_${mode}.txt" "$BUILD/o2/kd_${law}_${mode}.txt"
    done
  done
  echo 'PPA_WU05_MIGMAC06_REFERENCE_O0_O2_IDENTITY=PASS'
fi

if [[ "${WU05_MIGMAC07:-0}" == 1 ]]; then
 for law in 5 6 7; do
  cmp "$BUILD/o0/partial_${law}_trial.txt" "$BUILD/o2/partial_${law}_trial.txt"
  cmp "$BUILD/o0/partial_${law}_replay.txt" "$BUILD/o2/partial_${law}_replay.txt"
 done
 echo 'PPA_WU05_MIGMAC07_PARTIAL_REFERENCE_O0_O2=PASS'
fi

if [[ "${WU05_MIGMAC08:-0}" == 1 ]]; then
 for law in 5 6 7; do
  for mode in 1 4 5 replay; do
   cmp "$BUILD/o0/cover_${law}_${mode}.txt" "$BUILD/o2/cover_${law}_${mode}.txt"
  done
 done
 for fit in 1 2 3; do
  cmp "$BUILD/o0/cover_fit_${fit}.txt" "$BUILD/o2/cover_fit_${fit}.txt"
 done
 echo 'PPA_WU05_MIGMAC08_COVERED_REFERENCE_O0_O2=PASS'
fi

if [[ "${WU05_MIGMAC09:-0}" == 1 ]]; then
 for law in 5 6 7; do
  for mode in 1 4 5 replay; do
   cmp "$BUILD/o0/nonrigid_cover_${law}_${mode}.txt" "$BUILD/o2/nonrigid_cover_${law}_${mode}.txt"
  done
 done
 for fit in 1 2 3; do
  cmp "$BUILD/o0/nonrigid_cover_fit_${fit}.txt" "$BUILD/o2/nonrigid_cover_fit_${fit}.txt"
 done
 echo 'PPA_WU05_MIGMAC09_NONRIGID_COVER_O0_O2=PASS'
fi

if [[ "${WU05_MIGMAC10:-0}" == 1 ]]; then
 cmp "$BUILD/o0/migmac10_trial.txt" "$BUILD/o2/migmac10_trial.txt"
 cmp "$BUILD/o0/migmac10_replay.txt" "$BUILD/o2/migmac10_replay.txt"
 cmp "$BUILD/o0/migmac10_shrink_trial.txt" "$BUILD/o2/migmac10_shrink_trial.txt"
 cmp "$BUILD/o0/migmac10_shrink_replay.txt" "$BUILD/o2/migmac10_shrink_replay.txt"
 cmp "$BUILD/o0/migmac10_static_trial.txt" "$BUILD/o2/migmac10_static_trial.txt"
 cmp "$BUILD/o0/migmac10_static_replay.txt" "$BUILD/o2/migmac10_static_replay.txt"
 echo 'PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_O0_O2_IDENTITY=PASS'
fi

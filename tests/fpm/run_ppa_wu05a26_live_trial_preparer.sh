#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/swap5-a26live";rm -rf "${B}";mkdir -p "${B}"
"${FC:-gfortran}" -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace \
 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_process_hydraulic_view.f90 \
 src/process/macropore/mod_rfm_unponded_activation.f90 src/runtime/mod_rfm_unponded_surface_composition.f90 \
 src/process/macropore/mod_rfm_preferential_router.f90 src/process/macropore/mod_rfm_surface_event_age.f90 \
 src/runtime/mod_rfm_physical_state.f90 src/process/macropore/mod_rfm_surface_sorptivity.f90 \
 src/runtime/mod_fmr_rfm_activation_binding.f90 src/runtime/mod_rfm_runtime_configuration.f90 src/runtime/mod_rfm_surface_forcing.f90 \
 src/runtime/mod_rfm_wall_hydraulic_history_binding.f90 src/process/macropore/mod_rfm_endpoint_release.f90 \
 src/runtime/mod_rfm_whole_column_candidate_ledger.f90 src/runtime/mod_rfm_ic_storage_geometry.f90 \
 src/runtime/mod_rfm_ic_hydrostatic_head.f90 src/runtime/mod_rfm_production_candidate_composer.f90 \
 src/runtime/mod_rfm_live_trial_preparer.f90 tests/fpm/test_ppa_wu05a26_live_trial_preparer.f90 -J"${B}" -o "${B}/a26live"
"${B}/a26live"

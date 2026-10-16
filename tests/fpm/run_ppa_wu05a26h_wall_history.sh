#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/swap5-a26h";rm -rf "${B}";mkdir -p "${B}"
"${FC:-gfortran}" -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace \
 src/solver/mod_soil_water_solver_contract.f90 \
 src/solver/mod_process_hydraulic_view.f90 \
 src/process/macropore/mod_rfm_unponded_activation.f90 \
 src/runtime/mod_rfm_unponded_surface_composition.f90 \
 src/process/macropore/mod_rfm_preferential_router.f90 \
 src/process/macropore/mod_rfm_surface_event_age.f90 \
 src/runtime/mod_rfm_physical_state.f90 \
 src/process/macropore/mod_rfm_surface_sorptivity.f90 \
 src/runtime/mod_rfm_wall_hydraulic_history_binding.f90 \
 tests/fpm/test_ppa_wu05a26h_wall_history.f90 \
 -J"${B}" -o "${B}/a26h"
"${B}/a26h"

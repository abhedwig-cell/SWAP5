#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
BUILD_DIR="${TMPDIR:-/tmp}/swap5-ppa-wu05a16"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
"${FC}" -std=f2008 -Wall -Wextra -pedantic \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/process/evaporation/mod_restricted_surface_evaporation.f90 \
  src/solver/mod_b110_default_mvg_provider.f90 \
  src/solver/mod_b110_dynamic_top_boundary_provider.f90 \
  src/process/macropore/mod_rfm_unponded_activation.f90 \
  src/runtime/mod_rfm_unponded_surface_composition.f90 \
  src/runtime/mod_rfm_matrix_share_dynamic_top_binding.f90 \
  tests/fpm/test_ppa_wu05a16_rfm_matrix_share_rebinding.f90 \
  -J"${BUILD_DIR}" -o "${BUILD_DIR}/test_ppa_wu05a16"
"${BUILD_DIR}/test_ppa_wu05a16"

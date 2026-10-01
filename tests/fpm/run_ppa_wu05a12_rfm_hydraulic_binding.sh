#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
BUILD_DIR="${TMPDIR:-/tmp}/swap5-ppa-wu05a12"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
"${FC}" -std=f2008 -Wall -Wextra -pedantic \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_process_hydraulic_view.f90 \
  src/process/macropore/mod_rfm_unponded_activation.f90 \
  src/process/macropore/mod_rfm_surface_sorptivity.f90 \
  src/runtime/mod_fmr_rfm_activation_binding.f90 \
  tests/fpm/test_ppa_wu05a12_rfm_hydraulic_binding.f90 \
  -J"${BUILD_DIR}" -o "${BUILD_DIR}/test_ppa_wu05a12"
"${BUILD_DIR}/test_ppa_wu05a12"

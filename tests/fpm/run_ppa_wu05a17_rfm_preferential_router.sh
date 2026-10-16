#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
BUILD_DIR="${TMPDIR:-/tmp}/swap5-ppa-wu05a17"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
"${FC}" -std=f2008 -Wall -Wextra -pedantic \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/process/macropore/mod_rfm_unponded_activation.f90 \
  src/runtime/mod_rfm_unponded_surface_composition.f90 \
  src/process/macropore/mod_rfm_preferential_router.f90 \
  tests/fpm/test_ppa_wu05a17_rfm_preferential_router.f90 \
  -J"${BUILD_DIR}" -o "${BUILD_DIR}/test_ppa_wu05a17"
"${BUILD_DIR}/test_ppa_wu05a17"

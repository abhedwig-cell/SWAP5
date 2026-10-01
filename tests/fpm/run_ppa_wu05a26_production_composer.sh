#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/swap5-a26c";rm -rf "${B}";mkdir -p "${B}"
"${FC:-gfortran}" -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace \
 src/process/macropore/mod_rfm_unponded_activation.f90 \
 src/runtime/mod_rfm_unponded_surface_composition.f90 \
 src/process/macropore/mod_rfm_preferential_router.f90 \
 src/process/macropore/mod_rfm_surface_event_age.f90 \
 src/runtime/mod_rfm_physical_state.f90 \
 src/process/macropore/mod_rfm_endpoint_release.f90 \
 src/runtime/mod_rfm_whole_column_candidate_ledger.f90 \
 src/runtime/mod_rfm_ic_storage_geometry.f90 src/runtime/mod_rfm_ic_hydrostatic_head.f90 \
 src/runtime/mod_rfm_production_candidate_composer.f90 tests/fpm/test_ppa_wu05a26_production_composer.f90 \
 -J"${B}" -o "${B}/a26c"
"${B}/a26c"

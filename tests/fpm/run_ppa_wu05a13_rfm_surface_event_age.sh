#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
BUILD_DIR="${TMPDIR:-/tmp}/swap5-ppa-wu05a13"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
"${FC}" -std=f2008 -Wall -Wextra -pedantic \
  src/process/macropore/mod_rfm_surface_event_age.f90 \
  tests/fpm/test_ppa_wu05a13_rfm_surface_event_age.f90 \
  -J"${BUILD_DIR}" -o "${BUILD_DIR}/test_ppa_wu05a13"
"${BUILD_DIR}/test_ppa_wu05a13"

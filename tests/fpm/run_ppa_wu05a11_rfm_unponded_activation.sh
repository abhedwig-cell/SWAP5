#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
BUILD_DIR="${TMPDIR:-/tmp}/swap5-ppa-wu05a11"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
"${FC}" -std=f2008 -Wall -Wextra -pedantic \
  src/process/macropore/mod_rfm_unponded_activation.f90 \
  tests/fpm/test_ppa_wu05a11_rfm_unponded_activation.f90 \
  -J"${BUILD_DIR}" -o "${BUILD_DIR}/test_ppa_wu05a11"
"${BUILD_DIR}/test_ppa_wu05a11"

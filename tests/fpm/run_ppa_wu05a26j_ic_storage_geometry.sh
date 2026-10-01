#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/swap5-a26j";rm -rf "${B}";mkdir -p "${B}"
"${FC:-gfortran}" -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace \
 src/runtime/mod_rfm_ic_storage_geometry.f90 tests/fpm/test_ppa_wu05a26j_ic_storage_geometry.f90 \
 -J"${B}" -o "${B}/a26j"
"${B}/a26j"

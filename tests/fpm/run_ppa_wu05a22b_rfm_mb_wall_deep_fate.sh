#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
B="${TMPDIR:-/tmp}/swap5-a22b"
rm -rf "${B}"; mkdir -p "${B}"
"${FC}" -std=f2008 -Wall -Wextra -pedantic \
  src/process/macropore/mod_rfm_mb_wall_deep_fate.f90 \
  tests/fpm/test_ppa_wu05a22b_rfm_mb_wall_deep_fate.f90 \
  -J"${B}" -o "${B}/test_a22b"
"${B}/test_a22b"

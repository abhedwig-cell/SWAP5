#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
B="${TMPDIR:-/tmp}/swap5-a22a"
rm -rf "${B}"; mkdir -p "${B}"
"${FC}" -std=f2008 -Wall -Wextra -pedantic \
  src/process/macropore/mod_rfm_endpoint_release.f90 \
  tests/fpm/test_ppa_wu05a22a_rfm_endpoint_release.f90 \
  -J"${B}" -o "${B}/test_a22a"
"${B}/test_a22a"

#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/swap5-a23";rm -rf "${B}";mkdir -p "${B}"
"${FC:-gfortran}" -std=f2008 -Wall -Wextra -pedantic \
 src/runtime/mod_rfm_whole_column_candidate_ledger.f90 \
 tests/fpm/test_ppa_wu05a23_rfm_whole_column_candidate_ledger.f90 \
 -J"${B}" -o "${B}/a23"
"${B}/a23"

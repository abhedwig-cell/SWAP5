#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
OUT="${TMPDIR:-/tmp}/ppa_wu05_migmac02"
rm -rf "$OUT"; mkdir -p "$OUT"
for opt in 0 2; do
  "$FC" -std=f2008 -Wall -Wextra -Werror -O"$opt" -J"$OUT" -I"$OUT" \
    src/process/macropore/mod_macropore_dynamic_shrinkage.f90 \
    tests/fpm/test_ppa_wu05_migmac02_dynamic_shrinkage.f90 -o "$OUT/test_o$opt"
  "$OUT/test_o$opt" | tee "$OUT/out_o$opt.txt"
  grep -Fq 'PPA_WU05_MIGMAC02_E4_HYSTERESIS=PASS' "$OUT/out_o$opt.txt"
done
echo 'PPA_WU05_MIGMAC02_PURE_OPERATOR_O0_O2=PASS'

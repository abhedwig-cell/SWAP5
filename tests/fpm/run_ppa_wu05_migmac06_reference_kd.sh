#!/usr/bin/env bash
set -euo pipefail
OUT=$(mktemp -d "${TMPDIR:-/tmp}/migmac06-kd.XXXXXX")
trap 'rm -rf "$OUT"' EXIT
for opt in 0 2; do
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" -J"$OUT" -I"$OUT" \
    src/process/macropore/mod_macropore_dynamic_shrinkage.f90 \
    tests/fpm/test_ppa_wu05_migmac06_reference_kd.f90 -o "$OUT/test"
  "$OUT/test" > "$OUT/o$opt.txt" || { cat "$OUT/o$opt.txt"; exit 1; }
  cat "$OUT/o$opt.txt"
done
cmp "$OUT/o0.txt" "$OUT/o2.txt"
echo 'PPA_WU05_MIGMAC06_REFERENCE_KD_O0_O2=PASS'

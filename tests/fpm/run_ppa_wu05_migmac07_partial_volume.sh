#!/usr/bin/env bash
set -euo pipefail
OUT=$(mktemp -d /tmp/migmac07-pure.XXXXXX)
trap 'rm -rf "$OUT"' EXIT
for opt in 0 2; do
 gfortran -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" -J"$OUT" -I"$OUT" src/process/macropore/mod_ppa_wu05a6_rapid_drain_rate.f90 tests/fpm/test_ppa_wu05_migmac07_partial_volume.f90 -o "$OUT/test"
 "$OUT/test" > "$OUT/o$opt.txt"
 cat "$OUT/o$opt.txt"
done
cmp "$OUT/o0.txt" "$OUT/o2.txt"
echo 'PPA_WU05_MIGMAC07_PARTIAL_VOLUME_O0_O2=PASS'

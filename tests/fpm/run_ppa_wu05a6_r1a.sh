#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05a6-r1a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     research/macropore/mod_ppa_wu05a6_sorptivity_rate.f90 -o "$OUT/sorp.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     research/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90 -o "$OUT/unsat.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a6_sorptivity_rate.f90 -o "$OUT/test_sorp.o"
  gfortran -O"$opt" "$OUT/sorp.o" "$OUT/test_sorp.o" -o "$OUT/test_sorp"
  "$OUT/test_sorp" > "$OUT/sorp.txt"
  cat "$OUT/sorp.txt"
  grep -Fq 'PPA_WU05A6_SORPTIVITY_RATE=PASS' "$OUT/sorp.txt"

  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     research/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90 -o "$OUT/sat.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a6_unsat_absorption_rate.f90 -o "$OUT/test_unsat.o"
  gfortran -O"$opt" "$OUT/sorp.o" "$OUT/unsat.o" "$OUT/test_unsat.o" -o "$OUT/test_unsat"
  "$OUT/test_unsat" > "$OUT/unsat.txt"
  cat "$OUT/unsat.txt"
  grep -Fq 'PPA_WU05A6_UNSAT_ABSORPTION=PASS' "$OUT/unsat.txt"

  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a6_saturated_exchange_rate.f90 -o "$OUT/test_sat.o"
  gfortran -O"$opt" "$OUT/sat.o" "$OUT/test_sat.o" -o "$OUT/test_sat"
  "$OUT/test_sat" > "$OUT/sat.txt"
  cat "$OUT/sat.txt"
  grep -Fq 'PPA_WU05A6_SATURATED_EXCHANGE=PASS' "$OUT/sat.txt"
done
cmp "$BUILD/o0/sorp.txt" "$BUILD/o2/sorp.txt"
cmp "$BUILD/o0/unsat.txt" "$BUILD/o2/unsat.txt"
cmp "$BUILD/o0/sat.txt" "$BUILD/o2/sat.txt"
echo 'PPA_WU05A6_R1A_GATE=PASS'

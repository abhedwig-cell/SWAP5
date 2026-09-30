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
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a6_sorptivity_rate.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/sorp.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
  cat "$OUT/out.txt"
  grep -Fq 'PPA_WU05A6_SORPTIVITY_RATE=PASS' "$OUT/out.txt"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
echo 'PPA_WU05A6_R1A_GATE=PASS'

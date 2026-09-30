#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05a5-top-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     src/runtime/mod_macropore_continuation_state.f90 -o "$OUT/state.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     research/macropore/mod_ppa_wu05a5_top_partition.f90 -o "$OUT/partition.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     research/macropore/mod_ppa_wu05a5_multi_domain_process.f90 -o "$OUT/multi.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a5_top_partition.f90 -o "$OUT/test_top.o"
  gfortran -O"$opt" "$OUT/state.o" "$OUT/partition.o" "$OUT/multi.o" "$OUT/test_top.o" -o "$OUT/test_top"
  "$OUT/test_top" > "$OUT/top.txt"
  grep -Fq 'PPA_WU05A5_TOP_PARTITION=PASS' "$OUT/top.txt"

  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a5_multi_domain_process.f90 -o "$OUT/test_multi.o"
  gfortran -O"$opt" "$OUT/state.o" "$OUT/partition.o" "$OUT/multi.o" "$OUT/test_multi.o" -o "$OUT/test_multi"
  "$OUT/test_multi" > "$OUT/multi.txt"
  cat "$OUT/multi.txt"
  grep -Fq 'PPA_WU05A5_MULTI_DOMAIN_COMPOSITION=PASS' "$OUT/multi.txt"
done
cmp "$BUILD/o0/top.txt" "$BUILD/o2/top.txt"
cmp "$BUILD/o0/multi.txt" "$BUILD/o2/multi.txt"
echo 'PPA_WU05A5_TOP_PARTITION_GATE=PASS'

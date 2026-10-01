#!/usr/bin/env bash
set -euo pipefail
BUILD="${TMPDIR:-/tmp}/swap5-perch19"
rm -rf "$BUILD"; mkdir -p "$BUILD"
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -O"$opt" \
    -J "$OUT" -I "$OUT" -c src/transaction/mod_ppa_wu05_perch19_frreduq_controller.f90 -o "$OUT/controller.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -O"$opt" \
    -J "$OUT" -I "$OUT" -c tests/fpm/test_ppa_wu05_perch19_frreduq_controller.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/controller.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/out.txt"
  grep -Fq 'PPA_WU05_PERCH19_TEMPORAL_ORDERING=PASS' "$OUT/out.txt"
  grep -Fq 'PPA_WU05_PERCH19_REDUCTION_LADDER=PASS' "$OUT/out.txt"
  grep -Fq 'PPA_WU05_PERCH19_REJECT_ISOLATION=PASS' "$OUT/out.txt"
  grep -Fq 'PPA_WU05_PERCH19_RESTART_PAYLOAD=PASS' "$OUT/out.txt"
  grep -Fq 'PPA_WU05_PERCH19_RECOVERY_RULE=PASS' "$OUT/out.txt"
  grep -Fq 'PPA_WU05_PERCH19_CONTROLLER_GATE=PASS' "$OUT/out.txt"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
echo "PPA_WU05_PERCH19_O0_O2_IDENTITY=PASS"

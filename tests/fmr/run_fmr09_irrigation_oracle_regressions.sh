#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr09-irrigation-oracles-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ20_COMMIT=1c77752a69d74b1e8247f515aa37649e8d4200d2
FVQ20_ORACLE_BLOB=c932f83a77300b511c145f0ed87fdfbc7ecfe342
FVQ18_COMMIT=973d2b9d38917a4a459f51b6b46dd51cfd9690c4
FVQ18_ORACLE_BLOB=15989f375b557237eb36590f75361c02d19bb871
QUALIFIED_IRRIGATION_PROCESS_BLOB=c0755c1e0d0b7ca1a35e73cf26158c29e9940aec

[[ "$(git rev-parse "${FVQ20_COMMIT}:tests/fvq/test_fvq20_scheduled_irrigation_oracle.f90")" == "$FVQ20_ORACLE_BLOB" ]]
[[ "$(git rev-parse "${FVQ18_COMMIT}:tests/fvq/test_fvq18_fixed_irrigation_oracle.f90")" == "$FVQ18_ORACLE_BLOB" ]]
[[ "$(git hash-object src/process/mod_irrigation_process.f90)" == "$QUALIFIED_IRRIGATION_PROCESS_BLOB" ]]
echo 'FMR09_IRRIGATION_ORACLE_SOURCE_LOCKS=PASS'

git show "${FVQ20_COMMIT}:tests/fvq/test_fvq20_scheduled_irrigation_oracle.f90" > "$BUILD/test_fvq20.f90"
git show "${FVQ18_COMMIT}:tests/fvq/test_fvq18_fixed_irrigation_oracle.f90" > "$BUILD/test_fvq18.f90"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -Werror=compare-reals -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/process/mod_irrigation_process.f90 -o "$OUT/mod_irrigation_process.o"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    "$BUILD/test_fvq20.f90" "$OUT/mod_irrigation_process.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_soil_water_solver_contract.o" -o "$OUT/fvq20"
  "$OUT/fvq20" > "$OUT/fvq20.txt" 2>&1 || { cat "$OUT/fvq20.txt" >&2; exit 1; }
  for marker in \
    'FVQ20_EXPLICIT_SELECTION_NONMIDNIGHT=PASS' \
    'FVQ20_TCS7_TRIGGER_ORACLE=PASS' \
    'FVQ20_DCS2_TRANSLATED_DEPTH_ORACLE=PASS' \
    'FVQ20_SINGLE_NODE_SSDI_ORACLE=PASS' \
    'FVQ20_AFGEN_BOUNDARY_ORACLE=PASS' \
    'FVQ20_PARTIAL_TABLE_FAIL_CLOSED=PASS' \
    'FVQ20_CONTINUATION_NO_SELECTION_REQUIRED=PASS' \
    'FVQ20_COMPLETION_NO_IMPLICIT_RETRIGGER=PASS' \
    'FVQ20_SPLIT_NO_MUTATION=PASS' \
    'FVQ20_ROLLBACK_REPLAY=PASS' \
    'FVQ20_A_B_A=PASS' \
    'FVQ20_SCHEDULED_IRRIGATION_SCIENTIFIC_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/fvq20.txt"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    "$BUILD/test_fvq18.f90" "$OUT/mod_irrigation_process.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_soil_water_solver_contract.o" -o "$OUT/fvq18"
  "$OUT/fvq18" > "$OUT/fvq18.txt" 2>&1 || { cat "$OUT/fvq18.txt" >&2; exit 1; }
  grep -Fq 'FVQ18_FIXED_IRRIGATION_SCIENTIFIC_ORACLE PASS' "$OUT/fvq18.txt"

  cat "$OUT/fvq20.txt" "$OUT/fvq18.txt" > "$OUT/output.txt"
  echo "FMR09_IRRIGATION_ORACLES_O${opt}=PASS"
done

cmp "$BUILD/o0/fvq20.txt" "$BUILD/o2/fvq20.txt"
cmp "$BUILD/o0/fvq18.txt" "$BUILD/o2/fvq18.txt"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR09_IRRIGATION_ORACLES_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMR09_FVQ20_SCHEDULED_ORACLE_REPLAY=PASS'
echo 'FMR09_FVQ18_FIXED_ORACLE_REPLAY=PASS'
echo 'FMR09_IRRIGATION_ORACLE_REGRESSION_GATE PASS'

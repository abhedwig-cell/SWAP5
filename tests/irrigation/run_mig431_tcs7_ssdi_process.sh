#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-mig431-tcs7-ssdi-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_irrigation_process.f90
  src/runtime/mod_fmr_irrigation_restart.f90
  src/runtime/mod_fmr_irrigation_source_binding.f90
)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${SOURCES[@]}"; do
    object="$OUT/$(basename "${source%.*}").o"
    strict=()
    if [[ "$source" == src/process/mod_irrigation_process.f90 || \
          "$source" == src/runtime/mod_fmr_irrigation_restart.f90 || \
          "$source" == src/runtime/mod_fmr_irrigation_source_binding.f90 ]]; then strict=(-Werror); fi
    gfortran "${COMMON[@]}" "${strict[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$object"
    objects+=("$object")
  done
  test_obj="$OUT/test.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/irrigation/test_mig431_tcs7_ssdi_process.f90 -o "$test_obj"
  gfortran -O"$opt" "${objects[@]}" "$test_obj" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'F_MIG431_TCS7_SSDI_FORMULA=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_TCS8_THETA_FORMULA=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_TCS2_TCS3_TCS4_ROOT_DEPLETION=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_TCS6_WEEKLY_DEFICIT=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_DCS1_DCSLIM_RAIN=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_SCHEDULED_APPLICATION_ROUTE_TYPES=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_FIXED_IRRIGATION_EVENTS=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_TCS7_SSDI_SPLIT_REPLAY=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_TCS7_SSDI_MASS_CLOSURE=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_TCS7_SSDI_RESTART=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_SSDI_RUNTIME_SOURCE_BINDING=PASS' "$OUT/output.txt"
  grep -Fq 'F_MIG431_SCHEDULED_RATE_ADAPTATION_RESTART=PASS' "$OUT/output.txt"
  echo "F_MIG431_TCS7_SSDI_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo 'F_MIG431_TCS7_SSDI_PROCESS_QUALIFICATION=PASS'

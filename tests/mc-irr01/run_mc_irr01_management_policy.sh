#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mc-irr01-policy-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/solver.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_scheduled_irrigation_management_policy.f90 -o "$OUT/policy.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_irrigation_availability_policy.f90 -o "$OUT/availability.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_irrigation_root_zone_summary.f90 -o "$OUT/rootzone.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_irrigation_process.f90 -o "$OUT/irrigation.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_scheduled_management_irrigation_application.f90 -o "$OUT/application.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_irrigation_management_restart.f90 -o "$OUT/restart.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/mc-irr01/test_mc_irr01_management_policy.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/solver.o" "$OUT/view.o" "$OUT/policy.o" "$OUT/availability.o" "$OUT/rootzone.o" "$OUT/irrigation.o" "$OUT/application.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/mc-irr01/test_mc_irr01_management_application.f90 -o "$OUT/test_application.o"
  gfortran -O"$opt" "$OUT/solver.o" "$OUT/view.o" "$OUT/policy.o" "$OUT/availability.o" "$OUT/rootzone.o" "$OUT/irrigation.o" "$OUT/application.o" "$OUT/test_application.o" -o "$OUT/test_application"
  "$OUT/test_application" > "$OUT/application_output.txt" 2>&1 || { cat "$OUT/application_output.txt" >&2; exit 1; }
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/mc-irr01/test_mc_irr01_management_restart.f90 -o "$OUT/test_restart.o"
  gfortran -O"$opt" "$OUT/solver.o" "$OUT/view.o" "$OUT/policy.o" "$OUT/availability.o" "$OUT/rootzone.o" "$OUT/irrigation.o" "$OUT/application.o" "$OUT/restart.o" "$OUT/test_restart.o" -o "$OUT/test_restart"
  "$OUT/test_restart" > "$OUT/restart_output.txt" 2>&1 || { cat "$OUT/restart_output.txt" >&2; exit 1; }
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/mc-irr01/test_mc_irr01_availability_nonfinite.f90 -o "$OUT/test_availability_nonfinite.o"
  gfortran -O"$opt" "$OUT/availability.o" "$OUT/test_availability_nonfinite.o" -o "$OUT/test_availability_nonfinite"
  "$OUT/test_availability_nonfinite" > "$OUT/nonfinite_output.txt" 2>&1 || { cat "$OUT/nonfinite_output.txt" >&2; exit 1; }
  grep -Fq 'MC_IRR01_AVAILABILITY_NONFINITE=PASS' "$OUT/nonfinite_output.txt"
  grep -Fq 'MC_IRR01_MANAGEMENT_POLICY=PASS' "$OUT/output.txt"
  grep -Fq 'MC_IRR01_ROOT_ZONE_SUMMARY=PASS' "$OUT/output.txt"
  grep -Fq 'MC_IRR01_MANAGEMENT_APPLICATION=PASS' "$OUT/application_output.txt"
  grep -Fq 'MC_IRR01_AVAIL_MANAGEMENT_POLICY=PASS' "$OUT/application_output.txt"
  grep -Fq 'MC_IRR01_TCS2346_DCS2_COMPOSITION=PASS' "$OUT/application_output.txt"
  grep -Fq 'MC_IRR01_TCS2346_DCS1_EVENT_LIFECYCLE=PASS' "$OUT/application_output.txt"
  grep -Fq 'MC_IRR01_MANAGEMENT_RETRY_CONTINUATION=PASS' "$OUT/application_output.txt"
  grep -Fq 'MC_IRR01_TCS6_WEEK_COUNTER_RESTART=PASS' "$OUT/restart_output.txt"
  grep -Fq 'MC_IRR01_MANAGEMENT_EVENT_RESTART_CONTINUATION=PASS' "$OUT/restart_output.txt"
  grep -Fq 'MC_IRR01_MANAGEMENT_RESTART_FAIL_CLOSED=PASS' "$OUT/restart_output.txt"
  echo "MC_IRR01_MANAGEMENT_POLICY_O${opt}=PASS"
done
cmp -s "$BUILD/o0/nonfinite_output.txt" "$BUILD/o2/nonfinite_output.txt"
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cmp -s "$BUILD/o0/application_output.txt" "$BUILD/o2/application_output.txt"
cmp -s "$BUILD/o0/restart_output.txt" "$BUILD/o2/restart_output.txt"
cat "$BUILD/o0/output.txt"
cat "$BUILD/o0/application_output.txt"
cat "$BUILD/o0/restart_output.txt"
echo "MC_IRR01_MANAGEMENT_POLICY_SHA256=$(cat "$BUILD/o0/output.txt" "$BUILD/o0/application_output.txt" "$BUILD/o0/restart_output.txt" | sha256sum | awk '{print $1}')"
echo 'MC_IRR01_MANAGEMENT_POLICY_QUALIFICATION=PASS'

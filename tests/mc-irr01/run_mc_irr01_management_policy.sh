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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/solver.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_scheduled_irrigation_management_policy.f90 -o "$OUT/policy.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_irrigation_root_zone_summary.f90 -o "$OUT/rootzone.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/mc-irr01/test_mc_irr01_management_policy.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/solver.o" "$OUT/view.o" "$OUT/policy.o" "$OUT/rootzone.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt"
  grep -Fq 'MC_IRR01_MANAGEMENT_POLICY=PASS' "$OUT/output.txt"
  grep -Fq 'MC_IRR01_ROOT_ZONE_SUMMARY=PASS' "$OUT/output.txt"
  echo "MC_IRR01_MANAGEMENT_POLICY_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "MC_IRR01_MANAGEMENT_POLICY_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'MC_IRR01_MANAGEMENT_POLICY_QUALIFICATION=PASS'

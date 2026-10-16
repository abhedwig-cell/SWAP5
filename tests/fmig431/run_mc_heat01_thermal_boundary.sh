#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/mc-heat01-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

DEP=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Wno-error=unused-dummy-argument -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

compile_and_run() {
  local opt="$1" out="$2"
  gfortran "${DEP[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${DEP[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/solver_contract.o"
  gfortran "${DEP[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_process_hydraulic_view.f90 -o "$out/hydraulic_view.o"
  gfortran "${STRICT[@]}" "$opt" -J "$out" -I "$out" -c src/process/mod_soil_temperature_contract.f90 -o "$out/thermal_contract.o"
  gfortran "${STRICT[@]}" "$opt" -J "$out" -I "$out" -c src/process/mod_restricted_soil_temperature.f90 -o "$out/thermal_process.o"
  gfortran "${STRICT[@]}" "$opt" -J "$out" -I "$out" -c tests/fmig431/test_mc_heat01_thermal_boundary.f90 -o "$out/test.o"
  gfortran "$opt" "$out/transaction.o" "$out/solver_contract.o" "$out/hydraulic_view.o" \
    "$out/thermal_contract.o" "$out/thermal_process.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  "$out/test" > "$out/output-repeat.txt"
  cmp "$out/output.txt" "$out/output-repeat.txt"

  # Replay the admitted F-VQ58/F-CI43 oracle against the additive contract.
  # Its byte-stable output proves the default numerical route was not changed.
  gfortran "${STRICT[@]}" "$opt" -J "$out" -I "$out" \
    -c tests/fci/test_fci43_restricted_soil_temperature_independent.f90 -o "$out/default-preservation-test.o"
  gfortran "$opt" "$out/transaction.o" "$out/solver_contract.o" "$out/hydraulic_view.o" \
    "$out/thermal_contract.o" "$out/thermal_process.o" "$out/default-preservation-test.o" \
    -o "$out/default-preservation-test"
  "$out/default-preservation-test" > "$out/default-preservation-output.txt"
  "$out/default-preservation-test" > "$out/default-preservation-output-repeat.txt"
  cmp "$out/default-preservation-output.txt" "$out/default-preservation-output-repeat.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cmp "$BUILD/o0/default-preservation-output.txt" "$BUILD/o2/default-preservation-output.txt"
for marker in \
  MC_HEAT01_BC3_BC4_BOTTOM2_O0O2=PASS \
  MC_HEAT01_ANALYTIC_B111_PROFILE=PASS \
  MC_HEAT01_SNOW_RESISTANCE_COMPONENT_ONLY=PASS \
  MC_HEAT01_ENERGY_STATE_RESTART_CONTRACTS=PASS \
  MC_HEAT01_PROCESS_GATE=PASS; do
  grep -Fxq "$marker" "$BUILD/o0/output.txt"
done
DEFAULT_OUTPUT_SHA256="$(sha256sum "$BUILD/o0/default-preservation-output.txt" | awk '{print $1}')"
test "$DEFAULT_OUTPUT_SHA256" = e62c39e6fb3e71351fde4c949fb4c639d7fa16bb19fd593b55448432ae5ae583
grep -Fxq 'FVQ58_INDEPENDENT_ORACLE=PASS' "$BUILD/o0/default-preservation-output.txt"
cat "$BUILD/o0/output.txt"
echo "MC_HEAT01_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'MC_HEAT01_O0_O2_REPEAT_DETERMINISM=PASS'
echo "MC_HEAT01_DEFAULT_FVQ58_OUTPUT_SHA256=$DEFAULT_OUTPUT_SHA256"
echo 'MC_HEAT01_DEFAULT_NUMERICAL_ROUTE_PRESERVATION=PASS'

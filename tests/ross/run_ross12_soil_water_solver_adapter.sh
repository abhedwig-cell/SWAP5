#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross12-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
STEPDIR=src/solver/mod_soil_water_accepted_step_direction_contract.f90
TRAJSENS=src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
TRAJPUB=src/transaction/mod_accepted_trajectory_directional_publication.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
SW=src/solver/mod_soil_water_solver_contract.f90
REFBIND=src/solver/mod_reference_richards_state_binding.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
BINDING=src/runtime/mod_rossfast_d3r_model_binding.f90
KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
ADAPTER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
TEST=tests/ross/test_ross12_soil_water_solver_adapter.f90

test "$(git rev-parse HEAD:$SW)" = 276941d76ba951a89c43899e61fd0532418d8230
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
test "$(git rev-parse HEAD:$BINDING)" = 9f29ba7a08844692ba2628c7869d23713409f92b
test "$(git rev-parse HEAD:$KERNEL)" = 034136c193b287bcf9a953a9b89df2a8fb0c97cc
test "$(git rev-parse HEAD:$PROVIDER)" = afc05eb3001d91f66ca542978c3c6795283a7ac0

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  m="$BUILD/$opt"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$TX" -o "$m/tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$STEPDIR" -o "$m/stepdir.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$TRAJSENS" -o "$m/trajsens.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$TRAJPUB" -o "$m/trajpub.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$CONTRACTS" -o "$m/contracts.o"
  gfortran "${WARN[@]}" -Wno-error=unused-dummy-argument "$flag" -std=f2008 -J "$m" -I "$m" -c "$SW" -o "$m/sw.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$REFBIND" -o "$m/refbind.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$POLICY" -o "$m/policy.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$BINDING" -o "$m/binding.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$KERNEL" -o "$m/kernel.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$PROVIDER" -o "$m/provider.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$ADAPTER" -o "$m/adapter.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$m" -I "$m" -c "$TEST" -o "$m/test.o"
  gfortran -fopenmp "$m/tx.o" "$m/stepdir.o" "$m/trajsens.o" "$m/trajpub.o" "$m/contracts.o" "$m/sw.o" \
    "$m/refbind.o" "$m/policy.o" "$m/binding.o" "$m/kernel.o" "$m/provider.o" "$m/adapter.o" "$m/test.o" -o "$m/test"
  if ! "$m/test" assets/rossfast > "$m/output.txt"; then
    cat "$m/output.txt"
    exit 1
  fi
  grep -Fq 'ROSS12_SOIL_WATER_SOLVER_ADAPTER PASS' "$m/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "F_ROSS12_SOLVER_ADAPTER_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "F_ROSS12_SOLVER_ADAPTER=PASS"

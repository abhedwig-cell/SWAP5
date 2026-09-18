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
ASSET_ROOT=assets/rossfast/d3r

# PUB-P2E05 is a typed diagnostic ABI successor only. Rebind the frozen
# adapter qualification to the new solver-contract blob; all RossFast policy,
# model, kernel and provider authorities remain frozen below.
test "$(git rev-parse HEAD:$SW)" = 40a1ddc05fb8e2c1822763de645fd07a094568a3

# Exact RossFast successor lineage. Historical F-ROSS12 remains the default;
# only independently qualified exact postimages are recognized.
HIST_MODEL=9f29ba7a08844692ba2628c7869d23713409f92b
HIST_PROVIDER=afc05eb3001d91f66ca542978c3c6795283a7ac0
HIST_KERNEL=034136c193b287bcf9a953a9b89df2a8fb0c97cc
HIST_ADAPTER=dbb441f3529be179d64fb57f9c44336d3d20c540
FROSS13_MODEL=5442fd7e7a2f392c9b796cd17c76b17977259f22
FROSS13_PROVIDER=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
FCI107_CACHE_KERNEL=2ad2a680e62744451d6763de48585f1bd45d3067
FROSS22_TIERED_KERNEL=438ee46e012e9eb183b8f2532437e2fe56aa18ed
FROSS22_TIERED_ADAPTER=2b134c36097aed2a44a56bfe8e2194b15aa063aa
EXPECTED_MODEL="$HIST_MODEL"
EXPECTED_PROVIDER="$HIST_PROVIDER"
EXPECTED_KERNEL="$HIST_KERNEL"
EXPECTED_ADAPTER="$HIST_ADAPTER"
ROSSFAST_TIERED_MODE=0

current_model="$(git rev-parse HEAD:$BINDING)"
current_provider="$(git rev-parse HEAD:$PROVIDER)"
current_kernel="$(git rev-parse HEAD:$KERNEL)"
current_adapter="$(git rev-parse HEAD:$ADAPTER)"

if [[ "$current_model" == "$FROSS13_MODEL" && "$current_provider" == "$FROSS13_PROVIDER" ]]; then
  EXPECTED_MODEL="$FROSS13_MODEL"
  EXPECTED_PROVIDER="$FROSS13_PROVIDER"
  if [[ "$current_kernel" == "$FROSS22_TIERED_KERNEL" && "$current_adapter" == "$FROSS22_TIERED_ADAPTER" ]]; then
    EXPECTED_KERNEL="$FROSS22_TIERED_KERNEL"
    EXPECTED_ADAPTER="$FROSS22_TIERED_ADAPTER"
    ROSSFAST_TIERED_MODE=1
    echo 'F_ROSS12_EXACT_FROSS22_TIERED_SUCCESSOR=PASS'
  elif [[ "$current_kernel" == "$FCI107_CACHE_KERNEL" && "$current_adapter" == "$HIST_ADAPTER" ]]; then
    EXPECTED_KERNEL="$FCI107_CACHE_KERNEL"
    echo 'F_ROSS12_EXACT_FCI107_CACHE_SUCCESSOR=PASS'
  elif [[ "$current_kernel" == "$HIST_KERNEL" && "$current_adapter" == "$HIST_ADAPTER" ]]; then
    echo 'F_ROSS12_EXACT_FROSS13_STATIC_SUCCESSOR=PASS'
  else
    echo 'F_ROSS12_SUCCESSOR_LINEAGE_FAIL unexpected RossFast kernel/adapter pair' >&2
    exit 1
  fi
fi
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
test "$(git rev-parse HEAD:$BINDING)" = "$EXPECTED_MODEL"
test "$(git rev-parse HEAD:$KERNEL)" = "$EXPECTED_KERNEL"
test "$(git rev-parse HEAD:$PROVIDER)" = "$EXPECTED_PROVIDER"
test "$(git rev-parse HEAD:$ADAPTER)" = "$EXPECTED_ADAPTER"

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
  if ! SWAP5_ROSSFAST_EXPECT_TIERED_WORK="$ROSSFAST_TIERED_MODE" "$m/test" "$ASSET_ROOT" > "$m/output.txt"; then
    cat "$m/output.txt"
    exit 1
  fi
  grep -Fq 'ROSS12_SOIL_WATER_SOLVER_ADAPTER PASS' "$m/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "F_ROSS12_SOLVER_ADAPTER_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "F_ROSS12_SOLVER_ADAPTER=PASS"

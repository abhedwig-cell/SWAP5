#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross13-ross12-preservation-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail() { echo "F_ROSS13_ROSS12_PRESERVATION_FAIL $*" >&2; exit 1; }

TX=src/transaction/mod_transaction_reference.f90
STEPDIR=src/solver/mod_soil_water_accepted_step_direction_contract.f90
TRAJSENS=src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
A23BU=src/runtime/mod_a23bu_worker_execution_context.f90
TRAJPUB=src/transaction/mod_accepted_trajectory_directional_publication.f90
FKTHIST=src/transaction/mod_fkt_temporal_indicator_history.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
SW=src/solver/mod_soil_water_solver_contract.f90
REFBIND=src/solver/mod_reference_richards_state_binding.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
MODEL=src/runtime/mod_rossfast_d3r_model_binding.f90
KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
ADAPTER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
APP_HOST=src/runtime/mod_fmr_soil_water_application_host.f90
SELECTION=src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
TEST_ADAPTER=tests/ross/test_ross12_soil_water_solver_adapter.f90
TEST_SELECTION=tests/ross/test_ross12_solver_selection_binding.f90
ASSET_ROOT=assets/rossfast/d3r

# Preserve all F-ROSS12 authorities that F-ROSS13 is not authorized to change.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331 || fail 'transaction authority drift'
test "$(git rev-parse HEAD:$SW)" = 40a1ddc05fb8e2c1822763de645fd07a094568a3 || fail 'solver contract drift'
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9 || fail 'RossFast policy drift'
test "$(git rev-parse HEAD:$KERNEL)" = 034136c193b287bcf9a953a9b89df2a8fb0c97cc || fail 'RossFast kernel drift'
test "$(git rev-parse HEAD:$ADAPTER)" = dbb441f3529be179d64fb57f9c44336d3d20c540 || fail 'RossFast adapter drift'
test "$(git rev-parse HEAD:$APP_HOST)" = daca18b77673608436425e81ecd397ef3e35e4b2 || fail 'application host drift'
test "$(git rev-parse HEAD:$SELECTION)" = cca61af52bde3eed12b756547277cc2776589648 || fail 'solver selection binding drift'

# MODEL and PROVIDER are intentionally not pinned to the historical six-material
# blobs here. The enclosing F-ROSS13 transaction proves their exact two-file,
# catalog-derived mutation from those pinned preimages before this runner starts.
echo 'F_ROSS13_ROSS12_UNCHANGED_AUTHORITIES=PASS'
echo 'F_ROSS13_ROSS12_MODEL_PROVIDER_INTENTIONAL_SUCCESSOR_SCOPE=PASS'

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp)
MODULE_SRC=(
  "$TX" "$STEPDIR" "$TRAJSENS" "$A23BU" "$TRAJPUB" "$FKTHIST" "$CONTRACTS"
  "$SW" "$REFBIND" "$POLICY" "$MODEL" "$KERNEL" "$PROVIDER" "$ADAPTER"
  "$APP_HOST" "$SELECTION"
)

for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  m="$BUILD/$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$m/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "$SW" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${WARN[@]}" "${extra[@]}" "$flag" -std=f2008 -ffree-line-length-none -J "$m" -I "$m" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${WARN[@]}" "$flag" -std=f2008 -ffree-line-length-none -J "$m" -I "$m" -c "$TEST_ADAPTER" -o "$m/test_adapter.o"
  gfortran -fopenmp "${objects[@]:0:14}" "$m/test_adapter.o" -o "$m/test_adapter"
  if ! "$m/test_adapter" "$ASSET_ROOT" > "$m/adapter_output.txt"; then
    cat "$m/adapter_output.txt" >&2
    fail "Ross12 adapter runtime oracle $opt"
  fi
  grep -Fq 'ROSS12_SOIL_WATER_SOLVER_ADAPTER PASS' "$m/adapter_output.txt" || fail "Ross12 adapter marker $opt"

  gfortran "${WARN[@]}" "$flag" -std=f2008 -ffree-line-length-none -J "$m" -I "$m" -c "$TEST_SELECTION" -o "$m/test_selection.o"
  gfortran -fopenmp "${objects[@]}" "$m/test_selection.o" -o "$m/test_selection"
  if ! "$m/test_selection" "$ASSET_ROOT" > "$m/selection_output.txt"; then
    cat "$m/selection_output.txt" >&2
    fail "Ross12 selection runtime oracle $opt"
  fi
  grep -Fq 'ROSS12_SOLVER_SELECTION_BINDING PASS' "$m/selection_output.txt" || fail "Ross12 selection marker $opt"
  echo "F_ROSS13_ROSS12_UNIT_PRESERVATION_${opt^^}=PASS"
done

cmp "$BUILD/o0/adapter_output.txt" "$BUILD/o2/adapter_output.txt"
cmp "$BUILD/o0/selection_output.txt" "$BUILD/o2/selection_output.txt"
cat "$BUILD/o0/adapter_output.txt"
cat "$BUILD/o0/selection_output.txt"
echo "F_ROSS13_ROSS12_ADAPTER_O0_O2_SHA256=$(sha256sum "$BUILD/o0/adapter_output.txt" | awk '{print $1}')"
echo "F_ROSS13_ROSS12_SELECTION_O0_O2_SHA256=$(sha256sum "$BUILD/o0/selection_output.txt" | awk '{print $1}')"
echo 'F_ROSS13_ROSS12_UNIT_SEMANTIC_SUCCESSOR_PRESERVATION=PASS'

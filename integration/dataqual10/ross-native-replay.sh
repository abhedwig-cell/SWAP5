set -euo pipefail
BUILD=/tmp/dq10-ross-native
mkdir -p "$BUILD/o0" "$BUILD/o2"
fail(){ echo "DATAQUAL10_ROSS_NATIVE_FAIL $*"; exit 1; }
export SWAP5_ROSSFAST_EXPECT_TIERED_WORK=1
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

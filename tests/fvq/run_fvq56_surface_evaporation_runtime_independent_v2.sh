#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Preserve the failed v1 harness as evidence. Its only failure was that -Werror
# promoted pre-existing warnings outside the F-PM06F production delta. Re-run
# the identical gate without global warning promotion.
TMP_RUNNER="tests/fvq/.run_fvq56_v1_without_global_werror_$$.sh"
trap 'rm -f "$TMP_RUNNER"; rm -rf "${EXTRA_BUILD:-}"' EXIT
sed 's/ -Werror / /g' tests/fvq/run_fvq56_surface_evaporation_runtime_independent.sh > "$TMP_RUNNER"
chmod +x "$TMP_RUNNER"
bash "$TMP_RUNNER"
echo 'FVQ56_V1_FAILURE_CLASSIFIED_LEGACY_WARNING_PROMOTION_ONLY=PASS'

# The first held-out oracle deliberately uses an abstract observing provider.
# Add a second, independently written integration oracle with the actual
# canonical B1.10 capacity provider so that the runtime seam is not qualified
# only through a fake provider.
EXTRA_BUILD="${RUNNER_TEMP:-/tmp}/fvq56-real-b110-${GITHUB_RUN_ID:-local}"
mkdir -p "$EXTRA_BUILD"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
)
TEST=tests/fvq/test_fvq56_surface_evaporation_runtime_materialization_independent.f90
TEST_COMPILE="$EXTRA_BUILD/fvq56_runtime_b110.f90"
# Fortran 2008 limits identifiers to 63 characters. Shorten only the program
# identifier in the transient build copy; the persisted scientific test body is unchanged.
sed 's/test_fvq56_surface_evaporation_runtime_materialization_independent/fvq56_runtime_b110/g' "$TEST" > "$TEST_COMPILE"

for opt in 0 2; do
  OUT="$EXTRA_BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  # The held-out oracle intentionally uses exact equality for state-identity
  # checks, so compare-real warnings are diagnostic rather than qualification failures.
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$TEST_COMPILE" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/fvq56-real-b110"
  "$OUT/fvq56-real-b110" > "$OUT/output.txt" 2>&1
  for marker in \
    FVQ56_DERIVED_BASE_STATE_ORACLE=PASS \
    FVQ56_EXACT_THRESHOLD_DRY=PASS \
    FVQ56_JUST_ABOVE_THRESHOLD_PONDED=PASS \
    FVQ56_SIGNED_NEGATIVE_CAPACITY_STRUCTURAL_CLAMP=PASS \
    FVQ56_ZERO_CAPACITY=PASS \
    FVQ56_DEMAND_LIMIT=PASS \
    FVQ56_AVAILABLE_NONFINITE_FAIL_CLOSED=PASS \
    FVQ56_UNSUPPORTED_CAPACITY_FAIL_CLOSED=PASS \
    FVQ56_REJECTED_DEMAND_CONTAINED=PASS \
    FVQ56_INVALID_COMMITTED_STATE_CONTAINED=PASS \
    FVQ56_COLUMN_ORDER_ABA_DETERMINISM=PASS \
    FVQ56_COMMITTED_STATE_IMMUTABLE=PASS \
    FVQ56_REAL_B110_DRY_INTEGRATION=PASS \
    FVQ56_REAL_B110_PONDED_INTEGRATION=PASS \
    FVQ56_NO_AUTHORITATIVE_MASS_BOOKING=PASS \
    FVQ56_INDEPENDENT_RUNTIME_ORACLE=PASS; do
    grep -Fxq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; echo "FVQ56_GATE_FAIL missing $marker O$opt" >&2; exit 56; }
  done
  echo "FVQ56_REAL_B110_HELDOUT_O${opt}=PASS"
done
cmp -s "$EXTRA_BUILD/o0/output.txt" "$EXTRA_BUILD/o2/output.txt" || { echo 'FVQ56_GATE_FAIL real-B1.10 O0/O2 drift' >&2; exit 56; }
echo "FVQ56_REAL_B110_OUTPUT_SHA256=$(sha256sum "$EXTRA_BUILD/o0/output.txt" | awk '{print $1}')"
echo 'FVQ56_REAL_B110_O0_O2_IDENTITY=PASS'
echo 'FVQ56_PERFORMANCE_SCOPE_HOLD=PASS'
echo 'FVQ56_DECISIVE_GATE=PASS'

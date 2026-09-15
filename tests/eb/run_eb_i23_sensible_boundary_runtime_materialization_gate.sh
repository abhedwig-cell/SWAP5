#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i23-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I23_GATE_FAIL $*" >&2; exit 223; }

CANONICAL="3ff0f42299767d5ad5f07d031698dfcf7969ed0d"
BRANCH="work/eb-i23-sensible-boundary-runtime-materialization"
MODULE="src/runtime/mod_eb_i23_sensible_boundary_runtime.f90"
TEST="tests/eb/test_eb_i23_sensible_boundary_runtime_materialization.f90"
CONTRACT="tests/eb/EB-I23_CONTRACT.md"

# Current-canonical race guard.
git fetch -q origin integration/f-ci-canonical
LIVE_CANONICAL="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$LIVE_CANONICAL" == "$CANONICAL" ]] || fail "live canonical moved: $LIVE_CANONICAL != $CANONICAL"
[[ "$(git merge-base "$CANONICAL" HEAD)" == "$CANONICAL" ]] || fail 'branch is not descended from pinned canonical'
echo "EB_I23_LIVE_CANONICAL_LOCK=PASS sha=$CANONICAL"

# EB-I23 binds existing authorities; it must not mutate them to make the new
# materialization pass.
declare -A AUTHORITY_BLOBS=(
  [src/process/mod_restricted_soil_temperature.f90]=fa4e1d7b48d3515e6569c9080d497178c25c4e85
  [src/process/mod_soil_temperature_contract.f90]=baa13df3975de2c699b0ec910477bcfa9b47f15e
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=3506b453ba6a00111d182f29db8cbfb288001854
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/process/mod_whole_column_sensible_energy_accounting.f90]=c00efd8cdb4de947de16e1d32ae4c9f4d0590850
)
for path in "${!AUTHORITY_BLOBS[@]}"; do
  actual="$(git hash-object "$path")"
  [[ "$actual" == "${AUTHORITY_BLOBS[$path]}" ]] || fail "authority drift $path $actual"
done
echo 'EB_I23_INHERITED_AUTHORITY_BLOBS=PASS'

# Bounded delta: one new runtime wrapper plus owner evidence only.
while IFS= read -r path; do
  case "$path" in
    "$MODULE"|"$TEST"|"$CONTRACT"|tests/eb/run_eb_i23_sensible_boundary_runtime_materialization_gate.sh|.github/workflows/eb-i23-sensible-boundary-runtime-materialization.yml) ;;
    *) fail "out-of-scope branch delta: $path" ;;
  esac
done < <(git diff --name-only "$CANONICAL" HEAD)
echo 'EB_I23_BOUNDED_DELTA=PASS'

# Static scientific/transactional contract.
grep -Fq 'call fmr_execute_serialized_column_with_bottom_energy' "$MODULE" || fail 'accepted bottom-energy owner seam not reused'
grep -Fq 'observation = backend%observation()' "$MODULE" || fail 'same-call thermal observation binding missing'
grep -Fq 'output%accepted_substeps == 1' "$MODULE" || fail 'single-substep thermal safety gate missing'
grep -Fq 'J_CM2_TO_J_M2 = 1.0e4_real64' "$MODULE" || fail 'explicit J/cm2 to J/m2 conversion missing'
grep -Fq 'publication%bottom_conductive_outward_j_m2_value = 0.0_real64' "$MODULE" || fail 'explicit restricted bottom conductive BC missing'
grep -Fq 'boundary%top_advective_available = .false.' "$MODULE" || fail 'top advective fail-closed projection missing'
! grep -Fq 'boundary%top_advective_available = .true.' "$MODULE" || fail 'unqualified top advective source was promoted'
grep -Fq 'No qualified canonical top-water donor-temperature authority exists' "$MODULE" || fail 'top donor nonclaim missing'
grep -Fq 'accepted_substeps /= 1' "$CONTRACT" || fail 'multi-substep nonclaim missing'
grep -Fq 'runtime_materialization_complete() == false' "$CONTRACT" || fail 'runtime completeness nonclaim missing'
echo 'EB_I23_STATIC_CONTRACT=PASS'

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
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_linear_mixture_sensible_storage.f90
  src/kernel/mod_energy_conservation_types.f90
  src/process/mod_whole_column_sensible_energy_accounting.f90
  "$MODULE"
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/eb_i23_test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/eb_i23_test.o" -o "$OUT/eb_i23_test"
  "$OUT/eb_i23_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "runtime materialization oracle O$opt"
  }

  for marker in \
    'EB_I23_ACCEPTED_SINGLE_SUBSTEP_PARTIAL_MATERIALIZATION=PASS' \
    'EB_I23_BOTTOM_ADVECTIVE_UNAVAILABLE_FAIL_CLOSED=PASS' \
    'EB_I23_REJECTED_TRIAL_NO_PUBLICATION=PASS' \
    'EB_I23_SENSIBLE_BOUNDARY_RUNTIME_MATERIALIZATION_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing marker O$opt: $marker"
    }
  done
  cat "$OUT/output.txt"
  echo "EB_I23_RUNTIME_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 semantic output drift'
}
echo 'EB_I23_O0_O2_SEMANTIC_IDENTITY=PASS'

git diff "$CANONICAL" HEAD --check -- "$MODULE" "$TEST" "$CONTRACT" tests/eb/run_eb_i23_sensible_boundary_runtime_materialization_gate.sh .github/workflows/eb-i23-sensible-boundary-runtime-materialization.yml
echo "EB_I23_OWNER_QUALIFICATION=PASS branch=$BRANCH canonical=$CANONICAL"
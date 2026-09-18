#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASELINE=0e68a716f655f9bba3a0962cf35ccb724b5184c3
CONTRACT=integration/f-rom/F-ROM01_REFERENCE_HISTORY_PILOT_CONTRACT.json
TEST=tests/rom/test_f_rom01_reference_histories.f90
VALIDATOR=tests/rom/validate_f_rom01_contract.py
ANALYZER=tests/rom/analyze_f_rom01_reference_histories.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom01-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE_DIR="${F_ROM01_EVIDENCE_DIR:-$ROOT/F-ROM01_EVIDENCE}"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$EVIDENCE_DIR"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "F_ROM01_GATE_FAIL $*" >&2; exit 1; }

for path in "$CONTRACT" "$TEST" "$VALIDATOR" "$ANALYZER"; do
  [[ -f "$path" ]] || fail "missing required file $path"
done

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE_HEAD="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE_HEAD="$(git rev-parse HEAD)"
fi

git merge-base --is-ancestor "$BASELINE" "$CANDIDATE_HEAD" ||   fail "canonical pilot baseline is not an ancestor of the workstream head"
git diff --quiet "$BASELINE...$CANDIDATE_HEAD" -- src reference ||   fail "F-ROM01 workstream mutated production/reference source"

echo "F_ROM01_CANDIDATE_HEAD=$CANDIDATE_HEAD"
echo "F_ROM01_PRODUCTION_REFERENCE_DELTA=NONE"

python3 "$VALIDATOR"   --contract "$CONTRACT"   --baseline "$BASELINE"   --candidate-head "$CANDIDATE_HEAD"   --test-source "$TEST"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
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
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)

compile_and_run() {
  local opt="$1"
  local out="$BUILD/o$opt"
  local objects=()
  local source obj
  local extra=()

  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$out/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] &&       extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$TEST" -o "$out/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"

  if ! "$out/test" > "$out/output.txt" 2>&1; then
    cat "$out/output.txt" >&2
    fail "reference-history runtime O$opt"
  fi

  grep -Fq 'F_ROM01_REFERENCE_HISTORY_PILOT=PASS' "$out/output.txt" || fail "missing O$opt pilot PASS"
  grep -Fq 'F_ROM01_PRODUCTION_SOURCE_MUTATION=NONE' "$out/output.txt" || fail "missing O$opt mutation marker"
  grep -Fq 'F_ROM01_SCIENTIFIC_SUFFICIENCY_VERDICT=NOT_SET_IN_PILOT' "$out/output.txt" || fail "missing O$opt interpretation boundary"
  [[ "$(grep -Fc 'F_ROM01_CONTINUATION|' "$out/output.txt")" = "3" ]] ||     fail "expected three O$opt continuation checkpoints"

  python3 "$ANALYZER"     --contract "$CONTRACT"     --input "$out/output.txt"     --output "$out/result.json"
}

compile_and_run 0
compile_and_run 2

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 reference-history output drift"
}

cmp -s "$BUILD/o0/result.json" "$BUILD/o2/result.json" || {
  diff -u "$BUILD/o0/result.json" "$BUILD/o2/result.json" >&2 || true
  fail "O0/O2 structured-result drift"
}

cp "$BUILD/o0/output.txt" "$EVIDENCE_DIR/F-ROM01_REFERENCE_HISTORY_PILOT_OUTPUT.txt"
cp "$BUILD/o0/result.json" "$EVIDENCE_DIR/F-ROM01_REFERENCE_HISTORY_PILOT_RESULT.json"
sha256sum   "$EVIDENCE_DIR/F-ROM01_REFERENCE_HISTORY_PILOT_OUTPUT.txt"   "$EVIDENCE_DIR/F-ROM01_REFERENCE_HISTORY_PILOT_RESULT.json"   > "$EVIDENCE_DIR/sha256.txt"

cat "$BUILD/o0/output.txt"
cat "$BUILD/o0/result.json"
echo "F_ROM01_O0_O2_IDENTITY=PASS"
echo "F_ROM01_REFERENCE_HISTORY_GATE=PASS"

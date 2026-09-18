#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE=405ad30e823ea44deedf73edc67c68e01564c617
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross18-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS18_GATE_FAIL $*" >&2; exit 1; }

PREREG=integration/f-ross/F-ROSS18_TEMPORAL_SUBSTEP_MATRIX_PREREGISTRATION.json
SCI_TEST=tests/ross/test_ross18_substep_matrix.f90
TIMING_TEST=tests/ross/test_ross18_route_timing.f90
SUMMARIZER=tools/performance/f_ross18_matrix_summary.py
PAIR_SCREEN=tools/performance/f_ross18_paired_screen.py
KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
SOLVER=src/solver/mod_rossfast_d3r_soil_water_solver.f90

for p in "$PREREG" "$SCI_TEST" "$TIMING_TEST" "$SUMMARIZER" "$PAIR_SCREEN" "$KERNEL" "$SOLVER"; do
  [[ -f "$p" ]] || fail "missing $p"
done

grep -Fq '"phase": "PREREGISTERED_RESEARCH_ONLY"' "$PREREG" || fail "preregistration drift"
grep -Fq '"production_mutation_allowed": false' "$PREREG" || fail "production firewall drift"
grep -Fq '"component_internal_substeps": 8' "$PREREG" || fail "K8 preregistration drift"
grep -Fq '"component_internal_substeps": 4' "$PREREG" || fail "K4 preregistration drift"
grep -Fq '"component_internal_substeps": 2' "$PREREG" || fail "K2 preregistration drift"

git cat-file -e "$SOURCE^{commit}" || fail "source commit unavailable"
git diff --quiet "$SOURCE" HEAD -- src reference || fail "F-ROSS18 must not mutate src or reference"
test "$(git rev-parse "$SOURCE:$KERNEL")" = "2ad2a680e62744451d6763de48585f1bd45d3067" || fail "F-ROSS17 kernel authority drift"
test "$(git rev-parse "$SOURCE:$SOLVER")" = "dbb441f3529be179d64fb57f9c44336d3d20c540" || fail "solver binding authority drift"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -O2)
MODULES_BEFORE_KERNEL=(
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
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
)
MODULES_AFTER_KERNEL=(
  src/solver/mod_rossfast_d3r_table_provider.f90
)

prepare_variant_sources() {
  local out="$1"
  local k="$2"
  mkdir -p "$out"
  git show "$SOURCE:$KERNEL" > "$out/mod_rossfast_d3r_table_kernel.f90"
  git show "$SOURCE:$SOLVER" > "$out/mod_rossfast_d3r_soil_water_solver.f90"
  python3 - "$out/mod_rossfast_d3r_table_kernel.f90" "$out/mod_rossfast_d3r_soil_water_solver.f90" "$k" <<'PY'
from pathlib import Path
import sys
kernel=Path(sys.argv[1])
solver=Path(sys.argv[2])
k=int(sys.argv[3])
kt=kernel.read_text()
st=solver.read_text()
oldk="integer, parameter :: CERTIFICATE_INTERNAL_SUBSTEPS = 8"
olds="integer, parameter :: ROSSFAST_INTERNAL_SUBSTEPS = 8"
if kt.count(oldk)!=1 or st.count(olds)!=1:
    raise SystemExit("substep constant authority drift")
kernel.write_text(kt.replace(oldk,f"integer, parameter :: CERTIFICATE_INTERNAL_SUBSTEPS = {k}"))
solver.write_text(st.replace(olds,f"integer, parameter :: ROSSFAST_INTERNAL_SUBSTEPS = {k}"))
PY
}

compile_variant() {
  local out="$1"
  local objects=()
  local source obj
  for source in "${MODULES_BEFORE_KERNEL[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    local extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  obj="$out/mod_rossfast_d3r_table_kernel.o"
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$out/mod_rossfast_d3r_table_kernel.f90" -o "$obj"
  objects+=("$obj")

  for source in "${MODULES_AFTER_KERNEL[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  obj="$out/mod_rossfast_d3r_soil_water_solver.o"
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$out/mod_rossfast_d3r_soil_water_solver.f90" -o "$obj"
  objects+=("$obj")

  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$SCI_TEST" -o "$out/science.o"
  gfortran -fopenmp -O2 "${objects[@]}" "$out/science.o" -o "$out/science"

  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$TIMING_TEST" -o "$out/timing.o"
  gfortran -fopenmp -O2 "${objects[@]}" "$out/timing.o" -o "$out/timing"
}

run_variant() {
  local id="$1"
  local k="$2"
  local lin="$3"
  local out="$BUILD/$id"
  prepare_variant_sources "$out" "$k"
  compile_variant "$out"

  SWAP5_ROSS18_EXPECTED_LINEAR_SOLVES="$lin" "$out/science" > "$out/science.txt"
  grep -Fq 'F_ROSS18_MATRIX_GATE=PASS' "$out/science.txt" || fail "$id science harness failed"
  python3 "$SUMMARIZER" --variant "$id" --expected-linear-solves "$lin" \
    --input "$out/science.txt" --output "$out/science-result.json" | tee "$out/science-summary.txt"
  grep -Fq 'F_ROSS18_SCIENCE_SUMMARY=PASS' "$out/science-summary.txt" || fail "$id science summary failed"

  python3 "$PAIR_SCREEN" --variant "$id" --expected-linear-solves "$lin" \
    --executable "$out/timing" --output "$out/performance-result.json" | tee "$out/performance-summary.txt"
  grep -Fq 'F_ROSS18_PERFORMANCE_GATE=PASS' "$out/performance-summary.txt" || fail "$id performance screen failed"
}

run_variant K8 8 24
run_variant K4 4 12
run_variant K2 2 6

python3 - "$BUILD" <<'PY'
from pathlib import Path
import json, sys
root=Path(sys.argv[1])
variants={}
for vid in ("K8","K4","K2"):
    science=json.loads((root/vid/"science-result.json").read_text())
    perf=json.loads((root/vid/"performance-result.json").read_text())
    variants[vid]={"science":science,"performance":perf}
result={
    "schema":"swap5.f-ross18.temporal-substep-matrix-result.v1",
    "workunit":"F-ROSS18",
    "production_source_mutation":False,
    "variants":variants,
}
eligible=[v for v,d in variants.items() if d["science"]["production_candidate_under_preregistered_research_rule"]]
faster=[v for v,d in variants.items() if d["performance"]["screening_outcome"]=="SCREENING_ROSSFAST_FASTER"]
result["production_candidate_variants"]=eligible
result["research_variants_screening_faster_than_reference"]=faster
result["verdict"]="MATRIX_COMPLETE"
(root/"F-ROSS18_MATRIX_RESULT.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
print(json.dumps(result,indent=2,sort_keys=True))
print("F_ROSS18_MATRIX_RESULT=PASS")
PY

OUTDIR="${GITHUB_WORKSPACE:-$ROOT}/F-ROSS18_EVIDENCE"
rm -rf "$OUTDIR"; mkdir -p "$OUTDIR"
cp "$BUILD/F-ROSS18_MATRIX_RESULT.json" "$OUTDIR/"
for id in K8 K4 K2; do
  mkdir -p "$OUTDIR/$id"
  cp "$BUILD/$id/science-result.json" "$OUTDIR/$id/"
  cp "$BUILD/$id/performance-result.json" "$OUTDIR/$id/"
  cp "$BUILD/$id/science.txt" "$OUTDIR/$id/"
  cp "$BUILD/$id/science-summary.txt" "$OUTDIR/$id/"
  cp "$BUILD/$id/performance-summary.txt" "$OUTDIR/$id/"
done

echo 'F_ROSS18_QUALIFICATION_GATE=PASS'

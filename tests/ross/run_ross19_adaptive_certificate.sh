#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE=405ad30e823ea44deedf73edc67c68e01564c617
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross19-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/adaptive" "$BUILD/k4"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS19_GATE_FAIL $*" >&2; exit 1; }

PREREG=integration/f-ross/F-ROSS19_ADAPTIVE_CERTIFICATE_PREREGISTRATION.json
ADAPT_KERNEL=tests/ross/research/mod_rossfast_d3r_table_kernel_adaptive.f90
ADAPT_SOLVER=tests/ross/research/mod_rossfast_d3r_soil_water_solver_adaptive.f90
SCI_TEST=tests/ross/test_ross19_adaptive_science.f90
TIMING_TEST=tests/ross/test_ross19_adaptive_timing.f90
K4_TEST=tests/ross/test_ross18_substep_matrix.f90
SCI_COMPARE=tools/performance/f_ross19_science_compare.py
PAIR_SCREEN=tools/performance/f_ross19_paired_screen.py
PROD_KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
PROD_SOLVER=src/solver/mod_rossfast_d3r_soil_water_solver.f90

for p in "$PREREG" "$ADAPT_KERNEL" "$ADAPT_SOLVER" "$SCI_TEST" "$TIMING_TEST" "$K4_TEST" "$SCI_COMPARE" "$PAIR_SCREEN"; do
  [[ -f "$p" ]] || fail "missing $p"
done

grep -Fq '"phase": "PREREGISTERED_RESEARCH_ONLY"' "$PREREG" || fail "preregistration drift"
grep -Fq '"candidate_steps": 6' "$PREREG" || fail "K2 work drift"
grep -Fq '"candidate_steps": 12' "$PREREG" || fail "K4 fallback work drift"
grep -Fq '"total_work_if_fallback_used": 18' "$PREREG" || fail "fallback total drift"

git cat-file -e "$SOURCE^{commit}" || fail "source commit unavailable"
git diff --quiet "$SOURCE" HEAD -- src reference || fail "F-ROSS19 must not mutate src or reference"
test "$(git rev-parse "$SOURCE:$PROD_KERNEL")" = "2ad2a680e62744451d6763de48585f1bd45d3067" || fail "F-ROSS17 cached kernel drift"
test "$(git rev-parse "$SOURCE:$PROD_SOLVER")" = "dbb441f3529be179d64fb57f9c44336d3d20c540" || fail "production solver drift"

# Build a standalone K4 authority from immutable F-ROSS17 production sources.
git show "$SOURCE:$PROD_KERNEL" > "$BUILD/k4/mod_rossfast_d3r_table_kernel.f90"
git show "$SOURCE:$PROD_SOLVER" > "$BUILD/k4/mod_rossfast_d3r_soil_water_solver.f90"
python3 - "$BUILD/k4/mod_rossfast_d3r_table_kernel.f90" "$BUILD/k4/mod_rossfast_d3r_soil_water_solver.f90" <<'PY'
from pathlib import Path
import sys
k=Path(sys.argv[1]); s=Path(sys.argv[2])
kt=k.read_text(); st=s.read_text()
a="integer, parameter :: CERTIFICATE_INTERNAL_SUBSTEPS = 8"
b="integer, parameter :: ROSSFAST_INTERNAL_SUBSTEPS = 8"
if kt.count(a)!=1 or st.count(b)!=1: raise SystemExit("K4 source authority drift")
k.write_text(kt.replace(a,"integer, parameter :: CERTIFICATE_INTERNAL_SUBSTEPS = 4"))
s.write_text(st.replace(b,"integer, parameter :: ROSSFAST_INTERNAL_SUBSTEPS = 4"))
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -O2)
BEFORE=(
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
AFTER=(src/solver/mod_rossfast_d3r_table_provider.f90)

compile_stack() {
  local out="$1"; local kernel="$2"; local solver="$3"; shift 3
  local objects=()
  local source obj
  for source in "${BEFORE[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    local extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  obj="$out/mod_rossfast_d3r_table_kernel.o"
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$kernel" -o "$obj"; objects+=("$obj")
  for source in "${AFTER[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"; objects+=("$obj")
  done
  obj="$out/mod_rossfast_d3r_soil_water_solver.o"
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$solver" -o "$obj"; objects+=("$obj")

  while (( "$#" )); do
    local test_src="$1"; local exe="$2"; shift 2
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$test_src" -o "$out/$exe.o"
    gfortran -fopenmp -O2 "${objects[@]}" "$out/$exe.o" -o "$out/$exe"
  done
}

compile_stack "$BUILD/adaptive" "$ADAPT_KERNEL" "$ADAPT_SOLVER" \
  "$SCI_TEST" science "$TIMING_TEST" timing
compile_stack "$BUILD/k4" "$BUILD/k4/mod_rossfast_d3r_table_kernel.f90" "$BUILD/k4/mod_rossfast_d3r_soil_water_solver.f90" \
  "$K4_TEST" science

"$BUILD/adaptive/science" > "$BUILD/adaptive/science.txt"
grep -Fq 'F_ROSS19_MATRIX_GATE=PASS' "$BUILD/adaptive/science.txt" || fail "adaptive science harness failed"

SWAP5_ROSS18_EXPECTED_LINEAR_SOLVES=12 "$BUILD/k4/science" > "$BUILD/k4/science.txt"
grep -Fq 'F_ROSS18_MATRIX_GATE=PASS' "$BUILD/k4/science.txt" || fail "standalone K4 science harness failed"

python3 "$SCI_COMPARE" --adaptive "$BUILD/adaptive/science.txt" --k4 "$BUILD/k4/science.txt" \
  --output "$BUILD/F-ROSS19_SCIENCE_RESULT.json" | tee "$BUILD/science-summary.txt"
grep -Fq 'F_ROSS19_SCIENTIFIC_GATE=PASS' "$BUILD/science-summary.txt" || fail "adaptive scientific gate failed"

python3 "$PAIR_SCREEN" --executable "$BUILD/adaptive/timing" --output "$BUILD/F-ROSS19_PERFORMANCE_RESULT.json" \
  | tee "$BUILD/performance-summary.txt"
grep -Fq 'F_ROSS19_PERFORMANCE_GATE=PASS' "$BUILD/performance-summary.txt" || fail "adaptive performance screen failed"

python3 - "$BUILD/F-ROSS19_SCIENCE_RESULT.json" "$BUILD/F-ROSS19_PERFORMANCE_RESULT.json" "$BUILD/F-ROSS19_RESULT.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); p=json.load(open(sys.argv[2]))
out={
 "schema":"swap5.f-ross19.adaptive-result.v1","workunit":"F-ROSS19",
 "production_source_mutation":False,"science":s,"performance":p,
 "research_promotion_candidate":s["scientific_gate"]=="PASS" and p["screening_outcome"]=="SCREENING_ROSSFAST_FASTER",
 "formal_performance_claim":False,
}
json.dump(out,open(sys.argv[3],"w"),indent=2,sort_keys=True); open(sys.argv[3],"a").write("\n")
print(json.dumps(out,indent=2,sort_keys=True)); print("F_ROSS19_RESULT=PASS")
PY

OUTDIR="${GITHUB_WORKSPACE:-$ROOT}/F-ROSS19_EVIDENCE"
rm -rf "$OUTDIR"; mkdir -p "$OUTDIR"
cp "$BUILD/F-ROSS19_SCIENCE_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS19_PERFORMANCE_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS19_RESULT.json" "$OUTDIR/"
cp "$BUILD/adaptive/science.txt" "$OUTDIR/"
cp "$BUILD/k4/science.txt" "$OUTDIR/"
cp "$BUILD/science-summary.txt" "$OUTDIR/"
cp "$BUILD/performance-summary.txt" "$OUTDIR/"

echo 'F_ROSS19_QUALIFICATION_GATE=PASS'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE=094c113f77fe18df049af51629976a05bccc02ee
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross21-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tiered" "$BUILD/adaptive"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS21_GATE_FAIL $*" >&2; exit 1; }

PREREG=integration/f-ross/F-ROSS21_TIERED_CERTIFICATE_PREREGISTRATION.json
TIER_KERNEL=tests/ross/research/mod_rossfast_d3r_table_kernel_tiered.f90
TIER_SOLVER=tests/ross/research/mod_rossfast_d3r_soil_water_solver_tiered.f90
ADAPT_KERNEL=tests/ross/research/mod_rossfast_d3r_table_kernel_adaptive.f90
ADAPT_SOLVER=tests/ross/research/mod_rossfast_d3r_soil_water_solver_adaptive.f90
ALLMAT_TEST=tests/ross/test_ross21_all_material_tiered.f90
ANCHOR_TEST=tests/ross/test_ross19_adaptive_science.f90
TIMING_TEST=tests/ross/test_ross19_adaptive_timing.f90
ALLMAT_SUMMARY=tools/performance/f_ross21_all_material_summary.py
IDENTITY=tools/performance/f_ross21_anchor_identity.py
PAIR_SCREEN=tools/performance/f_ross19_paired_screen.py

for p in "$PREREG" "$TIER_KERNEL" "$TIER_SOLVER" "$ADAPT_KERNEL" "$ADAPT_SOLVER" \
         "$ALLMAT_TEST" "$ANCHOR_TEST" "$TIMING_TEST" "$ALLMAT_SUMMARY" "$IDENTITY" "$PAIR_SCREEN"; do
  [[ -f "$p" ]] || fail "missing $p"
done

grep -Fq '"phase": "PREREGISTERED_RESEARCH_ONLY"' "$PREREG" || fail "preregistration drift"
grep -Fq '"total_candidate_steps": 6' "$PREREG" || fail "K2 preregistration drift"
grep -Fq '"total_candidate_steps": 12' "$PREREG" || fail "K4 preregistration drift"
grep -Fq '"total_candidate_steps": 24' "$PREREG" || fail "K8 preregistration drift"
grep -Fq '"K8": 42' "$PREREG" || fail "tiered total-work drift"

git cat-file -e "$SOURCE^{commit}" || fail "source checkpoint unavailable"
git diff --quiet "$SOURCE" HEAD -- src reference || fail "F-ROSS21 must not mutate src or reference"
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS19_ADAPTIVE_CERTIFICATE_RESULT.json)" = "6d25bc6a4cdbc9c7f525758fa146893ec035a4b0" || fail "F-ROSS19 result authority drift"
test "$(git rev-parse HEAD:$ADAPT_KERNEL)" = "041964577bea71274acc6a7e13dd0909b61dd94d" || fail "adaptive kernel authority drift"
test "$(git rev-parse HEAD:$ADAPT_SOLVER)" = "2b134c36097aed2a44a56bfe8e2194b15aa063aa" || fail "adaptive solver authority drift"
test "$(git rev-parse HEAD:$ANCHOR_TEST)" = "760840a6f0894ded06f9a9038523e20257a93206" || fail "anchor harness drift"
test "$(git rev-parse HEAD:$TIMING_TEST)" = "9cecfbf147a543e7cf1211626d53024757317d2a" || fail "timing harness drift"
test "$(git rev-parse HEAD:$PAIR_SCREEN)" = "1f35c2b3fc5da9720d415c69e33d41334642a32a" || fail "paired screen drift"

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

compile_stack "$BUILD/tiered" "$TIER_KERNEL" "$TIER_SOLVER" \
  "$ALLMAT_TEST" all_material "$ANCHOR_TEST" anchor "$TIMING_TEST" timing
compile_stack "$BUILD/adaptive" "$ADAPT_KERNEL" "$ADAPT_SOLVER" \
  "$ANCHOR_TEST" anchor

if ! "$BUILD/tiered/all_material" > "$BUILD/tiered/all-material.txt" 2>&1; then
  cat "$BUILD/tiered/all-material.txt" >&2
  fail "tiered all-material harness runtime failed"
fi
grep -Fq 'F_ROSS21_MATRIX_GATE=PASS' "$BUILD/tiered/all-material.txt" || { cat "$BUILD/tiered/all-material.txt" >&2; fail "all-material marker failed"; }
python3 "$ALLMAT_SUMMARY" --input "$BUILD/tiered/all-material.txt" \
  --output "$BUILD/F-ROSS21_ALL_MATERIAL_RESULT.json" | tee "$BUILD/all-material-summary.txt"
grep -Fq 'F_ROSS21_ALL_MATERIAL_GATE=PASS' "$BUILD/all-material-summary.txt" || fail "all-material tiered gate failed"

# Anchor domain must remain exactly F-ROSS19 adaptive because F-ROSS20 showed no K8 need there.
if ! "$BUILD/tiered/anchor" > "$BUILD/tiered/anchor.txt" 2>&1; then
  cat "$BUILD/tiered/anchor.txt" >&2
  fail "tiered anchor harness failed"
fi
if ! "$BUILD/adaptive/anchor" > "$BUILD/adaptive/anchor.txt" 2>&1; then
  cat "$BUILD/adaptive/anchor.txt" >&2
  fail "adaptive authority anchor failed"
fi
grep -Fq 'F_ROSS19_MATRIX_GATE=PASS' "$BUILD/tiered/anchor.txt" || fail "tiered anchor marker failed"
grep -Fq 'F_ROSS19_MATRIX_GATE=PASS' "$BUILD/adaptive/anchor.txt" || fail "adaptive anchor marker failed"
python3 "$IDENTITY" --production "$BUILD/tiered/anchor.txt" --research "$BUILD/adaptive/anchor.txt" \
  --output "$BUILD/F-ROSS21_ANCHOR_IDENTITY_RESULT.json" | tee "$BUILD/identity-summary.txt"
grep -Fq 'F_ROSS21_TIERED_ANCHOR_IDENTITY=PASS' "$BUILD/identity-summary.txt" || fail "tiered anchor identity failed"

python3 "$PAIR_SCREEN" --executable "$BUILD/tiered/timing" \
  --output "$BUILD/F-ROSS21_PERFORMANCE_RESULT.json" | tee "$BUILD/performance-summary.txt"
grep -Fq 'F_ROSS19_PERFORMANCE_GATE=PASS' "$BUILD/performance-summary.txt" || fail "tiered performance screen execution failed"

python3 - "$BUILD/F-ROSS21_ALL_MATERIAL_RESULT.json" "$BUILD/F-ROSS21_ANCHOR_IDENTITY_RESULT.json" \
           "$BUILD/F-ROSS21_PERFORMANCE_RESULT.json" "$BUILD/F-ROSS21_RESULT.json" <<'PY'
import json,sys
a=json.load(open(sys.argv[1])); i=json.load(open(sys.argv[2])); p=json.load(open(sys.argv[3]))
science=(a["gate"]=="PASS" and i["gate"]=="PASS")
out={
 "schema":"swap5.f-ross21.tiered-certificate-result.v1",
 "workunit":"F-ROSS21","production_source_mutation":False,
 "all_material":a,"anchor_identity":i,"performance":p,
 "science_gate":science,
 "research_promotion_candidate":science and p["screening_outcome"]=="SCREENING_ROSSFAST_FASTER",
 "formal_performance_claim":False,
}
out["verdict"]="RESEARCH_PROMOTION_CANDIDATE" if out["research_promotion_candidate"] else ("SCIENCE_PASS_PERFORMANCE_NOT_FASTER" if science else "BLOCKED")
json.dump(out,open(sys.argv[4],"w"),indent=2,sort_keys=True); open(sys.argv[4],"a").write("\n")
print(json.dumps({
 "verdict":out["verdict"],
 "K2_final":a["K2_final_count"],"K4_final":a["K4_final_count"],"K8_final":a["K8_final_count"],
 "mean_linear_solves":a["mean_linear_solves"],
 "performance_outcome":p["screening_outcome"],
 "performance_mean_delta":p["rossfast_over_reference_relative_delta"]["mean"],
},sort_keys=True))
print("F_ROSS21_RESULT=PASS" if science else "F_ROSS21_RESULT=FAIL")
PY
grep -Fq 'F_ROSS21_RESULT=PASS' <(python3 - "$BUILD/F-ROSS21_RESULT.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); print("F_ROSS21_RESULT=PASS" if x["science_gate"] else "F_ROSS21_RESULT=FAIL")
PY
) || fail "aggregate tiered science gate failed"

OUTDIR="${GITHUB_WORKSPACE:-$ROOT}/F-ROSS21_EVIDENCE"
rm -rf "$OUTDIR"; mkdir -p "$OUTDIR"
cp "$BUILD/F-ROSS21_ALL_MATERIAL_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS21_ANCHOR_IDENTITY_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS21_PERFORMANCE_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS21_RESULT.json" "$OUTDIR/"
cp "$BUILD/all-material-summary.txt" "$OUTDIR/"
cp "$BUILD/identity-summary.txt" "$OUTDIR/"
cp "$BUILD/performance-summary.txt" "$OUTDIR/"
cp "$BUILD/tiered/anchor.txt" "$OUTDIR/"
cp "$BUILD/adaptive/anchor.txt" "$OUTDIR/"

echo 'F_ROSS21_QUALIFICATION_GATE=PASS'

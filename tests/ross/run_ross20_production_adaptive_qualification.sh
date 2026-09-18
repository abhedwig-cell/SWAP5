#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE=094c113f77fe18df049af51629976a05bccc02ee
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross20-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/prod" "$BUILD/research"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS20_GATE_FAIL $*" >&2; exit 1; }

PREREG=integration/f-ross/F-ROSS20_PRODUCTION_ADAPTIVE_CERTIFICATE_PREREGISTRATION.json
PROD_KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
PROD_SOLVER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
RESEARCH_KERNEL=tests/ross/research/mod_rossfast_d3r_table_kernel_adaptive.f90
RESEARCH_SOLVER=tests/ross/research/mod_rossfast_d3r_soil_water_solver_adaptive.f90
ALLMAT_TEST=tests/ross/test_ross20_all_material_adaptive.f90
ANCHOR_TEST=tests/ross/test_ross19_adaptive_science.f90
TIMING_TEST=tests/ross/test_ross19_adaptive_timing.f90
ALLMAT_SUMMARY=tools/performance/f_ross20_all_material_summary.py
IDENTITY=tools/performance/f_ross20_research_identity.py
PAIR_SCREEN=tools/performance/f_ross19_paired_screen.py

for p in "$PREREG" "$PROD_KERNEL" "$PROD_SOLVER" "$RESEARCH_KERNEL" "$RESEARCH_SOLVER" \
         "$ALLMAT_TEST" "$ANCHOR_TEST" "$TIMING_TEST" "$ALLMAT_SUMMARY" "$IDENTITY" "$PAIR_SCREEN"; do
  [[ -f "$p" ]] || fail "missing $p"
done

grep -Fq '"phase": "PREREGISTERED_BEFORE_PRODUCTION_MUTATION"' "$PREREG" || fail "preregistration drift"
grep -Fq '"fast_attempt_total_candidate_steps": 6' "$PREREG" || fail "K2 work drift"
grep -Fq '"fallback_total_candidate_steps": 12' "$PREREG" || fail "K4 work drift"
grep -Fq '"total_candidate_steps_if_fallback_used": 18' "$PREREG" || fail "adaptive work drift"

git cat-file -e "$SOURCE^{commit}" || fail "source checkpoint unavailable"
mapfile -t PROD_DIFF < <(git diff --name-only "$SOURCE" HEAD -- src reference)
if [[ "${#PROD_DIFF[@]}" -ne 2 ]]; then
  printf 'F_ROSS20_PRODUCTION_DIFF=%s\n' "${PROD_DIFF[@]:-NONE}" >&2
  fail "production mutation count must be exactly two"
fi
printf '%s\n' "${PROD_DIFF[@]}" | sort > "$BUILD/actual_prod_diff.txt"
printf '%s\n' "$PROD_KERNEL" "$PROD_SOLVER" | sort > "$BUILD/expected_prod_diff.txt"
cmp -s "$BUILD/actual_prod_diff.txt" "$BUILD/expected_prod_diff.txt" || {
  diff -u "$BUILD/expected_prod_diff.txt" "$BUILD/actual_prod_diff.txt" >&2 || true
  fail "production mutation escaped preregistered scope"
}

test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "5442fd7e7a2f392c9b796cd17c76b17977259f22" || fail "model binding drift"
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "ac997bf06c56a37080d1c8db69b6d4208f4b75ca" || fail "table provider drift"
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS19_ADAPTIVE_CERTIFICATE_RESULT.json)" = "6d25bc6a4cdbc9c7f525758fa146893ec035a4b0" || fail "F-ROSS19 result authority drift"
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS13_TRANSIENT_36_MATERIAL_QUALIFICATION_RESULT.json)" = "4be26de45d9fe75825bb482580ce6a9b098dedf0" || fail "F-ROSS13 transient authority drift"
test "$(git rev-parse HEAD:$RESEARCH_KERNEL)" = "041964577bea71274acc6a7e13dd0909b61dd94d" || fail "F-ROSS19 research kernel drift"
test "$(git rev-parse HEAD:$RESEARCH_SOLVER)" = "2b134c36097aed2a44a56bfe8e2194b15aa063aa" || fail "F-ROSS19 research solver drift"
test "$(git rev-parse HEAD:$ANCHOR_TEST)" = "760840a6f0894ded06f9a9038523e20257a93206" || fail "F-ROSS19 anchor harness drift"
test "$(git rev-parse HEAD:$TIMING_TEST)" = "9cecfbf147a543e7cf1211626d53024757317d2a" || fail "F-ROSS19 timing harness drift"
test "$(git rev-parse HEAD:$PAIR_SCREEN)" = "1f35c2b3fc5da9720d415c69e33d41334642a32a" || fail "F-ROSS19 performance screen drift"

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

compile_stack "$BUILD/prod" "$PROD_KERNEL" "$PROD_SOLVER" \
  "$ALLMAT_TEST" all_material "$ANCHOR_TEST" anchor "$TIMING_TEST" timing
compile_stack "$BUILD/research" "$RESEARCH_KERNEL" "$RESEARCH_SOLVER" \
  "$ANCHOR_TEST" anchor

# Existing production provider/material fail-closed preservation, O0/O2.
bash tests/ross/run_ross13_36_material_production_envelope.sh | tee "$BUILD/provider-preservation.txt"
grep -Fq 'F_ROSS13_36_MATERIAL_PRODUCTION_ENVELOPE=PASS' "$BUILD/provider-preservation.txt" || fail "F-ROSS13 production envelope preservation failed"

# New production material-axis qualification.
"$BUILD/prod/all_material" > "$BUILD/prod/all-material.txt"
grep -Fq 'F_ROSS20_MATRIX_GATE=PASS' "$BUILD/prod/all-material.txt" || fail "all-material harness failed"
python3 "$ALLMAT_SUMMARY" --input "$BUILD/prod/all-material.txt" \
  --output "$BUILD/F-ROSS20_ALL_MATERIAL_RESULT.json" | tee "$BUILD/all-material-summary.txt"
grep -Fq 'F_ROSS20_ALL_MATERIAL_GATE=PASS' "$BUILD/all-material-summary.txt" || fail "all-material qualification failed"

# Exact production promotion identity on the frozen 36-case research domain.
"$BUILD/prod/anchor" > "$BUILD/prod/anchor.txt"
"$BUILD/research/anchor" > "$BUILD/research/anchor.txt"
grep -Fq 'F_ROSS19_MATRIX_GATE=PASS' "$BUILD/prod/anchor.txt" || fail "production anchor harness failed"
grep -Fq 'F_ROSS19_MATRIX_GATE=PASS' "$BUILD/research/anchor.txt" || fail "research anchor harness failed"
python3 "$IDENTITY" --production "$BUILD/prod/anchor.txt" --research "$BUILD/research/anchor.txt" \
  --output "$BUILD/F-ROSS20_RESEARCH_IDENTITY_RESULT.json" | tee "$BUILD/identity-summary.txt"
grep -Fq 'F_ROSS20_PRODUCTION_RESEARCH_IDENTITY=PASS' "$BUILD/identity-summary.txt" || fail "production/research identity failed"

# Corroborating hosted performance screen; not a formal performance admission gate.
python3 "$PAIR_SCREEN" --executable "$BUILD/prod/timing" \
  --output "$BUILD/F-ROSS20_PERFORMANCE_RESULT.json" | tee "$BUILD/performance-summary.txt"
grep -Fq 'F_ROSS19_PERFORMANCE_GATE=PASS' "$BUILD/performance-summary.txt" || fail "production performance screen execution failed"

python3 - "$BUILD/F-ROSS20_ALL_MATERIAL_RESULT.json" "$BUILD/F-ROSS20_RESEARCH_IDENTITY_RESULT.json" \
           "$BUILD/F-ROSS20_PERFORMANCE_RESULT.json" "$BUILD/F-ROSS20_QUALIFICATION_RESULT.json" <<'PY'
import json,sys
a=json.load(open(sys.argv[1])); i=json.load(open(sys.argv[2])); p=json.load(open(sys.argv[3]))
out={
 "schema":"swap5.f-ross20.production-adaptive-qualification.v1",
 "workunit":"F-ROSS20",
 "all_material":a,
 "production_research_identity":i,
 "performance":p,
 "provider_preservation":"PASS",
 "science_and_preservation_gate":(
     a["gate"]=="PASS" and i["gate"]=="PASS"
 ),
 "formal_performance_claim":False,
 "performance_is_admission_dependency":False,
}
out["verdict"]="QUALIFIED_FOR_PRODUCTION_ADMISSION_REVIEW" if out["science_and_preservation_gate"] else "BLOCKED"
json.dump(out,open(sys.argv[4],"w"),indent=2,sort_keys=True); open(sys.argv[4],"a").write("\n")
print(json.dumps({
 "verdict":out["verdict"],
 "all_material_fallback_count":a["fallback_count"],
 "all_material_mean_linear_solves":a["mean_linear_solves"],
 "performance_outcome":p["screening_outcome"],
 "performance_mean_delta":p["rossfast_over_reference_relative_delta"]["mean"],
},sort_keys=True))
print("F_ROSS20_QUALIFICATION_RESULT="+("PASS" if out["science_and_preservation_gate"] else "FAIL"))
PY

grep -Fq 'F_ROSS20_QUALIFICATION_RESULT=PASS' <(python3 - "$BUILD/F-ROSS20_QUALIFICATION_RESULT.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); print("F_ROSS20_QUALIFICATION_RESULT="+("PASS" if x["science_and_preservation_gate"] else "FAIL"))
PY
) || fail "aggregate qualification failed"

OUTDIR="${GITHUB_WORKSPACE:-$ROOT}/F-ROSS20_EVIDENCE"
rm -rf "$OUTDIR"; mkdir -p "$OUTDIR"
cp "$BUILD/F-ROSS20_ALL_MATERIAL_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS20_RESEARCH_IDENTITY_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS20_PERFORMANCE_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS20_QUALIFICATION_RESULT.json" "$OUTDIR/"
cp "$BUILD/provider-preservation.txt" "$OUTDIR/"
cp "$BUILD/all-material-summary.txt" "$OUTDIR/"
cp "$BUILD/identity-summary.txt" "$OUTDIR/"
cp "$BUILD/performance-summary.txt" "$OUTDIR/"
cp "$BUILD/prod/anchor.txt" "$OUTDIR/"
cp "$BUILD/research/anchor.txt" "$OUTDIR/"

echo 'F_ROSS20_QUALIFICATION_GATE=PASS'

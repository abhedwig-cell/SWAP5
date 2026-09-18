#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e24a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E24A_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E24A_BENCHMARK_FINGERPRINT_PREREGISTRATION.json
TIMING_PREREG=docs/publication/P2E24_REALIZED_ERROR_TIMING_PREREGISTRATION.json
CONTROLS=docs/publication/P2E23_MATCHED_CONTROLS.json
BENCH=benchmarks/publication/p2e24_benchmark.f90
PARENT_BASE=637e0fd5455d68f1a292e200619ceb7e5e5fa526

PREREG_BLOB=c9ed8b184b542e645a3c3c8fc56909e397c0012b
TIMING_PREREG_BLOB=4a7ecd1737c9f66077f3bc28843027ded325cb4f
CONTROLS_BLOB=9f173b0431c775a8459930ab34f4989b8e098491
BENCH_BLOB=14979af1e2d9b4f716b66cf660bacbae5d6a82aa

REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
REFERENCE_STATE_BINDING_BLOB=a2488ce3a6a6eff665a59d3dd68907d26f8304ec
MVG_PROVIDER_BLOB=fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6
TOP_PROVIDER_BLOB=fb226f133bd48d8ab945f111c76897aeff49facf
SOURCE_SINK_BLOB=d6c57add72387e5c0022a44319fff08046194aac
ROSSFAST_SOLVER_BLOB=dbb441f3529be179d64fb57f9c44336d3d20c540
ROSSFAST_MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
ROSSFAST_EXECUTION_POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
ROSSFAST_TABLE_PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
ROSSFAST_TABLE_KERNEL_BLOB=034136c193b287bcf9a953a9b89df2a8fb0c97cc
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

for f in "$PREREG" "$TIMING_PREREG" "$CONTROLS" "$BENCH"; do
  [[ -f "$f" ]] || fail "missing authority $f"
done
test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E24A preregistration drift'
test "$(git rev-parse HEAD:$TIMING_PREREG)" = "$TIMING_PREREG_BLOB" || fail 'P2E24 timing preregistration drift'
test "$(git rev-parse HEAD:$CONTROLS)" = "$CONTROLS_BLOB" || fail 'P2E23 matched controls drift'
test "$(git rev-parse HEAD:$BENCH)" = "$BENCH_BLOB" || fail 'benchmark source drift'

grep -Fq '"phase": "PREREGISTERED_BEFORE_UNTIMED_BENCHMARK_WORKLOAD_QUALIFICATION"' "$PREREG" || fail 'P2E24A phase drift'
grep -Fq '"measured_timing_allowed": false' "$PREREG" || fail 'untimed firewall missing'
grep -Fq '"total": 106' "$PREREG" || fail 'configuration cardinality drift'
grep -Fq '9f173b0431c775a8459930ab34f4989b8e098491' "$BENCH" || fail 'matched-controls blob not embedded in benchmark'
if grep -Eiq '\b(cpu_time|system_clock)\b' "$BENCH"; then
  fail 'timing intrinsic detected in untimed benchmark source'
fi

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E24 timing preregistration parent is not an ancestor'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E24A mutated src or reference'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_state_binding.f90)" = "$REFERENCE_STATE_BINDING_BLOB" || fail 'Reference state binding drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = "$MVG_PROVIDER_BLOB" || fail 'MvG provider drift'
test "$(git rev-parse HEAD:src/solver/mod_fixed_flux_top_boundary_provider.f90)" = "$TOP_PROVIDER_BLOB" || fail 'top-boundary provider drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_source_sink_provider.f90)" = "$SOURCE_SINK_BLOB" || fail 'source/sink provider drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_soil_water_solver.f90)" = "$ROSSFAST_SOLVER_BLOB" || fail 'RossFast solver drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$ROSSFAST_MODEL_BINDING_BLOB" || fail 'RossFast model binding drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = "$ROSSFAST_EXECUTION_POLICY_BLOB" || fail 'RossFast policy drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "$ROSSFAST_TABLE_PROVIDER_BLOB" || fail 'RossFast provider drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_kernel.f90)" = "$ROSSFAST_TABLE_KERNEL_BLOB" || fail 'RossFast kernel drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" = "$WORKSPACE_BLOB" || fail 'Reference workspace drift'
test "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" = "$HEADCALC_BLOB" || fail 'HeadCalc drift'

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
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BENCH" -o "$OUT/bench.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/bench.o" -o "$OUT/p2e24_benchmark"

  : > "$OUT/output.txt"
  for case_id in $(seq 1 36); do
    "$OUT/p2e24_benchmark" "$case_id" ROSS 1 >> "$OUT/output.txt"
    "$OUT/p2e24_benchmark" "$case_id" REF_HI 1 >> "$OUT/output.txt"
    if [[ "$case_id" != "7" && "$case_id" != "8" ]]; then
      "$OUT/p2e24_benchmark" "$case_id" REF_LO 1 >> "$OUT/output.txt"
    fi
  done

  [[ "$(grep -Fc 'PUB_P2E24A_RUN|' "$OUT/output.txt")" = "106" ]] || fail 'expected 106 run records'
  [[ "$(grep -Fc 'PUB_P2E24A_FINGERPRINT|' "$OUT/output.txt")" = "106" ]] || fail 'expected 106 fingerprint records'
  [[ "$(grep -Fc 'PUB_P2E24A_HEAD|' "$OUT/output.txt")" = "106" ]] || fail 'expected 106 head records'
  [[ "$(grep -Fc 'PUB_P2E24A_THETA|' "$OUT/output.txt")" = "106" ]] || fail 'expected 106 theta records'
  [[ "$(grep -c '|VARIANT=ROSS|' "$OUT/output.txt")" -ge 144 ]] || fail 'Ross records missing'
  [[ "$(grep -c '|VARIANT=REF_HI|' "$OUT/output.txt")" -ge 144 ]] || fail 'REF_HI records missing'

  python3 - "$CONTROLS" "$OUT/output.txt" <<'PY'
import json, sys
controls=json.load(open(sys.argv[1],encoding='utf-8'))
lines=open(sys.argv[2],encoding='utf-8').read().splitlines()
finger=[x for x in lines if x.startswith('PUB_P2E24A_FINGERPRINT|')]
seen={}
for line in finger:
    fields={}
    for part in line.split('|')[1:]:
        k,v=part.split('=',1)
        fields[k]=v
    key=(int(fields['CASE']),fields['VARIANT'])
    if key in seen:
        raise SystemExit(f'duplicate fingerprint {key}')
    seen[key]=int(fields['N'])
for row in controls['cases']:
    case=row['case']
    expected={('ROSS',1),('REF_HI',row['reference_n_hi'])}
    if row['reference_n_lo']>0:
        expected.add(('REF_LO',row['reference_n_lo']))
    for variant,n in expected:
        got=seen.get((case,variant))
        if got != n:
            raise SystemExit(f'control mismatch case={case} variant={variant} expected={n} got={got}')
if len(seen)!=106:
    raise SystemExit(f'expected 106 unique fingerprints, got {len(seen)}')
PY

  echo "PUB_P2E24A_O${opt}_FINGERPRINT_SET_SHA256=$(sha256sum "$OUT/output.txt" | awk '{print $1}')"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 fingerprint output drift'
}

cat "$BUILD/o2/output.txt"
echo "PUB_P2E24A_FINGERPRINT_SET_SHA256=$(sha256sum "$BUILD/o2/output.txt" | awk '{print $1}')"
echo 'PUB_P2E24A_TIMING_EXECUTED=FALSE'
echo 'PUB_P2E24A_BENCHMARK_FINGERPRINT_GATE=PASS'

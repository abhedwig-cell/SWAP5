#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE="14ee1be3c221c973973a3fb3dcb450ff40d3f96a"
QUAL_SOURCE_TREE="d7ef6c045263de821db7800459289efcd8a6420b"
MANIFEST_COMMIT="5c5d30273437bfc5082d2c91a75d25681cc8d15d"
MANIFEST_PATH="docs/publications/manifests/PUB-GC-E1-SCREEN-0001.yaml"
MANIFEST_BLOB="06d781bdf946960b8d08bad913e97ae414d8c726"
QUAL_DIR="tests/publication/pub_gc/e1_origin"
GW_A_DIR="tests/publication/pub_gc/gw_a"
SCREEN_DIR="tests/publication/pub_gc/e1_screening"
TEST="$SCREEN_DIR/pub_gc_e1_screen_case.f90"
RUNNER="$SCREEN_DIR/run_pub_gc_e1_screening.sh"
WORKFLOW=".github/workflows/pub-gc-e1-screening.yml"
ARTIFACT_DIR="$ROOT/artifacts/PUB-GC-E1-SCREEN-0001"

fail(){ echo "PUB_GC_E1_SCREEN_GATE_FAIL $*" >&2; exit 41; }

[[ "$(git rev-parse "$BASE:src")" == "$QUAL_SOURCE_TREE" ]] || fail "qualified source-tree authority mismatch"
git merge-base --is-ancestor "$BASE" HEAD || fail "screening head does not descend from qualified harness"
[[ "$(git rev-parse HEAD:src)" == "$QUAL_SOURCE_TREE" ]] || fail "production source tree drift"
[[ "$(git rev-parse HEAD:$QUAL_DIR)" == "$(git rev-parse "$BASE:$QUAL_DIR")" ]] || fail "qualified origin harness bytes changed"
[[ "$(git rev-parse HEAD:$GW_A_DIR)" == "$(git rev-parse "$BASE:$GW_A_DIR")" ]] || fail "qualified GW-A bytes changed"

mapfile -t changed < <(git diff --name-only "$BASE..HEAD")
for path in "${changed[@]}"; do
  case "$path" in
    tests/publication/pub_gc/e1_screening/*|.github/workflows/pub-gc-e1-screening.yml) ;;
    *) fail "out-of-scope screening mutation: $path" ;;
  esac
done

git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
git cat-file -e "$MANIFEST_COMMIT^{commit}" 2>/dev/null || fail "screening manifest commit unavailable"
[[ "$(git rev-parse "$MANIFEST_COMMIT:$MANIFEST_PATH")" == "$MANIFEST_BLOB" ]] || fail "screening manifest blob drift"
echo "PUB_GC_E1_SCREEN_MANIFEST_LOCK=PASS:$MANIFEST_COMMIT:$MANIFEST_BLOB"
echo 'PUB_GC_E1_SCREEN_PRODUCTION_SRC_UNCHANGED=PASS'
echo 'PUB_GC_E1_SCREEN_QUALIFIED_HARNESS_BYTES_UNCHANGED=PASS'
echo 'PUB_GC_E1_SCREEN_GW_A_BYTES_UNCHANGED=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e1-screen-${GITHUB_RUN_ID:-local}-$$"
QUAL_WORKTREE="$BUILD/qualified-harness"
mkdir -p "$BUILD/cases" "$ARTIFACT_DIR"
cleanup(){
  git -C "$ROOT" worktree remove --force "$QUAL_WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$BUILD"
}
trap cleanup EXIT

# Re-establish the exact qualification prerequisite at its frozen head before
# screening. This is a prerequisite replay, not part of the screening result.
git worktree add --detach "$QUAL_WORKTREE" "$BASE" >/dev/null
(
  cd "$QUAL_WORKTREE"
  bash tests/publication/pub_gc/e1_origin/run_pub_gc_e1_origin_harness_qualification.sh
) > "$BUILD/origin-harness-qualification.txt" 2>&1 || {
  cat "$BUILD/origin-harness-qualification.txt" >&2
  fail "frozen E1 origin harness no longer replays"
}
grep -Fq 'PUB_GC_E1_ORIGIN_HARNESS_QUALIFICATION=PASS' "$BUILD/origin-harness-qualification.txt" ||   fail "frozen E1 harness PASS marker missing"
echo 'PUB_GC_E1_SCREEN_FROZEN_HARNESS_REPLAY=PASS'

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
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

OUT="$BUILD/o2"
mkdir -p "$OUT"
objects=()
for source in "${MODULE_SRC[@]}"; do
  [[ -f "$source" ]] || fail "missing compile source $source"
  obj="$OUT/$(basename "${source%.*}").o"
  extra=()
  [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
  gfortran "${COMMON[@]}" "${extra[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/screen.o"
gfortran -fopenmp -O2 "${objects[@]}" "$OUT/screen.o" -o "$OUT/screen"
echo 'PUB_GC_E1_SCREEN_BUILD=PASS'

INDEX="$BUILD/cases.index"
: > "$INDEX"
for dt in 0.0001 0.001 0.005 0.02 0.05; do
  for b in -90.0 -82.5 -70.0 -60.0; do
    safe_dt="${dt//./p}"
    safe_b="${b//-/m}"; safe_b="${safe_b//./p}"
    log="$BUILD/cases/dt_${safe_dt}_b_${safe_b}.log"
    if timeout 120s "$OUT/screen" "$dt" "$b" > "$log" 2>&1; then
      status=PASS
    else
      status=FAIL
    fi
    printf '%s\t%s\t%s\t%s\n' "$dt" "$b" "$status" "$log" >> "$INDEX"
    echo "PUB_GC_E1_SCREEN_CASE_BEGIN dt=$dt b=$b status=$status"
    cat "$log"
    echo "PUB_GC_E1_SCREEN_CASE_END dt=$dt b=$b status=$status"
  done
done

python3 - "$INDEX" "$ARTIFACT_DIR/screening.tsv" <<'PY'
import csv, math, pathlib, re, sys
index=pathlib.Path(sys.argv[1])
out=pathlib.Path(sys.argv[2])
rows=[]

def tag(text, name, cast=float):
    m=re.search(rf'^{re.escape(name)}=(.+)$', text, re.M)
    if not m:
        raise ValueError(name)
    return cast(m.group(1).strip())

for raw in index.read_text().splitlines():
    dt_s,b_s,status,logpath=raw.split('\t')
    text=pathlib.Path(logpath).read_text(errors='replace')
    row={
        'window_days': float(dt_s),
        'candidate_b_head_cm': float(b_s),
        'status': status,
        'q_a_same': '',
        'q_b_same': '',
        'q_a_history': '',
        'abs_delta_q': '',
        'endpoint_head_delta_cm': '',
        'endpoint_water_delta': '',
        'mass_a_same': '',
        'mass_b_same': '',
        'mass_a_history': '',
        'retries_a_same': '',
        'retries_b_same': '',
        'retries_a_history': '',
        'failure_reason': '',
    }
    if status == 'PASS':
        try:
            row.update(
                q_a_same=tag(text,'PUB_GC_E1_SCREEN_Q_A_SAME'),
                q_b_same=tag(text,'PUB_GC_E1_SCREEN_Q_B_SAME'),
                q_a_history=tag(text,'PUB_GC_E1_SCREEN_Q_A_HISTORY'),
                abs_delta_q=tag(text,'PUB_GC_E1_SCREEN_ABS_DELTA_Q'),
                endpoint_head_delta_cm=tag(text,'PUB_GC_E1_SCREEN_ENDPOINT_HEAD_DELTA'),
                endpoint_water_delta=tag(text,'PUB_GC_E1_SCREEN_ENDPOINT_WATER_DELTA'),
                mass_a_same=tag(text,'PUB_GC_E1_SCREEN_MASS_A_SAME'),
                mass_b_same=tag(text,'PUB_GC_E1_SCREEN_MASS_B_SAME'),
                mass_a_history=tag(text,'PUB_GC_E1_SCREEN_MASS_A_HISTORY'),
                retries_a_same=tag(text,'PUB_GC_E1_SCREEN_RETRIES_A_SAME',int),
                retries_b_same=tag(text,'PUB_GC_E1_SCREEN_RETRIES_B_SAME',int),
                retries_a_history=tag(text,'PUB_GC_E1_SCREEN_RETRIES_A_HISTORY',int),
            )
            nums=[row[k] for k in ('q_a_same','q_b_same','q_a_history','abs_delta_q',
                                    'endpoint_head_delta_cm','endpoint_water_delta',
                                    'mass_a_same','mass_b_same','mass_a_history')]
            if not all(math.isfinite(float(x)) for x in nums):
                raise ValueError('nonfinite parsed metric')
        except Exception as exc:
            row['status']='PARSE_FAIL'
            row['failure_reason']=f'parse:{exc}'
    else:
        failures=re.findall(r'^PUB_GC_E1_HARNESS_FAIL=(.+)$', text, re.M)
        if failures:
            row['failure_reason']=failures[-1]
        elif 'timeout' in text.lower():
            row['failure_reason']='timeout'
        else:
            row['failure_reason']='executable_failed'
    rows.append(row)

fieldnames=list(rows[0])
with out.open('w', newline='') as f:
    w=csv.DictWriter(f, fieldnames=fieldnames, delimiter='\t')
    w.writeheader()
    w.writerows(rows)

if len(rows) != 20:
    raise SystemExit(f'PUB_GC_E1_SCREEN_PARSE_FAIL row_count={len(rows)}')

eligible=[r for r in rows if r['status']=='PASS']
print(f'PUB_GC_E1_SCREEN_GRID_ROWS={len(rows)}')
print(f'PUB_GC_E1_SCREEN_ELIGIBLE_ROWS={len(eligible)}')
print(f'PUB_GC_E1_SCREEN_FAILED_ROWS={len(rows)-len(eligible)}')

if eligible:
    selected=max(
        eligible,
        key=lambda r:(float(r['abs_delta_q']), float(r['endpoint_head_delta_cm']),
                      -float(r['window_days']), -float(r['candidate_b_head_cm']))
    )
    print('PUB_GC_E1_SCREEN_SELECTION=AVAILABLE')
    print(f"PUB_GC_E1_SCREEN_SELECTED_WINDOW_DAYS={selected['window_days']:.17e}")
    print(f"PUB_GC_E1_SCREEN_SELECTED_B_HEAD_CM={selected['candidate_b_head_cm']:.17e}")
    print(f"PUB_GC_E1_SCREEN_SELECTED_ABS_DELTA_Q={float(selected['abs_delta_q']):.17e}")
    print(f"PUB_GC_E1_SCREEN_SELECTED_ENDPOINT_HEAD_DELTA_CM={float(selected['endpoint_head_delta_cm']):.17e}")
    print(f"PUB_GC_E1_SCREEN_SELECTED_ENDPOINT_WATER_DELTA={float(selected['endpoint_water_delta']):.17e}")
else:
    print('PUB_GC_E1_SCREEN_SELECTION=NONE')

print('PUB_GC_E1_SCREEN_GRID_COMPLETE=PASS')
PY

echo "PUB_GC_E1_SCREEN_RESEARCH_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_E1_SCREEN_SOURCE_TREE=$(git rev-parse HEAD:src)"
echo "PUB_GC_E1_SCREEN_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_E1_SCREEN_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo 'PUB_GC_E1_SCREENING=PASS'

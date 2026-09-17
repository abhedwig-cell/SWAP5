#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE="14ee1be3c221c973973a3fb3dcb450ff40d3f96a"
MANIFEST_COMMIT="bc8dca037912de10dbfce33d1ca7a62b34bc7761"
MANIFEST_PATH="docs/publications/manifests/PUB-GC-E1-SCREEN-0002.yaml"
MANIFEST_BLOB="2aef35c16f1b7c87ebd7ff572adeb24e4e830ee4"
ORIGIN_DIR="tests/publication/pub_gc/e1_origin"
GW_A_DIR="tests/publication/pub_gc/gw_a"
TEST="tests/publication/pub_gc/e1_screening/test_pub_gc_e1_screening.f90"
RUNNER="tests/publication/pub_gc/e1_screening/run_pub_gc_e1_screening.sh"
ARTIFACT_DIR="artifacts/PUB-GC-E1-SCREEN-0002"

fail() { echo "PUB_GC_E1_SCREEN_GATE_FAIL $*" >&2; exit 42; }

git cat-file -e "$BASE^{commit}" 2>/dev/null || fail "missing qualified E1 harness authority"
git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
git cat-file -e "$MANIFEST_COMMIT^{commit}" 2>/dev/null || fail "screening manifest commit unavailable"
[[ "$(git rev-parse "$MANIFEST_COMMIT:$MANIFEST_PATH")" == "$MANIFEST_BLOB" ]] || fail "screening manifest blob drift"
git merge-base --is-ancestor "$BASE" HEAD || fail "screening head does not descend from qualified E1 harness"
[[ "$(git rev-parse HEAD:src)" == "$(git rev-parse "$BASE:src")" ]] || fail "production source tree changed"
[[ "$(git rev-parse HEAD:$ORIGIN_DIR)" == "$(git rev-parse "$BASE:$ORIGIN_DIR")" ]] || fail "qualified origin-harness bytes changed"
[[ "$(git rev-parse HEAD:$GW_A_DIR)" == "$(git rev-parse "$BASE:$GW_A_DIR")" ]] || fail "qualified GW-A bytes changed"

mapfile -t changed < <(git diff --name-only "$BASE..HEAD")
for path in "${changed[@]}"; do
  case "$path" in
    tests/publication/pub_gc/e1_screening/*|.github/workflows/pub-gc-e1-screening.yml) ;;
    *) fail "out-of-scope screening mutation: $path" ;;
  esac
done
echo 'PUB_GC_E1_SCREEN_SCOPE=PASS'
echo "PUB_GC_E1_SCREEN_MANIFEST=PASS:$MANIFEST_COMMIT:$MANIFEST_BLOB"
echo 'PUB_GC_E1_SCREEN_PRODUCTION_SRC_UNCHANGED=PASS'
echo 'PUB_GC_E1_SCREEN_ORIGIN_HARNESS_BYTES_UNCHANGED=PASS'
echo 'PUB_GC_E1_SCREEN_GW_A_BYTES_UNCHANGED=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e1-screen2-${GITHUB_RUN_ID:-local}-$$"
BASE_WORKTREE="$BUILD/e1-base"
mkdir -p "$BUILD" "$ARTIFACT_DIR"
cleanup() {
  git -C "$ROOT" worktree remove --force "$BASE_WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$BUILD"
}
trap cleanup EXIT

git worktree add --detach "$BASE_WORKTREE" "$BASE" >/dev/null
(
  cd "$BASE_WORKTREE"
  bash tests/publication/pub_gc/e1_origin/run_pub_gc_e1_origin_harness_qualification.sh
) > "$BUILD/base-qualification.txt" 2>&1 || {
  cat "$BUILD/base-qualification.txt" >&2
  fail "frozen E1 harness requalification failed"
}
grep -Fq 'PUB_GC_E1_ORIGIN_HARNESS_QUALIFICATION=PASS' "$BUILD/base-qualification.txt" ||   fail "frozen E1 harness PASS marker missing"
echo 'PUB_GC_E1_SCREEN_BASE_REQUALIFICATION=PASS'

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
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
gfortran -fopenmp -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
echo 'PUB_GC_E1_SCREEN_COMPILE=PASS'

rowdir="$BUILD/rows"
mkdir -p "$rowdir"
heads=(-75.0 -77.5 -72.5 -85.0 -65.0 -100.0 -50.0)
durations=(0.0025 0.01 0.04)
row=0
: > "$ARTIFACT_DIR/screening.log"
for dt in "${durations[@]}"; do
  for b in "${heads[@]}"; do
    row=$((row+1))
    file="$rowdir/row-$row.txt"
    echo "=== ROW $row B=$b DT=$dt ===" | tee -a "$ARTIFACT_DIR/screening.log"
    if ! timeout 120s "$OUT/test" "$b" "$dt" > "$file" 2>&1; then
      cat "$file" | tee -a "$ARTIFACT_DIR/screening.log" >&2
      fail "screening executable infrastructure failure row=$row B=$b dt=$dt"
    fi
    cat "$file" | tee -a "$ARTIFACT_DIR/screening.log"
    grep -Eq '^SCREEN_ROW_STATUS=(PASS|INVALID)$' "$file" || fail "row missing status row=$row"
  done
done
[[ "$row" -eq 21 ]] || fail "screening grid row count drift"

python3 - "$rowdir" "$ARTIFACT_DIR/screening.tsv" "$ARTIFACT_DIR/selection.txt" <<'PY'
import math, pathlib, sys

rowdir=pathlib.Path(sys.argv[1])
tsv=pathlib.Path(sys.argv[2])
selout=pathlib.Path(sys.argv[3])

def parse(path):
    d={}
    for line in path.read_text().splitlines():
        if line.startswith("SCREEN_") and "=" in line:
            k,v=line.split("=",1)
            d[k]=v.strip()
    return d

def f(d,k):
    try: return float(d[k])
    except Exception: return math.nan

def bval(d,k):
    return d.get(k,"").upper() == "T"

def dclass(dt):
    if abs(dt-0.0025) < 1e-14: return "short"
    if abs(dt-0.01) < 1e-14: return "intermediate"
    if abs(dt-0.04) < 1e-14: return "long"
    return "unknown"

def pclass(b):
    delta=b+75.0
    a=abs(delta)
    if a < 1e-12: return "control","control"
    if a <= 5.0: c="mild"
    elif a <= 15.0: c="intermediate"
    else: c="strong"
    return c, ("wetting_side" if delta > 0 else "drying_side")

rows=[]
for p in sorted(rowdir.glob("row-*.txt"), key=lambda x:int(x.stem.split("-")[1])):
    d=parse(p)
    bh=f(d,"SCREEN_B_HEAD_CM")
    dt=f(d,"SCREEN_DURATION_DAYS")
    pc,sign=pclass(bh)
    status=d.get("SCREEN_ROW_STATUS","MISSING")
    eligible=(status=="PASS" and pc!="control" and bval(d,"SCREEN_B_ENDPOINT_DIFFERS") and
              bval(d,"SCREEN_SAME_ORIGIN_A_REPLAY_IDENTITY") and
              bval(d,"SCREEN_ACCEPTED_ORIGIN_UNCHANGED") and
              bval(d,"SCREEN_HISTORY_DIAGNOSTIC_NO_COMMIT"))
    rows.append({
      "row":int(p.stem.split("-")[1]),"status":status,"duration_class":dclass(dt),"duration_days":dt,
      "perturbation_class":pc,"perturbation_sign":sign,"B_head_cm":bh,"B_delta_cm":bh+75.0,
      "eligible":eligible,"invalid_stage":d.get("SCREEN_INVALID_STAGE",""),
      "invalid_reason":d.get("SCREEN_INVALID_REASON",""),
      "A_same_Q":f(d,"SCREEN_A_SAME_Q"),"B_same_Q":f(d,"SCREEN_B_SAME_Q"),
      "A_history_Q":f(d,"SCREEN_A_HISTORY_Q"),"delta_Q_abs":f(d,"SCREEN_DELTA_Q_ABS"),
      "delta_terminal_abs":f(d,"SCREEN_DELTA_TERMINAL_ABS"),
      "delta_head_max":f(d,"SCREEN_DELTA_ENDPOINT_HEAD_MAX"),
      "delta_water_max":f(d,"SCREEN_DELTA_ENDPOINT_WATER_MAX"),
      "A_mass":f(d,"SCREEN_A_SAME_MASS_RESIDUAL"),"B_mass":f(d,"SCREEN_B_SAME_MASS_RESIDUAL"),
      "H_mass":f(d,"SCREEN_A_HISTORY_MASS_RESIDUAL"),
      "A_retries":d.get("SCREEN_A_SAME_RETRIES",""),"B_retries":d.get("SCREEN_B_SAME_RETRIES",""),
      "H_retries":d.get("SCREEN_A_HISTORY_RETRIES","")
    })

cols=["row","status","duration_class","duration_days","perturbation_class","perturbation_sign",
      "B_head_cm","B_delta_cm","eligible","invalid_stage","invalid_reason","A_same_Q","B_same_Q",
      "A_history_Q","delta_Q_abs","delta_terminal_abs","delta_head_max","delta_water_max",
      "A_mass","B_mass","H_mass","A_retries","B_retries","H_retries"]
with tsv.open("w") as fh:
    fh.write("\t".join(cols)+"\n")
    for r in rows:
        vals=[]
        for c in cols:
            v=r[c]
            if isinstance(v,float):
                vals.append("" if math.isnan(v) else f"{v:.17e}")
            elif isinstance(v,bool):
                vals.append("true" if v else "false")
            else:
                vals.append(str(v))
        fh.write("\t".join(vals)+"\n")

eligible=[r for r in rows if r["eligible"] and math.isfinite(r["delta_head_max"]) and math.isfinite(r["delta_Q_abs"])]
with selout.open("w") as fh:
    fh.write(f"SCREEN_TOTAL_ROWS={len(rows)}\n")
    fh.write(f"SCREEN_PASS_ROWS={sum(r['status']=='PASS' for r in rows)}\n")
    fh.write(f"SCREEN_INVALID_ROWS={sum(r['status']!='PASS' for r in rows)}\n")
    fh.write(f"SCREEN_SELECTION_ELIGIBLE_ROWS={len(eligible)}\n")
    if not eligible:
        fh.write("SCREEN_SELECTION_STATUS=SCREENING_NULL\n")
    else:
        chosen=min(eligible,key=lambda r:(-r["delta_head_max"],-r["delta_Q_abs"],abs(r["B_delta_cm"]),
                                          r["duration_days"],r["B_head_cm"]))
        fh.write("SCREEN_SELECTION_STATUS=CLASS_SELECTED\n")
        fh.write(f"SCREEN_SELECTED_DURATION_CLASS={chosen['duration_class']}\n")
        fh.write(f"SCREEN_SELECTED_PERTURBATION_CLASS={chosen['perturbation_class']}\n")
        fh.write(f"SCREEN_SELECTED_PERTURBATION_SIGN={chosen['perturbation_sign']}\n")
        fh.write(f"SCREEN_SELECTED_ROW_ID={chosen['row']}\n")
        fh.write("SCREEN_SELECTED_ROW_PRIMARY_REUSE_ALLOWED=false\n")
        fh.write(f"SCREEN_SELECTED_ROW_DELTA_HEAD_MAX={chosen['delta_head_max']:.17e}\n")
        fh.write(f"SCREEN_SELECTED_ROW_DELTA_Q_ABS={chosen['delta_Q_abs']:.17e}\n")
PY

cat "$ARTIFACT_DIR/selection.txt" | tee -a "$ARTIFACT_DIR/screening.log"
grep -Fq 'SCREEN_TOTAL_ROWS=21' "$ARTIFACT_DIR/selection.txt" || fail "derived row count mismatch"

echo "PUB_GC_E1_SCREEN_RESEARCH_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_E1_SCREEN_SOURCE_TREE=$(git rev-parse HEAD:src)"
echo "PUB_GC_E1_SCREEN_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_E1_SCREEN_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo "PUB_GC_E1_SCREEN_TSV_SHA256=$(sha256sum "$ARTIFACT_DIR/screening.tsv" | awk '{print $1}')"
echo "PUB_GC_E1_SCREEN_LOG_SHA256=$(sha256sum "$ARTIFACT_DIR/screening.log" | awk '{print $1}')"
echo 'PUB_GC_E1_SCREEN_EXECUTION=PASS'

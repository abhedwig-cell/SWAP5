#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-direct-sweep-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX01_DIRECT_SWEEP_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -O2)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
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
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_approx01_direct_tangent.f90 -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

RESULT="$BUILD/results.csv"
echo 'regime,point,offset_cm,hbot_cm,tangent,bottom_flux' > "$RESULT"

run_point(){
  local regime="$1" h0="$2" point="$3" offset="$4" hbot raw line
  hbot="$(python3 - <<PY
print(float("$h0")+float("$offset"))
PY
)"
  raw="$("$BUILD/test" "$h0" "$hbot")"
  line="$(printf '%s\n' "$raw" | grep '^APPROX01_DIRECT|')"
  python3 - "$regime" "$point" "$offset" "$line" "$RESULT" <<'PY'
import csv,sys
regime,point,offset,line,path=sys.argv[1:]
d={}
for p in line.strip().split('|')[1:]:
    k,v=p.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([regime,point,offset,d['HBOT_CM'],d['TANGENT'],d['BOTTOM_FLUX']])
print(f"APPROX01_POINT|REGIME={regime}|POINT={point}|OFFSET_CM={offset}|HBOT_CM={d['HBOT_CM']}|TANGENT={d['TANGENT']}|BOTTOM_FLUX={d['BOTTOM_FLUX']}")
PY
}

offsets=(0 0.05 0.1 0.25 0.5 0.25 0.1 0 -0.05 -0.1 -0.25 -0.5)
for spec in "wet -10" "mid -75" "dry -500"; do
  read -r regime h0 <<< "$spec"
  point=0
  for offset in "${offsets[@]}"; do
    point=$((point+1))
    run_point "$regime" "$h0" "$point" "$offset"
  done
done

python3 - "$RESULT" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
if len(rows)!=36: raise SystemExit(f"expected 36 points, got {len(rows)}")
for regime in ("wet","mid","dry"):
    rr=[r for r in rows if r["regime"]==regime]
    tang=[float(r["tangent"]) for r in rr]
    flux=[float(r["bottom_flux"]) for r in rr]
    print(f"APPROX01_EVOLUTION|REGIME={regime}|MIN_TANGENT={min(tang):.17e}|MAX_TANGENT={max(tang):.17e}|SPAN={max(tang)-min(tang):.17e}|MIN_FLUX={min(flux):.17e}|MAX_FLUX={max(flux):.17e}")
    for cadence in (2,4,8):
        ae=[]; re=[]; qe=[]
        for i,t in enumerate(tang):
            refresh=(i//cadence)*cadence
            lag=tang[refresh]
            err=abs(lag-t)
            ae.append(err)
            re.append(err/max(abs(t),1e-30))
            qe.append(err)
        print(
            f"APPROX01_LAG|REGIME={regime}|CADENCE={cadence}"
            f"|FRESH_FRACTION={1/cadence:.6f}"
            f"|AVOIDED_TANGENT_FRACTION={1-1/cadence:.6f}"
            f"|MAX_ABS_TANGENT_ERROR={max(ae):.17e}"
            f"|MEAN_ABS_TANGENT_ERROR={statistics.mean(ae):.17e}"
            f"|MAX_REL_TANGENT_ERROR={max(re):.17e}"
            f"|MEAN_REL_TANGENT_ERROR={statistics.mean(re):.17e}"
            f"|MAX_BOTTOM_FLUX_LINEARIZATION_ERROR_FOR_1CM={max(qe):.17e}"
        )
print("FPE_APPROX01_DIRECT_TANGENT_SWEEP=PASS")
PY


TIMING="$BUILD/timing.csv"
echo 'rep,cadence,ns_per_call,fresh_fraction,checksum' > "$TIMING"
CALLS=20000
for rep in 1 2 3 4 5; do
  for cadence in 1 2 4 8; do
    raw="$("$BUILD/test" -75 -75 "$CALLS" "$cadence")"
    line="$(printf '%s\n' "$raw" | grep '^APPROX01_TIMING|')"
    python3 - "$rep" "$cadence" "$line" "$TIMING" <<'PY'
import csv,sys
rep,cad,line,path=sys.argv[1:]
d={}
for p in line.strip().split('|')[1:]:
    k,v=p.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([rep,cad,d['NS_PER_CALL'],d['FRESH_FRACTION'],d['CHECKSUM']])
print(line)
PY
  done
done

python3 - "$TIMING" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
base=[float(r['ns_per_call']) for r in rows if int(r['cadence'])==1]
base_med=statistics.median(base)
print(f"APPROX01_TIMING_BASE_MEDIAN_NS={base_med:.6f}")
for cadence in (2,4,8):
    vals=[float(r['ns_per_call']) for r in rows if int(r['cadence'])==cadence]
    ratios=[]
    for rep in sorted({int(r['rep']) for r in rows}):
        b=float(next(r['ns_per_call'] for r in rows if int(r['rep'])==rep and int(r['cadence'])==1))
        c=float(next(r['ns_per_call'] for r in rows if int(r['rep'])==rep and int(r['cadence'])==cadence))
        ratios.append(c/b)
    print(f"APPROX01_TIMING_AGGREGATE|CADENCE={cadence}|MEDIAN_NS={statistics.median(vals):.6f}|MEAN_PAIRED_RATIO={statistics.mean(ratios):.9f}|MEDIAN_PAIRED_RATIO={statistics.median(ratios):.9f}|MEAN_SPEEDUP_PERCENT={(1-statistics.mean(ratios))*100:.6f}|MEDIAN_SPEEDUP_PERCENT={(1-statistics.median(ratios))*100:.6f}|MIN_RATIO={min(ratios):.9f}|MAX_RATIO={max(ratios):.9f}")
print("FPE_APPROX01_DIRECT_TIMING_AGGREGATE=PASS")
PY

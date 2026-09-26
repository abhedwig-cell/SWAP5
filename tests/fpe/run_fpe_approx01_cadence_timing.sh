#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-cadence-timing-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX01_CADENCE_TIMING_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -O2)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_approx01_cadence_timing.f90 -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

CALLS=12000
REPS=5
CSV="$BUILD/results.csv"
echo 'regime,cadence,rep,variant,ns,refresh_fraction,physical_checksum' > "$CSV"

run_one(){
  local regime="$1" h0="$2" cadence="$3" rep="$4" variant="$5" raw line
  if [[ "$variant" == fresh ]]; then
    raw="$("$BUILD/test" fresh 1 "$CALLS" "$h0")"
  else
    raw="$("$BUILD/test" lag "$cadence" "$CALLS" "$h0")"
  fi
  line="$(printf '%s\n' "$raw" | grep '^APPROX01_CADENCE_TIMING|')"
  python3 - "$regime" "$cadence" "$rep" "$variant" "$line" "$CSV" <<'PY'
import csv,sys
regime,cadence,rep,variant,line,path=sys.argv[1:]
d={}
for p in line.split('|')[1:]:
    k,v=p.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([regime,cadence,rep,variant,d['NS_PER_EVAL'],d['REFRESH_FRACTION'],d['PHYSICAL_CHECKSUM']])
print(line)
PY
}

for spec in "wet -10" "mid -75" "dry -500"; do
  read -r regime h0 <<< "$spec"
  for cadence in 2 4 8; do
    for rep in $(seq 1 "$REPS"); do
      if (( rep % 2 == 1 )); then
        run_one "$regime" "$h0" "$cadence" "$rep" fresh
        run_one "$regime" "$h0" "$cadence" "$rep" lag
      else
        run_one "$regime" "$h0" "$cadence" "$rep" lag
        run_one "$regime" "$h0" "$cadence" "$rep" fresh
      fi
    done
  done
done

python3 - "$CSV" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
for regime in ('wet','mid','dry'):
  for cadence in (2,4,8):
    rr=[r for r in rows if r['regime']==regime and int(r['cadence'])==cadence]
    by={}
    for r in rr: by.setdefault(int(r['rep']),{})[r['variant']]=r
    ratios=[]; fresh=[]; lag=[]
    for rep,p in sorted(by.items()):
      if set(p)!={'fresh','lag'}: raise SystemExit(f'incomplete pair {regime} {cadence} {rep}')
      if p['fresh']['physical_checksum'] != p['lag']['physical_checksum']:
        raise SystemExit(f'physical checksum drift {regime} cadence={cadence} rep={rep}')
      fn=float(p['fresh']['ns']); ln=float(p['lag']['ns'])
      fresh.append(fn); lag.append(ln); ratios.append(ln/fn)
    print(
      f"APPROX01_CADENCE_RESULT|REGIME={regime}|CADENCE={cadence}"
      f"|FRESH_MEDIAN_NS={statistics.median(fresh):.6f}"
      f"|LAG_MEDIAN_NS={statistics.median(lag):.6f}"
      f"|MEAN_RATIO={statistics.mean(ratios):.9f}"
      f"|MEDIAN_RATIO={statistics.median(ratios):.9f}"
      f"|MEAN_SPEEDUP_PERCENT={(1-statistics.mean(ratios))*100:.6f}"
      f"|MEDIAN_SPEEDUP_PERCENT={(1-statistics.median(ratios))*100:.6f}"
      f"|MIN_RATIO={min(ratios):.9f}|MAX_RATIO={max(ratios):.9f}"
    )
print('FPE_APPROX01_CADENCE_TIMING_AGGREGATE=PASS')
PY

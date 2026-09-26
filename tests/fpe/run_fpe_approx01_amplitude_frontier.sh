#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-amplitude-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX01_AMPLITUDE_FAIL $*" >&2; exit 1; }

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
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_approx01_tangent_matrix.f90 -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

CSV="$BUILD/results.csv"
echo 'amplitude,material,regime,point,offset_cm,tangent,bottom_flux' > "$CSV"

for amplitude in 0.5 1.0 2.0; do
  for material in B01 B12 O05 O14; do
    for spec in "wet -10" "mid -75" "dry -500"; do
      read -r regime h0 <<< "$spec"
      for point in $(seq 1 12); do
        offset="$(python3 - "$amplitude" "$point" <<'PY'
import sys
a=float(sys.argv[1]); i=int(sys.argv[2])
p=[0,.1,.2,.5,1,.5,.2,0,-.1,-.2,-.5,-1]
print(a*p[i-1])
PY
)"
        hbot="$(python3 - <<PY
print(float("$h0")+float("$offset"))
PY
)"
        raw="$("$BUILD/test" "$material" "$h0" "$hbot")"
        line="$(printf '%s\n' "$raw" | grep '^APPROX01_MATRIX_POINT|')"
        python3 - "$amplitude" "$material" "$regime" "$point" "$offset" "$line" "$CSV" <<'PY'
import csv,sys
amp,mat,reg,point,off,line,path=sys.argv[1:]
d={}
for p in line.split('|')[1:]:
    k,v=p.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([amp,mat,reg,point,off,d['TANGENT'],d['BOTTOM_FLUX']])
PY
      done
    done
  done
done

python3 - "$CSV" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
mats=('B01','B12','O05','O14')
regs=('wet','mid','dry')
for amp in (0.5,1.0,2.0):
  for cadence in (2,4,8):
    worst=(0,None); vals=[]
    for mat in mats:
      for reg in regs:
        rr=[r for r in rows if abs(float(r['amplitude'])-amp)<1e-12 and r['material']==mat and r['regime']==reg]
        tang=[float(r['tangent']) for r in rr]
        re=[]
        for i,t in enumerate(tang):
          lag=tang[(i//cadence)*cadence]
          re.append(abs(lag-t)/max(abs(t),1e-30))
        mx=max(re); vals.extend(re)
        if mx>worst[0]: worst=(mx,f'{mat}:{reg}')
    print(f"APPROX01_AMPLITUDE|AMPLITUDE_CM={amp}|CADENCE={cadence}|WORST_MAX_REL={worst[0]:.17e}|WORST_CASE={worst[1]}|MEAN_REL_ALL={statistics.mean(vals):.17e}")

for amp in (0.5,1.0,2.0):
  for threshold in (0.25,0.5,1.0):
    worst=(0,None); all_rel=[]; refreshes=0; total=0
    for mat in mats:
      for reg in regs:
        rr=[r for r in rows if abs(float(r['amplitude'])-amp)<1e-12 and r['material']==mat and r['regime']==reg]
        offs=[float(r['offset_cm']) for r in rr]
        tang=[float(r['tangent']) for r in rr]
        last=0; age=0
        rel=[]
        for i,t in enumerate(tang):
          must = i==0 or abs(offs[i]-offs[last])>threshold or age>=8
          if must:
            last=i; age=0; refreshes+=1
          lag=tang[last]
          e=abs(lag-t)/max(abs(t),1e-30)
          rel.append(e); all_rel.append(e); total+=1
          age+=1
        mx=max(rel)
        if mx>worst[0]: worst=(mx,f'{mat}:{reg}')
    frac=refreshes/total
    print(f"APPROX01_ADAPTIVE|AMPLITUDE_CM={amp}|HEAD_THRESHOLD_CM={threshold}|MAX_AGE=8|REFRESH_FRACTION={frac:.9f}|AVOIDED_FRACTION={1-frac:.9f}|WORST_MAX_REL={worst[0]:.17e}|WORST_CASE={worst[1]}|MEAN_REL_ALL={statistics.mean(all_rel):.17e}")
print('FPE_APPROX01_AMPLITUDE_FRONTIER=PASS')
PY

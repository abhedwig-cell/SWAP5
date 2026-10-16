#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-matrix-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX01_MATRIX_FAIL $*" >&2; exit 1; }

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
echo 'material,regime,point,offset_cm,tangent,bottom_flux' > "$CSV"
offsets=(0 0.05 0.1 0.25 0.5 0.25 0.1 0 -0.05 -0.1 -0.25 -0.5)

for material in B01 B12 O05 O14; do
  for spec in "wet -10" "mid -75" "dry -500"; do
    read -r regime h0 <<< "$spec"
    point=0
    for offset in "${offsets[@]}"; do
      point=$((point+1))
      hbot="$(python3 - <<PY
print(float("$h0")+float("$offset"))
PY
)"
      raw="$("$BUILD/test" "$material" "$h0" "$hbot")"
      line="$(printf '%s\n' "$raw" | grep '^APPROX01_MATRIX_POINT|')"
      python3 - "$material" "$regime" "$point" "$offset" "$line" "$CSV" <<'PY'
import csv,sys
material,regime,point,offset,line,path=sys.argv[1:]
d={}
for p in line.strip().split('|')[1:]:
    k,v=p.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([material,regime,point,offset,d['TANGENT'],d['BOTTOM_FLUX']])
print(f"APPROX01_MATRIX_POINT_OK|MATERIAL={material}|REGIME={regime}|POINT={point}|OFFSET_CM={offset}|TANGENT={d['TANGENT']}|BOTTOM_FLUX={d['BOTTOM_FLUX']}")
PY
    done
  done
done

python3 - "$CSV" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
if len(rows)!=144: raise SystemExit(f"expected 144 rows, got {len(rows)}")
global_worst={2:(0,None),4:(0,None),8:(0,None)}
for material in ('B01','B12','O05','O14'):
  for regime in ('wet','mid','dry'):
    rr=[r for r in rows if r['material']==material and r['regime']==regime]
    tang=[float(r['tangent']) for r in rr]
    print(f"APPROX01_MATRIX_EVOLUTION|MATERIAL={material}|REGIME={regime}|MIN={min(tang):.17e}|MAX={max(tang):.17e}|SPAN={max(tang)-min(tang):.17e}")
    for cadence in (2,4,8):
      ae=[]; re=[]; qae=[]; qre=[]
      offsets=[float(r['offset_cm']) for r in rr]
      flux=[float(r['bottom_flux']) for r in rr]
      for i,t in enumerate(tang):
        refresh=(i//cadence)*cadence
        lag=tang[refresh]
        e=abs(lag-t)
        ae.append(e)
        re.append(e/max(abs(t),1e-30))
        qpred=flux[refresh]+lag*(offsets[i]-offsets[refresh])
        qe=abs(qpred-flux[i])
        qae.append(qe)
        excursion=abs(flux[i]-flux[refresh])
        if excursion>1e-12:
          qre.append(qe/excursion)
      mx=max(re)
      if mx>global_worst[cadence][0]:
        global_worst[cadence]=(mx,f"{material}:{regime}")
      print(f"APPROX01_MATRIX_LAG|MATERIAL={material}|REGIME={regime}|CADENCE={cadence}|MAX_ABS={max(ae):.17e}|MEAN_ABS={statistics.mean(ae):.17e}|MAX_REL={mx:.17e}|MEAN_REL={statistics.mean(re):.17e}|MAX_Q_PRED_ABS_ERROR={max(qae):.17e}|MEAN_Q_PRED_ABS_ERROR={statistics.mean(qae):.17e}|MAX_Q_PRED_REL_TO_EXCURSION={(max(qre) if qre else 0.0):.17e}")
for cadence,(err,where) in global_worst.items():
  print(f"APPROX01_MATRIX_WORST|CADENCE={cadence}|MAX_REL={err:.17e}|CASE={where}")
print("FPE_APPROX01_TANGENT_MATRIX=PASS")
PY

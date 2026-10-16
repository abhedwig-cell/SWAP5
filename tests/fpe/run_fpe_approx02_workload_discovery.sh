#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx02-discovery-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX02_DISCOVERY_FAIL $*" >&2; exit 1; }

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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_approx02_richards_effort.f90 -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

CSV="$BUILD/results.csv"
echo 'material,regime,h0,top_factor,duration,status,seconds,nonlinear,jacobian,linear,backtrack,bottom_flux,mass_residual' > "$CSV"

run_case(){
  local material="$1" regime="$2" h0="$3" factor="$4" duration="$5" raw line
  set +e
  raw="$("$BUILD/test" "$material" "$h0" "$h0" "$factor" "$duration" 1 2>&1)"
  rc=$?
  set -e
  line="$(printf '%s
' "$raw" | grep '^APPROX02_SOLVE|' || true)"
  if [[ -z "$line" ]]; then
    echo "APPROX02_DISCOVERY_NO_RECORD|MATERIAL=$material|REGIME=$regime|FACTOR=$factor|DURATION=$duration|RC=$rc"
    return
  fi
  python3 - "$material" "$regime" "$h0" "$factor" "$duration" "$line" "$CSV" <<'PY'
import csv,sys
material,regime,h0,factor,duration,line,path=sys.argv[1:]
d={}
for part in line.strip().split('|')[1:]:
    k,v=part.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([material,regime,h0,factor,duration,d['STATUS'],d['SECONDS_PER_SOLVE'],d['NONLINEAR'],d['JACOBIAN'],d['LINEAR'],d['BACKTRACK'],d['BOTTOM_FLUX'],d['MASS_RESIDUAL']])
print(f"APPROX02_DISCOVERY|MATERIAL={material}|REGIME={regime}|FACTOR={factor}|DURATION={duration}|STATUS={d['STATUS']}|NONLINEAR={d['NONLINEAR']}|BACKTRACK={d['BACKTRACK']}|BOTTOM_FLUX={d['BOTTOM_FLUX']}|MASS_RESIDUAL={d['MASS_RESIDUAL']}")
PY
}

for material in B01 B12 O05 O14; do
  for spec in "wet -10" "mid -75" "dry -500"; do
    read -r regime h0 <<< "$spec"
    for factor in -1 0 -2 1; do
      for duration in 1e-4 1e-3 1e-2 5e-2; do
        run_case "$material" "$regime" "$h0" "$factor" "$duration"
      done
    done
  done
done

python3 - "$CSV" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1])))
conv=[r for r in rows if int(r['status'])==1]
conv.sort(key=lambda r:(int(r['nonlinear']),int(r['backtrack'])),reverse=True)
print(f"APPROX02_DISCOVERY_SUMMARY|ROWS={len(rows)}|CONVERGED={len(conv)}")
for r in conv[:24]:
    print(
      "APPROX02_DISCOVERY_TOP"
      f"|MATERIAL={r['material']}|REGIME={r['regime']}|FACTOR={r['top_factor']}|DURATION={r['duration']}"
      f"|NONLINEAR={r['nonlinear']}|JACOBIAN={r['jacobian']}|LINEAR={r['linear']}|BACKTRACK={r['backtrack']}"
      f"|BOTTOM_FLUX={r['bottom_flux']}|MASS_RESIDUAL={r['mass_residual']}"
    )
multi=[r for r in conv if int(r['nonlinear'])>=2]
if not multi:
    raise SystemExit("no converged multi-Newton workload found")
best=multi[0]
print(
  "APPROX02_DISCOVERY_SELECTED"
  f"|MATERIAL={best['material']}|REGIME={best['regime']}|H0={best['h0']}|FACTOR={best['top_factor']}|DURATION={best['duration']}"
  f"|NONLINEAR={best['nonlinear']}|BACKTRACK={best['backtrack']}"
)
print("FPE_APPROX02_WORKLOAD_DISCOVERY=PASS")
PY

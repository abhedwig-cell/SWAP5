#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx02-balance-sweep-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX02_BALANCE_SWEEP_FAIL $*" >&2; exit 1; }

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
echo 'balance_mult,rep,ns,status,nonlinear,jacobian,linear,backtrack,bottom_flux,mass_residual,h1,h2,h3,h4,th1,th2,th3,th4' > "$CSV"

run_one(){
  local mult="$1" rep="$2" raw line
  raw="$("$BUILD/test" O14 -10 -10 0 5e-2 1 400 "$mult")"
  line="$(printf '%s\n' "$raw" | grep '^APPROX02_SOLVE|')"
  python3 - "$mult" "$rep" "$line" "$CSV" <<'PY'
import csv,sys
mult,rep,line,path=sys.argv[1:]
d={}
for part in line.strip().split('|')[1:]:
    k,v=part.split('=',1); d[k]=v
keys=['NS_PER_SOLVE','STATUS','NONLINEAR','JACOBIAN','LINEAR','BACKTRACK','BOTTOM_FLUX','MASS_RESIDUAL',
      'H1','H2','H3','H4','TH1','TH2','TH3','TH4']
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([mult,rep]+[d[k] for k in keys])
print(line)
PY
}

levels=(1 10 100 1000 10000 1000000 100000000 10000000000)
REPS=12
for rep in $(seq 1 "$REPS"); do
  if (( rep % 2 == 1 )); then order=("${levels[@]}"); else order=(10000000000 100000000 1000000 10000 1000 100 10 1); fi
  for mult in "${order[@]}"; do run_one "$mult" "$rep"; done
done

python3 - "$CSV" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
levels=(1,10,100,1000,10000,1000000,100000000,10000000000)
by={int(t):[r for r in rows if int(float(r['balance_mult']))==t] for t in levels}
for t,rr in by.items():
    if len(rr)!=12: raise SystemExit(f'missing reps balance={t}: {len(rr)}')
    if any(int(r['status'])!=1 for r in rr): raise SystemExit(f'nonconverged balance={t}')
ref=by[1][0]
ref_heads=[float(ref[f'h{i}']) for i in range(1,5)]
ref_theta=[float(ref[f'th{i}']) for i in range(1,5)]
ref_flux=float(ref['bottom_flux'])
ref_mass=float(ref['mass_residual'])
ref_ns=statistics.median(float(r['ns']) for r in by[1])
for t in levels:
    rr=by[t]
    vals=[float(r['ns']) for r in rr]
    r0=rr[0]
    heads=[float(r0[f'h{i}']) for i in range(1,5)]
    theta=[float(r0[f'th{i}']) for i in range(1,5)]
    flux=float(r0['bottom_flux']); mass=float(r0['mass_residual'])
    h_abs=max(abs(a-b) for a,b in zip(heads,ref_heads))
    h_rel=max(abs(a-b)/max(abs(b),1e-30) for a,b in zip(heads,ref_heads))
    th_abs=max(abs(a-b) for a,b in zip(theta,ref_theta))
    th_rel=max(abs(a-b)/max(abs(b),1e-30) for a,b in zip(theta,ref_theta))
    flux_abs=abs(flux-ref_flux); flux_rel=flux_abs/max(abs(ref_flux),1e-30)
    med=statistics.median(vals); ratio=med/ref_ns
    print(
      f"APPROX02_BALANCE_RESULT|BALANCE_MULT={t}|MEDIAN_NS={med:.17e}|RUNTIME_RATIO={ratio:.9f}"
      f"|SPEEDUP_PERCENT={(1-ratio)*100:.6f}|NONLINEAR={sorted({int(r['nonlinear']) for r in rr})}"
      f"|BACKTRACK={sorted({int(r['backtrack']) for r in rr})}"
      f"|MAX_HEAD_ABS_CM={h_abs:.17e}|MAX_HEAD_REL={h_rel:.17e}"
      f"|MAX_THETA_ABS={th_abs:.17e}|MAX_THETA_REL={th_rel:.17e}"
      f"|BOTTOM_FLUX_ABS={flux_abs:.17e}|BOTTOM_FLUX_REL={flux_rel:.17e}"
      f"|MASS_RESIDUAL={mass:.17e}|MASS_RESIDUAL_DELTA={mass-ref_mass:.17e}"
    )
print('FPE_APPROX02_BALANCE_SWEEP=PASS')
PY

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx02-candidate-matrix-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX02_CANDIDATE_MATRIX_FAIL $*" >&2; exit 1; }

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
echo 'material,regime,h0,mode,balance_mult,ns,status,nonlinear,jacobian,linear,backtrack,bottom_flux,mass_residual,h1,h2,h3,h4,th1,th2,th3,th4' > "$CSV"

run_one(){
  local material="$1" regime="$2" h0="$3" mode="$4" head_mult="$5" balance_mult="$6" raw line
  raw="$("$BUILD/test" "$material" "$h0" "$h0" 0 5e-2 "$head_mult" 300 "$balance_mult")"
  line="$(printf '%s\n' "$raw" | grep '^APPROX02_SOLVE|')"
  python3 - "$material" "$regime" "$h0" "$mode" "$balance_mult" "$line" "$CSV" <<'PY'
import csv,sys
material,regime,h0,mode,balance,line,path=sys.argv[1:]
d={}
for part in line.strip().split('|')[1:]:
    k,v=part.split('=',1); d[k]=v
keys=['NS_PER_SOLVE','STATUS','NONLINEAR','JACOBIAN','LINEAR','BACKTRACK','BOTTOM_FLUX','MASS_RESIDUAL',
      'H1','H2','H3','H4','TH1','TH2','TH3','TH4']
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([material,regime,h0,mode,balance]+[d[k] for k in keys])
print(line)
PY
}

for material in B01 B12 O05 O14; do
  for spec in "wet -10" "mid -75" "dry -500"; do
    read -r regime h0 <<< "$spec"
    run_one "$material" "$regime" "$h0" exact 1 1
    run_one "$material" "$regime" "$h0" m1e6 10000000000 1000000
    run_one "$material" "$regime" "$h0" m1e8 10000000000 100000000
    run_one "$material" "$regime" "$h0" m1e10 10000000000 10000000000
  done
done

python3 - "$CSV" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
cases={(r['material'],r['regime']) for r in rows}
if len(cases)!=12: raise SystemExit(f'expected 12 cases, got {len(cases)}')
summary={m:[] for m in ('m1e6','m1e8','m1e10')}
for material,regime in sorted(cases):
    rr=[r for r in rows if r['material']==material and r['regime']==regime]
    by={r['mode']:r for r in rr}
    if set(by)!= {'exact','m1e6','m1e8','m1e10'}:
        raise SystemExit(f'incomplete case {material} {regime}: {set(by)}')
    ref=by['exact']
    if int(ref['status'])!=1: raise SystemExit(f'exact nonconverged {material} {regime}')
    rh=[float(ref[f'h{i}']) for i in range(1,5)]
    rt=[float(ref[f'th{i}']) for i in range(1,5)]
    rf=float(ref['bottom_flux']); rns=float(ref['ns']); rnl=int(ref['nonlinear'])
    for mode in ('m1e6','m1e8','m1e10'):
        r=by[mode]
        if int(r['status'])!=1:
            print(f"APPROX02_MATRIX_CASE|MATERIAL={material}|REGIME={regime}|MODE={mode}|NONCONVERGED=1")
            summary[mode].append({'converged':False})
            continue
        h=[float(r[f'h{i}']) for i in range(1,5)]
        th=[float(r[f'th{i}']) for i in range(1,5)]
        flux=float(r['bottom_flux']); ns=float(r['ns']); nl=int(r['nonlinear'])
        h_abs=max(abs(a-b) for a,b in zip(h,rh))
        h_rel=max(abs(a-b)/max(abs(b),1e-30) for a,b in zip(h,rh))
        th_abs=max(abs(a-b) for a,b in zip(th,rt))
        th_rel=max(abs(a-b)/max(abs(b),1e-30) for a,b in zip(th,rt))
        f_abs=abs(flux-rf); f_rel=f_abs/max(abs(rf),1e-30)
        ratio=ns/rns; speed=(1-ratio)*100
        item=dict(converged=True,speed=speed,ratio=ratio,h_abs=h_abs,h_rel=h_rel,th_abs=th_abs,th_rel=th_rel,
                  f_abs=f_abs,f_rel=f_rel,nl=nl,rnl=rnl,material=material,regime=regime)
        summary[mode].append(item)
        print(
          f"APPROX02_MATRIX_CASE|MATERIAL={material}|REGIME={regime}|MODE={mode}"
          f"|RUNTIME_RATIO={ratio:.9f}|SPEEDUP_PERCENT={speed:.6f}"
          f"|EXACT_NONLINEAR={rnl}|CANDIDATE_NONLINEAR={nl}"
          f"|MAX_HEAD_ABS_CM={h_abs:.17e}|MAX_HEAD_REL={h_rel:.17e}"
          f"|MAX_THETA_ABS={th_abs:.17e}|MAX_THETA_REL={th_rel:.17e}"
          f"|BOTTOM_FLUX_ABS={f_abs:.17e}|BOTTOM_FLUX_REL={f_rel:.17e}"
          f"|MASS_RESIDUAL={float(r['mass_residual']):.17e}"
        )
for mode,items in summary.items():
    conv=[x for x in items if x.get('converged')]
    if len(conv)!=12:
        print(f"APPROX02_MATRIX_SUMMARY|MODE={mode}|CONVERGED={len(conv)}|TOTAL=12")
        continue
    worst_h=max(conv,key=lambda x:x['h_rel'])
    worst_f=max(conv,key=lambda x:x['f_rel'])
    print(
      f"APPROX02_MATRIX_SUMMARY|MODE={mode}|CONVERGED=12"
      f"|MEDIAN_SPEEDUP_PERCENT={statistics.median(x['speed'] for x in conv):.6f}"
      f"|MIN_SPEEDUP_PERCENT={min(x['speed'] for x in conv):.6f}"
      f"|MAX_SPEEDUP_PERCENT={max(x['speed'] for x in conv):.6f}"
      f"|WORST_HEAD_REL={worst_h['h_rel']:.17e}|WORST_HEAD_CASE={worst_h['material']}:{worst_h['regime']}"
      f"|WORST_FLUX_REL={worst_f['f_rel']:.17e}|WORST_FLUX_CASE={worst_f['material']}:{worst_f['regime']}"
      f"|WORST_THETA_REL={max(x['th_rel'] for x in conv):.17e}"
    )
print('FPE_APPROX02_CANDIDATE_MATRIX=PASS')
PY

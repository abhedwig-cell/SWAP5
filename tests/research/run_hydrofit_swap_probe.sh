#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-hydrofit-p6-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "HYDROFIT_P6_FAIL $*" >&2; exit 1; }

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
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/research/test_hydrofit_swap_probe.f90 -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"


# Materialize the preregistered P5B representatives deterministically.
PYTHONPATH=research/hydrofit python3 - "$BUILD/reps.csv" <<'PY'
import csv,sys,numpy as np
from hydrofit import FitConfig,MvGParameters,Observation,evaluate,near_equivalent_ensemble,function_envelope

truth=MvGParameters(0.06,0.43,0.015,1.7,35.0)
theta_heads=np.array([-1.0,-10.0,-100.0,-1000.0])
k_heads=np.array([-10.0,-1000.0])
theta,_=evaluate(theta_heads,truth,"swap_default_mvg")
_,kval=evaluate(k_heads,truth,"swap_default_mvg")
theta_delta=np.array([0.0015,-0.0020,0.0010,-0.0015])
logk_delta=np.array([0.04,-0.05])
obs=[Observation("theta",float(h),float(v+d),sigma=0.01) for h,v,d in zip(theta_heads,theta,theta_delta)]
obs += [Observation("K",float(h),float(v*np.exp(d)),sigma=0.1) for h,v,d in zip(k_heads,kval,logk_delta)]
cfg=FitConfig(semantics="swap_default_mvg",fixed_l=0.5,fixed_h_entry=0.0,weighting_mode="family_mean")
starts=[
 MvGParameters(0.03,0.38,0.005,1.25,8.0),
 MvGParameters(0.12,0.52,0.05,2.3,120.0),
 MvGParameters(0.08,0.46,0.012,1.5,25.0),
]
ens=near_equivalent_ensemble(obs,starts,cfg,local_draws=1500,broad_draws=1500)
env=function_envelope(ens,cfg)
with open(sys.argv[1],"w",newline="") as f:
 w=csv.writer(f); w.writerow(["rep","candidate","theta_r","theta_s","alpha","n","Ks","l","objective"])
 for rep,ci in enumerate(env.representative_candidate_indices):
  x=ens.candidates[ci]
  w.writerow([rep,int(ci),*map(float,x),0.5,float(ens.objectives[ci])])
print(f"HYDROFIT_P6_REPRESENTATIVES|COUNT={len(env.representative_candidate_indices)}|PRIMARY={int(ens.primary_mask.sum())}|JSTAR={ens.optimum.objective:.17g}")
PY

OUT="$BUILD/p6_rows.csv"
echo 'rep,candidate,objective,status,nonlinear,jacobian,linear,backtrack,mass_residual,bottom_flux' > "$OUT"
tail -n +2 "$BUILD/reps.csv" | while IFS=, read -r rep candidate tr ts alpha nvg ksat lambda objective; do
  raw="$("$BUILD/test" "$tr" "$ts" "$alpha" "$nvg" "$ksat" "$lambda" -75 -75 -1 0.01 1 2>&1)"
  printf '%s\n' "$raw"
  line="$(printf '%s\n' "$raw" | grep '^HYDROFIT_P6|' || true)"
  [[ -n "$line" ]] || fail "no probe record rep=$rep"
  python3 - "$rep" "$candidate" "$objective" "$line" "$OUT" <<'PY'
import csv,sys,math
rep,candidate,objective,line,path=sys.argv[1:]
d={}
for part in line.split('|')[1:]:
 k,v=part.split('=',1); d[k]=v
row=[rep,candidate,objective,d['STATUS'],d['NONLINEAR'],d['JACOBIAN'],d['LINEAR'],d['BACKTRACK'],d['MASS_RESIDUAL'],d['BOTTOM_FLUX']]
with open(path,'a',newline='') as f: csv.writer(f).writerow(row)
PY
done

python3 - "$OUT" <<'PY'
import csv,sys,math
rows=list(csv.DictReader(open(sys.argv[1])))
if not rows: raise SystemExit("no P6 rows")
base=rows[0]
print(f"HYDROFIT_P6_SUMMARY|COUNT={len(rows)}|BASE_NONLINEAR={base['nonlinear']}|BASE_BACKTRACK={base['backtrack']}")
for r in rows:
 print("HYDROFIT_P6_RESULT"
       f"|REP={r['rep']}|CANDIDATE={r['candidate']}|OBJECTIVE={r['objective']}|STATUS={r['status']}"
       f"|NONLINEAR={r['nonlinear']}|JACOBIAN={r['jacobian']}|LINEAR={r['linear']}|BACKTRACK={r['backtrack']}"
       f"|MASS_RESIDUAL={r['mass_residual']}|BOTTOM_FLUX={r['bottom_flux']}")
 if not math.isfinite(float(r['mass_residual'])): raise SystemExit("nonfinite mass")
if any(int(r['status']) != 1 for r in rows):
 print("HYDROFIT_P6_NOTE=ONE_OR_MORE_NONCONVERGED")
print("HYDROFIT_P6_ENSEMBLE=PASS")
PY

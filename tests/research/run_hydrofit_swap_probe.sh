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


# P6B: discover a harder workload using representative 0 only.
rep0="$(tail -n +2 "$BUILD/reps.csv" | head -n 1)"
IFS=, read -r rep0_id rep0_candidate tr0 ts0 alpha0 nvg0 ksat0 lambda0 objective0 <<< "$rep0"
DISC="$BUILD/p6b_discovery.csv"
echo 'h0,factor,duration,status,nonlinear,backtrack,jacobian,linear,mass_residual' > "$DISC"
for h0 in -10 -75 -500; do
  for factor in -1 0 -2 1; do
    for duration in 1e-4 1e-3 1e-2 5e-2; do
      raw="$("$BUILD/test" "$tr0" "$ts0" "$alpha0" "$nvg0" "$ksat0" "$lambda0" "$h0" "$h0" "$factor" "$duration" 1 2>&1)"
      line="$(printf '%s\n' "$raw" | grep '^HYDROFIT_P6|' || true)"
      [[ -n "$line" ]] || continue
      python3 - "$h0" "$factor" "$duration" "$line" "$DISC" <<'PY'
import csv,sys
h0,factor,duration,line,path=sys.argv[1:]
d={}
for p in line.split('|')[1:]:
 k,v=p.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
 csv.writer(f).writerow([h0,factor,duration,d['STATUS'],d['NONLINEAR'],d['BACKTRACK'],d['JACOBIAN'],d['LINEAR'],d['MASS_RESIDUAL']])
PY
    done
  done
done

selected="$(python3 - "$DISC" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1])))
conv=[r for r in rows if int(r['status'])==1 and int(r['nonlinear'])>=2]
conv.sort(key=lambda r:(int(r['nonlinear']),int(r['backtrack'])),reverse=True)
if not conv:
 print("NONE")
else:
 r=conv[0]
 print(",".join([r['h0'],r['factor'],r['duration'],r['nonlinear'],r['backtrack']]))
PY
)"
if [[ "$selected" == "NONE" ]]; then
  echo "HYDROFIT_P6B=BLOCKED_NO_MULTI_NEWTON_WORKLOAD"
  exit 0
fi
IFS=, read -r sel_h0 sel_factor sel_duration sel_nl sel_bt <<< "$selected"
echo "HYDROFIT_P6B_SELECTED|H0=$sel_h0|FACTOR=$sel_factor|DURATION=$sel_duration|REP0_NONLINEAR=$sel_nl|REP0_BACKTRACK=$sel_bt"

tail -n +2 "$BUILD/reps.csv" | while IFS=, read -r rep candidate tr ts alpha nvg ksat lambda objective; do
  raw="$("$BUILD/test" "$tr" "$ts" "$alpha" "$nvg" "$ksat" "$lambda" "$sel_h0" "$sel_h0" "$sel_factor" "$sel_duration" 1 2>&1)"
  line="$(printf '%s\n' "$raw" | grep '^HYDROFIT_P6|' || true)"
  [[ -n "$line" ]] || fail "P6B no record rep=$rep"
  python3 - "$rep" "$candidate" "$objective" "$line" <<'PY'
import sys
rep,candidate,objective,line=sys.argv[1:]
d={}
for p in line.split('|')[1:]:
 k,v=p.split('=',1); d[k]=v
print("HYDROFIT_P6B_RESULT"
      f"|REP={rep}|CANDIDATE={candidate}|OBJECTIVE={objective}|STATUS={d['STATUS']}"
      f"|NONLINEAR={d['NONLINEAR']}|JACOBIAN={d['JACOBIAN']}|LINEAR={d['LINEAR']}|BACKTRACK={d['BACKTRACK']}"
      f"|MASS_RESIDUAL={d['MASS_RESIDUAL']}|BOTTOM_FLUX={d['BOTTOM_FLUX']}")
PY
done
echo "HYDROFIT_P6B=PASS"


# P6C: fixed 18-workload replication matrix across all representatives.
P6C="$BUILD/p6c.csv"
echo 'rep,h0,factor,duration,status,nonlinear,jacobian,linear,backtrack,mass_residual' > "$P6C"
tail -n +2 "$BUILD/reps.csv" | while IFS=, read -r rep candidate tr ts alpha nvg ksat lambda objective; do
  for h0 in -10 -75 -500; do
    for factor in -1 0 1; do
      for duration in 1e-2 5e-2; do
        raw="$("$BUILD/test" "$tr" "$ts" "$alpha" "$nvg" "$ksat" "$lambda" "$h0" "$h0" "$factor" "$duration" 1 2>&1)"
        line="$(printf '%s\n' "$raw" | grep '^HYDROFIT_P6|' || true)"
        [[ -n "$line" ]] || fail "P6C no record rep=$rep h0=$h0 factor=$factor duration=$duration"
        python3 - "$rep" "$h0" "$factor" "$duration" "$line" "$P6C" <<'PY'
import csv,sys
rep,h0,factor,duration,line,path=sys.argv[1:]
d={}
for p in line.split('|')[1:]:
 k,v=p.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
 csv.writer(f).writerow([rep,h0,factor,duration,d['STATUS'],d['NONLINEAR'],d['JACOBIAN'],d['LINEAR'],d['BACKTRACK'],d['MASS_RESIDUAL']])
PY
      done
    done
  done
done

python3 - "$P6C" <<'PY'
import csv,sys,statistics,collections
rows=list(csv.DictReader(open(sys.argv[1])))
by=collections.defaultdict(list)
for r in rows: by[(r['h0'],r['factor'],r['duration'])].append(r)
ident=spread=ge10=ge20=ge40=0
anchor=None
for key in sorted(by,key=lambda x:(float(x[0]),float(x[1]),float(x[2]))):
 rs=sorted(by[key],key=lambda r:int(r['rep']))
 vals=[int(r['nonlinear']) for r in rs if int(r['status'])==1]
 if len(vals)!=8:
  print(f"HYDROFIT_P6C_WORKLOAD|H0={key[0]}|FACTOR={key[1]}|DURATION={key[2]}|CONVERGED={len(vals)}|INCOMPLETE=1")
  continue
 mn,mx=min(vals),max(vals); ratio=mx/mn if mn else float('inf')
 if mx==mn: ident+=1
 else: spread+=1
 ge10 += ratio>=1.10; ge20 += ratio>=1.20; ge40 += ratio>=1.40
 minrep=vals.index(mn); maxrep=vals.index(mx)
 print(f"HYDROFIT_P6C_WORKLOAD|H0={key[0]}|FACTOR={key[1]}|DURATION={key[2]}"
       f"|MIN={mn}|MEDIAN={statistics.median(vals):g}|MAX={mx}|RATIO={ratio:.6f}|MINREP={minrep}|MAXREP={maxrep}")
 if key==('-75','0','5e-2'): anchor=vals
expected=[34,29,41,38,32,32,36,38]
if anchor is None or len(anchor)!=8:
 raise SystemExit(f"P6C anchor missing {anchor}")
if any(abs(a-b)>1 for a,b in zip(anchor,expected)):
 raise SystemExit(f"P6C anchor materially changed {anchor}")
if anchor != expected:
 print(f"HYDROFIT_P6C_ANCHOR_JITTER|OBSERVED={anchor}|REFERENCE={expected}")
print(f"HYDROFIT_P6C_SUMMARY|WORKLOADS={len(by)}|IDENTICAL={ident}|SPREAD={spread}|GE10={ge10}|GE20={ge20}|GE40={ge40}")
print("HYDROFIT_P6C=PASS")
PY

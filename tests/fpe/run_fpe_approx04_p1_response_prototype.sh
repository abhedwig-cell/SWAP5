#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx04-p1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/lib" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX04_P1_FAIL $*" >&2; exit 1; }

cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
python3 - "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()

# Make case hydraulics configurable before initialize.
src=src.replace(
"  real(real64), parameter :: H0_CM=-75.0_real64\n",
"  real(real64), save :: REPRO_H0_CM=-75.0_real64\n"
"  real(real64), save :: REPRO_TR=0.032_real64, REPRO_TS=0.423_real64, REPRO_KSAT=4.75_real64\n"
"  real(real64), save :: REPRO_ALPHA=0.0135_real64, REPRO_LAMBDA=0.365_real64, REPRO_NVG=1.455_real64\n",1)
src=src.replace("H0_CM","REPRO_H0_CM")
old="""      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
"""
new="""      p%cofgen(1,k)=REPRO_TR; p%cofgen(2,k)=REPRO_TS; p%cofgen(3,k)=REPRO_KSAT
      p%cofgen(4,k)=REPRO_ALPHA; p%cofgen(5,k)=REPRO_LAMBDA; p%cofgen(6,k)=REPRO_NVG
"""
if old not in src: raise SystemExit("material seam missing")
src=src.replace(old,new,1)

src=src.replace(
"  public :: fgc44_predictor_run_diagnostics_c\n",
"  public :: fgc44_predictor_run_diagnostics_c\n"
"  public :: fgc44_approx04_configure_case_c, fgc44_approx04_physical_state_c\n",1)
needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_approx04_configure_case_c(h0,tr,ts,alpha,nvg,ksat,lambda) &
       bind(C,name="fgc44_approx04_configure_case_c")
    real(c_double), value, intent(in) :: h0,tr,ts,alpha,nvg,ksat,lambda
    fgc44_approx04_configure_case_c=1_c_int
    if(initialized)return
    REPRO_H0_CM=real(h0,real64); REPRO_TR=real(tr,real64); REPRO_TS=real(ts,real64)
    REPRO_ALPHA=real(alpha,real64); REPRO_NVG=real(nvg,real64)
    REPRO_KSAT=real(ksat,real64); REPRO_LAMBDA=real(lambda,real64)
    fgc44_approx04_configure_case_c=0_c_int
  end function fgc44_approx04_configure_case_c

  integer(c_int) function fgc44_approx04_physical_state_c(heads,theta) bind(C,name="fgc44_approx04_physical_state_c")
    real(c_double), intent(out) :: heads(numnod),theta(numnod)
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    fgc44_approx04_physical_state_c=1_c_int
    heads=0.0_c_double; theta=0.0_c_double
    if(.not.initialized)return
    call committed%snapshot(snapshot,available)
    if(.not.available .or. .not.allocated(snapshot))return
    select type(state=>snapshot)
    type is(fmr_b110_physical_state_t)
      if(.not.allocated(state%pressure_head) .or. .not.allocated(state%water_content))return
      heads=state%pressure_head
      theta=state%water_content
    class default
      return
    end select
    fgc44_approx04_physical_state_c=0_c_int
  end function fgc44_approx04_physical_state_c

"""
if needle not in src: raise SystemExit("contains seam missing")
src=src.replace(needle,insert,1)
p.write_text(src)
PY

cat > "$BUILD/py/bench.py" <<'PY'
import ctypes,json,math,os,sys,time
from pathlib import Path
sys.path.insert(0,str(Path("tests/fgc/support").resolve()))
from fgc44_real_swap_ctypes import Fgc44RealSwap

MATERIALS={
"B01":(0.02,0.427494,0.021659,1.734737,31.225016,0.98087),
"B12":(0.01,0.529749,0.016562,1.090671,2.245895,-4.493581),
"O05":(0.01,0.336701,0.030304,2.887502,17.418504,0.0736),
"O14":(0.01,0.393878,0.003288,1.616573,2.495984,0.514012),
}
PATTERNS={
"pos":[0.05,0.10,0.15,0.20,0.25,0.20,0.15,0.10],
"neg":[-0.05,-0.10,-0.15,-0.20,-0.25,-0.20,-0.15,-0.10],
"return":[0.05,0.10,0.20,0.25,0.15,0.05,0.00,-0.05],
"alternate":[0.05,-0.05,0.10,-0.10,0.20,-0.20,0.25,-0.25],
}
material,h0_s,pattern,mode,nseq_s=sys.argv[1:]
h0=float(h0_s); nseq=int(nseq_s)
lib=Path(os.environ["FGC44_SWAP_LIB"])
swap=Fgc44RealSwap(lib)
cfg=swap.lib.fgc44_approx04_configure_case_c
cfg.restype=ctypes.c_int
cfg.argtypes=[ctypes.c_double]*7
tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
st=cfg(h0,tr,ts,alpha,nvg,ksat,lamb)
if st: raise RuntimeError(f"configure failed {st}")
statefn=swap.lib.fgc44_approx04_physical_state_c
statefn.restype=ctypes.c_int
statefn.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
_,_,href=swap.initialize()
offsets=PATTERNS[pattern]
heads=[href+x/100.0 for x in offsets]

def response():
    q,_,t,av=swap.last_trial_response()
    if not av: raise RuntimeError("tangent unavailable")
    return q,t

# Calibration: exact q at all requested heads from same origin.
exact_q=[]; exact_t=[]
for h in heads:
    q=swap.trial(h); qq,t=response()
    if abs(q-qq)>1e-18: raise RuntimeError("q diagnostic mismatch")
    exact_q.append(q); exact_t.append(t); swap.discard()

# Timing uses repeated bounded sequences. Final trial is exact in both arms.
physical_solves=0
max_err=0.0; max_exc=0.0
start=time.perf_counter()
if mode=="exact":
    for _ in range(nseq):
        for h in heads:
            swap.trial(h); physical_solves+=1; swap.discard()
        swap.trial(heads[-1]); physical_solves+=1
        swap.discard()
elif mode=="surrogate":
    for _ in range(nseq):
        q0=swap.trial(href); physical_solves+=1
        _,t0=response(); swap.discard()
        for i,h in enumerate(heads):
            qp=q0+t0*(h-href)
            err=abs(qp-exact_q[i])
            exc=abs(exact_q[i]-q0)
            max_err=max(max_err,err)
            if exc>1e-30: max_exc=max(max_exc,err/exc)
        swap.trial(heads[-1]); physical_solves+=1
        swap.discard()
else:
    raise SystemExit("bad mode")
seconds=time.perf_counter()-start

# Final exact validation and authoritative commit.
qfinal=swap.trial(heads[-1]); physical_solves+=1
if not swap.swap_preflight(): raise RuntimeError("final SWAP preflight")
swap.prepare_ledger()
if not swap.ledger_preflight(): raise RuntimeError("final ledger preflight")
swap.commit_swap(); swap.commit_ledger()
revision,time_day,count,exchange=swap.state()
ha=(ctypes.c_double*4)(); th=(ctypes.c_double*4)()
if statefn(ha,th): raise RuntimeError("physical state query")
out={
"material":material,"h0":h0,"pattern":pattern,"mode":mode,"seconds":seconds,
"nseq":nseq,"physical_solves":physical_solves,"qfinal":qfinal,
"revision":revision,"time_day":time_day,"ledger_count":count,"ledger_exchange":exchange,
"heads":list(ha),"theta":list(th),"max_abs_error":max_err,"max_rel_excursion":max_exc,
"exact_q":exact_q,"exact_t":exact_t,
}
print("APPROX04_P1_RAW|"+json.dumps(out,separators=(",",":")))
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2 -fPIC -fopenmp)
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
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
  "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/lib/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/lib" -I "$BUILD/lib" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/lib/libswap.so" || fail "link"

export PYTHONPATH="$ROOT/tests/fgc/support"
OUT="$BUILD/results.txt"
: > "$OUT"
cases=("B01|wet|-10" "B01|mid|-75" "B12|wet|-10" "O05|wet|-10" "O14|wet|-10" "O14|mid|-75")
patterns=(pos neg return alternate)
nseq=300
for case_spec in "${cases[@]}"; do
  IFS='|' read -r material regime h0 <<< "$case_spec"
  for pattern in "${patterns[@]}"; do
    for mode in exact surrogate; do
      raw="$(FGC44_SWAP_LIB="$BUILD/lib/libswap.so" python3 "$BUILD/py/bench.py" "$material" "$h0" "$pattern" "$mode" "$nseq")" || { printf '%s\n' "$raw" >&2; fail "$material $pattern $mode"; }
      line="$(printf '%s\n' "$raw" | grep '^APPROX04_P1_RAW|' | tail -1)"
      printf '%s|REGIME=%s\n' "$line" "$regime" >> "$OUT"
    done
  done
done

python3 - "$OUT" <<'PY'
import json,statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("APPROX04_P1_RAW|"): continue
    payload,reg=line.strip().split("|REGIME=")
    d=json.loads(payload.split("|",1)[1]); d["regime"]=reg
    rows.append(d)
if len(rows)!=48: raise SystemExit(f"expected 48 rows, got {len(rows)}")
groups={}
for d in rows:
    groups.setdefault((d["material"],d["regime"],d["pattern"]),{})[d["mode"]]=d
case_speed={}
for key,m in sorted(groups.items()):
    if set(m)!={"exact","surrogate"}: raise SystemExit(f"missing arms {key}")
    e,s=m["exact"],m["surrogate"]
    if e["revision"]!=1 or s["revision"]!=1 or e["ledger_count"]!=1 or s["ledger_count"]!=1:
        raise SystemExit(f"commit ownership failure {key}")
    if e["qfinal"]!=s["qfinal"] or e["heads"]!=s["heads"] or e["theta"]!=s["theta"]:
        raise SystemExit(f"final exact state mismatch {key}")
    avoided=1-s["physical_solves"]/e["physical_solves"]
    speed=1-s["seconds"]/e["seconds"]
    case_speed.setdefault(key[:2],[]).append(speed*100)
    if avoided<0.5: raise SystemExit(f"solve avoidance below gate {key}")
    if s["max_rel_excursion"]>0.0041: raise SystemExit(f"P0 envelope exceeded {key}: {s['max_rel_excursion']}")
    print(
      f"APPROX04_P1_PATTERN|MATERIAL={key[0]}|REGIME={key[1]}|PATTERN={key[2]}"
      f"|EXACT_SECONDS={e['seconds']:.9f}|SURROGATE_SECONDS={s['seconds']:.9f}"
      f"|SPEEDUP_PERCENT={speed*100:.6f}|EXACT_SOLVES={e['physical_solves']}|SURROGATE_SOLVES={s['physical_solves']}"
      f"|SOLVES_AVOIDED_PERCENT={avoided*100:.6f}|MAX_ABS_Q_ERROR={s['max_abs_error']:.17e}"
      f"|MAX_REL_EXCURSION={s['max_rel_excursion']:.17e}|FINAL_STATE_IDENTITY=TRUE"
    )
positive=0
for key,speeds in sorted(case_speed.items()):
    med=statistics.median(speeds)
    if med>0: positive+=1
    print(f"APPROX04_P1_CASE|MATERIAL={key[0]}|REGIME={key[1]}|MEDIAN_SPEEDUP_PERCENT={med:.6f}|MIN={min(speeds):.6f}|MAX={max(speeds):.6f}")
print(f"APPROX04_P1_SUMMARY|CASES=6|SPEED_POSITIVE_CASES={positive}")
print("FPE_APPROX04_P1=PASS")
PY

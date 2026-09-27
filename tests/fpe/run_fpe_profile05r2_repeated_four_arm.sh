#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-profile05-stack-e2e-${GITHUB_RUN_ID:-local}-$"
CANDIDATE_TOL="${APPROX02_CANDIDATE_TOL:-1e-4}"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/exact" "$BUILD/a2" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PROFILE05_E2E_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
run_main(Path("$BUILD/modflow-bin"),owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=Path("$BUILD/downloads"),force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

python3 - "$BUILD/a2/mod_fgc44_real_swap_c_bridge.f90" "$CANDIDATE_TOL" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90").read_text()
tol=sys.argv[2]
old="""    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL; p%head_abs_tolerance=TOL
    p%head_rel_tolerance=TOL; p%ponding_tolerance=TOL; p%root_extraction_active=.false.
"""
new=f"""    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL; p%head_rel_tolerance=TOL
    p%ponding_tolerance=TOL; p%practical_richards_a2c_active=.true.; p%root_extraction_active=.false.
"""
if old not in src: raise SystemExit("A2 tolerance seam missing")
Path(sys.argv[1]).write_text(src.replace(old,new,1))
PY
cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/exact/mod_fgc44_real_swap_c_bridge.f90"

python3 - "$BUILD/exact/mod_fgc44_real_swap_c_bridge.f90" "$BUILD/a2/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
for name in sys.argv[1:]:
    p=Path(name); src=p.read_text()
    src=src.replace(
      "  public :: fgc44_predictor_run_diagnostics_c\n",
      "  public :: fgc44_predictor_run_diagnostics_c\n"
      "  public :: fgc44_tangent_cache_configure_c, fgc44_tangent_cache_counts_c\n",1)
    needle="contains\n\n"
    insert="""contains

  integer(c_int) function fgc44_tangent_cache_configure_c(enabled,head_limit_m,max_age) &
       bind(C,name="fgc44_tangent_cache_configure_c")
    integer(c_int), value, intent(in) :: enabled,max_age
    real(c_double), value, intent(in) :: head_limit_m
    integer :: status
    fgc44_tangent_cache_configure_c=1_c_int
    if(.not.initialized)return
    call participant%configure_tangent_cache(enabled/=0_c_int,real(head_limit_m,real64),int(max_age),status)
    fgc44_tangent_cache_configure_c=int(status,c_int)
  end function fgc44_tangent_cache_configure_c

  integer(c_int) function fgc44_tangent_cache_counts_c(fresh_count,reuse_count) &
       bind(C,name="fgc44_tangent_cache_counts_c")
    integer(c_int), intent(out) :: fresh_count,reuse_count
    integer :: fresh,reuse
    fgc44_tangent_cache_counts_c=1_c_int
    fresh_count=0_c_int; reuse_count=0_c_int
    if(.not.initialized)return
    call participant%tangent_cache_counts(fresh,reuse)
    fresh_count=int(fresh,c_int); reuse_count=int(reuse,c_int)
    fgc44_tangent_cache_counts_c=0_c_int
  end function fgc44_tangent_cache_counts_c

"""
    if needle not in src: raise SystemExit(f"cache bridge seam missing {name}")
    p.write_text(src.replace(needle,insert,1))
PY


python3 - "$BUILD/py/fgc44_real_swap_ctypes.py" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/support/fgc44_real_swap_ctypes.py").read_text()
needle="""        self.lib.fgc44_predictor_run_diagnostics_c.argtypes=[
            *([ctypes.POINTER(ctypes.c_int)]*14),
            *([ctypes.POINTER(ctypes.c_double)]*3),
        ]
"""
rep=needle+"""        self.lib.fgc44_tangent_cache_configure_c.restype=ctypes.c_int
        self.lib.fgc44_tangent_cache_configure_c.argtypes=[ctypes.c_int,ctypes.c_double,ctypes.c_int]
        self.lib.fgc44_tangent_cache_counts_c.restype=ctypes.c_int
        self.lib.fgc44_tangent_cache_counts_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int)
        ]
"""
if needle not in src: raise SystemExit("ctypes signature seam missing")
src=src.replace(needle,rep,1)
insert="""
    def configure_tangent_cache(self, enabled: bool, head_limit_m: float=0.005, max_age: int=8) -> None:
        status=self.lib.fgc44_tangent_cache_configure_c(
            int(bool(enabled)),float(head_limit_m),int(max_age)
        )
        if status: raise RuntimeError(f"tangent cache configure failed: {status}")

    def tangent_cache_counts(self) -> tuple[int,int]:
        fresh=ctypes.c_int(); reuse=ctypes.c_int()
        status=self.lib.fgc44_tangent_cache_counts_c(ctypes.byref(fresh),ctypes.byref(reuse))
        if status: raise RuntimeError(f"tangent cache counts failed: {status}")
        return fresh.value,reuse.value

"""
idx=src.index("    def initialize(self)")
src=src[:idx]+insert+src[idx:]
Path(sys.argv[1]).write_text(src)
PY

python3 - "$BUILD/py/test_a2_e2e.py" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/test_fgc44_real_swap_modflow_end_to_end.py").read_text()
src=src.replace("import tempfile\n","import tempfile\nimport time\n",1)
needle="""    swap=Fgc44RealSwap(swaplib)
    hcof,rhs,href=swap.initialize()
"""
rep=needle+"""    a1_enabled=os.environ.get("PROFILE05_A1_CACHE","0")=="1"
    if a1_enabled:
        swap.configure_tangent_cache(True,0.005,8)
"""
if needle not in src: raise SystemExit("PROFILE05 cache configure seam missing")
src=src.replace(needle,rep,1)
needle="""            for outer in range(1,min(40,session.max_solve_iterations)+1):
"""
rep="""            coupling_start=time.perf_counter()
            for outer in range(1,min(40,session.max_solve_iterations)+1):
"""
if needle not in src: raise SystemExit("coupling loop seam missing")
src=src.replace(needle,rep,1)
needle='            require(converged,"real SWAP + MODFLOW coupling did not converge")\n'
rep=needle+'            coupling_seconds=time.perf_counter()-coupling_start\n'
if needle not in src: raise SystemExit("convergence seam missing")
src=src.replace(needle,rep,1)
needle='            print(f"FGC44_LEDGER_EXCHANGE_M={ledger_exchange:.17g}")\n'
rep=needle+'            print(f"PROFILE05_E2E_COUPLING_SECONDS={coupling_seconds:.17g}")\n'+"""            fresh_count,reuse_count=swap.tangent_cache_counts()
            print(f"PROFILE05_E2E_FRESH_COUNT={fresh_count}")
            print(f"PROFILE05_E2E_REUSE_COUNT={reuse_count}")
"""
if needle not in src: raise SystemExit("print seam missing")
src=src.replace(needle,rep,1)
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
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
  BRIDGE_PLACEHOLDER
)

compile_variant(){
  local name="$1"
  local out="$BUILD/$name"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    if [[ "$source" == BRIDGE_PLACEHOLDER ]]; then source="$BUILD/$name/mod_fgc44_real_swap_c_bridge.f90"; fi
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O2 -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $name $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$out/libfgc44_swap.so" || fail "link $name"
}
compile_variant exact
compile_variant a2

export PYTHONPATH="$BUILD/py:$ROOT/src/adapter:$ROOT/tests/fgc/support"
cycles=15
results="$BUILD/results.txt"
: > "$results"

run_arm(){
  local cycle="$1" mode="$2"
  local lib cache
  case "$mode" in
    exact) lib="$BUILD/exact/libfgc44_swap.so"; cache=0 ;;
    a1)    lib="$BUILD/exact/libfgc44_swap.so"; cache=1 ;;
    a2c)   lib="$BUILD/a2/libfgc44_swap.so"; cache=0 ;;
    stack) lib="$BUILD/a2/libfgc44_swap.so"; cache=1 ;;
    *) fail "unknown arm $mode" ;;
  esac
  local out="$BUILD/cycle-${cycle}-${mode}.txt"
  set +e
  PROFILE05_A1_CACHE="$cache" LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC44_SWAP_LIB="$lib" \
    python3 "$BUILD/py/test_a2_e2e.py" > "$out" 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    cat "$out"
    fail "cycle $cycle mode $mode execution"
  fi
  grep -Fq 'FGC44_REAL_SWAP_MODFLOW_END_TO_END=PASS' "$out" || { cat "$out"; fail "cycle $cycle mode $mode marker"; }
  python3 - "$cycle" "$mode" "$out" >> "$results" <<'PY'
import re,sys
cycle,mode,path=sys.argv[1:]
txt=open(path).read()
def v(name):
    m=re.search(rf'^{re.escape(name)}=(.+)$',txt,re.M)
    if not m:
        raise SystemExit(f"missing {name} in {path}")
    return m.group(1).strip()
iters=len(re.findall(r'^FGC44_ITER=',txt,re.M))
print(
    f"CYCLE={cycle}|MODE={mode}|SECONDS={float(v('PROFILE05_E2E_COUPLING_SECONDS')):.17e}"
    f"|HEAD={float(v('FGC44_FINAL_HEAD_M')):.17e}|QSWAP={float(v('FGC44_FINAL_Q_SWAP_M_PER_S')):.17e}"
    f"|LEDGER={float(v('FGC44_LEDGER_EXCHANGE_M')):.17e}|RESIDUAL={float(v('FGC44_FINAL_FLUX_RESIDUAL')):.17e}"
    f"|ITERS={iters}|FRESH={int(v('PROFILE05_E2E_FRESH_COUNT'))}|REUSE={int(v('PROFILE05_E2E_REUSE_COUNT'))}"
)
PY
}

for cycle in $(seq 1 "$cycles"); do
  case $(( (cycle-1) % 4 )) in
    0) order=(exact a1 a2c stack) ;;
    1) order=(a1 a2c stack exact) ;;
    2) order=(a2c stack exact a1) ;;
    3) order=(stack exact a1 a2c) ;;
  esac
  for mode in "${order[@]}"; do
    run_arm "$cycle" "$mode"
  done
done

python3 - "$results" <<'PY'
import statistics,sys
rows=[]
for line in open(sys.argv[1]):
    d={}
    for p in line.strip().split("|"):
        k,v=p.split("=",1); d[k]=v
    for k in ("SECONDS","HEAD","QSWAP","LEDGER","RESIDUAL"):
        d[k]=float(d[k])
    for k in ("CYCLE","ITERS","FRESH","REUSE"):
        d[k]=int(d[k])
    rows.append(d)
by={}
for d in rows:
    by[(d["CYCLE"],d["MODE"])]=d

stack_ratios=[]; a1_ratios=[]; a2c_ratios=[]; stack_a1=[]; stack_a2c=[]
for cycle in range(1,16):
    e=by[(cycle,"exact")]
    a1=by[(cycle,"a1")]
    a2=by[(cycle,"a2c")]
    st=by[(cycle,"stack")]
    for name,x in (("A1",a1),("A2C",a2),("STACK",st)):
        if abs(x["RESIDUAL"])>1e-15:
            raise SystemExit(f"{name} residual drift cycle {cycle}")
        if x["ITERS"]!=e["ITERS"]:
            raise SystemExit(f"{name} iteration drift cycle {cycle}")
        if abs(x["QSWAP"]-e["QSWAP"])>0.0 or abs(x["LEDGER"]-e["LEDGER"])>0.0:
            raise SystemExit(f"{name} exchange/ledger drift cycle {cycle}")
        if abs(x["HEAD"]-e["HEAD"])>2e-16:
            raise SystemExit(f"{name} head drift cycle {cycle}")
    sr=st["SECONDS"]/e["SECONDS"]
    r1=a1["SECONDS"]/e["SECONDS"]
    r2=a2["SECONDS"]/e["SECONDS"]
    sa1=st["SECONDS"]/a1["SECONDS"]
    sa2=st["SECONDS"]/a2["SECONDS"]
    stack_ratios.append(sr); a1_ratios.append(r1); a2c_ratios.append(r2); stack_a1.append(sa1); stack_a2c.append(sa2)
    print(
      f"PROFILE05R2_B1_CYCLE|CYCLE={cycle}|EXACT_SECONDS={e['SECONDS']:.9f}|A1_SECONDS={a1['SECONDS']:.9f}"
      f"|A2C_SECONDS={a2['SECONDS']:.9f}|STACK_SECONDS={st['SECONDS']:.9f}"
      f"|STACK_SPEEDUP_PERCENT={(1-sr)*100:.6f}|A1_SPEEDUP_PERCENT={(1-r1)*100:.6f}"
      f"|A2C_SPEEDUP_PERCENT={(1-r2)*100:.6f}|STACK_VS_A1_SPEEDUP_PERCENT={(1-sa1)*100:.6f}"
      f"|STACK_VS_A2C_SPEEDUP_PERCENT={(1-sa2)*100:.6f}|STACK_FRESH={st['FRESH']}|STACK_REUSE={st['REUSE']}"
    )

def stats(r):
    sp=[(1-x)*100 for x in r]
    return statistics.median(sp),statistics.mean(sp),min(sp),max(sp),sum(x>0 for x in sp)
sm,smean,smin,smax,spos=stats(stack_ratios)
a1m,a1mean,a1min,a1max,a1pos=stats(a1_ratios)
a2m,a2mean,a2min,a2max,a2pos=stats(a2c_ratios)
sa1m,sa1mean,sa1min,sa1max,sa1pos=stats(stack_a1)
sa2m,sa2mean,sa2min,sa2max,sa2pos=stats(stack_a2c)
print(
 f"PROFILE05R2_B1_SUMMARY|CYCLES=15|STACK_POSITIVE={spos}|STACK_MEDIAN_SPEEDUP_PERCENT={sm:.6f}"
 f"|STACK_MEAN_SPEEDUP_PERCENT={smean:.6f}|STACK_MIN_SPEEDUP_PERCENT={smin:.6f}|STACK_MAX_SPEEDUP_PERCENT={smax:.6f}"
 f"|A1_POSITIVE={a1pos}|A1_MEDIAN_SPEEDUP_PERCENT={a1m:.6f}|A1_MEAN_SPEEDUP_PERCENT={a1mean:.6f}"
 f"|A2C_POSITIVE={a2pos}|A2C_MEDIAN_SPEEDUP_PERCENT={a2m:.6f}|A2C_MEAN_SPEEDUP_PERCENT={a2mean:.6f}"
 f"|STACK_VS_A1_POSITIVE={sa1pos}|STACK_VS_A1_MEDIAN_SPEEDUP_PERCENT={sa1m:.6f}"
 f"|STACK_VS_A2C_POSITIVE={sa2pos}|STACK_VS_A2C_MEDIAN_SPEEDUP_PERCENT={sa2m:.6f}"
)
print("FPE_PROFILE05R2_B1_REPEATED_FOUR_ARM=PASS")
PY

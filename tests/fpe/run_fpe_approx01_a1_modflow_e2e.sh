#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-a1-e2e-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX01_A1_E2E_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
run_main(Path("$BUILD/modflow-bin"),owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=Path("$BUILD/downloads"),force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

python3 - "$BUILD/bridge/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90").read_text()
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
if needle not in src: raise SystemExit("bridge contains seam missing")
src=src.replace(needle,insert,1)
Path(sys.argv[1]).write_text(src)
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

python3 - "$BUILD/py/test_a1_e2e.py" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/test_fgc44_real_swap_modflow_end_to_end.py").read_text()
src=src.replace("import tempfile\n","import tempfile\nimport time\n",1)
src=src.replace(
'from fgc44_real_swap_ctypes import Fgc44RealSwap',
'from fgc44_real_swap_ctypes import Fgc44RealSwap',1)
needle="""    swap=Fgc44RealSwap(swaplib)
    hcof,rhs,href=swap.initialize()
"""
rep=needle+"""    a1_enabled=os.environ.get("FGC44_A1_CACHE","0")=="1"
    if a1_enabled:
        swap.configure_tangent_cache(True,0.005,8)
"""
if needle not in src: raise SystemExit("A1 configure seam missing")
src=src.replace(needle,rep,1)
loopneedle="""            for outer in range(1,min(40,session.max_solve_iterations)+1):
"""
looprep="""            coupling_start=time.perf_counter()
            for outer in range(1,min(40,session.max_solve_iterations)+1):
"""
if loopneedle not in src: raise SystemExit("coupling loop seam missing")
src=src.replace(loopneedle,looprep,1)
reqneedle='            require(converged,"real SWAP + MODFLOW coupling did not converge")\n'
reqrep=reqneedle+"""            coupling_seconds=time.perf_counter()-coupling_start
"""
if reqneedle not in src: raise SystemExit("convergence seam missing")
src=src.replace(reqneedle,reqrep,1)
printneedle="""            print(f"FGC44_LEDGER_EXCHANGE_M={ledger_exchange:.17g}")
"""
printrep=printneedle+"""            fresh_count,reuse_count=swap.tangent_cache_counts()
            print(f"APPROX01_A1_E2E_MODE={int(a1_enabled)}")
            print(f"APPROX01_A1_E2E_COUPLING_SECONDS={coupling_seconds:.17g}")
            print(f"APPROX01_A1_E2E_FRESH_COUNT={fresh_count}")
            print(f"APPROX01_A1_E2E_REUSE_COUNT={reuse_count}")
"""
if printneedle not in src: raise SystemExit("final print seam missing")
src=src.replace(printneedle,printrep,1)
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
  "$BUILD/bridge/mod_fgc44_real_swap_c_bridge.f90"
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/bridge/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD/bridge" -I "$BUILD/bridge" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/bridge/libfgc44_swap.so" || fail "link bridge"

export PYTHONPATH="$BUILD/py:$ROOT/src/adapter:$ROOT/tests/fgc/support"
for mode in exact a1; do
  if [[ "$mode" == a1 ]]; then export FGC44_A1_CACHE=1; else export FGC44_A1_CACHE=0; fi
  LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so"     python3 "$BUILD/py/test_a1_e2e.py" > "$BUILD/$mode.txt"
  grep -Fq 'FGC44_REAL_SWAP_MODFLOW_END_TO_END=PASS' "$BUILD/$mode.txt" || { cat "$BUILD/$mode.txt"; fail "$mode E2E"; }
done

python3 - "$BUILD/exact.txt" "$BUILD/a1.txt" <<'PY'
import re,sys
def read(path):
    txt=open(path).read()
    def v(name):
        m=re.search(rf'^{re.escape(name)}=(.+)$',txt,re.M)
        if not m: raise SystemExit(f'missing {name} in {path}')
        return m.group(1).strip()
    return {
      'head':float(v('FGC44_FINAL_HEAD_M')),
      'qswap':float(v('FGC44_FINAL_Q_SWAP_M_PER_S')),
      'qgw':float(v('FGC44_FINAL_Q_GW_M_PER_S')),
      'res':float(v('FGC44_FINAL_FLUX_RESIDUAL')),
      'ledger':float(v('FGC44_LEDGER_EXCHANGE_M')),
      'seconds':float(v('APPROX01_A1_E2E_COUPLING_SECONDS')),
      'fresh':int(v('APPROX01_A1_E2E_FRESH_COUNT')),
      'reuse':int(v('APPROX01_A1_E2E_REUSE_COUNT')),
      'iters':len(re.findall(r'^FGC44_ITER=',txt,re.M)),
    }
e=read(sys.argv[1]); a=read(sys.argv[2])
print(f"APPROX01_A1_E2E|EXACT_HEAD={e['head']:.17e}|A1_HEAD={a['head']:.17e}|HEAD_DIFF={a['head']-e['head']:.17e}")
print(f"APPROX01_A1_E2E|EXACT_QSWAP={e['qswap']:.17e}|A1_QSWAP={a['qswap']:.17e}|QSWAP_DIFF={a['qswap']-e['qswap']:.17e}")
print(f"APPROX01_A1_E2E|EXACT_LEDGER={e['ledger']:.17e}|A1_LEDGER={a['ledger']:.17e}|LEDGER_DIFF={a['ledger']-e['ledger']:.17e}")
print(f"APPROX01_A1_E2E|EXACT_ITERS={e['iters']}|A1_ITERS={a['iters']}|FRESH={a['fresh']}|REUSE={a['reuse']}")
print(f"APPROX01_A1_E2E|EXACT_SECONDS={e['seconds']:.9f}|A1_SECONDS={a['seconds']:.9f}|RATIO={a['seconds']/e['seconds']:.9f}|SPEEDUP_PERCENT={(1-a['seconds']/e['seconds'])*100:.6f}")
if abs(a['res'])>1e-15 or abs(e['res'])>1e-15:
    raise SystemExit('coupled residual gate drift')
print('FPE_APPROX01_A1_MODFLOW_E2E=PASS')
PY

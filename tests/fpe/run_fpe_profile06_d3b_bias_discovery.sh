#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-profile06-d3b-${GITHUB_RUN_ID:-local}-$"
CANDIDATE_TOL="${APPROX02_CANDIDATE_TOL:-1e-4}"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/exact" "$BUILD/a2" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PROFILE06_D3B_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
run_main(Path("$BUILD/modflow-bin"),owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=Path("$BUILD/downloads"),force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/exact/mod_fgc44_real_swap_c_bridge.f90"
python3 - "$BUILD/exact/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
src=src.replace("real(real64), parameter :: H0_CM=-75.0_real64",
                "real(real64), parameter :: H0_CM=-10.0_real64",1)
old="""      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
"""
new="""      p%cofgen(1,k)=0.01_real64; p%cofgen(2,k)=0.336701_real64; p%cofgen(3,k)=17.418504_real64
      p%cofgen(4,k)=0.030304_real64; p%cofgen(5,k)=0.0736_real64; p%cofgen(6,k)=2.887502_real64
"""
if old not in src: raise SystemExit("O05 material seam missing")
src=src.replace(old,new,1)
src=src.replace(
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n"
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state\n",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n"
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &\n"
"       fmr_new_b110_temporal_indicator_committed_state\n",1)
src=src.replace(
"  public :: fgc44_predictor_run_diagnostics_c\n",
"  public :: fgc44_predictor_run_diagnostics_c\n"
"  public :: fgc44_profile06_corrector_diag_c\n",1)
needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_profile06_corrector_diag_c(solver_status,nonlinear,jacobian,linear,backtrack,retries,constitutive) &
       bind(C,name="fgc44_profile06_corrector_diag_c")
    integer(c_int), intent(out) :: solver_status,nonlinear,jacobian,linear,backtrack,retries,constitutive
    type(fmr_serialized_physical_observation_t) :: obs
    obs=corrector_backend%observation()
    solver_status=int(obs%solver_status,c_int)
    nonlinear=int(obs%solver_diagnostics%nonlinear_iterations,c_int)
    jacobian=int(obs%solver_diagnostics%jacobian_builds,c_int)
    linear=int(obs%solver_diagnostics%linear_solves,c_int)
    backtrack=int(obs%solver_diagnostics%backtracking_attempts,c_int)
    retries=int(obs%solver_diagnostics%internal_retries,c_int)
    constitutive=int(obs%solver_diagnostics%constitutive_evaluations,c_int)
    fgc44_profile06_corrector_diag_c=0_c_int
  end function fgc44_profile06_corrector_diag_c

"""
if needle not in src: raise SystemExit("contains seam missing")
src=src.replace(needle,insert,1)
p.write_text(src)
PY


cp tests/fgc/support/fgc44_real_swap_ctypes.py "$BUILD/py/fgc44_real_swap_ctypes.py"
python3 - "$BUILD/py/fgc44_real_swap_ctypes.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
needle="""        self.lib.fgc44_predictor_run_diagnostics_c.argtypes=[
            *([ctypes.POINTER(ctypes.c_int)]*14),
            *([ctypes.POINTER(ctypes.c_double)]*3),
        ]
"""
rep=needle+"""        self.lib.fgc44_profile06_corrector_diag_c.restype=ctypes.c_int
        self.lib.fgc44_profile06_corrector_diag_c.argtypes=[
            *([ctypes.POINTER(ctypes.c_int)]*7)
        ]
"""
if needle not in src: raise SystemExit("ctypes seam missing")
src=src.replace(needle,rep,1)
idx=src.index("    def initialize(self)")
method="""    def profile06_corrector_diag(self) -> dict[str,int]:
        vals=[ctypes.c_int() for _ in range(7)]
        status=self.lib.fgc44_profile06_corrector_diag_c(*[ctypes.byref(v) for v in vals])
        if status: raise RuntimeError(f"profile06 corrector diag failed: {status}")
        keys=("solver_status","nonlinear","jacobian","linear","backtrack","retries","constitutive")
        return dict(zip(keys,[v.value for v in vals]))

"""
src=src[:idx]+method+src[idx:]
p.write_text(src)
PY

python3 - "$BUILD/py/test_d3b.py" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/test_fgc44_real_swap_modflow_end_to_end.py").read_text()
src=src.replace("WINDOW_DAY=1.0e-4","WINDOW_DAY=1.0e-3",1)
src=src.replace("FLUX_TOL=1.0e-15","FLUX_TOL=1.0e-15\nGW_BIAS_M=float(os.environ.get('PROFILE06_GW_BIAS_M','0.0'))",1)
src=src.replace("flopy.mf6.ModflowGwfic(gwf,strt=reference_head)",
                "flopy.mf6.ModflowGwfic(gwf,strt=reference_head+GW_BIAS_M)",1)
src=src.replace("reference_head+0.002),((0,0,2),reference_head-0.002)",
                "reference_head+GW_BIAS_M+0.002),((0,0,2),reference_head+GW_BIAS_M-0.002)",1)
src=src.replace("    hcof,rhs,href=swap.initialize()",
                "    hcof,rhs,href=swap.initialize_configured(WINDOW_DAY,0.0)",1)
needle="""                q_swap=swap.trial(head)
                q_diag,_,dq_swap_dh,tangent_available=swap.last_trial_response()
"""
rep="""                q_swap=swap.trial(head)
                d=swap.profile06_corrector_diag()
                print("PROFILE06_D3B_CORRECTOR|OUTER=%d|SOLVER_STATUS=%d|NONLINEAR=%d|JACOBIAN=%d|LINEAR=%d|BACKTRACK=%d|RETRIES=%d|CONSTITUTIVE=%d" %
                      (outer,d["solver_status"],d["nonlinear"],d["jacobian"],d["linear"],d["backtrack"],d["retries"],d["constitutive"]))
                q_diag,_,dq_swap_dh,tangent_available=swap.last_trial_response()
"""
if needle not in src: raise SystemExit("trial seam missing")
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

export PYTHONPATH="$BUILD/py:$ROOT/src/adapter:$ROOT/tests/fgc/support"
OUT="$BUILD/discovery.txt"
: > "$OUT"
biases=(-0.020 -0.010 -0.005 -0.002 0.0 0.002 0.005 0.010 0.020)
for bias in "${biases[@]}"; do
  out="$BUILD/bias-${bias}.txt"
  set +e
  PROFILE06_GW_BIAS_M="$bias" LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC44_SWAP_LIB="$BUILD/exact/libfgc44_swap.so" \
    python3 "$BUILD/py/test_d3b.py" > "$out" 2>&1
  rc=$?
  set -e
  pass=0
  if [[ $rc -eq 0 ]] && grep -Fq 'FGC44_REAL_SWAP_MODFLOW_END_TO_END=PASS' "$out"; then pass=1; fi
  python3 - "$bias" "$pass" "$out" >> "$OUT" <<'PY'
import re,sys
bias=float(sys.argv[1]); passed=int(sys.argv[2]); txt=open(sys.argv[3]).read()
rows=[]
for m in re.finditer(r'^PROFILE06_D3B_CORRECTOR\|(.+)$',txt,re.M):
    d={}
    for p in m.group(1).split("|"):
        k,v=p.split("=",1); d[k]=int(v)
    rows.append(d)
def val(name,default="nan"):
    m=re.search(rf'^{re.escape(name)}=(.+)$',txt,re.M)
    return m.group(1).strip() if m else default
mx=max((r["NONLINEAR"] for r in rows),default=0)
total=sum(r["NONLINEAR"] for r in rows)
mb=max((r["BACKTRACK"] for r in rows),default=0)
retries=sum(r["RETRIES"] for r in rows)
print(
 f"PROFILE06_D3B_BIAS|BIAS_M={bias:.6f}|PASS={passed}|OUTER_ITERS={len(rows)}"
 f"|MAX_CORRECTOR_NONLINEAR={mx}|TOTAL_CORRECTOR_NONLINEAR={total}|MAX_BACKTRACK={mb}|TOTAL_RETRIES={retries}"
 f"|FINAL_HEAD={val('FGC44_FINAL_HEAD_M')}|FINAL_QSWAP={val('FGC44_FINAL_Q_SWAP_M_PER_S')}|LEDGER={val('FGC44_LEDGER_EXCHANGE_M')}"
)
PY
done
cat "$OUT"
python3 - "$OUT" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1]):
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    d["BIAS_M"]=float(d["BIAS_M"]); d["PASS"]=int(d["PASS"])
    d["MAX_CORRECTOR_NONLINEAR"]=int(d["MAX_CORRECTOR_NONLINEAR"])
    d["TOTAL_RETRIES"]=int(d["TOTAL_RETRIES"]); d["OUTER_ITERS"]=int(d["OUTER_ITERS"])
    rows.append(d)
eligible=[r for r in rows if r["PASS"]==1 and r["TOTAL_RETRIES"]==0 and r["MAX_CORRECTOR_NONLINEAR"]>=4]
if not eligible:
    print("PROFILE06_D3B_SELECTED|NONE=1")
    raise SystemExit("no stable materially difficult groundwater bias")
eligible.sort(key=lambda r:(abs(r["BIAS_M"]),r["OUTER_ITERS"],r["TOTAL_RETRIES"],r["BIAS_M"]))
best=eligible[0]
print(
 f"PROFILE06_D3B_SELECTED|BIAS_M={best['BIAS_M']:.6f}|OUTER_ITERS={best['OUTER_ITERS']}"
 f"|MAX_CORRECTOR_NONLINEAR={best['MAX_CORRECTOR_NONLINEAR']}|TOTAL_RETRIES={best['TOTAL_RETRIES']}"
)
print("FPE_PROFILE06_D3B_BIAS_DISCOVERY=PASS")
PY

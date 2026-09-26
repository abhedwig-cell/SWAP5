#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-repro01-d1-${GITHUB_RUN_ID:-local}-$"
CANDIDATE_TOL="${APPROX02_CANDIDATE_TOL:-1e-4}"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/exact" "$BUILD/a2" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "REPRO01_D1_FAIL $*" >&2; exit 1; }

cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/exact/mod_fgc44_real_swap_c_bridge.f90"

python3 - "$BUILD/exact/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
src=src.replace(
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n"
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state\n",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n"
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &\n"
"       fmr_new_b110_temporal_indicator_committed_state\n",1)
src=src.replace(
"  public :: fgc44_predictor_run_diagnostics_c\n",
"  public :: fgc44_predictor_run_diagnostics_c\n"
"  public :: fgc44_repro01_backend_diag_c\n",1)
needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_repro01_backend_diag_c(solver_executed,solver_status,nonlinear,jacobian,linear,backtrack, &
       internal_retries,constitutive,temporal_status,temporal_available,a2c_active,head_bound,top_flux,bottom_flux, &
       residual_available,residual) bind(C,name="fgc44_repro01_backend_diag_c")
    integer(c_int), intent(out) :: solver_executed,solver_status,nonlinear,jacobian,linear,backtrack
    integer(c_int), intent(out) :: internal_retries,constitutive,temporal_status,temporal_available,a2c_active
    integer(c_int), intent(out) :: residual_available
    real(c_double), intent(out) :: head_bound,top_flux,bottom_flux,residual
    type(fmr_serialized_physical_observation_t) :: obs
    obs=corrector_backend%observation()
    solver_executed=merge(1_c_int,0_c_int,obs%solver_executed)
    solver_status=int(obs%solver_status,c_int)
    nonlinear=int(obs%solver_diagnostics%nonlinear_iterations,c_int)
    jacobian=int(obs%solver_diagnostics%jacobian_builds,c_int)
    linear=int(obs%solver_diagnostics%linear_solves,c_int)
    backtrack=int(obs%solver_diagnostics%backtracking_attempts,c_int)
    internal_retries=int(obs%solver_diagnostics%internal_retries,c_int)
    constitutive=int(obs%solver_diagnostics%constitutive_evaluations,c_int)
    temporal_status=int(obs%temporal_indicator_status,c_int)
    temporal_available=merge(1_c_int,0_c_int,obs%temporal_indicator_available)
    a2c_active=merge(1_c_int,0_c_int,obs%practical_richards_a2c_active)
    head_bound=real(obs%temporal_head_inf_bound,c_double)
    top_flux=real(obs%top_flux,c_double)
    bottom_flux=real(obs%bottom_flux,c_double)
    residual_available=merge(1_c_int,0_c_int,obs%solver_equation_residual_available)
    residual=real(obs%solver_equation_residual,c_double)
    fgc44_repro01_backend_diag_c=0_c_int
  end function fgc44_repro01_backend_diag_c

"""
if needle not in src: raise SystemExit("contains seam missing")
p.write_text(src.replace(needle,insert,1))
PY

python3 - "$BUILD/py/fgc44_repro01_probe.py" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/support/fgc44_real_swap_ctypes.py").read_text()
src += r'''
def repro01_diag(self):
    import ctypes
    ints=[ctypes.c_int() for _ in range(12)]
    reals=[ctypes.c_double() for _ in range(4)]
    fn=self.lib.fgc44_repro01_backend_diag_c
    fn.restype=ctypes.c_int
    fn.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*11),
                 ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
                 ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_int),
                 ctypes.POINTER(ctypes.c_double)]
    status=fn(*[ctypes.byref(v) for v in ints[:11]],
              ctypes.byref(reals[0]),ctypes.byref(reals[1]),ctypes.byref(reals[2]),
              ctypes.byref(ints[11]),ctypes.byref(reals[3]))
    if status: raise RuntimeError(f"repro01 diagnostics failed: {status}")
    names=["solver_executed","solver_status","nonlinear","jacobian","linear","backtrack",
           "internal_retries","constitutive","temporal_status","temporal_available","a2c_active",
           "residual_available"]
    d={k:v.value for k,v in zip(names,ints)}
    d.update(head_bound=reals[0].value,top_flux=reals[1].value,bottom_flux=reals[2].value,residual=reals[3].value)
    return d
Fgc44RealSwap.repro01_diag=repro01_diag
'''
src += r'''
if __name__=="__main__":
    import os
    swap=Fgc44RealSwap(os.environ["FGC44_SWAP_LIB"])
    hcof,rhs,href=swap.initialize()
    import ctypes
    q=ctypes.c_double()
    status=swap.lib.fgc44_swap_trial_c(float(href),ctypes.byref(q))
    d=swap.repro01_diag()
    fields="|".join(f"{k}={v}" for k,v in d.items())
    print(f"REPRO01_D1|HCOF={hcof:.17e}|RHS={rhs:.17e}|HREF={href:.17e}|TRIAL_STATUS={status}|Q={q.value:.17e}|{fields}")
    raise SystemExit(0)
'''
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
cycles=40
pass=0
failcount=0
for cycle in $(seq 1 "$cycles"); do
  line="$(FGC44_SWAP_LIB="$BUILD/exact/libfgc44_swap.so" python3 "$BUILD/py/fgc44_repro01_probe.py" | grep '^REPRO01_D1|' | tail -1)"
  [[ -n "$line" ]] || fail "missing D1 record cycle $cycle"
  status="$(printf '%s\n' "$line" | sed -n 's/.*|TRIAL_STATUS=\([^|]*\).*/\1/p')"
  echo "REPRO01_D1_CYCLE|CYCLE=$cycle|${line#REPRO01_D1|}"
  if [[ "$status" == "0" ]]; then pass=$((pass+1)); else failcount=$((failcount+1)); fi
done
echo "REPRO01_D1_SUMMARY|CYCLES=$cycles|PASS=$pass|FAIL=$failcount"
echo "FPE_REPRO01_D1=OBSERVED"

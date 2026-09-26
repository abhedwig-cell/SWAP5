#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-repro01-d5-${GITHUB_RUN_ID:-local}-$"
CANDIDATE_TOL="${APPROX02_CANDIDATE_TOL:-1e-4}"
mkdir -p "$BUILD/asan" "$BUILD/valgrind"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "REPRO01_D5_FAIL $*" >&2; exit 1; }

cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/asan/mod_fgc44_real_swap_c_bridge.f90"

python3 - "$BUILD/asan/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
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

cp "$BUILD/asan/mod_fgc44_real_swap_c_bridge.f90" "$BUILD/valgrind/mod_fgc44_real_swap_c_bridge.f90"

cat > "$BUILD/probe.c" <<'C'
#include <stdio.h>
extern int fgc44_swap_initialize_c(double*,double*,double*);
extern int fgc44_swap_trial_c(double,double*);
extern int fgc44_repro01_backend_diag_c(int*,int*,int*,int*,int*,int*,int*,int*,int*,int*,int*,double*,double*,double*,int*,double*);
int main(void){
  double hcof=0,rhs=0,href=0,q=0,hb=0,qt=0,qb=0,res=0;
  int sx=0,ss=0,nl=0,jac=0,lin=0,bt=0,ir=0,ce=0,ts=0,ta=0,a2=0,ra=0;
  int init=fgc44_swap_initialize_c(&hcof,&rhs,&href);
  if(init){ printf("REPRO01_D5|INIT=%d\n",init); return 2; }
  int trial=fgc44_swap_trial_c(href,&q);
  int diag=fgc44_repro01_backend_diag_c(&sx,&ss,&nl,&jac,&lin,&bt,&ir,&ce,&ts,&ta,&a2,&hb,&qt,&qb,&ra,&res);
  printf("REPRO01_D5|INIT=%d|TRIAL=%d|DIAG=%d|HREF=%.17e|Q=%.17e|SOLVER=%d|NL=%d|JAC=%d|LIN=%d|BT=%d|IRETRY=%d|CONST=%d|TEMP=%d|TAVAIL=%d|HB=%.17e\n",
         init,trial,diag,href,q,ss,nl,jac,lin,bt,ir,ce,ts,ta,hb);
  return 0;
}
C

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
  local name="$1"; shift
  local out="$BUILD/$name"
  local extra=("$@")
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    if [[ "$source" == BRIDGE_PLACEHOLDER ]]; then source="$BUILD/$name/mod_fgc44_real_swap_c_bridge.f90"; fi
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" "${extra[@]}" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $name $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp "${extra[@]}" "${objects[@]}" -o "$out/libfgc44_swap.so" || fail "link $name"
}
compile_variant asan -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -fcheck=all
compile_variant valgrind -O0 -g -fcheck=all

gcc -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -c "$BUILD/probe.c" -o "$BUILD/probe-asan.o"
gfortran -fsanitize=address,undefined "$BUILD/probe-asan.o" -L"$BUILD/asan" -Wl,-rpath,"$BUILD/asan" -lfgc44_swap -o "$BUILD/probe-asan"

gcc -O0 -g -c "$BUILD/probe.c" -o "$BUILD/probe-vg.o"
gfortran "$BUILD/probe-vg.o" -L"$BUILD/valgrind" -Wl,-rpath,"$BUILD/valgrind" -lfgc44_swap -o "$BUILD/probe-vg"

asan_pass=0
asan_fail=0
for i in $(seq 1 100); do
  set +e
  raw="$("$BUILD/probe-asan" 2>&1)"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]] && printf '%s\n' "$raw" | grep -q '^REPRO01_D5|'; then
    asan_pass=$((asan_pass+1))
  else
    asan_fail=$((asan_fail+1))
    echo "REPRO01_D5_ASAN_FAIL|CYCLE=$i|RC=$rc"
    printf '%s\n' "$raw" | tail -30
    break
  fi
done
echo "REPRO01_D5_ASAN_SUMMARY|PASS=$asan_pass|FAIL=$asan_fail"

if ! command -v valgrind >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq valgrind
fi

vg_pass=0
vg_fail=0
for i in $(seq 1 10); do
  set +e
  raw="$(valgrind --tool=memcheck --track-origins=yes --leak-check=no --error-exitcode=99 "$BUILD/probe-vg" 2>&1)"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    vg_pass=$((vg_pass+1))
  else
    vg_fail=$((vg_fail+1))
    echo "REPRO01_D5_VALGRIND_FAIL|CYCLE=$i|RC=$rc"
    printf '%s\n' "$raw" | tail -120
    break
  fi
done
echo "REPRO01_D5_VALGRIND_SUMMARY|PASS=$vg_pass|FAIL=$vg_fail"
echo "FPE_REPRO01_D5=OBSERVED"

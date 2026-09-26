#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx03-t1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX03_T1_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys

src=Path("tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90").read_text()
src=src.replace(
    "use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE",
    "use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE",1)
src=src.replace(
    "  real(real64), parameter :: upward_dt = 1.0e-4_real64",
    "  real(real64) :: upward_dt = 1.0e-2_real64",1)
src=src.replace(
    "  real(real64), parameter :: qualification_head_budget = 2.5e-11_real64",
    "  real(real64) :: qualification_head_budget = 2.5e-11_real64",1)
src=src.replace(
    "  real(real64) :: k0, qeq\n",
    "  real(real64) :: k0, qeq, t2_top_flux, t2_bottom_head\n"
    "  real(real64) :: t2_heads(numnod)=0.0_real64, t2_water(numnod)=0.0_real64\n"
    "  character(len=64) :: arg\n",1)

start=src.index("  call determine_initial_conductivity(k0)")
end=src.index("\ncontains\n",start)
main="""  if(command_argument_count()/=4) error stop 'usage: TOP_FLUX BOTTOM_HEAD DT_DAY BUDGET_CM'
  call get_command_argument(1,arg); read(arg,*) t2_top_flux
  call get_command_argument(2,arg); read(arg,*) t2_bottom_head
  call get_command_argument(3,arg); read(arg,*) upward_dt
  call get_command_argument(4,arg); read(arg,*) qualification_head_budget
  if(upward_dt<=0.0_real64 .or. qualification_head_budget<=0.0_real64) error stop 'invalid controls'
  call run_t2_point()
"""
src=src[:start]+main+src[end:]

insert="""\n  subroutine run_t2_point()
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    real(real64) :: clock0,clock1
    call cpu_time(clock0)
    call execute_case(5,t2_top_flux,0.0_real64,t2_bottom_head,upward_dt,.true.,.true.,output,observation)
    call cpu_time(clock1)
    write(*,'(*(g0))') 'APPROX03_T2_DISCOVERY|TOP=',t2_top_flux,'|HBOT=',t2_bottom_head,'|DT=',upward_dt, &
         '|BUDGET=',qualification_head_budget,'|SECONDS=',clock1-clock0,'|COMPLETED=',output%completed, &
         '|COMMITTED=',output%committed,'|KERNEL_STATUS=',output%kernel_status,'|SUBSTEPS=',output%accepted_substeps, &
         '|RETRIES=',output%solver_internal_retries,'|NONLINEAR=',output%solver_nonlinear_iterations, &
         '|HEADCALC=',output%solver_headcalc_calls,'|MASS_COMPLETE=',output%mass%complete,'|MASS_RESIDUAL=',output%mass%residual, &
         '|BOTTOM_FLUX=',observation%bottom_flux,'|CERT_AVAILABLE=',observation%temporal_certificate_available, &
         '|BINF=',observation%temporal_head_inf_bound,'|CH=',observation%temporal_normalized_indicator, &
         '|H1=',t2_heads(1),'|H2=',t2_heads(2),'|H3=',t2_heads(3),'|H4=',t2_heads(4), &
         '|TH1=',t2_water(1),'|TH2=',t2_water(2),'|TH3=',t2_water(3),'|TH4=',t2_water(4)
  end subroutine run_t2_point
"""
src=src.replace("\ncontains\n","\ncontains\n"+insert,1)

old_decl="""    integer :: active_physical_calls
    logical :: ok
"""
new_decl="""    integer :: active_physical_calls
    logical :: ok, snapshot_available
    class(transaction_state_t), allocatable :: snapshot
"""
if old_decl not in src: raise SystemExit("execute declaration seam missing")
src=src.replace(old_decl,new_decl,1)

old_tail="""    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()
"""
new_tail="""    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()
    t2_heads=0.0_real64; t2_water=0.0_real64
    if(output%committed) then
      call committed%snapshot(snapshot,snapshot_available)
      if(snapshot_available .and. allocated(snapshot)) then
        select type(state=>snapshot)
        type is(fmr_b110_physical_state_t)
          if(allocated(state%pressure_head) .and. allocated(state%water_content)) then
            t2_heads=state%pressure_head
            t2_water=state%water_content
          end if
        class default
          continue
        end select
      end if
    end if
"""
if old_tail not in src: raise SystemExit("execute tail seam missing")
src=src.replace(old_tail,new_tail,1)
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2)
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
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
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

tops=(0.0 1e-9 -1e-9)
bottoms=(-50 -75 -100 -150)
dts=(1e-3 5e-3 1e-2 5e-2)
budget=2.5e-11
rows=0
refined=0
for top in "${tops[@]}"; do
  for hbot in "${bottoms[@]}"; do
    for dt in "${dts[@]}"; do
      set +e
      raw="$("$BUILD/test" "$top" "$hbot" "$dt" "$budget" 2>&1)"
      rc=$?
      set -e
      printf '%s\n' "$raw"
      if [[ $rc -eq 0 ]]; then
        line="$(printf '%s\n' "$raw" | grep '^APPROX03_T2_DISCOVERY|' | tail -1 || true)"
        if [[ -n "$line" ]]; then
          rows=$((rows+1))
          substeps="$(printf '%s\n' "$line" | sed -n 's/.*|SUBSTEPS=\([^|]*\).*/\1/p')"
          committed="$(printf '%s\n' "$line" | sed -n 's/.*|COMMITTED=\([^|]*\).*/\1/p')"
          if [[ "$committed" == "T" && "$substeps" =~ ^[0-9]+$ && "$substeps" -ge 2 ]]; then
            refined=$((refined+1))
          fi
        fi
      fi
    done
  done
done
echo "APPROX03_T2_DISCOVERY_SUMMARY|ROWS=$rows|REFINED=$refined"
[[ $refined -ge 1 ]] || fail "no converged multi-substep mode5 workload"
echo "FPE_APPROX03_T2_MODE5_DISCOVERY=PASS"

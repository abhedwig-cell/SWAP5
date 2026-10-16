module mod_fmr_accepted_salt_irrigation_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t
  use mod_fmr_base_salt_temporal_policy, only: fmr_base_salt_temporal_policy_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, irrigation_state_t
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_parameters_t
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_parameters_t, &
       irrigation_management_policy_result_t
  use mod_fmr_sensor_depth_irrigation_binding, only: fmr_prepare_sensor_depth_ssdi_forcing
  use mod_fmr_scheduled_irrigation_forcing_binding, only: fmr_irrigation_forcing_binding_diagnostics_t, FMR_IRR_FORCING_BIND_OK
  use mod_fmr_scheduled_management_irrigation_application, only: fmr_irrigation_management_parameters_t, &
       fmr_irrigation_management_request_t, fmr_irrigation_management_state_t
  use mod_fmr_management_irrigation_forcing_binding, only: fmr_prepare_management_ssdi_forcing, &
       fmr_management_forcing_binding_diagnostics_t, FMR_MGMT_FORCING_BIND_OK
  implicit none
  private
  integer, parameter, public :: FMR_IRR_ACCEPTED_SALT_OK=0, FMR_IRR_ACCEPTED_SALT_INVALID=1
  type, public :: fmr_accepted_salt_irrigation_diagnostics_t
    integer :: status=FMR_IRR_ACCEPTED_SALT_INVALID
    integer(int64) :: physical_revision=-1_int64
    real(real64) :: concentration_mg_cm3=0.0_real64
    logical :: concentration_read=.false.
  end type
  public :: fmr_read_committed_irrigation_cml
  public :: fmr_run_accepted_salt_sensor_irrigation, fmr_run_accepted_salt_root_irrigation
contains
  ! PR1015 owns mass. Concentration is derived from that same committed water
  ! state, never from the caller's independent scalar or an irrigation cache.
  subroutine fmr_read_committed_irrigation_cml(physical, parameters, node, t0, concentration, revision, ok)
    type(kernel_committed_state_t), intent(in) :: physical
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    integer, intent(in) :: node
    real(real64), intent(in) :: t0
    real(real64), intent(out) :: concentration
    integer(int64), intent(out) :: revision
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: snapshot
    real(real64) :: physical_time, water
    logical :: available
    concentration=0.0_real64; revision=-1_int64; ok=.false.
    if (.not.ieee_is_finite(t0)) return
    if (parameters%macropore_active) return
    if (node<1.or.node>parameters%active_nodes) return
    if (.not.allocated(parameters%dz)) return
    if (size(parameters%dz)/=parameters%active_nodes) return
    if (.not.all(ieee_is_finite(parameters%dz))) return
    if (any(parameters%dz<=0.0_real64)) return
    call physical%current_time(physical_time,available)
    if (.not.available) return
    if (.not.ieee_is_finite(physical_time)) return
    if (abs(physical_time-t0)>64.0_real64*epsilon(t0)*max(1.0_real64,abs(t0),abs(physical_time))) return
    call physical%snapshot(snapshot,available)
    if (.not.available) return
    select type (state=>snapshot)
    class is (fmr_b110_physical_state_t)
      if (state%active_nodes/=parameters%active_nodes) return
      if (allocated(state%macropore)) return
      if (.not.allocated(state%salt).or..not.allocated(state%water_content)) return
      if (.not.state%salt%ready(state%active_nodes)) return
      if (size(state%water_content)/=state%active_nodes) return
      if (.not.all(ieee_is_finite(state%water_content))) return
      if (any(state%water_content<=0.0_real64).or.any(state%water_content>1.0_real64)) return
      water=state%water_content(node)*parameters%dz(node)
      if (.not.ieee_is_finite(water).or.water<=0.0_real64) return
      if (water<1.0_real64) then
        if (state%salt%mass_mg_cm2(node)>huge(water)*water) return
      end if
      concentration=state%salt%mass_mg_cm2(node)/water
      if (.not.ieee_is_finite(concentration)) return
      revision=physical%current_revision()
      ok=revision>=0_int64
    end select
  end subroutine

  subroutine fmr_run_accepted_salt_sensor_irrigation(column,template,parameters,base,physical,sensor,root,depth,rainfall, &
       management,request,config,policy,top,result,runtime,binding,depth_result,salt_diag,accepted)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(kernel_committed_state_t), intent(inout) :: physical
    type(scheduled_irrigation_parameters_t), intent(in) :: sensor
    type(irrigation_root_zone_parameters_t), intent(in) :: root
    type(irrigation_management_policy_parameters_t), intent(in) :: depth
    real(real64), intent(in) :: rainfall
    type(irrigation_state_t), intent(inout) :: management
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(canonical_numerical_config_t), intent(in) :: config
    type(fmr_base_salt_temporal_policy_t), intent(in) :: policy
    class(top_boundary_provider_t), target, intent(in) :: top
    type(fmr_serialized_column_result_t), intent(out) :: result
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    type(fmr_irrigation_forcing_binding_diagnostics_t), intent(out) :: binding
    type(irrigation_management_policy_result_t), intent(out) :: depth_result
    type(fmr_accepted_salt_irrigation_diagnostics_t), intent(out) :: salt_diag
    logical, intent(out) :: accepted
    type(scheduled_irrigation_request_t) :: resolved
    type(irrigation_state_t) :: candidate
    type(fmr_b110_physical_forcing_t) :: bound
    logical :: ok
    accepted=.false.; result=fmr_serialized_column_result_t(); runtime=fmr_serialized_batch_diagnostics_t()
    binding=fmr_irrigation_forcing_binding_diagnostics_t(); depth_result=irrigation_management_policy_result_t()
    salt_diag=fmr_accepted_salt_irrigation_diagnostics_t()
    if (template%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED) return
    resolved=request; resolved%solute_enabled=.true.; resolved%sensor_concentration=0.0_real64
    if (.not.management%active_event) then
      call fmr_read_committed_irrigation_cml(physical,parameters,sensor%sensor_node,request%t0, &
           resolved%sensor_concentration,salt_diag%physical_revision,ok)
      if (.not.ok) return
      salt_diag%concentration_mg_cm3=resolved%sensor_concentration; salt_diag%concentration_read=.true.
    end if
    call fmr_prepare_sensor_depth_ssdi_forcing(sensor,root,depth,rainfall,management,resolved,physical,base, &
         candidate,bound,binding,depth_result)
    if (binding%status/=FMR_IRR_FORCING_BIND_OK) return
    call execute_bound(column,template,parameters,bound,physical,config,policy,top,request%t0,request%t1, &
         result,runtime,accepted)
    if (.not.accepted) return
    management=candidate; salt_diag%status=FMR_IRR_ACCEPTED_SALT_OK
  end subroutine

  subroutine fmr_run_accepted_salt_root_irrigation(column,template,parameters,base,physical,irrigation,sensor_node, &
       management,request,config,policy,top,result,runtime,binding,salt_diag,accepted)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(kernel_committed_state_t), intent(inout) :: physical
    type(fmr_irrigation_management_parameters_t), intent(in) :: irrigation
    integer, intent(in) :: sensor_node
    type(fmr_irrigation_management_state_t), intent(inout) :: management
    type(fmr_irrigation_management_request_t), intent(in) :: request
    type(canonical_numerical_config_t), intent(in) :: config
    type(fmr_base_salt_temporal_policy_t), intent(in) :: policy
    class(top_boundary_provider_t), target, intent(in) :: top
    type(fmr_serialized_column_result_t), intent(out) :: result
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    type(fmr_management_forcing_binding_diagnostics_t), intent(out) :: binding
    type(fmr_accepted_salt_irrigation_diagnostics_t), intent(out) :: salt_diag
    logical, intent(out) :: accepted
    type(fmr_irrigation_management_request_t) :: resolved
    type(fmr_irrigation_management_state_t) :: candidate
    type(fmr_b110_physical_forcing_t) :: bound
    logical :: ok
    accepted=.false.; result=fmr_serialized_column_result_t(); runtime=fmr_serialized_batch_diagnostics_t()
    binding=fmr_management_forcing_binding_diagnostics_t(); salt_diag=fmr_accepted_salt_irrigation_diagnostics_t()
    if (template%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED) return
    resolved=request; resolved%solute_enabled=.true.; resolved%sensor_concentration=0.0_real64
    if (.not.management%event%active_event) then
      call fmr_read_committed_irrigation_cml(physical,parameters,sensor_node,request%t0, &
           resolved%sensor_concentration,salt_diag%physical_revision,ok)
      if (.not.ok) return
      salt_diag%concentration_mg_cm3=resolved%sensor_concentration; salt_diag%concentration_read=.true.
    end if
    call fmr_prepare_management_ssdi_forcing(irrigation,management,resolved,physical,base,candidate,bound,binding)
    if (binding%status/=FMR_MGMT_FORCING_BIND_OK) return
    call execute_bound(column,template,parameters,bound,physical,config,policy,top,request%t0,request%t1, &
         result,runtime,accepted)
    if (.not.accepted) return
    management=candidate; salt_diag%status=FMR_IRR_ACCEPTED_SALT_OK
  end subroutine

  subroutine execute_bound(column,template,parameters,bound,physical,config,policy,top,t0,t1,result,runtime,accepted)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: bound
    type(kernel_committed_state_t), intent(inout) :: physical
    type(canonical_numerical_config_t), intent(in) :: config
    type(fmr_base_salt_temporal_policy_t), intent(in) :: policy
    class(top_boundary_provider_t), target, intent(in) :: top
    real(real64), intent(in) :: t0,t1
    type(fmr_serialized_column_result_t), intent(out) :: result
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    logical, intent(out) :: accepted
    type(kernel_committed_state_t) :: states(1)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    integer :: dispatch
    accepted=.false.; result=fmr_serialized_column_result_t(); runtime=fmr_serialized_batch_diagnostics_t()
    if (.not.policy%valid()) return
    if (config%transaction%temporal_mode/=TX_TEMPORAL_EXTERNAL_FULL_HALF) return
    states(1)=physical
    call fmr_run_serialized_physical_multiswap([column],[template],[parameters],[bound],states,config,top,t0,t1,1, &
         results,diagnostics,aggregate,dispatch,runtime,base_salt_temporal_policy=policy)
    if (dispatch/=FMR_SERIAL_DISPATCH_OK.or..not.allocated(results)) return
    if (size(results)/=1) return
    result=results(1)
    if (.not.result%completed.or..not.result%committed.or..not.result%mass%complete) return
    physical=states(1); accepted=.true.
  end subroutine
end module

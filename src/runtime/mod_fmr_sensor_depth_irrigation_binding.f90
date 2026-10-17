module mod_fmr_sensor_depth_irrigation_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t,scheduled_irrigation_request_t,irrigation_state_t, &
       irrigation_diagnostics_t,evaluate_irrigation_sensor_trigger,IRRIGATION_OK
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_parameters_t,irrigation_root_zone_summary_t, &
       evaluate_irrigation_root_zone_summary,IRR_ROOT_ZONE_OK
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_parameters_t, &
       irrigation_management_policy_request_t,irrigation_management_policy_result_t, &
       evaluate_irrigation_management_depth,IRR_MGMT_OK,irrigation_management_policy_state_t,apply_irrigation_minimum_interval
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t,fmr_b110_physical_parameters_t
  use mod_fmr_scheduled_irrigation_forcing_binding, only: fmr_irrigation_forcing_binding_diagnostics_t, &
       fmr_prepare_sensor_dcs2_single_node_ssdi_forcing,FMR_IRR_FORCING_BIND_OK, &
       FMR_IRR_FORCING_BIND_VIEW_REJECTED,FMR_IRR_FORCING_BIND_APPLICATION_REJECTED
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t,fmr_template_t,fmr_column_diagnostics_t,fmr_aggregate_diagnostics_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t,fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap,FMR_SERIAL_DISPATCH_OK
  implicit none
  private
  public :: fmr_prepare_sensor_depth_ssdi_forcing,fmr_run_sensor_depth_ssdi_interval
contains
  subroutine fmr_prepare_sensor_depth_ssdi_forcing(sensor,root,depth,rainfall_cm,committed,request,physical,base, &
       candidate,bound,binding,depth_result,committed_policy,candidate_policy)
    type(scheduled_irrigation_parameters_t), intent(in) :: sensor
    type(irrigation_root_zone_parameters_t), intent(in) :: root
    type(irrigation_management_policy_parameters_t), intent(in) :: depth
    real(real64), intent(in) :: rainfall_cm
    type(irrigation_state_t), intent(in) :: committed
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(kernel_committed_state_t), intent(in) :: physical
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(irrigation_state_t), intent(out) :: candidate
    type(fmr_b110_physical_forcing_t), intent(out) :: bound
    type(fmr_irrigation_forcing_binding_diagnostics_t), intent(out) :: binding
    type(irrigation_management_policy_result_t), intent(out) :: depth_result
    type(irrigation_management_policy_state_t),intent(in),optional::committed_policy
    type(irrigation_management_policy_state_t),intent(out),optional::candidate_policy
    type(irrigation_management_policy_parameters_t)::interval_policy
    type(irrigation_management_policy_state_t)::pending_policy
    type(irrigation_diagnostics_t)::sensor_result
    logical::trigger
    type(process_hydraulic_view_t) :: view
    type(irrigation_root_zone_summary_t) :: summary
    type(irrigation_management_policy_request_t) :: depth_request
    type(scheduled_irrigation_parameters_t) :: selected
    integer :: status
    logical :: ok
    candidate=committed
    if(present(candidate_policy))then
      candidate_policy=irrigation_management_policy_state_t()
      if(present(committed_policy))candidate_policy=committed_policy
    end if
    bound=base
    binding=fmr_irrigation_forcing_binding_diagnostics_t()
    depth_result=irrigation_management_policy_result_t()
    if(depth%fixed_interval_enabled)then
      if(.not.present(committed_policy).or..not.present(candidate_policy))then
        binding%status=FMR_IRR_FORCING_BIND_APPLICATION_REJECTED;return
      end if
    end if
    ! An active event retains its selected rate/end; root growth or rain
    ! cannot recalculate depth during continuation.
    if (committed%active_event) then
      selected=sensor
      selected%dcs2_knot_count=2
      selected%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
      selected%dcs2_depth_cm(1:2)=1.0_real64
      selected%depth_limit_enabled=.false.
      call fmr_prepare_sensor_dcs2_single_node_ssdi_forcing(selected,committed,request,physical,base,candidate,bound,binding)
      return
    end if
    if (.not.sensor%scheduled_irrigation_enabled .or. .not.request%selection_opportunity .or. &
         .not.request%irrigation_enabled .or. .not.request%schedule_enabled .or. .not.request%crop_emerged .or. &
         .not.request%irrigation_window_open .or. request%fixed_event_already_selected) return
    call fmr_build_committed_process_hydraulic_view(physical,view,ok)
    if (.not.ok) then
      binding%status=FMR_IRR_FORCING_BIND_VIEW_REJECTED
      return
    end if
    if(depth%fixed_interval_enabled)then
      ! Source timing and DAYFIX precede depth/limit/rate. Dummy depth is used
      ! only to validate the existing sensor contract; no event is constructed.
      selected=sensor
      selected%dcs2_knot_count=2;selected%dcs2_dvs(1:2)=[0._real64,2._real64]
      selected%dcs2_depth_cm(1:2)=1._real64;selected%depth_limit_enabled=.false.
      call evaluate_irrigation_sensor_trigger(selected,request%dvs,view,sensor_result)
      if(sensor_result%status/=IRRIGATION_OK)then
        binding%status=FMR_IRR_FORCING_BIND_APPLICATION_REJECTED;return
      end if
      trigger=sensor_result%triggered
      interval_policy=depth;interval_policy%timing_criterion=sensor%timing_criterion
      call apply_irrigation_minimum_interval(interval_policy,committed_policy,trigger,pending_policy,status)
      if(status/=IRR_MGMT_OK)then
        binding%status=FMR_IRR_FORCING_BIND_APPLICATION_REJECTED;return
      end if
      if(.not.trigger)then
        candidate_policy=pending_policy;return
      end if
    end if
    depth_request%dvs=request%dvs
    depth_request%rainfall_cm=rainfall_cm
    if (depth%depth_criterion==1) then
      call evaluate_irrigation_root_zone_summary(root,view,summary,status)
      if(status/=IRR_ROOT_ZONE_OK) then
        binding%status=FMR_IRR_FORCING_BIND_APPLICATION_REJECTED
        return
      end if
      depth_request%field_capacity_deficit_cm=summary%field_capacity_deficit_cm
    end if
    call evaluate_irrigation_management_depth(depth,depth_request,depth_result,status)
    if(status/=IRR_MGMT_OK) then
      binding%status=FMR_IRR_FORCING_BIND_APPLICATION_REJECTED
      return
    end if
    if(depth_result%selected_depth_cm<=0.0_real64)then
      if(depth%fixed_interval_enabled)candidate_policy=pending_policy
      return
    end if
    selected=sensor
    selected%dcs2_knot_count=2
    selected%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
    selected%dcs2_depth_cm(1:2)=depth_result%selected_depth_cm
    selected%depth_limit_enabled=.false.
    ! Reuse sensor trigger, salinity-after-limit ordering, availability,
    ! persistent event selection and spatial forcing, with no new physics.
    call fmr_prepare_sensor_dcs2_single_node_ssdi_forcing(selected,committed,request,physical,base,candidate,bound,binding)
    if(depth%fixed_interval_enabled.and.binding%status==FMR_IRR_FORCING_BIND_OK)candidate_policy=pending_policy
  end subroutine

  subroutine fmr_run_sensor_depth_ssdi_interval(column,template,parameters,base,physical,sensor,root,depth,rainfall_cm, &
       management,request,config,top,result,runtime,binding,depth_result,accepted,policy_state)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(kernel_committed_state_t), intent(inout) :: physical
    type(scheduled_irrigation_parameters_t), intent(in) :: sensor
    type(irrigation_root_zone_parameters_t), intent(in) :: root
    type(irrigation_management_policy_parameters_t), intent(in) :: depth
    real(real64), intent(in) :: rainfall_cm
    type(irrigation_state_t), intent(inout) :: management
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(canonical_numerical_config_t), intent(in) :: config
    class(top_boundary_provider_t), target, intent(in) :: top
    type(fmr_serialized_column_result_t), intent(out) :: result
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    type(fmr_irrigation_forcing_binding_diagnostics_t), intent(out) :: binding
    type(irrigation_management_policy_result_t), intent(out) :: depth_result
    logical, intent(out) :: accepted
    type(irrigation_management_policy_state_t),intent(inout),optional::policy_state
    type(irrigation_management_policy_state_t)::next_policy
    type(irrigation_state_t) :: candidate
    type(kernel_committed_state_t) :: states(1)
    type(fmr_b110_physical_forcing_t) :: forcing(1)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    integer :: dispatch
    accepted=.false.
    result=fmr_serialized_column_result_t()
    runtime=fmr_serialized_batch_diagnostics_t()
    call fmr_prepare_sensor_depth_ssdi_forcing(sensor,root,depth,rainfall_cm,management,request,physical,base, &
         candidate,forcing(1),binding,depth_result,policy_state,next_policy)
    if(binding%status/=FMR_IRR_FORCING_BIND_OK) return
    states(1)=physical
    call fmr_run_serialized_physical_multiswap([column],[template],[parameters],forcing,states,config,top, &
         request%t0,request%t1,1,results,diagnostics,aggregate,dispatch,runtime)
    if(dispatch/=FMR_SERIAL_DISPATCH_OK) return
    if(.not.allocated(results)) return
    if(size(results)/=1) return
    result=results(1)
    if(.not.result%completed.or..not.result%committed.or..not.result%mass%complete) return
    physical=states(1)
    management=candidate
    if(present(policy_state))policy_state=next_policy
    accepted=.true.
  end subroutine
end module

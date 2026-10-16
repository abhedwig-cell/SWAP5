module mod_fmr_irrigation_allocation_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_parameters_t
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_parameters_t, irrigation_management_policy_result_t
  use mod_fmr_sensor_depth_irrigation_binding, only: fmr_run_sensor_depth_ssdi_interval, &
       fmr_prepare_sensor_depth_ssdi_forcing
  use mod_fmr_scheduled_irrigation_forcing_binding, only: fmr_irrigation_forcing_binding_diagnostics_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t
  use mod_fmr_base_salt_temporal_policy, only: fmr_base_salt_temporal_policy_t
  use mod_fmr_scheduled_management_irrigation_application, only: fmr_irrigation_management_parameters_t, &
       fmr_irrigation_management_request_t, fmr_irrigation_management_state_t
  use mod_fmr_management_irrigation_forcing_binding, only: fmr_management_forcing_binding_diagnostics_t, &
       fmr_run_management_ssdi_interval
  use mod_fmr_accepted_salt_irrigation_binding, only: fmr_run_accepted_salt_root_irrigation, fmr_run_accepted_salt_sensor_irrigation, &
       fmr_accepted_salt_irrigation_diagnostics_t
  use mod_fmr_irrigation_management_restart, only: fmr_irrigation_management_restart_record_t, &
       export_fmr_irrigation_management_restart, restore_fmr_irrigation_management_restart, FMR_IRR_MGMT_RESTART_OK
  implicit none
  private
  integer, parameter, public :: FMR_IRR_ALLOCATION_OK=0, FMR_IRR_ALLOCATION_INVALID=1
  type, public :: fmr_irrigation_allocation_t
    integer(int64) :: source_id=0_int64, revision=-1_int64
    real(real64) :: valid_t0=0.0_real64, valid_t1=0.0_real64, fraction=1.0_real64
  contains

  ! Preparation only: use the same selection, frozen receipt and physical
  ! forcing owners as the admitted standalone route. The caller owns dispatch.
  subroutine fmr_prepare_allocated_sensor_irrigation(sensor,root,depth,rainfall,physical,base,state,request,allocation, &
       candidate,bound,binding,depth_result)
    type(scheduled_irrigation_parameters_t), intent(in) :: sensor
    type(irrigation_root_zone_parameters_t), intent(in) :: root
    type(irrigation_management_policy_parameters_t), intent(in) :: depth
    real(real64), intent(in) :: rainfall
    type(kernel_committed_state_t), intent(in) :: physical
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(fmr_allocated_irrigation_state_t), intent(in) :: state
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(fmr_irrigation_allocation_t), intent(in) :: allocation
    type(fmr_allocated_irrigation_state_t), intent(out) :: candidate
    type(fmr_b110_physical_forcing_t), intent(out) :: bound
    type(fmr_irrigation_forcing_binding_diagnostics_t), intent(out) :: binding
    type(irrigation_management_policy_result_t), intent(out) :: depth_result
    type(scheduled_irrigation_request_t) :: resolved
    logical :: selecting
    candidate=state;bound=base;binding=fmr_irrigation_forcing_binding_diagnostics_t()
    depth_result=irrigation_management_policy_result_t()
    ! Invalid receipt/allocation must not look like successful zero supply.
    binding%status=1
    if (.not.receipt_matches(state)) return
    resolved=request
    selecting=sensor%scheduled_irrigation_enabled.and..not.state%management%event%active_event.and. &
      request%selection_opportunity.and.request%irrigation_enabled.and.request%schedule_enabled.and. &
      request%crop_emerged.and.request%irrigation_window_open.and..not.request%fixed_event_already_selected
    resolved%availability_scaling_enabled=.false.;resolved%availability_fraction=1.0_real64
    if(selecting)then
      if(.not.allocation%valid(request%t0))return
      resolved%availability_scaling_enabled=.true.;resolved%availability_fraction=allocation%fraction
    end if
    call fmr_prepare_sensor_depth_ssdi_forcing(sensor,root,depth,rainfall,state%management%event,resolved, &
      physical,base,candidate%management%event,bound,binding,depth_result)
    if(binding%status/=0)return
    call freeze_allocation_receipt(candidate,allocation,request%t0,selecting,binding%external_inflow_amount_cm)
  end subroutine

  pure subroutine freeze_allocation_receipt(candidate,allocation,time,selecting,amount)
    type(fmr_allocated_irrigation_state_t), intent(inout) :: candidate
    type(fmr_irrigation_allocation_t), intent(in) :: allocation
    real(real64), intent(in) :: time,amount
    logical, intent(in) :: selecting
    if (selecting.and.amount>0.0_real64) then
      candidate%receipt%present=.true.; candidate%receipt%allocation=allocation
      candidate%receipt%selection_time=time
    end if
    candidate%receipt%active_event=candidate%management%event%active_event
    candidate%receipt%event_index=candidate%management%event%active_event_index
    candidate%receipt%event_origin=candidate%management%event%active_event_origin
    candidate%receipt%event_start=candidate%management%event%active_event_start
    candidate%receipt%event_end=candidate%management%event%active_event_end
    candidate%receipt%event_rate=candidate%management%event%active_event_rate_cm_per_day
  end subroutine
    procedure :: valid => allocation_valid
  end type
  type, public :: fmr_irrigation_allocation_receipt_t
    logical :: present=.false., active_event=.false.
    type(fmr_irrigation_allocation_t) :: allocation
    real(real64) :: selection_time=0.0_real64
    integer :: event_index=0, event_origin=0
    real(real64) :: event_start=0.0_real64, event_end=0.0_real64, event_rate=0.0_real64
  end type
  type, public :: fmr_allocated_irrigation_state_t
    type(fmr_irrigation_management_state_t) :: management
    type(fmr_irrigation_allocation_receipt_t) :: receipt
  end type
  type, public :: fmr_allocated_irrigation_restart_t
    integer :: schema=0
    type(fmr_irrigation_management_restart_record_t) :: management
    type(fmr_irrigation_allocation_receipt_t) :: receipt
  end type
  public :: fmr_run_allocated_root_irrigation, fmr_run_allocated_sensor_irrigation
  public :: fmr_export_allocated_irrigation_restart, fmr_restore_allocated_irrigation_restart
  public :: fmr_prepare_allocated_sensor_irrigation
contains
  pure logical function allocation_valid(self, time)
    class(fmr_irrigation_allocation_t), intent(in) :: self
    real(real64), intent(in) :: time
    allocation_valid=.false.
    if (self%source_id<=0_int64.or.self%revision<0_int64) return
    if (.not.all(ieee_is_finite([self%valid_t0,self%valid_t1,self%fraction,time]))) return
    if (self%valid_t1<=self%valid_t0) return
    if (time<self%valid_t0.or.time>=self%valid_t1) return
    if (self%fraction<0.0_real64.or.self%fraction>1.0_real64) return
    allocation_valid=.true.
  end function

  pure logical function receipt_matches(state)
    type(fmr_allocated_irrigation_state_t), intent(in) :: state
    receipt_matches=.false.
    if (state%receipt%active_event.neqv.state%management%event%active_event) return
    if (state%receipt%present) then
      if (.not.state%receipt%allocation%valid(state%receipt%selection_time)) return
    end if
    if (state%management%event%active_event) then
      if (.not.state%receipt%present) return
      if (state%receipt%event_index/=state%management%event%active_event_index) return
      if (state%receipt%event_origin/=state%management%event%active_event_origin) return
      if (.not.all(ieee_is_finite([state%receipt%event_start,state%receipt%event_end,state%receipt%event_rate]))) return
      if (state%receipt%event_start/=state%management%event%active_event_start) return
      if (state%receipt%event_end/=state%management%event%active_event_end) return
      if (state%receipt%event_rate/=state%management%event%active_event_rate_cm_per_day) return
    end if
    receipt_matches=.true.
  end function

  subroutine fmr_run_allocated_root_irrigation(column,template,parameters,base,physical,irrigation,sensor_node, &
       state,request,allocation,config,policy,top,result,runtime,binding,accepted)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(kernel_committed_state_t), intent(inout) :: physical
    type(fmr_irrigation_management_parameters_t), intent(in) :: irrigation
    integer, intent(in) :: sensor_node
    type(fmr_allocated_irrigation_state_t), intent(inout) :: state
    type(fmr_irrigation_management_request_t), intent(in) :: request
    type(fmr_irrigation_allocation_t), intent(in) :: allocation
    type(canonical_numerical_config_t), intent(in) :: config
    type(fmr_base_salt_temporal_policy_t), intent(in) :: policy
    class(top_boundary_provider_t), target, intent(in) :: top
    type(fmr_serialized_column_result_t), intent(out) :: result
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    type(fmr_management_forcing_binding_diagnostics_t), intent(out) :: binding
    logical, intent(out) :: accepted
    type(fmr_allocated_irrigation_state_t) :: candidate
    type(fmr_irrigation_management_request_t) :: resolved
    type(fmr_accepted_salt_irrigation_diagnostics_t) :: salt_diag
    logical :: selecting
    accepted=.false.; result=fmr_serialized_column_result_t(); runtime=fmr_serialized_batch_diagnostics_t()
    binding=fmr_management_forcing_binding_diagnostics_t()
    if (.not.receipt_matches(state)) return
    candidate=state; resolved=request
    ! The allocation is resolved once, at selection. A running event uses its
    ! frozen rate/end and receipt even when external delivery changes or expires.
    selecting=.not.state%management%event%active_event.and.request%selection_opportunity.and. &
         request%irrigation_enabled.and.request%schedule_enabled.and.request%crop_emerged.and. &
         request%irrigation_window_open.and..not.request%fixed_event_already_selected
    resolved%availability_scaling_enabled=.false.
    resolved%availability_fraction=1.0_real64
    if (selecting) then
      if (.not.allocation%valid(request%t0)) return
      resolved%availability_scaling_enabled=.true.; resolved%availability_fraction=allocation%fraction
    end if
    if (template%solute_state_layout_id==FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED) then
      call fmr_run_accepted_salt_root_irrigation(column,template,parameters,base,physical,irrigation,sensor_node, &
           candidate%management,resolved,config,policy,top,result,runtime,binding,salt_diag,accepted)
    else
      call fmr_run_management_ssdi_interval(column,template,parameters,base,physical,irrigation, &
           candidate%management,resolved,config,top,result,runtime,binding,accepted)
    end if
    if (.not.accepted) return
    call freeze_allocation_receipt(candidate,allocation,request%t0,selecting,binding%external_inflow_amount_cm)
    state=candidate
  end subroutine

  subroutine fmr_run_allocated_sensor_irrigation(column,template,parameters,base,physical,sensor,root,depth,rainfall, &
       state,request,allocation,config,policy,top,result,runtime,binding,accepted)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(kernel_committed_state_t), intent(inout) :: physical
    type(scheduled_irrigation_parameters_t), intent(in) :: sensor
    type(irrigation_root_zone_parameters_t), intent(in) :: root
    type(irrigation_management_policy_parameters_t), intent(in) :: depth
    real(real64), intent(in) :: rainfall
    type(fmr_allocated_irrigation_state_t), intent(inout) :: state
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(fmr_irrigation_allocation_t), intent(in) :: allocation
    type(canonical_numerical_config_t), intent(in) :: config
    type(fmr_base_salt_temporal_policy_t), intent(in) :: policy
    class(top_boundary_provider_t), target, intent(in) :: top
    type(fmr_serialized_column_result_t), intent(out) :: result
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    type(fmr_irrigation_forcing_binding_diagnostics_t), intent(out) :: binding
    logical, intent(out) :: accepted
    type(fmr_allocated_irrigation_state_t) :: candidate
    type(scheduled_irrigation_request_t) :: resolved
    type(fmr_accepted_salt_irrigation_diagnostics_t) :: salt_diag
    logical :: selecting
    type(irrigation_management_policy_result_t) :: depth_result
    accepted=.false.; result=fmr_serialized_column_result_t(); runtime=fmr_serialized_batch_diagnostics_t()
    binding=fmr_irrigation_forcing_binding_diagnostics_t()
    if (.not.receipt_matches(state)) return
    candidate=state; resolved=request
    ! The allocation is resolved once, at selection. A running event uses its
    ! frozen rate/end and receipt even when external delivery changes or expires.
    selecting=sensor%scheduled_irrigation_enabled.and..not.state%management%event%active_event.and.request%selection_opportunity.and. &
         request%irrigation_enabled.and.request%schedule_enabled.and.request%crop_emerged.and. &
         request%irrigation_window_open.and..not.request%fixed_event_already_selected
    resolved%availability_scaling_enabled=.false.
    resolved%availability_fraction=1.0_real64
    if (selecting) then
      if (.not.allocation%valid(request%t0)) return
      resolved%availability_scaling_enabled=.true.; resolved%availability_fraction=allocation%fraction
    end if
    if (template%solute_state_layout_id==FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED) then
      call fmr_run_accepted_salt_sensor_irrigation(column,template,parameters,base,physical,sensor,root,depth,rainfall, &
           candidate%management%event,resolved,config,policy,top,result,runtime,binding,depth_result,salt_diag,accepted)
    else
      call fmr_run_sensor_depth_ssdi_interval(column,template,parameters,base,physical,sensor,root,depth,rainfall, &
           candidate%management%event,resolved,config,top,result,runtime,binding,depth_result,accepted)
    end if
    if (.not.accepted) return
    call freeze_allocation_receipt(candidate,allocation,request%t0,selecting,binding%external_inflow_amount_cm)
    state=candidate
  end subroutine

  pure subroutine fmr_export_allocated_irrigation_restart(state,record,status)
    type(fmr_allocated_irrigation_state_t), intent(in) :: state
    type(fmr_allocated_irrigation_restart_t), intent(out) :: record
    integer, intent(out) :: status
    integer :: management_status
    record=fmr_allocated_irrigation_restart_t(); status=FMR_IRR_ALLOCATION_INVALID
    if (.not.receipt_matches(state)) return
    call export_fmr_irrigation_management_restart(state%management,record%management,management_status)
    if (management_status/=FMR_IRR_MGMT_RESTART_OK) return
    record%schema=1; record%receipt=state%receipt; status=FMR_IRR_ALLOCATION_OK
  end subroutine

  pure subroutine fmr_restore_allocated_irrigation_restart(record,state,status)
    type(fmr_allocated_irrigation_restart_t), intent(in) :: record
    type(fmr_allocated_irrigation_state_t), intent(inout) :: state
    integer, intent(out) :: status
    type(fmr_allocated_irrigation_state_t) :: candidate
    integer :: management_status
    status=FMR_IRR_ALLOCATION_INVALID
    if (record%schema/=1) return
    call restore_fmr_irrigation_management_restart(record%management,candidate%management,management_status)
    if (management_status/=FMR_IRR_MGMT_RESTART_OK) return
    candidate%receipt=record%receipt
    if (.not.receipt_matches(candidate)) return
    state=candidate; status=FMR_IRR_ALLOCATION_OK
  end subroutine
end module

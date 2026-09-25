! Candidate scheduled SSDI composition; no commit or restart ownership.
module mod_ppa_irrigation_source_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI, scheduled_irrigation_parameters_t, &
       scheduled_irrigation_request_t, irrigation_state_t, evaluate_scheduled_irrigation_interval
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_dcs1_composition, only: evaluate_profile_scheduled_irrigation
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t,ppa_irrigation_event_state_t, &
       fmr_serialized_reference_backend_t,fmr_b110_physical_parameters_t
  use mod_kernel_transactions, only: kernel_committed_state_t,kernel_checkpoint_t,kernel_candidate_state_t, &
       kernel_result_t,kernel_diagnostics_t,KERNEL_STATUS_NOT_ADMITTED
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_runtime_core, only: fmr_template_t,fmr_logical_column_t
  implicit none
  private
  public :: bind_ppa_irrigation_source
  public :: evaluate_ppa_irrigation_source
  public :: evaluate_ppa_profile_irrigation_source
  public :: evaluate_ppa_committed_irrigation_source
  public :: evaluate_ppa_committed_profile_irrigation_source
  public :: run_ppa_pending_irrigation_source_trial
  public :: run_ppa_profile_irrigation_source_trial
contains
  subroutine run_ppa_pending_irrigation_source_trial(backend,column,template,physical_parameters,irrigation_parameters, &
       committed,previous,numerical,t0,t1,checkpoint,result,candidate,diagnostics,irrigation_diagnostics,selection_request)
    use mod_irrigation_process, only: IRRIGATION_EVENT_SCHEDULED,IRRIGATION_INVALID_INTERVAL
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(fmr_b110_physical_parameters_t),intent(in)::physical_parameters
    type(scheduled_irrigation_parameters_t),intent(in)::irrigation_parameters
    type(kernel_committed_state_t),intent(in)::committed
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    type(canonical_numerical_config_t),intent(in)::numerical
    real(real64),intent(in)::t0,t1
    type(kernel_checkpoint_t),intent(in)::checkpoint
    type(kernel_result_t),intent(out)::result
    type(kernel_candidate_state_t),intent(out)::candidate
    type(kernel_diagnostics_t),intent(out)::diagnostics
    type(irrigation_diagnostics_t),intent(out)::irrigation_diagnostics
    type(scheduled_irrigation_request_t),intent(in),optional::selection_request
    type(scheduled_irrigation_request_t)::request
    type(irrigation_state_t)::proposed_event
    type(irrigation_flux_result_t)::flux
    type(fmr_b110_physical_forcing_t),allocatable::forcing
    logical::ok
    result=kernel_result_t()
    result%status=KERNEL_STATUS_NOT_ADMITTED
    candidate=kernel_candidate_state_t()
    diagnostics=kernel_diagnostics_t()
    diagnostics%admission_rejections=1
    irrigation_diagnostics=irrigation_diagnostics_t()
    irrigation_diagnostics%status=IRRIGATION_INVALID_INTERVAL
    if(.not.all(ieee_is_finite([t0,t1]))) return
    request%t0=t0; request%t1=t1
    if(present(selection_request)) then
      irrigation_diagnostics=irrigation_diagnostics_t()
      irrigation_diagnostics%status=IRRIGATION_INVALID_INTERVAL
      if(.not.all(ieee_is_finite([selection_request%t0,selection_request%t1]))) return
      if(selection_request%t0/=t0.or.selection_request%t1/=t1) return
      request=selection_request
    end if
    ! Default: continue/finish a saved gift or map inactivity to zero source.
    ! A supplied selection request still creates only a kernel-owned trial.
    call evaluate_ppa_committed_irrigation_source(irrigation_parameters,committed,template,request,previous, &
         proposed_event,flux,irrigation_diagnostics,forcing,ok)
    if(.not.ok) return
    call run_prepared_irrigation_source_trial(backend,column,template,physical_parameters,irrigation_parameters, &
         committed,forcing,numerical,t0,t1,checkpoint,proposed_event,flux,result,candidate,diagnostics)
  end subroutine run_ppa_pending_irrigation_source_trial

  subroutine run_ppa_profile_irrigation_source_trial(backend,column,template,physical_parameters,irrigation_parameters, &
       committed,previous,numerical,request,noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis, &
       checkpoint,result,candidate,diagnostics,irrigation_diagnostics)
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(fmr_b110_physical_parameters_t),intent(in)::physical_parameters
    type(scheduled_irrigation_parameters_t),intent(in)::irrigation_parameters
    type(kernel_committed_state_t),intent(in)::committed
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    type(canonical_numerical_config_t),intent(in)::numerical
    type(scheduled_irrigation_request_t),intent(in)::request
    integer,intent(in)::noddrz,layer(:)
    real(real64),intent(in)::dz(:),ztopcp(:),rd,wclos(:),wcmes(:),wchis(:)
    type(kernel_checkpoint_t),intent(in)::checkpoint
    type(kernel_result_t),intent(out)::result
    type(kernel_candidate_state_t),intent(out)::candidate
    type(kernel_diagnostics_t),intent(out)::diagnostics
    type(irrigation_diagnostics_t),intent(out)::irrigation_diagnostics
    type(irrigation_state_t)::proposed_event
    type(irrigation_flux_result_t)::flux
    type(fmr_b110_physical_forcing_t),allocatable::forcing
    logical::ok
    result=kernel_result_t(); result%status=KERNEL_STATUS_NOT_ADMITTED
    candidate=kernel_candidate_state_t()
    diagnostics=kernel_diagnostics_t(); diagnostics%admission_rejections=1
    call evaluate_ppa_committed_profile_irrigation_source(irrigation_parameters,committed,template,request, &
         noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis,previous,proposed_event,flux,irrigation_diagnostics,forcing,ok)
    if(.not.ok) return
    call run_prepared_irrigation_source_trial(backend,column,template,physical_parameters,irrigation_parameters, &
         committed,forcing,numerical,request%t0,request%t1,checkpoint,proposed_event,flux,result,candidate,diagnostics)
  end subroutine run_ppa_profile_irrigation_source_trial

  subroutine run_prepared_irrigation_source_trial(backend,column,template,physical_parameters,irrigation_parameters, &
       committed,forcing,numerical,t0,t1,checkpoint,event,flux,result,candidate,diagnostics)
    use mod_irrigation_process, only: IRRIGATION_EVENT_SCHEDULED
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(fmr_b110_physical_parameters_t),intent(in)::physical_parameters
    type(scheduled_irrigation_parameters_t),intent(in)::irrigation_parameters
    type(kernel_committed_state_t),intent(in)::committed
    type(fmr_b110_physical_forcing_t),intent(in)::forcing
    type(canonical_numerical_config_t),intent(in)::numerical
    real(real64),intent(in)::t0,t1
    type(kernel_checkpoint_t),intent(in)::checkpoint
    type(irrigation_state_t),intent(in)::event
    type(irrigation_flux_result_t),intent(in)::flux
    type(kernel_result_t),intent(out)::result
    type(kernel_candidate_state_t),intent(out)::candidate
    type(kernel_diagnostics_t),intent(out)::diagnostics
    type(irrigation_state_t)::proposed_event
    proposed_event=event
    if(flux%event_started) then
      ! The process candidate may already be cleared at t1. Reconstruct the
      ! selected start event from its checked flux for trial-local injection.
      proposed_event%active_event=.true.
      proposed_event%active_event_origin=IRRIGATION_EVENT_SCHEDULED
      proposed_event%active_event_index=0
      proposed_event%active_event_start=t0
      proposed_event%active_event_end=t0+flux%event_duration
      proposed_event%active_event_rate=flux%subsurface_source(irrigation_parameters%single_ssdi_node)
      call backend%run_pending_irrigation_trial(column,template,physical_parameters,committed,forcing,numerical, &
           irrigation_parameters%single_ssdi_node,t0,t1,checkpoint,result,candidate,diagnostics,proposed_event)
    else
      call backend%run_pending_irrigation_trial(column,template,physical_parameters,committed,forcing,numerical, &
           irrigation_parameters%single_ssdi_node,t0,t1,checkpoint,result,candidate,diagnostics)
    end if
  end subroutine run_prepared_irrigation_source_trial

  subroutine evaluate_ppa_committed_irrigation_source(parameters,committed,template,request,previous, &
       candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t),intent(in)::parameters
    type(kernel_committed_state_t),intent(in)::committed
    type(fmr_template_t),intent(in)::template
    type(scheduled_irrigation_request_t),intent(in)::request
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(fmr_b110_physical_forcing_t),allocatable,intent(out)::forcing
    logical,intent(out)::ok
    type(irrigation_state_t)::base
    type(process_hydraulic_view_t)::hydraulic
    flux=irrigation_flux_result_t()
    call snapshot_irrigation_source(parameters,committed,template,request,base,hydraulic,diagnostics,ok)
    candidate=base
    if(.not.ok) return
    call evaluate_ppa_irrigation_source(parameters,base,request,hydraulic,previous, &
         candidate,flux,diagnostics,forcing,ok)
  end subroutine evaluate_ppa_committed_irrigation_source

  subroutine evaluate_ppa_committed_profile_irrigation_source(parameters,committed,template,request, &
       noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis,previous,candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t),intent(in)::parameters
    type(kernel_committed_state_t),intent(in)::committed
    type(fmr_template_t),intent(in)::template
    type(scheduled_irrigation_request_t),intent(in)::request
    integer,intent(in)::noddrz,layer(:)
    real(real64),intent(in)::dz(:),ztopcp(:),rd,wclos(:),wcmes(:),wchis(:)
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(fmr_b110_physical_forcing_t),allocatable,intent(out)::forcing
    logical,intent(out)::ok
    type(irrigation_state_t)::base
    type(process_hydraulic_view_t)::hydraulic
    flux=irrigation_flux_result_t()
    call snapshot_irrigation_source(parameters,committed,template,request,base,hydraulic,diagnostics,ok)
    candidate=base
    if(.not.ok) return
    call evaluate_ppa_profile_irrigation_source(parameters,base,request,hydraulic, &
         noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis,previous,candidate,flux,diagnostics,forcing,ok)
  end subroutine evaluate_ppa_committed_profile_irrigation_source

  subroutine snapshot_irrigation_source(parameters,committed,template,request,candidate,hydraulic,diagnostics,ok)
    use mod_irrigation_process, only: IRRIGATION_INVALID_STATE,IRRIGATION_INVALID_INTERVAL, &
         IRRIGATION_INVALID_PARAMETERS
    type(scheduled_irrigation_parameters_t),intent(in)::parameters
    type(kernel_committed_state_t),intent(in)::committed
    type(fmr_template_t),intent(in)::template
    type(scheduled_irrigation_request_t),intent(in)::request
    type(irrigation_state_t),intent(out)::candidate
    type(process_hydraulic_view_t),intent(out)::hydraulic
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    logical,intent(out)::ok
    class(transaction_state_t),allocatable::snapshot
    real(real64)::boundary
    logical::available
    ok=.false.
    candidate=irrigation_state_t()
    diagnostics=irrigation_diagnostics_t()
    diagnostics%status=IRRIGATION_INVALID_STATE
    call committed%current_time(boundary,available)
    if(.not.available) return
    call committed%snapshot(snapshot,available)
    if(.not.available) return
    select type(snapshot)
    type is(ppa_irrigation_event_state_t)
      if(.not.snapshot%matches_candidate(template,boundary)) return
      candidate=snapshot%irrigation
      diagnostics%status=IRRIGATION_INVALID_INTERVAL
      if(.not.ieee_is_finite(request%t0)) return
      if(request%t0/=boundary) return
      diagnostics%status=IRRIGATION_INVALID_PARAMETERS
      if(parameters%active_nodes/=snapshot%active_nodes) return
      hydraulic%active_nodes=snapshot%active_nodes
      hydraulic%pressure_head=snapshot%pressure_head
      hydraulic%water_content=snapshot%water_content
      ! Detached outputs only: source evaluation never advances committed time
      ! or publishes the event candidate, even on successful evaluation.
      diagnostics%status=IRRIGATION_OK
      ok=.true.
    class default
      return
    end select
  end subroutine snapshot_irrigation_source

  subroutine evaluate_ppa_profile_irrigation_source(parameters,base,request,hydraulic, &
       noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis,previous,candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    type(irrigation_state_t), intent(in) :: base
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(process_hydraulic_view_t), intent(in) :: hydraulic
    integer, intent(in) :: noddrz,layer(:)
    real(real64), intent(in) :: dz(:),ztopcp(:),rd,wclos(:),wcmes(:),wchis(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: previous
    type(irrigation_state_t), intent(out) :: candidate
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_diagnostics_t), intent(out) :: diagnostics
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcing
    logical, intent(out) :: ok
    type(irrigation_state_t) :: proposed
    type(irrigation_flux_result_t) :: proposed_flux
    candidate=base
    flux=irrigation_flux_result_t()
    ok=.false.
    call evaluate_profile_scheduled_irrigation(parameters,base,request,hydraulic, &
         noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis,proposed,proposed_flux,diagnostics)
    if(diagnostics%status/=IRRIGATION_OK) return
    call bind_ppa_irrigation_source(previous,proposed_flux,diagnostics,request%t0,forcing,ok)
    if(.not.ok) return
    candidate=proposed
    flux=proposed_flux
  end subroutine

  subroutine evaluate_ppa_irrigation_source(parameters,base,request,hydraulic,previous, &
       candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    type(irrigation_state_t), intent(in) :: base
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(process_hydraulic_view_t), intent(in) :: hydraulic
    type(fmr_b110_physical_forcing_t), intent(in) :: previous
    type(irrigation_state_t), intent(out) :: candidate
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_diagnostics_t), intent(out) :: diagnostics
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcing
    logical, intent(out) :: ok
    type(irrigation_state_t) :: proposed
    type(irrigation_flux_result_t) :: proposed_flux
    ! All outputs remain tentative. In particular ok is NOT hydraulic acceptance.
    ! On failure preserve the base event and expose no actionable source/flux.
    candidate=base
    flux=irrigation_flux_result_t()
    ok=.false.
    call evaluate_scheduled_irrigation_interval(parameters,base,request,hydraulic, &
         proposed,proposed_flux,diagnostics)
    if(diagnostics%status/=IRRIGATION_OK) return
    call bind_ppa_irrigation_source(previous,proposed_flux,diagnostics,request%t0,forcing,ok)
    if(.not.ok) return
    candidate=proposed
    flux=proposed_flux
  end subroutine

  subroutine bind_ppa_irrigation_source(previous,flux,diagnostics,t0,forcing,ok)
    type(fmr_b110_physical_forcing_t), intent(in) :: previous
    type(irrigation_flux_result_t), intent(in) :: flux
    type(irrigation_diagnostics_t), intent(in) :: diagnostics
    real(real64), intent(in) :: t0
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcing
    logical, intent(out) :: ok
    real(real64), allocatable :: source(:)
    logical :: marked
    integer :: n
    ok=.false.
    if(diagnostics%status/=IRRIGATION_OK.or.diagnostics%split_required) return
    if(.not.ieee_is_finite(t0)) return
    ! This route binds water-only SSDI. Do not silently discard a surface
    ! delivery or solute concentration carried by a broader process result.
    if(.not.ieee_is_finite(flux%surface_gross_rate)) return
    if(.not.ieee_is_finite(flux%concentration)) return
    if(flux%surface_gross_rate/=0.0_real64.or.flux%concentration/=0.0_real64) return
    if(.not.allocated(previous%subsurface_irrigation_source)) return
    n=size(previous%subsurface_irrigation_source)
    if(n<1) return
    if(.not.all(ieee_is_finite(previous%subsurface_irrigation_source))) return
    if(any(previous%subsurface_irrigation_source<0.0_real64)) return
    marked=.false.
    if(previous%temporal_forcing_event) then
      if(.not.ieee_is_finite(previous%temporal_forcing_event_time)) return
      if(previous%temporal_forcing_event_time>t0) return
      marked=previous%temporal_forcing_event_time==t0
    end if
    allocate(source(n))
    source=0.0_real64
    if(flux%applied) then
      if(flux%application_type/=IRRIGATION_APPLICATION_SSDI) return
      if(.not.allocated(flux%subsurface_source)) return
      if(size(flux%subsurface_source)/=n) return
      if(.not.all(ieee_is_finite(flux%subsurface_source))) return
      if(any(flux%subsurface_source<0.0_real64)) return
      source=flux%subsurface_source
    else
      ! Inactive process output must not conceal a nonzero delivery.
      if(allocated(flux%subsurface_source)) then
        if(size(flux%subsurface_source)/=n) return
        if(.not.all(ieee_is_finite(flux%subsurface_source))) return
        if(any(flux%subsurface_source/=0.0_real64)) return
      end if
    end if
    marked=marked.or.any(source/=previous%subsurface_irrigation_source)
    allocate(forcing,source=previous)
    forcing%subsurface_irrigation_source=source
    forcing%temporal_forcing_event=marked
    forcing%temporal_forcing_event_time=0.0_real64
    if(marked) forcing%temporal_forcing_event_time=t0
    ok=.true.
  end subroutine
end module

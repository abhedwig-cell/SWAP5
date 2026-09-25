! Candidate scheduled SSDI composition; no commit or restart ownership.
module mod_ppa_irrigation_source_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI, scheduled_irrigation_parameters_t, &
       scheduled_irrigation_request_t, irrigation_state_t, evaluate_scheduled_irrigation_interval
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_dcs1_composition, only: evaluate_profile_scheduled_irrigation
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t,ppa_irrigation_event_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_runtime_core, only: fmr_template_t
  implicit none
  private
  public :: bind_ppa_irrigation_source
  public :: evaluate_ppa_irrigation_source
  public :: evaluate_ppa_profile_irrigation_source
  public :: evaluate_ppa_committed_irrigation_source
contains
  subroutine evaluate_ppa_committed_irrigation_source(parameters,committed,template,request,previous, &
       candidate,flux,diagnostics,forcing,ok)
    use mod_irrigation_process, only: IRRIGATION_INVALID_STATE,IRRIGATION_INVALID_INTERVAL, &
         IRRIGATION_INVALID_PARAMETERS
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
    class(transaction_state_t),allocatable::snapshot
    type(process_hydraulic_view_t)::hydraulic
    real(real64)::boundary
    logical::available
    ok=.false.
    candidate=irrigation_state_t()
    flux=irrigation_flux_result_t()
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
      call evaluate_ppa_irrigation_source(parameters,snapshot%irrigation,request,hydraulic,previous, &
           candidate,flux,diagnostics,forcing,ok)
    class default
      return
    end select
  end subroutine evaluate_ppa_committed_irrigation_source

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

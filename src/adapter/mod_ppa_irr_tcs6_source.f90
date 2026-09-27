! Detached weekly process + water-only source proposal; no owner publication.
module mod_ppa_irr_tcs6_source
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use mod_irrigation_process
  use mod_ppa_irr_tcs6_daily, only: evaluate_tcs6_daily_proposal
  use mod_ppa_irrigation_source_binding, only: bind_ppa_irrigation_source
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private
  public :: evaluate_tcs6_source
  type,public :: ppa_tcs6_daily_input_t
    logical :: daily_invocation=.false.
    integer(int64) :: ordinal=0_int64
    real(real64) :: deficit_cm=0.0_real64,threshold_mm=0.0_real64
  end type
contains
  subroutine evaluate_tcs6_source(parameters,base,request,weekly,input,previous, &
       proposed_weekly,candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t),intent(in)::parameters
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::request
    type(ppa_weekly_identity_t),intent(in)::weekly
    type(ppa_tcs6_daily_input_t),intent(in)::input
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    type(ppa_weekly_identity_t),intent(out)::proposed_weekly
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(fmr_b110_physical_forcing_t),allocatable,intent(out)::forcing
    logical,intent(out)::ok
    type(ppa_weekly_identity_t)::next_weekly
    type(irrigation_state_t)::next_event
    type(irrigation_flux_result_t)::next_flux
    proposed_weekly=weekly; candidate=base; flux=irrigation_flux_result_t(); ok=.false.
    call evaluate_tcs6_daily_proposal(parameters,base,request,weekly,input%daily_invocation,input%ordinal, &
         input%deficit_cm,input%threshold_mm,next_weekly,next_event,next_flux,diagnostics)
    if(diagnostics%status/=IRRIGATION_OK) return
    call bind_ppa_irrigation_source(previous,next_flux,diagnostics,request%t0,forcing,ok)
    if(.not.ok) return
    proposed_weekly=next_weekly; candidate=next_event; flux=next_flux
  end subroutine
end module

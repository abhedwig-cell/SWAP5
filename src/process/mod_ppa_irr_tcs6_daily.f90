module mod_ppa_irr_tcs6_daily
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use mod_irrigation_process
  use mod_ppa_irr_weekly_identity
  use mod_ppa_irr_tcs6_composition, only: evaluate_tcs6_scheduled
  implicit none
  private
  public :: evaluate_tcs6_daily_proposal
contains
  pure subroutine evaluate_tcs6_daily_proposal(p,base,request,weekly,daily,ordinal,deficit,threshold, &
       proposed_weekly,candidate,flux,diagnostics)
    type(scheduled_irrigation_parameters_t),intent(in)::p
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::request
    type(ppa_weekly_identity_t),intent(in)::weekly
    logical,intent(in)::daily
    integer(int64),intent(in)::ordinal
    real(real64),intent(in)::deficit,threshold
    type(ppa_weekly_identity_t),intent(out)::proposed_weekly
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(ppa_weekly_identity_t)::proposed
    logical::evaluate_daily,ok
    integer::next_day
    proposed_weekly=weekly; candidate=base; flux=irrigation_flux_result_t()
    diagnostics=irrigation_diagnostics_t(); diagnostics%status=IRRIGATION_INVALID_PARAMETERS
    call prepare_weekly_day(weekly,daily,ordinal,proposed,evaluate_daily,ok)
    if(.not.ok) return
    call evaluate_tcs6_scheduled(p,base,request,weekly%dayfix,evaluate_daily,deficit,threshold, &
         next_day,candidate,flux,diagnostics)
    if(diagnostics%status/=IRRIGATION_OK) return
    proposed%dayfix=next_day
    proposed_weekly=proposed
  end subroutine
end module

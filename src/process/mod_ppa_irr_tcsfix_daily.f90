module mod_ppa_irr_tcsfix_daily
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use mod_irrigation_process
  use mod_ppa_irr_tcsfix_identity
  use mod_ppa_irr_tcsfix_composition, only: evaluate_tcsfix_scheduled
  implicit none
  private
  public :: evaluate_tcsfix_daily_proposal
contains
  pure subroutine evaluate_tcsfix_daily_proposal(p,base,r,identity,daily,ordinal,knots,values,count, &
       iptra,iqdry,iqsol,awlh,awmh,awah,proposed_identity,candidate,flux,diagnostics)
    type(scheduled_irrigation_parameters_t),intent(in)::p
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::r
    type(ppa_tcsfix_identity_t),intent(in)::identity
    logical,intent(in)::daily
    integer(int64),intent(in)::ordinal
    real(real64),intent(in)::knots(7),values(7),iptra,iqdry,iqsol,awlh,awmh,awah
    integer,intent(in)::count
    type(ppa_tcsfix_identity_t),intent(out)::proposed_identity
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(ppa_tcsfix_identity_t)::proposed
    logical::evaluate_daily,ok
    integer::next_day
    proposed_identity=identity; candidate=base; flux=irrigation_flux_result_t()
    diagnostics=irrigation_diagnostics_t(); diagnostics%status=IRRIGATION_INVALID_PARAMETERS
    call prepare_tcsfix_day(identity,daily,ordinal,proposed,evaluate_daily,ok)
    if(.not.ok) return
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,count,iptra,iqdry,iqsol,awlh,awmh,awah, &
         evaluate_daily,identity%dayfix,identity%interval_days,next_day,candidate,flux,diagnostics)
    if(diagnostics%status/=IRRIGATION_OK) return
    proposed%dayfix=next_day; proposed_identity=proposed
  end subroutine
end module

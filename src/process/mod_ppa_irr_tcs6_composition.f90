module mod_ppa_irr_tcs6_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_tcs6_weekly_timing, only: evaluate_tcs6_weekly_timing,IRR_TCS6_OK
  implicit none
  private
  public :: evaluate_tcs6_scheduled
contains
  pure subroutine evaluate_tcs6_scheduled(p,base,request,dayfix,daily_invocation,deficit,threshold, &
       proposed_dayfix,candidate,flux,diagnostics)
    type(scheduled_irrigation_parameters_t),intent(in)::p
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::request
    integer,intent(in)::dayfix
    logical,intent(in)::daily_invocation
    real(real64),intent(in)::deficit,threshold
    integer,intent(out)::proposed_dayfix
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(irrigation_timing_selection_t)::timing
    type(process_hydraulic_view_t)::unused
    integer::next_day,code
    candidate=base; flux=irrigation_flux_result_t(); diagnostics=irrigation_diagnostics_t()
    diagnostics%status=IRRIGATION_INVALID_PARAMETERS; proposed_dayfix=dayfix; next_day=dayfix
    if(p%timing_criterion/=6.or.p%depth_criterion/=IRRIGATION_DEPTH_DCS2_FIXED) return
    timing%criterion=6; timing%valid=.true.; timing%triggered=.false.; timing%threshold=0.0_real64
    if(.not.base%active_event.and.p%scheduled_irrigation_enabled.and.request%selection_opportunity.and. &
         request%irrigation_enabled.and.request%schedule_enabled.and.request%crop_emerged.and. &
         request%irrigation_window_open.and..not.request%fixed_event_already_selected.and.daily_invocation) then
      call evaluate_tcs6_weekly_timing(dayfix,deficit,threshold,next_day,timing%triggered,code)
      if(code/=IRR_TCS6_OK) return
      timing%threshold=threshold
    end if
    call evaluate_scheduled_irrigation_interval(p,base,request,unused,candidate,flux,diagnostics,timing)
    ! Output is a proposal, never committed calendar state. Failed/split trials
    ! retain the input counter so callers cannot accidentally count retries.
    if(diagnostics%status==IRRIGATION_OK) proposed_dayfix=next_day
  end subroutine
end module

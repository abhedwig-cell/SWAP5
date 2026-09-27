module mod_ppa_irr_tcsfix_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_tcs1_4_timing, only: evaluate_tcs1_4_timing,IRR_TCS1_4_OK,IRR_TCS1_4_MAX_KNOTS
  use mod_ppa_irr_tcsfix_filter, only: evaluate_tcsfix_filter
  implicit none
  private
  public :: evaluate_tcsfix_scheduled
contains
  pure subroutine evaluate_tcsfix_scheduled(p,base,r,knots,values,count,iptra,iqdry,iqsol,awlh,awmh,awah, &
       daily_invocation,dayfix,interval_days,proposed_dayfix,candidate,flux,diagnostics)
    type(scheduled_irrigation_parameters_t),intent(in)::p
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::r
    real(real64),intent(in)::knots(IRR_TCS1_4_MAX_KNOTS),values(IRR_TCS1_4_MAX_KNOTS)
    integer,intent(in)::count,dayfix,interval_days
    real(real64),intent(in)::iptra,iqdry,iqsol,awlh,awmh,awah
    logical,intent(in)::daily_invocation
    integer,intent(out)::proposed_dayfix
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(irrigation_timing_selection_t)::timing
    type(process_hydraulic_view_t)::unused
    real(real64)::ratio,depletion
    integer::code,next_day
    logical::allowed
    candidate=base; flux=irrigation_flux_result_t(); diagnostics=irrigation_diagnostics_t()
    diagnostics%status=IRRIGATION_INVALID_PARAMETERS
    proposed_dayfix=dayfix; next_day=dayfix
    if(dayfix<0.or.dayfix>366.or.interval_days<1.or.interval_days>366) return
    if(p%timing_criterion<1.or.p%timing_criterion>4.or.p%depth_criterion/=IRRIGATION_DEPTH_DCS2_FIXED) return
    timing%criterion=p%timing_criterion; timing%valid=.true.; timing%triggered=.false.
    if(daily_invocation.and..not.base%active_event.and.p%scheduled_irrigation_enabled.and. &
         r%selection_opportunity.and.r%irrigation_enabled.and.r%schedule_enabled.and.r%crop_emerged.and. &
         r%irrigation_window_open.and..not.r%fixed_event_already_selected) then
      call evaluate_tcs1_4_timing(p%timing_criterion,r%dvs,knots,values,count, &
           iptra,iqdry,iqsol,awlh,awmh,awah,timing%triggered,timing%threshold,ratio,depletion,code)
      if(code/=IRR_TCS1_4_OK) return
      call evaluate_tcsfix_filter(dayfix,interval_days,timing%triggered,next_day,allowed,code)
      timing%triggered=allowed
    end if
    call evaluate_scheduled_irrigation_interval(p,base,r,unused,candidate,flux,diagnostics,timing)
    if(diagnostics%status==IRRIGATION_OK) proposed_dayfix=next_day
  end subroutine
end module

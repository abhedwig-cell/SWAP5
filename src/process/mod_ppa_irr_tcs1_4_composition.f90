module mod_ppa_irr_tcs1_4_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_tcs1_4_timing, only: evaluate_tcs1_4_timing,IRR_TCS1_4_OK,IRR_TCS1_4_MAX_KNOTS
  implicit none
  private
  public :: evaluate_tcs1_4_scheduled
contains
  pure subroutine evaluate_tcs1_4_scheduled(parameters,base,request,knots,values,count, &
       iptra,iqdry,iqsol,awlh,awmh,awah,candidate,flux,diagnostics)
    type(scheduled_irrigation_parameters_t),intent(in)::parameters
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::request
    real(real64),intent(in)::knots(IRR_TCS1_4_MAX_KNOTS),values(IRR_TCS1_4_MAX_KNOTS)
    integer,intent(in)::count
    real(real64),intent(in)::iptra,iqdry,iqsol,awlh,awmh,awah
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(irrigation_timing_selection_t)::timing
    type(process_hydraulic_view_t)::unused
    real(real64)::ratio,depletion
    integer::code
    candidate=base; flux=irrigation_flux_result_t(); diagnostics=irrigation_diagnostics_t()
    if(parameters%timing_criterion<1.or.parameters%timing_criterion>4.or. &
         parameters%depth_criterion/=IRRIGATION_DEPTH_DCS2_FIXED) then
      diagnostics%status=IRRIGATION_INVALID_PARAMETERS
      return
    end if
    timing%criterion=parameters%timing_criterion
    if(.not.base%active_event.and.parameters%scheduled_irrigation_enabled.and. &
         request%selection_opportunity.and.request%irrigation_enabled.and.request%schedule_enabled.and. &
         request%crop_emerged.and.request%irrigation_window_open.and..not.request%fixed_event_already_selected) then
      call evaluate_tcs1_4_timing(parameters%timing_criterion,request%dvs,knots,values,count, &
           iptra,iqdry,iqsol,awlh,awmh,awah,timing%triggered,timing%threshold,ratio,depletion,code)
      timing%valid=code==IRR_TCS1_4_OK
    end if
    call evaluate_scheduled_irrigation_interval(parameters,base,request,unused,candidate,flux,diagnostics,timing)
  end subroutine
end module

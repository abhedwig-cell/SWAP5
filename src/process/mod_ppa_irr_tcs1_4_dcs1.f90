module mod_ppa_irr_tcs1_4_dcs1
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_water_deficit, only: evaluate_root_zone_water_deficit_checked,IRR_DEFICIT_OK
  use mod_ppa_irr_tcs1_4_timing, only: evaluate_tcs1_4_timing,IRR_TCS1_4_OK
  implicit none
  private
  public :: evaluate_tcs1_4_dcs1_profile
contains
  pure subroutine evaluate_tcs1_4_dcs1_profile(p,base,request,h,noddrz,layer,dz,ztopcp,rd, &
       wclos,wcmes,wchis,knots,values,count,iptra,iqdry,iqsol,candidate,flux,diagnostics)
    type(scheduled_irrigation_parameters_t),intent(in)::p
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::request
    type(process_hydraulic_view_t),intent(in)::h
    integer,intent(in)::noddrz,layer(:),count
    real(real64),intent(in)::dz(:),ztopcp(:),rd,wclos(:),wcmes(:),wchis(:)
    real(real64),intent(in)::knots(7),values(7),iptra,iqdry,iqsol
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(scheduled_irrigation_request_t)::prepared
    type(irrigation_timing_selection_t)::timing
    real(real64)::awlh,awmh,awah,ratio,depletion
    integer::code
    candidate=base; flux=irrigation_flux_result_t(); diagnostics=irrigation_diagnostics_t()
    diagnostics%status=IRRIGATION_INVALID_PARAMETERS
    if(p%timing_criterion<1.or.p%timing_criterion>4) return
    if(p%depth_criterion/=IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY) return
    prepared=request; timing%criterion=p%timing_criterion
    if(.not.base%active_event.and.p%scheduled_irrigation_enabled.and.request%selection_opportunity.and. &
         request%irrigation_enabled.and.request%schedule_enabled.and.request%crop_emerged.and. &
         request%irrigation_window_open.and..not.request%fixed_event_already_selected) then
      diagnostics%status=IRRIGATION_INVALID_HYDRAULIC_VIEW
      if(h%active_nodes/=p%active_nodes.or.h%active_nodes<1) return
      if(.not.allocated(h%water_content)) return
      if(size(h%water_content)/=h%active_nodes) return
      diagnostics%status=IRRIGATION_INVALID_PARAMETERS
      if(noddrz>h%active_nodes) return
      call evaluate_root_zone_water_deficit_checked(noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis, &
           h%water_content,awlh,awmh,awah,prepared%deficit_cm,code)
      if(code/=IRR_DEFICIT_OK) return
      call evaluate_tcs1_4_timing(p%timing_criterion,request%dvs,knots,values,count, &
           iptra,iqdry,iqsol,awlh,awmh,awah,timing%triggered,timing%threshold,ratio,depletion,code)
      timing%valid=code==IRR_TCS1_4_OK
    end if
    call evaluate_scheduled_irrigation_interval(p,base,prepared,h,candidate,flux,diagnostics,timing)
  end subroutine
end module

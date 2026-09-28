module mod_ppa_irr_dcs1_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_water_deficit, only: evaluate_root_zone_water_deficit_checked, IRR_DEFICIT_OK
  implicit none
  private
  public :: evaluate_profile_scheduled_irrigation
contains
  pure subroutine evaluate_profile_scheduled_irrigation(p,base,request,h,noddrz,layer,dz,ztopcp,rd, &
       wclos,wcmes,wchis,candidate,flux,diagnostics)
    type(scheduled_irrigation_parameters_t), intent(in) :: p
    type(irrigation_state_t), intent(in) :: base
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(process_hydraulic_view_t), intent(in) :: h
    integer, intent(in) :: noddrz,layer(:)
    real(real64), intent(in) :: dz(:),ztopcp(:),rd,wclos(:),wcmes(:),wchis(:)
    type(irrigation_state_t), intent(out) :: candidate
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_diagnostics_t), intent(out) :: diagnostics
    type(scheduled_irrigation_request_t) :: prepared
    real(real64) :: awlh,awmh,awah
    integer :: status
    logical :: needs_profile

    prepared=request
    needs_profile=.not.base%active_event.and.p%depth_criterion==IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY.and. &
         p%scheduled_irrigation_enabled.and.request%selection_opportunity.and.request%irrigation_enabled.and. &
         request%schedule_enabled.and.request%crop_emerged.and.request%irrigation_window_open.and. &
         .not.request%fixed_event_already_selected
    if(needs_profile) then
      candidate=base
      flux=irrigation_flux_result_t()
      diagnostics=irrigation_diagnostics_t()
      diagnostics%status=IRRIGATION_INVALID_HYDRAULIC_VIEW
      if(.not.allocated(h%water_content)) return
      if(h%active_nodes/=p%active_nodes.or.h%active_nodes<1) return
      if(size(h%water_content)<h%active_nodes) return
      diagnostics%status=IRRIGATION_INVALID_PARAMETERS
      if(noddrz>h%active_nodes) return
      call evaluate_root_zone_water_deficit_checked(noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis, &
           h%water_content,awlh,awmh,awah,prepared%deficit_cm,status)
      if(status/=IRR_DEFICIT_OK) return
    end if
    call evaluate_scheduled_irrigation_interval(p,base,prepared,h,candidate,flux,diagnostics)
  end subroutine evaluate_profile_scheduled_irrigation
end module mod_ppa_irr_dcs1_composition

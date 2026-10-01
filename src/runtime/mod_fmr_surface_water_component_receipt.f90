module mod_fmr_surface_water_component_receipt
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: FMR_SW_COMPONENT_SUBSURFACE=1
  integer, parameter, public :: FMR_SW_COMPONENT_TOP_SURFACE=2
  integer, parameter, public :: FMR_SW_RECEIPT_OK=0, FMR_SW_RECEIPT_INVALID=1, FMR_SW_RECEIPT_MISMATCH=2
  type, public :: fmr_surface_water_component_candidate_t
    logical :: valid=.false.
    real(real64) :: subsurface_swap_to_surface_cm=0._real64
    real(real64) :: top_swap_to_surface_cm=0._real64
  end type
  type, public :: fmr_surface_water_component_receipt_t
    logical :: valid=.false.
    real(real64) :: subsurface_swap_to_surface_cm=0._real64
    real(real64) :: top_swap_to_surface_cm=0._real64
  end type
  public :: surface_water_component_receipt_matches
contains
  pure integer function surface_water_component_receipt_matches(candidate,receipt,tolerance_cm) result(status)
    type(fmr_surface_water_component_candidate_t),intent(in)::candidate
    type(fmr_surface_water_component_receipt_t),intent(in)::receipt
    real(real64),intent(in)::tolerance_cm
    status=FMR_SW_RECEIPT_INVALID
    if(.not.candidate%valid.or..not.receipt%valid)return
    if(.not.ieee_is_finite(tolerance_cm).or.tolerance_cm<0._real64)return
    if(.not.all(ieee_is_finite([candidate%subsurface_swap_to_surface_cm,candidate%top_swap_to_surface_cm, &
       receipt%subsurface_swap_to_surface_cm,receipt%top_swap_to_surface_cm])))return
    if(abs(candidate%subsurface_swap_to_surface_cm-receipt%subsurface_swap_to_surface_cm)>tolerance_cm.or. &
       abs(candidate%top_swap_to_surface_cm-receipt%top_swap_to_surface_cm)>tolerance_cm)then
      status=FMR_SW_RECEIPT_MISMATCH;return
    end if
    status=FMR_SW_RECEIPT_OK
  end function
end module

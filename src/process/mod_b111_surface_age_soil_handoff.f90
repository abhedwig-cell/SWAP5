! Candidate-only conservative boundary handoff. Not wired into admitted age route.
module mod_b111_surface_age_soil_handoff
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b111_surface_age_budget, only: surface_age_receipt_t, SURFACE_AGE_OK
  implicit none
  private
  integer, parameter, public :: AGE_HANDOFF_OK=0,AGE_HANDOFF_REJECT=1
  public :: trial_infiltrated_age_to_soil
contains
  pure subroutine trial_infiltrated_age_to_soil(soil_before,receipt,soil_after,transferred,status)
    real(real64),intent(in)::soil_before(:)
    type(surface_age_receipt_t),intent(in)::receipt
    real(real64),allocatable,intent(out)::soil_after(:)
    real(real64),intent(out)::transferred
    integer,intent(out)::status
    real(real64)::scale
    status=AGE_HANDOFF_REJECT
    transferred=0.0_real64
    allocate(soil_after(size(soil_before)))
    soil_after=soil_before
    if(receipt%status/=SURFACE_AGE_OK.or.size(soil_before)<1.or.size(soil_before)>4096)return
    if(.not.all(ieee_is_finite(soil_before)))return
    if(any(soil_before<0.0_real64).or.any(soil_before>1.0e12_real64))return
    if(.not.ieee_is_finite(receipt%infiltration_age_export_cm_day))return
    if(receipt%infiltration_age_export_cm_day<0.0_real64)return
    transferred=receipt%infiltration_age_export_cm_day
    if(transferred>1.0e12_real64-soil_before(1))then
      transferred=0.0_real64
      return
    end if
    soil_after(1)=soil_before(1)+transferred
    scale=max(1.0_real64,transferred,soil_before(1),soil_after(1))
    if(abs(sum(soil_after-soil_before)-transferred)>8192.0_real64*epsilon(1.0_real64)*scale)then
      soil_after=soil_before
      transferred=0.0_real64
      return
    end if
    status=AGE_HANDOFF_OK
  end subroutine
end module

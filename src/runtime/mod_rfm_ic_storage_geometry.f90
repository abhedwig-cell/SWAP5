module mod_rfm_ic_storage_geometry
 use,intrinsic::iso_fortran_env,only:real64
 use,intrinsic::ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 type,public::rfm_ic_storage_geometry_result_t
  logical::valid=.false.
  real(real64)::water_column_height_cm=0.0_real64
  real(real64)::storage_reconstructed_cm=0.0_real64
  real(real64)::residual_cm=0.0_real64
 end type
 public::derive_rfm_ic_water_column
contains
 pure subroutine derive_rfm_ic_water_column(storage_cm,area_fraction,contact_thickness_cm,tolerance,result)
  real(real64),intent(in)::storage_cm,area_fraction,contact_thickness_cm,tolerance
  type(rfm_ic_storage_geometry_result_t),intent(out)::result
  real(real64)::h
  result=rfm_ic_storage_geometry_result_t()
  if(.not.ieee_is_finite(storage_cm).or.storage_cm<0.0_real64)return
  if(.not.ieee_is_finite(area_fraction).or.area_fraction<=0.0_real64.or.area_fraction>1.0_real64)return
  if(.not.ieee_is_finite(contact_thickness_cm).or.contact_thickness_cm<=0.0_real64)return
  if(.not.ieee_is_finite(tolerance).or.tolerance<0.0_real64)return
  h=storage_cm/area_fraction
  if(.not.ieee_is_finite(h).or.h>contact_thickness_cm+tolerance)return
  h=min(h,contact_thickness_cm)
  result%water_column_height_cm=h
  result%storage_reconstructed_cm=area_fraction*h
  result%residual_cm=storage_cm-result%storage_reconstructed_cm
  if(abs(result%residual_cm)>tolerance)return
  result%valid=.true.
 end subroutine
end module

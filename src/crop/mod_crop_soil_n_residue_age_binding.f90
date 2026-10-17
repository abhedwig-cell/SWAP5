! Bridge original named SWAP431 residue-age profile to already owned crop/soil-N policies.
! No separate crop, pending stock, or restart codec.
module mod_crop_soil_n_residue_age_binding
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_historical_named_input,only:soil_n_residue_age_t
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_crop_soil_n_configuration,only:crop_n_configuration_t
 implicit none
 private
 integer,parameter,public::RESIDUE_AGE_BIND_OK=0,RESIDUE_AGE_BIND_INVALID=1
 public::bind_historical_residue_ages
contains
 subroutine bind_historical_residue_ages(source,existing,policy,configured,status)
   type(soil_n_residue_age_t),intent(in)::source
   type(crop_n_configuration_t),intent(in)::existing
   type(crop_senescence_policy_t),intent(out)::policy
   type(crop_n_configuration_t),intent(out)::configured
   integer,intent(out)::status
   real(real64)::v(4)
   policy=crop_senescence_policy_t();configured=existing;status=RESIDUE_AGE_BIND_INVALID
   v=[source%root,source%leaf,source%stem,source%storage]
   if(.not.all(ieee_is_finite(v)))return
   ! Existing physical material split requires ages >= .67, even though
   ! original source file reader allows 0..100. Reject unsupported values.
   if(any(v<.67d0).or.any(v>100d0))return
   if(.not.allocated(existing%harvest))return
   if(existing%harvest%sw_wofost/=1)return
   policy%application_age=v(:3)
   configured%harvest%policy%application_age=v
   status=RESIDUE_AGE_BIND_OK
 end subroutine
end module

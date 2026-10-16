module mod_crop_b111_n_request_binding
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_nfixation_policy
 use mod_crop_soil_n_configuration,only:crop_n_b111_request_t
 use mod_wofost81_one_day_candidate,only:wofost81_one_day_prepared_candidate_t
 use mod_wofost81_daily_parameter_contract,only:wofost81_daily_parameter_contract_t
 use MOD_wofost81_nitrogen,only:WOFOST81_n_request
 implicit none
 private
 public::bind_b111_vegetative_request
contains
 ! Only a request is replaced. The existing crop/Soil-N transaction owns apply,
 ! fixation accumulation, soil debit, whole-N acceptance and persistence.
 subroutine bind_b111_vegetative_request(policy,p81,dvs,prepared,status)
  type(crop_n_b111_request_t),intent(in)::policy
  type(wofost81_daily_parameter_contract_t),intent(in)::p81
  real(real64),intent(in)::dvs
  type(wofost81_one_day_prepared_candidate_t),intent(inout)::prepared
  integer,intent(out)::status
  type(b111_nfixation_result_t)::b
  type(WOFOST81_n_request)::request
  real(real64)::nmaxlv,nmaxst,nmaxrt,reltr
  integer::code
  status=1
  if(.not.prepared%ready.or..not.prepared%active)return
  if(.not.all(ieee_is_finite([dvs,policy%dvsnlt,policy%nfixf])))return
  if(policy%dvsnlt<0d0.or.policy%dvsnlt>2d0.or.policy%nfixf<0d0.or.policy%nfixf>1d0)return
  ! No implicit replacement of the distinct reproductive translocation laws.
  if(dvs>=p81%base%nitrogen%dvs_n_transl)return
  call p81%evaluate_maximum_leaf_n_concentration(dvs,nmaxlv,code)
  if(code/=0)return
  nmaxst=nmaxlv*p81%base%nitrogen%nmaxst_fr
  nmaxrt=nmaxlv*p81%base%nitrogen%nmaxrt_fr
  reltr=prepared%corrected_rates%relative_transpiration_used
  associate(n=>prepared%nitrogen_before%value)
   call evaluate_b111_nfixation(dvs,policy%dvsnlt,reltr,policy%nfixf, &
     nmaxlv,nmaxst,nmaxrt,prepared%wlv_before,prepared%wst_before,prepared%wrt_before, &
     n%namountlv,n%namountst,n%namountrt,b)
   if(b%status/=B111_NFIX_OK)return
   ! Original source books supply but allocates none in this small-demand band.
   if(b%vegetative_demand>0d0.and.b%vegetative_demand<=1d-5.and. &
     (b%soil_demand>0d0.or.b%fixation>0d0))return
   request%ndemandlv=max(0d0,nmaxlv*prepared%wlv_before-n%namountlv)
   request%ndemandst=max(0d0,nmaxst*prepared%wst_before-n%namountst)
   request%ndemandrt=max(0d0,nmaxrt*prepared%wrt_before-n%namountrt)
  end associate
  request%ndemand=b%vegetative_demand
  request%rnfixation=b%fixation
  request%soil_request=b%soil_demand
  ! Fresh request has zero storage demand and zero translocation. No second fix.
  prepared%nitrogen_request=request
  status=0
 end subroutine
end module

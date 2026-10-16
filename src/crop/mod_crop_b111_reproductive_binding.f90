module mod_crop_b111_reproductive_binding
 use iso_fortran_env,only:real64
 use mod_b111_reproductive_n_process
 use mod_wofost81_one_day_candidate
 use mod_wofost81_daily_parameter_contract,only:wofost81_daily_parameter_contract_t
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t,WOFOST81_CROP_OWNER_OK
 use mod_wofost81_n_owner_state,only:WOFOST81_N_OWNER_OK
 use MOD_wofost81_nitrogen,only:WOFOST81_n_state,WOFOST81_n_flux,WOFN81_OK
 implicit none
 private
 public::bind_b111_reproductive_request,apply_b111_reproductive_supply
contains
 subroutine bind_b111_reproductive_request(policy,p81,dvs,prepared,context,status)
  type(b111_reproductive_policy_t),intent(in)::policy
  type(wofost81_daily_parameter_contract_t),intent(in)::p81
  real(real64),intent(in)::dvs
  type(wofost81_one_day_prepared_candidate_t),intent(inout)::prepared
  type(b111_reproductive_prepared_t),intent(out)::context
  integer,intent(out)::status
  real(real64)::nmaxlv
  integer::code
  context=b111_reproductive_prepared_t();status=1
  if(.not.prepared%ready.or..not.prepared%active)return
  call p81%evaluate_maximum_leaf_n_concentration(dvs,nmaxlv,code)
  if(code/=0)return
  call prepare_b111_reproductive_n(policy,p81%base%nitrogen%donor_view(),prepared%nitrogen_before%value, &
    dvs,nmaxlv,[prepared%wlv_before,prepared%wst_before,prepared%wrt_before,prepared%wso_before], &
    [prepared%drlv,prepared%drst,prepared%drrt],prepared%corrected_rates%relative_transpiration_used,context,code)
  if(code/=B111_REPRO_OK)return
  prepared%nitrogen_request=context%request_view()
  status=0
 end subroutine
 subroutine apply_b111_reproductive_supply(prepared,context,supply,candidate,flux,status)
  type(wofost81_one_day_prepared_candidate_t),intent(in)::prepared
  type(b111_reproductive_prepared_t),intent(in)::context
  real(real64),intent(in)::supply
  type(wofost81_crop_owner_state_t),intent(out)::candidate
  type(WOFOST81_n_flux),intent(out)::flux
  integer,intent(out)::status
  type(WOFOST81_n_state)::n
  integer::code
  candidate=prepared%candidate;flux=WOFOST81_n_flux();status=WOFOST81_DAY_N_APPLY_FAILURE
  if(.not.prepared%ready.or..not.prepared%active)return
  call apply_b111_reproductive_n(context,supply,n,flux,code)
  if(code/=B111_REPRO_OK.or.flux%status/=WOFN81_OK)then
   candidate%nitrogen=prepared%nitrogen_before;return
  end if
  candidate%nitrogen%value=n
  if(candidate%nitrogen%validate()/=WOFOST81_N_OWNER_OK)then
   candidate%nitrogen=prepared%nitrogen_before;return
  end if
  status=WOFOST81_DAY_INVALID_CANDIDATE
  if(candidate%validate()/=WOFOST81_CROP_OWNER_OK)return
  status=WOFOST81_DAY_OK
 end subroutine
end module

program test_b111_request_boundaries
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_b111_n_request_binding
 use mod_crop_soil_n_configuration
 use mod_wofost81_one_day_candidate
 use mod_wofost81_daily_parameter_contract
 use mod_wofost_rate_table,only:construct_wofost_rate_table
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 implicit none
 type(wofost81_daily_parameter_contract_t)::p81
 type(wofost81_one_day_prepared_candidate_t)::prepared
 type(crop_n_b111_request_t)::policy
 integer::code
 p81%base%assimilation%amax_ref=35d0;p81%base%assimilation%kn=.4d0
 p81%base%nitrogen%nmaxst_fr=.5d0;p81%base%nitrogen%nmaxrt_fr=.5d0
 p81%base%nitrogen%dvs_n_transl=.8d0
 call construct_wofost_rate_table([0d0,2d0],[.04d0,.04d0],p81%tables%maximum_leaf_n_concentration,code)
 call require(code==0,'real table and parameter construction')
 prepared%ready=.true.;prepared%active=.true.
 prepared%wlv_before=1.25d-4
 prepared%corrected_rates%relative_transpiration_used=1d0
 prepared%nitrogen_request%rnfixation=123d0
 policy%dvsnlt=.7d0;policy%nfixf=.3d0
 call bind_b111_vegetative_request(policy,p81,.5d0,prepared,code)
 call require(code/=0.and.prepared%nitrogen_request%rnfixation==123d0,'tiny positive demand rejects without request leak')
 policy%dvsnlt=.5d0
 call bind_b111_vegetative_request(policy,p81,.5d0,prepared,code)
 call require(code==0.and.prepared%nitrogen_request%rnfixation==0d0.and. &
   prepared%nitrogen_request%soil_request==0d0,'strict DVS equality suppresses tiny input')
 policy%dvsnlt=.7d0
 prepared%corrected_rates%relative_transpiration_used=.01d0
 call bind_b111_vegetative_request(policy,p81,.5d0,prepared,code)
 call require(code==0.and.prepared%nitrogen_request%rnfixation==0d0,'strict RELTR equality')
 prepared%corrected_rates%relative_transpiration_used=nearest(.01d0,1d0)
 call bind_b111_vegetative_request(policy,p81,.5d0,prepared,code)
 call require(code/=0,'next representable RELTR enables tiny-demand refusal')
 prepared%wlv_before=100d0;prepared%wst_before=200d0;prepared%wrt_before=100d0
 prepared%wso_before=10000d0;prepared%grso=10000d0;prepared%grlv=10000d0
 prepared%nitrogen_before%value%namountlv=1d0
 prepared%nitrogen_before%value%namountst=1d0
 prepared%nitrogen_before%value%namountrt=1d0
 prepared%corrected_rates%relative_transpiration_used=1d0
 call bind_b111_vegetative_request(policy,p81,.5d0,prepared,code)
 call require(code==0,'nontrivial three-organ request')
 call require(prepared%nitrogen_request%ndemandlv==3d0.and.prepared%nitrogen_request%ndemandst==3d0.and. &
   prepared%nitrogen_request%ndemandrt==1d0.and.prepared%nitrogen_request%ndemand==7d0,'independent committed organ deficits')
 call require(prepared%nitrogen_request%soil_request==(.7d0*7d0).and. &
   prepared%nitrogen_request%rnfixation==(.3d0*7d0),'literal independent partitions')
 call require(prepared%nitrogen_request%ndemandso==0d0.and. &
   prepared%nitrogen_request%rntranslocation==0d0,'growth storage and translocation never leak')
 call bind_b111_vegetative_request(policy,p81,.8d0,prepared,code)
 call require(code/=0,'reproductive boundary is not silently reinterpreted')
 policy%nfixf=ieee_value(0d0,ieee_quiet_nan)
 call bind_b111_vegetative_request(policy,p81,.5d0,prepared,code)
 call require(code/=0,'invalid selected policy refused')
 print '(A)','B111_REQUEST_BOUNDARY_TINY_DEMAND_MULTI_ORGAN_NONFINITE=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
end program

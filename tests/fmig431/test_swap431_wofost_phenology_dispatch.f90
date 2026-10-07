program test_swap431_wofost_phenology_dispatch
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_soybean_phenology_factors
  use mod_wofost_vernalisation_phenology
  use mod_wofost_phenology_dispatch
  implicit none

  type(wofost_crop_owner_state_t)::owner
  type(soybean_phenology_parameters_t)::soy
  type(wofost_vernalisation_parameters_t)::vern
  type(wofost_phenology_request_t)::req
  type(wofost_phenology_dispatch_result_t)::res
  integer::status
  real(real64),parameter::tol=1e-12_real64

  owner%crop_emerged=.true.
  owner%development_stage=0.2_real64
  allocate(owner%biomass,owner%evolution_continuation)
  owner%biomass%root_biomass=10._real64
  owner%biomass%stem_biomass=10._real64
  owner%biomass%storage_biomass=0._real64
  owner%biomass%exponential_leaf_area_index=1._real64
  owner%evolution_continuation%temperature_sum=20._real64
  owner%evolution_continuation%anthesis_reached=.false.
  if(owner%validate()/=WOFOST_CROP_OWNER_OK)error stop 1

  req%mode=WOFOST_PHENOLOGY_CLASSIC
  req%average_temperature_c=20._real64
  call resolve_wofost_phenology(owner,req,result=res,status=status)
  if(status/=WOFOST_PHENOLOGY_DISPATCH_OK.or.res%override_available)error stop 2

  soy%maturity_group=4._real64
  soy%maximum_vegetative_development_rate=.1_real64
  soy%maximum_generative_development_rate=.08_real64
  soy%minimum_development_temperature_c=5._real64
  soy%optimum_development_temperature_c=25._real64
  soy%maximum_development_temperature_c=40._real64
  soy%apply_photoperiod_in_vegetative_phase=.false.
  soy%derive_photoperiod_from_maturity_group=.true.
  req=wofost_phenology_request_t()
  req%mode=WOFOST_PHENOLOGY_SOYBEAN
  req%average_temperature_c=25._real64
  req%latitude_degrees=0._real64
  req%day_of_year=100
  call resolve_wofost_phenology(owner,req,soybean_parameters=soy,result=res,status=status)
  if(status/=WOFOST_PHENOLOGY_DISPATCH_OK.or..not.res%override_available)error stop 3
  if(abs(res%rate%temperature_sum_increment-25._real64)>tol.or.abs(res%rate%development_rate-.1_real64)>tol)error stop 4
  if(res%vernalisation_candidate_available)error stop 5

  vern%critical_development_stage=.3_real64
  vern%base_requirement=10._real64
  vern%saturation_requirement=30._real64
  call construct_wofost_rate_table([-10._real64,20._real64,100._real64],[0._real64,5._real64,0._real64], &
       vern%temperature_rate,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 6
  allocate(owner%vernalisation)
  owner%vernalisation%accumulated_units=20._real64
  owner%vernalisation%vernalised=.false.
  owner%vernalisation%retained_rate=0._real64
  if(owner%validate()/=WOFOST_CROP_OWNER_OK)error stop 7

  req=wofost_phenology_request_t()
  req%mode=WOFOST_PHENOLOGY_VERNALISATION
  req%average_temperature_c=20._real64
  req%photoperiod_factor=.8_real64
  req%temperature_sum_increment=10._real64
  req%vegetative_temperature_sum_required=100._real64
  call resolve_wofost_phenology(owner,req,vernalisation_parameters=vern,result=res,status=status)
  if(status/=WOFOST_PHENOLOGY_DISPATCH_OK.or..not.res%override_available.or. &
       .not.res%vernalisation_candidate_available)error stop 8
  if(abs(res%rate%development_rate-.04_real64)>tol)error stop 9
  if(abs(res%vernalisation%candidate_state%accumulated_units-25._real64)>tol)error stop 10
  if(abs(res%vernalisation%candidate_state%retained_rate-5._real64)>tol)error stop 11

  owner%development_stage=1.2_real64
  owner%evolution_continuation%anthesis_reached=.true.
  call resolve_wofost_phenology(owner,req,vernalisation_parameters=vern,result=res,status=status)
  if(status/=WOFOST_PHENOLOGY_DISPATCH_OK.or.res%override_available.or.res%vernalisation_candidate_available)error stop 12

  print '(a)','SW431_CROP_PHENOLOGY_DISPATCH=PASS'
end program

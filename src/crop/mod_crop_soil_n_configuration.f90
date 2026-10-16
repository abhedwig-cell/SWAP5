module mod_crop_soil_n_configuration
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_wofost81_crop_owner_state,only:wofost81_harvest_policy_t
 use mod_wofost_rate_parameters
 use mod_wofost_rate_table,only:construct_wofost_rate_table
 use mod_wofost81_parameter_contract,only:wofost81_parameter_contract_t
 use mod_wofost81_daily_parameter_contract
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_update_parameters_t
 implicit none
 private
 type,public::crop_n_table_t
  real(real64),allocatable::x(:),y(:)
 end type
 type,public::crop_n_harvest_configuration_t
  integer::crop_identity=0,sw_harv=0,sw_wofost=1
  real(real64)::crop_end=0d0
  type(wofost81_harvest_policy_t)::policy
 end type
 type,public::crop_n_b111_request_t
  real(real64)::dvsnlt=0d0,nfixf=0d0
 end type
 type,public::crop_n_configuration_t
  type(crop_n_harvest_configuration_t),allocatable::harvest
  type(crop_n_b111_request_t),allocatable::b111_request
  type(wofost_rate_scalar_parameters_t)::scalars
  type(wofost81_parameter_contract_t)::base
  type(crop_n_table_t)::tables(16)
  type(wofost_one_day_update_parameters_t)::update
  real(real64)::root_depth_cm=0d0,tcsf_n=1d0,lai_crit_nupt=3d0,stem_area=0d0,storage_area=0d0
 end type
 public::build_crop_n_configuration,crop_n_configuration_vector
contains
 function crop_n_configuration_vector(p)result(v)
  type(crop_n_configuration_t),intent(in)::p
  real(real64),allocatable::v(:)
  integer::i,n
  allocate(v(0))
  v=[ &
    real(p%scalars%development_daylength_mode,real64),p%scalars%daylength_upper_hours,p%scalars%daylength_lower_hours, &
    p%scalars%vegetative_temperature_sum_required,p%scalars%generative_temperature_sum_required,p%scalars%diffuse_extinction_coefficient, &
    p%scalars%initial_light_use_efficiency,p%scalars%co2_to_dry_matter_fraction,p%scalars%attainable_yield_multiplier, &
    p%scalars%conversion_efficiency_root,p%scalars%conversion_efficiency_stem,p%scalars%conversion_efficiency_leaf, &
    p%scalars%conversion_efficiency_storage,p%scalars%respiration_temperature_q10,p%scalars%maintenance_respiration_root, &
    p%scalars%maintenance_respiration_leaf,p%scalars%maintenance_respiration_stem,p%scalars%maintenance_respiration_storage, &
    p%scalars%maximum_leaf_relative_death_rate,p%scalars%leaf_age_base_temperature,p%scalars%maximum_relative_lai_growth_rate, &
    p%base%assimilation%amax_lnb,p%base%assimilation%amax_ref,p%base%assimilation%amax_slp, &
    p%base%assimilation%kn,p%base%nitrogen%nmaxst_fr,p%base%nitrogen%nmaxrt_fr, &
    p%base%nitrogen%nmaxso,p%base%nitrogen%nresidlv,p%base%nitrogen%nresidst, &
    p%base%nitrogen%nresidrt,p%base%nitrogen%tcnt,p%base%nitrogen%nfix_fr, &
    p%base%nitrogen%rnuptakemax,p%base%nitrogen%dvs_n_transl,p%base%nitrogen%rgrlai_min, &
    p%update%development_stage_end,p%update%leaf_lifespan,p%root_depth_cm, &
    p%tcsf_n,p%lai_crit_nupt,p%stem_area, &
    p%storage_area]
  do i=1,16
   if(.not.allocated(p%tables(i)%x).or..not.allocated(p%tables(i)%y))then
    deallocate(v);allocate(v(0));return
   end if
   n=size(p%tables(i)%x)
   if(n<1.or.n>64.or.size(p%tables(i)%y)/=n)then
    deallocate(v);allocate(v(0));return
   end if
   v=[v,real(n,real64),p%tables(i)%x,p%tables(i)%y]
  end do
  if(allocated(p%b111_request))then
   associate(b=>p%b111_request)
    if(.not.all(ieee_is_finite([b%dvsnlt,b%nfixf])))then
     deallocate(v);allocate(v(0));return
    end if
    if(b%dvsnlt<0d0.or.b%dvsnlt>2d0.or.b%nfixf<0d0.or.b%nfixf>1d0)then
     deallocate(v);allocate(v(0));return
    end if
    v=[v,911002d0,b%dvsnlt,b%nfixf]
   end associate
  end if
  if(allocated(p%harvest))then
   associate(h=>p%harvest)
    if(h%crop_identity<1.or.h%crop_identity>1000000.or.h%sw_harv<0.or.h%sw_harv>1.or. &
      h%sw_wofost<1.or.h%sw_wofost>2)then
     deallocate(v);allocate(v(0));return
    end if
    if(.not.all(ieee_is_finite([h%crop_end,h%policy%return_fraction,h%policy%application_age])))then
     deallocate(v);allocate(v(0));return
    end if
    if(abs(h%crop_end)>1d6.or.any(h%policy%return_fraction<0d0).or.any(h%policy%return_fraction>1d0).or. &
      any(h%policy%application_age<.67d0).or.any(h%policy%application_age>100d0))then
     deallocate(v);allocate(v(0));return
    end if
    v=[v,911001d0,real(h%crop_identity,real64),h%crop_end,real(h%sw_harv,real64), &
      real(h%sw_wofost,real64),h%policy%return_fraction,h%policy%application_age]
   end associate
  end if
 end function
 subroutine build_crop_n_configuration(p,common,p81,status)
  type(crop_n_configuration_t),intent(in)::p
  type(wofost_rate_parameter_bundle_t),intent(out)::common
  type(wofost81_daily_parameter_contract_t),intent(out)::p81
  integer,intent(out)::status
  type(wofost_rate_parameter_tables_t)::t
  real(real64),allocatable::v(:)
  integer::code
  status=1;v=crop_n_configuration_vector(p)
  if(size(v)==0)return
  if(.not.all(ieee_is_finite(v)))return
  if(any(abs(v)>1d6))return
  if(p%root_depth_cm<=0d0.or.p%root_depth_cm>1d4.or.p%tcsf_n<0d0.or.p%tcsf_n>1d0)return
  if(p%lai_crit_nupt<0d0.or.p%lai_crit_nupt>100d0.or.min(p%stem_area,p%storage_area)<0d0)return
  if(p%update%leaf_lifespan<=0d0.or.p%update%development_stage_end<=0d0)return
  p81%base=p%base
  call construct_wofost_rate_table(p%tables(1)%x,p%tables(1)%y,t%temperature_sum_increment,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(2)%x,p%tables(2)%y,t%maximum_assimilation,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(3)%x,p%tables(3)%y,t%daytime_temperature_factor,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(4)%x,p%tables(4)%y,t%minimum_temperature_factor,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(5)%x,p%tables(5)%y,t%maintenance_respiration_factor,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(6)%x,p%tables(6)%y,t%root_partition_fraction,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(7)%x,p%tables(7)%y,t%leaf_partition_fraction,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(8)%x,p%tables(8)%y,t%stem_partition_fraction,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(9)%x,p%tables(9)%y,t%storage_partition_fraction,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(10)%x,p%tables(10)%y,t%relative_root_death_rate,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(11)%x,p%tables(11)%y,t%relative_stem_death_rate,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(12)%x,p%tables(12)%y,t%specific_leaf_area,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(13)%x,p%tables(13)%y,p81%tables%light_use_efficiency,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(14)%x,p%tables(14)%y,p81%tables%diffuse_extinction_coefficient,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(15)%x,p%tables(15)%y,p81%tables%maximum_leaf_n_concentration,code)
  if(code/=0)return
  call construct_wofost_rate_table(p%tables(16)%x,p%tables(16)%y,p81%tables%leaf_ageing_n_stress_multiplier,code)
  if(code/=0)return
  call construct_wofost_rate_parameter_bundle(p%scalars,t,common,code)
  if(code/=0.or.p81%validate()/=WOFOST81_DAILY_PARAMETER_OK)return
  status=0
 end subroutine
end module

module mod_crop_soil_n_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_reactive_owner
 use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
 use mod_soil_n_pool_state,only:soil_n_pool_state_t
 use mod_crop_soil_n_configuration
 use mod_wofost81_crop_owner_state
 use mod_wofost81_one_day_candidate
 use mod_wofost81_daily_parameter_contract
 use mod_wofost_rate_parameters
 use mod_wofost_one_day_structural_evolution
 use MOD_wofost81_nitrogen,only:WOFOST81_n_flux
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 integer,parameter,public::CROP_SOIL_OK=0,CROP_SOIL_INVALID=1,CROP_SOIL_PREPARE=2, &
  CROP_SOIL_REACTION=3,CROP_SOIL_APPLY=4,CROP_SOIL_TRANSFER=5,CROP_SOIL_BALANCE=6
 type,public::crop_soil_state_t
  private
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(crop_n_configuration_t)::p
  integer(int64)::parameter_id=0
  logical::initialized=.false.
 contains
  procedure::ready=>coupled_ready
  procedure::snapshot=>coupled_snapshot
  procedure::configuration=>coupled_configuration
 end type
 type,public::crop_soil_receipt_t
  integer::status=CROP_SOIL_INVALID
  type(reactive_receipt_t)::soil
  type(WOFOST81_n_flux)::crop
  type(wofost81_one_day_prepared_candidate_t)::prepared
  real(real64)::internal_supply_kg_m2=0d0,fixation_kg_m2=0d0,crop_loss_kg_m2=0d0,whole_n_residual=0d0
  real(real64)::actual_root_cm=0d0,potential_root_cm=0d0
 end type
 public::initialize_crop_soil,advance_crop_soil_day,pack_crop_n_owner,unpack_crop_n_owner,crop_n_live
contains
 logical function coupled_ready(self)result(ok)
  class(crop_soil_state_t),intent(in)::self
  ok=self%initialized.and.self%soil%ready()
 end function
 subroutine coupled_snapshot(self,soil,crop)
  class(crop_soil_state_t),intent(in)::self
  type(reactive_state_t),intent(out)::soil
  type(wofost81_crop_owner_state_t),intent(out)::crop
  soil=self%soil;crop=self%crop
 end subroutine
 subroutine coupled_configuration(self,p,id)
  class(crop_soil_state_t),intent(in)::self
  type(crop_n_configuration_t),intent(out)::p
  integer(int64),intent(out)::id
  p=self%p;id=self%parameter_id
 end subroutine
 subroutine initialize_crop_soil(soil,crop,p,id,state,status)
  type(reactive_state_t),intent(in)::soil
  type(wofost81_crop_owner_state_t),intent(in)::crop
  type(crop_n_configuration_t),intent(in)::p
  integer(int64),intent(in)::id
  type(crop_soil_state_t),intent(out)::state
  integer,intent(out)::status
  type(wofost_rate_parameter_bundle_t)::common
  type(wofost81_daily_parameter_contract_t)::p81
  type(reactive_parameters_t)::sp
  integer(int64)::sid
  real(real64),allocatable::v(:)
  integer::code
  state=crop_soil_state_t();status=CROP_SOIL_INVALID
  if(.not.soil%ready().or.id<1.or.id>100000000)return
  call build_crop_n_configuration(p,common,p81,code)
  if(code/=0)return
  call soil%configuration(sp,sid)
  if(.not.sp%enabled)return
  if(abs(p%root_depth_cm-sum(sp%mineral%dz_cm))>0d0)return
  v=pack_crop_n_owner(crop)
  if(size(v)==0)return
  state%soil=soil;state%crop=crop;state%p=p;state%parameter_id=id;state%initialized=.true.
  status=CROP_SOIL_OK
 end subroutine
 real(real64)function crop_n_live(crop)result(total)
  type(wofost81_crop_owner_state_t),intent(in)::crop
  associate(n=>crop%nitrogen%value)
   total=(n%namountlv+n%namountst+n%namountrt+n%namountso)*1d-4
  end associate
 end function
 subroutine advance_crop_soil_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm,weather,r,environment)
  type(crop_soil_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm
  type(wofost_one_day_forcing_t),intent(in)::weather
  type(crop_soil_receipt_t),intent(out)::r
  type(soil_n_day_environment_t),intent(in),optional::environment
  type(wofost_rate_parameter_bundle_t)::common
  type(wofost81_daily_parameter_contract_t)::p81
  type(wofost_accepted_window_aggregates_t)::a
  type(wofost81_crop_owner_state_t)::crop_trial
  type(reactive_state_t)::soil_trial
  type(reactive_crop_demand_t)::d
  type(reactive_parameters_t)::sp
  type(soil_n_pool_state_t)::before,after
  real(real64),allocatable::v(:)
  real(real64)::clock,theta,supply,initial,final,external_in,external_out,scale,wv(12)
  integer(int64)::revision,id
  integer::code
  r=crop_soil_receipt_t()
  if(.not.state%ready())return
  if(.not.all(ieee_is_finite([t0,t1,potential_cm,root_water])))return
  if(min(potential_cm,root_water)<0d0.or.max(potential_cm,root_water)>100d0)return
  wv=[weather%minimum_temperature,weather%average_temperature,weather%daytime_average_temperature, &
    weather%global_radiation,weather%daylength_hours,weather%photoperiodic_daylength_hours, &
    weather%sinld,weather%cosld,weather%diffuse_perpendicular_radiation,weather%daily_sine_solar_elevation_integral, &
    weather%co2_efficiency_factor,weather%co2_amax_factor]
  if(.not.all(ieee_is_finite(wv)))return
  if(any(abs(wv)>1d9))return
  if(minval(wv(1:3))< -50d0.or.maxval(wv(1:3))>60d0.or.minval(wv(4:6))<0d0.or.maxval(wv(5:6))>24d0)return
  if(maxval(abs(wv(7:8)))>1d0.or.minval(wv(9:12))<0d0.or.maxval(wv(11:12))>10d0)return
  call state%soil%snapshot(clock,theta,before,revision)
  if(abs(clock-t0)>0d0.or.abs(t1-t0-1d0)>0d0)return
  if(100d0*root_water>potential_cm+1d-12)return
  call build_crop_n_configuration(state%p,common,p81,code)
  if(code/=0)return
  a%actual_root_uptake=100d0*root_water;a%potential_transpiration=potential_cm
  r%actual_root_cm=a%actual_root_uptake;r%potential_root_cm=potential_cm
  r%status=CROP_SOIL_PREPARE
  call prepare_wofost81_one_day_candidate(state%crop,weather,t0,t1,common,p81,state%p%update,a, &
    state%p%stem_area,state%p%storage_area,.true.,r%prepared,code)
  if(code/=WOFOST81_DAY_OK.or..not.r%prepared%ready.or..not.r%prepared%active)return
  d%demand_kg_m2=1d-4*r%prepared%nitrogen_request%soil_request
  d%root_depth_cm=state%p%root_depth_cm;d%tcsf_n=state%p%tcsf_n
  d%dvs=state%crop%crop%development_stage
  call state%crop%crop%derive_actual_leaf_area_index(state%p%stem_area,state%p%storage_area,d%lai,code)
  if(code/=0)return
  d%lai_crit_nupt=state%p%lai_crit_nupt
  soil_trial=state%soil
  r%status=CROP_SOIL_REACTION
  call advance_reactive_day(soil_trial,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,r%soil,d,environment)
  if(r%soil%status/=MINERAL_OK)return
  supply=r%soil%process%exchange%nsupply_total_kg_m2_day
  r%status=CROP_SOIL_APPLY
  call apply_wofost81_one_day_n_supply(r%prepared,p81,supply*1d4,crop_trial,r%crop,code)
  if(code/=WOFOST81_DAY_OK)return
  v=pack_crop_n_owner(crop_trial)
  if(size(v)==0)return
  r%internal_supply_kg_m2=r%crop%rnuptake*1d-4
  r%fixation_kg_m2=r%crop%rnfixation*1d-4;r%crop_loss_kg_m2=r%crop%rnloss*1d-4
  r%status=CROP_SOIL_TRANSFER
  if(abs(supply-r%internal_supply_kg_m2)>1d-12*max(1d0,supply))return
  call state%soil%configuration(sp,id)
  call soil_trial%snapshot(clock,theta,after,revision)
  initial=before%nitrogen_total(sp%mineral%inventory)+crop_n_live(state%crop)
  final=after%nitrogen_total(sp%mineral%inventory)+crop_n_live(crop_trial)
  external_in=r%soil%external_in+r%fixation_kg_m2
  external_out=r%soil%external_out-supply+r%crop_loss_kg_m2
  r%whole_n_residual=initial+external_in-final-external_out
  r%status=CROP_SOIL_BALANCE
  scale=max(1d0,initial,final,external_in,external_out)
  if(abs(r%whole_n_residual)>1d-12*scale)return
  state%soil=soil_trial;state%crop=crop_trial;r%status=CROP_SOIL_OK
 end subroutine
 function pack_crop_n_owner(crop)result(v)
  type(wofost81_crop_owner_state_t),intent(in)::crop
  real(real64),allocatable::v(:)
  real(real64)::has_ref,ref
  integer::n
  allocate(v(0))
  if(.not.crop%crop%crop_emerged)return
  if(.not.allocated(crop%crop%biomass).or..not.allocated(crop%crop%evolution_continuation))return
  associate(b=>crop%crop%biomass,e=>crop%crop%evolution_continuation,s=>crop%nitrogen%value)
   if(.not.allocated(b%leaf_biomass).or..not.allocated(b%specific_leaf_area).or..not.allocated(b%leaf_age))return
   n=size(b%leaf_biomass)
   if(n<1.or.n>512.or.size(b%specific_leaf_area)/=n.or.size(b%leaf_age)/=n)return
   if(e%minimum_temperature_history_count<0.or.e%minimum_temperature_history_count>7)return
   has_ref=0d0;ref=0d0
   if(allocated(crop%crop%b110_reference_compatibility))then
    has_ref=1d0;ref=crop%crop%b110_reference_compatibility%lai_exponential_rate_carryover
   end if
   v=[crop%crop%development_stage,b%root_biomass,b%stem_biomass,b%storage_biomass,b%exponential_leaf_area_index, &
    e%temperature_sum,merge(1d0,0d0,e%anthesis_reached),real(e%minimum_temperature_history_count,real64), &
    e%minimum_temperature_history,has_ref,ref,s%namountlv,s%namountst,s%namountrt,s%namountso, &
    s%nuptake_total,s%nfix_total,s%nlosses_total,s%initial_total,real(n,real64),b%leaf_biomass,b%specific_leaf_area,b%leaf_age]
  end associate
  if(.not.all(ieee_is_finite(v)))then
   deallocate(v);allocate(v(0));return
  end if
  if(any(abs(v)>1d9))then
   deallocate(v);allocate(v(0));return
  end if
  if(crop%validate()/=WOFOST81_CROP_OWNER_OK)then
   deallocate(v);allocate(v(0))
  end if
 end function
 subroutine unpack_crop_n_owner(v,crop,status)
  real(real64),intent(in)::v(:)
  type(wofost81_crop_owner_state_t),intent(out)::crop
  integer,intent(out)::status
  real(real64),allocatable::proof(:)
  integer::n
  crop=wofost81_crop_owner_state_t();status=CROP_SOIL_INVALID
  if(size(v)<29)return
  if(.not.all(ieee_is_finite(v)))return
  if(any(abs(v)>1d9))return
  if(v(26)<1d0.or.v(26)>512d0)return
  n=int(v(26));if(real(n,real64)/=v(26).or.size(v)/=26+3*n)return
  if((v(7)/=0d0.and.v(7)/=1d0).or.(v(16)/=0d0.and.v(16)/=1d0))return
  if(v(8)<0d0.or.v(8)>7d0)return
  if(real(int(v(8)),real64)/=v(8))return
  if(v(16)==0d0.and.v(17)/=0d0)return
  crop%crop%crop_emerged=.true.;crop%crop%development_stage=v(1)
  allocate(crop%crop%biomass,crop%crop%evolution_continuation)
  associate(b=>crop%crop%biomass,e=>crop%crop%evolution_continuation,s=>crop%nitrogen%value)
   b%root_biomass=v(2);b%stem_biomass=v(3);b%storage_biomass=v(4);b%exponential_leaf_area_index=v(5)
   e%temperature_sum=v(6);e%anthesis_reached=v(7)==1d0;e%minimum_temperature_history_count=int(v(8))
   e%minimum_temperature_history=v(9:15)
   if(v(16)==1d0)then
    allocate(crop%crop%b110_reference_compatibility)
    crop%crop%b110_reference_compatibility%lai_exponential_rate_carryover=v(17)
   end if
   s%namountlv=v(18);s%namountst=v(19);s%namountrt=v(20);s%namountso=v(21)
   s%nuptake_total=v(22);s%nfix_total=v(23);s%nlosses_total=v(24);s%initial_total=v(25)
   b%leaf_biomass=v(27:26+n);b%specific_leaf_area=v(27+n:26+2*n);b%leaf_age=v(27+2*n:26+3*n)
  end associate
  proof=pack_crop_n_owner(crop)
  if(size(proof)==0)then
   crop=wofost81_crop_owner_state_t();return
  end if
  status=CROP_SOIL_OK
 end subroutine
end module

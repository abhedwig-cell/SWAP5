module mod_crop_soil_n_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_reactive_owner
 use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
 use mod_soil_n_pool_state,only:soil_n_pool_state_t,soil_n_transfer_t,soil_n_receipt_t,apply_soil_n_transfer,SOIL_N_OK
 use mod_crop_soil_n_configuration
 use mod_b111_reproductive_n_process,only:b111_reproductive_prepared_t
 use mod_crop_b111_reproductive_binding,only:bind_b111_reproductive_request,apply_b111_reproductive_supply
 use mod_crop_b111_n_request_binding,only:bind_b111_vegetative_request
 use mod_wofost81_crop_owner_state
 use mod_wofost81_one_day_candidate
 use mod_wofost81_daily_parameter_contract
 use mod_wofost_rate_parameters
 use mod_wofost_one_day_structural_evolution
 use MOD_wofost81_nitrogen,only:WOFOST81_n_flux
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 use mod_crop_senescence_residue,only:crop_residue_pending_t,build_pending_residue_materials
 use mod_wofost81_harvest_materials
 use mod_b111_soil_n_addition
 implicit none
 private
 integer,parameter,public::CROP_SOIL_OK=0,CROP_SOIL_INVALID=1,CROP_SOIL_PREPARE=2, &
  CROP_SOIL_REACTION=3,CROP_SOIL_APPLY=4,CROP_SOIL_TRANSFER=5,CROP_SOIL_BALANCE=6
 type,public::crop_soil_state_t
  private
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(crop_n_configuration_t)::p
  type(crop_residue_pending_t),allocatable::pending
  integer(int64)::parameter_id=0
  logical::initialized=.false.
 contains
  procedure::ready=>coupled_ready
  procedure::snapshot=>coupled_snapshot
  procedure::configuration=>coupled_configuration
  procedure::pending_snapshot=>coupled_pending_snapshot
 end type
 type,public::crop_soil_harvest_observation_t
  private
  type(wofost81_harvest_record_t)::record
  real(real64),allocatable::event(:)
 contains
  procedure::snapshot=>harvest_observation_snapshot
 end type
 type,public::crop_soil_harvest_receipt_t
  integer::rejection_stage=0
  integer::status=CROP_SOIL_INVALID
  real(real64)::initial_n=0d0,final_n=0d0,exported_n=0d0,incorporated_n=0d0,residual=0d0,seed_n=0d0
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
 public::harvest_crop_soil_boundary,consume_crop_soil_harvest_pending,crop_soil_whole_n,crop_soil_organic_mass
 public::observe_crop_soil_harvest,acknowledge_crop_soil_harvest,advance_crop_soil_fallow_day,initialize_crop_soil_successor
 public::pack_crop_n_continuation,unpack_crop_n_continuation,harvest_incorporation_valid
contains
 logical function coupled_ready(self)result(ok)
  class(crop_soil_state_t),intent(in)::self
  real(real64)::clock,theta
  integer(int64)::revision
  type(soil_n_pool_state_t)::pools
  ok=self%initialized.and.self%soil%ready()
  if(.not.ok)return
  ok=self%crop%validate()==0
  if(.not.ok)return
  ok=allocated(self%p%b112_return).eqv.self%crop%nitrogen%b112_residue_profile
  if(.not.ok)return
  if(self%crop%harvest_retired())then
   block
    type(wofost81_harvest_retired_t)::h
    logical::has
    if(.not.allocated(self%p%harvest).or.allocated(self%pending))then;ok=.false.;return;end if
    call self%crop%retired_snapshot(h,has)
    call self%soil%snapshot(clock,theta,pools,revision)
    ok=has.and.h%clock==clock.and.h%crop_identity==int(self%p%harvest%crop_identity,int64)
    if(.not.ok)return
    ok=abs(crop_soil_whole_n(self)-h%continuation_totals(1))<=1d-12*max(1d0,h%continuation_totals(1)).and. &
       abs(crop_soil_organic_mass(self)-h%continuation_totals(2))<=1d-12*max(1d0,h%continuation_totals(2))
    if(.not.ok)return
   end block
  else if(self%crop%harvested())then
   block
    type(wofost81_harvest_record_t)::h
    logical::has
    if(.not.allocated(self%p%harvest))then;ok=.false.;return;end if
    call self%crop%harvest_snapshot(h,has)
    call self%soil%snapshot(clock,theta,pools,revision)
    ok=has.and.h%clock==clock.and.h%crop_identity==int(self%p%harvest%crop_identity,int64).and. &
      all(h%policy%return_fraction==self%p%harvest%policy%return_fraction).and. &
      all(h%policy%application_age==self%p%harvest%policy%application_age)
    if(.not.ok)return
    if(any(h%continuation_totals<0d0))then;ok=.false.;return;end if
    ok=abs(crop_soil_whole_n(self)-h%continuation_totals(1))<=1d-12*max(1d0,h%continuation_totals(1)).and. &
       abs(crop_soil_organic_mass(self)-h%continuation_totals(2))<=1d-12*max(1d0,h%continuation_totals(2))
    if(.not.ok)return
   end block
  end if
  if(allocated(self%pending))then
   ok=self%pending%valid();if(.not.ok)return
   call self%soil%snapshot(clock,theta,pools,revision)
   ok=self%pending%clock==clock.and.any(self%pending%dry_matter_kg_ha>0d0).and. &
    sum(self%pending%nitrogen_kg_ha)<=self%crop%nitrogen%value%nlosses_total+1d-12
  end if
 end function
 subroutine coupled_snapshot(self,soil,crop)
  class(crop_soil_state_t),intent(in)::self
  type(reactive_state_t),intent(out)::soil
  type(wofost81_crop_owner_state_t),intent(out)::crop
  soil=self%soil;crop=self%crop
 end subroutine
 subroutine coupled_pending_snapshot(self,pending,present_pending)
  class(crop_soil_state_t),intent(in)::self
  type(crop_residue_pending_t),intent(out)::pending
  logical,intent(out)::present_pending
  present_pending=allocated(self%pending);pending=crop_residue_pending_t()
  if(present_pending)pending=self%pending
 end subroutine
 subroutine coupled_configuration(self,p,id)
  class(crop_soil_state_t),intent(in)::self
  type(crop_n_configuration_t),intent(out)::p
  integer(int64),intent(out)::id
  p=self%p;id=self%parameter_id
 end subroutine
 subroutine initialize_crop_soil(soil,crop,p,id,state,status,pending)
  type(reactive_state_t),intent(in)::soil
  type(wofost81_crop_owner_state_t),intent(in)::crop
  type(crop_n_configuration_t),intent(in)::p
  integer(int64),intent(in)::id
  type(crop_soil_state_t),intent(out)::state
  type(crop_residue_pending_t),optional,intent(in)::pending
  integer,intent(out)::status
  type(wofost_rate_parameter_bundle_t)::common
  type(wofost81_daily_parameter_contract_t)::p81
  type(reactive_parameters_t)::sp
  type(wofost81_crop_owner_state_t)::accepted_crop
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
  accepted_crop=crop
  if(allocated(p%b112_return).and..not.crop%nitrogen%b112_residue_profile)then
   if(crop%nitrogen%value%nlosses_total/=0d0.or.crop%harvested())return
   accepted_crop%nitrogen%b112_residue_profile=.true.
  endif
  v=pack_crop_n_continuation(accepted_crop)
  if(size(v)==0)return
  state%soil=soil;state%crop=accepted_crop;state%p=p;state%parameter_id=id;state%initialized=.true.
  if(present(pending))then
   allocate(state%pending,source=pending)
   if(.not.state%ready())then;state=crop_soil_state_t();return;end if
  end if
  if(.not.state%ready())then;state=crop_soil_state_t();return;end if
  status=CROP_SOIL_OK
 end subroutine
 real(real64)function crop_n_live(crop)result(total)
  type(wofost81_crop_owner_state_t),intent(in)::crop
  associate(n=>crop%nitrogen%value)
   total=(n%namountlv+n%namountst+n%namountrt+n%namountso)*1d-4
  end associate
  if(crop%nitrogen%b112_residue_profile)total=total+sum(crop%nitrogen%retained_dead_n)*1d-4
 end function
 subroutine advance_crop_soil_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm,weather,r,environment,surface_water,historical_top_water)
  type(crop_soil_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm
  type(wofost_one_day_forcing_t),intent(in)::weather
  type(crop_soil_receipt_t),intent(out)::r
  type(soil_n_day_environment_t),intent(in),optional::environment
  real(real64),intent(in),optional::surface_water,historical_top_water
  type(wofost_rate_parameter_bundle_t)::common
  type(wofost81_daily_parameter_contract_t)::p81
  type(wofost_accepted_window_aggregates_t)::a
  type(b111_reproductive_prepared_t)::reproductive_context
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
  if(allocated(state%pending))return
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
  ! cm -> m -> integrated cm can round a fully satisfied demand just below
  ! one. In the crop rate view only, restore equality within eight rounding
  ! units. Keep the raw accepted water amount in the receipt and Soil-N carrier.
  ! This does not raise water acceptance or mass tolerances and does not erase
  ! the physical water inventory; larger deficits keep their stress response.
  if(abs(a%actual_root_uptake-potential_cm)<=8d0*epsilon(1d0)* &
     max(tiny(1d0),abs(a%actual_root_uptake),abs(potential_cm))) &
    a%actual_root_uptake=potential_cm
  r%status=CROP_SOIL_PREPARE
  call prepare_wofost81_one_day_candidate(state%crop,weather,t0,t1,common,p81,state%p%update,a, &
    state%p%stem_area,state%p%storage_area,.true.,r%prepared,code)
  if(code/=WOFOST81_DAY_OK.or..not.r%prepared%ready.or..not.r%prepared%active)return
  if(allocated(state%p%b111_request))then
   call bind_b111_vegetative_request(state%p%b111_request,p81,state%crop%crop%development_stage,r%prepared,code)
   if(code/=0)return
  end if
  if(allocated(state%p%b111_reproductive))then
   call bind_b111_reproductive_request(state%p%b111_reproductive,p81,state%crop%crop%development_stage, &
     r%prepared,reproductive_context,code)
   if(code/=0)return
  end if
  d%demand_kg_m2=1d-4*r%prepared%nitrogen_request%soil_request
  d%root_depth_cm=state%p%root_depth_cm;d%tcsf_n=state%p%tcsf_n
  d%dvs=state%crop%crop%development_stage
  call state%crop%crop%derive_actual_leaf_area_index(state%p%stem_area,state%p%storage_area,d%lai,code)
  if(code/=0)return
  d%lai_crit_nupt=state%p%lai_crit_nupt
  soil_trial=state%soil
  r%status=CROP_SOIL_REACTION
  call advance_reactive_day(soil_trial,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,r%soil,d,environment,surface_water,historical_top_water)
  if(r%soil%status/=MINERAL_OK)return
  supply=r%soil%process%exchange%nsupply_total_kg_m2_day
  r%status=CROP_SOIL_APPLY
  if(allocated(state%p%b111_reproductive))then
   call apply_b111_reproductive_supply(r%prepared,reproductive_context,supply*1d4,crop_trial,r%crop,code)
  else
  call apply_wofost81_one_day_n_supply(r%prepared,p81,supply*1d4,crop_trial,r%crop,code)
  end if
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
   deallocate(v);allocate(v(0));return
  end if
  if(crop%nitrogen%b112_residue_profile)then
   associate(b=>crop%crop%biomass)
    v=[-81003d0,real(size(v),real64),v,b%cumulative_dead_root_biomass,b%cumulative_dead_stem_biomass, &
      b%cumulative_dead_leaf_biomass,b%retained_dead_biomass,crop%nitrogen%retained_dead_n]
   end associate
  endif
 end function
 recursive subroutine unpack_crop_n_owner(v,crop,status)
  real(real64),intent(in)::v(:)
  type(wofost81_crop_owner_state_t),intent(out)::crop
  integer,intent(out)::status
  real(real64),allocatable::proof(:)
  integer::n
  crop=wofost81_crop_owner_state_t();status=CROP_SOIL_INVALID
  if(size(v)>1)then
   if(v(1)==-81003d0)then
    if(.not.all(ieee_is_finite(v)))return
    if(v(2)<29d0.or.v(2)>1562d0.or.v(2)/=real(int(v(2)),real64))return
    n=int(v(2));if(size(v)/=n+9)return
    if(v(3)<0d0)return ! no nested envelope
    call unpack_crop_n_owner(v(3:2+n),crop,status);if(status/=0)return
    crop%nitrogen%b112_residue_profile=.true.
    associate(b=>crop%crop%biomass)
     b%cumulative_dead_root_biomass=v(3+n);b%cumulative_dead_stem_biomass=v(4+n)
     b%cumulative_dead_leaf_biomass=v(5+n);b%retained_dead_biomass=v(6+n:7+n)
    end associate
    crop%nitrogen%retained_dead_n=v(8+n:9+n)
    status=CROP_SOIL_INVALID
    proof=pack_crop_n_owner(crop)
    if(size(proof)/=size(v))then;crop=wofost81_crop_owner_state_t();return;endif
    if(any(proof/=v))then;crop=wofost81_crop_owner_state_t();return;endif
    status=CROP_SOIL_OK;return
   endif
  endif
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

 real(real64)function crop_soil_organic_mass(state)result(total)
  class(crop_soil_state_t),intent(in)::state
  type(reactive_parameters_t)::p
  type(soil_n_pool_state_t)::pools
  type(wofost81_harvest_record_t)::h
  integer(int64)::id,rev
  real(real64)::clock,theta
  logical::has
  call state%soil%configuration(p,id);call state%soil%snapshot(clock,theta,pools,rev)
  total=(sum(pools%fom_kg_m3)+pools%biomass_kg_m3+pools%humus_kg_m3)*p%mineral%inventory%depth_m
  if(state%crop%nitrogen%b112_residue_profile.and.allocated(state%crop%crop%biomass))then
   associate(b=>state%crop%crop%biomass)
    total=total+sum([b%root_biomass,b%living_leaf_biomass(),b%stem_biomass,b%storage_biomass,b%retained_dead_biomass])*1d-4
   end associate
  endif
  if(allocated(state%pending))total=total+sum(state%pending%dry_matter_kg_ha)*1d-4
  call state%crop%harvest_snapshot(h,has)
  if(has)then
   if(.not.h%pending_incorporated)total=total+sum(h%pending_dm)*1d-4
  end if
 end function
 real(real64)function crop_soil_whole_n(state)result(total)
  class(crop_soil_state_t),intent(in)::state
  type(reactive_parameters_t)::p
  type(soil_n_pool_state_t)::pools
  type(wofost81_harvest_record_t)::h
  integer(int64)::id,rev
  real(real64)::clock,theta
  logical::has
  call state%soil%configuration(p,id);call state%soil%snapshot(clock,theta,pools,rev)
  total=pools%nitrogen_total(p%mineral%inventory)+crop_n_live(state%crop)
  if(allocated(state%pending))total=total+state%pending%nitrogen_kg_m2()
  call state%crop%harvest_snapshot(h,has)
  if(has)then
   if(.not.h%pending_incorporated)total=total+sum(h%pending_n)*1d-4
  end if
 end function
 subroutine harvest_observation_snapshot(self,record,available)
  class(crop_soil_harvest_observation_t),intent(in)::self
  type(wofost81_harvest_record_t),intent(out)::record
  logical,intent(out)::available
  record=wofost81_harvest_record_t();available=allocated(self%event)
  if(available)record=self%record
 end subroutine
 subroutine observe_crop_soil_harvest(state,observation,status)
  type(crop_soil_state_t),intent(in)::state
  type(crop_soil_harvest_observation_t),intent(out)::observation
  integer,intent(out)::status
  logical::has
  observation=crop_soil_harvest_observation_t();status=CROP_SOIL_INVALID
  if(.not.state%ready())return
  call state%crop%harvest_snapshot(observation%record,has);if(.not.has)return
  observation%event=pack_crop_n_continuation(state%crop)
  if(size(observation%event)<59)return
  observation%event(4)=0d0 ! same observation before/after incorporation
  status=0
 end subroutine
 subroutine acknowledge_crop_soil_harvest(state,observation,r)
  type(crop_soil_state_t),intent(inout)::state
  type(crop_soil_harvest_observation_t),intent(in)::observation
  type(crop_soil_harvest_receipt_t),intent(out)::r
  type(crop_soil_state_t)::trial
  real(real64),allocatable::current(:)
  integer::code
  r=crop_soil_harvest_receipt_t()
  if(.not.state%ready().or.allocated(state%pending))return
  if(.not.allocated(observation%event))return
  current=pack_crop_n_continuation(state%crop)
  if(size(current)/=size(observation%event))return
  if(size(current)<59)return
  current(4)=0d0
  if(any(current/=observation%event))return
  trial=state
  call stage_wofost81_harvest_retired(state%crop,trial%crop,code)
  if(code/=0.or..not.trial%ready())return
  r%initial_n=crop_soil_whole_n(state);r%final_n=crop_soil_whole_n(trial)
  r%residual=r%initial_n-r%final_n
  if(abs(r%residual)>1d-12*max(1d0,r%initial_n,r%final_n))return
  state=trial;r%status=0
 end subroutine
 subroutine advance_crop_soil_fallow_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm,r,environment,surface_water,historical_top_water)
  type(crop_soil_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm
  type(crop_soil_receipt_t),intent(out)::r
  type(soil_n_day_environment_t),optional,intent(in)::environment
  real(real64),intent(in),optional::surface_water,historical_top_water
  type(crop_soil_state_t)::trial
  integer::code
  r=crop_soil_receipt_t()
  if(.not.state%ready().or..not.state%crop%harvest_retired())return
  if(allocated(state%pending))return
  if(.not.all(ieee_is_finite([root_water,potential_cm])))return
  if(root_water/=0d0.or.potential_cm/=0d0)return
  trial=state;r%status=CROP_SOIL_REACTION
  call advance_reactive_day(trial%soil,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,r%soil,environment=environment,surface_water=surface_water,historical_top_water=historical_top_water)
  if(r%soil%status/=MINERAL_OK)return
  ! Real accepted chemistry executes with no crop demand, uptake or fixation.
  if(r%soil%process%exchange%nsupply_total_kg_m2_day/=0d0)return
  r%whole_n_residual=crop_soil_whole_n(state)+r%soil%external_in- &
     crop_soil_whole_n(trial)-r%soil%external_out
  r%status=CROP_SOIL_BALANCE
  if(abs(r%whole_n_residual)>1d-12*max(1d0,crop_soil_whole_n(state),crop_soil_whole_n(trial)))return
  call stage_wofost81_fallow_continuation(state%crop,t0,t1, &
   [crop_soil_whole_n(trial),crop_soil_organic_mass(trial)],trial%crop,code)
  if(code/=0.or..not.trial%ready())return
  state=trial;r%status=0
 end subroutine
 subroutine initialize_crop_soil_successor(state,crop,p,id,r)
  type(crop_soil_state_t),intent(inout)::state
  type(wofost81_crop_owner_state_t),intent(in)::crop
  type(crop_n_configuration_t),intent(in)::p
  integer(int64),intent(in)::id
  type(crop_soil_harvest_receipt_t),intent(out)::r
  type(crop_soil_state_t)::trial
  type(wofost81_harvest_retired_t)::retired
  real(real64),allocatable::v(:)
  integer::code
  logical::has
  r=crop_soil_harvest_receipt_t()
  if(.not.state%ready().or..not.state%crop%harvest_retired())return
  if(allocated(state%pending).or..not.allocated(p%harvest))return
  call state%crop%retired_snapshot(retired,has);if(.not.has)return
  if(int(p%harvest%crop_identity,int64)<=retired%crop_identity)return
  if(.not.ieee_is_finite(p%harvest%crop_end))return
  if(p%harvest%crop_end<retired%clock)return
  v=pack_crop_n_owner(crop);if(size(v)==0.or.crop%harvested())return
  associate(n=>crop%nitrogen%value)
   if(any([n%nuptake_total,n%nfix_total,n%nlosses_total]/=0d0))return
  end associate
  call initialize_crop_soil(state%soil,crop,p,id,trial,code)
  if(code/=0)return
  r%initial_n=crop_soil_whole_n(state);r%final_n=crop_soil_whole_n(trial);r%seed_n=crop_n_live(crop)
  r%residual=r%initial_n+r%seed_n-r%final_n
  if(abs(r%residual)>1d-12*max(1d0,r%initial_n,r%final_n))return
  state=trial;r%status=0
 end subroutine

 subroutine harvest_crop_soil_boundary(state,r)
  type(crop_soil_state_t),intent(inout)::state
  type(crop_soil_harvest_receipt_t),intent(out)::r
  type(crop_soil_state_t)::trial
  type(wofost81_crop_owner_state_t)::crop
  type(wofost81_harvest_record_t)::h
  type(soil_n_pool_state_t)::pools
  real(real64)::clock,theta
  integer(int64)::rev
  integer::code
  logical::has
  r=crop_soil_harvest_receipt_t()
  if(.not.state%ready().or..not.allocated(state%p%harvest))return
  call state%soil%snapshot(clock,theta,pools,rev)
  if(rev<=0_int64)return ! requires actual completed daily chemical execution
  r%rejection_stage=1
  associate(p=>state%p%harvest)
   call prepare_wofost81_harvest(state%crop,clock,int(p%crop_identity,int64),p%crop_end,p%sw_harv, &
    p%sw_wofost,state%p%update%development_stage_end,p%policy,crop,code)
  end associate
  if(code/=0)return
  r%rejection_stage=2
  trial=state;trial%crop=crop
  call stage_wofost81_harvest_continuation_totals(crop, &
   [crop_soil_whole_n(trial),crop_soil_organic_mass(trial)],trial%crop,code)
  if(code/=0)return
  r%rejection_stage=3
  if(.not.trial%ready())return
  call crop%harvest_snapshot(h,has);if(.not.has)return
  r%rejection_stage=4
  r%initial_n=crop_soil_whole_n(state);r%final_n=crop_soil_whole_n(trial)
  r%exported_n=sum(h%exported_n)*1d-4;r%residual=r%initial_n-r%final_n-r%exported_n
  if(.not.ieee_is_finite(r%residual))return
  if(abs(r%residual)>1d-12*max(1d0,r%initial_n,r%final_n,r%exported_n))return
  r%rejection_stage=5
  if(.not.harvest_incorporation_valid(trial))return
  state=trial;r%status=0;r%rejection_stage=0
 end subroutine
 subroutine consume_crop_soil_harvest_pending(state,r)
  type(crop_soil_state_t),intent(inout)::state
  type(crop_soil_harvest_receipt_t),intent(out)::r
  type(crop_soil_state_t)::trial
  type(wofost81_crop_owner_state_t)::consumed
  type(b111_soil_n_material_t)::materials(7)
  type(b111_soil_n_split_parameters_t)::split
  type(soil_n_transfer_t)::transfer
  type(soil_n_receipt_t)::budget
  type(soil_n_pool_state_t)::pools,next
  type(reactive_parameters_t)::p
  type(reactive_state_t)::soil
  real(real64)::clock,theta,want(8),expected
  integer(int64)::id,rev
  integer::code,i,count
  r=crop_soil_harvest_receipt_t()
  if(.not.state%ready().or..not.state%crop%harvested())return
  call build_wofost81_harvest_materials(state%crop,materials(1:4),code)
  if(code/=0)return
  count=4
  if(allocated(state%pending))then
   call build_pending_residue_materials(state%pending,materials(5:7),code)
   if(code/=0)return
   count=7
  end if
  call state%soil%configuration(p,id);call state%soil%snapshot(clock,theta,pools,rev)
  if(size(p%mineral%inventory%nfrac_fom)/=8)return
  split%nfrac_fom_max=p%mineral%inventory%nfrac_fom(1);split%nfrac_fom_min=p%mineral%inventory%nfrac_fom(2)
  split%nfrac_humus=p%mineral%inventory%nfrac_humus
  split%asfa_min=p%organic_reference%asfa_fom_bio(1)+p%organic_reference%asfa_fom_hum(1)
  split%asfa_max=p%organic_reference%asfa_fom_bio(3)+p%organic_reference%asfa_fom_hum(3)
  want=[split%nfrac_fom_max,split%nfrac_fom_min,split%nfrac_fom_max,split%nfrac_fom_min, &
   split%nfrac_fom_max,split%nfrac_fom_min,split%nfrac_fom_max,split%nfrac_fom_min]
  if(any(abs(p%mineral%inventory%nfrac_fom-want)>0d0))return
  want=[split%asfa_min,split%asfa_min,split%asfa_max,split%asfa_max,split%asfa_min,split%asfa_min,split%asfa_max,split%asfa_max]
  if(any(abs(p%organic_reference%asfa_fom_bio+p%organic_reference%asfa_fom_hum-want)>1d-12))return
  expected=0d0
  do i=1,count
   expected=expected+materials(i)%application_kg_m2*materials(i)%organic_n_fraction
   call build_b111_residue_transfer(p%mineral%inventory%depth_m,materials(i),split,transfer,code)
   if(code/=0)return
   call apply_soil_n_transfer(p%mineral%inventory,pools,transfer,next,budget)
   if(budget%status/=SOIL_N_OK)return
   if(abs(budget%external_n_output_kg_m2)>0d0)return
   pools=next;r%incorporated_n=r%incorporated_n+budget%external_n_input_kg_m2
  end do
  if(abs(r%incorporated_n-expected)>1d-12)return
  call reconstruct_reactive_trusted(p,id,rev,clock,theta,pools,soil,code);if(code/=0)return
  call stage_wofost81_harvest_consumed(state%crop,consumed,code);if(code/=0)return
  trial=state;trial%soil=soil;trial%crop=consumed
  if(allocated(trial%pending))deallocate(trial%pending)
  if(.not.trial%ready())return
  r%initial_n=crop_soil_whole_n(state);r%final_n=crop_soil_whole_n(trial)
  r%residual=r%initial_n-r%final_n
  if(.not.ieee_is_finite(r%residual))return
  if(abs(r%residual)>1d-12*max(1d0,r%initial_n,r%final_n))return
  state=trial;r%status=0
 end subroutine
 logical function harvest_incorporation_valid(state)result(ok)
  type(crop_soil_state_t),intent(in)::state
  type(crop_soil_state_t)::trial
  type(crop_soil_harvest_receipt_t)::r
  type(wofost81_harvest_record_t)::h
  logical::has
  ok=state%ready();if(.not.ok)return
  if(state%crop%harvest_retired())then
   ok=.not.allocated(state%pending);return
  end if
  call state%crop%harvest_snapshot(h,has)
  if(.not.has)then;ok=.false.;return;end if
  if(h%pending_incorporated)then
   ok=.not.allocated(state%pending);return
  end if
  trial=state;call consume_crop_soil_harvest_pending(trial,r);ok=r%status==0
 end function
 function pack_crop_n_continuation(crop)result(v)
  type(wofost81_crop_owner_state_t),intent(in)::crop
  real(real64),allocatable::v(:),base(:)
  type(wofost81_harvest_record_t)::h
  type(wofost81_harvest_retired_t)::retired
  type(wofost81_crop_owner_state_t)::end_owner
  logical::has
  v=pack_crop_n_owner(crop)
  if(.not.crop%harvested())return
  if(crop%validate()/=0)return
  if(crop%harvest_retired())then
   call crop%retired_snapshot(retired,has);if(.not.has)return
   associate(n=>crop%nitrogen%value)
    v=[-81002d0,retired%clock,real(retired%crop_identity,real64),retired%continuation_totals, &
       n%nuptake_total,n%nfix_total,n%nlosses_total,n%initial_total]
   end associate
   if(crop%nitrogen%b112_residue_profile)v=[-81004d0,v]
   return
  end if
  call crop%harvest_snapshot(h,has);if(.not.has)return
  end_owner%crop=h%end_crop;end_owner%nitrogen=h%end_nitrogen
  base=pack_crop_n_owner(end_owner);if(size(base)==0)return
  v=[-81001d0,h%clock,real(h%crop_identity,real64),merge(1d0,0d0,h%pending_incorporated), &
   h%policy%return_fraction,h%policy%application_age,h%pending_dm,h%pending_n,h%exported_dm,h%exported_n,h%continuation_totals, &
   real(size(base),real64),base]
 end function
 recursive subroutine unpack_crop_n_continuation(v,crop,status)
  real(real64),intent(in)::v(:)
  type(wofost81_crop_owner_state_t),intent(out)::crop
  integer,intent(out)::status
  type(wofost81_harvest_record_t)::h
  type(wofost81_harvest_retired_t)::retired
  type(wofost81_crop_owner_state_t)::end_owner
  real(real64),allocatable::proof(:)
  integer::n
  crop=wofost81_crop_owner_state_t();status=CROP_SOIL_INVALID
  if(size(v)==0)return
  if(.not.all(ieee_is_finite(v)))return
  if(v(1)==-81004d0)then
   if(size(v)/=10)return
   if(v(2)/=-81002d0)return
   call unpack_crop_n_continuation(v(2:),crop,status);if(status/=0)return
   crop%nitrogen%b112_residue_profile=.true.
   proof=pack_crop_n_continuation(crop);status=CROP_SOIL_INVALID
   if(size(proof)/=size(v))return
   if(any(proof/=v))return
   status=0;return
  endif
  if(v(1)==-81002d0)then
   if(size(v)/=9)return
   if(any(abs(v)>1d9))return
   if(v(3)<1d0.or.v(3)>1d6.or.v(3)/=real(int(v(3)),real64))return
   retired%clock=v(2);retired%crop_identity=int(v(3),int64);retired%continuation_totals=v(4:5)
   associate(n=>end_owner%nitrogen%value)
    n%nuptake_total=v(6);n%nfix_total=v(7);n%nlosses_total=v(8);n%initial_total=v(9)
   end associate
   call restore_wofost81_retired_trusted(retired,end_owner%nitrogen,crop,status)
   if(status/=0)return
   proof=pack_crop_n_continuation(crop);status=CROP_SOIL_INVALID
   if(size(proof)/=size(v))return
   if(any(proof/=v))return
   status=0;return
  end if
  if(v(1)/=-81001d0)then;call unpack_crop_n_owner(v,crop,status);return;end if
  if(size(v)<59)return
  if(any(abs(v)>1d9))return
  if(v(3)<1d0.or.v(3)>1d6.or.v(3)/=real(int(v(3)),real64))return
  if(v(4)/=0d0.and.v(4)/=1d0)return
  if(v(30)<29d0.or.v(30)>1571d0)return
  n=int(v(30));if(v(30)/=real(n,real64).or.size(v)/=30+n)return
  call unpack_crop_n_owner(v(31:),end_owner,status);if(status/=0)return
  h%clock=v(2);h%crop_identity=int(v(3),int64);h%pending_incorporated=v(4)==1d0
  h%policy%return_fraction=v(5:7);h%policy%application_age=v(8:11)
  h%pending_dm=v(12:15);h%pending_n=v(16:19);h%exported_dm=v(20:23);h%exported_n=v(24:27)
  h%continuation_totals=v(28:29)
  h%end_crop=end_owner%crop;h%end_nitrogen=end_owner%nitrogen
  call restore_wofost81_harvest_trusted(h,crop,status);if(status/=0)return
  proof=pack_crop_n_continuation(crop)
  status=CROP_SOIL_INVALID
  if(size(proof)/=size(v))return
  if(any(abs(proof-v)>0d0))return
  status=0
 end subroutine

end module

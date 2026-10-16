program test_calendar_empty_day
 use iso_fortran_env,only:real64,int64
 use mod_soil_n_amendment_calendar
 use mod_crop_soil_n_calendar_day
 use mod_crop_soil_n_senescence_day
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_crop_soil_n_material_day
 use mod_b111_soil_n_addition
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 use mod_wofost_one_day_structural_evolution
 use mod_crop_senescence_residue
 use mod_soil_n_day_environment
 implicit none
 type(soil_n_amendment_calendar_t)::plan
 type(reactive_parameters_t)::sp
 type(reactive_state_t)::soil,left_soil,right_soil
 type(crop_n_configuration_t)::cp
 type(wofost81_crop_owner_state_t)::crop,left_crop,right_crop
 type(crop_soil_state_t)::scheduled,manual
 type(soil_n_pool_state_t)::pools,l,r
 type(soil_n_material_input_t)::items(2)
 type(b111_soil_n_split_parameters_t)::split
 type(crop_senescence_policy_t)::policy
 type(crop_residue_pending_t)::lp,rp
 type(senescence_day_receipt_t)::a,b
 type(wofost_one_day_forcing_t)::weather
 type(soil_n_day_environment_t)::env
 integer::code
 integer(int64)::lr,rr
 real(real64)::lt,rt,lw,rw
 logical::lh,rh
 call parameters(sp);call materials(items,split);call configure_crop(cp)
 cp%base%nitrogen%nfix_fr=.3d0;cp%update%leaf_lifespan=1.5d0;cp%lai_crit_nupt=1d0
 call configure_owner(crop,cp,code)
 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 call initialize_soil_n_pool_state(sp%mineral%inventory,spread(1d0,1,8),5d0,40d0,.02d0,.03d0,pools,code)
 call initialize_reactive(sp,9001_int64,0d0,.34d0,pools,soil,code)
 call initialize_crop_soil(soil,crop,cp,9101_int64,scheduled,code);manual=scheduled
 policy%application_age=[1.57d0,.99d0,1.57d0];env=soil_n_day_environment_t(0d0,1d0,5d0)
 block
  type(b111_soil_n_material_t)::future(1)
  future=items(1)%material;future%application_kg_m2=0d0
  call create_soil_n_amendment_calendar(0d0,[3d0],[400d0],future,plan,code)
 end block
 call require(code==0,'future schedule initialize')
 call advance_crop_soil_calendar_day(scheduled,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,plan,split,policy,a,env)
 call advance_crop_soil_senescence_day(manual,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items(:0),split,policy,b,env)
 call require(a%status==0.and.b%status==0.and.a%materials%gross_n==0d0,'no premature scheduled input')
 call scheduled%snapshot(left_soil,left_crop);call manual%snapshot(right_soil,right_crop)
 call left_soil%snapshot(lt,lw,l,lr);call right_soil%snapshot(rt,rw,r,rr)
 call scheduled%pending_snapshot(lp,lh);call manual%pending_snapshot(rp,rh)
 call require(lt==rt.and.lw==rw.and.lr==rr.and.all(pack_crop_n_owner(left_crop)==pack_crop_n_owner(right_crop)),'empty day full crop/clock identity')
 call require(all(l%fom_kg_m3==r%fom_kg_m3).and.l%biomass_kg_m3==r%biomass_kg_m3.and. &
  l%humus_kg_m3==r%humus_kg_m3.and.l%ammonium_n_kg_m2==r%ammonium_n_kg_m2.and. &
  l%nitrate_n_kg_m2==r%nitrate_n_kg_m2,'empty day all soil pools identity')
 call require(lh.and.rh.and.lp%clock==rp%clock.and.all(lp%dry_matter_kg_ha==rp%dry_matter_kg_ha).and. &
  all(lp%nitrogen_kg_ha==rp%nitrogen_kg_ha).and.all(lp%application_age==rp%application_age),'empty day actual pending identity')
 print '(A)','CALENDAR_NO_EVENT_ACTUAL_CROP_SOIL_PENDING_EXACT_IDENTITY=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,'FAIL ',label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'material_fixture.inc'
end program

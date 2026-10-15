program test_senescence_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_senescence_residue
 use mod_crop_soil_n_senescence_day
 use mod_crop_soil_n_material_day
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_b111_soil_n_addition
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 use mod_wofost_one_day_structural_evolution
 use mod_soil_n_day_environment
 implicit none
 type(reactive_parameters_t)::sp,oracle_p
 type(reactive_state_t)::soil,outsoil
 type(crop_n_configuration_t)::cp
 type(crop_soil_state_t)::state,initial,ordinary,before
 type(wofost81_crop_owner_state_t)::crop,outcrop
 type(soil_n_pool_state_t)::pools,got,want,staged,oldpools
 type(soil_n_material_input_t)::items(2),bad(2)
 type(b111_soil_n_split_parameters_t)::split
 type(crop_senescence_policy_t)::policy,invalid
 type(crop_residue_pending_t)::pending,next_pending
 type(b111_soil_n_material_t)::m(3)
 type(senescence_day_receipt_t)::r
 type(material_day_receipt_t)::oldr
 type(wofost_one_day_forcing_t)::weather
 type(soil_n_day_environment_t)::env
 real(real64)::clock,theta,literal(12),nit,denit,carbon,supply,oldclock,oldwater,dvs_before,lai_before
 real(real64),allocatable::v(:),v0(:)
 integer(int64)::rev,oldrev
 integer::code,i
 logical::has
 call parameters(sp);call materials(items,split);call configure_crop(cp)
 cp%base%nitrogen%nfix_fr=.3d0;cp%update%leaf_lifespan=.5d0
 call configure_owner(crop,cp,code)
 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 call initialize_soil_n_pool_state(sp%mineral%inventory,spread(1d0,1,8),5d0,40d0,.02d0,.03d0,pools,code)
 call initialize_reactive(sp,9001_int64,0d0,.34d0,pools,soil,code)
 call initialize_crop_soil(soil,crop,cp,9101_int64,initial,code);call require(code==0,'initial')
 policy%application_age=[1.57d0,.99d0,1.57d0];env=soil_n_day_environment_t(0d0,1d0,5d0)
 state=initial;ordinary=initial
 call advance_crop_soil_material_day(ordinary,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,oldr,env)
 call advance_crop_soil_senescence_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,policy,r,env)
 if(r%status/=0)print *,'diagnostic',r%status,r%materials%status
 call require(r%status==0.and.r%incorporated_n==0d0.and.r%pending_n>0d0,'actual day death retained')
 call state%pending_snapshot(pending,has);call require(has.and.all(pending%dry_matter_kg_ha>0d0),'all3 actual death including ageing')
 call state%snapshot(outsoil,outcrop);call outsoil%snapshot(clock,theta,got,rev);v=pack_crop_n_owner(outcrop)
 call ordinary%snapshot(outsoil,outcrop);call outsoil%snapshot(oldclock,oldwater,want,oldrev)
 call require(all(v==pack_crop_n_owner(outcrop)).and.all(got%fom_kg_m3==want%fom_kg_m3).and. &
  got%ammonium_n_kg_m2==want%ammonium_n_kg_m2.and.got%nitrate_n_kg_m2==want%nitrate_n_kg_m2,'today no premature incorporation and single crop debit')
 before=state;oldpools=got;v0=v
 call advance_crop_soil_material_day(state,1d0,2d0,theta-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,oldr)
 call require(oldr%status/=0,'old route cannot discard pending');call unchanged()
 do i=1,4
  invalid=policy;state=before;bad=items
  select case(i)
  case(1);invalid%application_age(3)=.66d0
  case(2);invalid%application_age(1)=100d0
  case(3);bad(2)%kind=999
  case(4);invalid%application_age(2)=ieee_value(0d0,ieee_quiet_nan)
  end select
  env=soil_n_day_environment_t(1d0,2d0,30d0)
  call advance_crop_soil_senescence_day(state,1d0,2d0,theta-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,bad,split,invalid,r,env)
  call require(r%status/=0,'late failed next day');call unchanged()
 end do
 call before%snapshot(outsoil,outcrop);dvs_before=outcrop%crop%development_stage
 call outcrop%crop%derive_actual_leaf_area_index(cp%stem_area,cp%storage_area,lai_before,code)
 state=before;policy%application_age=[1.2d0,.92d0,.99d0]
 call advance_crop_soil_senescence_day(state,1d0,2d0,theta-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,policy,r,env)
 if(r%status/=0)print *,'day2 diagnostic',r%status,r%materials%status
 call require(r%status==0.and.abs(r%whole_n_residual)<=1d-12.and.r%incorporated_n==pending%nitrogen_kg_m2(),'next day consumes yesterday once')
 staged=oldpools;call build_pending_residue_materials(pending,m,code)
 do i=1,5
  if(i<=3)then;call literal_material(2,m(i),split,literal)
  else;call literal_material(items(i-3)%kind,items(i-3)%material,split,literal);end if
  staged%fom_kg_m3=staged%fom_kg_m3+literal(1:8);staged%humus_kg_m3=staged%humus_kg_m3+literal(9)
  staged%ammonium_n_kg_m2=staged%ammonium_n_kg_m2+literal(10);staged%nitrate_n_kg_m2=staged%nitrate_n_kg_m2+literal(11)
 end do
 oracle_p=sp;oracle_p%environment%temperature_c=30d0
 call literal_crop_day(oracle_p,staged,theta,theta-.001d0/.3d0,0d0,0d0,0d0,.001d0,want,nit,denit,carbon, &
  r%materials%day%prepared%nitrogen_request%soil_request,dvs_before,lai_before,30d0,1d0,3d0,supply)
 call state%snapshot(outsoil,outcrop);call outsoil%snapshot(clock,oldwater,got,rev)
 call require(maxval(abs(got%fom_kg_m3-want%fom_kg_m3))<=1d-12.and. &
 abs(got%biomass_kg_m3-want%biomass_kg_m3)<=1d-12.and.abs(got%humus_kg_m3-want%humus_kg_m3)<=1d-12.and. &
 abs(got%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<=1d-12.and.abs(got%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<=1d-12,'full delayed literal next day')
 call state%pending_snapshot(next_pending,has);call require(has.and.all(next_pending%application_age==policy%application_age),'next policy belongs only to new material')
 before=state;oldpools=got;v0=pack_crop_n_owner(outcrop)
 call advance_crop_soil_senescence_day(state,1d0,2d0,oldwater,0d0,0d0,0d0,0d0,.1d0,weather,items,split,policy,r,env)
 call require(r%status/=0,'consumed day cannot replay')
 call state%snapshot(outsoil,outcrop);call require(all(v0==pack_crop_n_owner(outcrop)),'replay full crop identity')
 print '(A)','SENESCENCE_REAL_DAY_DELAYED_3_ORGANS_LITERAL_WHOLE_N_ROLLBACK_REPLAY=PASS'
contains
 subroutine unchanged()
 type(crop_residue_pending_t)::p
 logical::present_pending
 call state%snapshot(outsoil,outcrop);call outsoil%snapshot(clock,oldwater,got,rev)
 call state%pending_snapshot(p,present_pending)
 call require(present_pending.and.all(p%dry_matter_kg_ha==pending%dry_matter_kg_ha).and. &
  all(p%nitrogen_kg_ha==pending%nitrogen_kg_ha).and.all(pack_crop_n_owner(outcrop)==v0).and.clock==1d0.and.rev==1,'pending crop clock rollback')
 call require(all(got%fom_kg_m3==oldpools%fom_kg_m3).and.got%ammonium_n_kg_m2==oldpools%ammonium_n_kg_m2.and. &
 got%nitrate_n_kg_m2==oldpools%nitrate_n_kg_m2,'soil rollback')
 end subroutine
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print *,'FAIL ',label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'material_fixture.inc'
 include 'material_oracle.inc'
 include 'crop_oracle.inc'
end program

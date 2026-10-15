program test_material_environment_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_soil_n_addition
 use mod_crop_soil_n_material_day
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 use mod_wofost_one_day_structural_evolution
 use mod_soil_n_day_environment
 implicit none
 type(soil_n_day_environment_t)::env,bad_env
 type(reactive_parameters_t)::oracle_p
 type(reactive_parameters_t)::sp
 type(reactive_state_t)::soil,outsoil
 type(crop_n_configuration_t)::cp
 type(crop_soil_state_t)::state,initial,reference
 type(wofost81_crop_owner_state_t)::crop,outcrop
 type(soil_n_pool_state_t)::pools,got,want,staged
 type(soil_n_material_input_t)::items(2),bad(2),too_many(65)
 type(b111_soil_n_split_parameters_t)::split,wrong
 type(material_day_receipt_t)::r
 type(crop_soil_receipt_t)::oldr
 type(wofost_one_day_forcing_t)::weather,invalid
 real(real64)::time,theta,nit,denit,carbon,supply,literal(12),saved(13)
 real(real64)::cold_soil(13)
 real(real64),allocatable::cold_crop(:)
 real(real64),allocatable::v(:),v0(:),v1(:)
 integer(int64)::revision
 integer::code,i
 env=soil_n_day_environment_t(0d0,1d0,5d0)
 call parameters(sp);call materials(items,split);call configure_crop(cp)
 cp%base%nitrogen%nfix_fr=.3d0;call configure_owner(crop,cp,code)
 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 call initialize_soil_n_pool_state(sp%mineral%inventory,spread(1d0,1,8),5d0,40d0,.02d0,.03d0,pools,code)
 call initialize_reactive(sp,9001_int64,0d0,.34d0,pools,soil,code)
 call initialize_crop_soil(soil,crop,cp,9101_int64,initial,code);call require(code==0,'initialize actual owners')
 v0=pack_crop_n_owner(crop);saved=[pools%fom_kg_m3,pools%biomass_kg_m3,pools%humus_kg_m3, &
   pools%ammonium_n_kg_m2,pools%nitrate_n_kg_m2,.34d0]
 state=initial;staged=pools
 do i=1,2
  call literal_material(items(i)%kind,items(i)%material,split,literal)
  staged%fom_kg_m3=staged%fom_kg_m3+literal(1:8);staged%humus_kg_m3=staged%humus_kg_m3+literal(9)
  staged%ammonium_n_kg_m2=staged%ammonium_n_kg_m2+literal(10);staged%nitrate_n_kg_m2=staged%nitrate_n_kg_m2+literal(11)
 end do
 call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,r,env)
 if(r%status/=0)print *,'diagnostic',r%status,r%day%status
 call require(r%status==MATERIAL_OK.and.r%material_count==2,'actual material plus WOFOST81 day')
 call require(r%gross_n>0d0.and.r%volatilized_n>0d0.and.abs(r%residual)<=1d-12,'gross volatility whole N')
 call require(r%day%fixation_kg_m2>0d0.and.r%day%crop_loss_kg_m2>0d0,'actual fixation and senescence unchanged')
 oracle_p=sp;oracle_p%environment%temperature_c=env%temperature_c
 call require(r%day%soil%environment_forcing_used.and.r%day%soil%temperature_used_c==5d0,'explicit temperature after material')
 call literal_crop_day(oracle_p,staged,.34d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,want,nit,denit,carbon, &
   r%day%prepared%nitrogen_request%soil_request,.5d0,4d0,30d0,1d0,3d0,supply)
 call state%snapshot(outsoil,outcrop);call outsoil%snapshot(time,theta,got,revision)
 call require(maxval(abs(got%fom_kg_m3-want%fom_kg_m3))<=1d-12.and. &
   abs(got%biomass_kg_m3-want%biomass_kg_m3)<=1d-12.and.abs(got%humus_kg_m3-want%humus_kg_m3)<=1d-12,'full literal eight organic pools')
 call require(abs(got%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<=1d-12.and. &
   abs(got%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<=1d-12.and.abs(supply-r%day%internal_supply_kg_m2)<=1d-12,'literal mineral supply')
 call require(time==1d0.and.revision==1,'same sole daily clock and revision')
 v=pack_crop_n_owner(outcrop);cold_crop=v
 cold_soil=[got%fom_kg_m3,got%biomass_kg_m3,got%humus_kg_m3,got%ammonium_n_kg_m2,got%nitrate_n_kg_m2,theta]
 call advance_crop_soil_material_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,.1d0,weather,items,split,r,env)
 call require(r%status/=0,'batch replay rejected');call state%snapshot(outsoil,outcrop);v1=pack_crop_n_owner(outcrop)
 call require(all(v1==v),'replay no crop leak')
 do i=1,9
  state=initial;bad=items;wrong=split
  select case(i)
  case(1);bad(2)%kind=999
  case(2);bad(2)%material%application_kg_m2=ieee_value(0d0,ieee_quiet_nan)
  case(3);bad(2)%material%application_kg_m2=-1d0
  case(4);bad(2)%material%application_kg_m2=1d100
  case(5);wrong%nfrac_fom_max=.061d0
  case(6);wrong%nfrac_humus=.05d0
  case(7);wrong%asfa_max=.27d0
  case(8);bad(2)%material%application_kg_m2=1d-14
  case(9);bad(2)%material%organic_n_fraction=0d0
  end select
  call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,bad,wrong,r,env)
  call require(r%status/=0,'late invalid batch rejected');call unchanged()
 end do
 state=initial;invalid=weather;invalid%average_temperature=ieee_value(0d0,ieee_quiet_nan)
 call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,invalid,items,split,r,env)
 call require(r%status/=0,'late crop day rejection');call unchanged()
 do i=1,7
  state=initial;bad_env=env
  select case(i)
  case(1);bad_env%temperature_c=ieee_value(0d0,ieee_quiet_nan)
  case(2);bad_env%temperature_c=-20.01d0
  case(3);bad_env%temperature_c=60.01d0
  case(4);bad_env%t0=-1d0
  case(5);bad_env%t1=2d0
  case(6);bad_env%t0=huge(1d0)
  case(7);bad_env%t1=ieee_value(0d0,ieee_quiet_nan)
  end select
  call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,r,bad_env)
  call require(r%status/=0,'material plus invalid environment rejected');call unchanged()
 end do
 too_many=items(1)
 call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,too_many,split,r,env)
 call require(r%status/=0,'bounded batch rejected');call unchanged()
 call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,r,env)
 call require(r%status==0,'valid retry');call state%snapshot(outsoil,outcrop);v1=pack_crop_n_owner(outcrop)
 call require(all(v1==v),'retry exact crop continuation')
 state=initial;reference=initial
 call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items(:0),split,r,env)
 call advance_crop_soil_day(reference,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,oldr,env)
 call require(r%status==0.and.oldr%status==0,'empty batch incumbent route')
 call state%snapshot(outsoil,outcrop);v=pack_crop_n_owner(outcrop);call outsoil%snapshot(time,theta,got,revision)
 call reference%snapshot(outsoil,outcrop);v1=pack_crop_n_owner(outcrop);call outsoil%snapshot(time,theta,want,revision)
 call require(all(v==v1).and.all(got%fom_kg_m3==want%fom_kg_m3).and. &
   got%ammonium_n_kg_m2==want%ammonium_n_kg_m2.and.got%nitrate_n_kg_m2==want%nitrate_n_kg_m2,'empty byte identity')
 ! Reuse initial authority at another temperature; cold/warm/cold isolation.
 state=initial;env%temperature_c=30d0
 call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,r,env)
 call require(r%status==0,'warm material day')
 oracle_p=sp;oracle_p%environment%temperature_c=30d0
 call literal_crop_day(oracle_p,staged,.34d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,want,nit,denit,carbon, &
   r%day%prepared%nitrogen_request%soil_request,.5d0,4d0,30d0,1d0,3d0,supply)
 call state%snapshot(outsoil,outcrop);call outsoil%snapshot(time,theta,got,revision)
 call require(maxval(abs(got%fom_kg_m3-want%fom_kg_m3))<=1d-12.and. &
 abs(got%biomass_kg_m3-want%biomass_kg_m3)<=1d-12.and.abs(got%humus_kg_m3-want%humus_kg_m3)<=1d-12.and. &
 abs(got%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<=1d-12.and. &
 abs(got%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<=1d-12.and.abs(supply-r%day%internal_supply_kg_m2)<=1d-12,'warm full literal state')
 state=initial;env%temperature_c=5d0
 call advance_crop_soil_material_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,r,env)
 call require(r%status==0,'cold A B A retry');call state%snapshot(outsoil,outcrop);v1=pack_crop_n_owner(outcrop)
 ! Compare to a fresh cold execution, including all organic/mineral stores.
 reference=initial
 call advance_crop_soil_material_day(reference,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items,split,r,env)
 call reference%snapshot(outsoil,outcrop);v=pack_crop_n_owner(outcrop)
 call require(all(v==v1).and.all(v1==cold_crop),'A B A crop identity')
 call state%snapshot(outsoil,outcrop);call outsoil%snapshot(time,theta,got,revision)
 call require(all([got%fom_kg_m3,got%biomass_kg_m3,got%humus_kg_m3,got%ammonium_n_kg_m2,got%nitrate_n_kg_m2,theta]==cold_soil),'A B A full soil identity')
 call require(env%t0==0d0.and.env%t1==1d0.and.env%temperature_c==5d0.and.sp%environment%temperature_c==20d0,'forcing and configuration nonmutation')
 print '(A)','MATERIAL_ENVIRONMENT_DAY_LITERAL_5_30_ATOMIC_7_INVALID_ABA_EMPTY=PASS' 
contains
 subroutine unchanged()
 call state%snapshot(outsoil,outcrop);v1=pack_crop_n_owner(outcrop);call outsoil%snapshot(time,theta,got,revision)
 call require(all(v0==v1).and.time==0d0.and.revision==0,'full crop and clock rollback')
 call require(all([got%fom_kg_m3,got%biomass_kg_m3,got%humus_kg_m3, &
   got%ammonium_n_kg_m2,got%nitrate_n_kg_m2,theta]==saved),'full soil rollback')
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

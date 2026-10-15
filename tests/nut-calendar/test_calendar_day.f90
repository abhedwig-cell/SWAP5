program test_calendar_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_amendment_calendar
 use mod_b111_soil_n_addition
 use mod_crop_soil_n_calendar_day
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
 type(amendment_calendar_t)::calendar,empty,bad_calendar,uninitialized
 type(amendment_calendar_row_t)::rows(1)
 type(b111_soil_n_material_t)::defs(1)
 type(soil_n_day_environment_t)::env,bad_env
 type(reactive_parameters_t)::sp,oracle_p
 type(reactive_state_t)::soil,outsoil
 type(crop_n_configuration_t)::cp
 type(crop_soil_state_t)::state,initial,reference,first
 type(wofost81_crop_owner_state_t)::crop,outcrop
 type(soil_n_pool_state_t)::pools,got,want,staged
 type(soil_n_material_input_t)::items(2)
 type(b111_soil_n_split_parameters_t)::split,wrong
 type(material_day_receipt_t)::r,explicit
 type(wofost_one_day_forcing_t)::weather,invalid
 real(real64)::time,theta,nit,denit,carbon,supply,literal(12)
 integer(int64)::revision
 integer::code,i
 call parameters(sp);call materials(items,split);call configure_crop(cp)
 cp%base%nitrogen%nfix_fr=.3d0;call configure_owner(crop,cp,code)
 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 defs(1)=items(1)%material;defs(1)%application_kg_m2=0d0;defs(1)%volatilization_fraction=0d0
 rows(1)=amendment_calendar_row_t(0d0,400d0,.25d0,1)
 call initialize_amendment_calendar(0d0,3d0,rows,defs,calendar,code);call require(code==0,'construct dated application')
 call initialize_amendment_calendar(0d0,3d0,rows(:0),defs(:0),empty,code);call require(code==0,'construct empty calendar')
 defs(1)%organic_n_fraction=0d0
 call initialize_amendment_calendar(0d0,3d0,rows,defs,bad_calendar,code)
 call require(code==0,'syntactic forcing not a substitute for physical material domain')
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 call initialize_soil_n_pool_state(sp%mineral%inventory,spread(1d0,1,8),5d0,40d0,.02d0,.03d0,pools,code)
 call initialize_reactive(sp,9001_int64,0d0,.34d0,pools,soil,code)
 call initialize_crop_soil(soil,crop,cp,9101_int64,initial,code);call require(code==0,'initialize actual owners')
 env=soil_n_day_environment_t(0d0,1d0,5d0);state=initial;reference=initial
 call advance_crop_soil_calendar_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,calendar,split,r,env)
 call require(r%status==0.and.r%material_count==1,'calendar actual crop soil day')
 call advance_crop_soil_material_day(reference,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items(:1),split,explicit,env)
 call require(explicit%status==0,'explicit material comparator');call same(state,reference)
 staged=pools;call literal_material(MATERIAL_AMENDMENT,items(1)%material,split,literal)
 staged%fom_kg_m3=staged%fom_kg_m3+literal(1:8);staged%humus_kg_m3=staged%humus_kg_m3+literal(9)
 staged%ammonium_n_kg_m2=staged%ammonium_n_kg_m2+literal(10);staged%nitrate_n_kg_m2=staged%nitrate_n_kg_m2+literal(11)
 oracle_p=sp;oracle_p%environment%temperature_c=5d0
 call literal_crop_day(oracle_p,staged,.34d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,want,nit,denit,carbon, &
   r%day%prepared%nitrogen_request%soil_request,.5d0,4d0,30d0,1d0,3d0,supply)
 call state%snapshot(outsoil,outcrop);call outsoil%snapshot(time,theta,got,revision)
 call require(maxval(abs(got%fom_kg_m3-want%fom_kg_m3))<=1d-12.and. &
   abs(got%biomass_kg_m3-want%biomass_kg_m3)<=1d-12.and.abs(got%humus_kg_m3-want%humus_kg_m3)<=1d-12, &
   'original complete literal organic endpoints')
 call require(abs(got%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<=1d-12.and. &
   abs(got%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<=1d-12.and.abs(supply-r%day%internal_supply_kg_m2)<=1d-12,'original literal mineral supply')
 call require(abs(r%residual)<=1d-12.and.r%gross_n>0d0.and.r%volatilized_n>0d0,'calendar whole N external input/output')
 first=state
 call advance_crop_soil_calendar_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,.1d0,weather,calendar,split,r,env)
 call require(r%status/=0,'daily clock rejects calendar replay');call same(state,first)
 do i=1,5
  state=initial;wrong=split;invalid=weather;bad_env=env
  select case(i)
  case(1)
   call advance_crop_soil_calendar_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,.1d0,weather,uninitialized,split,r,env)
  case(2)
   call advance_crop_soil_calendar_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,.1d0,weather,bad_calendar,split,r,env)
  case(3)
   wrong%nfrac_humus=.05d0
   call advance_crop_soil_calendar_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,.1d0,weather,calendar,wrong,r,env)
  case(4)
   invalid%average_temperature=ieee_value(0d0,ieee_quiet_nan)
   call advance_crop_soil_calendar_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,.1d0,invalid,calendar,split,r,env)
  case(5)
   bad_env%temperature_c=ieee_value(0d0,ieee_quiet_nan)
   call advance_crop_soil_calendar_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,.1d0,weather,calendar,split,r,bad_env)
  end select
  call require(r%status/=0,'invalid calendar/material/forcing rejected');call same(state,initial)
 end do
 call advance_crop_soil_calendar_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,calendar,split,r,env)
 call require(r%status==0,'calendar retry succeeds');call same(state,first)
 ! An accepted no-event day executes ordinary real reactions and crop; no extra N.
 reference=state;env=soil_n_day_environment_t(1d0,2d0,30d0)
 call advance_crop_soil_calendar_day(state,1d0,2d0,.34d0-.002d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,calendar,split,r,env)
 call advance_crop_soil_material_day(reference,1d0,2d0,.34d0-.002d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,items(:0),split,explicit,env)
 call require(r%status==0.and.explicit%status==0.and.r%gross_n==0d0.and.r%material_count==0,'no-event real next day')
 call same(state,reference)
 print '(A)','CALENDAR_REAL_WOFOST81_LITERAL_EVENT_NONE_ATOMIC_RETRY_REPLAY=PASS'
contains
 subroutine same(a,b)
  type(crop_soil_state_t),intent(in)::a,b
  type(reactive_state_t)::sa,sb
  type(wofost81_crop_owner_state_t)::ca,cb
  type(soil_n_pool_state_t)::pa,pb
  real(real64)::ta,tb,wa,wb
  integer(int64)::ra,rb
  call a%snapshot(sa,ca);call b%snapshot(sb,cb)
  call sa%snapshot(ta,wa,pa,ra);call sb%snapshot(tb,wb,pb,rb)
  call require(ta==tb.and.wa==wb.and.ra==rb.and.all(pack_crop_n_owner(ca)==pack_crop_n_owner(cb)),'complete owner clock crop identity')
  call require(all(pa%fom_kg_m3==pb%fom_kg_m3).and.pa%biomass_kg_m3==pb%biomass_kg_m3.and.pa%humus_kg_m3==pb%humus_kg_m3.and. &
    pa%ammonium_n_kg_m2==pb%ammonium_n_kg_m2.and.pa%nitrate_n_kg_m2==pb%nitrate_n_kg_m2,'complete soil identity')
 end subroutine
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'material_fixture.inc'
 include 'material_oracle.inc'
 include 'crop_oracle.inc'
end program

program test_environment_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_b111_soil_n_reactive_owner
 use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
 use mod_soil_n_pool_state
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state,WOFOST81_N_OWNER_OK
 use mod_wofost81_daily_parameter_contract
 use mod_wofost_rate_parameters
 use mod_wofost_one_day_structural_evolution
 use mod_soil_n_day_environment
 implicit none
 type(crop_n_configuration_t)::p,bad
 type(soil_n_day_environment_t)::env,invalid
 type(reactive_parameters_t)::oracle_p
 type(reactive_parameters_t)::sp
 type(soil_n_pool_state_t)::pools,actual,want
 type(reactive_state_t)::soil,out_soil
 type(wofost81_crop_owner_state_t)::crop,out_crop,reconstructed
 type(crop_soil_state_t)::state,previous,a_reference
 type(crop_soil_receipt_t)::r
 type(wofost_one_day_forcing_t)::weather
 real(real64),allocatable::v(:),v0(:),v1(:)
 real(real64)::theta,time,nit,denit,carbon,supply,oldtotal
 integer(int64)::revision
 integer::status,i,j
 env=soil_n_day_environment_t(0d0,1d0,7.5d0)
 call parameters(sp);call configure_crop(p);call configure_owner(crop,p,status)
 call require(status==0,'original WOFOST81 crop N initialization')
 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 do i=1,4
  do j=1,2
   call configure_crop(p);p%base%nitrogen%nfix_fr=merge(.3d0,0d0,j==2)
   call initialize_soil_n_pool_state(sp%mineral%inventory,[10d0,20d0],5d0,40d0, &
     .02d0*real(i,real64),.03d0,pools,status)
   if(i==2)then
    pools%ammonium_n_kg_m2=1d0;pools%nitrate_n_kg_m2=1d0
   end if
   if(i==3)then
    pools%fom_kg_m3=0d0;pools%biomass_kg_m3=0d0;pools%humus_kg_m3=0d0
    pools%ammonium_n_kg_m2=1d-10;pools%nitrate_n_kg_m2=1d-10
   end if
   theta=.34d0
   call initialize_reactive(sp,9001_int64,0d0,theta,pools,soil,status)
   call initialize_crop_soil(soil,crop,p,9101_int64,state,status);call require(status==0,'coupled initialize')
   previous=state
   call advance_crop_soil_day(state,0d0,1d0,theta-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,r,env)
   if(r%status/=0)print *,'diagnostic case',i,j,r%status,r%soil%status,r%prepared%nitrogen_request%status
   call require(r%status==0,'real WOFOST81 request to reactive N accept')
   call require(r%prepared%nitrogen_request%soil_request>0d0,'nonzero demand')
   call require(r%internal_supply_kg_m2>0d0,'actual soil supply')
   call require(abs(r%whole_n_residual)<=1d-12,'whole soil plus crop N')
   call require(r%crop_loss_kg_m2>0d0,'explicit senescence N output')
   if(j==2)call require(r%fixation_kg_m2>0d0,'WOFOST81 fixation preserved')
   if(i==2)call require(abs(r%internal_supply_kg_m2-1d-4*r%prepared%nitrogen_request%soil_request)<1d-12,'ample supply')
   if(i==3)call require(r%internal_supply_kg_m2<.5d-4*r%prepared%nitrogen_request%soil_request,'exhausted limited supply')
   oracle_p=sp;oracle_p%environment%temperature_c=env%temperature_c
   call require(r%soil%environment_forcing_used.and.r%soil%temperature_used_c==7.5d0,'explicit soil temperature used')
   call literal_crop_day(oracle_p,pools,theta,theta-.001d0/.3d0,0d0,0d0,0d0,.001d0,want,nit,denit,carbon, &
    r%prepared%nitrogen_request%soil_request,crop%crop%development_stage,4d0,30d0,1d0,3d0,supply)
   call state%snapshot(out_soil,out_crop);call out_soil%snapshot(time,theta,actual,revision)
   call require(abs(supply-r%internal_supply_kg_m2)<1d-12,'literal complete historical uptake branch')
   call require(abs(actual%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<1d-12.and. &
     abs(actual%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<1d-12,'literal actual NH4 NO3 endpoints')
   call require(time==1d0.and.revision==1,'one authoritative consumed soil clock')
   call require(out_crop%crop%development_stage>crop%crop%development_stage,'real crop development')
   v=pack_crop_n_owner(out_crop);call unpack_crop_n_owner(v,reconstructed,status)
   call require(status==0,'crop full owner codec');v1=pack_crop_n_owner(reconstructed)
   call require(all(v==v1),'crop codec bit identity')
   call advance_crop_soil_day(state,0d0,1d0,theta,0d0,0d0,0d0,0d0,0d0,weather,r)
   call require(r%status/=0,'replay rejected')
   call state%snapshot(out_soil,out_crop);v1=pack_crop_n_owner(out_crop);call require(all(v==v1),'replay no crop leak')
  end do
 end do
 a_reference=state
 ! Invalid temperature/time inputs must not change any of the three soil stores,
 ! crop cohorts, nitrogen ledger, clock, parameter vector or revision.
 do i=1,10
  invalid=env
  select case(i)
  case(1);invalid%temperature_c=ieee_value(0d0,ieee_quiet_nan)
  case(2);invalid%temperature_c=huge(1d0)
  case(3);invalid%temperature_c=-20.01d0
  case(4);invalid%temperature_c=60.01d0
  case(5);invalid%t0=1d0;invalid%t1=2d0
  case(6);invalid%t1=.5d0
  case(7);invalid%t0=ieee_value(0d0,ieee_quiet_nan)
  case(8);invalid%t0=huge(1d0);invalid%t1=-huge(1d0)
  case(9);invalid%t0=1d9+1d0;invalid%t1=1d9+2d0
  case(10);invalid%t1=1d0+epsilon(1d0)
  end select
  state=previous
  call advance_crop_soil_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,r,invalid)
  call require(r%status/=0,'invalid prescribed environment rejected')
  call assert_same(previous,state,'invalid environment atomic rollback')
 end do
 ! Explicit equal temperature and the absent optional argument have identical
 ! full state. A/B/A proves no retained temperature changes immutable config.
 do i=1,5
  select case(i)
  case(1);env%temperature_c=-20d0
  case(2);env%temperature_c=0d0
  case(3);env%temperature_c=20d0
  case(4);env%temperature_c=40d0
  case(5);env%temperature_c=60d0
  end select
  state=previous;oracle_p=sp;oracle_p%environment%temperature_c=env%temperature_c
  call advance_crop_soil_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,r,env)
  if(i==1.or.i==5)then
   block
    type(reactive_state_t)::fixed_soil
    type(crop_soil_state_t)::fixed_state
    type(crop_soil_receipt_t)::fixed_r
    call initialize_reactive(oracle_p,9001_int64,0d0,.34d0,pools,fixed_soil,status)
    call initialize_crop_soil(fixed_soil,crop,p,9101_int64,fixed_state,status)
    call advance_crop_soil_day(fixed_state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,fixed_r)
    call require(r%status/=0.and.r%status==fixed_r%status.and. &
      r%soil%process%status==fixed_r%soil%process%status,'original extreme-rate guard preserved')
    call assert_same(previous,state,'extreme-rate complete rollback')
   end block
   cycle
  end if
  call require(r%status==0,'ordinary variable environment domain')
  call literal_crop_day(oracle_p,pools,.34d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,want,nit,denit,carbon, &
    r%prepared%nitrogen_request%soil_request,.5d0,4d0,30d0,1d0,3d0,supply)
  call state%snapshot(out_soil,out_crop);call out_soil%snapshot(time,theta,actual,revision)
  call require(abs(actual%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<1d-12.and. &
    abs(actual%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<1d-12,'temperature-domain literal transport')
  if(i==3)then
   block
    type(crop_soil_state_t)::absent
    type(crop_soil_receipt_t)::other
    absent=previous
    call advance_crop_soil_day(absent,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,other)
    call require(other%status==0.and..not.other%soil%environment_forcing_used,'absent forcing legacy mode')
    call assert_same(absent,state,'equal-temperature absent-mode preservation')
   end block
  end if
 end do
 env%temperature_c=7.5d0;state=previous
 call advance_crop_soil_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,r,env)
 call require(r%status==0,'A/B/A repeat accepts')
 call assert_same(a_reference,state,'A/B/A no retained temperature')
 print '(A)','DAILY_ENVIRONMENT_LITERAL_SUPPLY_ROLLBACK_IDENTITY=PASS' 
contains
 subroutine assert_same(a,b,label)
  type(crop_soil_state_t),intent(in)::a,b
  character(*),intent(in)::label
  type(reactive_state_t)::sa,sb
  type(wofost81_crop_owner_state_t)::ca,cb
  type(soil_n_pool_state_t)::pa,pb
  type(reactive_parameters_t)::qa,qb
  real(real64)::ta,tb,wa,wb
  real(real64),allocatable::va(:),vb(:)
  integer(int64)::ra,rb,ia,ib
  call a%snapshot(sa,ca);call b%snapshot(sb,cb)
  call sa%snapshot(ta,wa,pa,ra);call sb%snapshot(tb,wb,pb,rb)
  call sa%configuration(qa,ia);call sb%configuration(qb,ib)
  va=reactive_parameter_vector(qa);vb=reactive_parameter_vector(qb)
  call require(ia==ib.and.all(va==vb),label//' configuration')
  call require(ta==tb.and.wa==wb.and.ra==rb,label//' clock')
  call require(all(pa%fom_kg_m3==pb%fom_kg_m3).and.pa%biomass_kg_m3==pb%biomass_kg_m3.and. &
   pa%humus_kg_m3==pb%humus_kg_m3.and.pa%ammonium_n_kg_m2==pb%ammonium_n_kg_m2.and. &
   pa%nitrate_n_kg_m2==pb%nitrate_n_kg_m2,label//' all pools')
  va=pack_crop_n_owner(ca);vb=pack_crop_n_owner(cb)
  call require(size(va)==size(vb),label//' crop shape');call require(all(va==vb),label//' crop')
 end subroutine
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'reactive_parameters.inc'
 include 'crop_oracle.inc'
end program

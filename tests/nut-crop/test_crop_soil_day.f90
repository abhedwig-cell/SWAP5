program test_crop_soil_day
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
 implicit none
 type(crop_n_configuration_t)::p,bad
 type(reactive_parameters_t)::sp
 type(soil_n_pool_state_t)::pools,actual,want
 type(reactive_state_t)::soil,out_soil
 type(wofost81_crop_owner_state_t)::crop,out_crop,reconstructed
 type(crop_soil_state_t)::state,previous
 type(crop_soil_receipt_t)::r
 type(wofost_one_day_forcing_t)::weather
 real(real64),allocatable::v(:),v0(:),v1(:)
 real(real64)::theta,time,nit,denit,carbon,supply,oldtotal
 integer(int64)::revision
 integer::status,i,j
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
   call advance_crop_soil_day(state,0d0,1d0,theta-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,r)
   if(r%status/=0)print *,'diagnostic case',i,j,r%status,r%soil%status,r%prepared%nitrogen_request%status
   call require(r%status==0,'real WOFOST81 request to reactive N accept')
   call require(r%prepared%nitrogen_request%soil_request>0d0,'nonzero demand')
   call require(r%internal_supply_kg_m2>0d0,'actual soil supply')
   call require(abs(r%whole_n_residual)<=1d-12,'whole soil plus crop N')
   call require(r%crop_loss_kg_m2>0d0,'explicit senescence N output')
   if(j==2)call require(r%fixation_kg_m2>0d0,'WOFOST81 fixation preserved')
   if(i==2)call require(abs(r%internal_supply_kg_m2-1d-4*r%prepared%nitrogen_request%soil_request)<1d-12,'ample supply')
   if(i==3)call require(r%internal_supply_kg_m2<.5d-4*r%prepared%nitrogen_request%soil_request,'exhausted limited supply')
   call literal_crop_day(sp,pools,theta,theta-.001d0/.3d0,0d0,0d0,0d0,.001d0,want,nit,denit,carbon, &
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
 ! Complete invalid-input rollback after a live owner, and exact parameter identity.
 call previous%snapshot(soil,crop);v0=pack_crop_n_owner(crop)
 call advance_crop_soil_day(previous,0d0,1d0,.34d0,0d0,0d0,0d0,.001d0,0d0,weather,r)
 call require(r%status/=0,'unbooked potential transpiration rejects')
 call previous%snapshot(soil,out_crop);v1=pack_crop_n_owner(out_crop);call require(all(v0==v1),'rejected crop unchanged')
 bad=p;bad%tables(13)%y(1)=ieee_value(0d0,ieee_quiet_nan)
 call initialize_crop_soil(soil,crop,bad,9101_int64,state,status)
 call require(status/=0.and..not.state%ready(),'nonfinite raw parameter rejected')
 call advance_crop_soil_day(previous,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,.1d0,weather,r)
 call require(r%status==0.and.r%internal_supply_kg_m2==0d0.and.r%fixation_kg_m2==0d0,'zero accepted root water suppresses N demand and fixation')
 block
  type(reactive_parameters_t)::missing
  call require(.not.reactive_parameters_valid(missing),'unallocated soil configuration rejects safely')
  missing=sp;deallocate(missing%organic_reference%ratecon_fom)
  call require(.not.reactive_parameters_valid(missing),'missing organic rates reject safely')
 end block
 print '(A)','CROP_SOIL_REAL_WOFOST81_LITERAL_SUPPLY_FIXATION_LOSS_ROLLBACK_REPLAY=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'reactive_parameters.inc'
 include 'crop_oracle.inc'
end program

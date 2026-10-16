program test_b111_request_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 use mod_wofost_one_day_structural_evolution
 implicit none
 type(crop_n_configuration_t)::cp,invalid
 type(reactive_parameters_t)::sp
 type(reactive_state_t)::soil,after_soil
 type(soil_n_pool_state_t)::pools,got
 type(wofost81_crop_owner_state_t)::crop,after_crop
 type(crop_soil_state_t)::state,previous
 type(crop_soil_receipt_t)::r
 type(wofost_one_day_forcing_t)::weather
 real(real64),parameter::fractions(3)=[0d0,.3d0,1d0],ratios(4)=[0d0,.01d0,.010001d0,1d0]
 real(real64),parameter::phases(3)=[.49d0,.5d0,.51d0]
 real(real64)::root,theta,time,expected_fix,expected_soil,initial_n
 real(real64),allocatable::before(:),after(:),default_vector(:),selected_vector(:)
 integer(int64)::revision
 integer::i,j,k,m,code,cases
 logical::enabled
 call parameters(sp);call configure_crop(cp)
 default_vector=crop_n_configuration_vector(cp)
 allocate(cp%b111_request);cp%b111_request%dvsnlt=.5d0
 selected_vector=crop_n_configuration_vector(cp)
 call require(size(selected_vector)==size(default_vector)+3,'policy is explicit tagged native identity')
 call require(all(selected_vector(:size(default_vector))==default_vector),'default configuration exact prefix')
 invalid=cp;invalid%b111_request%nfixf=ieee_value(0d0,ieee_quiet_nan)
 selected_vector=crop_n_configuration_vector(invalid);call require(size(selected_vector)==0,'NaN policy rejected')
 invalid=cp;invalid%b111_request%nfixf=1.1d0
 selected_vector=crop_n_configuration_vector(invalid);call require(size(selected_vector)==0,'invalid fraction rejected')
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 cases=0
 do m=1,2
 do i=1,3
 do j=1,4
 do k=1,3
  cp%b111_request%nfixf=fractions(i)
  cp%base%nitrogen%nfix_fr=1d0-fractions(i) ! different policy must be completely replaced
  call configure_owner(crop,cp,code);call require(code==0,'crop initialization')
  crop%crop%development_stage=phases(k)
  crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
  crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
  call initialize_soil_n_pool_state(sp%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,code)
  if(m==2)then
   pools%fom_kg_m3=0d0;pools%biomass_kg_m3=0d0;pools%humus_kg_m3=0d0
   pools%ammonium_n_kg_m2=1d-10;pools%nitrate_n_kg_m2=1d-10
  end if
  call initialize_reactive(sp,9001_int64,0d0,.34d0,pools,soil,code)
  call initialize_crop_soil(soil,crop,cp,9101_int64,state,code);call require(code==0,'selected owner initialize')
  previous=state;root=.001d0*ratios(j)
  call advance_crop_soil_day(state,0d0,1d0,.34d0-root/.3d0,0d0,0d0,0d0,root,.1d0,weather,r)
  if(r%status/=0)print *,'case',m,i,j,k,r%status,r%soil%status
  call require(r%status==0,'actual soil crop selected policy')
  enabled=phases(k)<.5d0.and.ratios(j)>.01d0
  expected_fix=0d0;expected_soil=0d0
  if(enabled)then
   expected_fix=2d0*fractions(i);expected_soil=2d0*(1d0-fractions(i))
  end if
  call require(r%prepared%nitrogen_request%ndemand==2d0,'literal vegetative committed deficit only')
  call require(r%prepared%nitrogen_request%ndemandso==0d0,'no storage organ request')
  call require(r%prepared%nitrogen_request%rntranslocation==0d0,'no hidden translocation request')
  call require(r%prepared%nitrogen_request%rnfixation==expected_fix,'strict literal fixation gate and split')
  call require(r%prepared%nitrogen_request%soil_request==expected_soil,'literal soil split without W81 cap')
  call require(r%fixation_kg_m2==expected_fix*1d-4,'one fixation receipt in kg per square metre')
  call require(abs(r%whole_n_residual)<=1d-12,'whole soil plus crop budget')
  call state%snapshot(after_soil,after_crop)
  call require(after_crop%nitrogen%value%nfix_total==expected_fix,'fixation accumulated once')
  call require(abs(after_crop%nitrogen%value%nuptake_total-r%internal_supply_kg_m2*1d4)<=1d-12,'one actual soil uptake receipt')
  if(m==2.and.enabled.and.expected_soil>0d0) &
   call require(r%internal_supply_kg_m2<expected_soil*1d-4,'exhausted soil is not unlimited')
  before=pack_crop_n_owner(after_crop)
  call advance_crop_soil_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,root,.1d0,weather,r)
  call require(r%status/=0,'duplicate clock rejected')
  call state%snapshot(after_soil,after_crop);after=pack_crop_n_owner(after_crop)
  call require(all(before==after),'duplicate fixation cannot publish')
  cases=cases+1
 end do
 end do
 end do
 end do
 ! Reject a reproductive profile rather than silently replacing translocation.
 crop%crop%development_stage=cp%base%nitrogen%dvs_n_transl
 call initialize_crop_soil(soil,crop,cp,9101_int64,state,code)
 before=pack_crop_n_owner(crop)
 call advance_crop_soil_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,r)
 call require(r%status==CROP_SOIL_PREPARE,'reproductive policy outside bounded contract')
 call state%snapshot(after_soil,after_crop);after=pack_crop_n_owner(after_crop)
 call require(all(before==after),'failed request no crop leak')
 call after_soil%snapshot(time,theta,got,revision)
 call require(time==0d0.and.revision==0,'failed request no soil leak')
 print '(A,I0)','B111_REQUEST_REAL_SOIL_CROP_CASES=',cases
 print '(A)','B111_REQUEST_SINGLE_FIXATION_BALANCE_GATES_REPLAY=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'reactive_parameters.inc'
end program

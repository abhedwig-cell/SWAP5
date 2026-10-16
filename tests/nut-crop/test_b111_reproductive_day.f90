program test_b111_reproductive_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use literal_reproductive
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
 real(real64),parameter::phases(3)=[.79d0,.8d0,1.2d0]
 real(real64)::root,theta,time,expected_fix,expected_soil,initial_n
 real(real64),allocatable::before(:),after(:),default_vector(:),selected_vector(:)
 real(real64)::want(8),loss(3),trans(3),uptake(3),requests(6),x(3),pv(4),masses(4),deaths(3)
 integer(int64)::revision
 integer::i,j,k,m,code,cases
 logical::enabled
 call parameters(sp);call configure_crop(cp)
 default_vector=crop_n_configuration_vector(cp)
 allocate(cp%b111_reproductive);cp%b111_reproductive%dvsnlt=.9d0;cp%b111_reproductive%dvsnt=.8d0;cp%b111_reproductive%fntrt=.25d0
 selected_vector=crop_n_configuration_vector(cp)
 call require(size(selected_vector)==size(default_vector)+5,'policy is explicit tagged native identity')
 call require(all(selected_vector(:size(default_vector))==default_vector),'default configuration exact prefix')
 invalid=cp;invalid%b111_reproductive%nfixf=ieee_value(0d0,ieee_quiet_nan)
 selected_vector=crop_n_configuration_vector(invalid);call require(size(selected_vector)==0,'NaN policy rejected')
 invalid=cp;invalid%b111_reproductive%nfixf=1.1d0
 selected_vector=crop_n_configuration_vector(invalid);call require(size(selected_vector)==0,'invalid fraction rejected')
 invalid=cp;allocate(invalid%b111_request)
 selected_vector=crop_n_configuration_vector(invalid);call require(size(selected_vector)==0,'mutually exclusive profiles')
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 cases=0
 do m=1,2
 do i=1,3
 do j=1,4
 do k=1,3
  cp%b111_reproductive%nfixf=fractions(i)
  cp%base%nitrogen%nfix_fr=1d0-fractions(i) ! different policy must be completely replaced
  call configure_owner(crop,cp,code);call require(code==0,'crop initialization')
  crop%crop%development_stage=phases(k)
  crop%crop%evolution_continuation%anthesis_reached=phases(k)>=1d0
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
  if(r%status/=0)then
   print *,'case',m,i,j,k,r%status,r%soil%status
   print *,r%prepared%ready,r%prepared%active,r%prepared%drlv,r%prepared%drst,r%prepared%drrt
   print *,r%prepared%wlv_before,r%prepared%wst_before,r%prepared%wrt_before,r%prepared%corrected_rates%relative_transpiration_used
  end if
  call require(r%status==0,'actual soil crop selected policy')
  associate(q=>r%prepared)
   pv=[cp%b111_reproductive%dvsnlt,cp%b111_reproductive%dvsnt,cp%b111_reproductive%nfixf,cp%b111_reproductive%fntrt]
   masses=[q%wlv_before,q%wst_before,q%wrt_before,q%wso_before];deaths=[q%drlv,q%drst,q%drrt]
   call literal(cp%base%nitrogen%donor_view(),pv,crop%nitrogen%value,phases(k),.04d0,masses,deaths, &
     q%corrected_rates%relative_transpiration_used,r%internal_supply_kg_m2*1d4,want,loss,trans,uptake,requests,x)
   call require(all([q%nitrogen_request%ndemand,q%nitrogen_request%ndemandso,q%nitrogen_request%soil_request, &
    q%nitrogen_request%rnfixation,q%nitrogen_request%ntranslocatable,q%nitrogen_request%rntranslocation]==requests), &
    'actual prepared source request')
  end associate
  call require(abs(r%whole_n_residual)<=1d-12,'whole soil plus crop budget')
  call state%snapshot(after_soil,after_crop)
  associate(n=>after_crop%nitrogen%value)
   call require(maxval(abs([n%namountlv,n%namountst,n%namountrt,n%namountso,n%nuptake_total,n%nfix_total, &
     n%nlosses_total,n%initial_total]-want))<=1d-12,'literal all organ and cumulative values')
  end associate
  call require(all([r%crop%rndeathlv,r%crop%rndeathst,r%crop%rndeathrt]==loss),'actual residual death source')
  call require(all([r%crop%rntranslocationlv_applied,r%crop%rntranslocationst_applied,r%crop%rntranslocationrt_applied]==trans), &
    'actual multi organ donor source')
  call require(r%crop%rntranslocation_applied==requests(6),'storage funded by donor partition')
  call require(r%crop%rnloss>0d0,'simultaneous actual organ death')
  if(phases(k)>=.8d0)call require(r%crop%rntranslocation_applied>0d0,'active reproductive source')
  enabled=phases(k)<.9d0.and.ratios(j)>.01d0
  if(m==2.and.enabled.and.fractions(i)<1d0) &
   call require(r%internal_supply_kg_m2<requests(3)*1d-4,'exhausted soil actual finite supply')
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
 ! Source max donor may overdraw actual root pool: rollback after soil trial.
 call configure_owner(crop,cp,code);crop%crop%development_stage=1.2d0
 crop%crop%evolution_continuation%anthesis_reached=.true.
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-crop%nitrogen%value%namountrt
 crop%nitrogen%value%namountrt=0d0
 call initialize_crop_soil(soil,crop,cp,9101_int64,state,code);call require(code==0,'bounded overdraw initial owner')
 before=pack_crop_n_owner(crop)
 call advance_crop_soil_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0,weather,r)
 call require(r%status==CROP_SOIL_APPLY,'source overdraw rejected after tentative soil advance')
 call state%snapshot(after_soil,after_crop);after=pack_crop_n_owner(after_crop)
 call require(all(before==after),'failed apply no crop leak')
 call after_soil%snapshot(time,theta,got,revision)
 call require(time==0d0.and.revision==0,'failed apply no soil leak')
 print '(A,I0)','B111_REPRODUCTIVE_REAL_SOIL_CROP_CASES=',cases
 print '(A)','B111_REPRODUCTIVE_LITERAL_DEATH_DONORS_BALANCE_ROLLBACK_REPLAY=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'reactive_parameters.inc'
end program

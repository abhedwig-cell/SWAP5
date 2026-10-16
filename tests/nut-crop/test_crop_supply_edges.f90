program test_crop_supply_edges
 use iso_fortran_env,only:real64,int64
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 use mod_wofost_one_day_structural_evolution
 implicit none
 type(crop_n_configuration_t)::cp
 type(reactive_parameters_t)::sp
 type(reactive_state_t)::soil,after_soil
 type(wofost81_crop_owner_state_t)::crop,after_crop
 type(crop_soil_state_t)::state
 type(crop_soil_receipt_t)::r
 type(soil_n_pool_state_t)::pools,got,want
 type(wofost_one_day_forcing_t)::weather
 real(real64),allocatable::old(:),new(:)
 real(real64)::time,theta,supply,nit,denit,carbon
 integer(int64)::revision
 integer::i,code
 call parameters(sp);call configure_crop(cp);call configure_owner(crop,cp,code)
 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 old=pack_crop_n_owner(crop)
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 do i=1,4
  call configure_crop(cp);cp%lai_crit_nupt=6d0
  call initialize_soil_n_pool_state(sp%mineral%inventory,[10d0,20d0],5d0,40d0,.002d0,.003d0,pools,code)
  if(i==2)then
   pools%ammonium_n_kg_m2=5d0;pools%nitrate_n_kg_m2=5d0
  end if
  if(i>=3)then
   cp%lai_crit_nupt=3d0
   if(i==3)cp%base%nitrogen%nfix_fr=1d0
  end if
  call initialize_reactive(sp,9001_int64,0d0,.34d0,pools,soil,code)
  call initialize_crop_soil(soil,crop,cp,9101_int64,state,code);call require(code==0,'edge initialize')
  call advance_crop_soil_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0, &
    merge(10d0,.1d0,i==4),weather,r)
  if(i==2)then
   call require(r%status==CROP_SOIL_TRANSFER,'juvenile water-driven oversupply rejects unmatched debit')
   call state%snapshot(after_soil,after_crop);new=pack_crop_n_owner(after_crop)
   call require(all(old==new),'oversupply no crop leak')
   call after_soil%snapshot(time,theta,got,revision)
   call require(time==0d0.and.revision==0.and.got%ammonium_n_kg_m2==pools%ammonium_n_kg_m2,'oversupply no soil leak')
  else
   if(r%status/=0)print *,'edge diagnostics',i,r%status,r%soil%status
   call require(r%status==0,'accepted juvenile or fixation/threshold edge')
   call require(abs(r%whole_n_residual)<=1d-12,'edge whole N')
   if(i==1)then
    call literal_crop_day(sp,pools,.34d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,want,nit,denit,carbon, &
      r%prepared%nitrogen_request%soil_request,.5d0,4d0,30d0,1d0,6d0,supply)
    call require(r%soil%process%exchange%juvenile_factor>0d0,'actual juvenile source branch')
    call require(abs(supply-r%internal_supply_kg_m2)<=1d-12,'juvenile literal uptake')
    call state%snapshot(after_soil,after_crop);call after_soil%snapshot(time,theta,got,revision)
    call require(abs(got%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<=1d-12.and. &
      abs(got%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<=1d-12,'juvenile literal endpoint')
   else
    call require(r%internal_supply_kg_m2==0d0,'zero soil request produces no soil debit')
    if(i==3)call require(r%fixation_kg_m2>0d0,'complete WOFOST81 fixation input')
    if(i==4)call require(r%fixation_kg_m2==0d0,'rftra threshold disables N uptake and fixation')
   end if
  end if
 end do
 print '(A)','CROP_SOIL_JUVENILE_LITERAL_OVERSUPPLY_FULL_FIXATION_RFTRA_THRESHOLD=PASS'
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

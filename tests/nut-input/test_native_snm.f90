program test_native_snm
 use iso_fortran_env,only:real64
 use mod_soil_n_unified_input
 use mod_soil_n_historical_activation
 use mod_soil_n_amendment_calendar
 use mod_b111_soil_n_addition
 use mod_soil_n_historical_named_input,only:soil_n_residue_age_t
 implicit none
 type(soil_n_amendment_calendar_t)::plan
 type(soil_n_historical_initial_t)::initial
 type(soil_n_historical_rates_t)::rates
 type(soil_n_residue_age_t)::ages
 type(b111_soil_n_material_t),allocatable::items(:)
 integer,allocatable::indices(:)
 integer::status,line,expected,n
 character(512)::path,arg
 call get_command_argument(1,path);call get_command_argument(2,arg);read(arg,*)expected
 call read_soil_n_snm_keyword_file(trim(path),'1900-12-30',plan,initial,rates,status,line,ages)
 if(expected>=0)then
  if(status/=0.or..not.plan%ready())then
   print *,'unexpected rejected input',status,line;error stop 1
  end if
  if(any(initial%fom_kg_m3/=1d0).or.initial%bio_kg_m3/=5d0.or.initial%hum_kg_m3/=40d0)error stop 2
  if(rates%ratecon_nitrif_ref/=.02d0.or.rates%depth_m/=.3d0.or.rates%lai_crit_nupt/=0d0)error stop 3
  if(ages%root/=1.27d0.or.ages%leaf/=.99d0)error stop 4
  if(expected==8)then
   if(rates%hum_exp_per_year/=-1d0.or.rates%hum_exp_start_day/=0d0)error stop 19
   call select_soil_n_amendments(plan,365d0,366d0,items,indices,status)
   if(status/=0.or.size(items)/=1)error stop 20
   if(indices(1)/=1.or.items(1)%ammonium_n_fraction/=.4d0.or. &
      items(1)%nitrate_n_fraction/=.05d0.or.items(1)%application_kg_m2/=.01d0)error stop 21
   call select_soil_n_amendments(plan,366d0,367d0,items,indices,status)
   if(status/=0.or.size(items)/=1)error stop 22
   if(indices(1)/=2.or.items(1)%ammonium_n_fraction/=.1d0.or. &
      items(1)%nitrate_n_fraction/=.2d0.or.items(1)%application_kg_m2/=.02d0)error stop 23
   print '(A)','NATIVE_SNM_DEFINITION_LABELS_EVENT_POSITIONS=PASS'
   print '(A)','NATIVE_SNM_INTERPRETATION=PASS'
   stop
  end if
  if(expected>=2)then
   if(rates%hum_exp_start_day/=365d0)error stop 12
   if(expected==2.and.rates%hum_exp_per_year/=.1d0)error stop 13
   if(expected==3.and.rates%hum_exp_per_year/=0d0)error stop 14
   if(expected==4.and.rates%hum_exp_per_year/=.0001d0)error stop 15
   if(expected==5.or.expected==6)then
    if(rates%hum_exp_per_year/365.2425d0>1d-6)error stop 17
   end if
   if(expected==7.and.rates%hum_exp_per_year/365.2425d0<=1d-6)error stop 18
   if(expected>=5)print '(A,L1)','NATIVE_HUMUS_THRESHOLD_ACTIVE=',rates%hum_exp_per_year/365.2425d0>1d-6
  else
   if(rates%hum_exp_per_year/=-1d0.or.rates%hum_exp_start_day/=0d0)error stop 16
  end if
  if(expected==1)then
   if(rates%nh4_top/=.0005d0.or.rates%no3_top/=.0015d0)error stop 10
  else
   if(rates%nh4_top/=0d0.or.rates%no3_top/=0d0)error stop 11
  end if
  call select_soil_n_amendments(plan,365d0,366d0,items,indices,status)
  if(status/=0.or.size(items)/=2)error stop 5
  if(any(indices/=[2,3]).or.abs(items(1)%application_kg_m2-.005d0)>1d-14)error stop 6
  print '(A)','NATIVE_SNM_INTERPRETATION=PASS'
 else
  if(status==0.or.plan%ready())error stop 7
  if(any(initial%fom_kg_m3/=0d0).or.initial%hum_kg_m3/=0d0)error stop 8
  if(expected< -1.and.line/=-expected)then
   print *,'wrong physical line',line,-expected;error stop 9
  end if
  print '(A)','NATIVE_SNM_ATOMIC_REJECTION=PASS'
 end if
end program

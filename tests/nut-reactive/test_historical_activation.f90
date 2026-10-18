program test_historical_activation
 use iso_fortran_env,only:real64,int64
 use mod_soil_n_historical_named_input
 use mod_soil_n_historical_activation
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 implicit none
 type(soil_n_historical_selection_t)::sel
 type(reactive_parameters_t)::p,p_source,p_bound,p_complete
 type(reactive_state_t)::owner,other
 type(soil_n_pool_state_t)::pools,derived
 type(soil_n_historical_initial_t)::legacy
 type(soil_n_historical_rates_t)::rates
 type(soil_n_residue_age_t)::ages
 real(real64)::tcsf,lai
 integer::code,unit,line_number,i
 character(32)::key
 character(128)::record
 open(newunit=unit,file='historical-fields.txt',status='replace')
 do i=1,8
   write(key,'(A,I1,A)')'FOM',i,'_t'
   write(unit,'(A)')trim(key)//' = 1.0'
 end do
 write(unit,'(A)')'Bio_t = 5.0','Hum_t = 40.0','cNH4_t = 0.2','cNO3_t = 0.3', &
    'Temp_ref = 20.0','SorpCoef = 0.0002','RateConNitrif_ref = 0.02', &
    'RateConDenitr_ref = 0.03','WFPSCrit = 0.6','WFPScrit2 = 0.5', &
    'CdissiHalf = 0.1','TCSF_N = 0.5','dz_WSN = 0.3', &
    'cNH4N_lat = 0.3','cNO3N_lat = 0.4','cNH4N_seep = 0.1','cNO3N_seep = 0.2'
 close(unit)
 call read_historical_soil_n_named_export('historical-fields.txt',legacy,rates,code,line_number,ages)
 if(abs(ages%root-1.27d0)>1d-14.or.abs(ages%leaf-.99d0)>1d-14)error stop 'historical age defaults'
 if(code/=N_NAMED_OK)error stop '26 named fields'
 if(rates%no3_seep/=.2d0.or.rates%no3_lat/=.4d0)error stop 'distinct no3 routes'
 if(rates%lai_crit_nupt/=0d0)error stop 'original optional LaiCritNupt default'
 block
  character(128)::modern_lines(32)
  integer::j,nmodern,ios
  open(newunit=unit,file='historical-fields.txt',status='old')
  do j=1,31
   read(unit,'(A)',iostat=ios)modern_lines(j)
   if(ios/=0)exit
  end do
  close(unit)
  if(ios>=0)error stop 'modern fixture not bounded'
  nmodern=j
  modern_lines(nmodern)='flCropExt = .false.'
  call parse_historical_soil_n_named_lines(modern_lines(:nmodern),legacy,rates,code,line_number)
  if(code/=N_NAMED_INVALID.or.line_number/=nmodern)error stop 'native logical admitted by modern export'
  if(any(legacy%fom_kg_m3/=0d0).or.legacy%hum_kg_m3/=0d0)error stop 'modern flag rejection published inventory'
 end block
 open(newunit=unit,file='historical-fields.txt',position='append')
 write(unit,'(A)')'SorpCoef = 0.1'
 close(unit)
 call read_historical_soil_n_named_export('historical-fields.txt',legacy,rates,code,line_number)
 if(code/=N_NAMED_INVALID)error stop 'duplicate name accepted'
 open(newunit=unit,file='historical-fields.txt',status='replace')
 write(unit,'(A)')repeat('X',700)
 close(unit)
 call read_historical_soil_n_named_export('historical-fields.txt',legacy,rates,code,line_number)
 if(code/=N_NAMED_INVALID)error stop 'overlong record accepted'

 call parameters(p)
 call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,code)
 if(code/=0)error stop 'pools'
 call bind_historical_organic_source_profile(p,p_source,code)
 if(code/=N_ACTIVATION_OK)error stop 'source organic authority profile'
 if(size(p_source%organic_reference%ratecon_fom)/=8)error stop 'source eight rates'
 if(any(abs(p_source%organic_reference%ratecon_fom(1:4)-3d0/365.2425d0)>1d-15)) &
   error stop 'source fast FOM rates'
 if(any(abs(p_source%organic_reference%ratecon_fom(5:8)-.3d0/365.2425d0)>1d-15)) &
   error stop 'source slow FOM rates'
 if(any(p_source%mineral%inventory%nfrac_fom/=[.06d0,.002d0,.06d0,.002d0, &
       .06d0,.002d0,.06d0,.002d0]))error stop 'source eight N fractions'
 if(any(abs(p_source%organic_reference%asfa_fom_bio(3:4)-.28d0*.46d0)>1d-15)) &
   error stop 'source third fourth assimilation'
 if(abs(p_source%cfrac_biomass-.58d0)>1d-15.or.abs(p_source%cfrac_humus-.58d0)>1d-15) &
   error stop 'source C fraction'
 rates%temp_ref=20d0;rates%sorpcoef=.0002d0
 rates%ratecon_nitrif_ref=.02d0;rates%ratecon_denitr_ref=.03d0
 rates%wfpscrit=.6d0;rates%wfpscrit2=.5d0;rates%cdissi_half=.1d0
 rates%tcsf_n=.5d0;rates%lai_crit_nupt=3d0;rates%depth_m=.3d0
 rates%nh4_lat=.3d0;rates%no3_lat=.4d0
 rates%nh4_seep=.1d0;rates%no3_seep=.2d0
 call bind_historical_soil_n_rates(rates,p,p_bound,tcsf,lai,code)
 if(code/=N_ACTIVATION_OK)error stop 'source parameter binding'
 if(any(p_bound%mineral%c_bottom/=[.1d0,.2d0]))error stop 'distinct seepage'
 if(any(p_bound%mineral%c_lateral/=[.3d0,.4d0]))error stop 'distinct lateral'
 if(tcsf/=.5d0.or.lai/=3d0)error stop 'crop uptake parameters'
 rates%wfpscrit=1.5d0
 call bind_historical_soil_n_rates(rates,p,p_bound,tcsf,lai,code)
 if(code/=N_ACTIVATION_INVALID.or.tcsf/=0d0.or.lai/=0d0)error stop 'invalid rate accepted'
 rates%wfpscrit=.6d0
 call bind_historical_soil_n_rates(rates,p,p_bound,tcsf,lai,code)
 if(code/=N_ACTIVATION_OK)error stop 'restore rate binding'
 legacy%fom_kg_m3=[1d0,2d0,3d0,4d0,5d0,6d0,7d0,8d0]
 legacy%bio_kg_m3=5d0;legacy%hum_kg_m3=40d0
 legacy%cnh4_kg_m3=.2d0;legacy%cno3_kg_m3=.3d0
 call build_historical_soil_n_inventory(legacy,p_source,.34d0,derived,code)
 if(code/=N_ACTIVATION_OK)error stop 'historical inventory'
 if(abs(derived%ammonium_n_kg_m2-(.34d0+1300d0*.0002d0)*.2d0*.3d0)>1d-14) &
   error stop 'NH4 sorption storage wrong'
 if(abs(derived%nitrate_n_kg_m2-.34d0*.3d0*.3d0)>1d-14) &
   error stop 'NO3 mobile storage wrong'
 if(any(derived%fom_kg_m3/=legacy%fom_kg_m3))error stop 'eight pool assignment'
 legacy%cno3_kg_m3=-1d0
 call build_historical_soil_n_inventory(legacy,p,.34d0,derived,code)
 if(code/=N_ACTIVATION_INVALID.or.derived%valid())error stop 'invalid historical store accepted'
 legacy%cno3_kg_m3=.3d0
 sel%swcropsnm=1;sel%sw_wofost=1;sel%source_parameters_complete=.true.
 call initialize_historical_soil_n_complete(sel,rates,legacy,p_source,9001_int64,0d0,.34d0, &
   owner,p_complete,tcsf,lai,code)
 if(code/=N_ACTIVATION_OK.or..not.owner%ready())error stop 'combined historical activation'
 if(any(p_complete%mineral%c_bottom/=[.1d0,.2d0]))error stop 'combined seepage'
 rates%wfpscrit=1.5d0
 call initialize_historical_soil_n_complete(sel,rates,legacy,p_source,9001_int64,0d0,.34d0, &
   owner,p_complete,tcsf,lai,code)
 if(code==N_ACTIVATION_OK.or.owner%ready().or.tcsf/=0d0.or.lai/=0d0)error stop 'combined rollback'
 rates%wfpscrit=.6d0
 sel%source_parameters_complete=.false.
 call initialize_historical_soil_n_complete(sel,rates,legacy,p_source,9001_int64,0d0,.34d0, &
   owner,p_complete,tcsf,lai,code)
 if(code==N_ACTIVATION_OK.or.owner%ready())error stop 'combined incomplete accepted'
 sel%source_parameters_complete=.true.
 sel%source_parameters_complete=.false.
 call activate_soil_n_historical(sel,p,pools,9001_int64,0d0,.34d0,owner,code)
 if(code/=N_ACTIVATION_INVALID.or.owner%ready())error stop 'incomplete source accepted'
 sel%source_parameters_complete=.true.
 call activate_soil_n_historical(sel,p,pools,9001_int64,0d0,.34d0,owner,code)
 if(code/=N_ACTIVATION_OK.or..not.owner%ready())error stop 'complete source rejected'
 other=owner
 sel%swcropsnm=0
 call activate_soil_n_historical(sel,p,pools,9001_int64,0d0,.34d0,owner,code)
 if(code/=N_ACTIVATION_UNSUPPORTED.or.owner%ready())error stop 'other selector accepted'
 sel%swcropsnm=1;p%enabled=.false.
 call activate_soil_n_historical(sel,p,pools,9001_int64,0d0,.34d0,owner,code)
 if(code/=N_ACTIVATION_INVALID.or.owner%ready())error stop 'disabled accepted'
 if(.not.other%ready())error stop 'prior owner mutation'
 print '(A)','NUT_HISTORICAL_ACTIVATION_O0_O2=PASS'
contains
 include 'reactive_parameters.inc'
end program

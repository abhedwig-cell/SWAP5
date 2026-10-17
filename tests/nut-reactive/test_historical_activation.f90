program test_historical_activation
 use iso_fortran_env,only:real64,int64
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
 real(real64)::tcsf,lai
 integer::code
 call parameters(p)
 call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,code)
 if(code/=0)error stop 'pools'
 p_source=p
 p_source%mineral%inventory%nfrac_fom=[.015d0,.025d0,.015d0,.025d0,.015d0,.025d0,.015d0,.025d0]
 p_source%organic_reference%ratecon_fom=[.04d0,.015d0,.04d0,.015d0,.04d0,.015d0,.04d0,.015d0]
 p_source%organic_reference%asfa_fom_bio=[.2d0,.25d0,.2d0,.25d0,.2d0,.25d0,.2d0,.25d0]
 p_source%organic_reference%asfa_fom_hum=[.15d0,.1d0,.15d0,.1d0,.15d0,.1d0,.15d0,.1d0]
 p_source%cfrac_fom=[.45d0,.45d0,.45d0,.45d0,.45d0,.45d0,.45d0,.45d0]
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

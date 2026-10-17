program test_historical_activation
 use iso_fortran_env,only:real64,int64
 use mod_soil_n_historical_activation
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 implicit none
 type(soil_n_historical_selection_t)::sel
 type(reactive_parameters_t)::p
 type(reactive_state_t)::owner,other
 type(soil_n_pool_state_t)::pools
 integer::code
 call parameters(p)
 call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,code)
 if(code/=0)error stop 'pools'
 sel%swcropsnm=1;sel%sw_wofost=1
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

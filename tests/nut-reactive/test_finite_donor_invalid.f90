program test_finite_donor_invalid
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_soil_n_reactive_owner
 implicit none
 type(reactive_state_t)::state
 type(reactive_receipt_t)::r
 real(real64)::nan
 nan=ieee_value(0d0,ieee_quiet_nan)
 call advance_reactive_day(state,0d0,1d0,.3d0,0d0,0d0,0d0,nan,r)
 if(r%status==0)error stop 1
 call advance_reactive_day(state,0d0,1d0,.3d0,0d0,0d0,0d0,nan,r, &
      historical_top_water=-.04d0,finite_donor_top=.true.)
 if(r%status==0)error stop 2
 print '(A)','FINITE_DONOR_NONFINITE_ROOT_REJECTED=PASS'
end program

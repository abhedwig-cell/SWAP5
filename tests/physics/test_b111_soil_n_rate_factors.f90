program test_b111_soil_n_rate_factors
 use iso_fortran_env,only:real64
 use mod_b111_soil_n_rate_factors
 implicit none
 type(b111_soil_n_rate_result_t)::r
 real(real64)::redt,wfps,rednit,redden,redresp
 call evaluate_b111_soil_n_rate_constants(20d0,20d0,.30d0,.34d0,.50d0,.60d0,2d0,3d0,.1d0,.2d0,r)
 call check(r%status==B111_NRATE_OK,'base status')
 redt=1d0
 wfps=.5d0*(.30d0+.34d0)/.50d0
 rednit=.9d0/(1d0+exp(-15d0*(wfps-.45d0)))+.1d0-1d0/(1d0+exp(-50d0*(wfps-.95d0)))
 redden=(max(wfps-.60d0,0d0)/(1d0-.60d0))**2
 redresp=2d0/(3d0+2d0)
 call near(r%temperature_factor,redt,'temperature reference')
 call near(r%wfps,wfps,'wfps')
 call near(r%nitrification_moisture_factor,rednit,'nit moisture')
 call near(r%denitrification_moisture_factor,redden,'den moisture')
 call near(r%respiration_factor,redresp,'resp')
 call near(r%nitrification_rate_constant,.1d0*redt*rednit,'nit rate')
 call near(r%denitrification_rate_constant,.2d0*redt*redden*redresp,'den rate')
 call evaluate_b111_soil_n_rate_constants(20d0,20d0,.20d0,.20d0,.50d0,.60d0,2d0,3d0,.1d0,.2d0,r)
 call check(r%status==B111_NRATE_OK,'dry status')
 call near(r%denitrification_rate_constant,0d0,'den dry cutoff')
 call evaluate_b111_soil_n_rate_constants(20d0,20d0,.30d0,.34d0,.50d0,.60d0,0d0,3d0,.1d0,.2d0,r)
 call near(r%denitrification_rate_constant,0d0,'zero respiration')
 call evaluate_b111_soil_n_rate_constants(20d0,20d0,.30d0,.34d0,.50d0,.60d0,0d0,3d0,.1d0,.2d0,r)
 call check(r%status==B111_NRATE_OK,'zero respiration status')
 print '(A)','B111_SOIL_N_RATE_FACTORS_PASS'
contains
 subroutine near(a,b,label)
  real(real64),intent(in)::a,b;character(len=*),intent(in)::label
  call check(abs(a-b)<=1d-12*max(1d0,abs(a),abs(b)),label)
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program

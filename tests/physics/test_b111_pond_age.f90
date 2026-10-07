program test_b111_pond_age
 use iso_fortran_env,only:real64
 use mod_b111_pond_solute_exchange
 use mod_b111_age_tracer_production
 implicit none
 type(b111_pond_solute_result_t)::p
 type(b111_age_production_result_t)::a
 call evaluate_b111_pond_solute_exchange(2d0,1d0,.5d0,.2d0,1.5d0,-.4d0,.1d0,1.2d0,.5d0,p)
 call check(p%status==B111_POND_SOL_OK,'pond status')
 call near(p%rain_input,.25d0,'rain input')
 call near(p%irrigation_input,.15d0,'irrig input')
 call near(p%pond_concentration,2.4d0/(1.2d0+.2d0),'pond concentration')
 call near(p%soil_transfer,.4d0*.9d0*p%pond_concentration*.5d0,'soil transfer')
 call near(p%balance_residual,0d0,'pond balance')
 call evaluate_b111_pond_solute_exchange(2d0,0d0,0d0,0d0,0d0,0d0,0d0,1d0,.5d0,p)
 call near(p%mass_after,2d0,'no infiltration storage')
 call evaluate_b111_age_production([.2d0,.3d0],[.4d0,.5d0],[10d0,20d0],.5d0,a)
 call check(a%status==B111_AGE_OK,'age status')
 call near(a%production_density_rate(1),.3d0,'age density1')
 call near(a%production_amount(1),1.5d0,'age amount1')
 call near(a%production_amount(2),4d0,'age amount2')
 call near(a%total_production,5.5d0,'age total')
 print '(A)','B111_POND_AGE_PASS'
contains
 subroutine near(x,y,label)
  real(real64),intent(in)::x,y;character(len=*),intent(in)::label
  call check(abs(x-y)<=1d-12*max(1d0,abs(x),abs(y)),label)
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program

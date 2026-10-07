program test_b111_soil_n_transport
 use iso_fortran_env,only:real64
 use mod_b111_soil_n_transport
 implicit none
 type(b111_soil_n_transport_result_t)::r
 call evaluate_b111_soil_n_transport(.5d0,1d0,.3d0,.3d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0, &
      1200d0,.001d0,0d0,0d0,0d0,2d0,r)
 call check(r%status==B111_NTRANS_OK,'static status');call check(r%solution_class==5,'static class');call near(r%concentration_end,2d0,'static c')
 call evaluate_b111_soil_n_transport(.5d0,1d0,.3d0,.3d0,0d0,0d0,0d0,0d0,0d0,0d0,.1d0,0d0, &
      1000d0,.001d0,0d0,0d0,0d0,2d0,r)
 call check(r%status==B111_NTRANS_OK,'loss status');call check(r%solution_class==3,'loss class')
 call near(r%concentration_end,2d0*exp(-(.1d0*.3d0)/(.3d0+1d0)*1d0),'loss exponential')
 call evaluate_b111_soil_n_transport(.5d0,1d0,.3d0,.3d0,0d0,0d0,.01d0,0d0,0d0,0d0,0d0,0d0, &
      0d0,0d0,4d0,0d0,0d0,1d0,r)
 call check(r%status==B111_NTRANS_OK,'inflow status');call check(r%concentration_end>1d0,'inflow increase')
 print '(A)','B111_SOIL_N_TRANSPORT_PASS'
contains
 subroutine near(x,y,label)
  real(real64),intent(in)::x,y;character(len=*),intent(in)::label
  call check(abs(x-y)<=1d-10*max(1d0,abs(x),abs(y)),label)
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program

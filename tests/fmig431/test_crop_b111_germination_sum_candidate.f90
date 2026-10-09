program test_crop_b111_germination_sum_candidate
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_crop_b111_germination_sum_candidate
  implicit none
  real(real64)::s,d,nan
  integer::st
  logical::g
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  call check(5.d0,2.d0,20.d0,100.d0,100.d0,0.d0,3.d0,-0.097d0,.false.)
  call check(25.d0,2.d0,20.d0,100.d0,50.d0,0.d0,36.d0,-0.064d0,.false.)
  call check(1.d0,2.d0,20.d0,100.d0,50.d0,7.d0,7.d0,-0.093d0,.false.)
  call check(22.d0,2.d0,20.d0,30.d0,0.d0,20.d0,38.d0,0.d0,.true.)
  call b111_germination_sum_candidate(nan,2.d0,20.d0,30.d0,5.d0,7.d0,s,g,d,st)
  if(st/=B111_SUM_INVALID.or.s/=7.d0.or.g) error stop 10
  call b111_germination_sum_candidate(12.d0,2.d0,20.d0,0.d0,5.d0,7.d0,s,g,d,st)
  if(st/=B111_SUM_INVALID.or.s/=7.d0.or.g) error stop 11
  call b111_germination_sum_candidate(12.d0,2.d0,20.d0,30.d0,5.d0,7.d0,s,g,d,st)
  if(st/=B111_SUM_OK.or.s/=67.d0.or..not.g) error stop 12
  print '(a)','CROP_B111_GERMINATION_SUM_CANDIDATE=PASS'
contains
  subroutine check(t,b,m,opt,sub,old,expect,edvs,eg)
    real(real64),intent(in)::t,b,m,opt,sub,old,expect,edvs
    logical,intent(in)::eg
    call b111_germination_sum_candidate(t,b,m,opt,sub,old,s,g,d,st)
    if(st/=B111_SUM_OK.or.abs(s-expect)>1.d-12.or.abs(d-edvs)>1.d-12.or.g.neqv.eg) error stop 1
  end subroutine
end program

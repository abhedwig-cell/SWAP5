program test_swap431_hyd_power
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_hconduc
  implicit none
  real(real64) :: c(42), h, theta, kbase, kpower, expected, relsat, term1
  c=0.0_real64
  c(1)=0.05_real64; c(2)=0.45_real64; c(3)=10.0_real64
  c(4)=0.02_real64; c(5)=0.5_real64; c(6)=2.0_real64; c(7)=0.5_real64
  c(9)=0.0_real64; c(22)=-100.0_real64
  c(25)=c(2)-c(1); c(32)=1.0_real64/c(7); c(33)=c(6)*(2.0_real64+c(7)*c(5))
  h=c(22)
  theta=c(1)+c(25)/(1.0_real64+abs(c(4)*h)**c(6))**c(7)
  relsat=(theta-c(1))/c(25)
  term1=(1.0_real64-relsat**c(32))**c(7)
  c(23)=c(3)*relsat**c(5)*(1.0_real64-term1)**2

  kbase=b110_hconduc(c,h,theta,.false.)
  kpower=b110_hconduc(c,h,theta,.false.,.true.)
  call assert_close(kbase,c(23),1.0e-13_real64,'continuity base')
  call assert_close(kpower,c(23),1.0e-13_real64,'continuity power')

  h=-1000.0_real64
  theta=c(1)+c(25)/(1.0_real64+abs(c(4)*h)**c(6))**c(7)
  expected=c(23)*(abs(c(22))/abs(h))**c(33)
  kpower=b110_hconduc(c,h,theta,.false.,.true.)
  call assert_close(kpower,expected,1.0e-13_real64,'dry power tail')

  kbase=b110_hconduc(c,h,theta,.false.)
  if (abs(kbase-kpower)<=1.0e-14_real64) error stop 'power-disabled preservation not discriminated'
  print '(a)','PASS swap431 hyd power'
contains
  subroutine assert_close(actual,expected,tolerance,label)
    real(real64),intent(in)::actual,expected,tolerance
    character(len=*),intent(in)::label
    if(abs(actual-expected)>tolerance)then
      write(*,'(a,2es24.16)') trim(label)//' mismatch ',actual,expected
      error stop 1
    end if
  end subroutine
end program

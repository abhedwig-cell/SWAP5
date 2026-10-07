module test_b111_power_base
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  type, extends(constitutive_hydraulics_provider_t) :: base_t
  contains
    procedure :: evaluate => base_eval
    procedure :: supports_point_conductivity => base_support
    procedure :: evaluate_point_conductivity => base_point
  end type
contains
  subroutine base_eval(self,h,theta,k,c,dk)
    class(base_t),intent(in)::self
    real(real64),intent(in)::h(:)
    real(real64),intent(out)::theta(:),k(:),c(:),dk(:)
    theta=0.30_real64;k=3.25_real64;c=0.02_real64;dk=0.0_real64
  end subroutine
  logical function base_support(self)
    class(base_t),intent(in)::self
    base_support=.true.
  end function
  subroutine base_point(self,node,h,theta,k,available)
    class(base_t),intent(in)::self
    integer,intent(in)::node
    real(real64),intent(in)::h,theta
    real(real64),intent(out)::k
    logical,intent(out)::available
    k=3.25_real64;available=.true.
  end subroutine
end module

program test_b111_power_tail
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_conductivity_power_tail
  use test_b111_power_base
  implicit none
  type(base_t),target::base
  type(b111_conductivity_power_tail_t)::power
  real(real64)::cof(42,4),h(4),theta(4),k(4),cap(4),dk(4),expected,pk
  integer::status
  logical::available
  cof=0.0_real64
  cof(22,:)=[-100.0_real64,-100.0_real64,-100.0_real64,-100.0_real64]
  cof(23,:)=[2.0_real64,2.0_real64,2.0_real64,2.0_real64]
  cof(33,:)=[2.5_real64,2.5_real64,2.5_real64,2.5_real64]
  h=[-50.0_real64,-100.0_real64,-400.0_real64,-2.0e14_real64]
  call configure_b111_conductivity_power_tail(power,cof,status)
  if(status/=B111_POWER_OK)error stop 'power configure'
  call bind_b111_conductivity_power_tail(power,base,status)
  if(status/=B111_POWER_OK)error stop 'power bind'
  call power%evaluate(h,theta,k,cap,dk)
  if(k(1)/=3.25_real64)error stop 'normal branch preservation'
  call close(k(2),2.0_real64,'threshold')
  expected=2.0_real64*(100.0_real64/400.0_real64)**2.5_real64
  call close(k(3),expected,'power branch')
  call close(k(4),1.0e-10_real64,'dry guard')
  if(any(theta/=0.30_real64).or.any(cap/=0.02_real64).or.any(dk/=0.0_real64))error stop 'non-K preservation'
  call power%evaluate_point_conductivity(3,-400.0_real64,0.123_real64,pk,available)
  if(.not.available)error stop 'point unavailable'
  call close(pk,expected,'point power')
  print '(a)', 'B111_POWER_TAIL_PASS'
contains
  subroutine close(a,b,label)
    real(real64),intent(in)::a,b
    character(len=*),intent(in)::label
    if(abs(a-b)>2.0e-14_real64*max(1.0_real64,abs(a),abs(b)))then
      write(*,*)trim(label),a,b
      error stop 'power oracle mismatch'
    end if
  end subroutine
end program

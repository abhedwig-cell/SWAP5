! Candidate-only local storage difference for the smooth standard MvG branch.
! Not wired into HeadCalc. Unsupported inputs must use a separately owned path.
module mod_ppa_mvg_storage_difference
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: local_mvg_storage_difference
contains
  pure subroutine local_mvg_storage_difference(theta_range,alpha,n,m,h_before,h_after,dtheta,available)
    real(real64), intent(in) :: theta_range,alpha,n,m,h_before,h_after
    real(real64), intent(out) :: dtheta
    logical, intent(out) :: available
    real(real64) :: relative_head,x,relative_power,relative_denominator
    dtheta=0.0_real64
    available=.false.
    if(.not.all(ieee_is_finite([theta_range,alpha,n,m,h_before,h_after]))) return
    if(theta_range<=0.or.theta_range>1.or.alpha<=0.or.alpha>100) return
    if(n<=1.or.n>10.or.m<=0.or.m>=1) return
    if(h_before < -1.0e6_real64.or.h_before>=-0.01_real64) return
    if(h_after < -1.0e6_real64.or.h_after>=-0.01_real64) return
    relative_head=(h_after-h_before)/h_before
    if(abs(relative_head)>0.001_real64) return
    x=abs(alpha*h_before)**n
    relative_power=small_expm1(n*small_log1p(relative_head))
    relative_denominator=(x/(1.0_real64+x))*relative_power
    dtheta=(theta_range/(1.0_real64+x)**m)*small_expm1(-m*small_log1p(relative_denominator))
    available=ieee_is_finite(dtheta)
    if(.not.available) dtheta=0.0_real64
  end subroutine

  pure real(real64) function small_log1p(x) result(value)
    real(real64), intent(in) :: x
    real(real64) :: y,term
    integer :: k
    ! |x| <= about .011 in the admitted local envelope.
    y=x/(2.0_real64+x)
    term=y
    value=y
    do k=3,25,2
      term=term*y*y
      value=value+term/real(k,real64)
    end do
    value=2.0_real64*value
  end function

  pure real(real64) function small_expm1(x) result(value)
    real(real64), intent(in) :: x
    real(real64) :: term
    integer :: k
    term=x
    value=x
    do k=2,24
      term=term*x/real(k,real64)
      value=value+term
    end do
  end function
end module

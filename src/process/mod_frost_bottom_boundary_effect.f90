module mod_frost_bottom_boundary_effect
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: FROST_BOTTOM_OK=0, FROST_BOTTOM_INVALID=1
  type, public :: frost_bottom_config_t
    logical :: active=.false.
    real(real64) :: head_budget_cm=0.0_real64
    real(real64) :: temperature_budget_c=0.0_real64
  contains
    procedure :: valid => frost_bottom_valid
  end type
  type, public :: frost_bottom_result_t
    logical :: available=.false., blocked=.false.
    integer :: deepest_node=-1, status=FROST_BOTTOM_INVALID
    real(real64) :: available_air_cm=0.0_real64, final_flux=0.0_real64
  end type
  public :: compose_legacy_no_drain_frost_bottom
contains
  pure logical function frost_bottom_valid(self) result(ok)
    class(frost_bottom_config_t),intent(in)::self
    ok=.true.
    if(.not.self%active)return
    ok=all(ieee_is_finite([self%head_budget_cm,self%temperature_budget_c]))
    if(ok)ok=self%head_budget_cm>0.0_real64.and.self%temperature_budget_c>0.0_real64
  end function

  pure subroutine compose_legacy_no_drain_frost_bottom(active,temperature,end_c,theta,theta_sat,dz,factor,proposal,result)
    logical,intent(in)::active
    real(real64),intent(in)::temperature(:),end_c,theta(:),theta_sat(:),dz(:),factor(:),proposal
    type(frost_bottom_result_t),intent(out)::result
    integer::n,i
    result=frost_bottom_result_t()
    if(.not.ieee_is_finite(proposal))return
    result%final_flux=proposal
    if(.not.active)then
      result%available=.true.;result%status=FROST_BOTTOM_OK
      return
    end if
    n=size(temperature)
    if(n<=0)return
    if(size(theta)/=n.or.size(theta_sat)/=n.or.size(dz)/=n.or.size(factor)/=n)return
    if(.not.ieee_is_finite(end_c))return
    if(.not.ieee_is_finite(end_c+1.e-6_real64))return
    if(any(.not.ieee_is_finite(temperature)).or.any(.not.ieee_is_finite(theta)))return
    if(any(.not.ieee_is_finite(theta_sat)).or.any(.not.ieee_is_finite(dz)))return
    if(any(.not.ieee_is_finite(factor)))return
    if(any(theta<0._real64).or.any(theta_sat<=0._real64).or.any(theta_sat>1._real64))return
    if(any(dz<=0._real64).or.any(factor<0._real64).or.any(factor>1._real64))return
    ! Compatibility contract: FrozenCond decrements before testing; n is excluded.
    ! No depth interpolation is evaluated: only the legacy node index is used.
    do i=1,n-1
      if(temperature(i)<=end_c+1.e-6_real64)result%deepest_node=i
    end do
    i=n
    do
      result%available_air_cm=result%available_air_cm+max(0._real64,theta_sat(i)-theta(i))*dz(i)
      if(.not.ieee_is_finite(result%available_air_cm))return
      i=i-1
      if(i==0)exit
      if(factor(i)<=.01_real64)exit
    end do
    result%blocked=result%deepest_node>1.and.result%available_air_cm<.01_real64
    if(result%blocked)result%final_flux=0._real64
    result%available=.true.;result%status=FROST_BOTTOM_OK
  end subroutine
end module

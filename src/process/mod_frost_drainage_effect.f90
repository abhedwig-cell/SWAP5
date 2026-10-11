module mod_frost_drainage_effect
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_frost_bottom_boundary_effect, only: frost_bottom_result_t, compose_legacy_no_drain_frost_bottom
  implicit none
  private
  integer,parameter,public::FROST_DRAIN_OK=0,FROST_DRAIN_INVALID=1,FROST_DRAIN_LOW_AIR_UNQUALIFIED=2
  type,public::frost_drainage_config_t
    logical::active=.false.
    real(real64)::head_budget_cm=0._real64,temperature_budget_c=0._real64
  contains
    procedure::valid=>frost_drainage_valid
  end type
  type,public::frost_drainage_result_t
    logical::available=.false.,low_air_deep_frost=.false.
    integer::status=FROST_DRAIN_INVALID
    real(real64)::total_rate=0._real64
    real(real64),allocatable::level_rate(:)
  end type
  public::compose_legacy_normal_frost_drainage
contains
  pure logical function frost_drainage_valid(self) result(ok)
    class(frost_drainage_config_t),intent(in)::self
    ok=.true.
    if(.not.self%active)return
    ok=all(ieee_is_finite([self%head_budget_cm,self%temperature_budget_c]))
    if(ok)ok=self%head_budget_cm>0._real64.and.self%temperature_budget_c>0._real64
  end function
  pure subroutine compose_legacy_normal_frost_drainage(active,temperature,end_c,theta,theta_sat,dz,factor,proposal,final,result)
    logical,intent(in)::active
    real(real64),intent(in)::temperature(:),end_c,theta(:),theta_sat(:),dz(:),factor(:),proposal(:,:)
    real(real64),intent(out)::final(:,:)
    type(frost_drainage_result_t),intent(out)::result
    type(frost_bottom_result_t)::branch
    real(real64)::rate,total,air,part,gap
    integer::n,l,i
    result=frost_drainage_result_t();final=0._real64
    if(any(shape(final)/=shape(proposal)))return
    final=proposal
    if(any(.not.ieee_is_finite(proposal)))return
    n=size(proposal,2)
    if(n<1.or.size(proposal,1)<1)return
    if(active)then
      if(size(temperature)/=n.or.size(theta)/=n.or.size(theta_sat)/=n.or.size(dz)/=n.or.size(factor)/=n)return
      if(any(.not.ieee_is_finite(theta)).or.any(.not.ieee_is_finite(theta_sat)).or.any(.not.ieee_is_finite(dz)))return
      if(any(theta<0._real64).or.any(theta_sat<=0._real64).or.any(theta_sat>1._real64).or.any(dz<=0._real64))return
      ! Bound arithmetic before entering the shared exact legacy branch classifier.
      air=0._real64
      do i=1,n
        gap=max(0._real64,theta_sat(i)-theta(i))
        part=gap*dz(i)
        if(air>huge(air)-part)return
        air=air+part
      end do
      call compose_legacy_no_drain_frost_bottom(.true.,temperature,end_c,theta,theta_sat,dz,factor,0._real64,branch)
      if(.not.branch%available)return
      result%low_air_deep_frost=branch%blocked
      if(branch%blocked)then
        result%status=FROST_DRAIN_LOW_AIR_UNQUALIFIED
        return
      end if
    end if
    allocate(result%level_rate(size(proposal,1)))
    total=0._real64
    do l=1,size(proposal,1)
      rate=0._real64
      do i=1,n
        part=proposal(l,i)
        if(active)part=part*factor(i)
        if(.not.addition_safe(rate,part))return
        rate=rate+part
      end do
      result%level_rate(l)=rate
      if(.not.addition_safe(total,rate))return
      total=total+rate
    end do
    if(active)then
      do i=1,n
        final(:,i)=proposal(:,i)*factor(i)
      end do
    end if
    result%total_rate=total;result%available=.true.;result%status=FROST_DRAIN_OK
  end subroutine
  pure logical function addition_safe(a,b) result(ok)
    real(real64),intent(in)::a,b
    ok=.true.
    if(b>0._real64)then
      if(a>0._real64)ok=a<=huge(a)-b
    else if(b<0._real64)then
      if(a<0._real64)ok=a>=-huge(a)-b
    end if
  end function
end module

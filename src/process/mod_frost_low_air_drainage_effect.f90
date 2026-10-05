module mod_frost_low_air_drainage_effect
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_frost_geometry_effect,only:frost_geometry_result_t,evaluate_legacy_bracketed_frost_geometry
  use mod_frost_drainage_effect,only:frost_drainage_result_t,compose_legacy_normal_frost_drainage, &
       FROST_DRAIN_OK,FROST_DRAIN_LOW_AIR_UNQUALIFIED
  implicit none
  private
  type,public::frost_low_air_drainage_config_t
    logical::active=.false.
    real(real64),allocatable::drain_depth_cm(:)
  contains
    procedure::valid=>low_air_config_valid
  end type
  type,public::frost_low_air_drainage_result_t
    logical::available=.false.,low_air_branch=.false.,bottom_blocked=.false.
    real(real64)::final_bottom_flux=0._real64
    type(frost_geometry_result_t)::geometry
    type(frost_drainage_result_t)::drainage
    logical,allocatable::blocked_level(:)
  end type
  public::compose_legacy_bracketed_frost_drainage
contains
  pure logical function low_air_config_valid(self) result(ok)
    class(frost_low_air_drainage_config_t),intent(in)::self
    ok=.true.
    if(.not.self%active)return
    ok=allocated(self%drain_depth_cm)
    if(.not.ok)return
    ok=size(self%drain_depth_cm)>0
    if(ok)ok=all(ieee_is_finite(self%drain_depth_cm))
    if(ok)ok=all(self%drain_depth_cm<0._real64)
  end function
  pure subroutine compose_legacy_bracketed_frost_drainage(temperature,surface_c,start_c,end_c,theta,sat,dz,factor,z, &
       distance,drain_depth,proposal,bottom_proposal,final,result)
    real(real64),intent(in)::temperature(:),surface_c,start_c,end_c,theta(:),sat(:),dz(:),factor(:),z(:),distance(:), &
         drain_depth(:),proposal(:,:),bottom_proposal
    real(real64),intent(out)::final(:,:)
    type(frost_low_air_drainage_result_t),intent(out)::result
    integer::l,i,n,deepest
    real(real64)::total,level_rate,part
    result=frost_low_air_drainage_result_t();final=0._real64
    if(any(shape(final)/=shape(proposal)))return
    final=proposal
    if(.not.ieee_is_finite(bottom_proposal))return
    result%final_bottom_flux=bottom_proposal
    if(size(drain_depth)/=size(proposal,1).or.size(drain_depth)<1)return
    if(any(.not.ieee_is_finite(drain_depth)).or.any(drain_depth>=0._real64))return
    call compose_legacy_normal_frost_drainage(.true.,temperature,end_c,theta,sat,dz,factor,proposal,final,result%drainage)
    if(result%drainage%available)then
      allocate(result%blocked_level(size(drain_depth)));result%blocked_level=.false.
      result%available=.true.
      return
    end if
    if(result%drainage%status/=FROST_DRAIN_LOW_AIR_UNQUALIFIED)return
    result%low_air_branch=.true.
    call evaluate_legacy_bracketed_frost_geometry(temperature,surface_c,start_c,end_c,z,distance,result%geometry)
    if(.not.result%geometry%available)return
    n=size(proposal,2)
    allocate(result%drainage%level_rate(size(drain_depth)),result%blocked_level(size(drain_depth)))
    result%blocked_level=result%geometry%bottom_depth_cm<drain_depth
    total=0._real64
    do l=1,size(drain_depth)
      level_rate=0._real64
      do i=1,n
        part=proposal(l,i)
        if(result%blocked_level(l))part=0._real64
        if(.not.safe_sum(level_rate,part))return
        level_rate=level_rate+part
      end do
      result%drainage%level_rate(l)=level_rate
      if(.not.safe_sum(total,level_rate))return
      total=total+level_rate
    end do
    deepest=minloc(drain_depth,dim=1)
    result%bottom_blocked=abs(total)<1.e-6_real64.and.result%geometry%bottom_depth_cm<drain_depth(deepest)
    if(result%bottom_blocked)result%final_bottom_flux=0._real64
    do l=1,size(drain_depth)
      if(result%blocked_level(l))final(l,:)=0._real64
    end do
    result%drainage%total_rate=total;result%drainage%status=FROST_DRAIN_OK;result%drainage%available=.true.
    result%available=.true.
  end subroutine
  pure logical function safe_sum(a,b) result(ok)
    real(real64),intent(in)::a,b
    ok=.true.
    if(b>0._real64)then
      if(a>0._real64)ok=a<=huge(a)-b
    else if(b<0._real64)then
      if(a<0._real64)ok=a>=-huge(a)-b
    end if
  end function
end module

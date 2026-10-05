module mod_fmr_base_salt_temporal_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_advection_dispersion, only: mobile_transport_numerical_t
  implicit none
  private
  type, public :: fmr_base_salt_temporal_policy_t
    type(mobile_transport_numerical_t) :: transport
    logical :: enabled=.false.
    real(real64) :: head_tolerance_cm=0.0_real64
    real(real64) :: water_tolerance_cm=0.0_real64
    real(real64) :: salt_tolerance_mg_cm2=0.0_real64
    real(real64) :: temperature_tolerance_c=0.0_real64
  contains
    procedure :: valid => policy_valid
  end type
  public :: fmr_base_salt_normalized_error
contains
  pure logical function policy_valid(self) result(ok)
    class(fmr_base_salt_temporal_policy_t),intent(in)::self
    real(real64)::tol(4)
    tol=[self%head_tolerance_cm,self%water_tolerance_cm,self%salt_tolerance_mg_cm2,self%temperature_tolerance_c]
    ok=self%enabled.and.all(ieee_is_finite(tol)).and.all(tol>0.0_real64)
    if(self%transport%enabled)ok=ok.and.self%transport%valid()
  end function

  pure real(real64) function fmr_base_salt_normalized_error(policy,dz,full_head,half_head, &
       full_water,half_water,full_mass,half_mass,full_pond,half_pond,full_gw,half_gw, &
       full_temperature,half_temperature) result(error)
    type(fmr_base_salt_temporal_policy_t),intent(in)::policy
    real(real64),intent(in)::dz(:),full_head(:),half_head(:),full_water(:),half_water(:),full_mass(:),half_mass(:)
    real(real64),intent(in)::full_pond,half_pond,full_gw,half_gw
    real(real64),intent(in),optional::full_temperature(:),half_temperature(:)
    integer::n,i
    error=huge(0.0_real64)
    if(.not.policy%valid())return
    n=size(dz)
    if(n<=0.or.size(full_head)/=n.or.size(half_head)/=n.or.size(full_water)/=n.or.size(half_water)/=n.or. &
       size(full_mass)/=n.or.size(half_mass)/=n)return
    if(any(.not.ieee_is_finite(dz)).or.any(dz<=0.0_real64))return
    if(any(.not.ieee_is_finite(full_head)).or.any(.not.ieee_is_finite(half_head)).or. &
       any(.not.ieee_is_finite(full_water)).or.any(.not.ieee_is_finite(half_water)).or. &
       any(.not.ieee_is_finite(full_mass)).or.any(.not.ieee_is_finite(half_mass)))return
    if(any(full_water<0.0_real64).or.any(half_water<0.0_real64).or. &
       any(full_mass<0.0_real64).or.any(half_mass<0.0_real64))return
    if(.not.all(ieee_is_finite([full_pond,half_pond,full_gw,half_gw])))return
    if(full_pond<0.0_real64.or.half_pond<0.0_real64)return
    if(present(full_temperature).neqv.present(half_temperature))return
    if(present(full_temperature))then
      if(size(full_temperature)/=n.or.size(half_temperature)/=n)return
      if(any(.not.ieee_is_finite(full_temperature)).or.any(.not.ieee_is_finite(half_temperature)))return
    end if
    error=max(normalized_difference(full_pond,half_pond,policy%head_tolerance_cm,1.0_real64), &
         normalized_difference(full_gw,half_gw,policy%head_tolerance_cm,1.0_real64))
    do i=1,n
      error=max(error,normalized_difference(full_head(i),half_head(i),policy%head_tolerance_cm,1.0_real64), &
           normalized_difference(full_water(i),half_water(i),policy%water_tolerance_cm,dz(i)), &
           normalized_difference(full_mass(i),half_mass(i),policy%salt_tolerance_mg_cm2,1.0_real64))
      if(present(full_temperature))error=max(error, &
           normalized_difference(full_temperature(i),half_temperature(i),policy%temperature_tolerance_c,1.0_real64))
    end do
    if(.not.ieee_is_finite(error))error=huge(0.0_real64)
  end function
  pure real(real64) function normalized_difference(a,b,tolerance,weight) result(value)
    real(real64),intent(in)::a,b,tolerance,weight
    real(real64)::delta
    value=huge(0.0_real64)
    ! Saturate rejection instead of overflowing for finite extreme states or
    ! very small positive budgets, including builds with floating traps enabled.
    if((a>0.0_real64.and.b<0.0_real64).or.(a<0.0_real64.and.b>0.0_real64))then
      if(abs(a)>huge(0.0_real64)-abs(b))return
    end if
    delta=abs(a-b)
    if(weight>1.0_real64)then
      if(delta>huge(0.0_real64)/weight)return
    end if
    delta=delta*weight
    if(tolerance<1.0_real64)then
      if(delta>huge(0.0_real64)*tolerance)return
    end if
    value=delta/tolerance
  end function
end module

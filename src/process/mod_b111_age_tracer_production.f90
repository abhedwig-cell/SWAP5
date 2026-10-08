module mod_b111_age_tracer_production
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::B111_AGE_OK=0,B111_AGE_INVALID=1
 type,public::b111_age_production_result_t
  integer::status=B111_AGE_OK
  real(real64),allocatable::production_density_rate(:)
  real(real64),allocatable::production_amount(:)
  real(real64)::total_production=0d0
 end type
 public::evaluate_b111_age_production
contains
 subroutine evaluate_b111_age_production(theta_start,theta_end,dz,dt,result)
  real(real64),intent(in)::theta_start(:),theta_end(:),dz(:),dt
  type(b111_age_production_result_t),intent(out)::result
  integer::n
  result=b111_age_production_result_t();result%status=B111_AGE_INVALID
  n=size(theta_start)
  if(n<1.or.size(theta_end)/=n.or.size(dz)/=n)return
  if(.not.all(ieee_is_finite(theta_start)).or..not.all(ieee_is_finite(theta_end)).or. &
     .not.all(ieee_is_finite(dz)).or..not.ieee_is_finite(dt))return
  if(any(theta_start<0d0).or.any(theta_end<0d0).or.any(dz<=0d0).or.dt<=0d0)return
  allocate(result%production_density_rate(n),result%production_amount(n))
  result%production_density_rate=.5d0*(theta_start+theta_end)
  result%production_amount=result%production_density_rate*dt*dz
  result%total_production=sum(result%production_amount)
  result%status=B111_AGE_OK
 end subroutine
end module

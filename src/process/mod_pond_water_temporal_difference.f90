module mod_pond_water_temporal_difference
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  public::evaluate_pond_water_temporal_difference
  public::evaluate_water_flux_temporal_difference
  type,public::water_flux_temporal_policy_t
    logical::enabled=.false.
    real(real64)::state_budget_cm=0.001_real64
    real(real64)::groundwater_budget_cm=0.001_real64
    real(real64)::uptake_rate_budget_cm_day=0.001_real64
    real(real64)::output_rate_budget_cm_day=0.001_real64
  contains
    procedure::valid=>water_flux_policy_valid
  end type
contains
  logical function water_flux_policy_valid(self) result(ok)
    class(water_flux_temporal_policy_t),intent(in)::self
    real(real64)::b(4)
    b=[self%state_budget_cm,self%groundwater_budget_cm,self%uptake_rate_budget_cm_day,self%output_rate_budget_cm_day]
    ok=.false.
    if(.not.all(ieee_is_finite(b)))return
    ! Bounded numerical domain prevents overflow under trapped arithmetic.
    ok=all(b>=1.e-12_real64).and.all(b<=0.001_real64)
  end function

  subroutine evaluate_water_flux_temporal_difference(policy,dz,hf,hh,wf,wh,pf,ph,gf,gh, &
      uptake_available,uptake,output,dt,value,available)
    type(water_flux_temporal_policy_t),intent(in)::policy
    real(real64),intent(in)::dz(:),hf(:),hh(:),wf(:),wh(:),pf,ph,gf,gh,uptake(3),output(3),dt
    logical,intent(in)::uptake_available(3)
    real(real64),intent(out)::value
    logical,intent(out)::available
    real(real64)::incumbent,state_error,uptake_error,output_error
    logical::state_valid
    value=huge(0.0_real64);available=.false.
    if(.not.policy%enabled.or..not.policy%valid())return
    if(.not.all(uptake_available))return
    if(.not.all(ieee_is_finite([uptake,output,dt])))return
    if(dt<1.e-12_real64.or.dt>1.e6_real64)return
    if(any(uptake<0.0_real64).or.any(uptake>1.e12_real64).or.any(abs(output)>1.e12_real64))return
    call evaluate_pond_water_temporal_difference(hf,hh,wf,wh,pf,ph,gf,gh,incumbent,state_valid)
    if(.not.state_valid)return
    if(size(dz)/=size(wf))return
    if(.not.all(ieee_is_finite(dz)))return
    if(any(dz<=0.0_real64).or.any(dz>1.e6_real64))return
    state_error=sum(abs(wf-wh)*dz)+abs(pf-ph)
    uptake_error=abs(uptake(1)-uptake(2)-uptake(3))/dt
    output_error=abs(output(1)-output(2)-output(3))/dt
    value=max(state_error/policy%state_budget_cm,abs(gf-gh)/policy%groundwater_budget_cm, &
      uptake_error/policy%uptake_rate_budget_cm_day,output_error/policy%output_rate_budget_cm_day)
    available=ieee_is_finite(value)
  end subroutine

  subroutine evaluate_pond_water_temporal_difference(hf,hh,wf,wh,pf,ph,gf,gh,value,available)
    real(real64),intent(in)::hf(:),hh(:),wf(:),wh(:),pf,ph,gf,gh
    real(real64),intent(out)::value
    logical,intent(out)::available
    integer::n
    available=.false.;value=huge(0.0_real64)
    n=size(hf)
    if(n<1.or.n>4096)return
    if(size(hh)/=n.or.size(wf)/=n.or.size(wh)/=n)return
    if(.not.all(ieee_is_finite(hf)).or..not.all(ieee_is_finite(hh)).or. &
       .not.all(ieee_is_finite(wf)).or..not.all(ieee_is_finite(wh)))return
    if(.not.all(ieee_is_finite([pf,ph,gf,gh])))return
    if(any(abs(hf)>1.e6_real64).or.any(abs(hh)>1.e6_real64))return
    if(min(pf,ph)<0.0_real64.or.max(pf,ph)>1.e6_real64)return
    if(max(abs(gf),abs(gh))>1.e6_real64)return
    if(any(wf<0.0_real64).or.any(wf>1.0_real64).or.any(wh<0.0_real64).or.any(wh>1.0_real64))return
    value=max(maxval(abs(hf-hh)),abs(pf-ph),abs(gf-gh))
    available=.true.
  end subroutine
end module

module mod_pond_water_temporal_difference
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  public::evaluate_pond_water_temporal_difference
contains
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

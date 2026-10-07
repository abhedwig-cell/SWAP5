module mod_b111_explicit_cauchy_profile_flux
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: B111_EXPLICIT_CAUCHY_OK=0
  integer, parameter, public :: B111_EXPLICIT_CAUCHY_INVALID=1
  integer, parameter, public :: B111_EXPLICIT_CAUCHY_GWL_OUTSIDE_PROFILE=2
  public :: evaluate_b111_explicit_cauchy_profile_flux
contains
  pure subroutine evaluate_b111_explicit_cauchy_profile_flux(gwl_cm,hdrain_cm,shape_3,deepgw_cm,rimlay_day, &
       ztopcp_cm,zbotcp_cm,dz_cm,ksat_cm_per_day,q4_cm_per_day,qbot_cm_per_day, &
       gwlmean_cm,cvalprof_day,status)
    real(real64),intent(in)::gwl_cm,hdrain_cm,shape_3,deepgw_cm,rimlay_day
    real(real64),intent(in)::ztopcp_cm(:),zbotcp_cm(:),dz_cm(:),ksat_cm_per_day(:),q4_cm_per_day
    real(real64),intent(out)::qbot_cm_per_day,gwlmean_cm,cvalprof_day
    integer,intent(out)::status
    integer::n,node,nodnumgwl
    real(real64)::satnodgwl,denom
    qbot_cm_per_day=0._real64;gwlmean_cm=0._real64;cvalprof_day=0._real64;status=B111_EXPLICIT_CAUCHY_INVALID
    n=size(dz_cm)
    if(n<=0.or.size(ztopcp_cm)/=n.or.size(zbotcp_cm)/=n.or.size(ksat_cm_per_day)/=n)return
    if(.not.all(ieee_is_finite([gwl_cm,hdrain_cm,shape_3,deepgw_cm,rimlay_day,q4_cm_per_day])))return
    if(any(.not.ieee_is_finite(ztopcp_cm)).or.any(.not.ieee_is_finite(zbotcp_cm)).or. &
       any(.not.ieee_is_finite(dz_cm)).or.any(.not.ieee_is_finite(ksat_cm_per_day)))return
    if(any(dz_cm<=0._real64).or.any(ksat_cm_per_day<=0._real64).or.rimlay_day<0._real64)return
    gwlmean_cm=hdrain_cm+shape_3*(gwl_cm-hdrain_cm)
    if(.not.ieee_is_finite(gwlmean_cm))return
    node=n
    do while(gwlmean_cm>ztopcp_cm(node).and.node>1)
      node=node-1
    end do
    nodnumgwl=node
    satnodgwl=gwlmean_cm-zbotcp_cm(nodnumgwl)
    if(.not.ieee_is_finite(satnodgwl).or.satnodgwl<0._real64.or.satnodgwl>dz_cm(nodnumgwl))then
      status=B111_EXPLICIT_CAUCHY_GWL_OUTSIDE_PROFILE;return
    end if
    cvalprof_day=satnodgwl/ksat_cm_per_day(nodnumgwl)
    do node=nodnumgwl+1,n
      cvalprof_day=cvalprof_day+dz_cm(node)/ksat_cm_per_day(node)
    end do
    denom=rimlay_day+cvalprof_day
    if(.not.ieee_is_finite(denom).or.denom<=0._real64)return
    qbot_cm_per_day=(deepgw_cm-gwlmean_cm)/denom+q4_cm_per_day
    if(.not.ieee_is_finite(qbot_cm_per_day))then;qbot_cm_per_day=0._real64;return;end if
    status=B111_EXPLICIT_CAUCHY_OK
  end subroutine
end module

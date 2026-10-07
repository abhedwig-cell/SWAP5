module mod_fmr_legacy_explicit_cauchy_bottom_boundary_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: FMR_EXPLICIT_CAUCHY3_OK=0
  integer, parameter, public :: FMR_EXPLICIT_CAUCHY3_INVALID=1
  type, public :: fmr_explicit_cauchy3_result_t
    logical :: available=.false.
    integer :: groundwater_node=0
    real(real64) :: mean_groundwater_level_cm=0.0_real64
    real(real64) :: profile_resistance_days=0.0_real64
    real(real64) :: qbot_cm_per_day=0.0_real64
  end type
  public :: fmr_evaluate_legacy_explicit_cauchy_bottom_boundary
contains
  pure subroutine fmr_evaluate_legacy_explicit_cauchy_bottom_boundary(hdrain_cm,gwl_cm,shape_3,deepgw_cm,rimlay_days, &
       qbot4_cm_per_day,zbotcp_cm,ztopcp_cm,dz_cm,ksat_cm_per_day,result,status)
    real(real64),intent(in)::hdrain_cm,gwl_cm,shape_3,deepgw_cm,rimlay_days,qbot4_cm_per_day
    real(real64),intent(in)::zbotcp_cm(:),ztopcp_cm(:),dz_cm(:),ksat_cm_per_day(:)
    type(fmr_explicit_cauchy3_result_t),intent(out)::result
    integer,intent(out)::status
    integer::n,node,nodnumgwl,i
    real(real64)::gwlmean,satnodgwl,cvalprof,denom
    result=fmr_explicit_cauchy3_result_t();status=FMR_EXPLICIT_CAUCHY3_INVALID
    n=size(dz_cm)
    if(n<=0.or.size(zbotcp_cm)/=n.or.size(ztopcp_cm)/=n.or.size(ksat_cm_per_day)/=n)return
    if(.not.ieee_is_finite(hdrain_cm).or..not.ieee_is_finite(gwl_cm).or..not.ieee_is_finite(shape_3))return
    if(.not.ieee_is_finite(deepgw_cm).or..not.ieee_is_finite(rimlay_days).or..not.ieee_is_finite(qbot4_cm_per_day))return
    if(any(.not.ieee_is_finite(zbotcp_cm)).or.any(.not.ieee_is_finite(ztopcp_cm)).or. &
       any(.not.ieee_is_finite(dz_cm)).or.any(.not.ieee_is_finite(ksat_cm_per_day)))return
    if(any(dz_cm<=0.0_real64).or.any(ksat_cm_per_day<=0.0_real64).or.rimlay_days<0.0_real64)return
    gwlmean=hdrain_cm+shape_3*(gwl_cm-hdrain_cm)
    if(.not.ieee_is_finite(gwlmean))return
    node=n
    do while(gwlmean>ztopcp_cm(node).and.node>1)
      node=node-1
    end do
    nodnumgwl=node
    satnodgwl=gwlmean-zbotcp_cm(nodnumgwl)
    if(satnodgwl<0.0_real64.or.satnodgwl>dz_cm(nodnumgwl))return
    cvalprof=satnodgwl/ksat_cm_per_day(nodnumgwl)
    do i=nodnumgwl+1,n
      cvalprof=cvalprof+dz_cm(i)/ksat_cm_per_day(i)
    end do
    denom=rimlay_days+cvalprof
    if(.not.ieee_is_finite(cvalprof).or.denom<=tiny(denom))return
    result%qbot_cm_per_day=(deepgw_cm-gwlmean)/denom+qbot4_cm_per_day
    if(.not.ieee_is_finite(result%qbot_cm_per_day))return
    result%available=.true.;result%groundwater_node=nodnumgwl
    result%mean_groundwater_level_cm=gwlmean;result%profile_resistance_days=cvalprof
    status=FMR_EXPLICIT_CAUCHY3_OK
  end subroutine
end module mod_fmr_legacy_explicit_cauchy_bottom_boundary_provider

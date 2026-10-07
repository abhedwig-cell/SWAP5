module mod_b111_soil_n_transport
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::B111_NTRANS_OK=0,B111_NTRANS_INVALID=1
 type,public::b111_soil_n_transport_result_t
   integer::status=B111_NTRANS_OK
   integer::solution_class=0
   real(real64)::concentration_end=0d0
   real(real64)::concentration_average=0d0
   real(real64)::production_actual=0d0
 end type
 public::evaluate_b111_soil_n_transport
contains
 subroutine detcoef(iflsol,a1,a2,avs,b1,b2,hv,hv1,mto,rhbd,t,status)
  integer,intent(in)::iflsol
  real(real64),intent(out)::a1,a2,b1,b2
  real(real64),intent(in)::avs,hv,hv1,mto,rhbd,t
  integer,intent(out)::status
  real(real64)::base
  a1=0d0;a2=0d0;b1=0d0;b2=0d0;status=B111_NTRANS_INVALID
  if(.not.all(ieee_is_finite([avs,hv,hv1,mto,rhbd,t])).or.t<=0d0)return
  select case(iflsol)
  case(1)
    if(abs(hv)<=tiny(1d0).or.abs(hv1)<=tiny(1d0).or.abs(hv-hv1)<=tiny(1d0))return
    base=(mto+rhbd*avs+hv*t)/(mto+rhbd*avs);if(base<=0d0)return
    a1=base**(-hv1/hv);a2=(1d0-a1)/hv1
    b1=base**((hv-hv1)/hv)-1d0;b1=b1*(mto+rhbd*avs)/(t*(hv-hv1));b2=(1d0-b1)/hv1
  case(2)
    if(abs(hv)<=tiny(1d0).or.abs(hv1)<=tiny(1d0))return
    base=(mto+rhbd*avs+hv*t)/(mto+rhbd*avs);if(base<=0d0)return
    a1=base**(-hv1/hv);a2=(1d0-a1)/hv1
    b1=(mto+rhbd*avs)/hv/t*log(base);b2=(1d0-b1)/hv1
  case(3)
    if(abs(hv1)<=tiny(1d0).or.mto+rhbd*avs<=0d0)return
    a1=exp(-hv1/(mto+rhbd*avs)*t);a2=(1d0-a1)/hv1
    b1=(1d0-a1)/(hv1/(mto+rhbd*avs)*t);b2=(1d0-b1)/hv1
  case(4)
    if(abs(hv)<=tiny(1d0).or.mto+rhbd*avs<=0d0)return
    base=(mto+rhbd*avs+hv*t)/(mto+rhbd*avs);if(base<=0d0)return
    a1=1d0;a2=log(base)/hv;b1=1d0;b2=a2*(mto+rhbd*avs+hv*t)/(hv*t)-1d0/hv
  case(5)
    if(mto+rhbd*avs<=0d0)return
    a1=1d0;a2=t/(mto+rhbd*avs);b1=1d0;b2=.5d0*t/(mto+rhbd*avs)
  case default
    return
  end select
  if(.not.all(ieee_is_finite([a1,a2,b1,b2])))return
  status=B111_NTRANS_OK
 end subroutine

 subroutine evaluate_b111_soil_n_transport(dz,dt,wfrac_t,wfrac_t0,wflux_out,wflux_transp, &
      wflux_inbot,wflux_intop,wflux_inlat,tcsf,ratecon,producpot,drybd,sorpcoef,cseep,ctop,clat, &
      c_t0,result)
  real(real64),intent(in)::dz,dt,wfrac_t,wfrac_t0,wflux_out,wflux_transp,wflux_inbot,wflux_intop,wflux_inlat
  real(real64),intent(in)::tcsf,ratecon,producpot,drybd,sorpcoef,cseep,ctop,clat,c_t0
  type(b111_soil_n_transport_result_t),intent(out)::result
  real(real64),parameter::small=1d-8,vsmall=1d-12,vvsmall=1d-20,half=.5d0
  real(real64)::a1,a2,b1,b2,wfrac_av,hv,hv1,hv2,hv3,ttry,cav1
  logical::hvnil,hv1nil
  integer::iflsol,status
  result=b111_soil_n_transport_result_t();result%status=B111_NTRANS_INVALID
  if(.not.all(ieee_is_finite([dz,dt,wfrac_t,wfrac_t0,wflux_out,wflux_transp,wflux_inbot,wflux_intop, &
      wflux_inlat,tcsf,ratecon,producpot,drybd,sorpcoef,cseep,ctop,clat,c_t0])))return
  if(dz<=0d0.or.dt<=0d0.or.wfrac_t<0d0.or.wfrac_t0<0d0.or.wflux_out<0d0.or.wflux_transp<0d0.or. &
     wflux_inbot<0d0.or.wflux_intop<0d0.or.wflux_inlat<0d0.or.tcsf<0d0.or.ratecon<0d0.or. &
     drybd<0d0.or.sorpcoef<0d0.or.min(cseep,ctop,clat,c_t0)<0d0)return
  result%production_actual=producpot
  wfrac_av=half*(wfrac_t+wfrac_t0)
  hv=(wfrac_t-wfrac_t0)/dt;hvnil=abs(hv)<small;if(hvnil)hv=0d0
  hv1=hv+wflux_out/dz+tcsf*wflux_transp/dz+ratecon*wfrac_av
  hv1nil=abs(hv1)<small;if(hv1nil)hv1=0d0
  hv2=wflux_inbot*cseep/dz+wflux_intop*ctop/dz+wflux_inlat*clat/dz+producpot
  if(.not.hvnil.and..not.hv1nil)then;if(abs(hv-hv1)>small)then;iflsol=1;else;iflsol=2;end if
  else if(hvnil.and..not.hv1nil)then;iflsol=3
  else if(.not.hvnil.and.hv1nil)then;iflsol=4
  else;iflsol=5
  end if
  result%solution_class=iflsol
  if(iflsol==1.or.iflsol==2)then
    if(wfrac_t*dz<=1d-6.and.wfrac_t0*dz>1d-6)then
      result%concentration_end=0d0;result%concentration_average=(hv2-hv*c_t0)/(hv1-hv);result%status=B111_NTRANS_OK;return
    else if(wfrac_t*dz>1d-6.and.wfrac_t0*dz<=1d-6)then
      result%concentration_end=hv2/hv1;result%concentration_average=hv2/hv1;result%status=B111_NTRANS_OK;return
    end if
  else if(iflsol==4)then
    if(wfrac_t*dz<=1d-6.and.wfrac_t0*dz>1d-6)then
      result%concentration_end=0d0;result%concentration_average=c_t0-hv2/hv;result%status=B111_NTRANS_OK;return
    else if(wfrac_t*dz>1d-6.and.wfrac_t0*dz<=1d-6)then
      result%concentration_end=hv2/hv;result%concentration_average=hv2/hv;result%status=B111_NTRANS_OK;return
    end if
  end if
  if(iflsol<=3.and.abs(hv1*c_t0-hv2)<=vvsmall)then
    result%concentration_end=c_t0;result%concentration_average=c_t0;result%status=B111_NTRANS_OK;return
  end if
  call detcoef(iflsol,a1,a2,sorpcoef,b1,b2,hv,hv1,wfrac_t0,drybd,dt,status);if(status/=B111_NTRANS_OK)return
  result%concentration_end=a1*c_t0+a2*hv2;result%concentration_average=b1*c_t0+b2*hv2
  if(result%concentration_end<0d0)then
    if(result%concentration_end+vsmall>0d0 .or. (iflsol<=3.and. &
       abs(hv1*c_t0-hv2)>vvsmall .and. (hv1*vsmall-hv2)/(hv1*c_t0-hv2)<vsmall))then
      result%concentration_end=c_t0;result%concentration_average=c_t0;result%status=B111_NTRANS_OK;return
    end if
    hv3=wfrac_t0+drybd*sorpcoef
    select case(iflsol)
    case(1,2)
      ttry=hv3/hv*(((hv1*vsmall-hv2)/(hv1*c_t0-hv2))**(-hv/hv1)-1d0)
    case(3)
      ttry=-hv3/hv1*log((hv1*vsmall-hv2)/(hv1*c_t0-hv2))
    case(4)
      ttry=hv3/hv*(exp(hv/hv2*(vsmall-c_t0))-1d0)
    case(5)
      ttry=hv3/hv2*(vsmall-c_t0)
    end select
    result%concentration_end=vsmall
    if(ttry<vsmall)then
      result%concentration_average=vsmall;result%production_actual=vsmall
    else
      call detcoef(iflsol,a1,a2,sorpcoef,b1,b2,hv,hv1,wfrac_t0,drybd,ttry,status);if(status/=B111_NTRANS_OK)return
      cav1=b1*c_t0+b2*hv2
      result%concentration_average=(ttry*(wfrac_t0+half*ttry*hv)*cav1+(dt-ttry)* &
           (wfrac_t-half*(dt-ttry)*hv)*vsmall)/(dt*wfrac_av)
      result%production_actual=producpot*ttry/dt
    end if
  end if
  if(.not.all(ieee_is_finite([result%concentration_end,result%concentration_average,result%production_actual])))return
  if(result%concentration_end<0d0.or.result%concentration_average<0d0)return
  result%status=B111_NTRANS_OK
 end subroutine
end module

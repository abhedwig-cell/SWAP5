! SWAP-020 candidate: finite-donor correction of the historical aggregate.
! This is an isolated corrected-reference routine, not a pond mixing model.
subroutine Wofost_SoilWaterN_Negative(dz,dt,wt,w0,qout,qroot,qbot,qtop,qlat, &
    tcsf,rate,production,sorption,cbot,ctop,clat,c0,ce,ca,top_actual,unmet,depleted,status)
  use MOD_texture_orgmat, only: bdens
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  real(8),intent(in)::dz,dt,wt,w0,qout,qroot,qbot,qtop,qlat,tcsf,rate,production
  real(8),intent(in)::sorption,cbot,ctop,clat,c0
  real(8),intent(out)::ce,ca,top_actual,unmet,depleted
  integer,intent(out)::status
  real(8)::h,h1,h2,positive,requested,a1,a2,b1,b2,lo,hi,mid,candidate,unused,roundoff
  integer::kind,i
  ce=0d0;ca=0d0;top_actual=0d0;unmet=0d0;depleted=0d0;status=1
  if(.not.all(ieee_is_finite([dz,dt,wt,w0,qout,qroot,qbot,qtop,qlat,tcsf,rate,production, &
       sorption,cbot,ctop,clat,c0,bdens(1)])))return
  if(dz<=0d0.or.dt<=0d0.or.min(wt,w0)<=0d0.or.qtop>=0d0)return
  if(min(qout,qroot,qbot,qlat,tcsf,rate,production,sorption,cbot,ctop,clat,c0,bdens(1))<0d0)return
  ! Positive production/inflow continues after exhaustion. Only the requested
  ! negative top loading is constrained; no source is inferred from a residual.
  positive=(qbot*cbot+qlat*clat)/dz+production
  requested=-qtop*ctop/dz
  h=(wt-w0)/dt
  h1=h+qout/dz+tcsf*qroot/dz+rate*.5d0*(wt+w0)
  h2=positive-requested
  roundoff=32d0*epsilon(1d0)*max(abs(h),qout/dz+tcsf*qroot/dz+rate*.5d0*(wt+w0))
  if(abs(h1)<=roundoff)h1=0d0
  if(abs(h)<1d-8.and.h/=0d0)return
  if(abs(h1)<1d-8.and.h1/=0d0)return
  if(h/=0d0.and.h1/=0d0)then
    if(abs(h-h1)>1d-8)then
      kind=1
    else if(abs(h-h1)<=roundoff)then
      kind=2
    else
      return
    end if
  else if(h==0d0.and.h1/=0d0)then
    kind=3
  else if(h/=0d0)then
    kind=4
  else
    kind=5
  end if
  if(min(w0,wt)*dz<=1d-6)return
  call Detcoef2(kind,a1,a2,sorption,b1,b2,h,h1,w0,dt)
  ce=a1*c0+a2*h2;ca=b1*c0+b2*h2
  top_actual=qtop*ctop
  if(ce<0d0)then
    if(h2>=0d0)return
    lo=0d0;hi=dt
    ! The unconstrained analytical trajectory has a unique zero while h2<0.
    ! Bisection determines its time independently of the nitrogen balance.
    do i=1,90
      mid=lo+.5d0*(hi-lo)
      if(mid<=lo.or.mid>=hi)exit
      call Detcoef2(kind,a1,a2,sorption,b1,b2,h,h1,w0,mid)
      candidate=a1*c0+a2*h2
      if(candidate>0d0)then
        lo=mid
      else
        hi=mid
      end if
    end do
    depleted=lo+.5d0*(hi-lo)
    if(c0==0d0)depleted=0d0
    ca=0d0
    if(depleted>0d0)then
      call Detcoef2(kind,a1,a2,sorption,b1,b2,h,h1,w0,depleted)
      ca=(depleted/dt)*(b1*c0+b2*h2)
    end if
    ce=0d0
    top_actual=-dz*(requested*depleted+positive*(dt-depleted))/dt
    unmet=dz*(requested-positive)*(dt-depleted)
  else
    depleted=dt
    ! Outside depletion preserve the literal source's analytical results.
    call Wofost_SoilWaterN(dz,dt,wt,w0,qout,qroot,qbot,qtop,qlat,tcsf,rate, &
         production,unused,sorption,cbot,ctop,clat,c0,ce,ca)
  end if
  if(.not.all(ieee_is_finite([ce,ca,top_actual,unmet,depleted])))return
  if(min(ce,ca,unmet)<0d0.or.top_actual>0d0.or.top_actual<qtop*ctop)return
  status=0
end subroutine

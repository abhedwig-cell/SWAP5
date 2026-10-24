module mod_multipool_limited_organic
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_pool_state
 use mod_b111_soil_organic_turnover
 implicit none
 private
 type,public::multipool_receipt_t
  integer::status=1,accepted_steps=0,rejected_steps=0,limited_steps=0
  real(real64)::carbon=0d0,n_residual=0d0,c_residual=0d0
 end type
 public::advance_multipool_limited
contains
 subroutine advance_multipool_limited(p,s,k,dt,atol,rtol,c,r)
  type(soil_n_inventory_parameters_t),intent(in)::p
  type(soil_n_pool_state_t),intent(in)::s
  type(b111_organic_turnover_parameters_t),intent(in)::k
  real(real64),intent(in)::dt,atol,rtol
  type(soil_n_pool_state_t),intent(out)::c
  type(multipool_receipt_t),intent(out)::r
  type(b111_organic_turnover_result_t)::probe
  type(soil_n_transfer_t)::transfer
  type(soil_n_pool_state_t)::candidate
  type(soil_n_receipt_t)::budget
  real(real64),allocatable::a(:,:),gamma(:),rates(:),y(:),whole(:),half(:),fine(:),nfrac(:)
  real(real64)::clock,h,cap,err,factor,carbon,cr
  integer::n,d,i,tries
  logical::lim1,lim2,lim3
  c=s;r=multipool_receipt_t()
  if(.not.p%valid().or..not.s%valid())return
  if(.not.all(ieee_is_finite([dt,atol,rtol])))return
  if(dt<1d-6.or.dt>100d0.or.atol<1d-14.or.rtol<1d-12.or.atol>1d-3.or.rtol>1d-2)return
  if(p%depth_m<1d-6.or.p%depth_m>100d0)return
  n=size(s%fom_kg_m3);d=n+2
  if(size(p%nfrac_fom)/=n)return
  if(maxval([p%nfrac_fom,p%nfrac_biomass,p%nfrac_humus])>1d0)return
  if(maxval([s%fom_kg_m3,s%biomass_kg_m3,s%humus_kg_m3,s%ammonium_n_kg_m2])>100d0)return
  call evaluate_b111_organic_turnover(s%fom_kg_m3,s%biomass_kg_m3,s%humus_kg_m3,dt,k,probe)
  if(probe%status/=0)return
  rates=[k%ratecon_fom,k%ratecon_bio,k%ratecon_hum]
  if(maxval(rates)>100d0)return
  allocate(a(d,d),gamma(d),y(d+2),whole(d+2),half(d+2),fine(d+2))
  a=0d0
  do i=1,d
   a(i,i)=-1d0
  end do
  a(n+1,:n)=k%asfa_fom_bio;a(n+2,:n)=k%asfa_fom_hum
  a(n+1,n+1)=a(n+1,n+1)+k%asfa_bio;a(n+2,n+1)=k%asfa_hum
  a(n+1,n+2)=k%asfa_bio;a(n+2,n+2)=a(n+2,n+2)+k%asfa_hum
  nfrac=[p%nfrac_fom,p%nfrac_biomass,p%nfrac_humus]
  gamma=-matmul(nfrac,a)
  y=[s%fom_kg_m3,s%biomass_kg_m3,s%humus_kg_m3,s%ammonium_n_kg_m2/p%depth_m,0d0]
  cap=dt
  if(maxval(rates)>0d0)cap=min(cap,.25d0/maxval(rates))
  h=min(dt/8d0,cap);clock=0d0
  do tries=1,500000
   if(clock>=dt)exit
   h=min(h,dt-clock,cap)
   if(clock+h==clock.or.h<1d-16*max(1d0,dt))return
   call rk(y,h,whole,lim1)
   call rk(y,h*.5d0,half,lim2)
   call rk(half,h*.5d0,fine,lim3)
   err=maxval(abs(fine-whole)/(atol+rtol*max(abs(y),abs(fine))))
   if(.not.ieee_is_finite(err).or.minval(fine)<0d0)return
   if(err<=1d0)then
    y=fine;clock=clock+h;r%accepted_steps=r%accepted_steps+1
    if(lim2.or.lim3)r%limited_steps=r%limited_steps+1
   else
    r%rejected_steps=r%rejected_steps+1
   end if
   factor=2d0
   if(err>0d0)factor=max(.2d0,min(2d0,.8d0*err**(-1d0/3d0)))
   h=h*factor
  end do
  if(clock<dt)return
  transfer%fom_delta_kg_m3=y(:n)-s%fom_kg_m3
  transfer%biomass_delta_kg_m3=y(n+1)-s%biomass_kg_m3
  transfer%humus_delta_kg_m3=y(n+2)-s%humus_kg_m3
  transfer%ammonium_n_delta_kg_m2=y(d+1)*p%depth_m-s%ammonium_n_kg_m2
  call apply_soil_n_transfer(p,s,transfer,candidate,budget)
  if(budget%status/=0)return
  carbon=y(d+2)*p%depth_m
  cr=.45d0*p%depth_m*(sum(y(:d))-sum(s%fom_kg_m3)-s%biomass_kg_m3-s%humus_kg_m3)+carbon
  if(abs(cr)>1d-12)return
  c=candidate;r%carbon=carbon;r%n_residual=budget%balance_residual_kg_m2;r%c_residual=cr;r%status=0
 contains
  subroutine euler(v,step,q,limited)
   real(real64),intent(in)::v(:),step
   real(real64),intent(out)::q(:)
   logical,intent(out)::limited
   real(real64)::flow(d),source,demand,alpha
   flow=rates*v(:d)
   source=sum(max(0d0,gamma)*flow);demand=sum(max(0d0,-gamma)*flow)
   alpha=1d0
   if(demand>0d0)alpha=min(1d0,(v(d+1)/step+source)/demand)
   limited=alpha<1d0
   where(gamma<0d0)flow=flow*alpha
   q(:d)=v(:d)+step*matmul(a,flow)
   if(limited)then
    q(d+1)=0d0
   else
    q(d+1)=max(0d0,v(d+1)+step*sum(gamma*flow))
   end if
   q(d+2)=v(d+2)-.45d0*step*sum(matmul(a,flow))
  end subroutine
  subroutine rk(v,step,q,limited)
   real(real64),intent(in)::v(:),step
   real(real64),intent(out)::q(:)
   logical,intent(out)::limited
   real(real64)::tmp(size(v)),last(size(v))
   logical::l1,l2
   call euler(v,step,tmp,l1);call euler(tmp,step,last,l2)
   q=.5d0*(v+last);limited=l1.or.l2
  end subroutine
 end subroutine
end module

module mod_path_limited_organic
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_organic_turnover
 use mod_b111_soil_organic_dissimilation
 use mod_soil_n_pool_state
 implicit none
 private
 real(real64),parameter::nf=.001d0,nb=.08d0,assim=.5d0,need=assim*nb-nf,cf=.45d0
 type,public::path_limited_result_t
  integer::status=1
  real(real64)::fom=0d0,bio=0d0,nh4=0d0,carbon=0d0
  real(real64)::depletion=-1d0,release=-1d0,boundary_duration=0d0,n_residual=0d0,c_residual=0d0
 end type
 public::advance_path_limited_organic
contains
 subroutine advance_path_limited_organic(f0,b0,m0,kf,kb,dt,r)
  real(real64),intent(in)::f0,b0,m0,kf,kb,dt
  type(path_limited_result_t),intent(out)::r
  type(soil_n_inventory_parameters_t)::p
  type(soil_n_pool_state_t)::old,candidate
  type(soil_n_transfer_t)::transfer
  type(soil_n_receipt_t)::receipt
  real(real64)::f,b,m,carbon,tpeak,lo,hi,mid,ff,bb,cc,release_time, &
    b_release,remaining,boundary,organic_n,rate,g0,g1,clock
  integer::i,code
  r=path_limited_result_t();r%fom=f0;r%bio=b0;r%nh4=m0
  if(.not.all(ieee_is_finite([f0,b0,m0,kf,kb,dt])))return
  if(min(f0,b0,m0,kf,kb)<0d0.or.dt<=0d0.or.max(f0,b0,m0,kf,kb,dt)>100d0)return
  f=f0;b=b0;m=m0;carbon=0d0;clock=0d0
  call free(f0,b0,dt,ff,bb,cc,code);if(code/=0)return
  g0=need*kf*f0-nb*kb*b0;g1=need*kf*ff-nb*kb*bb
  tpeak=dt
  if(g0>0d0.and.g1<0d0)then
   lo=0d0;hi=dt
   do i=1,65
    mid=(lo+hi)/2d0;call free(f0,b0,mid,ff,bb,cc,code);if(code/=0)return
    if(need*kf*ff-nb*kb*bb>0d0)then;lo=mid;else;hi=mid;end if
   end do
   tpeak=(lo+hi)/2d0
  end if
  call free(f0,b0,tpeak,ff,bb,cc,code);if(code/=0)return
  if(g0>0d0.and.m0+nf*(f0-ff)+nb*(b0-bb)<0d0)then
   lo=0d0;hi=tpeak
   if(m0>0d0)then
    do i=1,65
     mid=(lo+hi)/2d0;call free(f0,b0,mid,ff,bb,cc,code);if(code/=0)return
     if(m0+nf*(f0-ff)+nb*(b0-bb)>0d0)then;lo=mid;else;hi=mid;end if
    end do
    clock=(lo+hi)/2d0
   end if
   call free(f0,b0,clock,f,b,carbon,code);if(code/=0)return
   r%depletion=clock;m=0d0;remaining=dt-clock
   if(b>0d0.and.kb>0d0)then
    organic_n=nf*f+nb*b
    b_release=organic_n/(nb*(1d0+nf*kb/(need*kf)))
    rate=nf*kb/need
    release_time=max(0d0,log(b_release/b)/rate)
    boundary=min(remaining,release_time)
    bb=b*exp(rate*boundary);ff=(organic_n-nb*bb)/nf
    if(ff<0d0)return
    carbon=carbon+cf*((f-ff)+(b-bb));f=ff;b=bb
   else
    boundary=remaining;release_time=huge(0d0)
   end if
   r%boundary_duration=boundary
   clock=clock+boundary
   if(release_time<remaining)then
    r%release=clock
    call free(f,b,dt-clock,ff,bb,cc,code);if(code/=0)return
    carbon=carbon+cc;f=ff;b=bb
   end if
  else
   call free(f0,b0,dt,f,b,carbon,code);if(code/=0)return
  end if
  m=m0+nf*(f0-f)+nb*(b0-b)
  if(m < -128d0*epsilon(1d0)*max(1d0,m0,nf*f0,nb*b0))return
  m=max(0d0,m)
  p%depth_m=1d0;p%nfrac_fom=[nf];p%nfrac_biomass=nb;p%nfrac_humus=.02d0
  call initialize_soil_n_pool_state(p,[f0],b0,0d0,m0,0d0,old,code);if(code/=0)return
  transfer%fom_delta_kg_m3=[f-f0];transfer%biomass_delta_kg_m3=b-b0
  transfer%ammonium_n_delta_kg_m2=m-m0
  call apply_soil_n_transfer(p,old,transfer,candidate,receipt)
  if(receipt%status/=0)return
  r%fom=candidate%fom_kg_m3(1);r%bio=candidate%biomass_kg_m3;r%nh4=candidate%ammonium_n_kg_m2
  r%carbon=carbon;r%n_residual=receipt%balance_residual_kg_m2
  r%c_residual=cf*((f-f0)+(b-b0))+carbon
  if(abs(r%c_residual)>1d-12)then
   r%fom=f0;r%bio=b0;r%nh4=m0;r%carbon=0d0;return
  end if
  r%status=0
 contains
  subroutine free(fi,bi,span,fo,bo,co,status)
   real(real64),intent(in)::fi,bi,span
   real(real64),intent(out)::fo,bo,co
   integer,intent(out)::status
   type(b111_organic_turnover_parameters_t)::k
   type(b111_organic_turnover_result_t)::o
   type(b111_organic_dissimilation_result_t)::d
   fo=fi;bo=bi;co=0d0;status=0
   if(span==0d0)return
   k%ratecon_fom=[kf];k%ratecon_bio=kb;k%ratecon_hum=0d0
   k%asfa_fom_bio=[assim];k%asfa_fom_hum=[0d0];k%asfa_bio=0d0;k%asfa_hum=0d0
   call evaluate_b111_organic_turnover([fi],bi,0d0,span,k,o)
   status=o%status;if(status/=0)return
   call evaluate_b111_organic_dissimilation([fi],bi,0d0,1d0,span,k,o,[cf],cf,cf,d)
   status=d%status;if(status/=0)return
   fo=o%fom_kg_m3(1);bo=o%biomass_kg_m3;co=d%carbon_dissimilation_kg_m2
  end subroutine
 end subroutine
end module

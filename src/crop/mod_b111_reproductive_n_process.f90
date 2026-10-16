module mod_b111_reproductive_n_process
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use MOD_wofost81_nitrogen,only:WOFOST81_n_state,WOFOST81_n_param,WOFOST81_n_request,WOFOST81_n_flux, &
      WOFN81_OK,WOFN81_INVALID_INPUT
 implicit none
 private
 integer,parameter,public::B111_REPRO_OK=0,B111_REPRO_INVALID=1,B111_REPRO_ALLOCATION=2, &
      B111_REPRO_OVERDRAW=3,B111_REPRO_BALANCE=4
 type,public::b111_reproductive_policy_t
  real(real64)::dvsnlt=0d0,dvsnt=0d0,nfixf=0d0,fntrt=0d0
 end type
 type,public::b111_reproductive_prepared_t
  private
  logical::available=.false.
  type(WOFOST81_n_state)::before
  type(WOFOST81_n_request)::request
  real(real64)::death(3)=0d0
 contains
  procedure::ready=>prepared_ready
  procedure::request_view
 end type
 public::valid_b111_reproductive_policy,prepare_b111_reproductive_n,apply_b111_reproductive_n
contains
 logical function prepared_ready(self)result(ok)
  class(b111_reproductive_prepared_t),intent(in)::self
  ok=self%available
 end function
 function request_view(self)result(r)
  class(b111_reproductive_prepared_t),intent(in)::self
  type(WOFOST81_n_request)::r
  r=self%request
  if(.not.self%available)r%status=WOFN81_INVALID_INPUT
 end function
 pure logical function valid_b111_reproductive_policy(p)result(ok)
  type(b111_reproductive_policy_t),intent(in)::p
  ok=.false.
  if(.not.all(ieee_is_finite([p%dvsnlt,p%dvsnt,p%nfixf,p%fntrt])))return
  ok=min(p%dvsnlt,p%dvsnt,p%nfixf,p%fntrt)>=0d0.and.max(p%dvsnlt,p%dvsnt)<=2d0.and. &
       max(p%nfixf,p%fntrt)<=1d0
 end function
 pure function n_vector(n)result(v)
  type(WOFOST81_n_state),intent(in)::n
  real(real64)::v(8)
  v=[n%namountlv,n%namountst,n%namountrt,n%namountso,n%nuptake_total,n%nfix_total,n%nlosses_total,n%initial_total]
 end function
 pure real(real64)function n_tolerance(n)result(tol)
  type(WOFOST81_n_state),intent(in)::n
  tol=2048d0*epsilon(1d0)*max(1d0,n%initial_total+n%nuptake_total+n%nfix_total)
 end function
 pure logical function valid_n(n)result(ok)
  type(WOFOST81_n_state),intent(in)::n
  real(real64)::v(8),balance
  v=n_vector(n);ok=.false.
  if(.not.all(ieee_is_finite(v)))return
  if(any(v<0d0).or.any(v>1d9))return
  balance=n%initial_total+n%nuptake_total+n%nfix_total-sum(v(1:4))-n%nlosses_total
  ok=abs(balance)<=n_tolerance(n)
 end function
 subroutine prepare_b111_reproductive_n(policy,p,n,dvs,nmaxlv,m,dead,reltr,prepared,status)
  type(b111_reproductive_policy_t),intent(in)::policy
  type(WOFOST81_n_param),intent(in)::p
  type(WOFOST81_n_state),intent(in)::n
  real(real64),intent(in)::dvs,nmaxlv,m(4),dead(3),reltr
  type(b111_reproductive_prepared_t),intent(out)::prepared
  integer,intent(out)::status
  type(WOFOST81_n_request)::r
  real(real64)::v(18),nmaxst,nmaxrt,nlimit,nsupso,tcnt
  prepared=b111_reproductive_prepared_t();prepared%before=n;status=B111_REPRO_INVALID
  r=WOFOST81_n_request()
  if(.not.valid_b111_reproductive_policy(policy).or..not.valid_n(n))return
  v=[dvs,nmaxlv,m,dead,reltr,p%nmaxst_fr,p%nmaxrt_fr,p%nmaxso,p%nresidlv,p%nresidst,p%nresidrt,p%tcnt,0d0]
  if(.not.all(ieee_is_finite(v)))return
  if(dvs<0d0.or.dvs>2d0.or.nmaxlv<0d0.or.nmaxlv>1d0.or.reltr<0d0.or.reltr>1d0)return
  if(any(m<0d0).or.any(m>1d8).or.any(dead<0d0).or.any(dead>m(1:3)))return
  if(min(p%nmaxst_fr,p%nmaxrt_fr,p%nmaxso,p%nresidlv,p%nresidst,p%nresidrt)<0d0)return
  if(max(p%nmaxst_fr,p%nmaxrt_fr,p%nmaxso,p%nresidlv,p%nresidst,p%nresidrt)>1d0)return
  if(p%tcnt<1d-6.or.p%tcnt>1d3)return
  nmaxst=nmaxlv*p%nmaxst_fr;nmaxrt=nmaxlv*p%nmaxrt_fr;tcnt=p%tcnt
  ! Literal B1.11 demand354..370: root+stem+leaf addition; no growth demand.
  r%ndemandlv=max(nmaxlv*m(1)-n%namountlv,0d0)
  r%ndemandst=max(nmaxst*m(2)-n%namountst,0d0)
  r%ndemandrt=max(nmaxrt*m(3)-n%namountrt,0d0)
  r%ndemandso=max(p%nmaxso*m(4)-n%namountso,0d0)/tcnt
  r%ndemand=max(0d0,r%ndemandrt+r%ndemandst+r%ndemandlv)
  nlimit=0d0
  if(dvs-policy%dvsnlt<0d0.and.reltr-.01d0>0d0)nlimit=1d0
  r%soil_request=(1d0-policy%nfixf)*r%ndemand*nlimit
  r%rnfixation=policy%nfixf*r%ndemand*nlimit
  ! Literal update201..222: source donor max is NOT a donor cap.
  r%ntranslocatablest=max(0d0,n%namountst-m(2)*p%nresidst)
  r%ntranslocatablelv=max(0d0,n%namountlv-m(1)*p%nresidlv)
  r%ntranslocatablert=max((r%ntranslocatablelv+r%ntranslocatablest)*policy%fntrt,n%namountrt-m(3)*p%nresidrt)
  r%ntranslocatable=r%ntranslocatablelv+r%ntranslocatablest+r%ntranslocatablert
  nsupso=0d0
  if(dvs-policy%dvsnt>=0d0)nsupso=r%ntranslocatable/tcnt
  r%rntranslocation=min(r%ndemandso,nsupso)
  if(r%ntranslocatable>1d-5)then
   r%rntranslocationlv=r%rntranslocation*r%ntranslocatablelv/r%ntranslocatable
   r%rntranslocationst=r%rntranslocation*r%ntranslocatablest/r%ntranslocatable
   r%rntranslocationrt=r%rntranslocation*r%ntranslocatablert/r%ntranslocatable
  end if
  status=B111_REPRO_ALLOCATION
  ! Separate structural gates, even when a net balance might cancel errors.
  if(r%ndemand<=1d-5.and.(r%soil_request>0d0.or.r%rnfixation>0d0))return
  if(r%ntranslocatable<=1d-5.and.r%rntranslocation>0d0)return
  prepared%request=r;prepared%death=[p%nresidlv*dead(1),p%nresidst*dead(2),p%nresidrt*dead(3)]
  prepared%available=.true.;status=B111_REPRO_OK
 end subroutine
 subroutine apply_b111_reproductive_n(prepared,soil_supply,candidate,flux,status)
  type(b111_reproductive_prepared_t),intent(in)::prepared
  real(real64),intent(in)::soil_supply
  type(WOFOST81_n_state),intent(out)::candidate
  type(WOFOST81_n_flux),intent(out)::flux
  integer,intent(out)::status
  type(WOFOST81_n_state)::trial
  real(real64)::uptake(3),trans(3),living(3),total,supplied,tol
  candidate=prepared%before;flux=WOFOST81_n_flux();flux%status=WOFN81_INVALID_INPUT;status=B111_REPRO_INVALID
  if(.not.prepared%available.or..not.ieee_is_finite(soil_supply))return
  if(soil_supply<0d0.or.soil_supply>1d9)return
  trial=prepared%before
  associate(r=>prepared%request,n=>prepared%before)
   flux%rnuptake=max(0d0,min(r%soil_request,soil_supply))
   flux%rnfixation=max(0d0,r%rnfixation)
   supplied=flux%rnuptake+flux%rnfixation
   trans=[r%rntranslocationlv,r%rntranslocationst,r%rntranslocationrt]
   uptake=0d0
   if(r%ndemand>1d-5)then
    uptake(1)=(r%ndemandlv/r%ndemand)*supplied
    uptake(2)=(r%ndemandst/r%ndemand)*supplied
    uptake(3)=(r%ndemandrt/r%ndemand)*supplied
   end if
   status=B111_REPRO_ALLOCATION
   tol=n_tolerance(n)
   if(r%ndemand<=1d-5.and.supplied>0d0)return
   if(abs(sum(uptake)-supplied)>tol)return
   if(abs(r%rntranslocation-sum(trans))>tol)return
   ! Original source x_i before max(0,x); never hide overdraw by clipping.
   living=[n%namountlv,n%namountst,n%namountrt]+(uptake-trans-prepared%death)
   status=B111_REPRO_OVERDRAW
   if(any(living<0d0))return
   flux%rnuptakelv=uptake(1);flux%rnuptakest=uptake(2);flux%rnuptakert=uptake(3)
   flux%rntranslocationlv_applied=trans(1);flux%rntranslocationst_applied=trans(2)
   flux%rntranslocationrt_applied=trans(3);flux%rntranslocation_applied=r%rntranslocation
   flux%rndeathlv=prepared%death(1);flux%rndeathst=prepared%death(2);flux%rndeathrt=prepared%death(3)
   flux%rnamountlv=uptake(1)-trans(1)-prepared%death(1)
   flux%rnamountst=uptake(2)-trans(2)-prepared%death(2)
   flux%rnamountrt=uptake(3)-trans(3)-prepared%death(3)
   flux%rnamountso=r%rntranslocation
   flux%rnloss=prepared%death(1)+prepared%death(3)+prepared%death(2)
   trial%namountlv=max(0d0,n%namountlv+flux%rnamountlv)
   trial%namountst=max(0d0,n%namountst+flux%rnamountst)
   trial%namountrt=max(0d0,n%namountrt+flux%rnamountrt)
   trial%namountso=n%namountso+r%rntranslocation
   trial%nuptake_total=n%nuptake_total+flux%rnuptake
   trial%nfix_total=n%nfix_total+flux%rnfixation
   trial%nlosses_total=n%nlosses_total+flux%rnloss
  end associate
  status=B111_REPRO_BALANCE
  total=trial%namountlv+trial%namountst+trial%namountrt+trial%namountso
  flux%balance_tolerance=n_tolerance(trial)
  flux%balance_residual=trial%initial_total+trial%nuptake_total+trial%nfix_total-total-trial%nlosses_total
  if(.not.valid_n(trial).or.abs(flux%balance_residual)>flux%balance_tolerance)return
  candidate=trial;flux%status=WOFN81_OK;status=B111_REPRO_OK
 end subroutine
end module

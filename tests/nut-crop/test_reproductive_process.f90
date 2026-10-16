program test_reproductive_process
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_next_after,ieee_positive_inf
 use MOD_wofost81_nitrogen
 use mod_b111_reproductive_n_process
 use literal_reproductive
 implicit none
 type(WOFOST81_n_param)::p
 type(WOFOST81_n_state)::n,next,old
 type(WOFOST81_n_request)::r
 type(WOFOST81_n_flux)::flux
 type(b111_reproductive_policy_t)::policy
 type(b111_reproductive_prepared_t)::prepared
 real(real64)::m(4),dead(3),dvs,nmaxlv,reltr,supply,a(8),loss(3),trans(3),uptake(3),requests(6),x(3),v(8),draw(20),nan,inf
 integer::i,j,status,accepted,rejected,allocation,overdraw,seed_count
 integer,allocatable::seed(:)
 call random_seed(size=seed_count);allocate(seed(seed_count));seed=1741;call random_seed(put=seed)
 accepted=0;rejected=0;allocation=0;overdraw=0
 nan=ieee_value(0d0,ieee_quiet_nan);inf=ieee_value(0d0,ieee_positive_inf)
 do i=1,2048
  call random_number(draw)
  m=[100d0,100d0,10d0,20d0]+draw(1:4)*100d0
  n=WOFOST81_n_state();n%namountlv=draw(5)*8d0;n%namountst=draw(6)*6d0
  n%namountrt=draw(7)*5d0;n%namountso=draw(8)*.1d0
  n%initial_total=n%namountlv+n%namountst+n%namountrt+n%namountso
  p=WOFOST81_n_param();p%nmaxst_fr=.5d0;p%nmaxrt_fr=.5d0;p%nmaxso=.02d0
  p%nresidlv=.004d0;p%nresidst=.002d0;p%nresidrt=.002d0;p%tcnt=1d0+draw(9)*10d0
  policy=b111_reproductive_policy_t(.9d0,1d0,draw(10),draw(11))
  dvs=draw(12)*2d0;nmaxlv=.04d0;reltr=draw(13);dead=m(1:3)*draw(14:16)*.05d0;supply=draw(17)*10d0
  call evaluate_case()
 end do
 ! Exact physiological gates, adjacent representable values, zero/full fixation.
 do i=1,54
  call base()
  policy%nfixf=real(mod(i,3),real64)/2d0
  select case(mod(i/3,3))
  case(0)
   reltr=ieee_next_after(.01d0,0d0)
  case(1)
   reltr=.01d0
  case(2)
   reltr=ieee_next_after(.01d0,1d0)
  end select
  dvs=merge(.9d0,ieee_next_after(.9d0,0d0),mod(i,2)==0)
  call evaluate_case()
 end do
 ! Independent active allocation/cutoff checks, including cancelling net errors.
 do i=1,4
  call base();dead=0d0;m=[1d0,0d0,0d0,1d0];n=WOFOST81_n_state();n%namountlv=5d-6;n%initial_total=5d-6
  p%nresidlv=0d0;p%nresidst=0d0;p%nresidrt=0d0;p%tcnt=1d0;policy%fntrt=0d0;policy%dvsnt=0d0
  nmaxlv=1d-5;dvs=.5d0;supply=5d-6;policy%nfixf=0d0
  if(i==2)dvs=1.5d0
  if(i==3)then
   m(4)=0d0
  end if
  if(i==4)then
   n%namountlv=ieee_next_after(1d-5,1d0);n%initial_total=n%namountlv
   p%tcnt=2d0;dvs=1.5d0
  end if
  call evaluate_case()
  if(i==1)call require(abs(sum(a(1:4))+sum(loss)-n%initial_total-min(requests(3),supply)-requests(4))<1d-15, &
    'net cancellation fixture is not itself a sufficient guard')
 end do
 ! Every public scalar/array carrier rejects NaN before comparisons/arithmetic.
 do i=1,26
  call base()
  select case(i)
  case(1)
   policy%dvsnlt=nan
  case(2)
   policy%dvsnt=nan
  case(3)
   policy%nfixf=nan
  case(4)
   policy%fntrt=nan
  case(5)
   dvs=nan
  case(6)
   nmaxlv=nan
  case(7)
   reltr=nan
  case(8:11)
   m(i-7)=nan
  case(12:14)
   dead(i-11)=nan
  case(15)
   p%nmaxst_fr=nan
  case(16)
   p%nmaxrt_fr=nan
  case(17)
   p%nmaxso=nan
  case(18)
   p%nresidlv=nan
  case(19)
   p%nresidst=nan
  case(20)
   p%nresidrt=nan
  case(21)
   p%tcnt=nan
  case(22)
   n%namountlv=nan
  case(23)
   n%initial_total=nan
  case(24)
   p%tcnt=0d0
  case(25)
   policy%fntrt=1.1d0
  case(26)
   dead(1)=m(1)+1d0
  end select
  call prepare_b111_reproductive_n(policy,p,n,dvs,nmaxlv,m,dead,reltr,prepared,status)
  call require(status==B111_REPRO_INVALID.and..not.prepared%ready(),'invalid public input refused')
 end do
 do i=1,3
  call base();call prepare_b111_reproductive_n(policy,p,n,dvs,nmaxlv,m,dead,reltr,prepared,status)
  call require(status==0,'valid private preparation')
  r=prepared%request_view();r%rnfixation=1d8 ! A public view cannot poison private scratch.
  supply=nan
  if(i==2)supply=inf
  if(i==3)supply=-1d0
  call apply_b111_reproductive_n(prepared,supply,next,flux,status)
  call require(status==B111_REPRO_INVALID,'invalid actual supply refused')
  call require(all(pack(next)==pack(n)),'failed supply keeps all organ/ledger values')
 end do
 call require(accepted>500.and.rejected>0.and.overdraw>0.and.allocation>=3,'discriminating positive/negative corpus')
 print '(A,4(I0,1X))','B111_REPRODUCTIVE_CASE_COUNTS=',accepted,rejected,allocation,overdraw
 print '(A)','B111_REPRODUCTIVE_LITERAL_CORPUS_GUARDS=PASS'
contains
 subroutine base()
  p=WOFOST81_n_param();p%nmaxst_fr=1d0;p%nmaxrt_fr=.6d0;p%nmaxso=.02d0
  p%nresidlv=.01d0;p%nresidst=.01d0;p%nresidrt=.01d0;p%tcnt=1d0
  policy=b111_reproductive_policy_t(.9d0,1d0,0d0,.25d0)
  n=WOFOST81_n_state();n%namountlv=5d0;n%namountst=5d0;n%namountrt=.5d0;n%initial_total=10.5d0
  m=[100d0,100d0,10d0,20d0];dead=[10d0,0d0,0d0];dvs=1.2d0;nmaxlv=.05d0;reltr=1d0;supply=0d0
 end subroutine
 function pack(s)result(v)
  type(WOFOST81_n_state),intent(in)::s
  real(real64)::v(8)
  v=[s%namountlv,s%namountst,s%namountrt,s%namountso,s%nuptake_total,s%nfix_total,s%nlosses_total,s%initial_total]
 end function
 subroutine evaluate_case()
  real(real64)::pv(4)
  pv=[policy%dvsnlt,policy%dvsnt,policy%nfixf,policy%fntrt]
  call literal(p,pv,n,dvs,nmaxlv,m,dead,reltr,supply,a,loss,trans,uptake,requests,x)
  call prepare_b111_reproductive_n(policy,p,n,dvs,nmaxlv,m,dead,reltr,prepared,status)
  if((requests(1)<=1d-5.and.(requests(3)>0d0.or.requests(4)>0d0)).or. &
     (requests(5)<=1d-5.and.requests(6)>0d0))then
   if(status/=B111_REPRO_ALLOCATION)print *, 'allocation diagnostic',i,status,requests
   call require(status==B111_REPRO_ALLOCATION.and..not.prepared%ready(),'separate source allocation guards')
   allocation=allocation+1;rejected=rejected+1;return
  end if
  call require(status==0.and.prepared%ready(),'literal valid preparation')
  r=prepared%request_view()
  call require(all([r%ndemand,r%ndemandso,r%soil_request,r%rnfixation,r%ntranslocatable,r%rntranslocation]==requests),'literal source request exact')
  call apply_b111_reproductive_n(prepared,supply,next,flux,status)
  if(any(x<0d0))then
   call require(status==B111_REPRO_OVERDRAW,'preclipping donor nonnegativity')
   call require(all(pack(next)==pack(n)),'rejected donor leaves candidate identical')
   overdraw=overdraw+1;rejected=rejected+1;return
  end if
  if(status/=0)print *,status,i
  call require(status==0.and.flux%status==WOFN81_OK,'accepted conserving source apply')
  call require(all(pack(next)==a),'all8 source organ/cumulative values exact')
  call require(all([flux%rndeathlv,flux%rndeathst,flux%rndeathrt]==loss),'literal residual death exact')
  call require(all([flux%rntranslocationlv_applied,flux%rntranslocationst_applied,flux%rntranslocationrt_applied]==trans),'literal source translocation exact')
  call require(all([flux%rnuptakelv,flux%rnuptakest,flux%rnuptakert]==uptake),'literal uptake partition exact')
  call require(abs(flux%balance_residual)<=flux%balance_tolerance,'independent crop N balance')
  accepted=accepted+1
 end subroutine
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
end program

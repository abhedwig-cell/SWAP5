program test_pr700_gash_source_disposition
 use,intrinsic::iso_fortran_env,only:real64
 use mod_gash_interception,only:gash_parameters_t,historical_gash=>evaluate_gash_source_window
 use mod_vonhhbraden_interception,only:vonhhbraden_source_window_t,apportion_vonhhbraden_interception
 use mod_gash_interception_process,only:gash_source_window_input_t,gash_source_window_result_t, &
      gash_table_t,current_gash=>evaluate_gash_source_window,GASH_OK
 use mod_gash_daily_application
 implicit none
 type(gash_parameters_t)::p
 type(vonhhbraden_source_window_t)::s
 type(gash_source_window_input_t)::x
 type(gash_source_window_result_t)::r
 type(gash_daily_application_input_t)::a
 type(gash_daily_application_result_t)::b
 real(real64),parameter::pf(2)=[0.2d0,0.4d0],storage(2)=[0.14d0,0.21d0]
 real(real64),parameter::evap(2)=[0.1d0,0.3d0],prec(2)=[2d0,4d0]
 real(real64),parameter::rain(5)=[0.001d0,0.1d0,0.4d0,1d0,2d0],irr(4)=[0d0,0.05d0,0.3d0,1d0]
 real(real64),parameter::amount(6)=[1d-6,9d-6,1d-5,9d-4,1d-3,1d-2]
 real(real64)::old,c,sc,e,ps,total,old_expected,new_expected,part,netrain,netirr
 integer::i,j,k,l,m,n,q,so,sn,cases,common,different,partition_different
 logical::crossed
 cases=0;common=0;different=0;partition_different=0
 s%leaf_area_index=2d0;s%vegetation_cover_fraction=1d0
 do i=1,2;do j=1,2;do k=1,2;do l=1,2
  p%free_throughfall=pf(i);p%stemflow=0.1d0;p%canopy_storage_cm=storage(j)
  p%average_evaporation=evap(k);p%average_precipitation=prec(l)
  call tab(x%free_throughfall,p%free_throughfall);call tab(x%stemflow,p%stemflow)
  call tab(x%canopy_storage_cm,p%canopy_storage_cm);call tab(x%average_evaporation,p%average_evaporation)
  call tab(x%average_precipitation,p%average_precipitation)
  c=1d0-p%free_throughfall-p%stemflow;sc=p%canopy_storage_cm/c;e=p%average_evaporation/c
  ps=-p%average_precipitation*sc/e*log(1d0-e/p%average_precipitation)
  do m=1,5;do n=1,4;do q=0,1
   s%gross_rain_cm_per_day=rain(m);s%sprinkling_irrigation_cm_per_day=irr(n)
   s%sprinkling_is_intercepted=q==1
   x%gross_rain_cm=rain(m);x%surface_irrigation_cm=irr(n);x%surface_irrigation_is_intercepted=q==1
   total=rain(m);if(q==1)total=total+irr(n)
   call historical_gash(p,s,old,so);call current_gash(x,r,sn)
   call req(so==0.and.sn==GASH_OK,'valid shared one-day input')
   old_expected=formula(total,total,ps,c,p%average_evaporation,p%average_precipitation)
   new_expected=formula(rain(m),total,ps,c,p%average_evaporation,p%average_precipitation)
   call req(abs(old-old_expected)<1d-14,'historical total-input branch oracle')
   call req(abs(r%interception_cm-new_expected)<1d-14,'accepted rain-only branch oracle')
   crossed=rain(m)<ps.and.total>=ps
   if(crossed)then
    call req(abs(old-r%interception_cm)>1d-14,'crossing must not be equated')
    different=different+1
   else
    call req(abs(old-r%interception_cm)<1d-14,'common bounded formula')
    common=common+1
   end if
   cases=cases+1
  end do;end do;end do
 end do;end do;end do;end do
 s%gross_rain_cm_per_day=0.8d0;s%sprinkling_irrigation_cm_per_day=0.2d0;s%sprinkling_is_intercepted=.true.
 a%gross_rain_cm=0.8d0;a%surface_irrigation_cm=0.2d0
 do i=1,size(amount)
  a%interception_cm=amount(i)
  call apportion_vonhhbraden_interception(s,amount(i),0.8d0,0.2d0,part,netrain,netirr,so)
  call apply_gash_daily(a,b,sn)
  call req(so==0.and.sn==GASH_APP_OK,'partition accepts valid daily input')
  if(amount(i)>=1d-5.and.amount(i)<1d-3)then
   call req(abs(netrain-b%net_rain_cm)>1d-14.and.abs(netirr-b%net_irrigation_cm)>1d-14, &
     'historical1e-5 versus accepted1e-3 partition threshold')
   partition_different=partition_different+1
  else
   call req(abs(netrain-b%net_rain_cm)<1d-14.and.abs(netirr-b%net_irrigation_cm)<1d-14,'common partition domain')
  end if
 end do
 call req(cases==640.and.different>0.and.common>0.and.partition_different==2,'complete diagnostic corpus')
 print '(a,i0,a,i0,a,i0)','PR700_GASH_SOURCE|CASES=',cases,'|COMMON=',common,'|BRANCH_DIFFERENT=',different
 print '(a,i0,a,i0)','PR700_GASH_PARTITION|CASES=',size(amount),'|THRESHOLD_DIFFERENT=',partition_different
 print '(a)','PR700_GASH_NOT_SAME_POLICY_SUPERSESSION=PASS'
contains
 subroutine tab(t,value)
  type(gash_table_t),intent(out)::t
  real(real64),intent(in)::value
  allocate(t%time(1),t%value(1));t%time=0d0;t%value=value
 end subroutine
 pure real(real64) function formula(selector,total_amount,sat,cover,ave,pr)result(v)
  real(real64),intent(in)::selector,total_amount,sat,cover,ave,pr
  if(selector<sat)then
   v=cover*total_amount
  else
   v=cover*(sat+ave/pr*(total_amount-sat))
  end if
 end function
 subroutine req(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,label;error stop 1;end if
 end subroutine
end program

program test_native_dramet3
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use variables,only:gwl,t1900,dt
 use MOD_drain
 use mod_drainage_dramet3_response
 use mod_fmr_drainage_response_binding
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 implicit none
 type(fmr_drainage_response_level_parameters_t)::p(3)
 type(fmr_drainage_response_level_control_t)::c(3)
 type(fmr_drainage_response_diagnostics_t)::d
 type(dramet3_level_result_t)::r
 type(dramet3_channel_control_t)::bad
 type(process_hydraulic_view_t)::v
 real(real64)::q(3,4),x(3),y(3),endpoints(9),grounds(9),expected,query,head
 integer::a,b,l,j,k,m,n,st,count,neg
 x=[40000d0,40000.25d0,40001d0];endpoints=[99d0,100d0,100.125d0,100.25d0,100.5d0,101d0,102d0,366d0,1000d0]
 grounds=[-200d0,-100d0,-80d0,-60d0,-40d0,0d0,10d0,-60.00000001d0,-59.99999999d0]
 v%active_nodes=4;allocate(v%pressure_head(4),v%water_content(4));v%pressure_head=-75d0;v%water_content=.3d0
 count=0;neg=0
 do n=1,3,2
 do m=1,2
 do a=1,3
 do b=1,2
 do j=0,1
 do k=1,size(endpoints)
 do l=1,3
  p(l)%variant=FMR_DRAIN_VARIANT_DRAMET3
  p(l)%dramet3%drain_bottom_cm=-100d0+5d0*(l-1)
  p(l)%dramet3%drainage_resistance_day=100d0*l
  p(l)%dramet3%infiltration_resistance_day=233d0*l
  p(l)%dramet3%allocation_mode=1+mod(a+l-2,3)
  p(l)%dramet3%drain_type=b;p(l)%dramet3%limit_channel_infiltration=j==1
  y=[-120d0,-60d0,-40d0]+10d0*(l-1)
  call initialize_dramet3_channel_control(p(l)%dramet3_channel,100d0,40000d0,x(:n),y(:n),st)
  call require(st==0,'valid table')
  nowltab(l)=n;owltab(l,:)=0d0;owltab(l,1:2*n:2)=x(:n);owltab(l,2:2*n:2)=y(:n)
  zbotdr(l)=p(l)%dramet3%drain_bottom_cm;drares(l)=100d0*l;infres(l)=233d0*l
  swallo(l)=p(l)%dramet3%allocation_mode;swdtyp(l)=b
 end do
 swliminf=j;nrlevs=3
 do l=1,size(grounds)
  gwl=grounds(l);v%groundwater_level=gwl
  ! The source receives trial-start t1900 and duration separately. Use two
  ! different starts for the same endpoint to falsify start-only sampling.
  dt=.125d0*m;t1900=40000d0+(endpoints(k)-dt-100d0)+1d0
  call drainflux_basic()
  call evaluate_fmr_drainage_response_bottom_lumped(p,c,v,q,d,endpoints(k))
  call require(d%status==0.and.d%evaluated,'real native binder')
  call require(all(q(:,1:3)==0d0),'source SWDIVD0 layer allocation')
  do st=1,3
   call require(abs(q(st,4)-qdrain(st))<1d-14,'complete original source parity')
   call require(abs(d%level(st)%dramet3%resolved_channel_head_cm-drainl(st))<1d-14,'original channel resolution')
   call require(abs(d%level(st)%dramet3%head_difference_cm-diffl(st))<1d-14,'original limited head')
   call require(d%level(st)%dramet3%legacy_query_t1900==t1900+dt-1d0,'actual legacy endpoint')
  end do
  call require(abs(sum(q)-sum(qdrain))<1d-14,'single scalar sum')
  count=count+1
 end do
 end do
 end do
 end do
 end do
 end do
 end do
 call evaluate_fmr_drainage_response_bottom_lumped(p,c,v,q,d)
 call require(d%status/=0.and.all(q==0d0),'missing trial endpoint');neg=neg+1
 call initialize_dramet3_channel_control(bad,0d0,0d0,[0d0,0d0],[1d0,2d0],st)
 call require(st/=0.and..not.bad%ready(),'duplicate times atomic');neg=neg+1
 call initialize_dramet3_channel_control(bad,0d0,0d0,[1d0,0d0],[1d0,2d0],st)
 call require(st/=0.and..not.bad%ready(),'descending table');neg=neg+1
 call initialize_dramet3_channel_control(bad,0d0,0d0,[0d0],[1d0,2d0],st)
 call require(st/=0.and..not.bad%ready(),'shape');neg=neg+1
 call initialize_dramet3_channel_control(bad,0d0,0d0,[0d0],[ieee_value(0d0,ieee_quiet_nan)],st)
 call require(st/=0.and..not.bad%ready(),'nonfinite table');neg=neg+1
 call initialize_dramet3_channel_control(bad,ieee_value(0d0,ieee_quiet_nan),0d0,[0d0],[1d0],st)
 call require(st/=0.and..not.bad%ready(),'nonfinite epoch');neg=neg+1
 p(1)%dramet3_channel=bad
 call evaluate_fmr_drainage_response_bottom_lumped(p,c,v,q,d,100d0)
 call require(d%status/=0.and.all(q==0d0),'unready channel binder');neg=neg+1
 call initialize_dramet3_channel_control(p(1)%dramet3_channel,0d0,0d0,[0d0],[-50d0],st)
 do a=1,7
  p(1)%dramet3%drainage_resistance_day=100d0;p(1)%dramet3%infiltration_resistance_day=200d0
  p(1)%dramet3%allocation_mode=1;p(1)%dramet3%drain_type=1;v%groundwater_level=-60d0
  select case(a)
  case(1);p(1)%dramet3%drainage_resistance_day=0d0
  case(2);p(1)%dramet3%infiltration_resistance_day=-1d0
  case(3);p(1)%dramet3%allocation_mode=0
  case(4);p(1)%dramet3%drain_type=3
  case(5);v%groundwater_level=ieee_value(0d0,ieee_quiet_nan)
  case(6);p(1)%dramet3%drain_bottom_cm=ieee_value(0d0,ieee_quiet_nan)
  case(7);c(1)%drain_head_supplied=.true.
  end select
  call evaluate_fmr_drainage_response_bottom_lumped(p,c,v,q,d,100d0)
  call require(d%status/=0.and.all(q==0d0),'invalid atomic binder');neg=neg+1
  p(1)%dramet3%drain_bottom_cm=-100d0;c(1)%drain_head_supplied=.false.
 end do
 p(1)%dramet3%infiltration_resistance_day=0d0
 call evaluate_dramet3_level(p(1)%dramet3,p(1)%dramet3_channel,-40d0,1d0,r)
 call require(r%available.and.r%signed_exchange_cm_per_day==.1d0,'source zero INFRES unused drainage')
 call evaluate_dramet3_level(p(1)%dramet3,p(1)%dramet3_channel,-60d0,1d0,r)
 call require(.not.r%available,'source undefined active zero INFRES held');neg=neg+1
 call p(1)%dramet3_channel%evaluate(ieee_value(0d0,ieee_quiet_nan),query,head,st)
 call require(st/=0,'nonfinite endpoint');neg=neg+1
 expected=0d0
 print '(A,I0)','DRAMET3_COMPLETE_SOURCE_BINDER_CASES=',count
 print '(A,I0)','DRAMET3_INVALID_AND_UNDEFINED_CONTROLS=',neg
 print '(A)','DRAMET3_REAL_SOURCE_NATIVE_BINDER=PASS'
contains
 subroutine require(ok,why)
 logical,intent(in)::ok
 character(*),intent(in)::why
 if(.not.ok)then
 print *,why
 error stop 1
 end if
 end subroutine
end program

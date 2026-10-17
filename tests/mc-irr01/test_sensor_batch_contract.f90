program sensor_batch
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_irrigation_process
 use mod_process_hydraulic_view
 use mod_scheduled_irrigation_management_policy
 implicit none
 type(scheduled_irrigation_parameters_t)::p,bad
 type(scheduled_irrigation_request_t)::r
 type(irrigation_state_t)::event,next
 type(irrigation_flux_result_t)::flux
 type(irrigation_diagnostics_t)::diag
 type(irrigation_management_policy_parameters_t)::ip
 type(irrigation_management_policy_state_t)::state,candidate
 type(process_hydraulic_view_t)::v
 real(real64)::ht(14),tt(14),dvs,threshold,delta
 real(real64),parameter::xs(9)=[-.1_real64,0._real64,.1_real64,.333_real64,.75_real64,1._real64,1.9_real64,2._real64,2.1_real64]
 real(real64),external::afgen
 integer::n,tcs,i,j,side,k,day,st,dayfix,interval,irrigevent,cases,spatial
 logical::trigger
 p%scheduled_irrigation_enabled=.true.;p%active_nodes=3;p%sensor_node=2;p%single_ssdi_node=2
 p%dcs2_knot_count=2;p%dcs2_dvs(1:2)=[0._real64,2._real64];p%dcs2_depth_cm=1
 v%active_nodes=3;allocate(v%pressure_head(3),v%water_content(3));v%pressure_head=-100;v%water_content=.2_real64
 cases=0;dayfix=366
 do n=1,7
 ht=-99;tt=-99;p%tcs7_knot_count=n;p%tcs8_knot_count=n
 do i=1,n
  dvs=0;if(n>1)dvs=2._real64*real(i-1,real64)/real(n-1,real64)
  p%tcs7_dvs(i)=dvs;p%tcs8_dvs(i)=dvs
  p%tcs7_pressure_head(i)=-1000000._real64+1000100._real64*real(mod(i,3),real64)*.5_real64
  p%tcs8_water_content(i)=real(mod(i,3),real64)*.5_real64
  ht(2*i-1)=dvs;ht(2*i)=p%tcs7_pressure_head(i)
  tt(2*i-1)=dvs;tt(2*i)=p%tcs8_water_content(i)
 end do
 do tcs=7,8
 p%timing_criterion=tcs
 do j=1,size(xs)
 dvs=xs(j);threshold=afgen(ht,14,dvs);if(tcs==8)threshold=afgen(tt,14,dvs)
 do side=-1,1
 delta=real(side,real64)*1.e-8_real64
 v%pressure_head(2)=threshold+delta;v%water_content(2)=threshold+delta
 call b111_sensor(tcs,dvs,v%pressure_head,v%water_content,2,ht,tt,0,dayfix,3,irrigevent)
 call evaluate_irrigation_sensor_trigger(p,dvs,v,diag)
 call require(diag%status==IRRIGATION_OK,'valid typed sensor table including constant and upper clamp')
 call require(diag%triggered.eqv.(irrigevent==2),'exact inclusive sensor source trigger')
 if(abs(diag%interpolated_threshold-threshold)>0._real64)print *,n,tcs,j,side,threshold,diag%interpolated_threshold
 call require(abs(diag%interpolated_threshold-threshold)<=0._real64,'exact source AFGEN operation order')
 cases=cases+1
 end do
 end do
 end do
 end do
 ! Raw trigger, saturation, first gift, suppressed wet/dry days and max interval.
 do tcs=7,8
 p%timing_criterion=tcs
 do k=1,3
 interval=1;if(k==2)interval=3
 if(k==3)interval=366
 ip%fixed_interval_enabled=.true.;ip%fixed_interval_days=interval;ip%timing_criterion=tcs
 state=irrigation_management_policy_state_t();dayfix=366
 do day=0,370
 v%pressure_head(2)=-1.e6_real64;v%water_content(2)=0
 if(mod(day,11)==3)then
 v%pressure_head(2)=1.e6_real64;v%water_content(2)=1
 end if
 call b111_sensor(tcs,1._real64,v%pressure_head,v%water_content,2,ht,tt,1,dayfix,interval,irrigevent)
 call evaluate_irrigation_sensor_trigger(p,1._real64,v,diag);trigger=diag%triggered
 call apply_irrigation_minimum_interval(ip,state,trigger,candidate,st)
 call require(st==IRR_MGMT_OK.and.(trigger.eqv.(irrigevent==2)),'source sensor+interval trigger')
 call require(candidate%weekly_day_counter==dayfix,'source shared DAYFIX recurrence')
 state=candidate;cases=cases+1
 end do
 end do
 end do
 ! Every contiguous interval on three unequal physical compartments is a source
 ! per-compartment rate, not a normalized profile total. Process owns amount.
 p%timing_criterion=7;p%tcs7_knot_count=1;p%tcs7_pressure_head(1)=0;p%tcs7_dvs(1)=0
 r%selection_opportunity=.true.;r%irrigation_enabled=.true.;r%schedule_enabled=.true.
 r%crop_emerged=.true.;r%irrigation_window_open=.true.;r%t0=0;r%t1=.25_real64
 v%pressure_head=-1;v%water_content=.2_real64;spatial=0
 do i=1,3
 do j=i,3
 p%ssdi_first_node=i;p%ssdi_last_node=j
 call evaluate_scheduled_irrigation_interval(p,event,r,v,next,flux,diag)
 call require(diag%status==IRRIGATION_OK.and.diag%selection_evaluated.and.flux%event_started,'source spatial event')
 call require(abs(flux%external_inflow_amount-real(j-i+1,real64)*.25_real64)<1.e-14_real64,'source per-node accepted amount')
 call require(all(flux%subsurface_source(i:j)==1._real64),'source per-compartment rate')
 spatial=spatial+1
 end do
 end do
 do i=1,5
 bad=p
 select case(i)
 case(1);bad%tcs7_knot_count=0
 case(2);bad%tcs7_pressure_head(1)=ieee_value(0._real64,ieee_quiet_nan)
 case(3);bad%sensor_node=0
 case(4);bad%ssdi_first_node=3;bad%ssdi_last_node=2
 case(5);bad%tcs7_knot_count=2;bad%tcs7_dvs(2)=bad%tcs7_dvs(1)
 end select
 call evaluate_irrigation_sensor_trigger(bad,1._real64,v,diag)
 call require(diag%status/=IRRIGATION_OK,'invalid sensor rejected')
 end do
 print '(a,i0,a,i0)','SENSOR_BATCH_LITERAL_CASES=',cases,'|SPATIAL_CASES=',spatial
 print '(a)','SENSOR_BATCH_SOURCE_AFGEN_INTERVAL_SSDI=PASS'
contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then
 print *,label
 error stop 1
 end if
 end subroutine
end program

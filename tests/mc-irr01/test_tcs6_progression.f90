program test_tcs6_progression
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
  use mod_scheduled_irrigation_management_policy
  use mod_fmr_scheduled_management_irrigation_application
  use mod_fmr_irrigation_management_restart
  use mod_process_hydraulic_view
  use mod_irrigation_process
  use mod_irrigation_root_zone_summary
  implicit none
  type(irrigation_management_policy_parameters_t)::p
  type(irrigation_management_policy_state_t)::s,c
  type(irrigation_management_policy_request_t)::r
  type(irrigation_management_policy_result_t)::y
  type(fmr_irrigation_management_parameters_t)::ap
  type(fmr_irrigation_management_state_t)::accepted,candidate,recovered
  type(fmr_irrigation_management_request_t)::request
  type(fmr_irrigation_management_diagnostics_t)::diag
  type(fmr_irrigation_management_restart_record_t)::record
  type(irrigation_flux_result_t)::flux
  type(irrigation_root_zone_summary_t)::summary
  type(process_hydraulic_view_t)::view
  integer::day,k,idx,oracle_day,event,st,n,old,t
  real(real64)::deficit,threshold
  logical::opportunity
  interface
    subroutine b111_tcs6(dayfix,cdef,irgthreshold,irrigevent)
      import real64
      integer,intent(inout)::dayfix
      real(real64),intent(in)::cdef,irgthreshold
      integer,intent(out)::irrigevent
    end subroutine
  end interface
  p%timing_criterion=6;p%depth_criterion=2
  p%dcs2_knot_count=2;p%dcs2_dvs(1:2)=[0._real64,2._real64];p%dcs2_depth_cm(1:2)=.04_real64
  n=0
  do idx=0,7
    k=idx;if(idx==7)k=366
    do day=1,17
      do t=0,4
        threshold=real(t*5,real64)
        do old=-1,1
          deficit=threshold*.1_real64+real(old,real64)*1.e-12_real64
          s%weekly_day_counter=k;oracle_day=k
          p%tcs6_threshold_mm=threshold;r%field_capacity_deficit_cm=deficit
          call b111_tcs6(oracle_day,deficit,threshold,event)
          call evaluate_irrigation_management_policy(p,s,r,c,y,st)
          call require(st==0.and.s%weekly_day_counter==k,'real production source nonmutation')
          call require(c%weekly_day_counter==oracle_day,'literal extracted B111 recurrence')
          opportunity=k+1>=7
          call require(y%weekly_opportunity.eqv.opportunity,'weekly opportunity including nontrigger')
          call require(y%trigger.eqv.(event==2),'strict below/equal/above literal threshold')
          n=n+1
        end do
      end do
      k=k+1;if(k>=7)k=0
    end do
  end do
  do k=7,8
    s%weekly_day_counter=k
    call evaluate_irrigation_management_policy(p,s,r,c,y,st)
    call require(st==IRR_MGMT_INVALID_REQUEST.and.c%weekly_day_counter==k,'invalid counter')
  end do
  s%weekly_day_counter=huge(1)
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  call require(st==IRR_MGMT_INVALID_REQUEST,'counter overflow prevented')
  s%weekly_day_counter=6
  do k=1,2
    p%tcs6_threshold_mm=ieee_value(0._real64,ieee_quiet_nan)
    if(k==2)p%tcs6_threshold_mm=ieee_value(0._real64,ieee_positive_inf)
    call evaluate_irrigation_management_policy(p,s,r,c,y,st)
    call require(st==IRR_MGMT_INVALID_PARAMETERS.and.c%weekly_day_counter==6,'nonfinite threshold fails closed')
  end do
  p%tcs6_threshold_mm=0._real64
  ap%policy=p;ap%active_nodes=1;ap%root_zone%active_nodes=1;ap%root_zone%rooted_nodes=1
  ap%root_zone%last_rooted_fraction=.5_real64
  ap%root_zone%node_thickness_cm=[10._real64];ap%root_zone%field_capacity_water_content=[.3_real64]
  ap%root_zone%stress_water_content=[.2_real64];ap%root_zone%wilting_water_content=[.1_real64]
  ap%application_type=IRRIGATION_APPLICATION_SSDI;ap%single_ssdi_node=1
  view%active_nodes=1;view%pressure_head=[-100._real64];view%water_content=[.25_real64]
  request%t0=0;request%t1=.25_real64;request%selection_opportunity=.true.
  request%irrigation_enabled=.true.;request%schedule_enabled=.true.;request%crop_emerged=.true.
  request%irrigation_window_open=.true.
  do k=1,4
    request%crop_emerged=k/=1;request%irrigation_window_open=k/=2
    request%fixed_event_already_selected=k==3;request%selection_opportunity=k/=4
    call fmr_evaluate_scheduled_management_irrigation(ap,accepted,request,view,candidate,flux,y,summary,diag)
    call require(diag%status==0.and..not.diag%selection_evaluated,'inactive/closed/fixed/consumed day gates')
    call require(candidate%policy%weekly_day_counter==366,'ineligible day cannot advance week')
  end do
  request%crop_emerged=.true.;request%irrigation_window_open=.true.
  request%fixed_event_already_selected=.false.;request%selection_opportunity=.true.
  call fmr_evaluate_scheduled_management_irrigation(ap,accepted,request,view,candidate,flux,y,summary,diag)
  call require(diag%status==0.and.candidate%event%active_event.and.candidate%policy%weekly_day_counter==0,'first real opportunity')
  call require(accepted%policy%weekly_day_counter==366,'discarded trial consumes no week')
  call export_fmr_irrigation_management_restart(candidate,record,st)
  call require(st==0,'existing irrigation restart export')
  call restore_fmr_irrigation_management_restart(record,recovered,st)
  call require(st==0.and.recovered%event%active_event.and.recovered%policy%weekly_day_counter==0,'existing irrigation owner restore')
  accepted=recovered;request%t0=.25_real64;request%t1=1._real64
  call fmr_evaluate_scheduled_management_irrigation(ap,accepted,request,view,candidate,flux,y,summary,diag)
  call require(diag%status==0.and.flux%event_finished.and.candidate%policy%weekly_day_counter==0,'active event cannot count second day')
  accepted=candidate
  do day=1,7
    request%t0=real(day,real64);request%t1=real(day,real64)+.25_real64
    call fmr_evaluate_scheduled_management_irrigation(ap,accepted,request,view,candidate,flux,y,summary,diag)
    call require(diag%status==0.and.candidate%policy%weekly_day_counter==mod(day,7),'production week progression')
    if(day<7)call require(.not.flux%applied,'no repeated weekly event')
    if(day==7)call require(flux%event_started,'next weekly event exactly seven eligible days later')
    accepted=candidate
    call export_fmr_irrigation_management_restart(accepted,record,st);call require(st==0,'daily counter export')
    call restore_fmr_irrigation_management_restart(record,recovered,st);call require(st==0,'daily counter restore')
    call require(recovered%policy%weekly_day_counter==mod(day,7),'restart retains every counter')
  end do
  print '(a,i0)','TCS6_LITERAL_SOURCE_CASES=',n
  print '(a)','TCS6_PRODUCTION_WEEK_THRESHOLD_INELIGIBLE_REPLAY_RESTART=PASS'
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

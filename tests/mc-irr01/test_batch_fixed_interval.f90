program batch_interval
 use iso_fortran_env,only:real64
 use mod_scheduled_irrigation_management_policy
 use mod_fmr_irrigation_management_restart
 use mod_fmr_scheduled_management_irrigation_application
 implicit none
 type(irrigation_management_policy_parameters_t)::p
 type(irrigation_management_policy_state_t)::s,c
 type(irrigation_management_policy_request_t)::r
 type(irrigation_management_policy_result_t)::y
 type(fmr_irrigation_management_state_t)::whole,restored
 type(fmr_irrigation_management_restart_record_t)::record
 integer,parameter::intervals(4)=[1,2,7,366]
 integer::criterion,j,day,st,dayfix,irrigevent,irgdayfix,cases,old
 logical::raw_trigger
 cases=0
 do criterion=2,4
 do j=1,4
  p=irrigation_management_policy_parameters_t();s=irrigation_management_policy_state_t()
  p%timing_criterion=criterion;p%fixed_interval_enabled=.true.;p%fixed_interval_days=intervals(j)
  p%tcs2_knot_count=2;p%tcs2_dvs(1:2)=[0._real64,2._real64];p%tcs2_fraction=.5_real64
  p%tcs3_knot_count=2;p%tcs3_dvs(1:2)=[0._real64,2._real64];p%tcs3_fraction=.5_real64
  p%tcs4_knot_count=2;p%tcs4_dvs(1:2)=[0._real64,2._real64];p%tcs4_depletion_mm=50._real64
  p%depth_criterion=1;p%dcs1_knot_count=2;p%dcs1_dvs(1:2)=[0._real64,2._real64]
  r=irrigation_management_policy_request_t();r%dvs=1;r%total_available_water_cm=10
  r%stress_to_wilting_available_cm=0;r%field_capacity_deficit_cm=1
  dayfix=366;irgdayfix=intervals(j)
  ! Follow a full maximum interval, with wet/no-trigger days on either side
  ! of the boundary. This discriminates saturation from unconditional increment.
  do day=0,370
   r%actual_available_water_cm=0
   if(mod(day,11)==3)r%actual_available_water_cm=10
   raw_trigger=r%actual_available_water_cm<5._real64
   irrigevent=0;if(raw_trigger)irrigevent=2
   call literal_fixed_interval(dayfix,irgdayfix,irrigevent)
   old=s%weekly_day_counter
   call evaluate_irrigation_management_policy(p,s,r,c,y,st)
   call require(st==IRR_MGMT_OK,'policy accepts legal source interval')
   call require(y%trigger.eqv.(irrigevent==2),'literal source trigger after interval gate')
   call require(c%weekly_day_counter==dayfix,'literal DAYFIX recurrence')
   call require(s%weekly_day_counter==old,'tentative evaluation never consumes committed day')
   whole%policy=c
   call export_fmr_irrigation_management_restart(whole,record,st)
   call require(st==FMR_IRR_MGMT_RESTART_OK,'existing codec exports interval counter')
   call restore_fmr_irrigation_management_restart(record,restored,st)
   call require(st==FMR_IRR_MGMT_RESTART_OK,'existing codec restores interval counter')
   call require(restored%policy%weekly_day_counter==dayfix,'joint management restart retains DAYFIX')
   s=restored%policy;cases=cases+1
  end do
 end do
 end do
 p%timing_criterion=6;p%fixed_interval_enabled=.true.
 call evaluate_irrigation_management_policy(p,s,r,c,y,st)
 call require(st==IRR_MGMT_INVALID_PARAMETERS,'source rejects TCS6 with TCSFIX')
 p%timing_criterion=2
 p%fixed_interval_days=0
 call evaluate_irrigation_management_policy(p,s,r,c,y,st)
 call require(st==IRR_MGMT_INVALID_PARAMETERS,'interval zero invalid')
 p%fixed_interval_days=367
 call evaluate_irrigation_management_policy(p,s,r,c,y,st)
 call require(st==IRR_MGMT_INVALID_PARAMETERS,'interval above366 invalid')
 p%fixed_interval_days=7;s%weekly_day_counter=huge(1)
 call evaluate_irrigation_management_policy(p,s,r,c,y,st)
 call require(st==IRR_MGMT_INVALID_REQUEST.and.c%weekly_day_counter==s%weekly_day_counter,'overflow state rejected atomically')
 record%weekly_day_counter=367
 call restore_fmr_irrigation_management_restart(record,restored,st)
 call require(st==FMR_IRR_MGMT_RESTART_INVALID,'codec rejects out-of-source domain')
 ! The unchanged default path must not advance an unused counter.
 p%fixed_interval_enabled=.false.;s%weekly_day_counter=366
 call evaluate_irrigation_management_policy(p,s,r,c,y,st)
 call require(st==IRR_MGMT_OK.and.c%weekly_day_counter==366,'disabled option retains default state')
 print '(a,i0)','BATCH_FIXED_INTERVAL_SOURCE_CASES=',cases
 print '(a)','BATCH_FIXED_INTERVAL_LITERAL_RESTART_NONMUTATION=PASS'
contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then
 print *,label
 error stop 1
 endif
 end subroutine
 include 'batch_fixed_interval_literal.inc'
end program

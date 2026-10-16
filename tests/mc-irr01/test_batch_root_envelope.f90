program root_envelope
 use iso_fortran_env,only:real64
 use mod_scheduled_irrigation_management_policy
 implicit none
 type(irrigation_management_policy_parameters_t)::p
 type(irrigation_management_policy_state_t)::s,c
 type(irrigation_management_policy_request_t)::r
 type(irrigation_management_policy_result_t)::z
 real(real64)::rawtab(14),tawtab(14),dwatab(14),ditab(14),v,depth,threshold,edge,scale,x
 real(real64),parameter::xs(11)=[-.1_real64,0._real64,.1_real64,.333_real64,.5_real64, &
   .75_real64,1._real64,1.333_real64,1.9_real64,2._real64,2.1_real64]
 integer::n,criterion,i,j,st,irrigevent,side,raincase,fail,cases
 real(real64),external::afgen
 fail=0;cases=0
 do n=1,7
 p=irrigation_management_policy_parameters_t();p%depth_criterion=1
 p%dcs1_knot_count=n;p%tcs2_knot_count=n;p%tcs3_knot_count=n;p%tcs4_knot_count=n
 rawtab=-99;tawtab=-99;dwatab=-99;ditab=-99
 do i=1,n
  x=0;if(n>1)x=2._real64*real(i-1,real64)/real(n-1,real64)
  v=real(mod(i,3),real64)*.5_real64
  p%tcs2_dvs(i)=x;p%tcs2_fraction(i)=v
  p%tcs3_dvs(i)=x;p%tcs3_fraction(i)=v
  p%tcs4_dvs(i)=x;p%tcs4_depletion_mm(i)=500._real64*v
  p%dcs1_dvs(i)=x;p%dcs1_adjustment_mm(i)=200._real64*v-100._real64
  rawtab(2*i-1)=x;rawtab(2*i)=v
  tawtab(2*i-1)=x;tawtab(2*i)=v
  dwatab(2*i-1)=x;dwatab(2*i)=500._real64*v
  ditab(2*i-1)=x;ditab(2*i)=200._real64*v-100._real64
 end do
 do criterion=2,4
 p%timing_criterion=criterion
 do j=1,size(xs)
 r=irrigation_management_policy_request_t();r%dvs=xs(j)
 r%total_available_water_cm=10;r%stress_to_wilting_available_cm=4;r%field_capacity_deficit_cm=3
 select case(criterion)
 case(2);threshold=10._real64-afgen(rawtab,14,r%dvs)*6._real64
 case(3);threshold=10._real64-afgen(tawtab,14,r%dvs)*10._real64
 case(4);threshold=10._real64-afgen(dwatab,14,r%dvs)*.1_real64
 end select
 do side=-1,1
 edge=real(side,real64)*1.e-10_real64
 r%actual_available_water_cm=threshold+edge
 do raincase=1,3
 p%rainfall_threshold_cm=.05_real64
 r%rainfall_cm=.05_real64+real(raincase-2,real64)*1.e-5_real64
 call b111_root(criterion,r%dvs,rawtab,tawtab,dwatab,ditab, &
   r%total_available_water_cm,r%stress_to_wilting_available_cm,r%actual_available_water_cm, &
   r%field_capacity_deficit_cm,r%rainfall_cm,p%rainfall_threshold_cm,irrigevent,depth)
 call evaluate_irrigation_management_policy(p,s,r,c,z,st)
 cases=cases+1
 if(st/=IRR_MGMT_OK)then
  fail=fail+1
 else
  if(z%trigger.neqv.(irrigevent==2))then
   print *, 'TRIGGER_MISMATCH',n,criterion,j,side,r%actual_available_water_cm,z%trigger,irrigevent,z%timing_threshold
   error stop 'literal trigger mismatch'
  endif
  if(z%trigger.and.abs(z%selected_depth_cm-depth)>2.e-13_real64)error stop 'literal DCS1 mismatch'
 endif
 end do
 end do
 end do
 end do
 end do
 print '(a,i0,a,i0)','BATCH_ROOT_ENVELOPE_CASES=',cases,'|FAILURES=',fail
 if(fail/=0)error stop 2
 print '(a)','BATCH_ROOT_LITERAL_AFGEN_TCS234_DCS1_FULL_DOMAIN=PASS'
end program

program source_event_phase_driver
 use iso_fortran_env,only:real64,int64
#ifndef LEGACY_PHASE
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
#endif
 use mod_interception_source_window_runtime
 implicit none
 type(interception_source_window_t)::window
 type(interception_progress_t)::progress
 type(interception_trial_t)::trial
 real(real64),parameter::starts(3)=[19.002d0,19.60599999999928d0,32.75699999999695d0]
 real(real64),parameter::events(3)=[19.002000000000407d0,19.605999999999767d0,32.75699999999779d0]
 real(real64),parameter::old_rates(3)=[2.333333333262191d0,.6447368420973625d0,.32236842104868124d0]
 real(real64),parameter::new_rates(3)=[1.0425531915190585d0,0d0,9.423076923794186d0]
 real(real64)::cursor,rain_ends(2),rain_rates(2),endpoint,rain_rate,amount,first_amount,midpoint
 integer::rain_index,rain_count,code,k,defects
#ifndef LEGACY_PHASE
 real(real64)::nan,inf
 integer::next_rain_index
#endif
 defects=0;rain_count=2
 if(rain_count/=size(rain_ends))error stop 'fixture event count'
 do k=1,3
   cursor=starts(k);rain_ends=[events(k),events(k)+1d0];rain_rates=[old_rates(k),new_rates(k)]
   rain_index=1
#ifdef LEGACY_PHASE
   include 'legacy_phase_body.inc'
#else
   call select_interception_event_index(cursor,rain_ends,rain_index,next_rain_index,code)
   if(code/=INTWIN_OK)error stop 'valid actual phase refused'
   rain_index=next_rain_index
#endif
   if(rain_index/=1)then
     defects=defects+1
     cycle
   end if
   rain_rate=rain_rates(rain_index)
   call select_interception_event_endpoint(cursor,rain_ends(rain_index),.002d0,endpoint,code)
   if(code/=INTWIN_OK.or.endpoint/=events(k))error stop 'actual uncommitted event lost'
   amount=rain_rate*(endpoint-cursor)
   call initialize_interception_window(int(k,int64),cursor,endpoint,amount,window,code)
   call initialize_interception_progress(window,progress,code)
   call prepare_interception_trial(window,progress,endpoint,trial,code)
   if(code/=INTWIN_OK.or.trial%apportioned_amount()/=amount)error stop 'actual tiny rain packet lost'
   midpoint=cursor+.5d0*(endpoint-cursor)
   call prepare_interception_trial(window,progress,midpoint,trial,code)
   if(code/=INTWIN_OK)error stop 'actual tiny packet first half'
   first_amount=trial%apportioned_amount()
   call accept_interception_trial(window,trial,progress,code)
   if(code/=INTWIN_OK)error stop 'actual tiny packet first acceptance'
   call prepare_interception_trial(window,progress,endpoint,trial,code)
   if(code/=INTWIN_OK.or.first_amount+trial%apportioned_amount()/=amount)error stop 'actual tiny split packet lost'
   call accept_interception_trial(window,trial,progress,code)
   if(code/=INTWIN_OK.or.progress%accepted_time()/=endpoint)error stop 'actual tiny packet terminal clock'
#ifndef LEGACY_PHASE
   cursor=endpoint
   call select_interception_event_index(cursor,rain_ends,rain_index,next_rain_index,code)
   if(code/=INTWIN_OK.or.next_rain_index/=2)error stop 'committed event not advanced'
#endif
 end do
#ifdef LEGACY_PHASE
 if(defects==3)error stop 'UNCOMMITTED_RAIN_EVENT_SKIPPED_IN_3_ACTUAL_CASES'
 error stop 'legacy negative control not reproduced'
#else
 if(defects/=0)error stop 'uncommitted rain event skipped'
 call select_interception_event_index(0d0,[1d0,2d0],1,next_rain_index,code)
 if(code/=INTWIN_OK.or.next_rain_index/=1)error stop 'ordinary initial phase'
 call select_interception_event_index(0d0,[1d0],1,next_rain_index,code)
 if(code/=INTWIN_OK.or.next_rain_index/=1)error stop 'single event curve'
 call select_interception_event_index(1d0,[1d0,2d0],1,next_rain_index,code)
 if(code/=INTWIN_OK.or.next_rain_index/=2)error stop 'ordinary committed phase'
 call select_interception_event_index(1.5d0,[1d0,2d0],2,next_rain_index,code)
 if(code/=INTWIN_OK.or.next_rain_index/=2)error stop 'ordinary own current phase'
 call select_interception_event_index(.5d0,[1d0,2d0],2,next_rain_index,code)
 call refuse('already skipped uncommitted event')
 call select_interception_event_index(2d0,[1d0,2d0],1,next_rain_index,code)
 call refuse('exhausted event curve')
 call select_interception_event_index(0d0,[real(real64)::],1,next_rain_index,code)
 call refuse('empty event curve')
 call select_interception_event_index(0d0,[2d0,1d0],1,next_rain_index,code)
 call refuse('reversed event curve')
 call select_interception_event_index(0d0,[1d0,1d0],1,next_rain_index,code)
 call refuse('duplicate event curve')
 call select_interception_event_index(0d0,[1d0,2d0],0,next_rain_index,code)
 call refuse('invalid current index')
 nan=ieee_value(0d0,ieee_quiet_nan);inf=ieee_value(0d0,ieee_positive_inf)
 call select_interception_event_index(nan,[1d0,2d0],1,next_rain_index,code)
 call refuse('nonfinite cursor')
 call select_interception_event_index(0d0,[nan,2d0],1,next_rain_index,code)
 call refuse('nonfinite event')
 call select_interception_event_index(0d0,[1d0,inf],1,next_rain_index,code)
 call refuse('infinite event')
 print '(a)','SOURCE_PHASE_ACTUAL_TINY_PACKETS_AND_COMMITTED_CLOCK_PASS'
contains
 subroutine refuse(label)
   character(len=*),intent(in)::label
   if(code/=INTWIN_INVALID.or.next_rain_index/=0)then
     print *,label
     error stop 'invalid phase admitted'
   end if
 end subroutine
#endif
end program

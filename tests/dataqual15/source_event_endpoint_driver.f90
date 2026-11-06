program source_event_endpoint_driver
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_interception_source_window_runtime
 implicit none
 type(interception_source_window_t)::window
 type(interception_progress_t)::progress
 type(interception_trial_t)::first,second
 real(real64)::cursor,event_end,old_end,endpoint,rate,amount,part1,midpoint,bound
 integer::code
 cursor=80.421000000001399d0;event_end=80.423000000002503d0
 rate=.37236842104806855d0;old_end=cursor+.002d0
 amount=rate*(event_end-old_end)
 call initialize_interception_window(1_int64,old_end,event_end,amount,window,code)
 if(code/=INTWIN_OK)error stop 'real remainder witness setup'
 call initialize_interception_progress(window,progress,code)
 call prepare_interception_trial(window,progress,event_end,first,code)
 if(code/=INTWIN_OK)error stop 'real remainder witness trial'
 write(*,*)'ORIGINAL_UNRESOLVABLE_REMAINDER',event_end-old_end,amount,first%apportioned_amount()
 call select_interception_event_endpoint(cursor,event_end,.002d0,endpoint,code)
 if(code/=INTWIN_OK.or.endpoint/=event_end)error stop 'exact detailed event not selected'
 bound=64d0*epsilon(1d0)*max(1d0,abs(event_end))
 if(endpoint-cursor>.002d0+bound)error stop 'step ceiling exceeded beyond source-time roundoff'
 amount=rate*(endpoint-cursor)
 call initialize_interception_window(2_int64,cursor,endpoint,amount,window,code)
 call initialize_interception_progress(window,progress,code)
 call prepare_interception_trial(window,progress,endpoint,first,code)
 if(code/=INTWIN_OK.or.first%apportioned_amount()/=amount)error stop 'selected whole rain not apportioned'
 midpoint=cursor+.5d0*(endpoint-cursor)
 call prepare_interception_trial(window,progress,midpoint,first,code)
 if(code/=INTWIN_OK)error stop 'selected half trial'
 part1=first%apportioned_amount()
 call accept_interception_trial(window,first,progress,code)
 if(code/=INTWIN_OK.or.progress%complete(window))error stop 'premature selected event completion'
 call prepare_interception_trial(window,progress,endpoint,second,code)
 if(code/=INTWIN_OK)error stop 'selected terminal half trial'
 if(abs(part1+second%apportioned_amount()-amount)>8d0*epsilon(amount)*amount)error stop 'selected split lost rain'
 call accept_interception_trial(window,second,progress,code)
 if(code/=INTWIN_OK.or..not.progress%complete(window).or.progress%accepted_time()/=event_end) &
   error stop 'selected exact terminal progress'
 call select_interception_event_endpoint(0d0,1d0,.2d0,endpoint,code)
 if(code/=INTWIN_OK.or.endpoint/=.2d0)error stop 'ordinary capped endpoint changed'
 call select_interception_event_endpoint(cursor,event_end+1d-8,.002d0,endpoint,code)
 if(code/=INTWIN_OK.or.endpoint/=old_end)error stop 'distinct event was blurred'
 call select_interception_event_endpoint(0d0,.1d0,.2d0,endpoint,code)
 if(code/=INTWIN_OK.or.endpoint/=.1d0)error stop 'ordinary terminal event changed'
 call select_interception_event_endpoint(old_end,event_end,.002d0,endpoint,code)
 if(code/=INTWIN_INVALID.or.endpoint/=0d0)error stop 'already committed cursor relabelled'
 call select_interception_event_endpoint(1d0,1d0,.1d0,endpoint,code)
 if(code/=INTWIN_INVALID.or.endpoint/=0d0)error stop 'empty event admitted'
 call select_interception_event_endpoint(1d0,2d0,0d0,endpoint,code)
 if(code/=INTWIN_INVALID.or.endpoint/=0d0)error stop 'zero ceiling admitted'
 call select_interception_event_endpoint(1d0,2d0,tiny(1d0),endpoint,code)
 if(code/=INTWIN_INVALID.or.endpoint/=0d0)error stop 'nonadvancing capped step admitted'
 call select_interception_event_endpoint(ieee_value(0d0,ieee_quiet_nan),2d0,.1d0,endpoint,code)
 if(code/=INTWIN_INVALID.or.endpoint/=0d0)error stop 'nonfinite cursor admitted'
 call select_interception_event_endpoint(-huge(1d0),huge(1d0),1d0,endpoint,code)
 if(code/=INTWIN_INVALID.or.endpoint/=0d0)error stop 'unrepresentable event extent admitted'
 print '(a)','SOURCE_EVENT_ENDPOINT_REAL_WINDOW_AMOUNT_AND_REFUSAL_PASS'
end program

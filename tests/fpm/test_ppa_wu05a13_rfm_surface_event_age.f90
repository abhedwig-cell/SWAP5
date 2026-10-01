program test_ppa_wu05a13_rfm_surface_event_age
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rfm_surface_event_age
  implicit none

  real(real64), parameter :: tol=1.0e-15_real64
  type(rfm_surface_event_age_request_t) :: req
  type(rfm_surface_event_age_result_t) :: first,second,reset,restarted,replay

  req%accepted_age_day=0.0_real64
  req%step_duration_day=0.1_real64
  req%event_active=.true.
  call evaluate_rfm_surface_event_age(req,first)
  if(first%status/=RFM_SURFACE_EVENT_AGE_AVAILABLE)error stop 'A13 first status'
  if(abs(first%evaluation_age_day-0.05_real64)>tol)error stop 'A13 first midpoint'
  if(abs(first%candidate_age_day-0.1_real64)>tol)error stop 'A13 first candidate'

  req%accepted_age_day=first%candidate_age_day
  call evaluate_rfm_surface_event_age(req,second)
  if(abs(second%evaluation_age_day-0.15_real64)>tol)error stop 'A13 continuation midpoint'
  if(abs(second%candidate_age_day-0.2_real64)>tol)error stop 'A13 continuation candidate'

  ! Replay from the same accepted state must be bit-identical.
  call evaluate_rfm_surface_event_age(req,replay)
  if(.not.second%same_values(replay))error stop 'A13 replay identity'

  req%accepted_age_day=second%candidate_age_day
  req%event_active=.false.
  call evaluate_rfm_surface_event_age(req,reset)
  if(reset%status/=RFM_SURFACE_EVENT_AGE_AVAILABLE)error stop 'A13 reset status'
  if(abs(reset%evaluation_age_day)+abs(reset%candidate_age_day)>tol)error stop 'A13 reset'

  ! A caller commits reset before the next distinct event.
  req%accepted_age_day=reset%candidate_age_day
  req%event_active=.true.
  call evaluate_rfm_surface_event_age(req,restarted)
  if(abs(restarted%evaluation_age_day-0.05_real64)>tol)error stop 'A13 restart midpoint'
  if(abs(restarted%candidate_age_day-0.1_real64)>tol)error stop 'A13 restart candidate'

  req%accepted_age_day=-0.1_real64
  call evaluate_rfm_surface_event_age(req,replay)
  if(replay%status/=RFM_SURFACE_EVENT_AGE_INVALID)error stop 'A13 negative age accepted'

  req%accepted_age_day=0.0_real64
  req%step_duration_day=0.0_real64
  call evaluate_rfm_surface_event_age(req,replay)
  if(replay%status/=RFM_SURFACE_EVENT_AGE_INVALID)error stop 'A13 zero dt accepted'

  print '(a)', 'PPA_WU05A13_RFM_SURFACE_EVENT_AGE=PASS'
end program test_ppa_wu05a13_rfm_surface_event_age

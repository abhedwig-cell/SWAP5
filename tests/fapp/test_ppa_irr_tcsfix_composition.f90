program test_tcsfix
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_ppa_irr_tcsfix_composition
  implicit none
  type(scheduled_irrigation_parameters_t)::p
  type(scheduled_irrigation_request_t)::r
  type(irrigation_state_t)::base,candidate,pending
  type(irrigation_flux_result_t)::flux
  type(irrigation_diagnostics_t)::d
  real(real64)::knots(7),values(7)
  integer::i,j,next_day
  p%scheduled_irrigation_enabled=.true.; p%active_nodes=1; p%sensor_node=1; p%single_ssdi_node=1
  p%irr_rate_cm_per_day=1.0_real64; p%dcs2_knot_count=2
  p%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]; p%dcs2_depth_cm=0.5_real64
  r%t0=0.0_real64; r%t1=0.25_real64
  r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
  r%crop_emerged=.true.; r%irrigation_window_open=.true.
  knots=0.0_real64; knots(2)=2.0_real64; values=0.5_real64
  do i=1,4
    p%timing_criterion=i
    do j=2,4
      call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
           1.0_real64,0.5_real64,0.1_real64,.true.,j,3,next_day,candidate,flux,d)
      if(d%status/=IRRIGATION_OK) error stop 'composition'
      if(flux%event_started.neqv.(j>=3)) error stop 'interval filter'
      if(j==2.and.next_day/=3) error stop 'counter increment'
      if(j>=3.and.next_day/=1) error stop 'counter reset'
    end do
    r%t1=0.75_real64
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,.true.,2,3,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.flux%event_started.or.next_day/=3) error stop 'suppressed split'
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,.true.,366,3,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_SPLIT_REQUIRED.or.next_day/=366) error stop 'split counter atomicity'
    r%t1=d%split_time
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,.true.,366,3,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.next_day/=1.or..not.flux%event_finished) error stop 'retry'
    r%t1=0.25_real64
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,.true.,3,3,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or..not.candidate%active_event) error stop 'pending setup'
    pending=candidate; r%t0=0.25_real64; r%t1=0.5_real64
    call evaluate_tcsfix_scheduled(p,pending,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,0.0_real64,.true.,1,3,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.next_day/=1.or..not.flux%event_finished) error stop 'pending bypass'
    r%t0=0.0_real64; r%t1=0.25_real64
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,0.0_real64,.false.,2,3,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.next_day/=2.or.flux%event_started) error stop 'nondaily bypass'
    r%crop_emerged=.false.
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,0.0_real64,.true.,2,3,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.next_day/=2.or.flux%event_started) error stop 'ineligible counter'
    r%crop_emerged=.true.
    do j=2,4
      call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.0_real64,0.0_real64, &
           1.0_real64,0.5_real64,1.0_real64,.true.,j,3,next_day,candidate,flux,d)
      if(d%status/=IRRIGATION_OK.or.flux%event_started.or.next_day/=max(j,3)) &
           error stop 'no candidate increment or hold'
    end do
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,0.0_real64,.true.,2,3,next_day,candidate,flux,d)
    if(d%status==IRRIGATION_OK.or.next_day/=2.or.flux%event_started) error stop 'invalid observations'
    do j=0,367,367
      call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
           1.0_real64,0.5_real64,0.1_real64,.true.,2,j,next_day,candidate,flux,d)
      if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.next_day/=2) error stop 'invalid interval'
    end do
  end do
  print '(a)', 'PPA_IRR_TCSFIX_COMPOSITION_INITIAL=PASS'
  print '(a)', 'PPA_IRR_TCSFIX_PENDING_ELIGIBILITY_INPUT_GUARDS=PASS'
  print '(a)', 'PPA_IRR_TCSFIX_NO_CANDIDATE_COUNTER=PASS'
end program

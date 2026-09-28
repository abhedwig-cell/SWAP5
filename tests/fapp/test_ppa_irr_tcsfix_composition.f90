program test_tcsfix
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_ppa_irr_tcsfix_identity
  use mod_ppa_irr_tcsfix_daily
  use mod_irrigation_process
  use mod_ppa_irr_tcsfix_composition
  implicit none
  type(scheduled_irrigation_parameters_t)::p
  type(scheduled_irrigation_request_t)::r
  type(irrigation_state_t)::base,candidate,pending
  type(irrigation_flux_result_t)::flux
  type(irrigation_diagnostics_t)::d
  real(real64)::knots(7),values(7)
  integer::i,j,next_day,guard
  type(ppa_tcsfix_identity_t)::identity,proposal
  logical::daily,ok
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
    do guard=1,7
      p%scheduled_irrigation_enabled=guard/=1
      r%selection_opportunity=guard/=2; r%irrigation_enabled=guard/=3
      r%schedule_enabled=guard/=4; r%crop_emerged=guard/=5
      r%irrigation_window_open=guard/=6; r%fixed_event_already_selected=guard==7
      call evaluate_tcsfix_scheduled(p,base,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
           0.0_real64,0.0_real64,0.0_real64,.true.,2,3,next_day,candidate,flux,d)
      if(d%status/=IRRIGATION_OK.or.next_day/=2.or.flux%event_started) error stop 'eligibility grid'
    end do
    p%scheduled_irrigation_enabled=.true.; r%selection_opportunity=.true.; r%irrigation_enabled=.true.
    r%schedule_enabled=.true.; r%crop_emerged=.true.; r%irrigation_window_open=.true.
    r%fixed_event_already_selected=.false.
    do j=-1,367,368
      call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
           1.0_real64,0.5_real64,0.1_real64,.true.,j,3,next_day,candidate,flux,d)
      if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.next_day/=j.or.flux%event_started) &
           error stop 'invalid counter'
    end do
  end do
  do i=5,8
    p%timing_criterion=i
    call evaluate_tcsfix_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,.true.,3,3,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.next_day/=3.or.flux%event_started) &
         error stop 'unsupported timing including weekly'
  end do
  print '(a)', 'PPA_IRR_TCSFIX_COMPOSITION_INITIAL=PASS'
  print '(a)', 'PPA_IRR_TCSFIX_PENDING_ELIGIBILITY_INPUT_GUARDS=PASS'
  print '(a)', 'PPA_IRR_TCSFIX_NO_CANDIDATE_COUNTER=PASS'
  print '(a)', 'PPA_IRR_TCSFIX_ELIGIBILITY_COUNTER_TIMING_GRID=PASS'
  if(.not.valid_tcsfix_identity(identity)) error stop 'identity default'
  call prepare_tcsfix_day(identity,.true.,100_int64,proposal,daily,ok)
  if(ok) error stop 'disabled identity'
  identity%enabled=.true.; identity%interval_days=3
  call prepare_tcsfix_day(identity,.true.,100_int64,proposal,daily,ok)
  if(.not.ok.or..not.daily.or..not.proposal%day_bound) error stop 'first identity'
  identity=proposal
  do i=99,102
    call prepare_tcsfix_day(identity,.true.,int(i,int64),proposal,daily,ok)
    if(ok.neqv.(i==100.or.i==101)) error stop 'ordinal guard'
    if(daily.neqv.(i==101)) error stop 'duplicate evaluation'
  end do
  identity%last_day=huge(0_int64)
  call prepare_tcsfix_day(identity,.true.,0_int64,proposal,daily,ok)
  if(ok) error stop 'ordinal overflow guard'
  identity%interval_days=0
  if(valid_tcsfix_identity(identity)) error stop 'identity interval'
  print '(a)', 'PPA_IRR_TCSFIX_DETACHED_DAILY_IDENTITY=PASS'
  identity=ppa_tcsfix_identity_t(); identity%enabled=.true.; identity%interval_days=3
  p%timing_criterion=1; r%t1=0.75_real64
  call evaluate_tcsfix_daily_proposal(p,base,r,identity,.true.,100_int64,knots,values,2, &
       1.0_real64,0.75_real64,0.0_real64,1.0_real64,0.5_real64,0.1_real64,proposal,candidate,flux,d)
  if(d%status/=IRRIGATION_SPLIT_REQUIRED.or.proposal%day_bound.or.proposal%dayfix/=366) &
       error stop 'daily split consumed identity'
  r%t1=d%split_time
  call evaluate_tcsfix_daily_proposal(p,base,r,identity,.true.,100_int64,knots,values,2, &
       1.0_real64,0.75_real64,0.0_real64,1.0_real64,0.5_real64,0.1_real64,proposal,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.proposal%dayfix/=1.or.proposal%last_day/=100_int64) &
       error stop 'daily retry identity'
  identity=proposal
  call evaluate_tcsfix_daily_proposal(p,base,r,identity,.true.,100_int64,knots,values,0, &
       0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,proposal,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.flux%event_started.or.proposal%dayfix/=1) error stop 'daily duplicate'
  call evaluate_tcsfix_daily_proposal(p,base,r,identity,.true.,101_int64,knots,values,2, &
       1.0_real64,0.75_real64,0.0_real64,1.0_real64,0.5_real64,0.1_real64,proposal,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.flux%event_started.or.proposal%dayfix/=2.or.proposal%last_day/=101_int64) &
       error stop 'daily successor filter'
  print '(a)', 'PPA_IRR_TCSFIX_DAILY_ATOMIC_PROPOSAL=PASS'
  identity=proposal
  call evaluate_tcsfix_daily_proposal(p,base,r,identity,.true.,102_int64,knots,values,0, &
       0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,proposal,candidate,flux,d)
  if(d%status==IRRIGATION_OK.or.proposal%last_day/=101_int64.or.proposal%dayfix/=2) &
       error stop 'daily failure consumed ordinal'
  do i=102,106
    call evaluate_tcsfix_daily_proposal(p,base,r,identity,.true.,int(i,int64),knots,values,2, &
         1.0_real64,0.75_real64,0.0_real64,1.0_real64,0.5_real64,0.1_real64,proposal,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.proposal%last_day/=int(i,int64)) error stop 'daily sequence'
    if(flux%event_started.neqv.(i==103.or.i==106)) error stop 'daily interval sequence'
    identity=proposal
  end do
  ! Fresh partial gift followed by duplicate and successor pending invocations.
  identity=ppa_tcsfix_identity_t(); identity%enabled=.true.; identity%interval_days=3
  r%t1=0.25_real64
  call evaluate_tcsfix_daily_proposal(p,base,r,identity,.true.,100_int64,knots,values,2, &
       1.0_real64,0.75_real64,0.0_real64,1.0_real64,0.5_real64,0.1_real64,proposal,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or..not.candidate%active_event) error stop 'daily pending setup'
  identity=proposal; pending=candidate; r%t0=0.25_real64; r%t1=0.5_real64
  do i=100,101
    call evaluate_tcsfix_daily_proposal(p,pending,r,identity,.true.,int(i,int64),knots,values,0, &
         0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,proposal,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.proposal%dayfix/=1.or.proposal%last_day/=int(i,int64).or. &
         .not.flux%event_finished.or.flux%event_started) error stop 'daily pending counter'
  end do
  print '(a)', 'PPA_IRR_TCSFIX_DAILY_SEQUENCE_FAILURE_PENDING=PASS'
  identity%day_bound=.true.; identity%last_day=100_int64
  do guard=1,366
    identity%interval_days=guard
    do i=0,366
      identity%dayfix=i
      do j=0,366
        proposal=identity; proposal%last_day=101_int64; proposal%dayfix=j
        ok=j==i
        if(i<guard) ok=ok.or.j==i+1
        if(i>=guard) ok=ok.or.j==1
        if(valid_tcsfix_transition(identity,proposal).neqv.ok) error stop 'transition grid'
        proposal%last_day=100_int64
        if(valid_tcsfix_transition(identity,proposal).neqv.(j==i)) error stop 'same-day transition'
      end do
    end do
  end do
  proposal=identity; proposal%interval_days=365
  if(valid_tcsfix_transition(identity,proposal)) error stop 'interval mutation'
  proposal=identity; proposal%last_day=102_int64
  if(valid_tcsfix_transition(identity,proposal)) error stop 'transition gap'
  proposal=identity; proposal%enabled=.false.
  if(valid_tcsfix_transition(identity,proposal)) error stop 'transition disable'
  print '(a)', 'PPA_IRR_TCSFIX_TRANSITION_GRID=PASS'
end program

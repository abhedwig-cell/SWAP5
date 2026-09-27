program test_tcsfix
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_ppa_irr_tcsfix_composition
  implicit none
  type(scheduled_irrigation_parameters_t)::p
  type(scheduled_irrigation_request_t)::r
  type(irrigation_state_t)::base,candidate
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
  end do
  print '(a)', 'PPA_IRR_TCSFIX_COMPOSITION_INITIAL=PASS'
end program

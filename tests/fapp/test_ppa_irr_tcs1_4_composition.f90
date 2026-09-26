program test_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_ppa_irr_tcs1_4_composition
  implicit none
  type(scheduled_irrigation_parameters_t)::p
  type(scheduled_irrigation_request_t)::r
  type(irrigation_state_t)::base,candidate,pending
  type(irrigation_flux_result_t)::flux
  type(irrigation_diagnostics_t)::d
  real(real64)::knots(7),values(7)
  integer::i
  p%scheduled_irrigation_enabled=.true.; p%active_nodes=1; p%sensor_node=1; p%single_ssdi_node=1
  p%irr_rate_cm_per_day=1.0_real64; p%dcs2_knot_count=2
  p%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]; p%dcs2_depth_cm=0.5_real64
  r%t0=0.0_real64; r%t1=0.25_real64
  r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
  r%crop_emerged=.true.; r%irrigation_window_open=.true.
  knots=0.0_real64; knots(2)=2.0_real64; values=0.5_real64
  do i=1,4
    p%timing_criterion=i
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or..not.flux%event_started.or..not.candidate%active_event) error stop 'selection'
    if(flux%external_inflow_amount/=0.25_real64.or.candidate%active_event_end/=0.5_real64) error stop 'amount'
    pending=candidate
    r%t0=0.25_real64; r%t1=0.75_real64
    call evaluate_tcs1_4_scheduled(p,pending,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,0.0_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_SPLIT_REQUIRED.or.d%split_time/=0.5_real64) error stop 'pending split'
    r%t1=d%split_time
    call evaluate_tcs1_4_scheduled(p,pending,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,0.0_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.candidate%active_event.or..not.flux%event_finished) error stop 'pending finish'
    r%t0=0.0_real64; r%t1=0.25_real64
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,2,1.0_real64,0.0_real64,0.0_real64, &
         1.0_real64,0.5_real64,1.0_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.flux%event_started.or.candidate%active_event) error stop 'false trigger'
  end do
  write(*,'(a)') 'PPA_IRR_TCS1_4_DCS2_COMPOSITION=PASS'
end program

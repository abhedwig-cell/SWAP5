program test_mc_irr01_management_application
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: irrigation_flux_result_t, IRRIGATION_APPLICATION_SURFACE, IRRIGATION_APPLICATION_SSDI
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_result_t
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_summary_t
  use mod_fmr_scheduled_management_irrigation_application
  implicit none

  type(fmr_irrigation_management_parameters_t) :: p
  type(fmr_irrigation_management_state_t) :: s,c
  type(fmr_irrigation_management_request_t) :: r
  type(process_hydraulic_view_t) :: h
  type(irrigation_flux_result_t) :: flux
  type(irrigation_management_policy_result_t) :: policy
  type(irrigation_root_zone_summary_t) :: summary
  type(fmr_irrigation_management_diagnostics_t) :: d
  real(real64), parameter :: tol=1.0e-12_real64

  ! Choose unambiguous trigger-side samples; the strict B1.11 equality
  ! boundaries are covered separately by the policy test.
  call setup_base(p,h,r)
  p%policy%timing_criterion=2
  p%policy%tcs2_knot_count=2
  p%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs2_fraction(1:2)=[0.4_real64,0.4_real64]
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%trigger .and. flux%event_finished,1)
  call require(abs(flux%surface_gross_rate-1.0_real64)<tol .and. abs(flux%external_inflow_amount-1.0_real64)<tol,2)

  call setup_base(p,h,r)
  p%policy%timing_criterion=3
  p%policy%tcs3_knot_count=2
  p%policy%tcs3_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs3_fraction(1:2)=[0.20_real64,0.20_real64]
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%trigger,3)

  call setup_base(p,h,r)
  p%policy%timing_criterion=4
  p%policy%tcs4_knot_count=2
  p%policy%tcs4_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs4_depletion_mm(1:2)=[9.0_real64,9.0_real64]
  p%policy%depth_limit_enabled=.true.
  p%policy%minimum_depth_cm=1.5_real64
  p%policy%maximum_depth_cm=3.0_real64
  r%t1=r%t0+1.0_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%depth_limited,4)
  call require(abs(d%selected_depth_cm-1.5_real64)<tol .and. abs(flux%external_inflow_amount-1.5_real64)<tol,5)

  call setup_base(p,h,r)
  p%policy%timing_criterion=4
  p%policy%tcs4_knot_count=2
  p%policy%tcs4_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs4_depletion_mm(1:2)=[9.0_real64,9.0_real64]
  p%policy%rainfall_threshold_cm=0.5_real64
  r%rainfall_cm=0.6_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%rainfall_deducted,6)
  call require(abs(d%selected_depth_cm-0.4_real64)<tol .and. abs(flux%external_inflow_amount-0.4_real64)<tol,7)

  call setup_base(p,h,r)
  p%policy%timing_criterion=6
  p%policy%tcs6_threshold_mm=9.0_real64
  s%policy%weekly_day_counter=6
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%weekly_opportunity .and. policy%trigger,8)
  call require(c%policy%weekly_day_counter==0,9)

  call setup_base(p,h,r)
  p%policy%timing_criterion=2
  p%policy%tcs2_knot_count=2
  p%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs2_fraction(1:2)=[0.4_real64,0.4_real64]
  p%application_type=IRRIGATION_APPLICATION_SSDI
  p%single_ssdi_node=2
  p%rate_cm_per_day=4.0_real64
  r%t1=r%t0+0.25_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. allocated(flux%subsurface_source),10)
  call require(abs(flux%subsurface_source(2)-4.0_real64)<tol .and. abs(flux%external_inflow_amount-1.0_real64)<tol,11)

  ! Crossing the selected event end is a retry request with no candidate state progress.
  call setup_base(p,h,r)
  p%policy%timing_criterion=2
  p%policy%tcs2_knot_count=2
  p%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs2_fraction(1:2)=[0.4_real64,0.4_real64]
  p%rate_cm_per_day=4.0_real64
  r%t1=r%t0+1.0_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_SPLIT_REQUIRED .and. d%split_required,12)
  call require(.not.c%event%active_event .and. c%policy%weekly_day_counter==s%policy%weekly_day_counter,13)

  ! Zero-rate fallback persists its effective rate across accepted continuation.
  call setup_base(p,h,r)
  p%policy%timing_criterion=2
  p%policy%tcs2_knot_count=2
  p%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs2_fraction(1:2)=[0.4_real64,0.4_real64]
  p%rate_cm_per_day=0.0_real64
  r%t1=r%t0+0.5_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. c%event%active_event,14)
  call require(abs(c%event%active_event_rate_cm_per_day-1.0_real64)<tol .and. abs(flux%external_inflow_amount-0.5_real64)<tol,15)
  s=c
  r=fmr_irrigation_management_request_t()
  r%t0=100.5_real64; r%t1=101.0_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. flux%event_finished .and. .not.c%event%active_event,16)
  call require(abs(flux%surface_gross_rate-1.0_real64)<tol .and. abs(flux%external_inflow_amount-0.5_real64)<tol,17)


  ! TCS2/3/4/6 can reuse the independently admitted DCS2 DVS-depth owner.
  call setup_base(p,h,r)
  p%policy%depth_criterion=2
  p%policy%dcs2_knot_count=2
  p%policy%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%dcs2_depth_cm(1:2)=[0.8_real64,1.2_real64]
  p%policy%timing_criterion=2
  p%policy%tcs2_knot_count=2
  p%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs2_fraction(1:2)=[0.4_real64,0.4_real64]
  r%dvs=1.0_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%trigger,18)
  call require(abs(d%selected_depth_cm-1.0_real64)<tol .and. abs(flux%external_inflow_amount-1.0_real64)<tol,19)

  call setup_base(p,h,r)
  p%policy%depth_criterion=2
  p%policy%dcs2_knot_count=2
  p%policy%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%dcs2_depth_cm(1:2)=[1.0_real64,1.0_real64]
  p%policy%timing_criterion=3
  p%policy%tcs3_knot_count=2
  p%policy%tcs3_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs3_fraction(1:2)=[0.20_real64,0.20_real64]
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%trigger,22)
  call require(abs(d%selected_depth_cm-1.0_real64)<tol .and. abs(flux%external_inflow_amount-1.0_real64)<tol,23)

  call setup_base(p,h,r)
  p%policy%depth_criterion=2
  p%policy%dcs2_knot_count=2
  p%policy%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%dcs2_depth_cm(1:2)=[1.0_real64,1.0_real64]
  p%policy%timing_criterion=4
  p%policy%tcs4_knot_count=2
  p%policy%tcs4_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs4_depletion_mm(1:2)=[9.0_real64,9.0_real64]
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%trigger,24)
  call require(abs(d%selected_depth_cm-1.0_real64)<tol .and. abs(flux%external_inflow_amount-1.0_real64)<tol,25)

  call setup_base(p,h,r)
  p%policy%depth_criterion=2
  p%policy%dcs2_knot_count=2
  p%policy%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%dcs2_depth_cm(1:2)=[1.0_real64,1.0_real64]
  p%policy%timing_criterion=6
  p%policy%tcs6_threshold_mm=9.0_real64
  s=fmr_irrigation_management_state_t()
  s%policy%weekly_day_counter=6
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. policy%weekly_opportunity .and. policy%trigger,20)
  call require(abs(d%selected_depth_cm-1.0_real64)<tol .and. c%policy%weekly_day_counter==0,21)

  ! TASK=4 availability is post-selection and persists its scaled event state.
  call setup_base(p,h,r)
  p%policy%depth_criterion=2
  p%policy%dcs2_knot_count=2
  p%policy%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%dcs2_depth_cm(1:2)=[1.0_real64,1.0_real64]
  p%policy%timing_criterion=2
  p%policy%tcs2_knot_count=2
  p%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs2_fraction(1:2)=[0.4_real64,0.4_real64]
  p%rate_cm_per_day=4.0_real64
  r%availability_scaling_enabled=.true.
  r%availability_fraction=0.5_real64
  r%t1=r%t0+0.125_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. d%availability_applied .and. c%event%active_event,26)
  call require(abs(flux%surface_gross_rate-2.0_real64)<tol .and. abs(flux%external_inflow_amount-0.25_real64)<tol,27)

  call setup_base(p,h,r)
  p%policy%depth_criterion=2
  p%policy%dcs2_knot_count=2
  p%policy%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%dcs2_depth_cm(1:2)=[1.0_real64,1.0_real64]
  p%policy%timing_criterion=2
  p%policy%tcs2_knot_count=2
  p%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%tcs2_fraction(1:2)=[0.4_real64,0.4_real64]
  p%rate_cm_per_day=0.0_real64
  r%availability_scaling_enabled=.true.
  r%availability_fraction=0.5_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. flux%event_finished,28)
  call require(abs(flux%surface_gross_rate-0.5_real64)<tol .and. abs(flux%external_inflow_amount-0.5_real64)<tol,29)

  print '(A)','MC_IRR01_AVAIL_MANAGEMENT_POLICY=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_APPLICATION=PASS'
  print '(A)','MC_IRR01_TCS2346_DCS2_COMPOSITION=PASS'
  print '(A)','MC_IRR01_TCS2346_DCS1_EVENT_LIFECYCLE=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_RETRY_CONTINUATION=PASS'

contains
  subroutine setup_base(p,h,r)
    type(fmr_irrigation_management_parameters_t),intent(out)::p
    type(process_hydraulic_view_t),intent(out)::h
    type(fmr_irrigation_management_request_t),intent(out)::r
    p=fmr_irrigation_management_parameters_t()
    p%active_nodes=3
    p%application_type=IRRIGATION_APPLICATION_SURFACE
    p%rate_cm_per_day=0.0_real64
    p%root_zone%active_nodes=3
    p%root_zone%rooted_nodes=2
    p%root_zone%last_rooted_fraction=0.5_real64
    allocate(p%root_zone%node_thickness_cm(3),p%root_zone%field_capacity_water_content(3), &
             p%root_zone%stress_water_content(3),p%root_zone%wilting_water_content(3))
    p%root_zone%node_thickness_cm=[10.0_real64,20.0_real64,30.0_real64]
    p%root_zone%field_capacity_water_content=[0.30_real64,0.35_real64,0.40_real64]
    p%root_zone%stress_water_content=[0.20_real64,0.25_real64,0.30_real64]
    p%root_zone%wilting_water_content=[0.10_real64,0.15_real64,0.20_real64]
    p%policy%depth_criterion=1
    p%policy%dcs1_knot_count=2
    p%policy%dcs1_dvs(1:2)=[0.0_real64,2.0_real64]
    p%policy%dcs1_adjustment_mm(1:2)=[0.0_real64,0.0_real64]
    h=process_hydraulic_view_t()
    h%active_nodes=3
    allocate(h%pressure_head(3),h%water_content(3))
    h%pressure_head=-100.0_real64
    h%water_content=[0.25_real64,0.30_real64,0.99_real64]
    r=fmr_irrigation_management_request_t()
    r%t0=100.0_real64
    r%t1=101.0_real64
    r%dvs=1.0_real64
    r%selection_opportunity=.true.
    r%irrigation_enabled=.true.
    r%schedule_enabled=.true.
    r%crop_emerged=.true.
    r%irrigation_window_open=.true.
  end subroutine setup_base

  subroutine require(ok,n)
    logical,intent(in)::ok
    integer,intent(in)::n
    if(.not.ok)then
      write(*,'(A,I0)')'MC_IRR01_MANAGEMENT_APP_FAIL=',n
      error stop 1
    end if
  end subroutine require
end program test_mc_irr01_management_application

program test_mc_irr01_management_restart
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: irrigation_flux_result_t
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_result_t
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_summary_t
  use mod_fmr_scheduled_management_irrigation_application
  use mod_fmr_irrigation_management_restart
  implicit none

  type(fmr_irrigation_management_parameters_t) :: p
  type(fmr_irrigation_management_state_t) :: s,c,restored
  type(fmr_irrigation_management_request_t) :: r
  type(fmr_irrigation_management_restart_record_t) :: rec,bad
  type(process_hydraulic_view_t) :: h
  type(irrigation_flux_result_t) :: flux
  type(irrigation_management_policy_result_t) :: policy
  type(irrigation_root_zone_summary_t) :: summary
  type(fmr_irrigation_management_diagnostics_t) :: d
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  call setup(p,h,r)
  p%policy%timing_criterion=6
  p%policy%tcs6_threshold_mm=9.0_real64
  p%policy%depth_criterion=2
  p%policy%dcs2_knot_count=2
  p%policy%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%policy%dcs2_depth_cm(1:2)=[1.0_real64,1.0_real64]
  p%rate_cm_per_day=2.0_real64
  s%policy%weekly_day_counter=6
  r%t1=r%t0+0.25_real64

  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. c%event%active_event,1)
  call require(c%policy%weekly_day_counter==0,2)
  call require(abs(c%event%active_event_rate_cm_per_day-2.0_real64)<tol,3)

  call export_fmr_irrigation_management_restart(c,rec,status)
  call require(status==FMR_IRR_MGMT_RESTART_OK .and. rec%weekly_day_counter==0,4)
  call restore_fmr_irrigation_management_restart(rec,restored,status)
  call require(status==FMR_IRR_MGMT_RESTART_OK,5)
  call require(restored%event%active_event .and. restored%policy%weekly_day_counter==0,6)

  s=restored
  r=fmr_irrigation_management_request_t()
  r%t0=100.25_real64
  r%t1=100.5_real64
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,d)
  call require(d%status==FMR_IRR_MGMT_APP_OK .and. flux%event_finished .and. .not.c%event%active_event,7)
  call require(abs(flux%external_inflow_amount-0.5_real64)<tol .and. c%policy%weekly_day_counter==0,8)

  bad=rec
  bad%schema=rec%schema+1
  call restore_fmr_irrigation_management_restart(bad,restored,status)
  call require(status==FMR_IRR_MGMT_RESTART_SCHEMA_MISMATCH,9)
  call require(.not.restored%event%active_event .and. restored%policy%weekly_day_counter==366,10)

  bad=rec
  bad%weekly_day_counter=-1
  call restore_fmr_irrigation_management_restart(bad,restored,status)
  call require(status==FMR_IRR_MGMT_RESTART_INVALID,11)
  call require(.not.restored%event%active_event .and. restored%policy%weekly_day_counter==366,12)

  print '(A)','MC_IRR01_TCS6_WEEK_COUNTER_RESTART=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_EVENT_RESTART_CONTINUATION=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_RESTART_FAIL_CLOSED=PASS'

contains
  subroutine setup(p,h,r)
    type(fmr_irrigation_management_parameters_t),intent(out)::p
    type(process_hydraulic_view_t),intent(out)::h
    type(fmr_irrigation_management_request_t),intent(out)::r
    p=fmr_irrigation_management_parameters_t()
    p%active_nodes=3
    p%root_zone%active_nodes=3
    p%root_zone%rooted_nodes=2
    p%root_zone%last_rooted_fraction=0.5_real64
    allocate(p%root_zone%node_thickness_cm(3),p%root_zone%field_capacity_water_content(3), &
             p%root_zone%stress_water_content(3),p%root_zone%wilting_water_content(3))
    p%root_zone%node_thickness_cm=[10.0_real64,20.0_real64,30.0_real64]
    p%root_zone%field_capacity_water_content=[0.30_real64,0.35_real64,0.40_real64]
    p%root_zone%stress_water_content=[0.20_real64,0.25_real64,0.30_real64]
    p%root_zone%wilting_water_content=[0.10_real64,0.15_real64,0.20_real64]
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
  end subroutine

  subroutine require(ok,n)
    logical,intent(in)::ok
    integer,intent(in)::n
    if(.not.ok)then
      write(*,'(A,I0)')'MC_IRR01_MGMT_RESTART_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_mc_irr01_management_restart

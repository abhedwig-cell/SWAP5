program test_mc_irr01_scheduled_tcs7_ssdi_runtime_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, irrigation_state_t
  use mod_fmr_scheduled_irrigation_application
  use mod_fmr_irrigation_management_restart, only: fmr_irrigation_event_restart_record_t, &
       export_fmr_irrigation_event_restart, restore_fmr_irrigation_event_restart, FMR_IRR_MGMT_RESTART_OK
  implicit none

  type(scheduled_irrigation_parameters_t) :: p
  type(scheduled_irrigation_request_t) :: r
  type(irrigation_state_t) :: s, c
  type(process_hydraulic_view_t) :: h
  type(fmr_scheduled_irrigation_application_diagnostics_t) :: d
  type(fmr_irrigation_event_restart_record_t) :: restart_record
  integer :: restart_status
  real(real64), allocatable :: q(:)
  real(real64), parameter :: tol = 1.0e-12_real64
  real(real64) :: duration

  p%scheduled_irrigation_enabled = .true.
  p%active_nodes = 4
  p%sensor_node = 2
  p%single_ssdi_node = 3
  p%irr_rate_cm_per_day = 0.48_real64
  p%tcs7_knot_count = 2
  p%tcs7_dvs(1:2) = [0.0_real64, 2.0_real64]
  p%tcs7_pressure_head(1:2) = [-70.0_real64, -70.0_real64]
  p%dcs2_knot_count = 2
  p%dcs2_dvs(1:2) = [0.0_real64, 2.0_real64]
  p%dcs2_depth_cm(1:2) = [0.12_real64, 0.12_real64]

  h%active_nodes = 4
  allocate(h%pressure_head(4),h%water_content(4))
  h%pressure_head = -60.0_real64
  h%pressure_head(2) = -75.0_real64
  h%water_content = 0.30_real64

  duration = 0.12_real64/0.48_real64
  r%t0 = 2600.375_real64
  r%t1 = r%t0 + duration
  r%dvs = 1.0_real64
  r%selection_opportunity = .true.
  r%irrigation_enabled = .true.
  r%schedule_enabled = .true.
  r%crop_emerged = .true.
  r%irrigation_window_open = .true.

  call fmr_apply_scheduled_tcs7_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. d%result_produced .and. d%source_bound,1)
  call require(allocated(q) .and. size(q) == 4,2)
  call require(abs(q(3)-0.48_real64) < tol .and. sum(abs(q([1,2,4]))) < tol,3)
  call require(abs(d%external_inflow_amount_cm-0.12_real64) < tol,4)
  call require(.not. c%active_event,5)

  ! No trigger remains inactive and does not manufacture a source vector.
  h%pressure_head(2) = -60.0_real64
  call fmr_apply_scheduled_tcs7_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_INACTIVE .and. .not. d%result_produced,6)
  call require(.not. allocated(q),7)

  ! A trial crossing event end fails upstream and leaves candidate authority unchanged.
  h%pressure_head(2) = -75.0_real64
  r%t1 = r%t0 + 1.0_real64
  call fmr_apply_scheduled_tcs7_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_UPSTREAM_REJECTED .and. .not. d%result_produced,8)
  call require(.not. allocated(q) .and. .not. c%active_event,9)

  ! TCS8 uses water content at the same explicit sensor node.
  p%timing_criterion = 8
  p%tcs8_knot_count = 2
  p%tcs8_dvs(1:2) = [0.0_real64, 2.0_real64]
  p%tcs8_water_content(1:2) = [0.25_real64, 0.25_real64]
  h%water_content(2) = 0.20_real64
  r%t1 = r%t0 + duration
  s = irrigation_state_t()
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. d%result_produced .and. d%source_bound,10)
  call require(abs(q(3)-0.48_real64) < tol .and. abs(d%external_inflow_amount_cm-0.12_real64) < tol,11)

  ! DCSLIM is applied to the selected DCS2 depth before sensor salinity surplus.
  p%depth_limit_enabled = .true.
  p%minimum_depth_cm = 0.20_real64
  p%maximum_depth_cm = 0.30_real64
  p%salinity_excess_enabled = .true.
  p%salinity_threshold = 8.0_real64
  p%salinity_excess_percent = 50.0_real64
  r%solute_enabled = .true.
  r%sensor_concentration = 9.0_real64
  r%t1 = r%t0 + 0.625_real64
  s = irrigation_state_t()
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  if (d%status /= FMR_SCHEDULED_IRR_OK .or. abs(d%external_inflow_amount_cm-0.30_real64) >= tol) then
    write(*,'(A,I0,A,I0,A,ES24.16,A,L1,A,L1)') 'MC_IRR01_LIMIT_SALINITY_DIAGNOSTIC status=',d%status, &
      ' process_status=',d%process_status,' amount_cm=',d%external_inflow_amount_cm, &
      ' active=',c%active_event,' bound=',d%source_bound
  end if
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. abs(d%external_inflow_amount_cm-0.30_real64) < tol,21)
  call require(abs(q(3)-0.48_real64) < tol,22)

  p%depth_limit_enabled = .false.
  r%solute_enabled = .false.

  ! Sensor salinity excess increases the selected event depth before duration normalization.
  p%salinity_excess_enabled = .true.
  p%salinity_threshold = 8.0_real64
  p%salinity_excess_percent = 100.0_real64
  r%solute_enabled = .true.
  r%sensor_concentration = 9.0_real64
  r%t1 = r%t0 + 0.5_real64
  s = irrigation_state_t()
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. abs(d%external_inflow_amount_cm-0.24_real64) < tol,12)
  call require(abs(q(3)-0.48_real64) < tol,13)

  ! IRR_RATE=0 spreads the selected depth over one day for sensor scheduling too.
  p%salinity_excess_enabled = .false.
  r%solute_enabled = .false.
  p%irr_rate_cm_per_day = 0.0_real64
  r%t1 = r%t0 + 1.0_real64
  s = irrigation_state_t()
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. abs(q(3)-0.12_real64) < tol,14)
  call require(abs(d%external_inflow_amount_cm-0.12_real64) < tol,15)

  ! A configured rate implying >1 day is raised to depth/day and preserves depth.
  p%irr_rate_cm_per_day = 0.06_real64
  s = irrigation_state_t()
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. abs(q(3)-0.12_real64) < tol,16)
  call require(abs(d%external_inflow_amount_cm-0.12_real64) < tol,17)

  ! The normalized rate is persistent candidate event state and survives continuation.
  p%irr_rate_cm_per_day = 0.0_real64
  r%t1 = r%t0 + 0.5_real64
  s = irrigation_state_t()
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. c%active_event .and. abs(q(3)-0.12_real64) < tol,18)
  call export_fmr_irrigation_event_restart(c,restart_record,restart_status)
  call require(restart_status == FMR_IRR_MGMT_RESTART_OK,25)
  call restore_fmr_irrigation_event_restart(restart_record,s,restart_status)
  call require(restart_status == FMR_IRR_MGMT_RESTART_OK .and. s%active_event,26)
  r = scheduled_irrigation_request_t()
  r%t0 = 2600.875_real64
  r%t1 = 2601.375_real64
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. .not. c%active_event .and. abs(q(3)-0.12_real64) < tol,19)
  call require(abs(d%external_inflow_amount_cm-0.06_real64) < tol,20)

  ! Literal TASK=4 availability: positive configured rate scales both rate and event duration.
  p%irr_rate_cm_per_day = 0.48_real64
  r = scheduled_irrigation_request_t()
  r%t0 = 2700.0_real64
  r%t1 = 2700.125_real64
  r%dvs = 1.0_real64
  r%selection_opportunity = .true.; r%irrigation_enabled = .true.; r%schedule_enabled = .true.
  r%crop_emerged = .true.; r%irrigation_window_open = .true.
  r%availability_scaling_enabled = .true.; r%availability_fraction = 0.5_real64
  s = irrigation_state_t()
  h%water_content(2) = 0.20_real64
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. c%active_event,21)
  call require(abs(q(3)-0.24_real64) < tol .and. abs(d%external_inflow_amount_cm-0.03_real64) < tol,22)

  ! Zero-rate fallback keeps the one-day duration and scales only the generated rate.
  p%irr_rate_cm_per_day = 0.0_real64
  r%t0 = 2800.0_real64
  r%t1 = 2801.0_real64
  r%availability_fraction = 0.5_real64
  s = irrigation_state_t()
  call fmr_apply_scheduled_tcs8_dcs2_single_node_ssdi(p,s,r,h,c,q,d)
  call require(d%status == FMR_SCHEDULED_IRR_OK .and. .not.c%active_event,23)
  call require(abs(q(3)-0.06_real64) < tol .and. abs(d%external_inflow_amount_cm-0.06_real64) < tol,24)

  print '(A)','MC_IRR01_AVAIL_SENSOR_POLICY=PASS'
  print '(A)','MC_IRR01_TCS7_RUNTIME_BINDING=PASS'
  print '(A)','MC_IRR01_TCS8_RUNTIME_BINDING=PASS'
  print '(A)','MC_IRR01_SENSOR_DCSLIM_BEFORE_SALINITY=PASS'
  print '(A)','MC_IRR01_SENSOR_SALINITY_EXCESS=PASS'
  print '(A)','MC_IRR01_SENSOR_RATE_NORMALIZATION=PASS'
  print '(A)','MC_IRR01_RESTRICTED_SINGLE_NODE_SSDI_BINDING=PASS'
  print '(A)','MC_IRR01_TCS7_RETRY_FAIL_CLOSED=PASS'
  print '(A)','MC_IRR01_SENSOR_EVENT_RESTART=PASS'

contains
  subroutine require(ok,n)
    logical, intent(in) :: ok
    integer, intent(in) :: n
    if (.not. ok) then
      write(*,'(A,I0)') 'MC_IRR01_TCS7_BIND_FAIL=',n
      error stop 1
    end if
  end subroutine require
end program test_mc_irr01_scheduled_tcs7_ssdi_runtime_binding

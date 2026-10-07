program test_mc_irr01_scheduled_tcs7_ssdi_runtime_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, irrigation_state_t
  use mod_fmr_scheduled_irrigation_application
  implicit none

  type(scheduled_irrigation_parameters_t) :: p
  type(scheduled_irrigation_request_t) :: r
  type(irrigation_state_t) :: s, c
  type(process_hydraulic_view_t) :: h
  type(fmr_scheduled_irrigation_application_diagnostics_t) :: d
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
  call require(abs(q(3)-0.48_real64) < tol .and. sum(abs(q([1,2,4]))) == 0.0_real64,3)
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

  print '(A)','MC_IRR01_TCS7_RUNTIME_BINDING=PASS'
  print '(A)','MC_IRR01_RESTRICTED_SINGLE_NODE_SSDI_BINDING=PASS'
  print '(A)','MC_IRR01_TCS7_RETRY_FAIL_CLOSED=PASS'

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

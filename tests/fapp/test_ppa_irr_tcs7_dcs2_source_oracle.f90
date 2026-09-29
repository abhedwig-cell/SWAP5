program test_ppa_irr_tcs7_dcs2_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64), parameter :: eps = epsilon(1.0_real64)
  type(scheduled_irrigation_parameters_t) :: p
  type(irrigation_state_t) :: committed, candidate
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_flux_result_t) :: fluxes
  type(irrigation_diagnostics_t) :: diagnostics
  type(process_hydraulic_view_t) :: hydraulic
  real(real64) :: dvs, expected_threshold, expected_depth, head_offset, tol
  real(real64) :: source_tcs7(14), source_dcs2(14)
  integer(int64) :: random_state
  integer :: i, triggered_count, untriggered_count
  logical :: should_trigger

  p = scheduled_irrigation_parameters_t()
  p%scheduled_irrigation_enabled = .true.
  p%active_nodes = 1
  p%sensor_node = 1
  p%single_ssdi_node = 1
  p%irr_rate_cm_per_day = 2.0_real64
  p%tcs7_knot_count = 3
  p%tcs7_dvs(1:3) = [0.0_real64, 0.5_real64, 1.0_real64]
  p%tcs7_pressure_head(1:3) = [-100.0_real64, -500.0_real64, -1000.0_real64]
  p%dcs2_knot_count = 3
  p%dcs2_dvs(1:3) = [0.0_real64, 0.5_real64, 1.0_real64]
  p%dcs2_depth_cm(1:3) = [0.15_real64, 0.25_real64, 0.35_real64]

  allocate(hydraulic%pressure_head(1), hydraulic%water_content(1))
  hydraulic%active_nodes = 1
  hydraulic%water_content = 0.25_real64
  committed = irrigation_state_t()

  call make_source_table(p%tcs7_dvs, p%tcs7_pressure_head, p%tcs7_knot_count, source_tcs7)
  call make_source_table(p%dcs2_dvs, 10.0_real64*p%dcs2_depth_cm, p%dcs2_knot_count, source_dcs2)

  ! Exact source branch equality: TCS7 triggers when h equals the threshold.
  request = make_request(1.0_real64, 1.125_real64)
  request%dvs = 0.5_real64
  hydraulic%pressure_head(1) = -500.0_real64
  call evaluate_scheduled_irrigation_interval(p, committed, request, hydraulic, candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered, 1)
  call require(abs(diagnostics%interpolated_depth - 0.25_real64) <= 4.0_real64*eps, 2)

  ! Both AFGEN tables clamp to the first populated value below their first knot.
  request = make_request(0.0_real64, 0.075_real64)
  request%dvs = -0.25_real64
  hydraulic%pressure_head(1) = -100.0_real64
  call evaluate_scheduled_irrigation_interval(p, committed, request, hydraulic, candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered, 3)
  call require(abs(diagnostics%interpolated_threshold + 100.0_real64) <= 4.0_real64*eps, 4)
  call require(abs(diagnostics%interpolated_depth - 0.15_real64) <= 4.0_real64*eps, 5)

  triggered_count = 0
  untriggered_count = 0
  random_state = 20260923_int64
  do i = 1, vector_count
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    if (modulo(i, 2) == 0) then
      dvs = 1.01_real64 + 0.98_real64 * &
            real(modulo(random_state, 1000000_int64), real64) / 1000000.0_real64
    else
      dvs = 0.001_real64 + 0.998_real64 * &
            real(modulo(random_state, 1000000_int64), real64) / 1000000.0_real64
    end if
    expected_threshold = source_afgen(source_tcs7, 14, dvs)
    expected_depth = 0.1_real64 * source_afgen(source_dcs2, 14, dvs)

    should_trigger = modulo(i, 2) == 0
    head_offset = 1.0e-4_real64
    if (should_trigger) then
      hydraulic%pressure_head(1) = expected_threshold - head_offset
    else
      hydraulic%pressure_head(1) = expected_threshold + head_offset
    end if

    request = make_request(1.0_real64, 2.0_real64)
    request%dvs = dvs
    if (should_trigger) request%t1 = request%t0 + expected_depth/p%irr_rate_cm_per_day

    call evaluate_scheduled_irrigation_interval(p, committed, request, hydraulic, candidate, fluxes, diagnostics)
    call require(diagnostics%status == IRRIGATION_OK, 10)
    tol = 16.0_real64*eps*max(1.0_real64, abs(expected_threshold))
    call require(abs(diagnostics%interpolated_threshold - expected_threshold) <= tol, 11)
    call require(diagnostics%triggered .eqv. should_trigger, 12)

    if (should_trigger) then
      triggered_count = triggered_count + 1
      tol = 16.0_real64*eps*max(1.0_real64, abs(expected_depth))
      call require(abs(diagnostics%interpolated_depth - expected_depth) <= tol, 13)
      call require(fluxes%applied .and. fluxes%event_started .and. fluxes%event_finished, 14)
      call require(allocated(fluxes%subsurface_source), 15)
      call require(abs(fluxes%subsurface_source(1) - p%irr_rate_cm_per_day) <= tol, 16)
      call require(abs(fluxes%external_inflow_amount - expected_depth) <= tol, 17)
      call require(.not. candidate%active_event, 18)
    else
      untriggered_count = untriggered_count + 1
      call require(.not. fluxes%applied .and. abs(diagnostics%interpolated_depth) <= tol, 19)
      call require(candidate%active_event .eqv. committed%active_event, 20)
    end if
  end do

  call require(triggered_count == vector_count/2 .and. untriggered_count == vector_count/2, 21)
  print '(A)', 'PPA_IRR_TCS7_DCS2_B111_AFGEN_100000=PASS'
  print '(A)', 'PPA_IRR_TCS7_DCS2_PARTIAL_TABLE_CLAMPS_AND_INTERPOLATION=PASS'
  print '(A)', 'PPA_IRR_TCS7_THRESHOLD_EQUALITY_AND_EVENT_AMOUNT=PASS'
  print '(A)', 'PPA_IRR_TCS7_DCS2_SOURCE_ORACLE=PASS'

contains

  function make_request(t0, t1) result(r)
    real(real64), intent(in) :: t0, t1
    type(scheduled_irrigation_request_t) :: r
    r = scheduled_irrigation_request_t()
    r%t0 = t0
    r%t1 = t1
    r%selection_opportunity = .true.
    r%irrigation_enabled = .true.
    r%schedule_enabled = .true.
    r%crop_emerged = .true.
    r%irrigation_window_open = .true.
  end function make_request

  subroutine make_source_table(knots, values, knot_count, table)
    real(real64), intent(in) :: knots(IRRIGATION_MAX_SCHEDULED_KNOTS)
    real(real64), intent(in) :: values(IRRIGATION_MAX_SCHEDULED_KNOTS)
    integer, intent(in) :: knot_count
    real(real64), intent(out) :: table(14)
    integer :: j
    table = 0.0_real64
    do j = 1, knot_count
      table(2*j-1) = knots(j)
      table(2*j) = values(j)
    end do
    if (knot_count < IRRIGATION_MAX_SCHEDULED_KNOTS) then
      table(2*knot_count+1) = knots(knot_count) - 1.0_real64
      table(2*knot_count+2) = values(knot_count)
    end if
  end subroutine make_source_table

  real(real64) function source_afgen(table, table_length, x) result(y)
    integer, intent(in) :: table_length
    real(real64), intent(in) :: table(table_length), x
    real(real64) :: slope
    integer :: j

    if (table(1) >= x) then
      y = table(2)
      return
    end if
    do j = 3, table_length-1, 2
      if (table(j) >= x) then
        slope = (table(j+1)-table(j-1))/(table(j)-table(j-2))
        y = table(j-1) + (x-table(j-2))*slope
        return
      end if
      if (table(j) < table(j-2)) then
        y = table(j-1)
        return
      end if
    end do
    y = table(table_length)
  end function source_afgen

  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_IRR_TCS7_DCS2_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_tcs7_dcs2_source_oracle

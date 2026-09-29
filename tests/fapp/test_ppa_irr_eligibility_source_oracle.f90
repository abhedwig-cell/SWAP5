program test_ppa_irr_eligibility_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process
  implicit none

  integer, parameter :: vector_count = 100000
  type(scheduled_irrigation_parameters_t) :: parameters
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_state_t) :: committed, candidate
  type(irrigation_flux_result_t) :: fluxes
  type(irrigation_diagnostics_t) :: diagnostics
  type(process_hydraulic_view_t) :: hydraulic_view
  integer(int64) :: random_state
  integer :: i, gate_word, eligible_count, blocked_count
  logical :: expected_eligible

  parameters%scheduled_irrigation_enabled = .true.
  parameters%timing_criterion = IRRIGATION_TIMING_TCS7_PRESSURE_HEAD
  parameters%active_nodes = 1
  parameters%sensor_node = 1
  parameters%single_ssdi_node = 1
  parameters%irr_rate_cm_per_day = 0.5_real64
  parameters%tcs7_knot_count = 2
  parameters%tcs7_dvs(1:2) = [0.0_real64, 2.0_real64]
  parameters%tcs7_pressure_head(1:2) = [0.5_real64, 0.5_real64]
  parameters%dcs2_knot_count = 2
  parameters%dcs2_dvs(1:2) = [0.0_real64, 2.0_real64]
  parameters%dcs2_depth_cm(1:2) = [0.2_real64, 0.2_real64]
  hydraulic_view%active_nodes = 1
  allocate(hydraulic_view%pressure_head(1), hydraulic_view%water_content(1))
  hydraulic_view%pressure_head = -1.0_real64
  hydraulic_view%water_content = 0.2_real64
  committed = irrigation_state_t()

  random_state = 20260923_int64
  eligible_count = 0
  blocked_count = 0
  do i = 1, vector_count
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    gate_word = int(modulo(random_state, 128_int64))
    parameters%scheduled_irrigation_enabled = btest(gate_word, 0)
    request%selection_opportunity = btest(gate_word, 1)
    request%irrigation_enabled = btest(gate_word, 2)
    request%schedule_enabled = btest(gate_word, 3)
    request%crop_emerged = btest(gate_word, 4)
    request%irrigation_window_open = btest(gate_word, 5)
    request%fixed_event_already_selected = btest(gate_word, 6)
    request%t0 = 0.0_real64
    request%t1 = 0.1_real64
    request%dvs = 0.0_real64

    expected_eligible = parameters%scheduled_irrigation_enabled .and. request%selection_opportunity .and. &
                        request%irrigation_enabled .and. request%schedule_enabled .and. request%crop_emerged .and. &
                        request%irrigation_window_open .and. .not. request%fixed_event_already_selected
    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%selection_evaluated .eqv. expected_eligible, 1)
    call require(fluxes%applied .eqv. expected_eligible, 2)
    call require(candidate%active_event .eqv. expected_eligible, 3)
    if (expected_eligible) then
      eligible_count = eligible_count+1
      call require(diagnostics%triggered .and. fluxes%event_started .and. fluxes%event_remains_active, 4)
      call require(abs(fluxes%event_duration-0.4_real64) <= 4.0_real64*epsilon(0.4_real64), 5)
      call require(abs(fluxes%external_inflow_amount-0.05_real64) <= 4.0_real64*epsilon(0.05_real64), 6)
    else
      blocked_count = blocked_count+1
      call require(diagnostics%status == IRRIGATION_OK, 7)
    end if
  end do
  call require(eligible_count > 0 .and. blocked_count > 0, 8)

  print '(A)', 'PPA_IRR_TYPED_SCHEDULE_ELIGIBILITY_100000=PASS'
  print '(A)', 'PPA_IRR_FIXED_EVENT_PRECEDENCE_GATE=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_EVENT_ONLY_ON_ALL_GATES=PASS'
  print '(A)', 'PPA_IRR_ELIGIBILITY_SOURCE_ORACLE=PASS'

contains

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_ELIGIBILITY_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_eligibility_source_oracle

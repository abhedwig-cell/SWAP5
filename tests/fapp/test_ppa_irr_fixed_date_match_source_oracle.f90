program test_ppa_irr_fixed_date_match_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_irrigation_process
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64), parameter :: match_tolerance = 1.0e-3_real64
  type(irrigation_parameters_t) :: parameters
  type(irrigation_state_t) :: committed, candidate
  type(irrigation_management_request_t) :: request
  type(irrigation_flux_result_t) :: fluxes
  type(irrigation_diagnostics_t) :: diagnostics
  real(real64) :: delta, date, offset, expected_amount
  integer(int64) :: random_state
  integer :: i, matched_count, missed_count
  logical :: expected_match

  parameters%fixed_irrigation_enabled = .true.
  allocate(parameters%fixed_events(1))
  parameters%fixed_events(1)%application_type = IRRIGATION_APPLICATION_SPRINKLER
  parameters%fixed_events(1)%depth = 0.1_real64
  parameters%fixed_events(1)%rate = 1.0_real64
  parameters%fixed_events(1)%concentration = 0.0_real64
  committed = irrigation_state_t()

  ! Exact source boundary is strict: equality to 1e-3 day is not a match.
  call run_case(0.0_real64, match_tolerance, .false., 1)
  call run_case(0.0_real64, -match_tolerance, .false., 2)
  call run_case(0.0_real64, nearest(match_tolerance, -1.0_real64), .true., 3)
  call run_case(0.0_real64, nearest(-match_tolerance, 1.0_real64), .true., 4)

  random_state = 20260923_int64
  matched_count = 0
  missed_count = 0
  do i = 1, vector_count
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    offset = real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    delta = -1.5e-3_real64 + 3.0e-3_real64*offset
    date = 100.0_real64 + delta
    expected_match = abs(date-100.0_real64) < match_tolerance
    call run_case(100.0_real64, delta, expected_match, 10)
    if (expected_match) then
      matched_count = matched_count + 1
    else
      missed_count = missed_count + 1
    end if
  end do
  call require(matched_count > 0 .and. missed_count > 0, 20)

  print '(A)', 'PPA_IRR_FIXED_DATE_MATCH_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_FIXED_DATE_STRICT_1E3_DAY_BOUNDARY=PASS'
  print '(A)', 'PPA_IRR_FIXED_EVENT_APPLICATION_AND_INDEX_ADVANCE=PASS'
  print '(A)', 'PPA_IRR_FIXED_DATE_MATCH_SOURCE_ORACLE=PASS'

contains

  subroutine run_case(current_time, time_offset, source_match, code)
    real(real64), intent(in) :: current_time, time_offset
    logical, intent(in) :: source_match
    integer, intent(in) :: code
    integer :: expected_index

    parameters%fixed_events(1)%event_time = current_time + time_offset
    request%t0 = current_time
    request%t1 = current_time + parameters%fixed_events(1)%depth/parameters%fixed_events(1)%rate
    expected_amount = parameters%fixed_events(1)%rate * (request%t1-request%t0)
    call evaluate_fixed_irrigation_interval(parameters, committed, request, candidate, fluxes, diagnostics)
    call require(diagnostics%status == IRRIGATION_OK, 30+code)
    call require(diagnostics%event_match .eqv. source_match, 40+code)
    call require(fluxes%applied .eqv. source_match, 50+code)
    expected_index = 1
    if (source_match) expected_index = 2
    call require(candidate%next_fixed_event_index == expected_index, 60+code)
    if (source_match) then
      call require(fluxes%event_started .and. fluxes%event_finished, 70+code)
      call require(abs(fluxes%external_inflow_amount-expected_amount) <= 4.0_real64*epsilon(expected_amount), 80+code)
    end if
  end subroutine run_case

  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_IRR_FIXED_DATE_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_fixed_date_match_source_oracle

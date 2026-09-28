program test_ppa_irr_fixed_split_retry
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_irrigation_process
  implicit none

  integer, parameter :: vector_count = 100000
  type(irrigation_parameters_t) :: parameters
  type(irrigation_state_t) :: committed, split_candidate, retry_candidate, direct_candidate
  type(irrigation_flux_result_t) :: split_fluxes, retry_fluxes, direct_fluxes
  type(irrigation_diagnostics_t) :: split_diagnostics, retry_diagnostics, direct_diagnostics
  type(irrigation_management_request_t) :: request
  real(real64) :: rate, duration, depth, start_time, unit_value, event_end
  integer(int64) :: random_state
  integer :: i

  parameters%fixed_irrigation_enabled = .true.
  allocate(parameters%fixed_events(1))
  parameters%fixed_events(1)%application_type = IRRIGATION_APPLICATION_SURFACE
  parameters%fixed_events(1)%concentration = 1.25_real64
  committed = irrigation_state_t()
  random_state = 20260923_int64

  do i = 1, vector_count
    call random_unit(random_state, unit_value)
    start_time = 4000.0_real64*unit_value
    call random_unit(random_state, unit_value)
    rate = 0.1_real64 + 2.0_real64*unit_value
    call random_unit(random_state, unit_value)
    duration = 0.001_real64 + 0.998_real64*unit_value
    depth = rate*duration
    parameters%fixed_events(1)%event_time = start_time
    parameters%fixed_events(1)%depth = depth
    parameters%fixed_events(1)%rate = rate
    request%t0 = start_time
    request%t1 = start_time + depth/rate + 0.025_real64
    event_end = start_time + depth/rate

    call evaluate_fixed_irrigation_interval(parameters, committed, request, split_candidate, &
                                            split_fluxes, split_diagnostics)
    call require(split_diagnostics%status == IRRIGATION_SPLIT_REQUIRED, 1)
    call require(split_diagnostics%split_required .and. same_bits(split_diagnostics%split_time, event_end), 2)
    call require(split_candidate%next_fixed_event_index == committed%next_fixed_event_index .and. &
                 .not. split_candidate%active_event, 3)
    call require(.not. split_fluxes%applied .and. abs(split_fluxes%external_inflow_amount) <= 0.0_real64, 4)

    request%t1 = event_end
    call evaluate_fixed_irrigation_interval(parameters, committed, request, retry_candidate, &
                                            retry_fluxes, retry_diagnostics)
    call require(retry_diagnostics%status == IRRIGATION_OK .and. retry_fluxes%event_started .and. &
                 retry_fluxes%event_finished .and. .not. retry_candidate%active_event, 5)

    call evaluate_fixed_irrigation_interval(parameters, committed, request, direct_candidate, &
                                            direct_fluxes, direct_diagnostics)
    call require(direct_diagnostics%status == IRRIGATION_OK, 6)
    call require(retry_candidate%next_fixed_event_index == direct_candidate%next_fixed_event_index, 7)
    call require(retry_candidate%active_event .eqv. direct_candidate%active_event, 8)
    call require(same_bits(retry_fluxes%surface_gross_rate, direct_fluxes%surface_gross_rate), 9)
    call require(same_bits(retry_fluxes%event_duration, direct_fluxes%event_duration), 10)
    call require(same_bits(retry_fluxes%active_duration, direct_fluxes%active_duration), 11)
    call require(same_bits(retry_fluxes%external_inflow_amount, direct_fluxes%external_inflow_amount), 12)
  end do

  print '(A)', 'PPA_IRR_FIXED_OVERSIZED_INTERVAL_SPLIT_100000=PASS'
  print '(A)', 'PPA_IRR_FIXED_RETRY_EQUALS_DIRECT_EVENT_INTERVAL=PASS'
  print '(A)', 'PPA_IRR_FIXED_SPLIT_PRESERVES_CANDIDATE_ON_REQUEST=PASS'
  print '(A)', 'PPA_IRR_FIXED_SPLIT_RETRY=PASS'

contains

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_FIXED_SPLIT_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_fixed_split_retry

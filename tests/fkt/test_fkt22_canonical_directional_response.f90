module fkt22_test_support
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_physical_model_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t, canonical_directional_response_request_t, canonical_directional_response_t
  implicit none

  type, extends(transaction_state_t) :: probe_state_t
    real(real64) :: value = 0.0_real64
  contains
    procedure :: clone => probe_clone
  end type probe_state_t

  type, extends(canonical_forcing_t) :: probe_forcing_t
  end type probe_forcing_t

  type, extends(canonical_physical_model_t) :: probe_model_t
    integer :: begin_calls = 0
    integer :: finish_calls = 0
    logical :: response_active = .false.
    integer :: response_control = 0
  contains
    procedure :: advance => probe_advance
    procedure :: storage => probe_storage
    procedure :: temporal_error => probe_temporal_error
    procedure :: storage_accounting_status => probe_storage_status
    procedure :: prepare_interval => probe_prepare_interval
    procedure :: begin_directional_response => probe_begin_directional_response
    procedure :: finish_directional_response => probe_finish_directional_response
  end type probe_model_t

contains

  subroutine probe_clone(self, copy)
    class(probe_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(probe_state_t :: copy)
    select type (target => copy)
    type is (probe_state_t)
      target%value = self%value
    end select
  end subroutine probe_clone

  subroutine probe_advance(self, state, t0, t1, outcome)
    class(probe_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    outcome = trial_outcome_t()
    dt = t1-t0
    select type (typed => state)
    type is (probe_state_t)
      typed%value = typed%value + dt
    class default
      error stop 'F-KT22 probe: unexpected state'
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
    outcome%bottom_interface_exchange_available = .true.
    outcome%bottom_outward_exchange_native = dt
    outcome%terminal_bottom_outward_flux_native = 1.0_real64
    if (.not. same_type_as(self, self)) error stop 'unreachable probe model'
  end subroutine probe_advance

  real(real64) function probe_storage(self, state) result(value)
    class(probe_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    value = 0.0_real64
    select type (typed => state)
    type is (probe_state_t)
      value = typed%value
    class default
      error stop 'F-KT22 probe: unexpected storage state'
    end select
    if (.not. same_type_as(self, self)) error stop 'unreachable probe model'
  end function probe_storage

  real(real64) function probe_temporal_error(self, full_state, half_state) result(value)
    class(probe_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    value = 0.0_real64
    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, full_state) .or. &
        .not. same_type_as(half_state, half_state)) error stop 'unreachable probe temporal error'
  end function probe_temporal_error

  subroutine probe_storage_status(self, state, complete, missing_mask)
    class(probe_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) &
      error stop 'unreachable probe storage status'
  end subroutine probe_storage_status

  subroutine probe_prepare_interval(self, forcing, interval, config)
    class(probe_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self, self) .or. .not. same_type_as(forcing, forcing) .or. &
        interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
      error stop 'F-KT22 probe: invalid prepare'
  end subroutine probe_prepare_interval

  subroutine probe_begin_directional_response(self, request, interval, active)
    class(probe_model_t), intent(inout) :: self
    type(canonical_directional_response_request_t), intent(in) :: request
    type(canonical_interval_t), intent(in) :: interval
    logical, intent(out) :: active
    self%begin_calls = self%begin_calls + 1
    active = request%requested .and. request%control_coordinate > 0 .and. interval%t1 > interval%t0
    self%response_active = active
    self%response_control = request%control_coordinate
  end subroutine probe_begin_directional_response

  subroutine probe_finish_directional_response(self, interval, completed, response)
    class(probe_model_t), intent(inout) :: self
    type(canonical_interval_t), intent(in) :: interval
    logical, intent(in) :: completed
    type(canonical_directional_response_t), intent(out) :: response
    self%finish_calls = self%finish_calls + 1
    response = canonical_directional_response_t()
    response%requested = .true.
    response%control_coordinate = self%response_control
    response%origin_t0 = interval%t0
    response%accepted_t1 = interval%t0
    response%method = 'probe-chain-rule'
    response%route = 'canonical-not-completed'
    if (completed .and. self%response_active) then
      response%available = .true.
      response%accepted_steps = 2
      response%accepted_t1 = interval%t1
      response%accepted_bottom_exchange_derivative = 2.0_real64*(interval%t1-interval%t0)
      response%route = 'whole-window'
    end if
    self%response_active = .false.
  end subroutine probe_finish_directional_response

end module fkt22_test_support

program test_fkt22_canonical_directional_response
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t, canonical_result_t, &
       canonical_directional_response_request_t
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use fkt22_test_support, only: probe_state_t, probe_forcing_t, probe_model_t
  implicit none

  class(transaction_state_t), allocatable :: committed
  type(probe_state_t) :: initial
  type(probe_forcing_t) :: forcing
  type(probe_model_t) :: model
  type(canonical_interval_t) :: interval
  type(canonical_numerical_config_t) :: config
  type(canonical_result_t) :: result
  type(canonical_directional_response_request_t) :: request

  initial%value = 0.0_real64
  call initial%clone(committed)
  interval%t0 = 0.0_real64
  interval%t1 = 1.0_real64
  config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  config%transaction%temporal_tolerance = 1.0_real64
  config%transaction%mass_tolerance = 1.0e-12_real64
  config%transaction%max_retries = 0
  config%max_committed_substeps = 4
  request%requested = .true.
  request%control_coordinate = 5

  call run_canonical_interval(model, committed, forcing, interval, config, result, &
       target_selector=half_window_selector, directional_request=request)

  call assert_true(result%completed, 'physical canonical interval completed')
  call assert_true(result%mass%accepted_transaction_count == 2, 'two canonical transactions accepted')
  call assert_true(model%begin_calls == 1 .and. model%finish_calls == 1, 'one outer lifecycle')
  call assert_true(result%directional_response%requested, 'response request preserved')
  call assert_true(result%directional_response%available, 'whole-window response available')
  call assert_true(result%directional_response%origin_t0 == 0.0_real64 .and. &
       result%directional_response%accepted_t1 == 1.0_real64, 'whole-window provenance')
  call assert_true(abs(result%directional_response%accepted_bottom_exchange_derivative-2.0_real64) < 1.0e-14_real64, &
       'whole-window derivative carried')

  deallocate(committed)
  call initial%clone(committed)
  call run_canonical_interval(model, committed, forcing, interval, config, result, &
       target_selector=failing_second_selector, directional_request=request)
  call assert_true(.not. result%completed, 'failed canonical interval remains uncommitted')
  call assert_true(.not. result%directional_response%available, 'failed window publishes no response')
  call assert_true(model%begin_calls == 2 .and. model%finish_calls == 2, 'failure path cleans lifecycle')

  print '(A)', 'FKT22_CANONICAL_DIRECTIONAL_RESPONSE PASS'
  print '(A)', 'FKT22_MULTI_TRANSACTION_WHOLE_WINDOW=PASS'
  print '(A)', 'FKT22_FAILURE_NO_PUBLICATION=PASS'
  print '(A)', 'FKT22_OUTER_LIFECYCLE_ONCE=PASS'

contains

  subroutine half_window_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = min(cursor + 0.5_real64, requested_t1)
    max_retries_cap = 0
    valid = .true.
  end subroutine half_window_selector

  subroutine failing_second_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = min(cursor + 0.5_real64, requested_t1)
    max_retries_cap = 0
    valid = cursor < 0.25_real64
  end subroutine failing_second_selector

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'ASSERTION FAILED:', trim(label)
      error stop 1
    end if
  end subroutine assert_true

end program test_fkt22_canonical_directional_response

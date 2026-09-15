module test_fkt22_canonical_trajectory_fixture
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t, canonical_physical_model_t
  implicit none

  type, extends(canonical_state_t) :: test_state_t
    real(real64) :: storage_value = 0.0_real64
  contains
    procedure :: clone => clone_test_state
  end type test_state_t

  type, extends(canonical_forcing_t) :: test_forcing_t
  end type test_forcing_t

  type, extends(canonical_physical_model_t) :: test_model_t
    logical :: trajectory_requested = .false.
    real(real64) :: requested_t0 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
  contains
    procedure :: prepare_interval => prepare_test_interval
    procedure :: advance => advance_test_model
    procedure :: storage => storage_test_model
    procedure :: temporal_error => temporal_error_test_model
    procedure :: accepted_trajectory_direction_snapshot => snapshot_test_trajectory
  end type test_model_t

contains

  subroutine make_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(test_state_t :: state)
    select type (typed => state)
    type is (test_state_t)
      typed%storage_value = value
    end select
  end subroutine make_state

  subroutine clone_test_state(self, copy)
    class(test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(test_state_t :: copy)
    select type (typed => copy)
    type is (test_state_t)
      typed%storage_value = self%storage_value
    end select
  end subroutine clone_test_state

  subroutine prepare_test_interval(self, forcing, interval, config)
    class(test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    self%trajectory_requested = config%accepted_trajectory_direction%requested
    self%requested_t0 = interval%t0
    self%requested_t1 = interval%t1
    if (.not. same_type_as(forcing, forcing)) error stop 'unreachable forcing type'
  end subroutine prepare_test_interval

  subroutine advance_test_model(self, state, t0, t1, outcome)
    class(test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt
    outcome = trial_outcome_t()
    dt = t1 - t0
    select type (typed => state)
    type is (test_state_t)
      typed%storage_value = typed%storage_value + dt
    class default
      return
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    if (.not. same_type_as(self, self)) error stop 'unreachable model type'
  end subroutine advance_test_model

  function storage_test_model(self, state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    value = huge(0.0_real64)
    select type (typed => state)
    type is (test_state_t)
      value = typed%storage_value
    end select
    if (.not. same_type_as(self, self)) error stop 'unreachable model type'
  end function storage_test_model

  function temporal_error_test_model(self, full_state, half_state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    value = 0.0_real64
    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, full_state) .or. &
        .not. same_type_as(half_state, half_state)) error stop 'unreachable temporal types'
  end function temporal_error_test_model

  subroutine snapshot_test_trajectory(self, interval, result)
    class(test_model_t), intent(inout) :: self
    type(canonical_interval_t), intent(in) :: interval
    type(accepted_trajectory_direction_result_t), intent(out) :: result
    result = accepted_trajectory_direction_result_t()
    if (.not. self%trajectory_requested) return
    result%requested = .true.
    result%available = .true.
    result%worker_id = 1
    result%generation = 1
    result%control_coordinate = 5
    result%accepted_steps = 3
    result%origin_t0 = self%requested_t0
    result%accepted_t1 = self%requested_t1
    result%accepted_bottom_exchange_derivative = 7.5_real64
    result%method = 'test-whole-window'
    result%route = 'accepted-trajectory'
    if (interval%t0 /= self%requested_t0 .or. interval%t1 /= self%requested_t1) then
      result = accepted_trajectory_direction_result_t()
    end if
  end subroutine snapshot_test_trajectory

  subroutine split_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = min(requested_t1, cursor + 0.4_real64)
    max_retries_cap = 2
    valid = .true.
  end subroutine split_selector

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      print '(A)', 'FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine assert_true

end module test_fkt22_canonical_trajectory_fixture

program test_fkt22_canonical_trajectory_exposure
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t, canonical_result_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_SUBSTEP_LIMIT
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use test_fkt22_canonical_trajectory_fixture, only: test_model_t, test_forcing_t, make_state, split_selector, assert_true
  implicit none

  class(transaction_state_t), allocatable :: committed
  type(test_model_t) :: model
  type(test_forcing_t) :: forcing
  type(canonical_interval_t) :: interval
  type(canonical_numerical_config_t) :: config
  type(canonical_result_t) :: result

  call make_state(committed, 0.0_real64)
  interval%t0 = 0.0_real64
  interval%t1 = 1.0_real64
  config%transaction%mass_tolerance = 1.0e-12_real64
  config%transaction%temporal_tolerance = 1.0e-12_real64
  config%transaction%max_retries = 2
  config%max_committed_substeps = 4
  config%accepted_trajectory_direction%requested = .true.
  config%accepted_trajectory_direction%control_coordinate = 5

  call run_canonical_interval(model, committed, forcing, interval, config, result, split_selector)
  call assert_true(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'completed split interval')
  call assert_true(result%mass%accepted_transaction_count == 3, 'three accepted canonical transactions')
  call assert_true(result%accepted_trajectory_direction%requested, 'trajectory requested published')
  call assert_true(result%accepted_trajectory_direction%available, 'trajectory available published')
  call assert_true(result%accepted_trajectory_direction%origin_t0 == interval%t0, 'whole-window origin preserved')
  call assert_true(result%accepted_trajectory_direction%accepted_t1 == interval%t1, 'whole-window endpoint preserved')
  call assert_true(result%accepted_trajectory_direction%accepted_bottom_exchange_derivative == 7.5_real64, &
       'dedicated trajectory result preserved')

  call make_state(committed, 0.0_real64)
  config%max_committed_substeps = 1
  call run_canonical_interval(model, committed, forcing, interval, config, result, split_selector)
  call assert_true(result%status == CANONICAL_STATUS_SUBSTEP_LIMIT .and. .not. result%completed, &
       'partial canonical interval rejected')
  call assert_true(.not. result%accepted_trajectory_direction%available, 'no partial-window trajectory publication')

  call make_state(committed, 0.0_real64)
  config%max_committed_substeps = 4
  config%accepted_trajectory_direction%requested = .false.
  call run_canonical_interval(model, committed, forcing, interval, config, result, split_selector)
  call assert_true(result%status == CANONICAL_STATUS_COMPLETED, 'default-off physical route completes')
  call assert_true(.not. result%accepted_trajectory_direction%requested .and. &
       .not. result%accepted_trajectory_direction%available, 'default-off trajectory remains absent')

  print '(A)', 'FKT22_CANONICAL_TRAJECTORY_EXPOSURE=PASS'
  print '(A)', 'FKT22_FCI66_SPLIT_WHOLE_WINDOW_PROVENANCE=PASS'
  print '(A)', 'FKT22_PARTIAL_WINDOW_NO_PUBLICATION=PASS'
  print '(A)', 'FKT22_DEFAULT_OFF_IDENTITY=PASS'

end program test_fkt22_canonical_trajectory_exposure

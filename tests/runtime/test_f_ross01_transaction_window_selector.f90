module mod_f_ross01_window_selector_test_types
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_physical_model_t, &
       canonical_interval_t, canonical_numerical_config_t
  implicit none

  type, extends(canonical_state_t) :: test_state_t
    real(real64) :: storage_value = 0.0_real64
  contains
    procedure :: clone => clone_test_state
  end type test_state_t

  type, extends(canonical_forcing_t) :: test_forcing_t
  end type test_forcing_t

  type, extends(canonical_physical_model_t) :: default_model_t
  contains
    procedure :: prepare_interval => prepare_test_interval
    procedure :: advance => advance_test_state
    procedure :: storage => test_storage
    procedure :: temporal_error => test_temporal_error
    procedure :: storage_accounting_status => test_storage_accounting_status
  end type default_model_t

  type, extends(default_model_t) :: selecting_model_t
    integer :: selector_mode = 1
  contains
    procedure :: select_transaction_window => select_test_transaction_window
  end type selecting_model_t

contains

  subroutine clone_test_state(self, copy)
    class(test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(test_state_t :: copy)
    select type (copy)
    type is (test_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine clone_test_state

  subroutine prepare_test_interval(self, forcing, interval, config)
    class(default_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self, self) .or. .not. same_type_as(forcing, forcing)) error stop 101
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 102
  end subroutine prepare_test_interval

  subroutine advance_test_state(self, state, t0, t1, outcome)
    class(default_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    if (.not. same_type_as(self, self)) error stop 103
    dt = t1 - t0
    select type (state)
    type is (test_state_t)
      state%storage_value = state%storage_value + dt
    class default
      error stop 104
    end select
    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
  end subroutine advance_test_state

  function test_storage(self, state) result(value)
    class(default_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (.not. same_type_as(self, self)) error stop 105
    select type (state)
    type is (test_state_t)
      value = state%storage_value
    class default
      error stop 106
    end select
  end function test_storage

  function test_temporal_error(self, full_state, half_state) result(value)
    class(default_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, full_state) .or. &
        .not. same_type_as(half_state, half_state)) error stop 107
    value = 0.0_real64
  end function test_temporal_error

  subroutine test_storage_accounting_status(self, state, complete, missing_mask)
    class(default_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) error stop 108
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine test_storage_accounting_status

  subroutine select_test_transaction_window(self, cursor, outer_t1, selected_t1)
    class(selecting_model_t), intent(inout) :: self
    real(real64), intent(in) :: cursor, outer_t1
    real(real64), intent(out) :: selected_t1

    select case (self%selector_mode)
    case (1)
      selected_t1 = min(cursor + 0.25_real64, outer_t1)
    case (2)
      selected_t1 = cursor
    case (3)
      selected_t1 = outer_t1 + 0.25_real64
    case default
      selected_t1 = outer_t1
    end select
  end subroutine select_test_transaction_window

end module mod_f_ross01_window_selector_test_types

program test_f_ross01_transaction_window_selector
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t, canonical_result_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_INVALID_REQUEST, CANONICAL_STATUS_NO_PROGRESS, &
       CANONICAL_STATUS_SUBSTEP_LIMIT
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_f_ross01_window_selector_test_types, only: test_state_t, test_forcing_t, default_model_t, selecting_model_t
  implicit none

  call test_default_outer_endpoint()
  call test_bounded_quarter_windows()
  call test_no_progress_fails_closed()
  call test_overshoot_fails_closed()
  call test_substep_limit_preserves_external_state()

  write(*,'(a)') 'F-ROSS01 transaction-window selector: PASS'

contains

  subroutine init_config(config, max_substeps)
    type(canonical_numerical_config_t), intent(out) :: config
    integer, intent(in) :: max_substeps
    config = canonical_numerical_config_t()
    config%max_committed_substeps = max_substeps
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%max_retries = 0
  end subroutine init_config

  subroutine init_state(committed)
    class(transaction_state_t), allocatable, intent(out) :: committed
    allocate(test_state_t :: committed)
  end subroutine init_state

  function committed_storage(committed) result(value)
    class(transaction_state_t), allocatable, intent(in) :: committed
    real(real64) :: value
    select type (committed)
    type is (test_state_t)
      value = committed%storage_value
    class default
      error stop 201
    end select
  end function committed_storage

  subroutine assert_close(actual, expected, code)
    real(real64), intent(in) :: actual, expected
    integer, intent(in) :: code
    if (abs(actual - expected) > 1.0e-13_real64) error stop code
  end subroutine assert_close

  subroutine test_default_outer_endpoint()
    type(default_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    call init_state(committed)
    call init_config(config, 8)
    interval = canonical_interval_t(0.0_real64, 1.0_real64)
    call run_canonical_interval(model, committed, forcing, interval, config, result)
    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 211
    if (result%diagnostics%transaction_calls /= 1 .or. result%diagnostics%external_commits /= 1) error stop 212
    if (result%mass%accepted_transaction_count /= 1 .or. .not. result%mass%complete) error stop 213
    call assert_close(committed_storage(committed), 1.0_real64, 214)
    call assert_close(result%mass%residual, 0.0_real64, 215)
  end subroutine test_default_outer_endpoint

  subroutine test_bounded_quarter_windows()
    type(selecting_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    model%selector_mode = 1
    call init_state(committed)
    call init_config(config, 8)
    interval = canonical_interval_t(0.0_real64, 1.0_real64)
    call run_canonical_interval(model, committed, forcing, interval, config, result)
    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 221
    if (result%diagnostics%transaction_calls /= 4 .or. result%diagnostics%committed_substeps /= 4) error stop 222
    if (result%diagnostics%external_commits /= 1 .or. result%mass%accepted_transaction_count /= 4) error stop 223
    if (.not. result%mass%complete) error stop 224
    call assert_close(committed_storage(committed), 1.0_real64, 225)
    call assert_close(result%mass%residual, 0.0_real64, 226)
  end subroutine test_bounded_quarter_windows

  subroutine test_no_progress_fails_closed()
    type(selecting_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    model%selector_mode = 2
    call init_state(committed)
    call init_config(config, 8)
    interval = canonical_interval_t(0.0_real64, 1.0_real64)
    call run_canonical_interval(model, committed, forcing, interval, config, result)
    if (result%status /= CANONICAL_STATUS_NO_PROGRESS) error stop 231
    if (result%diagnostics%transaction_calls /= 0 .or. result%diagnostics%external_commits /= 0) error stop 232
    call assert_close(committed_storage(committed), 0.0_real64, 233)
  end subroutine test_no_progress_fails_closed

  subroutine test_overshoot_fails_closed()
    type(selecting_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    model%selector_mode = 3
    call init_state(committed)
    call init_config(config, 8)
    interval = canonical_interval_t(0.0_real64, 1.0_real64)
    call run_canonical_interval(model, committed, forcing, interval, config, result)
    if (result%status /= CANONICAL_STATUS_INVALID_REQUEST) error stop 241
    if (result%diagnostics%transaction_calls /= 0 .or. result%diagnostics%external_commits /= 0) error stop 242
    call assert_close(committed_storage(committed), 0.0_real64, 243)
  end subroutine test_overshoot_fails_closed

  subroutine test_substep_limit_preserves_external_state()
    type(selecting_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    model%selector_mode = 1
    call init_state(committed)
    call init_config(config, 3)
    interval = canonical_interval_t(0.0_real64, 1.0_real64)
    call run_canonical_interval(model, committed, forcing, interval, config, result)
    if (result%status /= CANONICAL_STATUS_SUBSTEP_LIMIT .or. result%completed) error stop 251
    if (result%diagnostics%transaction_calls /= 3 .or. result%diagnostics%external_commits /= 0) error stop 252
    call assert_close(result%completed_t, 0.75_real64, 253)
    call assert_close(committed_storage(committed), 0.0_real64, 254)
  end subroutine test_substep_limit_preserves_external_state

end program test_f_ross01_transaction_window_selector

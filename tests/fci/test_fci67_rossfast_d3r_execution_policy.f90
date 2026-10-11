module mod_fci67_rossfast_test_types
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t, canonical_physical_model_t
  use mod_rossfast_d3r_execution_policy, only: rossfast_d3r_full_duration_for_index
  implicit none
  private

  type, extends(canonical_state_t), public :: test_state_t
    real(real64) :: storage_value = 0.0_real64
  contains
    procedure :: clone => clone_state
  end type test_state_t

  type, extends(canonical_forcing_t), public :: test_forcing_t
  end type test_forcing_t

  type, extends(canonical_physical_model_t), public :: test_model_t
    logical :: reject_initial_above_level2 = .false.
    logical :: reject_all = .false.
    real(real64) :: outer_t0 = 0.0_real64
  contains
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: temporal_error => temporal_error
    procedure :: storage_accounting_status => storage_accounting_status
  end type test_model_t

contains

  subroutine clone_state(self, copy)
    class(test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(test_state_t :: copy)
    select type(copy)
    type is(test_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine clone_state

  subroutine prepare_interval(self, forcing, interval, config)
    class(test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    if (.not. same_type_as(forcing, forcing)) error stop 101
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 102
    self%outer_t0 = interval%t0
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, level2, origin_tol

    outcome = trial_outcome_t()
    dt = t1 - t0
    level2 = rossfast_d3r_full_duration_for_index(2)
    origin_tol = 4.0_real64 * max(spacing(t0), spacing(self%outer_t0))

    if (self%reject_all) then
      outcome%solver_ok = .false.
      return
    end if
    if (self%reject_initial_above_level2 .and. abs(t0 - self%outer_t0) <= origin_tol .and. &
        dt > level2 + 1.0e-15_real64) then
      outcome%solver_ok = .false.
      return
    end if

    select type(state)
    type is(test_state_t)
      state%storage_value = state%storage_value + dt
    class default
      error stop 103
    end select

    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
  end subroutine advance

  function storage(self, state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value

    if (.not. same_type_as(self, self)) error stop 104
    select type(state)
    type is(test_state_t)
      value = state%storage_value
    class default
      error stop 105
    end select
  end function storage

  function temporal_error(self, full_state, half_state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value

    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, full_state) .or. &
        .not. same_type_as(half_state, half_state)) error stop 106
    value = 0.0_real64
  end function temporal_error

  subroutine storage_accounting_status(self, state, complete, missing_mask)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) error stop 107
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine storage_accounting_status

end module mod_fci67_rossfast_test_types

program test_fci67_rossfast_d3r_execution_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t, canonical_result_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_INVALID_REQUEST, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       rossfast_d3r_full_duration_for_index, rossfast_d3r_select_transaction_window, &
       ROSSFAST_D3R_OUTER_HORIZON_DAY, ROSSFAST_D3R_RETRY_SCALE, ROSSFAST_D3R_MAX_FULL_INDEX, &
       ROSSFAST_D3R_HALF_ONLY_INDEX, ROSSFAST_D3R_MIN_FULL_DURATION_DAY
  use mod_fci67_rossfast_test_types, only: test_state_t, test_forcing_t, test_model_t
  implicit none

  call test_policy_and_selector_contract()
  call test_full_outer_interval()
  call test_level2_remainder_composition()
  call test_smallest_segment_failure_is_bounded()
  call test_off_grid_request_fails_before_transaction()
  call test_oversized_request_fails_before_transaction()

  write(*,'(a)') 'FCI67_ROSSFAST_D3R_EXECUTION_POLICY_GATE PASS'

contains

  subroutine init_config(config)
    type(canonical_numerical_config_t), intent(out) :: config

    config = canonical_numerical_config_t()
    config%max_committed_substeps = 32
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 1.0e-6_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    call apply_rossfast_d3r_retry_policy(config)
  end subroutine init_config

  subroutine init_state(committed)
    class(transaction_state_t), allocatable, intent(out) :: committed
    allocate(test_state_t :: committed)
  end subroutine init_state

  function committed_storage(committed) result(value)
    class(transaction_state_t), allocatable, intent(in) :: committed
    real(real64) :: value

    select type(committed)
    type is(test_state_t)
      value = committed%storage_value
    class default
      error stop 201
    end select
  end function committed_storage

  subroutine assert_close(actual, expected, tolerance, code)
    real(real64), intent(in) :: actual, expected, tolerance
    integer, intent(in) :: code
    if (abs(actual - expected) > tolerance) error stop code
  end subroutine assert_close

  subroutine test_policy_and_selector_contract()
    type(canonical_numerical_config_t) :: config
    real(real64) :: target
    integer :: cap
    logical :: valid

    call init_config(config)
    call assert_close(config%transaction%retry_scale, ROSSFAST_D3R_RETRY_SCALE, 0.0_real64, 211)
    if (config%transaction%max_retries /= ROSSFAST_D3R_MAX_FULL_INDEX) error stop 212
    if (ROSSFAST_D3R_HALF_ONLY_INDEX /= 9) error stop 213
    call assert_close(rossfast_d3r_full_duration_for_index(0), 0.0016_real64, 1.0e-16_real64, 214)
    call assert_close(rossfast_d3r_full_duration_for_index(8), 0.00000625_real64, 1.0e-18_real64, 215)
    call assert_close(rossfast_d3r_full_duration_for_index(9), 0.0_real64, 0.0_real64, 216)

    call rossfast_d3r_select_transaction_window(0.0_real64, 0.0016_real64, target, cap, valid)
    if (.not. valid .or. cap /= 8) error stop 217
    call assert_close(target, 0.0016_real64, 1.0e-16_real64, 218)

    call rossfast_d3r_select_transaction_window(0.0004_real64, 0.0016_real64, target, cap, valid)
    if (.not. valid .or. cap /= 7) error stop 219
    call assert_close(target, 0.0012_real64, 1.0e-16_real64, 220)

    call rossfast_d3r_select_transaction_window(0.0012_real64, 0.0016_real64, target, cap, valid)
    if (.not. valid .or. cap /= 6) error stop 221
    call assert_close(target, 0.0016_real64, 1.0e-16_real64, 222)

    call rossfast_d3r_select_transaction_window(ROSSFAST_D3R_OUTER_HORIZON_DAY - &
         ROSSFAST_D3R_MIN_FULL_DURATION_DAY, ROSSFAST_D3R_OUTER_HORIZON_DAY, target, cap, valid)
    if (.not. valid .or. cap /= 0) error stop 223
    call assert_close(target, ROSSFAST_D3R_OUTER_HORIZON_DAY, 1.0e-16_real64, 224)

    call rossfast_d3r_select_transaction_window(0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY - &
         0.5_real64 * ROSSFAST_D3R_MIN_FULL_DURATION_DAY, target, cap, valid)
    if (valid) error stop 225

    call rossfast_d3r_select_transaction_window(0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY + &
         ROSSFAST_D3R_MIN_FULL_DURATION_DAY, target, cap, valid)
    if (valid) error stop 226
  end subroutine test_policy_and_selector_contract

  subroutine test_full_outer_interval()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    call init_state(committed)
    call init_config(config)
    interval = canonical_interval_t(5.0_real64, 5.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY)
    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 231
    if (result%diagnostics%transaction_calls /= 1) error stop 232
    if (result%mass%accepted_transaction_count /= 1) error stop 233
    if (result%diagnostics%external_commits /= 1) error stop 234
    if (.not. result%mass%complete) error stop 235
    call assert_close(committed_storage(committed), ROSSFAST_D3R_OUTER_HORIZON_DAY, 1.0e-13_real64, 236)
    call assert_close(result%mass%residual, 0.0_real64, 1.0e-13_real64, 237)
  end subroutine test_full_outer_interval

  subroutine test_level2_remainder_composition()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    model%reject_initial_above_level2 = .true.
    call init_state(committed)
    call init_config(config)
    interval = canonical_interval_t(7.0_real64, 7.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY)
    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 241
    if (result%diagnostics%transaction_calls /= 3) error stop 242
    if (result%mass%accepted_transaction_count /= 3) error stop 243
    if (result%diagnostics%retries /= 2 .or. result%diagnostics%solver_rejections /= 2) error stop 244
    if (result%diagnostics%external_commits /= 1) error stop 245
    if (.not. result%mass%complete) error stop 246
    call assert_close(result%diagnostics%min_accepted_substep_duration, &
         rossfast_d3r_full_duration_for_index(2), 1.0e-13_real64, 247)
    call assert_close(result%diagnostics%max_accepted_substep_duration, &
         rossfast_d3r_full_duration_for_index(1), 1.0e-13_real64, 248)
    call assert_close(committed_storage(committed), ROSSFAST_D3R_OUTER_HORIZON_DAY, 1.0e-13_real64, 249)
    call assert_close(result%mass%residual, 0.0_real64, 1.0e-13_real64, 250)
  end subroutine test_level2_remainder_composition

  subroutine test_smallest_segment_failure_is_bounded()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    model%reject_all = .true.
    call init_state(committed)
    call init_config(config)
    interval = canonical_interval_t(11.0_real64, 11.0_real64 + ROSSFAST_D3R_MIN_FULL_DURATION_DAY)
    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_TRANSACTION_FAILED) error stop 261
    if (result%diagnostics%transaction_calls /= 1) error stop 262
    if (result%diagnostics%attempts /= 1 .or. result%diagnostics%solver_rejections /= 1) error stop 263
    if (result%diagnostics%external_commits /= 0) error stop 264
    call assert_close(committed_storage(committed), 0.0_real64, 0.0_real64, 265)
  end subroutine test_smallest_segment_failure_is_bounded

  subroutine test_off_grid_request_fails_before_transaction()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    call init_state(committed)
    call init_config(config)
    interval = canonical_interval_t(13.0_real64, 13.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY - &
         0.5_real64 * ROSSFAST_D3R_MIN_FULL_DURATION_DAY)
    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_INVALID_REQUEST) error stop 271
    if (result%diagnostics%transaction_calls /= 0 .or. result%diagnostics%external_commits /= 0) error stop 272
    call assert_close(committed_storage(committed), 0.0_real64, 0.0_real64, 273)
  end subroutine test_off_grid_request_fails_before_transaction

  subroutine test_oversized_request_fails_before_transaction()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    call init_state(committed)
    call init_config(config)
    interval = canonical_interval_t(17.0_real64, 17.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY + &
         ROSSFAST_D3R_MIN_FULL_DURATION_DAY)
    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_INVALID_REQUEST) error stop 281
    if (result%diagnostics%transaction_calls /= 0 .or. result%diagnostics%external_commits /= 0) error stop 282
    call assert_close(committed_storage(committed), 0.0_real64, 0.0_real64, 283)
  end subroutine test_oversized_request_fails_before_transaction

end program test_fci67_rossfast_d3r_execution_policy

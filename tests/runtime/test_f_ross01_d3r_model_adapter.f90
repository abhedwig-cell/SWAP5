module mod_f_ross01_d3r_adapter_test_types
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_rossfast_d3r_model_adapter, only: rossfast_d3r_model_adapter_t
  implicit none

  type, extends(canonical_state_t) :: test_state_t
    real(real64) :: storage_value = 0.0_real64
  contains
    procedure :: clone => clone_state
  end type test_state_t

  type, extends(canonical_forcing_t) :: test_forcing_t
  end type test_forcing_t

  type, extends(rossfast_d3r_model_adapter_t) :: test_model_t
    logical :: reject_above_half_window = .false.
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
    select type (copy)
    type is (test_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine clone_state

  subroutine prepare_interval(self, forcing, interval, config)
    class(test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self, self) .or. .not. same_type_as(forcing, forcing)) error stop 101
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 102
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    dt = t1 - t0
    outcome = trial_outcome_t()
    if (self%reject_above_half_window .and. dt > 0.0008_real64 + 1.0e-15_real64) then
      outcome%solver_ok = .false.
      return
    end if

    select type (state)
    type is (test_state_t)
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
    select type (state)
    type is (test_state_t)
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

end module mod_f_ross01_d3r_adapter_test_types

program test_f_ross01_d3r_model_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t, canonical_result_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_NO_PROGRESS
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_rossfast_d3r_model_adapter, only: apply_rossfast_d3r_retry_policy, &
       rossfast_d3r_duration_for_index, ROSSFAST_D3R_RETRY_SCALE, ROSSFAST_D3R_MAX_RETRIES
  use mod_f_ross01_d3r_adapter_test_types, only: test_state_t, test_forcing_t, test_model_t
  implicit none

  call test_policy_binding()
  call test_ladder_composition()
  call test_transaction_retry_composition()
  call test_unrepresentable_remainder_fails_closed()
  write(*,'(a)') 'F-ROSS01 production D3R model adapter: PASS'

contains

  subroutine init_config(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config = canonical_numerical_config_t()
    config%max_committed_substeps = 32
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
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

  subroutine test_policy_binding()
    type(canonical_numerical_config_t) :: config
    call init_config(config)
    call assert_close(config%transaction%retry_scale, ROSSFAST_D3R_RETRY_SCALE, 211)
    if (config%transaction%max_retries /= ROSSFAST_D3R_MAX_RETRIES) error stop 212
    call assert_close(rossfast_d3r_duration_for_index(0), 0.0016_real64, 213)
    call assert_close(rossfast_d3r_duration_for_index(1), 0.0008_real64, 214)
    call assert_close(rossfast_d3r_duration_for_index(9), 0.000003125_real64, 215)
    call assert_close(rossfast_d3r_duration_for_index(10), 0.0_real64, 216)
  end subroutine test_policy_binding

  subroutine test_ladder_composition()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    call init_state(committed)
    call init_config(config)
    interval = canonical_interval_t(0.0_real64, 0.004_real64)
    call run_canonical_interval(model, committed, forcing, interval, config, result)
    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 221
    if (result%diagnostics%transaction_calls /= 3 .or. result%mass%accepted_transaction_count /= 3) error stop 222
    if (result%diagnostics%external_commits /= 1) error stop 223
    call assert_close(committed_storage(committed), 0.004_real64, 224)
    call assert_close(result%mass%residual, 0.0_real64, 225)
  end subroutine test_ladder_composition

  subroutine test_transaction_retry_composition()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    model%reject_above_half_window = .true.
    call init_state(committed)
    call init_config(config)
    interval = canonical_interval_t(0.0_real64, 0.0032_real64)
    call run_canonical_interval(model, committed, forcing, interval, config, result)
    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 231
    if (result%diagnostics%transaction_calls /= 4 .or. result%mass%accepted_transaction_count /= 4) error stop 232
    if (result%diagnostics%retries /= 3 .or. result%diagnostics%solver_rejections /= 3) error stop 233
    if (result%diagnostics%external_commits /= 1) error stop 234
    call assert_close(committed_storage(committed), 0.0032_real64, 235)
    call assert_close(result%mass%residual, 0.0_real64, 236)
  end subroutine test_transaction_retry_composition

  subroutine test_unrepresentable_remainder_fails_closed()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    call init_state(committed)
    call init_config(config)
    interval = canonical_interval_t(0.0_real64, 1.0e-6_real64)
    call run_canonical_interval(model, committed, forcing, interval, config, result)
    if (result%status /= CANONICAL_STATUS_NO_PROGRESS) error stop 241
    if (result%diagnostics%transaction_calls /= 0 .or. result%diagnostics%external_commits /= 0) error stop 242
    call assert_close(committed_storage(committed), 0.0_real64, 243)
  end subroutine test_unrepresentable_remainder_fails_closed

end program test_f_ross01_d3r_model_adapter

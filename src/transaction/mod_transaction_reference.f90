module mod_transaction_reference
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: TX_STATUS_ACCEPTED = 0
  integer, parameter, public :: TX_STATUS_RETRY_EXHAUSTED = 1
  integer, parameter, public :: TX_STATUS_INVALID_INTERVAL = 2
  integer, parameter, public :: TX_ROUTE_NONE = 0
  integer, parameter, public :: TX_ROUTE_TWO_HALF = 2

  type, abstract, public :: transaction_state_t
  contains
    procedure(clone_state_iface), deferred :: clone
  end type transaction_state_t

  type, public :: trial_outcome_t
    logical :: solver_ok = .false.
    real(real64) :: mass_in = 0.0_real64
    real(real64) :: mass_out = 0.0_real64
    integer :: nonlinear_iterations = 0
    integer :: internal_retries = 0
    integer :: headcalc_calls = 0
    integer :: jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
  end type trial_outcome_t

  type, abstract, public :: transaction_model_t
  contains
    procedure(advance_iface), deferred :: advance
    procedure(storage_iface), deferred :: storage
    procedure(temporal_error_iface), deferred :: temporal_error
  end type transaction_model_t

  type, public :: transaction_policy_t
    real(real64) :: temporal_tolerance = 1.0e-6_real64
    real(real64) :: mass_tolerance = 1.0e-10_real64
    real(real64) :: retry_scale = 0.5_real64
    integer :: max_retries = 8
  end type transaction_policy_t

  type, public :: transaction_result_t
    integer :: status = TX_STATUS_INVALID_INTERVAL
    integer :: accepted_route = TX_ROUTE_NONE
    integer :: attempts = 0
    integer :: retries = 0
    integer :: rollbacks = 0
    integer :: commits = 0
    integer :: full_trials = 0
    integer :: half_trials = 0
    integer :: solver_rejections = 0
    integer :: temporal_rejections = 0
    integer :: mass_rejections = 0
    integer :: nonlinear_iterations = 0
    integer :: accepted_nonlinear_iterations = 0
    integer :: internal_retries = 0
    integer :: accepted_internal_retries = 0
    integer :: headcalc_calls = 0
    integer :: accepted_headcalc_calls = 0
    integer :: jacobian_builds = 0
    integer :: accepted_jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: accepted_linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: accepted_backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    integer :: accepted_alternative_solver_calls = 0
    real(real64) :: requested_t0 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
    real(real64) :: accepted_t1 = 0.0_real64
    real(real64) :: accepted_dt = 0.0_real64
    real(real64) :: temporal_error = huge(0.0_real64)
    real(real64) :: full_mass_residual = huge(0.0_real64)
    real(real64) :: half_mass_residual = huge(0.0_real64)
  end type transaction_result_t

  public :: execute_reference_interval

  abstract interface
    subroutine clone_state_iface(self, copy)
      import :: transaction_state_t
      class(transaction_state_t), intent(in) :: self
      class(transaction_state_t), allocatable, intent(out) :: copy
    end subroutine clone_state_iface

    subroutine advance_iface(self, state, t0, t1, outcome)
      import :: transaction_model_t, transaction_state_t, trial_outcome_t, real64
      class(transaction_model_t), intent(inout) :: self
      class(transaction_state_t), intent(inout) :: state
      real(real64), intent(in) :: t0, t1
      type(trial_outcome_t), intent(out) :: outcome
    end subroutine advance_iface

    function storage_iface(self, state) result(value)
      import :: transaction_model_t, transaction_state_t, real64
      class(transaction_model_t), intent(in) :: self
      class(transaction_state_t), intent(in) :: state
      real(real64) :: value
    end function storage_iface

    function temporal_error_iface(self, full_state, half_state) result(value)
      import :: transaction_model_t, transaction_state_t, real64
      class(transaction_model_t), intent(in) :: self
      class(transaction_state_t), intent(in) :: full_state
      class(transaction_state_t), intent(in) :: half_state
      real(real64) :: value
    end function temporal_error_iface
  end interface

contains

  subroutine execute_reference_interval(model, committed, t0, t1, policy, result)
    class(transaction_model_t), intent(inout) :: model
    class(transaction_state_t), allocatable, intent(inout) :: committed
    real(real64), intent(in) :: t0, t1
    type(transaction_policy_t), intent(in) :: policy
    type(transaction_result_t), intent(out) :: result

    class(transaction_state_t), allocatable :: checkpoint
    class(transaction_state_t), allocatable :: full_state
    class(transaction_state_t), allocatable :: half_state
    type(trial_outcome_t) :: full_outcome, half1_outcome, half2_outcome
    real(real64) :: attempt_dt, attempt_t1, midpoint
    real(real64) :: storage0, storage_full, storage_half
    real(real64) :: full_mass_residual, half_mass_residual, terr
    logical :: solver_ok, mass_ok, temporal_ok
    integer :: retry_index

    result = transaction_result_t()
    result%requested_t0 = t0
    result%requested_t1 = t1
    result%accepted_t1 = t0

    if (.not. valid_policy(policy) .or. t1 <= t0 .or. .not. allocated(committed)) then
      result%status = TX_STATUS_INVALID_INTERVAL
      return
    end if

    call committed%clone(checkpoint)
    storage0 = model%storage(checkpoint)
    attempt_dt = t1 - t0

    do retry_index = 0, policy%max_retries
      result%attempts = result%attempts + 1
      attempt_t1 = t0 + attempt_dt
      midpoint = t0 + 0.5_real64 * attempt_dt

      call checkpoint%clone(full_state)
      call model%advance(full_state, t0, attempt_t1, full_outcome)
      result%full_trials = result%full_trials + 1
      result%nonlinear_iterations = result%nonlinear_iterations + full_outcome%nonlinear_iterations
      result%internal_retries = result%internal_retries + full_outcome%internal_retries
      result%headcalc_calls = result%headcalc_calls + full_outcome%headcalc_calls
      result%jacobian_builds = result%jacobian_builds + full_outcome%jacobian_builds
      result%linear_solves = result%linear_solves + full_outcome%linear_solves
      result%backtracking_attempts = result%backtracking_attempts + full_outcome%backtracking_attempts
      result%alternative_solver_calls = result%alternative_solver_calls + full_outcome%alternative_solver_calls

      if (.not. full_outcome%solver_ok) then
        result%solver_rejections = result%solver_rejections + 1
        call reject_and_retry(result, retry_index, policy, attempt_dt)
        if (result%status == TX_STATUS_RETRY_EXHAUSTED) return
        cycle
      end if

      storage_full = model%storage(full_state)
      full_mass_residual = storage_full - storage0 - (full_outcome%mass_in - full_outcome%mass_out)

      call checkpoint%clone(half_state)
      call model%advance(half_state, t0, midpoint, half1_outcome)
      result%half_trials = result%half_trials + 1
      result%nonlinear_iterations = result%nonlinear_iterations + half1_outcome%nonlinear_iterations
      result%internal_retries = result%internal_retries + half1_outcome%internal_retries
      result%headcalc_calls = result%headcalc_calls + half1_outcome%headcalc_calls
      result%jacobian_builds = result%jacobian_builds + half1_outcome%jacobian_builds
      result%linear_solves = result%linear_solves + half1_outcome%linear_solves
      result%backtracking_attempts = result%backtracking_attempts + half1_outcome%backtracking_attempts
      result%alternative_solver_calls = result%alternative_solver_calls + half1_outcome%alternative_solver_calls

      if (half1_outcome%solver_ok) then
        call model%advance(half_state, midpoint, attempt_t1, half2_outcome)
        result%half_trials = result%half_trials + 1
        result%nonlinear_iterations = result%nonlinear_iterations + half2_outcome%nonlinear_iterations
        result%internal_retries = result%internal_retries + half2_outcome%internal_retries
        result%headcalc_calls = result%headcalc_calls + half2_outcome%headcalc_calls
        result%jacobian_builds = result%jacobian_builds + half2_outcome%jacobian_builds
        result%linear_solves = result%linear_solves + half2_outcome%linear_solves
        result%backtracking_attempts = result%backtracking_attempts + half2_outcome%backtracking_attempts
        result%alternative_solver_calls = result%alternative_solver_calls + half2_outcome%alternative_solver_calls
      else
        half2_outcome = trial_outcome_t()
      end if

      solver_ok = half1_outcome%solver_ok .and. half2_outcome%solver_ok
      if (.not. solver_ok) then
        result%solver_rejections = result%solver_rejections + 1
        call reject_and_retry(result, retry_index, policy, attempt_dt)
        if (result%status == TX_STATUS_RETRY_EXHAUSTED) return
        cycle
      end if

      storage_half = model%storage(half_state)
      half_mass_residual = storage_half - storage0 - &
        ((half1_outcome%mass_in + half2_outcome%mass_in) - &
         (half1_outcome%mass_out + half2_outcome%mass_out))
      terr = model%temporal_error(full_state, half_state)

      result%full_mass_residual = full_mass_residual
      result%half_mass_residual = half_mass_residual
      result%temporal_error = terr

      mass_ok = abs(full_mass_residual) <= policy%mass_tolerance .and. &
                abs(half_mass_residual) <= policy%mass_tolerance
      temporal_ok = terr <= policy%temporal_tolerance

      if (.not. mass_ok) then
        result%mass_rejections = result%mass_rejections + 1
        call reject_and_retry(result, retry_index, policy, attempt_dt)
        if (result%status == TX_STATUS_RETRY_EXHAUSTED) return
        cycle
      end if

      if (.not. temporal_ok) then
        result%temporal_rejections = result%temporal_rejections + 1
        call reject_and_retry(result, retry_index, policy, attempt_dt)
        if (result%status == TX_STATUS_RETRY_EXHAUSTED) return
        cycle
      end if

      call move_alloc(half_state, committed)
      result%status = TX_STATUS_ACCEPTED
      result%accepted_route = TX_ROUTE_TWO_HALF
      result%accepted_t1 = attempt_t1
      result%accepted_dt = attempt_dt
      result%accepted_nonlinear_iterations = half1_outcome%nonlinear_iterations + half2_outcome%nonlinear_iterations
      result%accepted_internal_retries = half1_outcome%internal_retries + half2_outcome%internal_retries
      result%accepted_headcalc_calls = half1_outcome%headcalc_calls + half2_outcome%headcalc_calls
      result%accepted_jacobian_builds = half1_outcome%jacobian_builds + half2_outcome%jacobian_builds
      result%accepted_linear_solves = half1_outcome%linear_solves + half2_outcome%linear_solves
      result%accepted_backtracking_attempts = half1_outcome%backtracking_attempts + half2_outcome%backtracking_attempts
      result%accepted_alternative_solver_calls = half1_outcome%alternative_solver_calls + half2_outcome%alternative_solver_calls
      result%commits = result%commits + 1
      return
    end do

    result%status = TX_STATUS_RETRY_EXHAUSTED
  end subroutine execute_reference_interval

  subroutine reject_and_retry(result, retry_index, policy, attempt_dt)
    type(transaction_result_t), intent(inout) :: result
    integer, intent(in) :: retry_index
    type(transaction_policy_t), intent(in) :: policy
    real(real64), intent(inout) :: attempt_dt

    result%rollbacks = result%rollbacks + 1
    if (retry_index >= policy%max_retries) then
      result%status = TX_STATUS_RETRY_EXHAUSTED
      return
    end if
    result%retries = result%retries + 1
    attempt_dt = attempt_dt * policy%retry_scale
  end subroutine reject_and_retry

  pure logical function valid_policy(policy)
    type(transaction_policy_t), intent(in) :: policy
    valid_policy = policy%temporal_tolerance >= 0.0_real64 .and. &
                   policy%mass_tolerance >= 0.0_real64 .and. &
                   policy%retry_scale > 0.0_real64 .and. policy%retry_scale < 1.0_real64 .and. &
                   policy%max_retries >= 0
  end function valid_policy

end module mod_transaction_reference

module mod_test_transaction_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  implicit none
  private

  type, extends(transaction_state_t), public :: test_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => test_clone
  end type test_state_t

  type, extends(transaction_model_t), public :: test_model_t
    real(real64) :: k = 1.0_real64
    integer :: advance_calls = 0
    integer :: fail_on_call = 0
    logical :: inject_mass_defect = .false.
    real(real64) :: mass_defect = 0.0_real64
  contains
    procedure :: advance => test_advance
    procedure :: storage => test_storage
    procedure :: temporal_error => test_temporal_error
  end type test_model_t

contains

  subroutine test_clone(self, copy)
    class(test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(test_state_t :: copy)
    select type(copy)
    type is(test_state_t)
      copy%water = self%water
    end select
  end subroutine test_clone

  subroutine test_advance(self, state, t0, t1, outcome)
    class(test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water

    self%advance_calls = self%advance_calls + 1
    outcome = trial_outcome_t()
    dt = t1 - t0

    select type(state)
    type is(test_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - self%k * dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      outcome%nonlinear_iterations = 1
      outcome%solver_ok = .true.
      if (self%advance_calls == self%fail_on_call) then
        state%water = -999.0_real64
        outcome%solver_ok = .false.
        return
      end if
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + self%mass_defect
    class default
      error stop 'unexpected state type in test_advance'
    end select
  end subroutine test_advance

  function test_storage(self, state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(state)
    type is(test_state_t)
      value = state%water
    class default
      error stop 'unexpected state type in test_storage'
    end select
  end function test_storage

  function test_temporal_error(self, full_state, half_state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state
    real(real64) :: value, full_water, half_water
    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(full_state)
    type is(test_state_t)
      full_water = full_state%water
    class default
      error stop 'unexpected full state type'
    end select
    select type(half_state)
    type is(test_state_t)
      half_water = half_state%water
    class default
      error stop 'unexpected half state type'
    end select
    value = abs(half_water - full_water)
  end function test_temporal_error

end module mod_test_transaction_model

program test_transaction_reference
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_test_transaction_model
  implicit none

  integer :: failures
  failures = 0
  call test_normal(failures)
  call test_temporal_retry(failures)
  call test_solver_failure_no_leak(failures)
  call test_mass_gate(failures)
  call test_noncalendar_time(failures)
  call test_repeatability(failures)
  call test_parallel_independence(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'A23BL_TRANSACTION_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'A23BL_TRANSACTION_GATE PASS'

contains

  subroutine new_state(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(test_state_t :: state)
    select type(state)
    type is(test_state_t)
      state%water = water
    end select
  end subroutine new_state

  function water_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value
    select type(state)
    type is(test_state_t)
      value = state%water
    class default
      error stop 'unexpected state type in water_of'
    end select
  end function water_of

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine expect_true

  subroutine expect_close(actual, expected, tol, label, failures)
    real(real64), intent(in) :: actual, expected, tol
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call expect_true(abs(actual-expected) <= tol, label, failures)
  end subroutine expect_close

  subroutine test_normal(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(test_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 1.0_real64)
    policy%temporal_tolerance = 0.01_real64
    policy%mass_tolerance = 1.0e-13_real64
    call execute_reference_interval(model, state, 0.0_real64, 0.1_real64, policy, result)
    call expect_true(result%status == TX_STATUS_ACCEPTED, 'normal accepted', failures)
    call expect_true(result%accepted_route == TX_ROUTE_TWO_HALF, 'normal two-half route', failures)
    call expect_true(result%full_trials == 1 .and. result%half_trials == 2, 'normal always sampled', failures)
    call expect_true(result%rollbacks == 0 .and. result%commits == 1, 'normal commit accounting', failures)
    call expect_close(water_of(state), 0.9025_real64, 1.0e-14_real64, 'normal endpoint', failures)
    call expect_close(result%full_mass_residual, 0.0_real64, 1.0e-14_real64, 'normal full mass', failures)
    call expect_close(result%half_mass_residual, 0.0_real64, 1.0e-14_real64, 'normal half mass', failures)
  end subroutine test_normal

  subroutine test_temporal_retry(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(test_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 1.0_real64)
    policy%temporal_tolerance = 0.02_real64
    policy%mass_tolerance = 1.0e-13_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 3
    call execute_reference_interval(model, state, 5.0_real64, 5.5_real64, policy, result)
    call expect_true(result%status == TX_STATUS_ACCEPTED, 'temporal retry accepted', failures)
    call expect_true(result%temporal_rejections == 1, 'one temporal rejection', failures)
    call expect_true(result%retries == 1 .and. result%rollbacks == 1, 'temporal retry accounting', failures)
    call expect_close(result%accepted_dt, 0.25_real64, 1.0e-14_real64, 'temporal retry dt', failures)
    call expect_close(water_of(state), 0.765625_real64, 1.0e-14_real64, 'retry from committed checkpoint', failures)
  end subroutine test_temporal_retry

  subroutine test_solver_failure_no_leak(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(test_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 1.0_real64)
    model%fail_on_call = 1
    policy%temporal_tolerance = 0.01_real64
    policy%mass_tolerance = 1.0e-13_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 3
    call execute_reference_interval(model, state, 10.0_real64, 10.2_real64, policy, result)
    call expect_true(result%status == TX_STATUS_ACCEPTED, 'solver failure retry accepted', failures)
    call expect_true(result%solver_rejections == 1 .and. result%rollbacks == 1, 'solver rollback accounted', failures)
    call expect_close(water_of(state), 0.9025_real64, 1.0e-14_real64, 'failed trial cannot leak', failures)
  end subroutine test_solver_failure_no_leak

  subroutine test_mass_gate(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(test_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 1.0_real64)
    model%inject_mass_defect = .true.
    model%mass_defect = 1.0e-4_real64
    policy%temporal_tolerance = 1.0_real64
    policy%mass_tolerance = 1.0e-10_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 2
    call execute_reference_interval(model, state, 0.0_real64, 0.1_real64, policy, result)
    call expect_true(result%status == TX_STATUS_RETRY_EXHAUSTED, 'mass defect rejected hard', failures)
    call expect_true(result%mass_rejections == 3, 'mass rejected every attempt', failures)
    call expect_true(result%commits == 0, 'mass defect never commits', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'mass failure keeps committed state', failures)
  end subroutine test_mass_gate

  subroutine test_noncalendar_time(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(test_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 2.0_real64)
    policy%temporal_tolerance = 0.1_real64
    policy%mass_tolerance = 1.0e-13_real64
    call execute_reference_interval(model, state, 123.456_real64, 123.506_real64, policy, result)
    call expect_true(result%status == TX_STATUS_ACCEPTED, 'noncalendar interval accepted', failures)
    call expect_close(result%accepted_t1, 123.506_real64, 1.0e-13_real64, 'generic t1 preserved', failures)
  end subroutine test_noncalendar_time

  subroutine test_repeatability(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state_a, state_b
    type(test_model_t) :: model_a, model_b
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result_a, result_b

    call new_state(state_a, 1.0_real64)
    call new_state(state_b, 1.0_real64)
    policy%temporal_tolerance = 0.02_real64
    policy%mass_tolerance = 1.0e-13_real64
    policy%max_retries = 3
    call execute_reference_interval(model_a, state_a, 7.25_real64, 7.75_real64, policy, result_a)
    call execute_reference_interval(model_b, state_b, 7.25_real64, 7.75_real64, policy, result_b)
    call expect_close(water_of(state_a), water_of(state_b), 0.0_real64, 'repeat endpoint exact', failures)
    call expect_true(result_a%attempts == result_b%attempts, 'repeat attempts exact', failures)
    call expect_true(result_a%retries == result_b%retries, 'repeat retries exact', failures)
    call expect_close(result_a%temporal_error, result_b%temporal_error, 0.0_real64, 'repeat error exact', failures)
  end subroutine test_repeatability

  subroutine test_parallel_independence(failures)
    integer, intent(inout) :: failures
    integer :: i, local_failures

    local_failures = 0
!$omp parallel do default(none) private(i) reduction(+:local_failures)
    do i = 1, 8000
      call run_parallel_case(i, local_failures)
    end do
!$omp end parallel do
    call expect_true(local_failures == 0, 'parallel worker independence', failures)
  end subroutine test_parallel_independence

  subroutine run_parallel_case(index, failures)
    integer, intent(in) :: index
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(test_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64) :: initial, expected

    initial = 1.0_real64 + 1.0e-6_real64 * real(index, real64)
    call new_state(state, initial)
    policy%temporal_tolerance = 0.01_real64
    policy%mass_tolerance = 1.0e-13_real64
    call execute_reference_interval(model, state, 0.125_real64, 0.225_real64, policy, result)
    expected = initial * 0.95_real64 * 0.95_real64
    if (result%status /= TX_STATUS_ACCEPTED) failures = failures + 1
    if (abs(water_of(state) - expected) > 2.0e-14_real64) failures = failures + 1
  end subroutine run_parallel_case

end program test_transaction_reference

module mod_contextual_transaction_test
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  implicit none
  private

  type, extends(transaction_state_t), public :: context_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => clone_context_state
  end type context_state_t

  type, extends(transaction_attempt_context_t) :: counter_context_t
    integer :: counter = 0
  end type counter_context_t

  type, extends(transaction_model_t), public :: contextual_model_t
    integer :: legacy_counter = 0
    logical :: inject_mass_defect = .false.
  contains
    procedure :: advance => contextual_advance
    procedure :: storage => contextual_storage
    procedure :: temporal_error => contextual_temporal_error
    procedure :: capture_attempt_context => contextual_capture
    procedure :: restore_attempt_context => contextual_restore
  end type contextual_model_t

contains

  subroutine clone_context_state(self, copy)
    class(context_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(context_state_t :: copy)
    select type (copy)
    type is (context_state_t)
      copy%water = self%water
    end select
  end subroutine clone_context_state

  subroutine contextual_capture(self, context)
    class(contextual_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context
    allocate(counter_context_t :: context)
    select type (context)
    type is (counter_context_t)
      context%counter = self%legacy_counter
    class default
      error stop 'context allocation mismatch'
    end select
  end subroutine contextual_capture

  subroutine contextual_restore(self, context)
    class(contextual_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context
    select type (context)
    type is (counter_context_t)
      self%legacy_counter = context%counter
    class default
      error stop 'unexpected attempt context'
    end select
  end subroutine contextual_restore

  subroutine contextual_advance(self, state, t0, t1, outcome)
    class(contextual_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: before, delta

    outcome = trial_outcome_t()
    self%legacy_counter = self%legacy_counter + 1
    select type (state)
    type is (context_state_t)
      before = state%water
      delta = (t1-t0) * real(self%legacy_counter, real64)
      state%water = before - delta
      outcome%mass_out = delta
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + 1.0e-3_real64
      outcome%solver_ok = .true.
    class default
      error stop 'unexpected contextual state'
    end select
  end subroutine contextual_advance

  function contextual_storage(self, state) result(value)
    class(contextual_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%legacy_counter < -huge(0)) error stop 'unreachable'
    select type (state)
    type is (context_state_t)
      value = state%water
    class default
      error stop 'unexpected contextual state'
    end select
  end function contextual_storage

  function contextual_temporal_error(self, full_state, half_state) result(value)
    class(contextual_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value, a, b
    if (self%legacy_counter < -huge(0)) error stop 'unreachable'
    select type (full_state)
    type is (context_state_t)
      a = full_state%water
    class default
      error stop 'unexpected full contextual state'
    end select
    select type (half_state)
    type is (context_state_t)
      b = half_state%water
    class default
      error stop 'unexpected half contextual state'
    end select
    value = abs(a-b)
  end function contextual_temporal_error

end module mod_contextual_transaction_test

program test_transaction_attempt_context
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_contextual_transaction_test
  implicit none
  class(transaction_state_t), allocatable :: state
  type(contextual_model_t) :: model
  type(transaction_policy_t) :: policy
  type(transaction_result_t) :: result

  allocate(context_state_t :: state)
  select type (state)
  type is (context_state_t)
    state%water = 10.0_real64
  end select
  policy%temporal_tolerance = 100.0_real64
  policy%mass_tolerance = 1.0e-12_real64
  policy%max_retries = 0

  call execute_reference_interval(model, state, 0.0_real64, 1.0_real64, policy, result)
  if (result%status /= TX_STATUS_ACCEPTED) error stop 'contextual transaction not accepted'
  select type (state)
  type is (context_state_t)
    if (abs(state%water-8.5_real64) > 1.0e-14_real64) error stop 'accepted half branch state wrong'
  class default
    error stop 'state type lost'
  end select
  if (model%legacy_counter /= 2) error stop 'accepted attempt context not committed'

  deallocate(state)
  allocate(context_state_t :: state)
  select type (state)
  type is (context_state_t)
    state%water = 10.0_real64
  end select
  model%legacy_counter = 0
  model%inject_mass_defect = .true.
  call execute_reference_interval(model, state, 0.0_real64, 1.0_real64, policy, result)
  if (result%status /= TX_STATUS_RETRY_EXHAUSTED) error stop 'mass defect should reject'
  select type (state)
  type is (context_state_t)
    if (abs(state%water-10.0_real64) > 1.0e-14_real64) error stop 'rejected physical state leaked'
  end select
  if (model%legacy_counter /= 0) error stop 'rejected attempt context leaked'

  print *, 'FCI08_TRANSACTION_ATTEMPT_CONTEXT PASS'
end program test_transaction_attempt_context

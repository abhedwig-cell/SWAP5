module mod_test_root_result_model
  use, intrinsic :: iso_fortran_env, only: real64, int64
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
    logical :: storage_complete = .true.
  contains
    procedure :: advance => test_advance
    procedure :: storage => test_storage
    procedure :: temporal_error => test_temporal_error
    procedure :: storage_accounting_status => test_storage_status
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
      outcome%actual_transpiration_available=.true.
      outcome%actual_transpiration_amount=outcome%mass_out
      if(dt>.75_real64) outcome%actual_transpiration_amount=.9_real64*outcome%mass_out
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=0.0_real64
      outcome%nonlinear_iterations = 1
      outcome%solver_ok = .true.
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      if (self%advance_calls == self%fail_on_call) then
        state%water = -999.0_real64
        outcome%solver_ok = .false.
        outcome%actual_transpiration_amount=999._real64
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
    if (.not. self%storage_complete) error stop 'incomplete storage must not be evaluated'
    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(state)
    type is(test_state_t)
      value = state%water
    class default
      error stop 'unexpected state type in test_storage'
    end select
  end function test_storage

  subroutine test_storage_status(self, state, complete, missing_mask)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(state,state)) error stop 'unreachable'
    complete = self%storage_complete
    if (complete) then
      missing_mask = TX_MASS_MISSING_NONE
    else
      missing_mask = TX_MASS_MISSING_UNSPECIFIED
    end if
  end subroutine test_storage_status

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

end module mod_test_root_result_model

program test_ppa_wu05d2_accepted_result
 use iso_fortran_env,only:real64
 use mod_transaction_reference
 use mod_test_root_result_model
 implicit none
 class(transaction_state_t),allocatable::state,fresh
 type(test_model_t)::model,replay
 type(transaction_policy_t)::policy
 type(transaction_result_t)::r,s
 policy%temporal_tolerance=100._real64;policy%mass_tolerance=1.e-12_real64;policy%max_retries=2
 model%k=.1_real64;replay%k=.1_real64
 call reset(state)
 call execute_reference_interval(model,state,0._real64,1._real64,policy,r)
 call req(r%status==TX_STATUS_ACCEPTED.and.r%actual_transpiration_available,'accepted half route')
 call req(abs(r%actual_transpiration_amount-.975_real64)<1.e-14_real64,'half amount excludes full trial')
 model%advance_calls=0;model%fail_on_call=1
 call reset(state)
 call execute_reference_interval(model,state,0._real64,1._real64,policy,r)
 call req(r%status==TX_STATUS_ACCEPTED.and.r%retries==1,'failed then accepted retry')
 call reset(fresh)
 call execute_reference_interval(replay,fresh,0._real64,.5_real64,policy,s)
 call req(abs(r%actual_transpiration_amount-s%actual_transpiration_amount)<=0._real64,'fresh retry result identity')
 call req(r%actual_transpiration_amount<1._real64,'rejected 999 discarded')
 model%advance_calls=0;model%fail_on_call=1;policy%max_retries=0
 call reset(state)
 call execute_reference_interval(model,state,0._real64,1._real64,policy,r)
 call req(r%status/=TX_STATUS_ACCEPTED.and..not.r%actual_transpiration_available,'failed result unavailable')
 select type(state)
 type is(test_state_t)
 call req(abs(state%water-10._real64)<=0._real64,'failed state preserved')
 end select
 model%advance_calls=0;model%fail_on_call=0;policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
 call reset(state)
 call execute_reference_interval(model,state,0._real64,1._real64,policy,r)
 call req(r%status==TX_STATUS_ACCEPTED.and.r%actual_transpiration_available,'certified route')
 call req(abs(r%actual_transpiration_amount-.9_real64)<1.e-14_real64,'certified result uses chosen trial')
 print '(a)','PPA_WU05D2_ACCEPTED_RESULT=PASS'
contains
 subroutine reset(v)
 class(transaction_state_t),allocatable,intent(out)::v
 allocate(test_state_t::v)
 select type(v)
 type is(test_state_t)
 v%water=10._real64
 end select
 end subroutine
 subroutine req(v,m)
 logical,intent(in)::v
 character(*),intent(in)::m
 if(.not.v) then
 print *,m
 error stop 1
 end if
 end subroutine
end program

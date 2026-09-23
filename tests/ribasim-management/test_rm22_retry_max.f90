module mod_rm22_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  implicit none
  type, extends(transaction_state_t) :: rm22_state_t
    real(real64) :: storage_value=1.0_real64
  contains
    procedure :: clone => rm22_clone
  end type
  type, extends(transaction_model_t) :: rm22_model_t
    integer :: calls=0
  contains
    procedure :: advance => rm22_advance
    procedure :: storage => rm22_storage
    procedure :: temporal_error => rm22_temporal_error
  end type
contains
  subroutine rm22_clone(self,copy)
    class(rm22_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(rm22_state_t::copy)
    select type(copy); type is(rm22_state_t); copy%storage_value=self%storage_value; end select
  end subroutine
  subroutine rm22_advance(self,state,t0,t1,outcome)
    class(rm22_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    real(real64),parameter::values(3)=[4.0_real64,2.0_real64,1.5_real64]
    self%calls=self%calls+1
    outcome=trial_outcome_t()
    outcome%mass_accounting_complete=.true.
    outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
    outcome%mass_in=0.0_real64; outcome%mass_out=0.0_real64
    if(t1<=t0) error stop 'invalid synthetic interval'
    if(self%calls<=3)then
      outcome%solver_ok=.true.
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=values(self%calls)
    else
      outcome%solver_ok=.false.
      outcome%temporal_certificate_available=.false.
    end if
    select type(state); type is(rm22_state_t); state%storage_value=state%storage_value; end select
  end subroutine
  function rm22_storage(self,state) result(value)
    class(rm22_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    real(real64)::value
    if(self%calls<0) error stop 'unreachable'
    select type(state); type is(rm22_state_t); value=state%storage_value; class default; value=huge(1.0_real64); end select
  end function
  function rm22_temporal_error(self,full_state,half_state) result(value)
    class(rm22_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    real(real64)::value
    if(self%calls<0) error stop 'unreachable'
    value=0.0_real64
  end function
end module

program test_rm22_retry_max
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_rm22_test_model
  implicit none
  class(transaction_state_t),allocatable::state
  type(rm22_model_t)::model
  type(transaction_policy_t)::policy
  type(transaction_result_t)::result
  allocate(rm22_state_t::state)
  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  policy%temporal_tolerance=0.0_real64
  policy%mass_tolerance=1.0e-12_real64
  policy%retry_scale=0.5_real64
  policy%max_retries=3
  call execute_reference_interval(model,state,0.0_real64,1.0_real64,policy,result)
  if(result%status/=TX_STATUS_RETRY_EXHAUSTED) error stop 'status changed'
  if(result%attempts/=4 .or. result%retries/=3 .or. result%rollbacks/=4) error stop 'retry accounting changed'
  if(result%temporal_rejections/=3 .or. result%solver_rejections/=1) error stop 'rejection accounting changed'
  if(abs(result%temporal_indicator-1.5_real64)>1.0e-15_real64) error stop 'terminal indicator provenance changed'
  if(abs(result%max_temporal_indicator-4.0_real64)>1.0e-15_real64) error stop 'retry maximum wrong'
  write(*,'(A,ES26.17E3)') 'RM22_SYNTHETIC_TERMINAL_INDICATOR=',result%temporal_indicator
  write(*,'(A,ES26.17E3)') 'RM22_SYNTHETIC_RETRY_MAX=',result%max_temporal_indicator
  write(*,'(A)') 'RM22_RETRY_COMPLETE_DIAGNOSTIC=PASS'
end program

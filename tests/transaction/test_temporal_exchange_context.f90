module temporal_exchange_fixture
  use iso_fortran_env,only:real64,int64
  use mod_transaction_reference
  implicit none
  type,extends(transaction_state_t)::water_state
    real(real64)::water=1
  contains
    procedure::clone
  end type
  type,extends(transaction_attempt_context_t)::exchange_context
    real(real64)::exchange=0
  end type
  type,extends(transaction_model_t)::exchange_model
    real(real64)::exchange=0
  contains
    procedure::advance
    procedure::storage
    procedure::storage_accounting_status=>accounting
    procedure::temporal_error=>legacy_error
    procedure::temporal_error_with_context=>context_error
    procedure::capture_attempt_context=>capture
    procedure::restore_attempt_context=>restore
  end type
contains
  subroutine clone(self,copy)
    class(water_state),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(copy,source=self)
  end subroutine
  subroutine advance(self,state,t0,t1,outcome)
    class(exchange_model),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    ! Throughflow with unchanged endpoint exposes an exchange-only temporal error.
    real(real64)::delta
    delta=(t1-t0)**2
    self%exchange=self%exchange+delta
    outcome=trial_outcome_t()
    outcome%solver_ok=.true.;outcome%mass_in=delta;outcome%mass_out=delta
    outcome%mass_accounting_complete=.true.;outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
  end subroutine
  real(real64) function storage(self,state) result(value)
    class(exchange_model),intent(in)::self
    class(transaction_state_t),intent(in)::state
    select type(state)
    type is(water_state)
      value=state%water
    class default
      error stop 'bad state'
    end select
  end function
  subroutine accounting(self,state,complete,missing_mask)
    class(exchange_model),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    complete=.true.;missing_mask=TX_MASS_MISSING_NONE
  end subroutine
  real(real64) function legacy_error(self,full_state,half_state) result(value)
    class(exchange_model),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    value=0
  end function
  real(real64) function context_error(self,full_state,half_state,full_context,half_context) result(value)
    class(exchange_model),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    class(transaction_attempt_context_t),intent(in),optional::full_context,half_context
    value=huge(value)
    if(.not.present(full_context).or..not.present(half_context))return
    select type(f=>full_context)
    type is(exchange_context)
      select type(h=>half_context)
      type is(exchange_context)
        value=abs(f%exchange-h%exchange)
      end select
    end select
  end function
  subroutine capture(self,context)
    class(exchange_model),intent(inout)::self
    class(transaction_attempt_context_t),allocatable,intent(out)::context
    allocate(exchange_context::context)
    select type(context)
    type is(exchange_context)
      context%exchange=self%exchange
    end select
  end subroutine
  subroutine restore(self,context)
    class(exchange_model),intent(inout)::self
    class(transaction_attempt_context_t),intent(in)::context
    select type(context)
    type is(exchange_context)
      self%exchange=context%exchange
    class default
      error stop 'bad context'
    end select
  end subroutine
end module
program test_temporal_exchange_context
  use temporal_exchange_fixture
  implicit none
  class(transaction_state_t),allocatable::state
  type(exchange_model)::model
  type(transaction_policy_t)::policy
  type(transaction_result_t)::result
  allocate(water_state::state)
  policy%temporal_tolerance=0.2_real64;policy%max_retries=0
  call execute_reference_interval(model,state,0.0_real64,1.0_real64,policy,result)
  if(result%status/=TX_STATUS_RETRY_EXHAUSTED.or.result%temporal_rejections/=1) error stop 'exchange-only must reject'
  if(model%exchange/=0)error stop 'rejected exchange leaked'
  policy%max_retries=1
  call execute_reference_interval(model,state,0.0_real64,1.0_real64,policy,result)
  if(result%status/=TX_STATUS_ACCEPTED.or.result%retries/=1)error stop 'retry did not select refined halves'
  if(result%accepted_t1/=0.5_real64.or.model%exchange/=0.125_real64)error stop 'full/half exchange context mixed'
  call execute_reference_interval(model,state,0.5_real64,1.0_real64,policy,result)
  if(result%status/=TX_STATUS_ACCEPTED.or.model%exchange/=0.25_real64)error stop 'context subdivision composition wrong'
  select type(state)
  type is(water_state)
    if(state%water/=1)error stop 'physical endpoint changed'
  end select
  model%exchange=0
  call execute_reference_interval(model,state,0.0_real64,1.0_real64,policy,result)
  if(model%exchange/=0.125_real64)error stop 'retry replay drift'
  print '(A)','TEMPORAL_EXCHANGE_CONTEXT_ACCEPT_REJECT_RETRY_COMPOSITION_REPLAY=PASS'
end program

program test_fkt10_temporal_history_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, transaction_policy_t, &
       transaction_result_t, trial_outcome_t, execute_reference_interval, TX_STATUS_ACCEPTED, &
       TX_STATUS_RETRY_EXHAUSTED, TX_ROUTE_TWO_HALF, TX_TEMPORAL_EXTERNAL_FULL_HALF, &
       TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE
  use mod_fkt_temporal_indicator_history, only: fkt_temporal_indicator_history_t
  implicit none

  type, extends(transaction_state_t) :: history_state_t
    real(real64) :: storage_value = 0.0_real64
    type(fkt_temporal_indicator_history_t) :: temporal_history
  contains
    procedure :: clone => history_state_clone
  end type history_state_t

  type, extends(transaction_model_t) :: history_model_t
    real(real64) :: solver_dt_limit = huge(0.0_real64)
    real(real64) :: mass_bad_above_dt = huge(0.0_real64)
  contains
    procedure :: advance => history_model_advance
    procedure :: storage => history_model_storage
    procedure :: temporal_error => history_model_temporal_error
    procedure :: storage_accounting_status => history_storage_status
  end type history_model_t

  call test_clone_isolation()
  call test_temporal_reject_retry()
  call test_solver_reject_retry()
  call test_mass_reject_retry()
  call test_model_certificate_fail_closed()
  call test_A_B_A_no_history_leakage()
  write(*,'(A)') 'FKT10_TEMPORAL_HISTORY_TRANSACTION PASS'

contains

  subroutine history_state_clone(self, copy)
    class(history_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(history_state_t :: copy)
    select type (copy)
    type is (history_state_t)
      copy = self
    end select
  end subroutine history_state_clone

  subroutine history_model_advance(self, state, t0, t1, outcome)
    class(history_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, increment
    real(real64) :: derivative(2)
    logical :: ok

    outcome = trial_outcome_t()
    dt = t1-t0
    if (dt <= 0.0_real64) return
    derivative = [t0,t1]

    select type (s => state)
    type is (history_state_t)
      increment = dt*dt
      s%storage_value = s%storage_value + increment
      call s%temporal_history%replace(derivative,ok)
      if (.not. ok) return
      outcome%mass_in = increment
      outcome%mass_out = 0.0_real64
      if (dt > self%mass_bad_above_dt) outcome%mass_in = increment + 1.0_real64
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%solver_ok = dt <= self%solver_dt_limit
    class default
      return
    end select
  end subroutine history_model_advance

  real(real64) function history_model_storage(self,state) result(value)
    class(history_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%solver_dt_limit < 0.0_real64) error stop 'unreachable model marker'
    select type (s => state)
    type is (history_state_t)
      value = s%storage_value
    class default
      value = huge(0.0_real64)
    end select
  end function history_model_storage

  real(real64) function history_model_temporal_error(self,full_state,half_state) result(value)
    class(history_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state,half_state
    if (self%mass_bad_above_dt < 0.0_real64) error stop 'unreachable model marker'
    value = huge(0.0_real64)
    select type (f => full_state)
    type is (history_state_t)
      select type (h => half_state)
      type is (history_state_t)
        value = abs(f%storage_value-h%storage_value)
      end select
    end select
  end function history_model_temporal_error

  subroutine history_storage_status(self,state,complete,missing_mask)
    class(history_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%solver_dt_limit < 0.0_real64) error stop 'unreachable model marker'
    complete = .false.
    missing_mask = 1_int64
    select type (s => state)
    type is (history_state_t)
      complete = s%storage_value < huge(0.0_real64)
      if (complete) missing_mask = TX_MASS_MISSING_NONE
    end select
  end subroutine history_storage_status

  subroutine initialize_state(state,marker0,marker1)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: marker0,marker1
    real(real64) :: values(2)
    logical :: ok
    allocate(history_state_t :: state)
    select type (s => state)
    type is (history_state_t)
      s%storage_value = 0.0_real64
      values = [marker0,marker1]
      call s%temporal_history%replace(values,ok)
      call require(ok,'initialize history')
    end select
  end subroutine initialize_state

  subroutine require_history(state,expected,label)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64), intent(in) :: expected(2)
    character(len=*), intent(in) :: label
    real(real64), allocatable :: values(:)
    logical :: available
    call require(allocated(state),trim(label)//' state allocated')
    select type (s => state)
    type is (history_state_t)
      call s%temporal_history%snapshot(values,available)
      call require(available,trim(label)//' history available')
      call require(size(values)==2,trim(label)//' history size')
      call require(all(values==expected),trim(label)//' history value')
    class default
      call require(.false.,trim(label)//' dynamic state type')
    end select
  end subroutine require_history

  subroutine test_clone_isolation()
    class(transaction_state_t), allocatable :: original,copy
    real(real64) :: replacement(2)
    logical :: ok
    call initialize_state(original,-1.0_real64,0.0_real64)
    call original%clone(copy)
    select type (s => copy)
    type is (history_state_t)
      replacement=[9.0_real64,10.0_real64]
      call s%temporal_history%replace(replacement,ok)
      call require(ok,'clone replacement')
    end select
    call require_history(original,[-1.0_real64,0.0_real64],'clone original isolation')
    call require_history(copy,[9.0_real64,10.0_real64],'clone copy mutation')
    write(*,'(A)') 'FKT10_GATE_B_CLONE_ISOLATION=PASS'
  end subroutine test_clone_isolation

  subroutine base_policy(policy)
    type(transaction_policy_t), intent(out) :: policy
    policy = transaction_policy_t()
    policy%temporal_tolerance = 1.0e6_real64
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 4
    policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  end subroutine base_policy

  subroutine test_temporal_reject_retry()
    class(transaction_state_t), allocatable :: committed
    type(history_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    call initialize_state(committed,-1.0_real64,0.0_real64)
    call base_policy(policy)
    policy%temporal_tolerance = 0.2_real64
    call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'temporal retry accepted')
    call require(result%accepted_route==TX_ROUTE_TWO_HALF,'temporal retry two-half')
    call require(result%temporal_rejections==1,'temporal retry count')
    call require(result%retries==1,'temporal retry retries')
    call require(result%accepted_t1==0.5_real64,'temporal retry shortened endpoint')
    call require_history(committed,[0.25_real64,0.5_real64],'temporal retry accepted history')
    write(*,'(A)') 'FKT10_GATE_C_TEMPORAL_RETRY_HISTORY=PASS'
  end subroutine test_temporal_reject_retry

  subroutine test_solver_reject_retry()
    class(transaction_state_t), allocatable :: committed
    type(history_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    call initialize_state(committed,-2.0_real64,0.0_real64)
    call base_policy(policy)
    model%solver_dt_limit = 0.6_real64
    call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'solver retry accepted')
    call require(result%solver_rejections==1,'solver retry rejection count')
    call require(result%retries==1,'solver retry retries')
    call require_history(committed,[0.25_real64,0.5_real64],'solver retry accepted history')
    write(*,'(A)') 'FKT10_GATE_C_SOLVER_RETRY_HISTORY=PASS'
  end subroutine test_solver_reject_retry

  subroutine test_mass_reject_retry()
    class(transaction_state_t), allocatable :: committed
    type(history_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    call initialize_state(committed,-3.0_real64,0.0_real64)
    call base_policy(policy)
    model%mass_bad_above_dt = 0.6_real64
    call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'mass retry accepted')
    call require(result%mass_rejections==1,'mass retry rejection count')
    call require(result%retries==1,'mass retry retries')
    call require_history(committed,[0.25_real64,0.5_real64],'mass retry accepted history')
    write(*,'(A)') 'FKT10_GATE_C_MASS_RETRY_HISTORY=PASS'
  end subroutine test_mass_reject_retry

  subroutine test_model_certificate_fail_closed()
    class(transaction_state_t), allocatable :: committed
    type(history_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    call initialize_state(committed,-4.0_real64,0.0_real64)
    call base_policy(policy)
    policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    policy%max_retries = 1
    call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
    call require(result%status==TX_STATUS_RETRY_EXHAUSTED,'certificate unavailable fail closed')
    call require(result%temporal_certificate_unavailable_rejections==2,'certificate unavailable count')
    call require_history(committed,[-4.0_real64,0.0_real64],'certificate rejection preserves committed history')
    write(*,'(A)') 'FKT10_GATE_C_NO_UNQUALIFIED_CERTIFICATE=PASS'
  end subroutine test_model_certificate_fail_closed

  subroutine test_A_B_A_no_history_leakage()
    class(transaction_state_t), allocatable :: a,b
    type(history_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    call initialize_state(a,-10.0_real64,0.0_real64)
    call initialize_state(b,-20.0_real64,0.0_real64)
    call base_policy(policy)

    call execute_reference_interval(model,a,0.0_real64,0.5_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'A first accepted')
    call require_history(a,[0.25_real64,0.5_real64],'A first history')
    call execute_reference_interval(model,b,0.0_real64,0.25_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'B accepted')
    call require_history(b,[0.125_real64,0.25_real64],'B history')
    call require_history(a,[0.25_real64,0.5_real64],'A unchanged by B')
    call execute_reference_interval(model,a,0.5_real64,0.75_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'A second accepted')
    call require_history(a,[0.625_real64,0.75_real64],'A second history')
    call require_history(b,[0.125_real64,0.25_real64],'B unchanged by A second')
    write(*,'(A)') 'FKT10_GATE_F_A_B_A_HISTORY_ISOLATION=PASS'
  end subroutine test_A_B_A_no_history_leakage

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FKT10_TEMPORAL_HISTORY_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fkt10_temporal_history_transaction

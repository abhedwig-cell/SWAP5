module mod_fpe_elastic58_scripted_model
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference
  implicit none
  private

  type, extends(transaction_state_t), public :: scripted_state_t
    real(real64) :: water = 1.0_real64
  contains
    procedure :: clone => scripted_clone
  end type scripted_state_t

  type, extends(transaction_model_t), public :: scripted_model_t
    integer :: calls = 0
    logical :: solver_ok_script(16) = .true.
    logical :: cert_available_script(16) = .true.
    real(real64) :: cert_value_script(16) = 0.0_real64
    logical :: mass_defect_script(16) = .false.
    real(real64) :: dt_seen(16) = 0.0_real64
  contains
    procedure :: advance => scripted_advance
    procedure :: storage => scripted_storage
    procedure :: temporal_error => scripted_temporal_error
    procedure :: storage_accounting_status => scripted_storage_status
    procedure :: attempt_context_required => scripted_no_context
  end type scripted_model_t

contains

  subroutine scripted_clone(self, copy)
    class(scripted_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(scripted_state_t :: copy)
    select type(copy)
    type is(scripted_state_t)
      copy%water = self%water
    end select
  end subroutine scripted_clone

  subroutine scripted_advance(self, state, t0, t1, outcome)
    class(scripted_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water
    integer :: idx

    self%calls = self%calls + 1
    idx = self%calls
    if (idx > size(self%dt_seen)) error stop 'ELASTIC58 scripted model call overflow'
    dt = t1-t0
    self%dt_seen(idx) = dt
    outcome = trial_outcome_t()
    outcome%solver_ok = self%solver_ok_script(idx)
    outcome%temporal_certificate_available = self%cert_available_script(idx)
    outcome%temporal_indicator = self%cert_value_script(idx)
    outcome%nonlinear_iterations = 2
    outcome%headcalc_calls = 2
    outcome%jacobian_builds = 2
    outcome%linear_solves = 3
    outcome%backtracking_attempts = 1
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    if (.not. outcome%solver_ok) return
    select type(state)
    type is(scripted_state_t)
      start_water = state%water
      state%water = start_water-dt
      outcome%mass_out = dt
      if (self%mass_defect_script(idx)) outcome%mass_out = outcome%mass_out+1.0e-3_real64
    class default
      error stop 'ELASTIC58 unexpected state type'
    end select
  end subroutine scripted_advance

  function scripted_storage(self, state) result(value)
    class(scripted_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%calls < -1) error stop 'unreachable'
    select type(state)
    type is(scripted_state_t)
      value = state%water
    class default
      error stop 'ELASTIC58 unexpected state type storage'
    end select
  end function scripted_storage

  function scripted_temporal_error(self, full_state, half_state) result(value)
    class(scripted_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    if (self%calls < -1 .or. .not. same_type_as(full_state, half_state)) error stop 'unreachable'
    value = 0.0_real64
  end function scripted_temporal_error

  subroutine scripted_storage_status(self, state, complete, missing_mask)
    class(scripted_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%calls < -1 .or. .not. same_type_as(state,state)) error stop 'unreachable'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine scripted_storage_status

  logical function scripted_no_context(self) result(required)
    class(scripted_model_t), intent(in) :: self
    if (self%calls < -1) error stop 'unreachable'
    required = .false.
  end function scripted_no_context

end module mod_fpe_elastic58_scripted_model

program test_fpe_elastic58_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_fpe_elastic58_scripted_model
  implicit none

  call test_immediate_accept()
  call test_retry_accept()
  call test_nonmonotone_retry()
  call test_unavailable_fail_closed()
  call test_mass_precedes_certificate()
  call test_retry_exhaustion()
  write(*,'(A)') 'F_PE_ELASTIC58_TRANSACTION=PASS'

contains

  subroutine new_state(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(scripted_state_t :: state)
    select type(state)
    type is(scripted_state_t)
      state%water=water
    end select
  end subroutine new_state

  real(real64) function water_of(state)
    class(transaction_state_t), allocatable, intent(in) :: state
    select type(state)
    type is(scripted_state_t)
      water_of=state%water
    class default
      error stop 'ELASTIC58 state type'
    end select
  end function water_of

  subroutine init_policy(policy,maxr)
    type(transaction_policy_t), intent(out) :: policy
    integer, intent(in) :: maxr
    policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    policy%temporal_tolerance=1.0_real64
    policy%mass_tolerance=1.0e-12_real64
    policy%retry_scale=0.5_real64
    policy%max_retries=maxr
  end subroutine init_policy

  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC58_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine test_immediate_accept()
    class(transaction_state_t),allocatable::state
    type(scripted_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(state,1.0_real64); call init_policy(p,3)
    m%cert_value_script(1)=0.5_real64
    call execute_reference_interval(m,state,0.0_real64,0.4_real64,p,r)
    call require(r%status==TX_STATUS_ACCEPTED,'A1 accepted')
    call require(r%accepted_route==TX_ROUTE_MODEL_CERTIFIED,'A1 route')
    call require(r%full_trials==1.and.r%half_trials==0,'A1 one full no halves')
    call require(r%commits==1.and.r%rollbacks==0,'A1 commit')
    call require(abs(water_of(state)-0.6_real64)<=1e-15_real64,'A1 endpoint')
    write(*,'(A)')'F_PE_ELASTIC58_A1_IMMEDIATE=PASS'
  end subroutine

  subroutine test_retry_accept()
    class(transaction_state_t),allocatable::state
    type(scripted_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(state,1.0_real64); call init_policy(p,3)
    m%cert_value_script(1)=2.0_real64; m%cert_value_script(2)=0.5_real64
    call execute_reference_interval(m,state,0.0_real64,0.4_real64,p,r)
    call require(r%status==TX_STATUS_ACCEPTED.and.r%temporal_rejections==1,'A2 retry accepted')
    call require(r%retries==1.and.r%rollbacks==1,'A2 accounting')
    call require(abs(m%dt_seen(1)-0.4_real64)<=1e-15_real64.and.abs(m%dt_seen(2)-0.2_real64)<=1e-15_real64,'A2 halving')
    write(*,'(A)')'F_PE_ELASTIC58_A2_RETRY=PASS'
  end subroutine

  subroutine test_nonmonotone_retry()
    class(transaction_state_t),allocatable::state
    type(scripted_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(state,1.0_real64); call init_policy(p,4)
    m%cert_value_script(1)=2.0_real64; m%cert_value_script(2)=3.0_real64; m%cert_value_script(3)=0.5_real64
    call execute_reference_interval(m,state,0.0_real64,0.8_real64,p,r)
    call require(r%status==TX_STATUS_ACCEPTED.and.r%temporal_rejections==2,'A3 nonmono accepted')
    call require(abs(m%dt_seen(1)-0.8_real64)<=1e-15_real64.and.abs(m%dt_seen(2)-0.4_real64)<=1e-15_real64.and.abs(m%dt_seen(3)-0.2_real64)<=1e-15_real64,'A3 one-way')
    write(*,'(A)')'F_PE_ELASTIC58_A3_NONMONOTONE=PASS'
  end subroutine

  subroutine test_unavailable_fail_closed()
    class(transaction_state_t),allocatable::state
    type(scripted_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(state,1.0_real64); call init_policy(p,2)
    m%cert_available_script(1:3)=.false.
    call execute_reference_interval(m,state,0.0_real64,0.4_real64,p,r)
    call require(r%status==TX_STATUS_RETRY_EXHAUSTED,'A4 exhausted')
    call require(r%temporal_certificate_unavailable_rejections==3.and.r%temporal_rejections==3,'A4 unavailable counters')
    call require(r%commits==0.and.abs(water_of(state)-1.0_real64)<=0.0_real64,'A4 rollback')
    write(*,'(A)')'F_PE_ELASTIC58_A4_UNAVAILABLE=PASS'
  end subroutine

  subroutine test_mass_precedes_certificate()
    class(transaction_state_t),allocatable::state
    type(scripted_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(state,1.0_real64); call init_policy(p,1)
    m%cert_value_script(1:2)=0.1_real64
    m%mass_defect_script(1:2)=.true.
    call execute_reference_interval(m,state,0.0_real64,0.4_real64,p,r)
    call require(r%status==TX_STATUS_RETRY_EXHAUSTED.and.r%mass_rejections==2,'A5 mass rejected')
    call require(r%temporal_rejections==0.and.r%commits==0,'A5 mass before temporal commit')
    call require(abs(water_of(state)-1.0_real64)<=0.0_real64,'A5 rollback')
    write(*,'(A)')'F_PE_ELASTIC58_A5_MASS=PASS'
  end subroutine

  subroutine test_retry_exhaustion()
    class(transaction_state_t),allocatable::state
    type(scripted_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(state,1.0_real64); call init_policy(p,2)
    m%cert_value_script(1:3)=2.0_real64
    call execute_reference_interval(m,state,0.0_real64,0.8_real64,p,r)
    call require(r%status==TX_STATUS_RETRY_EXHAUSTED.and.r%commits==0,'A6 exhausted no commit')
    call require(r%attempts==3.and.r%retries==2.and.r%rollbacks==3,'A6 accounting')
    call require(abs(water_of(state)-1.0_real64)<=0.0_real64,'A6 checkpoint preserved')
    write(*,'(A)')'F_PE_ELASTIC58_A6_EXHAUSTION=PASS'
  end subroutine

end program test_fpe_elastic58_transaction

module mod_f_rom0ta3_tx_fixture
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference
  implicit none

  type, extends(transaction_state_t) :: floor_state_t
    real(real64) :: water = 1.0_real64
  contains
    procedure :: clone => floor_clone
  end type floor_state_t

  type, extends(transaction_model_t) :: floor_model_t
    logical :: fail_solver = .false.
    logical :: fail_mass = .false.
    integer :: calls = 0
  contains
    procedure :: advance => floor_advance
    procedure :: storage => floor_storage
    procedure :: temporal_error => floor_temporal_error
    procedure :: storage_accounting_status => floor_storage_status
  end type floor_model_t

contains

  subroutine floor_clone(self, copy)
    class(floor_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(floor_state_t :: copy)
    select type (typed => copy)
    type is (floor_state_t)
      typed%water = self%water
    end select
  end subroutine floor_clone

  subroutine floor_advance(self, state, t0, t1, outcome)
    class(floor_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, before
    outcome = trial_outcome_t()
    self%calls = self%calls + 1
    dt = t1-t0
    select type (typed => state)
    type is (floor_state_t)
      before = typed%water
      typed%water = before - 0.1_real64*dt
      outcome%mass_out = before-typed%water
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%solver_ok = .not. self%fail_solver
      outcome%nonlinear_iterations = 3
      outcome%linear_solves = 3
      if (self%fail_mass) outcome%mass_out = outcome%mass_out + 1.0e-4_real64
    class default
      error stop 'floor fixture wrong state'
    end select
  end subroutine floor_advance

  real(real64) function floor_storage(self, state) result(value)
    class(floor_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%calls < -1) error stop 'unreachable'
    select type (typed => state)
    type is (floor_state_t)
      value = typed%water
    class default
      value = huge(0.0_real64)
    end select
  end function floor_storage

  real(real64) function floor_temporal_error(self, full_state, half_state) result(value)
    class(floor_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    value = huge(0.0_real64)
    if (self%calls < -1 .or. .not. same_type_as(full_state,half_state)) error stop 'unreachable'
  end function floor_temporal_error

  subroutine floor_storage_status(self, state, complete, missing_mask)
    class(floor_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = same_type_as(state,state)
    missing_mask = merge(TX_MASS_MISSING_NONE,TX_MASS_MISSING_UNSPECIFIED,complete)
    if (self%calls < -1) error stop 'unreachable'
  end subroutine floor_storage_status

  subroutine new_floor_state(state)
    class(transaction_state_t), allocatable, intent(out) :: state
    allocate(floor_state_t :: state)
  end subroutine new_floor_state

  real(real64) function water_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    select type (typed => state)
    type is (floor_state_t)
      value = typed%water
    class default
      error stop 'floor fixture wrong committed state'
    end select
  end function water_of
end module mod_f_rom0ta3_tx_fixture

program test_f_rom0ta3_reference_floor_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_f_rom0ta3_tx_fixture
  implicit none
  integer :: failures
  failures = 0
  call pass_case(failures)
  call solver_fail_case(failures)
  call mass_fail_case(failures)
  if (failures /= 0) error stop 1
  write(*,'(A)') 'F_ROM0TA3_TRANSACTION_GATE=PASS'
contains
  subroutine check(x,label,failures)
    logical,intent(in) :: x
    character(len=*),intent(in) :: label
    integer,intent(inout) :: failures
    if(.not.x) then
      failures=failures+1
      write(*,'(A,1X,A)') 'F_ROM0TA3_FAIL',trim(label)
    end if
  end subroutine check

  subroutine base_policy(policy)
    type(transaction_policy_t),intent(out) :: policy
    policy=transaction_policy_t()
    policy%temporal_mode=TX_TEMPORAL_REFERENCE_FLOOR_FIXED_RESOLUTION
    policy%temporal_tolerance=0.0_real64
    policy%mass_tolerance=1.0e-12_real64
    policy%retry_scale=0.5_real64
    policy%max_retries=7
  end subroutine base_policy

  subroutine pass_case(failures)
    integer,intent(inout) :: failures
    class(transaction_state_t),allocatable :: state
    type(floor_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    call new_floor_state(state)
    call base_policy(policy)
    call execute_reference_interval(model,state,2.0_real64,2.25_real64,policy,result)
    call check(result%status==TX_STATUS_ACCEPTED,'pass accepted',failures)
    call check(result%accepted_route==TX_ROUTE_REFERENCE_FLOOR_FIXED,'pass route',failures)
    call check(result%temporal_acceptance_source==TX_TEMPORAL_REFERENCE_FLOOR_FIXED_RESOLUTION,'pass source',failures)
    call check(result%attempts==1 .and. result%retries==0 .and. result%rollbacks==0,'pass no retry',failures)
    call check(result%commits==1 .and. result%full_trials==1 .and. result%half_trials==0,'pass one trial one commit',failures)
    call check(abs(result%accepted_dt-0.25_real64)<=epsilon(1.0_real64),'pass exact requested dt',failures)
    call check(abs(result%accepted_mass_residual)<=1.0e-12_real64 .and. result%accepted_mass_complete,'pass mass',failures)
    call check(abs(water_of(state)-0.975_real64)<=16.0_real64*epsilon(1.0_real64),'pass endpoint',failures)
    call check(model%calls==1,'pass exactly one model advance',failures)
    write(*,'(A)') 'F_ROM0TA3_FIXED_SAMPLE_ACCEPT=PASS'
  end subroutine pass_case

  subroutine solver_fail_case(failures)
    integer,intent(inout) :: failures
    class(transaction_state_t),allocatable :: state
    type(floor_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    call new_floor_state(state)
    call base_policy(policy)
    model%fail_solver=.true.
    call execute_reference_interval(model,state,0.0_real64,1.0_real64,policy,result)
    call check(result%status==TX_STATUS_FIXED_SAMPLE_REJECTED,'solver fail status',failures)
    call check(result%attempts==1 .and. result%retries==0 .and. result%rollbacks==1,'solver fail no retry',failures)
    call check(result%commits==0 .and. model%calls==1,'solver fail no commit',failures)
    call check(abs(water_of(state)-1.0_real64)<=0.0_real64,'solver fail no state leak',failures)
    write(*,'(A)') 'F_ROM0TA3_SOLVER_FAILURE_NO_DT_REDUCTION=PASS'
  end subroutine solver_fail_case

  subroutine mass_fail_case(failures)
    integer,intent(inout) :: failures
    class(transaction_state_t),allocatable :: state
    type(floor_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    call new_floor_state(state)
    call base_policy(policy)
    model%fail_mass=.true.
    call execute_reference_interval(model,state,0.0_real64,1.0_real64,policy,result)
    call check(result%status==TX_STATUS_FIXED_SAMPLE_REJECTED,'mass fail status',failures)
    call check(result%mass_rejections==1,'mass fail counted',failures)
    call check(result%attempts==1 .and. result%retries==0 .and. result%rollbacks==1,'mass fail no retry',failures)
    call check(result%commits==0 .and. model%calls==1,'mass fail no commit',failures)
    call check(abs(water_of(state)-1.0_real64)<=0.0_real64,'mass fail no state leak',failures)
    write(*,'(A)') 'F_ROM0TA3_MASS_FAILURE_NO_DT_REDUCTION=PASS'
  end subroutine mass_fail_case
end program test_f_rom0ta3_reference_floor_transaction

module fvq67_attack_support
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t, &
       transaction_policy_t, transaction_result_t, execute_reference_interval, &
       TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, TX_ROUTE_NONE, TX_ROUTE_MODEL_CERTIFIED, &
       TX_ROUTE_TWO_HALF, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_ACTIVE_CONTRIBUTION
  implicit none
  private
  public :: run_all_fvq67_tests

  integer, parameter :: SC_GOOD = 1
  integer, parameter :: SC_INCOMPLETE_ZERO = 2
  integer, parameter :: SC_NONZERO_MASK = 3
  integer, parameter :: SC_RESIDUAL_OUTSIDE = 4
  integer, parameter :: SC_NAN_MASS = 5
  integer, parameter :: SC_INF_MASS = 6
  integer, parameter :: SC_ALT_INCOMPLETE = 7
  integer, parameter :: SC_SECOND_HALF_INCOMPLETE = 8

  type, extends(transaction_state_t) :: vq67_state_t
    real(real64) :: water = 0.0_real64
    integer(int64) :: sentinel = 0_int64
  contains
    procedure :: clone => vq67_clone
  end type vq67_state_t

  type, extends(transaction_model_t) :: vq67_model_t
    integer :: scenario = SC_GOOD
    integer :: advance_calls = 0
  contains
    procedure :: advance => vq67_advance
    procedure :: storage => vq67_storage
    procedure :: temporal_error => vq67_temporal_error
    procedure :: storage_accounting_status => vq67_storage_accounting_status
  end type vq67_model_t

contains

  subroutine run_all_fvq67_tests()
    call reject_case(SC_INCOMPLETE_ZERO, TX_TEMPORAL_EXTERNAL_FULL_HALF, 'INCOMPLETE_ZERO_EXTERNAL', .false.)
    call reject_case(SC_INCOMPLETE_ZERO, TX_TEMPORAL_MODEL_CERTIFICATE, 'INCOMPLETE_ZERO_CERTIFICATE', .false.)
    call reject_case(SC_NONZERO_MASK, TX_TEMPORAL_EXTERNAL_FULL_HALF, 'NONZERO_MASK_EXTERNAL', .false.)
    call reject_case(SC_NONZERO_MASK, TX_TEMPORAL_MODEL_CERTIFICATE, 'NONZERO_MASK_CERTIFICATE', .false.)
    call reject_case(SC_RESIDUAL_OUTSIDE, TX_TEMPORAL_EXTERNAL_FULL_HALF, 'RESIDUAL_OUTSIDE_EXTERNAL', .false.)
    call reject_case(SC_RESIDUAL_OUTSIDE, TX_TEMPORAL_MODEL_CERTIFICATE, 'RESIDUAL_OUTSIDE_CERTIFICATE', .false.)
    call reject_case(SC_NAN_MASS, TX_TEMPORAL_EXTERNAL_FULL_HALF, 'NAN_MASS_EXTERNAL', .false.)
    call reject_case(SC_NAN_MASS, TX_TEMPORAL_MODEL_CERTIFICATE, 'NAN_MASS_CERTIFICATE', .false.)
    call reject_case(SC_INF_MASS, TX_TEMPORAL_EXTERNAL_FULL_HALF, 'INF_MASS_EXTERNAL', .false.)
    call reject_case(SC_INF_MASS, TX_TEMPORAL_MODEL_CERTIFICATE, 'INF_MASS_CERTIFICATE', .false.)
    call reject_case(SC_ALT_INCOMPLETE, TX_TEMPORAL_EXTERNAL_FULL_HALF, 'ALT_INCOMPLETE_EXTERNAL', .true.)
    call reject_case(SC_ALT_INCOMPLETE, TX_TEMPORAL_MODEL_CERTIFICATE, 'ALT_INCOMPLETE_CERTIFICATE', .true.)
    call reject_case(SC_SECOND_HALF_INCOMPLETE, TX_TEMPORAL_EXTERNAL_FULL_HALF, 'SECOND_HALF_INCOMPLETE_EXTERNAL', .false.)

    call accept_case(TX_TEMPORAL_EXTERNAL_FULL_HALF, 'COMPLETE_EXTERNAL')
    call accept_case(TX_TEMPORAL_MODEL_CERTIFICATE, 'COMPLETE_CERTIFICATE')
    call generic_time_case(TX_TEMPORAL_EXTERNAL_FULL_HALF, 'GENERIC_TIME_EXTERNAL')
    call generic_time_case(TX_TEMPORAL_MODEL_CERTIFICATE, 'GENERIC_TIME_CERTIFICATE')

    print '(a)', 'FVQ67_ZERO_RESIDUAL_INCOMPLETE_FAIL_CLOSED=PASS'
    print '(a)', 'FVQ67_NONZERO_MISSING_MASK_FAIL_CLOSED=PASS'
    print '(a)', 'FVQ67_COMPLETE_IN_TOLERANCE_ACCEPTS=PASS'
    print '(a)', 'FVQ67_COMPLETE_OUTSIDE_TOLERANCE_REJECTS=PASS'
    print '(a)', 'FVQ67_NONFINITE_MASS_FAIL_CLOSED=PASS'
    print '(a)', 'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS'
    print '(a)', 'FVQ67_RETRY_NO_PHYSICAL_ACCUMULATION=PASS'
    print '(a)', 'FVQ67_RETRY_EXHAUSTION_FAIL_CLOSED=PASS'
    print '(a)', 'FVQ67_INCOMPLETE_CANNOT_MATERIALIZE_ACCEPTED_CANDIDATE=PASS'
    print '(a)', 'FVQ67_NORMAL_COMPLETE_LEDGER_PRESERVATION=PASS'
    print '(a)', 'FVQ67_ALTERNATIVE_SOLVER_INCOMPLETE_FAIL_CLOSED=PASS'
    print '(a)', 'FVQ67_SECOND_HALF_INCOMPLETE_FAIL_CLOSED=PASS'
    print '(a)', 'FVQ67_MASS_RESULT_TRANSPORT=PASS'
    print '(a)', 'FVQ67_GENERIC_TIME_TRANSACTION=PASS'
    print '(a)', 'FVQ67_ATTACK_MATRIX=PASS'
  end subroutine run_all_fvq67_tests

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'FVQ67_ASSERT_FAIL=' // trim(label)
      error stop 67
    end if
  end subroutine assert_true

  subroutine allocate_state(state, water, sentinel)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    integer(int64), intent(in) :: sentinel
    allocate(vq67_state_t :: state)
    select type (state)
    type is (vq67_state_t)
      state%water = water
      state%sentinel = sentinel
    class default
      error stop 67
    end select
  end subroutine allocate_state

  subroutine reject_case(scenario, temporal_mode, label, expect_alternative)
    integer, intent(in) :: scenario, temporal_mode
    character(len=*), intent(in) :: label
    logical, intent(in) :: expect_alternative
    type(vq67_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    integer(int64) :: water_bits_before, water_bits_after
    integer(int64), parameter :: sentinel_value = 987654321_int64

    call allocate_state(committed, 10.0_real64, sentinel_value)
    select type (committed)
    type is (vq67_state_t)
      water_bits_before = transfer(committed%water, water_bits_before)
    class default
      error stop 67
    end select

    model%scenario = scenario
    policy%temporal_mode = temporal_mode
    policy%temporal_tolerance = 0.0_real64
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 2

    call execute_reference_interval(model, committed, 0.0_real64, 1.0_real64, policy, result)

    call assert_true(result%status == TX_STATUS_RETRY_EXHAUSTED, trim(label)//':status')
    call assert_true(result%attempts == 3, trim(label)//':attempts')
    call assert_true(result%retries == 2, trim(label)//':retries')
    call assert_true(result%rollbacks == 3, trim(label)//':rollbacks')
    call assert_true(result%mass_rejections == 3, trim(label)//':mass_rejections')
    call assert_true(result%commits == 0, trim(label)//':commits')
    call assert_true(result%accepted_route == TX_ROUTE_NONE, trim(label)//':accepted_route')
    call assert_true(abs(result%accepted_dt) <= tiny(1.0_real64), trim(label)//':accepted_dt')
    call assert_true(.not. result%accepted_mass_complete, trim(label)//':accepted_mass_complete')
    if (expect_alternative) then
      call assert_true(result%alternative_solver_calls > 0, trim(label)//':alternative_solver_calls')
      call assert_true(result%accepted_alternative_solver_calls == 0, trim(label)//':accepted_alternative_solver_calls')
    end if

    select type (committed)
    type is (vq67_state_t)
      water_bits_after = transfer(committed%water, water_bits_after)
      call assert_true(water_bits_after == water_bits_before, trim(label)//':water_bitwise')
      call assert_true(committed%sentinel == sentinel_value, trim(label)//':sentinel')
    class default
      error stop 67
    end select

    write(*,'(a)') 'FVQ67_CASE_' // trim(label) // '=PASS'
  end subroutine reject_case

  subroutine accept_case(temporal_mode, label)
    integer, intent(in) :: temporal_mode
    character(len=*), intent(in) :: label
    type(vq67_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    class(transaction_state_t), allocatable :: committed

    call allocate_state(committed, 10.0_real64, 123456789_int64)
    model%scenario = SC_GOOD
    policy%temporal_mode = temporal_mode
    policy%temporal_tolerance = 0.0_real64
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 2

    call execute_reference_interval(model, committed, 0.0_real64, 1.0_real64, policy, result)

    call assert_true(result%status == TX_STATUS_ACCEPTED, trim(label)//':status')
    call assert_true(result%commits == 1, trim(label)//':commits')
    call assert_true(result%rollbacks == 0, trim(label)//':rollbacks')
    call assert_true(result%mass_rejections == 0, trim(label)//':mass_rejections')
    call assert_true(result%accepted_mass_complete, trim(label)//':accepted_mass_complete')
    call assert_true(result%accepted_missing_contribution_mask == TX_MASS_MISSING_NONE, trim(label)//':mask')
    call assert_true(abs(result%accepted_mass_residual) <= policy%mass_tolerance, trim(label)//':residual')
    call assert_true(abs(result%accepted_total_in - 1.0_real64) <= 1.0e-15_real64, trim(label)//':mass_in')
    call assert_true(abs(result%accepted_storage_change - 1.0_real64) <= 1.0e-15_real64, trim(label)//':storage_change')
    if (temporal_mode == TX_TEMPORAL_EXTERNAL_FULL_HALF) then
      call assert_true(result%accepted_route == TX_ROUTE_TWO_HALF, trim(label)//':route')
    else
      call assert_true(result%accepted_route == TX_ROUTE_MODEL_CERTIFIED, trim(label)//':route')
    end if
    select type (committed)
    type is (vq67_state_t)
      call assert_true(abs(committed%water - 11.0_real64) <= 1.0e-15_real64, trim(label)//':committed_water')
      call assert_true(committed%sentinel == 123456789_int64, trim(label)//':sentinel')
    class default
      error stop 67
    end select
    write(*,'(a)') 'FVQ67_CASE_' // trim(label) // '=PASS'
  end subroutine accept_case

  subroutine generic_time_case(temporal_mode, label)
    integer, intent(in) :: temporal_mode
    character(len=*), intent(in) :: label
    type(vq67_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64), parameter :: t0 = 2.25_real64, t1 = 3.75_real64, dt = 1.5_real64

    call allocate_state(committed, 4.0_real64, 24680_int64)
    model%scenario = SC_GOOD
    policy%temporal_mode = temporal_mode
    policy%temporal_tolerance = 0.0_real64
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 1

    call execute_reference_interval(model, committed, t0, t1, policy, result)
    call assert_true(result%status == TX_STATUS_ACCEPTED, trim(label)//':status')
    call assert_true(abs(result%requested_t0 - t0) <= 1.0e-15_real64, trim(label)//':requested_t0')
    call assert_true(abs(result%requested_t1 - t1) <= 1.0e-15_real64, trim(label)//':requested_t1')
    call assert_true(abs(result%accepted_t1 - t1) <= 1.0e-15_real64, trim(label)//':accepted_t1')
    call assert_true(abs(result%accepted_dt - dt) <= 1.0e-15_real64, trim(label)//':accepted_dt')
    select type (committed)
    type is (vq67_state_t)
      call assert_true(abs(committed%water - 5.5_real64) <= 1.0e-15_real64, trim(label)//':committed_water')
    class default
      error stop 67
    end select
    write(*,'(a)') 'FVQ67_CASE_' // trim(label) // '=PASS'
  end subroutine generic_time_case

  subroutine vq67_clone(self, copy)
    class(vq67_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(vq67_state_t :: copy)
    select type (copy)
    type is (vq67_state_t)
      copy%water = self%water
      copy%sentinel = self%sentinel
    class default
      error stop 67
    end select
  end subroutine vq67_clone

  subroutine vq67_advance(self, state, t0, t1, outcome)
    class(vq67_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    dt = t1 - t0
    self%advance_calls = self%advance_calls + 1
    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64

    select type (state)
    type is (vq67_state_t)
      state%water = state%water + dt
    class default
      error stop 67
    end select

    select case (self%scenario)
    case (SC_GOOD)
      continue
    case (SC_INCOMPLETE_ZERO)
      outcome%mass_accounting_complete = .false.
    case (SC_NONZERO_MASK)
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
    case (SC_RESIDUAL_OUTSIDE)
      outcome%mass_in = 0.0_real64
    case (SC_NAN_MASS)
      outcome%mass_in = ieee_value(0.0_real64, ieee_quiet_nan)
    case (SC_INF_MASS)
      outcome%mass_out = ieee_value(0.0_real64, ieee_positive_inf)
    case (SC_ALT_INCOMPLETE)
      outcome%mass_accounting_complete = .false.
      outcome%alternative_solver_calls = 1
    case (SC_SECOND_HALF_INCOMPLETE)
      if (t0 > 0.0_real64) outcome%mass_accounting_complete = .false.
    case default
      error stop 67
    end select
  end subroutine vq67_advance

  function vq67_storage(self, state) result(value)
    class(vq67_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%scenario < SC_GOOD) error stop 67
    select type (state)
    type is (vq67_state_t)
      value = state%water
    class default
      error stop 67
    end select
  end function vq67_storage

  subroutine vq67_storage_accounting_status(self, state, complete, missing_mask)
    class(vq67_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%scenario < SC_GOOD) error stop 67
    select type (state)
    type is (vq67_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    class default
      error stop 67
    end select
  end subroutine vq67_storage_accounting_status

  function vq67_temporal_error(self, full_state, half_state) result(value)
    class(vq67_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    if (self%scenario < SC_GOOD) error stop 67
    select type (full_state)
    type is (vq67_state_t)
      select type (half_state)
      type is (vq67_state_t)
        value = 0.0_real64
      class default
        error stop 67
      end select
    class default
      error stop 67
    end select
  end function vq67_temporal_error

end module fvq67_attack_support

program test_fvq67_mass_completeness_attack
  use fvq67_attack_support, only: run_all_fvq67_tests
  implicit none
  call run_all_fvq67_tests()
end program test_fvq67_mass_completeness_attack

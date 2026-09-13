program test_fvq65_mass_fail_closed
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, TX_ROUTE_NONE, &
       TX_ROUTE_TWO_HALF, TX_ROUTE_MODEL_CERTIFIED, TX_TEMPORAL_EXTERNAL_FULL_HALF, &
       TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE
  use fvq65_mass_attack_support
  implicit none

  call external_rejection_matrix()
  call certificate_rejection_matrix()
  call external_complete_acceptance()
  call certificate_complete_acceptance()
  call external_small_residual_acceptance()
  call certificate_small_residual_acceptance()
  call external_retry_recovery()
  call certificate_retry_recovery()
  print '(a)', 'FVQ65_INDEPENDENT_MASS_COMPLETENESS_ATTACK_MATRIX=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write (*, '(a)') 'FVQ65_FAIL:' // trim(message)
      error stop 1
    end if
  end subroutine require

  function make_policy(mode, retries) result(policy)
    integer, intent(in) :: mode, retries
    type(transaction_policy_t) :: policy
    policy%temporal_mode = mode
    policy%temporal_tolerance = 1.0e-12_real64
    policy%mass_tolerance = Q_MASS_TOL
    policy%retry_scale = 0.5_real64
    policy%max_retries = retries
  end function make_policy

  subroutine external_rejection_matrix()
    integer, parameter :: n = 14
    integer :: scenarios(n), i
    character(len=48) :: labels(n)

    scenarios = [ &
      SC_START_STORAGE_INCOMPLETE, &
      SC_START_STORAGE_MASK, &
      SC_EXT_FULL_STORAGE_INCOMPLETE, &
      SC_EXT_END_STORAGE_INCOMPLETE, &
      SC_EXT_END_STORAGE_MASK, &
      SC_EXT_FULL_OUTCOME_INCOMPLETE, &
      SC_EXT_HALF1_OUTCOME_INCOMPLETE, &
      SC_EXT_HALF2_OUTCOME_INCOMPLETE, &
      SC_EXT_FULL_OUTCOME_MASK, &
      SC_EXT_HALF1_OUTCOME_MASK, &
      SC_EXT_HALF2_OUTCOME_MASK, &
      SC_EXT_NONFINITE_FULL_MASS, &
      SC_EXT_NONFINITE_HALF2_MASS, &
      SC_LARGE_COMPLETE_RESIDUAL ]

    labels = [ character(len=48) :: &
      'start-storage-incomplete', &
      'start-storage-mask', &
      'full-storage-incomplete', &
      'accepted-storage-incomplete', &
      'accepted-storage-mask', &
      'full-outcome-incomplete', &
      'half1-outcome-incomplete', &
      'half2-outcome-incomplete', &
      'full-outcome-mask', &
      'half1-outcome-mask', &
      'half2-outcome-mask', &
      'nonfinite-full-mass', &
      'nonfinite-half2-mass', &
      'complete-residual-outside-tolerance' ]

    do i = 1, n
      call assert_external_rejected(scenarios(i), trim(labels(i)))
    end do
    print '(a,i0)', 'FVQ65_EXTERNAL_REJECTION_MATRIX_CASES=PASS:', n
  end subroutine external_rejection_matrix

  subroutine certificate_rejection_matrix()
    integer, parameter :: n = 8
    integer :: scenarios(n), i
    character(len=48) :: labels(n)

    scenarios = [ &
      SC_START_STORAGE_INCOMPLETE, &
      SC_START_STORAGE_MASK, &
      SC_CERT_END_STORAGE_INCOMPLETE, &
      SC_CERT_END_STORAGE_MASK, &
      SC_CERT_OUTCOME_INCOMPLETE, &
      SC_CERT_OUTCOME_MASK, &
      SC_CERT_NONFINITE_MASS, &
      SC_LARGE_COMPLETE_RESIDUAL ]

    labels = [ character(len=48) :: &
      'start-storage-incomplete', &
      'start-storage-mask', &
      'end-storage-incomplete', &
      'end-storage-mask', &
      'outcome-incomplete', &
      'outcome-mask', &
      'nonfinite-mass', &
      'complete-residual-outside-tolerance' ]

    do i = 1, n
      call assert_certificate_rejected(scenarios(i), trim(labels(i)), .false.)
    end do
    call assert_certificate_rejected(SC_CERT_ALT_SOLVER_INCOMPLETE, 'alternative-solver-incomplete', .true.)
    print '(a,i0)', 'FVQ65_CERTIFICATE_REJECTION_MATRIX_CASES=PASS:', n + 1
  end subroutine certificate_rejection_matrix

  subroutine assert_external_rejected(scenario, label)
    integer, intent(in) :: scenario
    character(len=*), intent(in) :: label
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64), parameter :: initial = 17.25_real64
    real(real64), parameter :: t0 = 0.37_real64
    real(real64), parameter :: t1 = 2.87_real64

    call make_state(committed, initial)
    model%route_mode = Q_ROUTE_EXTERNAL
    model%scenario = scenario
    policy = make_policy(TX_TEMPORAL_EXTERNAL_FULL_HALF, 2)
    call execute_reference_interval(model, committed, t0, t1, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, label // ': status accepted')
    call require(result%attempts == 3 .and. result%retries == 2, label // ': retry count')
    call require(result%rollbacks == 3 .and. result%mass_rejections == 3, label // ': mass rejection count')
    call require(result%commits == 0 .and. result%accepted_route == TX_ROUTE_NONE, label // ': commit reachable')
    call require(abs(state_water(committed) - initial) <= 1.0e-14_real64, label // ': committed state mutated')
    call require(abs(result%accepted_t1 - t0) <= 1.0e-14_real64, label // ': accepted time advanced')
    call require(model%advance_calls == 9, label // ': unexpected trial call count')
  end subroutine assert_external_rejected

  subroutine assert_certificate_rejected(scenario, label, expect_alternative)
    integer, intent(in) :: scenario
    character(len=*), intent(in) :: label
    logical, intent(in) :: expect_alternative
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64), parameter :: initial = -4.5_real64
    real(real64), parameter :: t0 = 1.13_real64
    real(real64), parameter :: t1 = 3.63_real64

    call make_state(committed, initial)
    model%route_mode = Q_ROUTE_CERTIFICATE
    model%scenario = scenario
    policy = make_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 1)
    call execute_reference_interval(model, committed, t0, t1, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, label // ': status accepted')
    call require(result%attempts == 2 .and. result%retries == 1, label // ': retry count')
    call require(result%rollbacks == 2 .and. result%mass_rejections == 2, label // ': mass rejection count')
    call require(result%commits == 0 .and. result%accepted_route == TX_ROUTE_NONE, label // ': commit reachable')
    call require(abs(state_water(committed) - initial) <= 1.0e-14_real64, label // ': committed state mutated')
    call require(abs(result%accepted_t1 - t0) <= 1.0e-14_real64, label // ': accepted time advanced')
    call require(model%advance_calls == 2, label // ': unexpected trial call count')
    if (expect_alternative) then
      call require(result%alternative_solver_calls == 2, label // ': alternative solver path not observed')
    end if
  end subroutine assert_certificate_rejected

  subroutine external_complete_acceptance()
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64), parameter :: initial = 8.0_real64
    real(real64), parameter :: t0 = 2.25_real64
    real(real64), parameter :: t1 = 4.75_real64

    call make_state(committed, initial)
    model%route_mode = Q_ROUTE_EXTERNAL
    model%scenario = SC_COMPLETE
    policy = make_policy(TX_TEMPORAL_EXTERNAL_FULL_HALF, 1)
    call execute_reference_interval(model, committed, t0, t1, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'complete external rejected')
    call require(result%accepted_route == TX_ROUTE_TWO_HALF .and. result%commits == 1, 'external route/commit')
    call require(result%mass_rejections == 0 .and. result%rollbacks == 0, 'external false rejection')
    call require(result%accepted_mass_complete, 'external acceptance not marked complete')
    call require(result%accepted_missing_contribution_mask == TX_MASS_MISSING_NONE, 'external accepted mask')
    call require(abs(result%accepted_mass_residual) <= Q_MASS_TOL, 'external accepted residual')
    call require(abs(state_water(committed) - (initial + t1 - t0)) <= 1.0e-13_real64, 'external committed state')
    print '(a)', 'FVQ65_COMPLETE_EXTERNAL_ACCEPTS=PASS'
  end subroutine external_complete_acceptance

  subroutine certificate_complete_acceptance()
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64), parameter :: initial = 2.0_real64
    real(real64), parameter :: t0 = 7.10_real64
    real(real64), parameter :: t1 = 8.35_real64

    call make_state(committed, initial)
    model%route_mode = Q_ROUTE_CERTIFICATE
    model%scenario = SC_COMPLETE
    policy = make_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 1)
    call execute_reference_interval(model, committed, t0, t1, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'complete certificate rejected')
    call require(result%accepted_route == TX_ROUTE_MODEL_CERTIFIED .and. result%commits == 1, 'certificate route/commit')
    call require(result%mass_rejections == 0 .and. result%rollbacks == 0, 'certificate false rejection')
    call require(result%accepted_mass_complete, 'certificate acceptance not marked complete')
    call require(result%accepted_missing_contribution_mask == TX_MASS_MISSING_NONE, 'certificate accepted mask')
    call require(abs(result%accepted_mass_residual) <= Q_MASS_TOL, 'certificate accepted residual')
    call require(abs(state_water(committed) - (initial + t1 - t0)) <= 1.0e-13_real64, 'certificate committed state')
    print '(a)', 'FVQ65_COMPLETE_CERTIFICATE_ACCEPTS=PASS'
  end subroutine certificate_complete_acceptance

  subroutine external_small_residual_acceptance()
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call make_state(committed, 1.0_real64)
    model%route_mode = Q_ROUTE_EXTERNAL
    model%scenario = SC_SMALL_COMPLETE_RESIDUAL
    policy = make_policy(TX_TEMPORAL_EXTERNAL_FULL_HALF, 0)
    call execute_reference_interval(model, committed, 0.2_real64, 1.2_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'small complete external residual rejected')
    call require(result%accepted_mass_complete, 'small external accepted ledger incomplete')
    call require(abs(result%full_mass_residual) <= Q_MASS_TOL, 'small external full residual')
    call require(abs(result%half_mass_residual) <= Q_MASS_TOL, 'small external half residual')
    print '(a)', 'FVQ65_COMPLETE_SMALL_RESIDUAL_EXTERNAL_ACCEPTS=PASS'
  end subroutine external_small_residual_acceptance

  subroutine certificate_small_residual_acceptance()
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call make_state(committed, 6.0_real64)
    model%route_mode = Q_ROUTE_CERTIFICATE
    model%scenario = SC_SMALL_COMPLETE_RESIDUAL
    policy = make_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 0)
    call execute_reference_interval(model, committed, 4.0_real64, 5.0_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'small complete certificate residual rejected')
    call require(result%accepted_mass_complete, 'small certificate accepted ledger incomplete')
    call require(abs(result%accepted_mass_residual) <= Q_MASS_TOL, 'small certificate residual')
    print '(a)', 'FVQ65_COMPLETE_SMALL_RESIDUAL_CERTIFICATE_ACCEPTS=PASS'
  end subroutine certificate_small_residual_acceptance

  subroutine external_retry_recovery()
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64), parameter :: initial = 9.75_real64
    real(real64), parameter :: t0 = 10.30_real64
    real(real64), parameter :: t1 = 12.80_real64
    real(real64), parameter :: expected_dt = 1.25_real64

    call make_state(committed, initial)
    model%route_mode = Q_ROUTE_EXTERNAL
    model%scenario = SC_EXT_RETRY_RECOVERY
    policy = make_policy(TX_TEMPORAL_EXTERNAL_FULL_HALF, 2)
    call execute_reference_interval(model, committed, t0, t1, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'external recovery did not accept')
    call require(result%attempts == 2 .and. result%retries == 1 .and. result%rollbacks == 1, 'external recovery retry accounting')
    call require(result%mass_rejections == 1 .and. result%commits == 1, 'external recovery mass/commit accounting')
    call require(abs(result%accepted_dt - expected_dt) <= 1.0e-14_real64, 'external recovery accepted dt')
    call require(abs(result%accepted_t1 - (t0 + expected_dt)) <= 1.0e-14_real64, 'external recovery accepted t1')
    call require(abs(state_water(committed) - (initial + expected_dt)) <= 1.0e-13_real64, 'external rejected trial accumulated state')
    call require(result%accepted_mass_complete, 'external recovery accepted incomplete ledger')
    print '(a)', 'FVQ65_EXTERNAL_RETRY_RECOVERY_FROM_COMMITTED_ORIGIN=PASS'
  end subroutine external_retry_recovery

  subroutine certificate_retry_recovery()
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64), parameter :: initial = -1.5_real64
    real(real64), parameter :: t0 = 20.125_real64
    real(real64), parameter :: t1 = 22.625_real64
    real(real64), parameter :: expected_dt = 1.25_real64

    call make_state(committed, initial)
    model%route_mode = Q_ROUTE_CERTIFICATE
    model%scenario = SC_CERT_RETRY_RECOVERY
    policy = make_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 2)
    call execute_reference_interval(model, committed, t0, t1, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'certificate recovery did not accept')
    call require(result%attempts == 2 .and. result%retries == 1 .and. result%rollbacks == 1, 'certificate recovery retry accounting')
    call require(result%mass_rejections == 1 .and. result%commits == 1, 'certificate recovery mass/commit accounting')
    call require(abs(result%accepted_dt - expected_dt) <= 1.0e-14_real64, 'certificate recovery accepted dt')
    call require(abs(result%accepted_t1 - (t0 + expected_dt)) <= 1.0e-14_real64, 'certificate recovery accepted t1')
    call require(abs(state_water(committed) - (initial + expected_dt)) <= 1.0e-13_real64, 'certificate rejected trial accumulated state')
    call require(result%accepted_mass_complete, 'certificate recovery accepted incomplete ledger')
    print '(a)', 'FVQ65_CERTIFICATE_RETRY_RECOVERY_FROM_COMMITTED_ORIGIN=PASS'
  end subroutine certificate_retry_recovery

end program test_fvq65_mass_fail_closed

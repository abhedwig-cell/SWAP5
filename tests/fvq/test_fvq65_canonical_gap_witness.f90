program test_fvq65_canonical_gap_witness
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_ROUTE_TWO_HALF, TX_ROUTE_MODEL_CERTIFIED, &
       TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE
  use fvq65_mass_attack_support
  implicit none

  call witness_external_incomplete_acceptance()
  call witness_certificate_mask_acceptance()
  print '(a)', 'FVQ65_CURRENT_CANONICAL_GAP_WITNESS=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write (*, '(a)') 'FVQ65_CANONICAL_WITNESS_FAIL:' // trim(message)
      error stop 1
    end if
  end subroutine require

  function make_policy(mode) result(policy)
    integer, intent(in) :: mode
    type(transaction_policy_t) :: policy
    policy%temporal_mode = mode
    policy%temporal_tolerance = 1.0e-12_real64
    policy%mass_tolerance = Q_MASS_TOL
    policy%retry_scale = 0.5_real64
    policy%max_retries = 0
  end function make_policy

  subroutine witness_external_incomplete_acceptance()
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call make_state(committed, 12.0_real64)
    model%route_mode = Q_ROUTE_EXTERNAL
    model%scenario = SC_EXT_HALF2_OUTCOME_INCOMPLETE
    policy = make_policy(TX_TEMPORAL_EXTERNAL_FULL_HALF)
    call execute_reference_interval(model, committed, 0.4_real64, 1.4_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'canonical no longer reproduces external defect')
    call require(result%accepted_route == TX_ROUTE_TWO_HALF .and. result%commits == 1, 'canonical external route/commit')
    call require(.not. result%accepted_mass_complete, 'canonical external acceptance unexpectedly marked complete')
    call require(result%accepted_missing_contribution_mask /= TX_MASS_MISSING_NONE, 'canonical external diagnostic mask stayed zero')
    call require(abs(state_water(committed) - 13.0_real64) <= 1.0e-13_real64, 'canonical external accepted state mismatch')
    print '(a)', 'FVQ65_CANONICAL_EXTERNAL_INCOMPLETE_LEDGER_ACCEPTANCE_REPRODUCED=PASS'
  end subroutine witness_external_incomplete_acceptance

  subroutine witness_certificate_mask_acceptance()
    class(transaction_state_t), allocatable :: committed
    type(qualification_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call make_state(committed, -3.0_real64)
    model%route_mode = Q_ROUTE_CERTIFICATE
    model%scenario = SC_CERT_OUTCOME_MASK
    policy = make_policy(TX_TEMPORAL_MODEL_CERTIFICATE)
    call execute_reference_interval(model, committed, 2.2_real64, 3.2_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'canonical no longer reproduces certificate defect')
    call require(result%accepted_route == TX_ROUTE_MODEL_CERTIFIED .and. result%commits == 1, 'canonical certificate route/commit')
    call require(.not. result%accepted_mass_complete, 'canonical certificate acceptance unexpectedly marked complete')
    call require(result%accepted_missing_contribution_mask /= TX_MASS_MISSING_NONE, 'canonical certificate diagnostic mask stayed zero')
    call require(abs(state_water(committed) + 2.0_real64) <= 1.0e-13_real64, 'canonical certificate accepted state mismatch')
    print '(a)', 'FVQ65_CANONICAL_CERTIFICATE_MISSING_MASK_ACCEPTANCE_REPRODUCED=PASS'
  end subroutine witness_certificate_mask_acceptance

end program test_fvq65_canonical_gap_witness

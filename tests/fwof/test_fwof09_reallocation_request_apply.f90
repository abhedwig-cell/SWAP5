program test_fwof09_reallocation_request_apply
  use iso_fortran_env, only: real64
  use mod_wofost73_reallocation, only: &
    REALLOC_OK, &
    wofost73_reallocation_parameters_t, &
    wofost73_reallocation_state_t, &
    wofost73_reallocation_biomass_t, &
    wofost73_reallocation_flux_t, &
    wofost73_reallocation_diagnostics_t, &
    evaluate_wofost73_reallocation_reference_call
  use mod_wofost_reallocation_request_apply
  implicit none

  call test_full_availability_reference_parity()
  call test_pre_activation_identity()
  call test_limited_transfer_preserves_unused_cap()
  call test_zero_availability_does_not_consume_cap()
  call test_leaf_full_depletion_scalar_edge()
  call test_combined_limited_balance()
  call test_repeat_trial_is_deterministic()
  call test_non_daily_trial_fails_closed()
  call test_invalid_availability_trial_is_atomic()
  call test_direct_apply_rejects_request_above_remaining_cap()

  print '(A)', 'FWOF09_REALLOCATION_REQUEST_APPLY_PASS'

contains

  subroutine test_full_availability_reference_parity()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate, reference_candidate
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied, reference_flux
    type(wofost73_reallocation_diagnostics_t) :: reference_diagnostics
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_trial_diagnostics_t) :: diagnostics

    call winter_wheat_stem_parameters(p)
    biomass%leaf = 500.0_real64
    biomass%stem = 1000.0_real64
    availability%leaf = 500.0_real64
    availability%stem = 1000.0_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.5_real64, &
                                            10.0_real64, 11.0_real64, candidate, request, &
                                            applied, diagnostics)
    call evaluate_wofost73_reallocation_reference_call(p, committed, biomass, 1.5_real64, &
                                                        10.0_real64, 11.0_real64, reference_candidate, &
                                                        reference_flux, reference_diagnostics)

    call assert_true('new full-availability status', diagnostics%status == WOFRAP_OK)
    call assert_true('reference full-availability status', reference_diagnostics%status == REALLOC_OK)
    call assert_state_close('full-availability candidate parity', candidate, reference_candidate)
    call assert_flux_close('full-availability flux parity', applied, reference_flux)
    call assert_close('request stem equals reference transfer', request%stem, reference_flux%stem_out)
    call assert_close('request leaf equals reference transfer', request%leaf, reference_flux%leaf_out)
  end subroutine test_full_availability_reference_parity

  subroutine test_pre_activation_identity()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_trial_diagnostics_t) :: diagnostics

    call winter_wheat_stem_parameters(p)
    biomass%stem = 1000.0_real64
    availability%stem = 1000.0_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.49_real64, &
                                            0.0_real64, 1.0_real64, candidate, request, &
                                            applied, diagnostics)

    call assert_true('pre-activation status', diagnostics%status == WOFRAP_OK)
    call assert_state_close('pre-activation state identity', candidate, committed)
    call assert_close('pre-activation request stem', request%stem, 0.0_real64)
    call assert_close('pre-activation applied stem', applied%stem_out, 0.0_real64)
  end subroutine test_pre_activation_identity

  subroutine test_limited_transfer_preserves_unused_cap()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, first_candidate, second_candidate
    type(wofost73_reallocation_biomass_t) :: biomass, limited_availability, full_availability
    type(wofost73_reallocation_flux_t) :: first_applied, second_applied
    type(wofost_reallocation_request_t) :: first_request, second_request
    type(wofost_reallocation_trial_diagnostics_t) :: first_diagnostics, second_diagnostics

    call winter_wheat_stem_parameters(p)
    biomass%stem = 1000.0_real64
    limited_availability%stem = 3.0_real64
    full_availability%stem = 1000.0_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, limited_availability, 1.5_real64, &
                                            0.0_real64, 1.0_real64, first_candidate, first_request, &
                                            first_applied, first_diagnostics)

    call assert_true('limited first status', first_diagnostics%status == WOFRAP_OK)
    call assert_true('limited first diagnostic', first_diagnostics%stem_availability_limited)
    call assert_close('limited first request', first_request%stem, 8.3_real64)
    call assert_close('limited first applied', first_applied%stem_out, 3.0_real64)
    call assert_close('limited first cumulative', first_candidate%stem_reallocated, 3.0_real64)
    call assert_close('limited first cap', first_candidate%stem_cap, 200.0_real64)
    call assert_close('limited first storage', first_applied%storage_in, 2.85_real64)
    call assert_close('limited first loss', first_applied%conversion_loss, 0.15_real64)

    call evaluate_wofost_reallocation_trial(p, first_candidate, biomass, full_availability, 1.6_real64, &
                                            1.0_real64, 2.0_real64, second_candidate, second_request, &
                                            second_applied, second_diagnostics)

    call assert_true('limited second status', second_diagnostics%status == WOFRAP_OK)
    call assert_true('limited second not limited', .not. second_diagnostics%stem_availability_limited)
    call assert_close('limited second request retains rate', second_request%stem, 8.3_real64)
    call assert_close('limited second applied', second_applied%stem_out, 8.3_real64)
    call assert_close('limited cumulative uses applied only', second_candidate%stem_reallocated, 11.3_real64)
  end subroutine test_limited_transfer_preserves_unused_cap

  subroutine test_zero_availability_does_not_consume_cap()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_trial_diagnostics_t) :: diagnostics

    call winter_wheat_stem_parameters(p)
    biomass%stem = 1000.0_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.5_real64, &
                                            0.0_real64, 1.0_real64, candidate, request, applied, diagnostics)

    call assert_true('zero availability status', diagnostics%status == WOFRAP_OK)
    call assert_true('zero availability limited', diagnostics%stem_availability_limited)
    call assert_true('zero availability activates cap', candidate%activated)
    call assert_close('zero availability cap', candidate%stem_cap, 200.0_real64)
    call assert_close('zero availability request', request%stem, 8.3_real64)
    call assert_close('zero availability applied', applied%stem_out, 0.0_real64)
    call assert_close('zero availability cumulative', candidate%stem_reallocated, 0.0_real64)
  end subroutine test_zero_availability_does_not_consume_cap

  subroutine test_leaf_full_depletion_scalar_edge()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_trial_diagnostics_t) :: diagnostics

    p%activation_dvs = 1.0_real64
    p%leaf_fraction = 1.0_real64
    p%leaf_rate = 1.0_real64
    p%efficiency = 0.8_real64
    biomass%leaf = 10.0_real64
    availability%leaf = 10.0_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.0_real64, &
                                            0.0_real64, 1.0_real64, candidate, request, applied, diagnostics)

    call assert_true('leaf full depletion status', diagnostics%status == WOFRAP_OK)
    call assert_true('leaf full depletion not limited', .not. diagnostics%leaf_availability_limited)
    call assert_close('leaf full depletion request', request%leaf, 10.0_real64)
    call assert_close('leaf full depletion applied', applied%leaf_out, 10.0_real64)
    call assert_close('leaf full depletion cumulative', candidate%leaf_reallocated, 10.0_real64)
    call assert_close('leaf full depletion cap', candidate%leaf_cap, 10.0_real64)
    call assert_close('leaf full depletion storage', applied%storage_in, 8.0_real64)
    call assert_close('leaf full depletion loss', applied%conversion_loss, 2.0_real64)
    call assert_close('leaf full depletion balance', diagnostics%dry_matter_residual, 0.0_real64)
  end subroutine test_leaf_full_depletion_scalar_edge

  subroutine test_combined_limited_balance()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_trial_diagnostics_t) :: diagnostics

    p%activation_dvs = 1.0_real64
    p%leaf_fraction = 0.5_real64
    p%stem_fraction = 0.4_real64
    p%leaf_rate = 0.2_real64
    p%stem_rate = 0.25_real64
    p%efficiency = 0.7_real64
    biomass%leaf = 100.0_real64
    biomass%stem = 200.0_real64
    availability%leaf = 3.0_real64
    availability%stem = 7.0_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.0_real64, &
                                            0.0_real64, 1.0_real64, candidate, request, applied, diagnostics)

    call assert_true('combined status', diagnostics%status == WOFRAP_OK)
    call assert_true('combined leaf limited', diagnostics%leaf_availability_limited)
    call assert_true('combined stem limited', diagnostics%stem_availability_limited)
    call assert_close('combined leaf request', request%leaf, 10.0_real64)
    call assert_close('combined stem request', request%stem, 20.0_real64)
    call assert_close('combined leaf applied', applied%leaf_out, 3.0_real64)
    call assert_close('combined stem applied', applied%stem_out, 7.0_real64)
    call assert_close('combined storage', applied%storage_in, 7.0_real64)
    call assert_close('combined loss', applied%conversion_loss, 3.0_real64)
    call assert_close('combined leaf cumulative', candidate%leaf_reallocated, 3.0_real64)
    call assert_close('combined stem cumulative', candidate%stem_reallocated, 7.0_real64)
    call assert_close('combined balance', diagnostics%dry_matter_residual, 0.0_real64)
  end subroutine test_combined_limited_balance

  subroutine test_repeat_trial_is_deterministic()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate_a, candidate_b
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied_a, applied_b
    type(wofost_reallocation_request_t) :: request_a, request_b
    type(wofost_reallocation_trial_diagnostics_t) :: diagnostics_a, diagnostics_b

    call winter_wheat_stem_parameters(p)
    biomass%stem = 1000.0_real64
    availability%stem = 2.5_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.5_real64, &
                                            4.0_real64, 5.0_real64, candidate_a, request_a, &
                                            applied_a, diagnostics_a)
    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.5_real64, &
                                            4.0_real64, 5.0_real64, candidate_b, request_b, &
                                            applied_b, diagnostics_b)

    call assert_state_close('repeat candidate', candidate_a, candidate_b)
    call assert_close('repeat request leaf', request_a%leaf, request_b%leaf)
    call assert_close('repeat request stem', request_a%stem, request_b%stem)
    call assert_flux_close('repeat applied', applied_a, applied_b)
    call assert_true('repeat status', diagnostics_a%status == diagnostics_b%status)
    call assert_true('repeat stem limit', &
                     diagnostics_a%stem_availability_limited .eqv. diagnostics_b%stem_availability_limited)
  end subroutine test_repeat_trial_is_deterministic

  subroutine test_non_daily_trial_fails_closed()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_trial_diagnostics_t) :: diagnostics

    call winter_wheat_stem_parameters(p)
    biomass%stem = 1000.0_real64
    availability%stem = 1000.0_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.5_real64, &
                                            0.0_real64, 0.5_real64, candidate, request, applied, diagnostics)

    call assert_true('non-daily status', diagnostics%status == WOFRAP_UNADMITTED_DURATION)
    call assert_state_close('non-daily state atomic', candidate, committed)
    call assert_close('non-daily request reset', request%stem, 0.0_real64)
    call assert_close('non-daily applied reset', applied%stem_out, 0.0_real64)
  end subroutine test_non_daily_trial_fails_closed

  subroutine test_invalid_availability_trial_is_atomic()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_trial_diagnostics_t) :: diagnostics

    call winter_wheat_stem_parameters(p)
    biomass%stem = 1000.0_real64
    availability%stem = -1.0_real64

    call evaluate_wofost_reallocation_trial(p, committed, biomass, availability, 1.5_real64, &
                                            0.0_real64, 1.0_real64, candidate, request, applied, diagnostics)

    call assert_true('invalid availability status', diagnostics%status == WOFRAP_INVALID_AVAILABILITY)
    call assert_state_close('invalid availability state atomic', candidate, committed)
    call assert_close('invalid availability request reset', request%stem, 0.0_real64)
    call assert_close('invalid availability applied reset', applied%stem_out, 0.0_real64)
  end subroutine test_invalid_availability_trial_is_atomic

  subroutine test_direct_apply_rejects_request_above_remaining_cap()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, requested_state, candidate
    type(wofost73_reallocation_biomass_t) :: biomass, availability
    type(wofost73_reallocation_flux_t) :: applied
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_request_diagnostics_t) :: request_diagnostics
    type(wofost_reallocation_apply_diagnostics_t) :: apply_diagnostics

    call winter_wheat_stem_parameters(p)
    biomass%stem = 1000.0_real64
    availability%stem = 1000.0_real64

    call evaluate_wofost_reallocation_request(p, committed, biomass, 1.5_real64, &
                                              0.0_real64, 1.0_real64, requested_state, &
                                              request, request_diagnostics)
    call assert_true('direct request setup status', request_diagnostics%status == WOFRAP_OK)

    request%stem = requested_state%stem_cap + 1.0_real64
    call apply_wofost_reallocation_request(p, requested_state, request, availability, &
                                           candidate, applied, apply_diagnostics)

    call assert_true('direct invalid request status', apply_diagnostics%status == WOFRAP_INVALID_REQUEST)
    call assert_state_close('direct invalid request no apply-state mutation', candidate, requested_state)
    call assert_close('direct invalid request no applied flux', applied%stem_out, 0.0_real64)
  end subroutine test_direct_apply_rejects_request_above_remaining_cap

  subroutine winter_wheat_stem_parameters(p)
    type(wofost73_reallocation_parameters_t), intent(out) :: p

    p = wofost73_reallocation_parameters_t()
    p%activation_dvs = 1.5_real64
    p%stem_fraction = 0.2_real64
    p%leaf_fraction = 0.0_real64
    p%stem_rate = 0.0415_real64
    p%leaf_rate = 0.0_real64
    p%efficiency = 0.95_real64
  end subroutine winter_wheat_stem_parameters

  subroutine assert_state_close(label, actual, expected)
    character(len=*), intent(in) :: label
    type(wofost73_reallocation_state_t), intent(in) :: actual, expected

    call assert_true(trim(label)//' activated', actual%activated .eqv. expected%activated)
    call assert_close(trim(label)//' leaf cap', actual%leaf_cap, expected%leaf_cap)
    call assert_close(trim(label)//' stem cap', actual%stem_cap, expected%stem_cap)
    call assert_close(trim(label)//' leaf cumulative', actual%leaf_reallocated, expected%leaf_reallocated)
    call assert_close(trim(label)//' stem cumulative', actual%stem_reallocated, expected%stem_reallocated)
  end subroutine assert_state_close

  subroutine assert_flux_close(label, actual, expected)
    character(len=*), intent(in) :: label
    type(wofost73_reallocation_flux_t), intent(in) :: actual, expected

    call assert_close(trim(label)//' leaf', actual%leaf_out, expected%leaf_out)
    call assert_close(trim(label)//' stem', actual%stem_out, expected%stem_out)
    call assert_close(trim(label)//' storage', actual%storage_in, expected%storage_in)
    call assert_close(trim(label)//' loss', actual%conversion_loss, expected%conversion_loss)
  end subroutine assert_flux_close

  subroutine assert_close(label, actual, expected)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: actual, expected
    real(real64), parameter :: atol = 1.0e-12_real64
    real(real64), parameter :: rtol = 1.0e-12_real64
    real(real64) :: scale

    scale = max(1.0_real64, abs(actual), abs(expected))
    if (abs(actual - expected) > atol + rtol * scale) then
      write (*, '(A,2ES24.15)') trim(label)//' mismatch: ', actual, expected
      error stop 1
    end if
  end subroutine assert_close

  subroutine assert_true(label, condition)
    character(len=*), intent(in) :: label
    logical, intent(in) :: condition

    if (.not. condition) then
      write (*, '(A)') trim(label)//' failed'
      error stop 1
    end if
  end subroutine assert_true

end program test_fwof09_reallocation_request_apply

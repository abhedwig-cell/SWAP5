program test_fwof10_leaf_cohort_apply
  use iso_fortran_env, only: real64
  use mod_wofost73_reallocation, only: &
    wofost73_reallocation_parameters_t, &
    wofost73_reallocation_state_t, &
    wofost73_reallocation_biomass_t, &
    wofost73_reallocation_flux_t
  use mod_wofost_reallocation_request_apply, only: &
    WOFRAP_OK, &
    wofost_reallocation_request_t, &
    wofost_reallocation_trial_diagnostics_t, &
    evaluate_wofost_reallocation_trial
  use mod_wofost_leaf_cohort_reallocation
  implicit none

  call test_interior_reference_formula()
  call test_zero_transfer_identity()
  call test_full_depletion_equality_edge()
  call test_excess_transfer_fails_closed()
  call test_negative_cohort_fails_closed()
  call test_negative_applied_fails_closed()
  call test_zero_size_cohort_set()
  call test_relative_proportions_preserved()
  call test_awkward_floating_point_closure()
  call test_layout_is_not_legacy_366_bound()
  call test_fwof09_limited_leaf_composition()

  print '(A)', 'FWOF10_LEAF_COHORT_APPLY_PASS'

contains

  subroutine test_interior_reference_formula()
    real(real64) :: weights(3), candidate(3), expected(3), factor
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [10.0_real64, 20.0_real64, 30.0_real64]
    factor = (60.0_real64 - 12.0_real64) / 60.0_real64
    expected = weights * factor

    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 12.0_real64, &
                                                              candidate, diagnostics)

    call assert_true('interior status', diagnostics%status == WOFLEAF_OK)
    call assert_vector_close('interior PCSE formula', candidate, expected)
    call assert_close('interior available', diagnostics%available, 60.0_real64)
    call assert_close('interior applied', diagnostics%applied, 12.0_real64)
    call assert_close('interior scale', diagnostics%scale, factor)
    call assert_close('interior removed', diagnostics%removed, 12.0_real64)
    call assert_true('interior closure', &
                     abs(diagnostics%mass_residual) <= diagnostics%closure_tolerance)
  end subroutine test_interior_reference_formula

  subroutine test_zero_transfer_identity()
    real(real64) :: weights(3), candidate(3)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [1.25_real64, 0.0_real64, 8.75_real64]
    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 0.0_real64, &
                                                              candidate, diagnostics)

    call assert_true('zero transfer status', diagnostics%status == WOFLEAF_OK)
    call assert_vector_close('zero transfer identity', candidate, weights)
    call assert_close('zero transfer scale', diagnostics%scale, 1.0_real64)
    call assert_close('zero transfer removed', diagnostics%removed, 0.0_real64)
  end subroutine test_zero_transfer_identity

  subroutine test_full_depletion_equality_edge()
    real(real64) :: weights(3), candidate(3)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [1.0_real64, 2.0_real64, 5.0_real64]
    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 8.0_real64, &
                                                              candidate, diagnostics)

    call assert_true('full depletion status', diagnostics%status == WOFLEAF_OK)
    call assert_vector_close('full depletion zeros', candidate, 0.0_real64 * weights)
    call assert_close('full depletion scale', diagnostics%scale, 0.0_real64)
    call assert_close('full depletion removed', diagnostics%removed, 8.0_real64)
    call assert_close('full depletion residual', diagnostics%mass_residual, 0.0_real64)
  end subroutine test_full_depletion_equality_edge

  subroutine test_excess_transfer_fails_closed()
    real(real64) :: weights(2), candidate(2)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [1.0_real64, 2.0_real64]
    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 3.1_real64, &
                                                              candidate, diagnostics)

    call assert_true('excess status', diagnostics%status == WOFLEAF_TRANSFER_EXCEEDS_AVAILABLE)
    call assert_vector_close('excess fail closed', candidate, weights)
  end subroutine test_excess_transfer_fails_closed

  subroutine test_negative_cohort_fails_closed()
    real(real64) :: weights(3), candidate(3)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [1.0_real64, -0.1_real64, 2.0_real64]
    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 0.5_real64, &
                                                              candidate, diagnostics)

    call assert_true('negative cohort status', diagnostics%status == WOFLEAF_INVALID_COHORT_BIOMASS)
    call assert_vector_close('negative cohort fail closed', candidate, weights)
  end subroutine test_negative_cohort_fails_closed

  subroutine test_negative_applied_fails_closed()
    real(real64) :: weights(2), candidate(2)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [1.0_real64, 2.0_real64]
    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, -0.1_real64, &
                                                              candidate, diagnostics)

    call assert_true('negative applied status', diagnostics%status == WOFLEAF_INVALID_APPLIED_TRANSFER)
    call assert_vector_close('negative applied fail closed', candidate, weights)
  end subroutine test_negative_applied_fails_closed

  subroutine test_zero_size_cohort_set()
    real(real64), allocatable :: weights(:), candidate(:)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    allocate(weights(0), candidate(0))

    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 0.0_real64, &
                                                              candidate, diagnostics)
    call assert_true('zero-size zero transfer status', diagnostics%status == WOFLEAF_OK)
    call assert_close('zero-size available', diagnostics%available, 0.0_real64)

    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 1.0_real64, &
                                                              candidate, diagnostics)
    call assert_true('zero-size positive transfer status', &
                     diagnostics%status == WOFLEAF_TRANSFER_EXCEEDS_AVAILABLE)

    deallocate(weights, candidate)
  end subroutine test_zero_size_cohort_set

  subroutine test_relative_proportions_preserved()
    real(real64) :: weights(4), candidate(4)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [0.0_real64, 2.0_real64, 4.0_real64, 8.0_real64]
    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 7.0_real64, &
                                                              candidate, diagnostics)

    call assert_true('proportion status', diagnostics%status == WOFLEAF_OK)
    call assert_close('proportion zero remains zero', candidate(1), 0.0_real64)
    call assert_close('proportion scale 2', candidate(2) / weights(2), diagnostics%scale)
    call assert_close('proportion scale 3', candidate(3) / weights(3), diagnostics%scale)
    call assert_close('proportion scale 4', candidate(4) / weights(4), diagnostics%scale)
  end subroutine test_relative_proportions_preserved

  subroutine test_awkward_floating_point_closure()
    real(real64) :: weights(4), candidate(4)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [0.1_real64, 0.2_real64, 0.3_real64, 0.4_real64]
    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 0.37_real64, &
                                                              candidate, diagnostics)

    call assert_true('awkward status', diagnostics%status == WOFLEAF_OK)
    call assert_true('awkward nonnegative', all(candidate >= 0.0_real64))
    call assert_true('awkward closure tolerance', &
                     abs(diagnostics%mass_residual) <= diagnostics%closure_tolerance)
    call assert_close('awkward target total', sum(candidate), sum(weights) - 0.37_real64)
  end subroutine test_awkward_floating_point_closure

  subroutine test_layout_is_not_legacy_366_bound()
    real(real64) :: weights(7), candidate(7), expected(7)
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: diagnostics

    weights = [1.0_real64, 3.0_real64, 2.0_real64, 4.0_real64, &
               5.0_real64, 7.0_real64, 6.0_real64]
    expected = 0.75_real64 * weights

    call apply_wofost_leaf_reallocation_to_surviving_cohorts(weights, 7.0_real64, &
                                                              candidate, diagnostics)

    call assert_true('layout-neutral status', diagnostics%status == WOFLEAF_OK)
    call assert_vector_close('layout-neutral seven cohorts', candidate, expected)
  end subroutine test_layout_is_not_legacy_366_bound

  subroutine test_fwof09_limited_leaf_composition()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: committed, candidate_state
    type(wofost73_reallocation_biomass_t) :: activation_biomass, availability
    type(wofost73_reallocation_flux_t) :: applied_fluxes
    type(wofost_reallocation_request_t) :: request
    type(wofost_reallocation_trial_diagnostics_t) :: trial_diagnostics
    type(wofost_leaf_cohort_reallocation_diagnostics_t) :: leaf_diagnostics
    real(real64) :: surviving(2), candidate_cohorts(2), combined_residual

    p%activation_dvs = 1.0_real64
    p%leaf_fraction = 1.0_real64
    p%leaf_rate = 1.0_real64
    p%efficiency = 0.8_real64
    activation_biomass%leaf = 10.0_real64
    surviving = [1.0_real64, 2.0_real64]
    availability%leaf = sum(surviving)

    call evaluate_wofost_reallocation_trial(p, committed, activation_biomass, availability, &
                                            1.0_real64, 0.0_real64, 1.0_real64, candidate_state, &
                                            request, applied_fluxes, trial_diagnostics)

    call assert_true('composed F-WOF09 status', trial_diagnostics%status == WOFRAP_OK)
    call assert_true('composed F-WOF09 availability limited', &
                     trial_diagnostics%leaf_availability_limited)
    call assert_close('composed requested leaf', request%leaf, 10.0_real64)
    call assert_close('composed applied leaf', applied_fluxes%leaf_out, 3.0_real64)
    call assert_close('composed cumulative applied leaf', candidate_state%leaf_reallocated, 3.0_real64)

    call apply_wofost_leaf_reallocation_to_surviving_cohorts(surviving, applied_fluxes%leaf_out, &
                                                              candidate_cohorts, leaf_diagnostics)

    call assert_true('composed leaf status', leaf_diagnostics%status == WOFLEAF_OK)
    call assert_vector_close('composed donor depleted', candidate_cohorts, 0.0_real64 * surviving)
    call assert_close('composed donor removal', leaf_diagnostics%removed, 3.0_real64)

    combined_residual = -leaf_diagnostics%removed + applied_fluxes%storage_in + &
                        applied_fluxes%conversion_loss
    call assert_close('composed reallocation dry-matter balance', combined_residual, 0.0_real64)
  end subroutine test_fwof09_limited_leaf_composition

  subroutine assert_vector_close(label, actual, expected)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: actual(:), expected(:)
    integer :: i

    call assert_true(trim(label)//' size', size(actual) == size(expected))
    do i = 1, size(actual)
      call assert_close(trim(label)//' element', actual(i), expected(i))
    end do
  end subroutine assert_vector_close

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

end program test_fwof10_leaf_cohort_apply

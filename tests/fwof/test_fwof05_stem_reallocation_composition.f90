program test_fwof05_stem_reallocation_composition
  use iso_fortran_env, only: real64
  use mod_wofost73_reallocation, only: &
    REALLOC_UNADMITTED_DURATION, &
    wofost73_reallocation_parameters_t
  use mod_wofost_stem_reallocation_composition
  implicit none

  call test_official_winterwheat_vector()
  call test_pre_activation_identity()
  call test_repeat_trial_is_transactional()
  call test_second_day_preserves_independent_caps()
  call test_leaf_configuration_fails_closed()
  call test_non_daily_child_failure_is_atomic()
  call test_actual_child_failure_is_pair_atomic()
  call test_negative_endpoint_fails_closed()
  call test_zero_efficiency_balance()
  call test_unit_efficiency_balance()

  write(*,'(a)') 'FWOF05_STEM_REALLOCATION_COMPOSITION_PASS'

contains

  subroutine test_official_winterwheat_vector()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)

    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate, fluxes, diagnostics)

    call require(diagnostics%status == WOFOST_COMPOSE_OK, 'official vector status')
    call require_close(candidate%potential%leaf, 400.0_real64, 'potential leaf unchanged')
    call require_close(candidate%actual%leaf, 350.0_real64, 'actual leaf unchanged')
    call require_close(fluxes%potential%reallocation%stem_out, 8.3_real64, 'potential stem out')
    call require_close(fluxes%actual%reallocation%stem_out, 4.98_real64, 'actual stem out')
    call require_close(fluxes%potential%reallocation%storage_in, 7.885_real64, 'potential storage in')
    call require_close(fluxes%actual%reallocation%storage_in, 4.731_real64, 'actual storage in')
    call require_close(fluxes%potential%reallocation%conversion_loss, 0.415_real64, 'potential loss')
    call require_close(fluxes%actual%reallocation%conversion_loss, 0.249_real64, 'actual loss')
    call require_close(candidate%potential%stem, 991.7_real64, 'potential endpoint stem')
    call require_close(candidate%actual%stem, 595.02_real64, 'actual endpoint stem')
    call require_close(candidate%potential%storage, 207.885_real64, 'potential endpoint storage')
    call require_close(candidate%actual%storage, 154.731_real64, 'actual endpoint storage')
    call require_close(candidate%potential%reallocation%stem_cap, 200.0_real64, 'potential cap')
    call require_close(candidate%actual%reallocation%stem_cap, 120.0_real64, 'actual cap')
    call require_close(candidate%potential%reallocation%stem_reallocated, 8.3_real64, 'potential cumulative')
    call require_close(candidate%actual%reallocation%stem_reallocated, 4.98_real64, 'actual cumulative')
    call require_small(diagnostics%potential%dry_matter_residual, 'potential dry matter balance')
    call require_small(diagnostics%actual%dry_matter_residual, 'actual dry matter balance')
  end subroutine test_official_winterwheat_vector

  subroutine test_pre_activation_identity()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.49_real64, 0.0_real64, 1.0_real64, &
                                                candidate, fluxes, diagnostics)

    call require(diagnostics%status == WOFOST_COMPOSE_OK, 'pre activation status')
    call require_pair_equal(candidate, committed, 'pre activation identity')
    call require_close(fluxes%potential%reallocation%stem_out, 0.0_real64, 'pre activation potential flux')
    call require_close(fluxes%actual%reallocation%stem_out, 0.0_real64, 'pre activation actual flux')
  end subroutine test_pre_activation_identity

  subroutine test_repeat_trial_is_transactional()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate1, candidate2
    type(wofost_reallocation_pair_flux_t) :: fluxes1, fluxes2
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics1, diagnostics2
    type(wofost_reallocation_pair_state_t) :: original

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    original = committed

    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate1, fluxes1, diagnostics1)
    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate2, fluxes2, diagnostics2)

    call require_pair_equal(committed, original, 'committed state mutated')
    call require_pair_equal(candidate1, candidate2, 'repeat trial candidate')
    call require_close(fluxes1%potential%reallocation%stem_out, &
                       fluxes2%potential%reallocation%stem_out, 'repeat trial potential flux')
    call require_close(fluxes1%actual%reallocation%stem_out, &
                       fluxes2%actual%reallocation%stem_out, 'repeat trial actual flux')
  end subroutine test_repeat_trial_is_transactional

  subroutine test_second_day_preserves_independent_caps()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, day1, day2
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                day1, fluxes, diagnostics)
    call require(diagnostics%status == WOFOST_COMPOSE_OK, 'day1 status')

    call evaluate_wofost_stem_reallocation_pair(p, day1, 1.6_real64, 1.0_real64, 2.0_real64, &
                                                day2, fluxes, diagnostics)
    call require(diagnostics%status == WOFOST_COMPOSE_OK, 'day2 status')
    call require_close(day2%potential%reallocation%stem_cap, 200.0_real64, 'day2 potential cap stable')
    call require_close(day2%actual%reallocation%stem_cap, 120.0_real64, 'day2 actual cap stable')
    call require_close(day2%potential%reallocation%stem_reallocated, 16.6_real64, 'day2 potential cumulative')
    call require_close(day2%actual%reallocation%stem_reallocated, 9.96_real64, 'day2 actual cumulative')
  end subroutine test_second_day_preserves_independent_caps

  subroutine test_leaf_configuration_fails_closed()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    p%leaf_fraction = 0.1_real64
    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%status == WOFOST_COMPOSE_LEAF_REALLOCATION_UNADMITTED, &
                 'leaf fraction should fail closed')
    call require_pair_equal(candidate, committed, 'leaf fraction changed candidate')

    call set_winterwheat_parameters(p)
    p%leaf_rate = 0.1_real64
    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%status == WOFOST_COMPOSE_LEAF_REALLOCATION_UNADMITTED, &
                 'leaf rate should fail closed')
    call require_pair_equal(candidate, committed, 'leaf rate changed candidate')
  end subroutine test_leaf_configuration_fails_closed

  subroutine test_non_daily_child_failure_is_atomic()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 0.5_real64, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%status == WOFOST_COMPOSE_CHILD_ERROR, 'subdaily host status')
    call require(diagnostics%potential%child_status == REALLOC_UNADMITTED_DURATION, 'subdaily child status')
    call require_pair_equal(candidate, committed, 'subdaily candidate changed')
  end subroutine test_non_daily_child_failure_is_atomic

  subroutine test_actual_child_failure_is_pair_atomic()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    committed%actual%reallocation%activated = .true.
    committed%actual%reallocation%stem_cap = 10.0_real64
    committed%actual%reallocation%stem_reallocated = 11.0_real64

    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%potential%status == WOFOST_COMPOSE_OK, 'potential should have succeeded locally')
    call require(diagnostics%actual%status == WOFOST_COMPOSE_CHILD_ERROR, 'actual child failure missing')
    call require(diagnostics%status == WOFOST_COMPOSE_CHILD_ERROR, 'pair child failure missing')
    call require_pair_equal(candidate, committed, 'pair was not fail atomic')
    call require_close(fluxes%potential%reallocation%stem_out, 0.0_real64, 'failed pair leaked potential flux')
  end subroutine test_actual_child_failure_is_pair_atomic

  subroutine test_negative_endpoint_fails_closed()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    p%stem_rate = 1.0_real64
    committed%potential%stem = 1.0_real64
    committed%potential%reallocation%activated = .true.
    committed%potential%reallocation%stem_cap = 100.0_real64
    committed%potential%reallocation%stem_reallocated = 0.0_real64

    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%status == WOFOST_COMPOSE_NEGATIVE_ENDPOINT, 'negative endpoint not rejected')
    call require_pair_equal(candidate, committed, 'negative endpoint changed candidate')
  end subroutine test_negative_endpoint_fails_closed

  subroutine test_zero_efficiency_balance()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    p%efficiency = 0.0_real64
    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%status == WOFOST_COMPOSE_OK, 'zero efficiency status')
    call require_close(candidate%potential%storage, committed%potential%storage, 'zero efficiency storage')
    call require_close(fluxes%potential%reallocation%conversion_loss, &
                       fluxes%potential%reallocation%stem_out, 'zero efficiency loss')
    call require_small(diagnostics%potential%dry_matter_residual, 'zero efficiency balance')
  end subroutine test_zero_efficiency_balance

  subroutine test_unit_efficiency_balance()
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost_reallocation_pair_state_t) :: committed, candidate
    type(wofost_reallocation_pair_flux_t) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t) :: diagnostics

    call set_winterwheat_parameters(p)
    call set_pair_state(committed)
    p%efficiency = 1.0_real64
    call evaluate_wofost_stem_reallocation_pair(p, committed, 1.5_real64, 0.0_real64, 1.0_real64, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%status == WOFOST_COMPOSE_OK, 'unit efficiency status')
    call require_close(fluxes%potential%reallocation%conversion_loss, 0.0_real64, 'unit efficiency loss')
    call require_small(diagnostics%potential%dry_matter_residual, 'unit efficiency balance')
  end subroutine test_unit_efficiency_balance

  subroutine set_winterwheat_parameters(p)
    type(wofost73_reallocation_parameters_t), intent(out) :: p

    p%activation_dvs = 1.5_real64
    p%stem_fraction = 0.2_real64
    p%leaf_fraction = 0.0_real64
    p%stem_rate = 0.0415_real64
    p%leaf_rate = 0.0_real64
    p%efficiency = 0.95_real64
  end subroutine set_winterwheat_parameters

  subroutine set_pair_state(state)
    type(wofost_reallocation_pair_state_t), intent(out) :: state

    state = wofost_reallocation_pair_state_t()
    state%potential%leaf = 400.0_real64
    state%potential%stem = 1000.0_real64
    state%potential%storage = 200.0_real64
    state%actual%leaf = 350.0_real64
    state%actual%stem = 600.0_real64
    state%actual%storage = 150.0_real64
  end subroutine set_pair_state

  subroutine require_pair_equal(a, b, label)
    type(wofost_reallocation_pair_state_t), intent(in) :: a, b
    character(len=*), intent(in) :: label

    call require_track_equal(a%potential, b%potential, trim(label)//' potential')
    call require_track_equal(a%actual, b%actual, trim(label)//' actual')
  end subroutine require_pair_equal

  subroutine require_track_equal(a, b, label)
    type(wofost_reallocation_track_state_t), intent(in) :: a, b
    character(len=*), intent(in) :: label

    call require_close(a%leaf, b%leaf, trim(label)//' leaf')
    call require_close(a%stem, b%stem, trim(label)//' stem')
    call require_close(a%storage, b%storage, trim(label)//' storage')
    call require(a%reallocation%activated .eqv. b%reallocation%activated, trim(label)//' activated')
    call require_close(a%reallocation%leaf_cap, b%reallocation%leaf_cap, trim(label)//' leaf cap')
    call require_close(a%reallocation%stem_cap, b%reallocation%stem_cap, trim(label)//' stem cap')
    call require_close(a%reallocation%leaf_reallocated, b%reallocation%leaf_reallocated, &
                       trim(label)//' leaf cumulative')
    call require_close(a%reallocation%stem_reallocated, b%reallocation%stem_reallocated, &
                       trim(label)//' stem cumulative')
  end subroutine require_track_equal

  subroutine require_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    real(real64) :: scale

    scale = max(1.0_real64, abs(expected))
    if (abs(actual - expected) > 5.0e-12_real64 * scale) then
      write(*,'(a,1x,es24.16,1x,es24.16)') trim(label), actual, expected
      error stop 1
    end if
  end subroutine require_close

  subroutine require_small(value, label)
    real(real64), intent(in) :: value
    character(len=*), intent(in) :: label

    if (abs(value) > 5.0e-12_real64) then
      write(*,'(a,1x,es24.16)') trim(label), value
      error stop 1
    end if
  end subroutine require_small

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label

    if (.not. condition) then
      write(*,'(a)') trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fwof05_stem_reallocation_composition

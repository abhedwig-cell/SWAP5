program test_fwof04_reallocation
  use iso_fortran_env, only: real64
  use mod_wofost73_reallocation
  implicit none

  integer :: failures

  failures = 0
  call test_before_threshold(failures)
  call test_activation(failures)
  call test_remaining_cap_limit(failures)
  call test_completed(failures)
  call test_unity_efficiency(failures)
  call test_disabled_profile(failures)
  call test_transaction_repeatability(failures)
  call test_duration_rejection(failures)
  call test_invalid_state_rejection(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FWOF04_FAILURES=', failures
    error stop 1
  end if

  write(*,'(A)') 'FWOF04_WOFOST73_REALLOCATION_PASS'

contains

  subroutine expect_close(name, actual, expected, failures)
    character(len=*), intent(in) :: name
    real(real64), intent(in) :: actual, expected
    integer, intent(inout) :: failures
    real(real64), parameter :: tol = 1.0e-12_real64

    if (abs(actual - expected) > tol) then
      failures = failures + 1
      write(*,'(A,1X,A,2(1X,ES24.16E3))') 'MISMATCH', trim(name), actual, expected
    end if
  end subroutine expect_close

  subroutine expect_true(name, condition, failures)
    character(len=*), intent(in) :: name
    logical, intent(in) :: condition
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,1X,A)') 'FAILED', trim(name)
    end if
  end subroutine expect_true

  subroutine standard_parameters(p, efficiency)
    type(wofost73_reallocation_parameters_t), intent(out) :: p
    real(real64), intent(in) :: efficiency

    p = wofost73_reallocation_parameters_t( &
      activation_dvs=1.5_real64, stem_fraction=0.2_real64, leaf_fraction=0.1_real64, &
      stem_rate=0.0415_real64, leaf_rate=0.05_real64, efficiency=efficiency)
  end subroutine standard_parameters

  subroutine evaluate_standard(dvs, efficiency, state0, leaf, stem, state1, flux, diag)
    real(real64), intent(in) :: dvs, efficiency, leaf, stem
    type(wofost73_reallocation_state_t), intent(in) :: state0
    type(wofost73_reallocation_state_t), intent(out) :: state1
    type(wofost73_reallocation_flux_t), intent(out) :: flux
    type(wofost73_reallocation_diagnostics_t), intent(out) :: diag
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_biomass_t) :: b

    call standard_parameters(p, efficiency)
    b = wofost73_reallocation_biomass_t(leaf=leaf, stem=stem)
    call evaluate_wofost73_reallocation_reference_call(p, state0, b, dvs, 0.0_real64, 1.0_real64, &
                                                       state1, flux, diag)
  end subroutine evaluate_standard

  subroutine test_before_threshold(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_state_t) :: s0, s1
    type(wofost73_reallocation_flux_t) :: f
    type(wofost73_reallocation_diagnostics_t) :: d

    s0 = wofost73_reallocation_state_t()
    call evaluate_standard(1.49_real64, 0.95_real64, s0, 500.0_real64, 1000.0_real64, s1, f, d)
    call expect_true('before/status', d%status == REALLOC_OK, failures)
    call expect_true('before/not-activated', .not. s1%activated, failures)
    call expect_close('before/leaf', f%leaf_out, 0.0_real64, failures)
    call expect_close('before/stem', f%stem_out, 0.0_real64, failures)
    call expect_close('before/storage', f%storage_in, 0.0_real64, failures)
  end subroutine test_before_threshold

  subroutine test_activation(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_state_t) :: s0, s1
    type(wofost73_reallocation_flux_t) :: f
    type(wofost73_reallocation_diagnostics_t) :: d

    s0 = wofost73_reallocation_state_t()
    call evaluate_standard(1.5_real64, 0.95_real64, s0, 500.0_real64, 1000.0_real64, s1, f, d)
    call expect_true('activation/status', d%status == REALLOC_OK, failures)
    call expect_true('activation/flag', s1%activated .and. d%activated_this_trial, failures)
    call expect_close('activation/leaf-cap', s1%leaf_cap, 50.0_real64, failures)
    call expect_close('activation/stem-cap', s1%stem_cap, 200.0_real64, failures)
    call expect_close('activation/leaf-out', f%leaf_out, 2.5_real64, failures)
    call expect_close('activation/stem-out', f%stem_out, 8.3_real64, failures)
    call expect_close('activation/storage-in', f%storage_in, 10.26_real64, failures)
    call expect_close('activation/loss', f%conversion_loss, 0.54_real64, failures)
    call expect_close('activation/residual', d%dry_matter_residual, 0.0_real64, failures)
  end subroutine test_activation

  subroutine test_remaining_cap_limit(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_state_t) :: s0, s1
    type(wofost73_reallocation_flux_t) :: f
    type(wofost73_reallocation_diagnostics_t) :: d

    s0 = wofost73_reallocation_state_t(.true., 50.0_real64, 200.0_real64, 49.0_real64, 197.0_real64)
    call evaluate_standard(1.7_real64, 0.95_real64, s0, 450.0_real64, 900.0_real64, s1, f, d)
    call expect_close('remaining/leaf', f%leaf_out, 1.0_real64, failures)
    call expect_close('remaining/stem', f%stem_out, 3.0_real64, failures)
    call expect_close('remaining/storage', f%storage_in, 3.8_real64, failures)
    call expect_close('remaining/loss', f%conversion_loss, 0.2_real64, failures)
    call expect_close('remaining/leaf-done', s1%leaf_reallocated, 50.0_real64, failures)
    call expect_close('remaining/stem-done', s1%stem_reallocated, 200.0_real64, failures)
  end subroutine test_remaining_cap_limit

  subroutine test_completed(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_state_t) :: s0, s1
    type(wofost73_reallocation_flux_t) :: f
    type(wofost73_reallocation_diagnostics_t) :: d

    s0 = wofost73_reallocation_state_t(.true., 50.0_real64, 200.0_real64, 50.0_real64, 200.0_real64)
    call evaluate_standard(1.8_real64, 0.95_real64, s0, 500.0_real64, 1000.0_real64, s1, f, d)
    call expect_close('completed/leaf', f%leaf_out, 0.0_real64, failures)
    call expect_close('completed/stem', f%stem_out, 0.0_real64, failures)
    call expect_close('completed/storage', f%storage_in, 0.0_real64, failures)
  end subroutine test_completed

  subroutine test_unity_efficiency(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_state_t) :: s0, s1
    type(wofost73_reallocation_flux_t) :: f
    type(wofost73_reallocation_diagnostics_t) :: d

    s0 = wofost73_reallocation_state_t()
    call evaluate_standard(1.5_real64, 1.0_real64, s0, 500.0_real64, 1000.0_real64, s1, f, d)
    call expect_close('unity/storage', f%storage_in, 10.8_real64, failures)
    call expect_close('unity/loss', f%conversion_loss, 0.0_real64, failures)
  end subroutine test_unity_efficiency

  subroutine test_disabled_profile(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_parameters_t) :: p

    call standard_parameters(p, 0.95_real64)
    p%leaf_fraction = 0.0_real64
    p%stem_fraction = 0.0_real64
    call expect_true('disabled/capability', .not. reallocation_enabled(p), failures)
    p%leaf_fraction = 0.1_real64
    call expect_true('enabled/capability', reallocation_enabled(p), failures)
    p%activation_dvs = 3.0_real64
    call expect_true('late-threshold/capability', .not. reallocation_enabled(p), failures)
  end subroutine test_disabled_profile

  subroutine test_transaction_repeatability(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_state_t) :: committed, a, b
    type(wofost73_reallocation_flux_t) :: fa, fb
    type(wofost73_reallocation_diagnostics_t) :: da, db

    committed = wofost73_reallocation_state_t()
    call evaluate_standard(1.5_real64, 0.95_real64, committed, 500.0_real64, 1000.0_real64, a, fa, da)
    call evaluate_standard(1.5_real64, 0.95_real64, committed, 500.0_real64, 1000.0_real64, b, fb, db)

    call expect_true('transaction/committed-unmodified', .not. committed%activated, failures)
    call expect_close('transaction/committed-leaf-cap', committed%leaf_cap, 0.0_real64, failures)
    call expect_true('transaction/same-activation', a%activated .eqv. b%activated, failures)
    call expect_close('transaction/same-leaf-cap', a%leaf_cap, b%leaf_cap, failures)
    call expect_close('transaction/same-stem-cap', a%stem_cap, b%stem_cap, failures)
    call expect_close('transaction/same-leaf-flux', fa%leaf_out, fb%leaf_out, failures)
    call expect_close('transaction/same-stem-flux', fa%stem_out, fb%stem_out, failures)
  end subroutine test_transaction_repeatability

  subroutine test_duration_rejection(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: s0, s1
    type(wofost73_reallocation_biomass_t) :: b
    type(wofost73_reallocation_flux_t) :: f
    type(wofost73_reallocation_diagnostics_t) :: d

    call standard_parameters(p, 0.95_real64)
    s0 = wofost73_reallocation_state_t()
    b = wofost73_reallocation_biomass_t(500.0_real64, 1000.0_real64)
    call evaluate_wofost73_reallocation_reference_call(p, s0, b, 1.5_real64, 0.0_real64, 0.5_real64, s1, f, d)
    call expect_true('duration/status', d%status == REALLOC_UNADMITTED_DURATION, failures)
    call expect_true('duration/no-state-change', .not. s1%activated, failures)
  end subroutine test_duration_rejection

  subroutine test_invalid_state_rejection(failures)
    integer, intent(inout) :: failures
    type(wofost73_reallocation_parameters_t) :: p
    type(wofost73_reallocation_state_t) :: s0, s1
    type(wofost73_reallocation_biomass_t) :: b
    type(wofost73_reallocation_flux_t) :: f
    type(wofost73_reallocation_diagnostics_t) :: d

    call standard_parameters(p, 0.95_real64)
    s0 = wofost73_reallocation_state_t(.true., 10.0_real64, 10.0_real64, 11.0_real64, 0.0_real64)
    b = wofost73_reallocation_biomass_t(500.0_real64, 1000.0_real64)
    call evaluate_wofost73_reallocation_reference_call(p, s0, b, 1.5_real64, 0.0_real64, 1.0_real64, s1, f, d)
    call expect_true('invalid-state/status', d%status == REALLOC_INVALID_STATE, failures)
  end subroutine test_invalid_state_rejection

end program test_fwof04_reallocation

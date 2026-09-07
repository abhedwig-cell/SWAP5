program test_fsi07_real_state_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, dz
  use MOD_swap_base, only: swmacro
  use variables
  use fsi05_fixture_control, only: force_tridag_failure
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, a23bu_initialize_worker
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       poison_reference_workspace
#ifndef FSI07_PREIMAGE
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
#endif
  implicit none

  type(a23bu_worker_context_t) :: worker
  type(a23bu_solver_history_t) :: history
  type(reference_richards_workspace_t) :: workspace
#ifndef FSI07_PREIMAGE
  type(reference_richards_state_binding_t) :: state
#endif
  integer :: failures
  integer(int64) :: fp_a1, fp_a2

  interface
#ifdef FSI07_PREIMAGE
    subroutine headcalc(worker, fsi_workspace, history)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      type(a23bu_worker_context_t), target, intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
    end subroutine headcalc
#else
    subroutine headcalc(worker, fsi_workspace, history, state_binding)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
      type(a23bu_worker_context_t), target, intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
    end subroutine headcalc
#endif
  end interface

  failures = 0
  swmacro = 0

  call run_case(-100.0_real64, .false., 'MAIN-A1', fp_a1, failures)
  call run_case(-200.0_real64, .false., 'MAIN-B ', fp_a2, failures)
  call run_case(-100.0_real64, .false., 'MAIN-A2', fp_a2, failures)
  if (fp_a1 /= fp_a2) failures = failures + 1

  call run_case(-100.0_real64, .true., 'BAND-A1', fp_a1, failures)
  call run_case(-200.0_real64, .true., 'BAND-B ', fp_a2, failures)
  call run_case(-100.0_real64, .true., 'BAND-A2', fp_a2, failures)
  if (fp_a1 /= fp_a2) failures = failures + 1

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-SI07_REAL_STATE_BINDING FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-SI07_REAL_STATE_BINDING PASS'

contains

  subroutine run_case(head_value, fallback, label, fingerprint, fails)
    real(real64), intent(in) :: head_value
    logical, intent(in) :: fallback
    character(len=*), intent(in) :: label
    integer(int64), intent(out) :: fingerprint
    integer, intent(inout) :: fails
    real(real64) :: residual, top_flux, bottom_flux
    real(real64) :: out_h(numnod), out_theta(numnod)
    integer :: i, expected_alternative, out_numbit

    call seed_case(head_value)
    force_tridag_failure = fallback
    expected_alternative = merge(1, 0, fallback)
    call a23bu_initialize_worker(worker, numnod, 31)
    history%flwarn = .false.
    history%iwarn = 55
    history%nstep = 66
    call initialize_reference_workspace(workspace, numnod)
    call poison_reference_workspace(workspace)

#ifdef FSI07_PREIMAGE
    call headcalc(worker, workspace, history)
    out_h = h
    out_theta = theta
    top_flux = qtop
    bottom_flux = qbot
    out_numbit = numbit
#else
    call load_state_from_globals(state)
    call headcalc(worker, workspace, history, state)
    out_h = state%h
    out_theta = state%theta
    top_flux = state%qtop
    bottom_flux = state%qbot
    out_numbit = state%numbit
    if (state%fldecdt) fails = fails + 1
#endif

    if (workspace%poisoned) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%residual))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%dfdh_main))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_matrix))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_aux))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_rhs))) fails = fails + 1

    residual = sum(dz*(out_theta-thetam1_view())) + top_flux - bottom_flux
    if (.not. ieee_is_finite(residual)) fails = fails + 1
    if (abs(residual) > 16.0_real64*epsilon(1.0_real64)) fails = fails + 1
    if (out_numbit /= 1) fails = fails + 1
    if (worker%diagnostics%headcalc_calls /= 1) fails = fails + 1
    if (worker%diagnostics%nonlinear_iterations /= 1) fails = fails + 1
    if (worker%diagnostics%jacobian_builds /= 1) fails = fails + 1
    if (worker%diagnostics%linear_solves /= 1) fails = fails + 1
    if (worker%diagnostics%alternative_solver_calls /= expected_alternative) fails = fails + 1
    if (worker%diagnostics%internal_retries /= 0) fails = fails + 1
    if (worker%control%request_dt_reduction) fails = fails + 1
    if (worker%control%last_numbit /= 1) fails = fails + 1

    fingerprint = 1469598103934665603_int64
    do i = 1, numnod
      fingerprint = ieor(fingerprint, transfer(out_h(i), fingerprint))
      fingerprint = ieor(fingerprint, transfer(out_theta(i), fingerprint))
    end do
    fingerprint = ieor(fingerprint, transfer(top_flux, fingerprint))
    fingerprint = ieor(fingerprint, transfer(bottom_flux, fingerprint))
    fingerprint = ieor(fingerprint, int(out_numbit, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%nonlinear_iterations, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%jacobian_builds, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%linear_solves, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%alternative_solver_calls, int64))

    write(*,'(A,1X,A,1X,Z16.16,1X,ES24.16,1X,ES24.16,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0)') &
      'CASE', trim(label), fingerprint, top_flux, bottom_flux, out_numbit, worker%diagnostics%nonlinear_iterations, &
      worker%diagnostics%jacobian_builds, worker%diagnostics%linear_solves, worker%diagnostics%alternative_solver_calls
  end subroutine run_case

  function thetam1_view() result(v)
    real(real64) :: v(numnod)
#ifdef FSI07_PREIMAGE
    v = thetm1
#else
    v = state%thetm1
#endif
  end function thetam1_view

#ifndef FSI07_PREIMAGE
  subroutine load_state_from_globals(s)
    type(reference_richards_state_binding_t), intent(inout) :: s
    call s%ensure_shape(numnod)
    s%h = h
    s%theta = theta
    s%hm1 = hm1
    s%thetm1 = thetm1
    s%k = k
    s%kmean = kmean
    s%dimoca = dimoca
    s%pond = pond
    s%pondm1 = pondm1
    s%gwl = gwl
    s%gwlm1 = gwlm1
    s%qtop = qtop
    s%qbot = qbot
    s%hbot = hbot
    s%gwlinp = gwlinp
    s%fllowgwl = fllowgwl
    s%fldecdt = .false.
    s%numbit = 0
  end subroutine load_state_from_globals
#endif

  subroutine seed_case(head_value)
    real(real64), intent(in) :: head_value
    h = head_value
    theta = 0.30_real64
    hm1 = h
    thetm1 = theta
    pond = 0.0_real64
    pondm1 = pond
    gwl = -2.0_real64
    gwlm1 = gwl
    qtop = -1.0_real64
    qbot = -1.0_real64
    hbot = -100.0_real64
    gwlinp = -5.0_real64
    fllowgwl = .false.
    k = 1.0_real64
    kmean = 1.0_real64
    dimoca = 0.0_real64
    itnumb = 0
    numbit = 0
    fldecdt = .false.
    fldtmin = .false.
    fldaystart = .false.
    swbotb = 7
    swkimpl = 0
    swkmean = 1
    maxit = 8
    maxbacktr = 4
    CritDevBalCp = 1.0e-12_real64
    CritDevBalTot = 1.0e-12_real64
    critdevh2cp = 1.0e-12_real64
    critdevh1cp = 1.0e-12_real64
    critdevponddt = 1.0e-12_real64
  end subroutine seed_case
end program test_fsi07_real_state_binding

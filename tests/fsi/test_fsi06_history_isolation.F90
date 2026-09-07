program test_fsi06_history_isolation
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, dz
  use MOD_swap_base, only: swmacro
  use variables
  use fsi05_fixture_control, only: force_tridag_failure
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, a23bu_initialize_worker
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       poison_reference_workspace
  implicit none

  type(a23bu_worker_context_t) :: worker
  type(a23bu_solver_history_t) :: history
  type(reference_richards_workspace_t) :: workspace
  integer :: failures
  integer(int64) :: fp_a1, fp_a2

  interface
#ifdef FSI06_PREIMAGE
    subroutine headcalc(worker, fsi_workspace)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      type(a23bu_worker_context_t), target, intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
    end subroutine headcalc
#else
    subroutine headcalc(worker, fsi_workspace, history)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      type(a23bu_worker_context_t), target, intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
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

#ifndef FSI06_PREIMAGE
  call verify_explicit_history_event(failures)
#endif

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-SI06_HISTORY_ISOLATION FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-SI06_HISTORY_ISOLATION PASS'

contains

  subroutine run_case(head_value, fallback, label, fingerprint, fails)
    real(real64), intent(in) :: head_value
    logical, intent(in) :: fallback
    character(len=*), intent(in) :: label
    integer(int64), intent(out) :: fingerprint
    integer, intent(inout) :: fails
    real(real64) :: residual
    integer :: i, expected_alternative

    call seed_case(head_value)
    force_tridag_failure = fallback
    expected_alternative = merge(1, 0, fallback)
    call a23bu_initialize_worker(worker, numnod, 17)
    worker%history%flwarn = .false.
    worker%history%iwarn = 77
    worker%history%nstep = 88
    history%flwarn = .false.
    history%iwarn = 55
    history%nstep = 66
    call initialize_reference_workspace(workspace, numnod)
    call poison_reference_workspace(workspace)
#ifdef FSI06_PREIMAGE
    call headcalc(worker, workspace)
#else
#ifdef FSI06_COMPAT_CALL
    call headcalc(worker)
#else
    call headcalc(worker, workspace, history)
#endif
#endif
    if (workspace%poisoned .and. .not. defined(FSI06_COMPAT_CALL)) then
      continue
    end if
#ifndef FSI06_COMPAT_CALL
    if (workspace%poisoned) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%residual))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%dfdh_main))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_matrix))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_aux))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_rhs))) fails = fails + 1
#endif
    if (worker%history%flwarn) fails = fails + 1
    if (worker%history%iwarn /= 77) fails = fails + 1
    if (worker%history%nstep /= 88) fails = fails + 1
#ifndef FSI06_PREIMAGE
#ifndef FSI06_COMPAT_CALL
    if (history%flwarn) fails = fails + 1
    if (history%iwarn /= 55) fails = fails + 1
    if (history%nstep /= 66) fails = fails + 1
#endif
#endif

    residual = sum(dz*(theta-thetm1)) + qtop - qbot
    if (.not. ieee_is_finite(residual)) fails = fails + 1
    if (abs(residual) > 16.0_real64*epsilon(1.0_real64)) fails = fails + 1
    if (numbit /= 1) fails = fails + 1
    if (worker%diagnostics%headcalc_calls /= 1) fails = fails + 1
    if (worker%diagnostics%nonlinear_iterations /= 1) fails = fails + 1
    if (worker%diagnostics%jacobian_builds /= 1) fails = fails + 1
    if (worker%diagnostics%linear_solves /= 1) fails = fails + 1
    if (worker%diagnostics%alternative_solver_calls /= expected_alternative) fails = fails + 1
    if (worker%diagnostics%internal_retries /= 0) fails = fails + 1
    if (worker%control%request_dt_reduction) fails = fails + 1
    if (worker%control%last_numbit /= 1) fails = fails + 1
    if (fldecdt) fails = fails + 1

    fingerprint = 1469598103934665603_int64
    do i = 1, numnod
      fingerprint = ieor(fingerprint, transfer(h(i), fingerprint))
      fingerprint = ieor(fingerprint, transfer(theta(i), fingerprint))
    end do
    fingerprint = ieor(fingerprint, transfer(qtop, fingerprint))
    fingerprint = ieor(fingerprint, transfer(qbot, fingerprint))
    fingerprint = ieor(fingerprint, int(numbit, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%nonlinear_iterations, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%jacobian_builds, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%linear_solves, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%alternative_solver_calls, int64))

    write(*,'(A,1X,A,1X,Z16.16,1X,ES24.16,1X,ES24.16,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0)') &
      'CASE', trim(label), fingerprint, qtop, qbot, numbit, worker%diagnostics%nonlinear_iterations, &
      worker%diagnostics%jacobian_builds, worker%diagnostics%linear_solves, worker%diagnostics%alternative_solver_calls
  end subroutine run_case

#ifndef FSI06_PREIMAGE
  subroutine verify_explicit_history_event(fails)
    integer, intent(inout) :: fails
    call seed_case(-100.0_real64)
    fldaystart = .true.
    force_tridag_failure = .false.
    call a23bu_initialize_worker(worker, numnod, 23)
    worker%history%flwarn = .false.
    worker%history%iwarn = 177
    worker%history%nstep = 188
    history%flwarn = .false.
    history%iwarn = 155
    history%nstep = 166
    call initialize_reference_workspace(workspace, numnod)
    call headcalc(worker, workspace, history)
    if (.not. history%flwarn) fails = fails + 1
    if (history%iwarn /= 0) fails = fails + 1
    if (history%nstep /= 166) fails = fails + 1
    if (worker%history%flwarn) fails = fails + 1
    if (worker%history%iwarn /= 177) fails = fails + 1
    if (worker%history%nstep /= 188) fails = fails + 1
    fldaystart = .false.
  end subroutine verify_explicit_history_event
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
end program test_fsi06_history_isolation

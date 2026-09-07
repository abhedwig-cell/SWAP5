program test_fsi04_real_headcalc_replay
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, dz
  use MOD_swap_base, only: swmacro
  use variables
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
#ifdef FSI04_WORKSPACE
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       poison_reference_workspace
#endif
  implicit none

  type(a23bu_worker_context_t) :: worker
#ifdef FSI04_WORKSPACE
  type(reference_richards_workspace_t) :: workspace
#endif
  integer :: failures
  integer(int64) :: fingerprint_a1, fingerprint_a2

  interface
#ifdef FSI04_WORKSPACE
    subroutine headcalc(worker, fsi_workspace)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(reference_richards_workspace_t), intent(inout) :: fsi_workspace
    end subroutine headcalc
#else
    subroutine headcalc(worker)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      type(a23bu_worker_context_t), intent(inout), optional :: worker
    end subroutine headcalc
#endif
  end interface

  failures = 0
  swmacro = 0

  call run_case(-100.0_real64, 'A1', fingerprint_a1, failures)
  call run_case(-200.0_real64, 'B ', fingerprint_a2, failures)
  call run_case(-100.0_real64, 'A2', fingerprint_a2, failures)
  if (fingerprint_a1 /= fingerprint_a2) failures = failures + 1

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-SI04_REAL_HEADCALC_REPLAY FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-SI04_REAL_HEADCALC_REPLAY PASS'

contains

  subroutine run_case(head_value, label, fingerprint, fails)
    real(real64), intent(in) :: head_value
    character(len=*), intent(in) :: label
    integer(int64), intent(out) :: fingerprint
    integer, intent(inout) :: fails
    real(real64) :: residual
    integer :: i

    call seed_case(head_value)
    call a23bu_initialize_worker(worker, numnod, 17)
#ifdef FSI04_WORKSPACE
    call initialize_reference_workspace(workspace, numnod)
    call poison_reference_workspace(workspace)
    call headcalc(worker, workspace)
    if (workspace%poisoned) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%residual))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%dfdh_main))) fails = fails + 1
#else
    call headcalc(worker)
#endif

    residual = sum(dz*(theta-thetm1)) + qtop - qbot
    if (.not. ieee_is_finite(residual)) fails = fails + 1
    if (abs(residual) > 16.0_real64*epsilon(1.0_real64)) fails = fails + 1
    if (numbit /= 1) fails = fails + 1
    if (worker%diagnostics%headcalc_calls /= 1) fails = fails + 1
    if (worker%diagnostics%nonlinear_iterations /= 1) fails = fails + 1
    if (worker%diagnostics%jacobian_builds /= 1) fails = fails + 1
    if (worker%diagnostics%linear_solves /= 1) fails = fails + 1
    if (worker%diagnostics%alternative_solver_calls /= 0) fails = fails + 1
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

    write(*,'(A,1X,A,1X,Z16.16,1X,ES24.16,1X,ES24.16,1X,I0,1X,I0,1X,I0,1X,I0)') &
      'CASE', trim(label), fingerprint, qtop, qbot, numbit, worker%diagnostics%nonlinear_iterations, &
      worker%diagnostics%jacobian_builds, worker%diagnostics%linear_solves
  end subroutine run_case

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
end program test_fsi04_real_headcalc_replay

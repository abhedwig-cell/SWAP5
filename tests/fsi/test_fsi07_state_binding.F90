program test_fsi07_state_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, dz
  use MOD_swap_base, only: swmacro
  use MOD_top, only: q0, flrunoff, ftoph, hsurf
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
    write(*,'(A,I0)') 'F-SI07_STATE_BINDING FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-SI07_STATE_BINDING PASS'

contains

  subroutine run_case(head_value, fallback, label, fingerprint, fails)
    real(real64), intent(in) :: head_value
    logical, intent(in) :: fallback
    character(len=*), intent(in) :: label
    integer(int64), intent(out) :: fingerprint
    integer, intent(inout) :: fails
    real(real64) :: residual, out_qtop, out_qbot
#ifndef FSI07_PREIMAGE
#ifndef FSI07_COMPAT_CALL
    real(real64) :: global_h(numnod), global_theta(numnod), global_hm1(numnod), global_thetm1(numnod)
    real(real64) :: global_pond, global_pondm1, global_gwl, global_gwlm1, global_qtop, global_qbot
#endif
#endif
    integer :: i, expected_alternative, out_numbit

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

#ifndef FSI07_PREIMAGE
#ifndef FSI07_COMPAT_CALL
    call seed_explicit_state()
    global_h = h; global_theta = theta; global_hm1 = hm1; global_thetm1 = thetm1
    global_pond = pond; global_pondm1 = pondm1; global_gwl = gwl; global_gwlm1 = gwlm1
    global_qtop = qtop; global_qbot = qbot
    call headcalc(worker, workspace, history, state)
    if (.not. same_vector(h, global_h)) fails = fails + 1
    if (.not. same_vector(theta, global_theta)) fails = fails + 1
    if (.not. same_vector(hm1, global_hm1)) fails = fails + 1
    if (.not. same_vector(thetm1, global_thetm1)) fails = fails + 1
    if (.not. same_real(pond, global_pond)) fails = fails + 1
    if (.not. same_real(pondm1, global_pondm1)) fails = fails + 1
    if (.not. same_real(gwl, global_gwl)) fails = fails + 1
    if (.not. same_real(gwlm1, global_gwlm1)) fails = fails + 1
    if (.not. same_real(qtop, global_qtop)) fails = fails + 1
    if (.not. same_real(qbot, global_qbot)) fails = fails + 1
#else
    call headcalc(worker, workspace, history)
#endif
#else
    call headcalc(worker, workspace, history)
#endif

    if (workspace%poisoned) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%residual))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%dfdh_main))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_matrix))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_aux))) fails = fails + 1
    if (.not. all(ieee_is_finite(workspace%band_rhs))) fails = fails + 1
    if (worker%history%flwarn) fails = fails + 1
    if (worker%history%iwarn /= 77) fails = fails + 1
    if (worker%history%nstep /= 88) fails = fails + 1
    if (history%flwarn) fails = fails + 1
    if (history%iwarn /= 55) fails = fails + 1
    if (history%nstep /= 66) fails = fails + 1

#ifndef FSI07_PREIMAGE
#ifndef FSI07_COMPAT_CALL
    residual = sum(dz*(state%theta-state%thetm1)) + state%qtop - state%qbot
    out_qtop = state%qtop
    out_qbot = state%qbot
    out_numbit = state%numbit
#else
    residual = sum(dz*(theta-thetm1)) + qtop - qbot
    out_qtop = qtop
    out_qbot = qbot
    out_numbit = numbit
#endif
#else
    residual = sum(dz*(theta-thetm1)) + qtop - qbot
    out_qtop = qtop
    out_qbot = qbot
    out_numbit = numbit
#endif

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
#ifndef FSI07_PREIMAGE
#ifndef FSI07_COMPAT_CALL
    do i = 1, numnod
      fingerprint = ieor(fingerprint, transfer(state%h(i), fingerprint))
      fingerprint = ieor(fingerprint, transfer(state%theta(i), fingerprint))
    end do
#else
    do i = 1, numnod
      fingerprint = ieor(fingerprint, transfer(h(i), fingerprint))
      fingerprint = ieor(fingerprint, transfer(theta(i), fingerprint))
    end do
#endif
#else
    do i = 1, numnod
      fingerprint = ieor(fingerprint, transfer(h(i), fingerprint))
      fingerprint = ieor(fingerprint, transfer(theta(i), fingerprint))
    end do
#endif
    fingerprint = ieor(fingerprint, transfer(out_qtop, fingerprint))
    fingerprint = ieor(fingerprint, transfer(out_qbot, fingerprint))
    fingerprint = ieor(fingerprint, int(out_numbit, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%nonlinear_iterations, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%jacobian_builds, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%linear_solves, int64))
    fingerprint = ieor(fingerprint, int(worker%diagnostics%alternative_solver_calls, int64))

    write(*,'(A,1X,A,1X,Z16.16,1X,ES24.16,1X,ES24.16,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0)') &
      'CASE', trim(label), fingerprint, out_qtop, out_qbot, out_numbit, worker%diagnostics%nonlinear_iterations, &
      worker%diagnostics%jacobian_builds, worker%diagnostics%linear_solves, worker%diagnostics%alternative_solver_calls
  end subroutine run_case

#ifndef FSI07_PREIMAGE
  subroutine seed_explicit_state()
    state%active_nodes = numnod
    state%h = h
    state%theta = theta
    state%hm1 = hm1
    state%thetm1 = thetm1
    state%k = k
    state%kmean = kmean
    state%dimoca = dimoca
    state%pond = pond
    state%pondm1 = pondm1
    state%gwl = gwl
    state%gwlm1 = gwlm1
    state%gwlinp = gwlinp
    state%dtold = dtold
    state%qtop = qtop
    state%qbot = qbot
    state%hbot = hbot
    state%itnumb = itnumb
    state%numbit = numbit
    state%fllowgwl = fllowgwl
    state%fldecdt = fldecdt
    state%q0 = q0
    state%hsurf = hsurf
    state%runots = runots
    state%flrunoff = flrunoff
    state%ftoph = ftoph
  end subroutine seed_explicit_state
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
    gwlinp = -5.0_real64
    qtop = -1.0_real64
    qbot = -1.0_real64
    hbot = -100.0_real64
    dtold = dt
    runots = 0.0_real64
    k = 1.0_real64
    kmean = 1.0_real64
    dimoca = 0.0_real64
    itnumb = 0
    numbit = 0
    fllowgwl = .false.
    fldecdt = .false.
    fldtmin = .false.
    fldaystart = .false.
    q0 = 0.0_real64
    flrunoff = .false.
    ftoph = .false.
    hsurf = 0.0_real64
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

  logical function same_real(a, b)
    real(real64), intent(in) :: a, b
    same_real = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real

  logical function same_vector(a, b)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i
    same_vector = size(a) == size(b)
    if (.not. same_vector) return
    do i = 1, size(a)
      if (.not. same_real(a(i), b(i))) then
        same_vector = .false.
        return
      end if
    end do
  end function same_vector

end program test_fsi07_state_binding

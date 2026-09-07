program test_fsi07_real_concurrency
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use omp_lib, only: omp_get_max_threads, omp_get_thread_num
  use MOD_grid, only: numnod
  use MOD_swap_base, only: swmacro
  use variables
  use fsi07_concurrency_control, only: parallel_probe
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, a23bu_initialize_worker
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       poison_reference_workspace
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
  implicit none

  type(reference_richards_state_binding_t), allocatable :: serial_state(:), parallel_state(:)
  type(reference_richards_workspace_t), allocatable :: serial_ws(:), parallel_ws(:)
  type(a23bu_worker_context_t), allocatable :: serial_worker(:), parallel_worker(:)
  type(a23bu_solver_history_t), allocatable :: serial_history(:), parallel_history(:)
  integer(int64), allocatable :: serial_fp(:), parallel_fp(:)
  integer :: nthreads, i, mismatches

  interface
    subroutine headcalc(worker, fsi_workspace, history, state_binding)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
      type(a23bu_worker_context_t), target, intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
    end subroutine headcalc
  end interface

  nthreads = omp_get_max_threads()
  if (.not. any(nthreads == [1,2,4,8])) error stop 'F-SI07 concurrency probe requires 1/2/4/8 threads'

  allocate(serial_state(nthreads), parallel_state(nthreads))
  allocate(serial_ws(nthreads), parallel_ws(nthreads))
  allocate(serial_worker(nthreads), parallel_worker(nthreads))
  allocate(serial_history(nthreads), parallel_history(nthreads))
  allocate(serial_fp(nthreads), parallel_fp(nthreads))

  call seed_shared_fixture()
  parallel_probe = .false.
  do i = 1, nthreads
    call initialize_column(serial_state(i), serial_ws(i), serial_worker(i), serial_history(i), i)
    call headcalc(serial_worker(i), serial_ws(i), serial_history(i), serial_state(i))
    serial_fp(i) = state_fingerprint(serial_state(i), serial_worker(i))
  end do

  do i = 1, nthreads
    call initialize_column(parallel_state(i), parallel_ws(i), parallel_worker(i), parallel_history(i), i)
  end do
  parallel_probe = .true.
!$omp parallel default(shared) private(i)
  i = omp_get_thread_num() + 1
  if (i <= nthreads) then
    call headcalc(parallel_worker(i), parallel_ws(i), parallel_history(i), parallel_state(i))
    parallel_fp(i) = state_fingerprint(parallel_state(i), parallel_worker(i))
  end if
!$omp end parallel
  parallel_probe = .false.

  mismatches = count(serial_fp /= parallel_fp)
  do i = 1, nthreads
    write(*,'(A,I0,1X,Z16.16,1X,Z16.16,1X,ES24.16,1X,ES24.16)') &
      'COLUMN ', i, serial_fp(i), parallel_fp(i), serial_state(i)%hsurf, parallel_state(i)%hsurf
  end do

#ifdef FSI07_EXPECT_LEAK
  if (nthreads == 1) then
    if (mismatches /= 0) error stop 'F-SI07 concurrency probe: single worker mismatch'
    write(*,'(A)') 'F-SI07_REAL_HEADCALC_1 PASS'
  else
    if (mismatches == 0) error stop 'F-SI07 concurrency probe failed to expose shared provider state'
    write(*,'(A,I0,A,I0)') 'F-SI07_REAL_HEADCALC_', nthreads, ' LEAK_CONFIRMED mismatches=', mismatches
  end if
#else
  if (mismatches /= 0) then
    write(*,'(A,I0,A,I0)') 'F-SI07_REAL_HEADCALC_', nthreads, ' FAIL mismatches=', mismatches
    error stop 1
  end if
  write(*,'(A,I0,A)') 'F-SI07_REAL_HEADCALC_', nthreads, ' PASS'
#endif

contains

  subroutine seed_shared_fixture()
    swmacro = 0
    swbotb = 7
    swkimpl = 0
    swkmean = 1
    fldtmin = .false.
    fldaystart = .false.
    maxit = 8
    maxbacktr = 4
    CritDevBalCp = 1.0e-12_real64
    CritDevBalTot = 1.0e-12_real64
    critdevh2cp = 1.0e-12_real64
    critdevh1cp = 1.0e-12_real64
    critdevponddt = 1.0e-12_real64
    h = -999.0_real64
    theta = 0.30_real64
    hm1 = h
    thetm1 = theta
    pond = 0.0_real64
    pondm1 = 0.0_real64
    gwl = -2.0_real64
    gwlm1 = -2.0_real64
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
  end subroutine seed_shared_fixture

  subroutine initialize_column(state, workspace, worker, history, column)
    type(reference_richards_state_binding_t), intent(out) :: state
    type(reference_richards_workspace_t), intent(out) :: workspace
    type(a23bu_worker_context_t), intent(out) :: worker
    type(a23bu_solver_history_t), intent(out) :: history
    integer, intent(in) :: column
    real(real64) :: head_value

    head_value = -100.0_real64 - 10.0_real64*real(column, real64)
    state%active_nodes = numnod
    allocate(state%h(numnod), state%theta(numnod), state%hm1(numnod), state%thetm1(numnod))
    allocate(state%k(numnod), state%kmean(numnod+1), state%dimoca(numnod), state%itnumb(100,2))
    state%h = head_value
    state%theta = 0.30_real64
    state%hm1 = state%h
    state%thetm1 = state%theta
    state%k = 1.0_real64
    state%kmean = 1.0_real64
    state%dimoca = 0.0_real64
    state%pond = 0.0_real64
    state%pondm1 = 0.0_real64
    state%gwl = -2.0_real64
    state%gwlm1 = -2.0_real64
    state%gwlinp = -5.0_real64
    state%dtold = dt
    state%qtop = -1.0_real64
    state%qbot = -1.0_real64
    state%hbot = -100.0_real64
    state%q0 = 0.0_real64
    state%hsurf = 9000.0_real64 + real(column,real64)
    state%runots = 0.0_real64
    state%itnumb = 0
    state%numbit = 0
    state%fllowgwl = .false.
    state%fldecdt = .false.
    state%flrunoff = .false.
    state%ftoph = .false.

    call a23bu_initialize_worker(worker, numnod, column)
    history%flwarn = .false.
    history%iwarn = 0
    history%nstep = 0
    call initialize_reference_workspace(workspace, numnod)
    call poison_reference_workspace(workspace)
  end subroutine initialize_column

  integer(int64) function state_fingerprint(state, worker) result(fp)
    type(reference_richards_state_binding_t), intent(in) :: state
    type(a23bu_worker_context_t), intent(in) :: worker
    integer :: j
    fp = 1469598103934665603_int64
    do j = 1, numnod
      fp = ieor(fp, transfer(state%h(j), fp))
      fp = ieor(fp, transfer(state%theta(j), fp))
    end do
    fp = ieor(fp, transfer(state%qtop, fp))
    fp = ieor(fp, transfer(state%qbot, fp))
    fp = ieor(fp, transfer(state%hsurf, fp))
    fp = ieor(fp, int(state%numbit, int64))
    fp = ieor(fp, int(worker%diagnostics%nonlinear_iterations, int64))
    fp = ieor(fp, int(worker%diagnostics%jacobian_builds, int64))
    fp = ieor(fp, int(worker%diagnostics%linear_solves, int64))
  end function state_fingerprint

end program test_fsi07_real_concurrency

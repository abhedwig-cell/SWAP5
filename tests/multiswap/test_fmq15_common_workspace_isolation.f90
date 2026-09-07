program test_fmq15_common_workspace_isolation
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use omp_lib, only: omp_get_thread_num
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, &
       initialize_reference_workspace, poison_reference_workspace, reset_reference_workspace, &
       release_reference_workspace, reference_workspace_payload_bytes
  implicit none

  integer, parameter :: ncols = 256
  integer, parameter :: active_nodes = 12
  integer, parameter :: ncases = 4
  integer, parameter :: worker_counts(ncases) = [1, 2, 4, 8]
  real(real64) :: results(ncols), expected(ncols)
  integer :: failures, i, icase, order_mode
  integer(int64) :: bytes_one, signature_total

  failures = 0
  do i = 1, ncols
     expected(i) = real(active_nodes * i, real64)
  end do

  bytes_one = -1_int64
  do icase = 1, ncases
     do order_mode = 1, 2
        call run_case(worker_counts(icase), order_mode == 2, results, failures, bytes_one)
        do i = 1, ncols
           if (results(i) /= expected(i)) failures = failures + 1
        end do
     end do
  end do

  signature_total = nint(sum(expected), kind=int64)

  if (failures /= 0) then
     print '(A,I0)', 'F-MQ15_COMMON_WORKSPACE_GATE FAIL failures=', failures
     error stop 1
  end if

  print '(A)', 'F-MQ15_COMMON_WORKSPACE_GATE PASS'
  print '(A,I0)', 'columns=', ncols
  print '(A)', 'worker_counts=1,2,4,8'
  print '(A)', 'orders=forward,reverse'
  print '(A,I0)', 'workspace_payload_bytes_per_worker=', bytes_one
  print '(A,I0)', 'column_signature_total=', signature_total

contains

  subroutine run_case(nworkers, reverse_order, results_out, failures, bytes_reference)
    integer, intent(in) :: nworkers
    logical, intent(in) :: reverse_order
    real(real64), intent(out) :: results_out(ncols)
    integer, intent(inout) :: failures
    integer(int64), intent(inout) :: bytes_reference

    type(reference_richards_workspace_t), allocatable :: workspaces(:)
    integer :: worker, pos, col, j
    integer(int64) :: bytes_this, bytes_total

    allocate(workspaces(nworkers))
    do worker = 1, nworkers
       call initialize_reference_workspace(workspaces(worker), active_nodes)
    end do

    bytes_this = reference_workspace_payload_bytes(workspaces(1))
    if (bytes_this <= 0_int64) failures = failures + 1
    if (bytes_reference < 0_int64) then
       bytes_reference = bytes_this
    else if (bytes_this /= bytes_reference) then
       failures = failures + 1
    end if

    bytes_total = 0_int64
    do worker = 1, nworkers
       if (reference_workspace_payload_bytes(workspaces(worker)) /= bytes_this) failures = failures + 1
       bytes_total = bytes_total + reference_workspace_payload_bytes(workspaces(worker))
    end do
    if (bytes_total /= int(nworkers, int64) * bytes_this) failures = failures + 1

    results_out = -1.0_real64

!$omp parallel do num_threads(nworkers) schedule(static,1) reduction(+:failures) private(worker,col,j)
    do pos = 1, ncols
       worker = omp_get_thread_num() + 1
       if (reverse_order) then
          col = ncols - pos + 1
       else
          col = pos
       end if

       call poison_reference_workspace(workspaces(worker))
       if (.not. workspaces(worker)%poisoned) failures = failures + 1
       if (.not. all(ieee_is_nan(workspaces(worker)%residual))) failures = failures + 1
       if (.not. workspaces(worker)%has_warm_start) failures = failures + 1

       call reset_reference_workspace(workspaces(worker))
       if (workspaces(worker)%poisoned) failures = failures + 1
       if (workspaces(worker)%has_warm_start) failures = failures + 1
       if (any(workspaces(worker)%residual /= 0.0_real64)) failures = failures + 1
       if (any(workspaces(worker)%warm_start_head /= 0.0_real64)) failures = failures + 1
       if (workspaces(worker)%diagnostics%nonlinear_iterations /= 0) failures = failures + 1

       do j = 1, active_nodes
          workspaces(worker)%residual(j) = real(col, real64)
          workspaces(worker)%warm_start_head(j) = -real(col + j, real64)
       end do
       workspaces(worker)%has_warm_start = .true.
       workspaces(worker)%diagnostics%nonlinear_iterations = col
       results_out(col) = sum(workspaces(worker)%residual)
    end do
!$omp end parallel do

    do worker = 1, nworkers
       call release_reference_workspace(workspaces(worker))
       if (workspaces(worker)%active_nodes /= 0) failures = failures + 1
    end do
    deallocate(workspaces)
  end subroutine run_case

end program test_fmq15_common_workspace_isolation

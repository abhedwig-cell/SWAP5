program test_fpe07_worker_memory
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       reference_workspace_payload_bytes
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker, &
       a23bu_scratch_payload_bytes
  implicit none

  integer, parameter :: n = 4
  integer, parameter :: drainage_levels = 2
  type(reference_richards_workspace_t) :: richards
  type(a23bu_worker_context_t) :: worker
  integer(int64) :: richards_bytes, a23bu_bytes, backend_cache_bytes, total_bytes
  integer(int64) :: rb, ib, lb

  rb = storage_size(0.0d0)/8
  ib = storage_size(0)/8
  lb = storage_size(.false.)/8

  call initialize_reference_workspace(richards, n)
  call a23bu_initialize_worker(worker, n, 1)

  richards_bytes = reference_workspace_payload_bytes(richards)
  a23bu_bytes = int(a23bu_scratch_payload_bytes(worker), int64)
  backend_cache_bytes = rb * int((45 + drainage_levels + 2) * n, int64)
  total_bytes = richards_bytes + a23bu_bytes + backend_cache_bytes

  call require(richards_bytes == rb*int(23*n+2,int64) + ib*int(n,int64) + lb*int(2*n+3,int64), &
       'reference workspace payload formula')
  call require(a23bu_bytes == rb*int(11*n+2,int64) + lb*int(2*n+3,int64), &
       'A23BU scratch payload formula')
  call require(total_bytes == 2792_int64, 'frozen four-node known dynamic worker payload')

  write(*,'(A,I0)') 'FPE07_MEMORY_REFERENCE_WORKSPACE_BYTES=', richards_bytes
  write(*,'(A,I0)') 'FPE07_MEMORY_A23BU_SCRATCH_BYTES=', a23bu_bytes
  write(*,'(A,I0)') 'FPE07_MEMORY_BACKEND_CACHE_BYTES=', backend_cache_bytes
  write(*,'(A,I0)') 'FPE07_MEMORY_KNOWN_DYNAMIC_BYTES_PER_WORKER=', total_bytes
  write(*,'(A)') 'FPE07_WORKER_MEMORY_PROBE PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FPE07_MEMORY_FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe07_worker_memory

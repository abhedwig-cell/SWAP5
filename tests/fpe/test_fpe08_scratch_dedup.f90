program test_fpe08_scratch_dedup
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker, &
       a23bu_release_worker, a23bu_scratch_payload_bytes
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       reference_workspace_payload_bytes
  implicit none

  integer, parameter :: n = 4
  integer, parameter :: drainage_levels = 2
  type(a23bu_worker_context_t) :: worker
  type(reference_richards_workspace_t) :: richards
  integer(int64) :: rb
  integer :: full_bytes, lean_bytes
  integer(int64) :: reference_bytes, backend_cache_bytes, full_known_payload, lean_known_payload

  rb = storage_size(0.0d0)/8
  call initialize_reference_workspace(richards, n)
  reference_bytes = reference_workspace_payload_bytes(richards)
  backend_cache_bytes = rb * int((45 + drainage_levels + 2) * n, int64)

  call a23bu_initialize_worker(worker, n, 17)
  full_bytes = a23bu_scratch_payload_bytes(worker)
  call require(worker%active_nodes == n, 'default worker active_nodes')
  call require(worker%worker_id == 17, 'default worker id')
  call require(full_bytes == 412, 'default initializer preserves four-node scratch payload')
  call require(allocated(worker%headcalc%dfdhl), 'default initializer allocates scratch')
  full_known_payload = reference_bytes + int(full_bytes,int64) + backend_cache_bytes

  call a23bu_release_worker(worker)
  call a23bu_initialize_worker(worker, n, 23, allocate_headcalc_scratch=.false.)
  lean_bytes = a23bu_scratch_payload_bytes(worker)
  call require(worker%active_nodes == n, 'lean worker active_nodes')
  call require(worker%worker_id == 23, 'lean worker id')
  call require(lean_bytes == 0, 'lean initializer carries zero HeadCalc scratch payload')
  call require(.not. allocated(worker%headcalc%dfdhl), 'lean initializer leaves scratch unallocated')
  call require(.not. allocated(worker%headcalc%qv), 'lean initializer leaves flux scratch unallocated')
  call require(.not. allocated(worker%headcalc%flnonconv1), 'lean initializer leaves logical scratch unallocated')
  lean_known_payload = reference_bytes + int(lean_bytes,int64) + backend_cache_bytes

  call require(reference_bytes == 812_int64, 'reference workspace payload unchanged')
  call require(backend_cache_bytes == 1568_int64, 'backend cache payload unchanged')
  call require(full_known_payload == 2792_int64, 'pre-optimization known worker payload')
  call require(lean_known_payload == 2380_int64, 'post-optimization known worker payload')
  call require(full_known_payload-lean_known_payload == 412_int64, 'known payload saving')

  write(*,'(A,I0)') 'FPE08_DEFAULT_SCRATCH_BYTES=', full_bytes
  write(*,'(A,I0)') 'FPE08_CANONICAL_LEAN_SCRATCH_BYTES=', lean_bytes
  write(*,'(A,I0)') 'FPE08_KNOWN_WORKER_PAYLOAD_BEFORE_BYTES=', full_known_payload
  write(*,'(A,I0)') 'FPE08_KNOWN_WORKER_PAYLOAD_AFTER_BYTES=', lean_known_payload
  write(*,'(A,I0)') 'FPE08_REMOVED_BYTES_FOUR_NODE_FIXTURE=', full_known_payload-lean_known_payload
  write(*,'(A)') 'FPE08_SCRATCH_DEDUP_PROBE PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FPE08_FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe08_scratch_dedup

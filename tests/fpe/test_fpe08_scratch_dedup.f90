program test_fpe08_scratch_dedup
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker, &
       a23bu_release_worker, a23bu_scratch_payload_bytes
  implicit none

  type(a23bu_worker_context_t) :: worker
  integer :: full_bytes, lean_bytes

  call a23bu_initialize_worker(worker, 4, 17)
  full_bytes = a23bu_scratch_payload_bytes(worker)
  call require(worker%active_nodes == 4, 'default worker active_nodes')
  call require(worker%worker_id == 17, 'default worker id')
  call require(full_bytes == 412, 'default initializer preserves four-node scratch payload')
  call require(allocated(worker%headcalc%dfdhl), 'default initializer allocates scratch')

  call a23bu_release_worker(worker)
  call a23bu_initialize_worker(worker, 4, 23, allocate_headcalc_scratch=.false.)
  lean_bytes = a23bu_scratch_payload_bytes(worker)
  call require(worker%active_nodes == 4, 'lean worker active_nodes')
  call require(worker%worker_id == 23, 'lean worker id')
  call require(lean_bytes == 0, 'lean initializer carries zero HeadCalc scratch payload')
  call require(.not. allocated(worker%headcalc%dfdhl), 'lean initializer leaves scratch unallocated')
  call require(.not. allocated(worker%headcalc%qv), 'lean initializer leaves flux scratch unallocated')
  call require(.not. allocated(worker%headcalc%flnonconv1), 'lean initializer leaves logical scratch unallocated')

  write(*,'(A,I0)') 'FPE08_DEFAULT_SCRATCH_BYTES=', full_bytes
  write(*,'(A,I0)') 'FPE08_CANONICAL_LEAN_SCRATCH_BYTES=', lean_bytes
  write(*,'(A,I0)') 'FPE08_REMOVED_BYTES_FOUR_NODE_FIXTURE=', full_bytes-lean_bytes
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

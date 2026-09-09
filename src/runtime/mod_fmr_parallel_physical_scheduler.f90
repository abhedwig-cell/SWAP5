module mod_fmr_parallel_physical_scheduler
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_build_execution_order
  implicit none
  private

  integer, parameter, public :: FMR_PARALLEL_SCHEDULE_OK = 0
  integer, parameter, public :: FMR_PARALLEL_SCHEDULE_INVALID_WORKER_COUNT = 1

  type, public :: fmr_parallel_assignment_t
    integer :: canonical_position = 0
    integer :: column_index = 0
    integer(int64) :: column_id = 0_int64
    integer(int64) :: template_id = 0_int64
    integer :: worker_id = 0
  end type fmr_parallel_assignment_t

  public :: fmr_build_parallel_schedule

contains

  subroutine fmr_build_parallel_schedule(columns, worker_count, assignments, status)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, intent(in) :: worker_count
    type(fmr_parallel_assignment_t), allocatable, intent(out) :: assignments(:)
    integer, intent(out) :: status

    integer, allocatable :: order(:)
    integer :: pos, idx

    status = FMR_PARALLEL_SCHEDULE_INVALID_WORKER_COUNT
    allocate(assignments(0))
    if (worker_count <= 0) return

    call fmr_build_execution_order(columns, order)
    deallocate(assignments)
    allocate(assignments(size(columns)))

    do pos = 1, size(order)
      idx = order(pos)
      assignments(pos)%canonical_position = pos
      assignments(pos)%column_index = idx
      assignments(pos)%column_id = columns(idx)%column_id
      assignments(pos)%template_id = columns(idx)%template_id
      assignments(pos)%worker_id = mod(pos - 1, worker_count) + 1
    end do

    status = FMR_PARALLEL_SCHEDULE_OK
  end subroutine fmr_build_parallel_schedule

end module mod_fmr_parallel_physical_scheduler

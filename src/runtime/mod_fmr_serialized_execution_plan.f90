module mod_fmr_serialized_execution_plan
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_build_execution_order
  implicit none
  private

  type, public :: fmr_serialized_execution_plan_t
    private
    logical :: initialized = .false.
    integer(int64), allocatable :: column_ids(:)
    integer(int64), allocatable :: column_template_ids(:)
    integer(int64), allocatable :: state_handles(:)
    integer(int64), allocatable :: template_ids(:)
    integer, allocatable :: order(:)
    integer, allocatable :: template_indices(:)
    integer(int64) :: max_state_handle = 0_int64
  contains
    procedure, public :: ready => execution_plan_ready
    procedure, public :: matches => execution_plan_matches
    procedure, public :: column_count => execution_plan_column_count
    procedure, public :: order_index => execution_plan_order_index
    procedure, public :: template_index => execution_plan_template_index
  end type fmr_serialized_execution_plan_t

  public :: fmr_build_serialized_execution_plan

contains

  subroutine fmr_build_serialized_execution_plan(columns, templates, state_count, plan, valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    integer, intent(in) :: state_count
    type(fmr_serialized_execution_plan_t), intent(out) :: plan
    logical, intent(out) :: valid
    integer :: i

    plan = fmr_serialized_execution_plan_t()
    valid = .false.

    if (.not. registry_structure_valid(columns, templates, state_count)) return

    allocate(plan%column_ids(size(columns)), plan%column_template_ids(size(columns)), &
         plan%state_handles(size(columns)), plan%template_indices(size(columns)), &
         plan%template_ids(size(templates)))

    if (size(columns) > 0) then
      plan%column_ids = columns%column_id
      plan%column_template_ids = columns%template_id
      plan%state_handles = columns%state_handle
      plan%max_state_handle = maxval(columns%state_handle)
    end if
    if (size(templates) > 0) plan%template_ids = templates%template_id

    call fmr_build_execution_order(columns, plan%order)
    do i = 1, size(columns)
      plan%template_indices(i) = find_template_index(columns(i)%template_id, templates)
    end do

    plan%initialized = .true.
    valid = .true.
  end subroutine fmr_build_serialized_execution_plan

  logical function execution_plan_ready(self) result(ready)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    ready = self%initialized .and. allocated(self%column_ids) .and. &
         allocated(self%column_template_ids) .and. allocated(self%state_handles) .and. &
         allocated(self%template_ids) .and. allocated(self%order) .and. allocated(self%template_indices)
  end function execution_plan_ready

  logical function execution_plan_matches(self, columns, templates, state_count) result(matches)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    integer, intent(in) :: state_count
    integer :: i

    matches = .false.
    if (.not. self%ready()) return
    if (size(columns) /= size(self%column_ids)) return
    if (size(templates) /= size(self%template_ids)) return
    if (int(state_count,int64) < self%max_state_handle) return

    do i = 1, size(columns)
      if (columns(i)%column_id /= self%column_ids(i)) return
      if (columns(i)%template_id /= self%column_template_ids(i)) return
      if (columns(i)%state_handle /= self%state_handles(i)) return
    end do
    do i = 1, size(templates)
      if (templates(i)%template_id /= self%template_ids(i)) return
    end do
    matches = .true.
  end function execution_plan_matches

  integer function execution_plan_column_count(self) result(value)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    value = 0
    if (allocated(self%column_ids)) value = size(self%column_ids)
  end function execution_plan_column_count

  integer function execution_plan_order_index(self, position) result(index)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    integer, intent(in) :: position
    index = 0
    if (.not. allocated(self%order)) return
    if (position < 1 .or. position > size(self%order)) return
    index = self%order(position)
  end function execution_plan_order_index

  integer function execution_plan_template_index(self, column_index) result(index)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    integer, intent(in) :: column_index
    index = 0
    if (.not. allocated(self%template_indices)) return
    if (column_index < 1 .or. column_index > size(self%template_indices)) return
    index = self%template_indices(column_index)
  end function execution_plan_template_index

  logical function registry_structure_valid(columns, templates, state_count) result(valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    integer, intent(in) :: state_count
    integer :: i, j

    valid = .false.
    if (state_count < 0) return

    do i = 1, size(templates)
      if (templates(i)%template_id <= 0_int64) return
      do j = i + 1, size(templates)
        if (templates(j)%template_id == templates(i)%template_id) return
      end do
    end do

    do i = 1, size(columns)
      if (columns(i)%column_id <= 0_int64) return
      do j = i + 1, size(columns)
        if (columns(j)%column_id == columns(i)%column_id) return
        if (columns(j)%state_handle == columns(i)%state_handle) return
      end do
      if (columns(i)%state_handle < 1_int64 .or. &
          columns(i)%state_handle > int(state_count, int64)) return
    end do

    valid = .true.
  end function registry_structure_valid

  integer function find_template_index(template_id, templates) result(index)
    integer(int64), intent(in) :: template_id
    type(fmr_template_t), intent(in) :: templates(:)
    integer :: i

    index = 0
    do i = 1, size(templates)
      if (templates(i)%template_id == template_id) then
        index = i
        return
      end if
    end do
  end function find_template_index

end module mod_fmr_serialized_execution_plan

module mod_fmr_tillage_type_binding
  implicit none
  private
  integer, parameter, public :: TILLAGE_TYPE_BIND_OK = 0
  integer, parameter, public :: TILLAGE_TYPE_BIND_INVALID = 1
  public :: bind_tillage_type_rows
contains
  pure subroutine bind_tillage_type_rows(type_ids,event_types,expected_rows,first_row,last_row,status)
    integer, intent(in) :: type_ids(:),event_types(:),expected_rows(:)
    integer, allocatable, intent(out) :: first_row(:),last_row(:)
    integer, intent(out) :: status
    integer :: i,j,n,found_first,found_last
    status = TILLAGE_TYPE_BIND_INVALID
    n = size(event_types)
    if (n < 1 .or. size(type_ids) < 1 .or. size(expected_rows) /= n) return
    if (any(type_ids < 1) .or. any(event_types < 1) .or. any(expected_rows < 1)) return
    ! Map sparse type identifiers to explicit row slices; reject interleaving
    ! and missing or mismatched blocks instead of indexing the B1.11 arrays
    ! by event ordinal.
    do j=2,size(type_ids)
      if (type_ids(j) < type_ids(j-1)) return
    end do
    allocate(first_row(n),last_row(n))
    do i=1,n
      found_first = 0
      found_last = 0
      do j=1,size(type_ids)
        if (type_ids(j) /= event_types(i)) cycle
        if (found_first == 0) found_first = j
        found_last = j
      end do
      if (found_first < 1) then
        deallocate(first_row,last_row)
        return
      end if
      if (found_last-found_first+1 /= expected_rows(i)) then
        deallocate(first_row,last_row)
        return
      end if
      first_row(i) = found_first
      last_row(i) = found_last
    end do
    status = TILLAGE_TYPE_BIND_OK
  end subroutine
end module

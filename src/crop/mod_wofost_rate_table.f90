module mod_wofost_rate_table
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: WOFOST_RATE_TABLE_OK = 0
  integer, parameter, public :: WOFOST_RATE_TABLE_INVALID_SIZE = 1
  integer, parameter, public :: WOFOST_RATE_TABLE_INVALID_VALUE = 2
  integer, parameter, public :: WOFOST_RATE_TABLE_INVALID_X_ORDER = 3
  integer, parameter, public :: WOFOST_RATE_TABLE_INVALID_TABLE = 4
  integer, parameter, public :: WOFOST_RATE_TABLE_INVALID_QUERY = 5

  type, public :: wofost_rate_table_t
    private
    real(real64), allocatable :: x(:)
    real(real64), allocatable :: y(:)
  contains
    procedure, public :: ready => wofost_rate_table_ready
    procedure, public :: knot_count => wofost_rate_table_knot_count
    procedure, public :: evaluate => wofost_rate_table_evaluate
  end type wofost_rate_table_t

  public :: construct_wofost_rate_table

contains

  subroutine construct_wofost_rate_table(x_values, y_values, table, status)
    real(real64), intent(in) :: x_values(:)
    real(real64), intent(in) :: y_values(:)
    type(wofost_rate_table_t), intent(out) :: table
    integer, intent(out) :: status
    integer :: i, n

    status = WOFOST_RATE_TABLE_OK
    n = size(x_values)

    if (n < 1 .or. size(y_values) /= n) then
      status = WOFOST_RATE_TABLE_INVALID_SIZE
      return
    end if
    if (.not. all(ieee_is_finite(x_values)) .or. .not. all(ieee_is_finite(y_values))) then
      status = WOFOST_RATE_TABLE_INVALID_VALUE
      return
    end if

    do i = 2, n
      if (x_values(i) <= x_values(i-1)) then
        status = WOFOST_RATE_TABLE_INVALID_X_ORDER
        return
      end if
    end do

    allocate(table%x(n), table%y(n))
    table%x = x_values
    table%y = y_values
  end subroutine construct_wofost_rate_table

  logical function wofost_rate_table_ready(self) result(ready)
    class(wofost_rate_table_t), intent(in) :: self
    integer :: i, n

    ready = .false.
    if (.not. allocated(self%x) .or. .not. allocated(self%y)) return
    n = size(self%x)
    if (n < 1 .or. size(self%y) /= n) return
    if (.not. all(ieee_is_finite(self%x)) .or. .not. all(ieee_is_finite(self%y))) return
    do i = 2, n
      if (self%x(i) <= self%x(i-1)) return
    end do
    ready = .true.
  end function wofost_rate_table_ready

  integer function wofost_rate_table_knot_count(self) result(count)
    class(wofost_rate_table_t), intent(in) :: self

    count = 0
    if (.not. self%ready()) return
    count = size(self%x)
  end function wofost_rate_table_knot_count

  subroutine wofost_rate_table_evaluate(self, query_x, value_y, status)
    class(wofost_rate_table_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    integer :: lo, hi, mid, n
    real(real64) :: fraction

    value_y = 0.0_real64
    status = WOFOST_RATE_TABLE_OK

    if (.not. self%ready()) then
      status = WOFOST_RATE_TABLE_INVALID_TABLE
      return
    end if
    if (.not. ieee_is_finite(query_x)) then
      status = WOFOST_RATE_TABLE_INVALID_QUERY
      return
    end if

    n = size(self%x)
    if (query_x <= self%x(1)) then
      value_y = self%y(1)
      return
    end if
    if (query_x >= self%x(n)) then
      value_y = self%y(n)
      return
    end if

    lo = 1
    hi = n
    do while (hi - lo > 1)
      mid = lo + (hi - lo) / 2
      if (query_x <= self%x(mid)) then
        hi = mid
      else
        lo = mid
      end if
    end do

    fraction = (query_x - self%x(lo)) / (self%x(hi) - self%x(lo))
    value_y = self%y(lo) + fraction * (self%y(hi) - self%y(lo))
  end subroutine wofost_rate_table_evaluate

end module mod_wofost_rate_table

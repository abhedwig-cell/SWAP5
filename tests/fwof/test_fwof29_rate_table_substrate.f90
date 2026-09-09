program test_fwof29_rate_table_substrate
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, &
       WOFOST_RATE_TABLE_OK, WOFOST_RATE_TABLE_INVALID_SIZE, &
       WOFOST_RATE_TABLE_INVALID_VALUE, WOFOST_RATE_TABLE_INVALID_X_ORDER, &
       WOFOST_RATE_TABLE_INVALID_TABLE, WOFOST_RATE_TABLE_INVALID_QUERY
  implicit none

  type(wofost_rate_table_t) :: table, one_knot, invalid_table
  real(real64), parameter :: compact_x(3) = [0.0_real64, 1.0_real64, 3.0_real64]
  real(real64), parameter :: compact_y(3) = [10.0_real64, 20.0_real64, 50.0_real64]
  real(real64), parameter :: legacy_full(6) = &
       [0.0_real64, 10.0_real64, 1.0_real64, 20.0_real64, 3.0_real64, 50.0_real64]
  real(real64), parameter :: legacy_partial(10) = &
       [0.0_real64, 10.0_real64, 1.0_real64, 20.0_real64, 3.0_real64, 50.0_real64, &
        -1.0_real64, 999.0_real64, -2.0_real64, 888.0_real64]
  real(real64), parameter :: queries(9) = &
       [-2.0_real64, 0.0_real64, 0.25_real64, 0.5_real64, 1.0_real64, &
        1.5_real64, 2.0_real64, 3.0_real64, 4.0_real64]
  real(real64) :: actual, expected, nanv
  integer :: i, status

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  call construct_wofost_rate_table(compact_x, compact_y, table, status)
  call require(status == WOFOST_RATE_TABLE_OK, 'compact table construction')
  call require(table%ready(), 'compact table ready')
  call require(table%knot_count() == 3, 'compact table knot count')

  do i = 1, size(queries)
    call table%evaluate(queries(i), actual, status)
    call require(status == WOFOST_RATE_TABLE_OK, 'compact evaluation status')
    expected = legacy_afgen(legacy_full, queries(i))
    call require(same_bits(actual, expected), 'full legacy AFGEN bitwise equivalence')
  end do
  write(*,'(A)') 'FWOF29_FULL_LEGACY_AFGEN_BITWISE_EQUIVALENCE=PASS'

  do i = 1, size(queries)
    call table%evaluate(queries(i), actual, status)
    call require(status == WOFOST_RATE_TABLE_OK, 'partial-table evaluation status')
    expected = legacy_afgen(legacy_partial, queries(i))
    call require(same_bits(actual, expected), 'partial legacy AFGEN bitwise equivalence')
  end do
  write(*,'(A)') 'FWOF29_SENTINEL_TAIL_REMOVAL_PRESERVES_ACTIVE_FUNCTION=PASS'

  call construct_wofost_rate_table([2.0_real64], [7.5_real64], one_knot, status)
  call require(status == WOFOST_RATE_TABLE_OK, 'one-knot table construction')
  call require(one_knot%ready(), 'one-knot ready')
  call require(one_knot%knot_count() == 1, 'one-knot count')
  call one_knot%evaluate(-100.0_real64, actual, status)
  call require(status == WOFOST_RATE_TABLE_OK .and. same_bits(actual, 7.5_real64), &
       'one-knot lower constant')
  call one_knot%evaluate(2.0_real64, actual, status)
  call require(status == WOFOST_RATE_TABLE_OK .and. same_bits(actual, 7.5_real64), &
       'one-knot exact constant')
  call one_knot%evaluate(100.0_real64, actual, status)
  call require(status == WOFOST_RATE_TABLE_OK .and. same_bits(actual, 7.5_real64), &
       'one-knot upper constant')
  write(*,'(A)') 'FWOF29_SINGLE_KNOT_CONSTANT_TABLE=PASS'

  call invalid_table%evaluate(0.0_real64, actual, status)
  call require(status == WOFOST_RATE_TABLE_INVALID_TABLE, 'unconstructed table rejected')

  call construct_wofost_rate_table([real(real64) ::], [real(real64) ::], invalid_table, status)
  call require(status == WOFOST_RATE_TABLE_INVALID_SIZE, 'empty table rejected')
  call construct_wofost_rate_table([0.0_real64, 1.0_real64], [1.0_real64], invalid_table, status)
  call require(status == WOFOST_RATE_TABLE_INVALID_SIZE, 'size mismatch rejected')
  call construct_wofost_rate_table([0.0_real64, 0.0_real64], [1.0_real64, 2.0_real64], invalid_table, status)
  call require(status == WOFOST_RATE_TABLE_INVALID_X_ORDER, 'duplicate x rejected')
  call construct_wofost_rate_table([1.0_real64, 0.0_real64], [1.0_real64, 2.0_real64], invalid_table, status)
  call require(status == WOFOST_RATE_TABLE_INVALID_X_ORDER, 'decreasing x rejected')
  call construct_wofost_rate_table([0.0_real64, nanv], [1.0_real64, 2.0_real64], invalid_table, status)
  call require(status == WOFOST_RATE_TABLE_INVALID_VALUE, 'nonfinite x rejected')
  call construct_wofost_rate_table([0.0_real64, 1.0_real64], [1.0_real64, nanv], invalid_table, status)
  call require(status == WOFOST_RATE_TABLE_INVALID_VALUE, 'nonfinite y rejected')
  write(*,'(A)') 'FWOF29_INVALID_TABLE_DATA_FAILS_CLOSED=PASS'

  call table%evaluate(nanv, actual, status)
  call require(status == WOFOST_RATE_TABLE_INVALID_QUERY, 'nonfinite query rejected')
  call require(same_bits(actual, 0.0_real64), 'failed query leaves deterministic zero result')
  write(*,'(A)') 'FWOF29_NONFINITE_QUERY_FAILS_CLOSED_WITHOUT_ARITHMETIC=PASS'

  write(*,'(A)') 'FWOF29_RATE_TABLE_SUBSTRATE_TEST PASS'

contains

  real(real64) function legacy_afgen(values, x) result(y)
    real(real64), intent(in) :: values(:), x
    integer :: i, iltab
    real(real64) :: slope

    iltab = size(values)
    if (values(1) >= x) then
      y = values(2)
      return
    end if

    do i = 3, iltab - 1, 2
      if (values(i) >= x) then
        slope = (values(i+1) - values(i-1)) / (values(i) - values(i-2))
        y = values(i-1) + (x - values(i-2)) * slope
        return
      end if
      if (values(i) < values(i-2)) then
        y = values(i-1)
        return
      end if
    end do

    y = values(iltab)
  end function legacy_afgen

  logical function same_bits(left, right) result(equal)
    real(real64), intent(in) :: left, right
    equal = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: ' // trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof29_rate_table_substrate

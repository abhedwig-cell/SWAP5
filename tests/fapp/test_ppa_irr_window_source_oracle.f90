program test_ppa_irr_window_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_window, only: scheduled_irrigation_window_open
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64), parameter :: tolerance = 1.0e-3_real64
  real(real64) :: current_date, start_date, end_date, u, v
  integer(int64) :: random_state
  integer :: i
  logical :: actual, expected

  call require(.not. scheduled_irrigation_window_open(.true., 0.0_real64, -tolerance, 0.0_real64), 1)
  call require(scheduled_irrigation_window_open(.true., 0.0_real64, &
       -nearest(tolerance, 1.0_real64), -tolerance), 2)
  call require(scheduled_irrigation_window_open(.true., 0.0_real64, -1.0_real64, -tolerance), 3)
  call require(.not. scheduled_irrigation_window_open(.true., 0.0_real64, -1.0_real64, &
       -nearest(tolerance, 1.0_real64)), 4)

  call require(scheduled_irrigation_window_open(.false., 0.0_real64, tolerance, 0.0_real64), 5)
  call require(.not. scheduled_irrigation_window_open(.false., 0.0_real64, &
       nearest(tolerance, 1.0_real64), 0.0_real64), 6)
  call require(scheduled_irrigation_window_open(.false., 0.0_real64, 0.0_real64, -tolerance), 7)
  call require(.not. scheduled_irrigation_window_open(.false., 0.0_real64, 0.0_real64, &
       -nearest(tolerance, 1.0_real64)), 8)

  random_state = 20260923_int64
  do i = 1, vector_count
    call random_unit(random_state, u)
    call random_unit(random_state, v)
    current_date = 20000.0_real64 + 36525.0_real64*u
    start_date = current_date - 2.0_real64 + 4.0_real64*v
    call random_unit(random_state, u)
    end_date = current_date - 2.0_real64 + 4.0_real64*u
    expected = source_crop_year_window(current_date, start_date, end_date)
    actual = scheduled_irrigation_window_open(.true., current_date, start_date, end_date)
    call require(actual .eqv. expected, 10)

    call random_unit(random_state, u)
    call random_unit(random_state, v)
    current_date = 20000.0_real64 + 36525.0_real64*u
    start_date = current_date - 2.0_real64 + 4.0_real64*v
    call random_unit(random_state, u)
    end_date = current_date - 2.0_real64 + 4.0_real64*u
    expected = source_absolute_window(current_date, start_date, end_date)
    actual = scheduled_irrigation_window_open(.false., current_date, start_date, end_date)
    call require(actual .eqv. expected, 11)
  end do

  print '(A)', 'PPA_IRR_CROP_YEAR_WINDOW_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_ABSOLUTE_WINDOW_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_WINDOW_TOLERANCE_OPERATOR_BOUNDARIES=PASS'
  print '(A)', 'PPA_IRR_WINDOW_SOURCE_ORACLE=PASS'

contains

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  logical function source_crop_year_window(date1900, crop_start, crop_end)
    real(real64), intent(in) :: date1900, crop_start, crop_end
    source_crop_year_window = (date1900-crop_start) > 1.0e-3_real64 .and. &
                              (date1900-crop_end) <= 1.0e-3_real64
  end function source_crop_year_window

  logical function source_absolute_window(date, absolute_start, absolute_end)
    real(real64), intent(in) :: date, absolute_start, absolute_end
    source_absolute_window = (date-absolute_start) >= -1.0e-3_real64 .and. &
                             (date-absolute_end) <= 1.0e-3_real64
  end function source_absolute_window

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_WINDOW_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_window_source_oracle

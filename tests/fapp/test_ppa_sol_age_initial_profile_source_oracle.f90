program test_ppa_sol_age_initial_profile_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_initial_profile
  implicit none

  integer, parameter :: ntab = 10, nnode = 7, ncase = 100000
  real(real64) :: table(ntab), depth(nnode), expected(nnode), got, want
  real(real64), allocatable :: profile(:)
  integer :: next_cursor, ref_cursor, status, i, j

  do j = 1, ncase
    table(1) = 0.0_real64
    table(2) = real(mod(j, 31), real64) / 10.0_real64
    do i = 2, 4
      table(2 * i - 1) = table(2 * i - 3) + 0.5_real64 + real(mod(j + i, 11), real64) / 100.0_real64
      table(2 * i) = table(2 * i - 2) + real(mod(j * (i + 3), 29) - 14, real64) / 20.0_real64
    end do
    if (mod(j, 3) == 0) then
      table(9) = table(7) - 0.25_real64
    else
      table(9) = table(7) + 0.5_real64
    end if
    table(10) = table(8) + 0.2_real64
    do i = 1, nnode
      depth(i) = real(i - 1, real64) * 0.45_real64 + real(mod(j + i * 5, 13), real64) / 100.0_real64
    end do
    ref_cursor = 0
    do i = 1, nnode
      call reference_afgen2(table, depth(i), ref_cursor, want)
      call ppa_sol_age_afgen2_candidate(table, depth(i), ref_cursor, got, next_cursor, status)
      if (status /= PPA_SOL_AGE_INIT_OK) then
        write(*,*) j, i, ref_cursor, depth(i), table
        error stop 'valid interpolation rejected'
      end if
      if (transfer(want, 0_int64) /= transfer(got, 0_int64) .or. ref_cursor /= next_cursor) &
           error stop 'afgen2 value/cursor mismatch'
      ref_cursor = next_cursor
      expected(i) = want
    end do
    call ppa_sol_age_initialize_profile(table, depth, profile, status)
    if (status /= PPA_SOL_AGE_INIT_OK) error stop 'valid profile initialization rejected'
    do i = 1, nnode
      if (transfer(expected(i), 0_int64) /= transfer(profile(i), 0_int64)) error stop 'initialized profile mismatch'
    end do
  end do
  print '(a)', 'PPA_SOL_AGE_INIT_B1_11_AFGEN2_100000x7=PASS'
  print '(a)', 'PPA_SOL_AGE_INIT_CURSOR_AND_PARTIAL_TABLE_TERMINATOR=PASS'

  table(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_afgen2_candidate(table, 0.0_real64, 0, got, next_cursor, status)
  if (status /= PPA_SOL_AGE_INIT_INVALID_INPUT) error stop 'nonfinite table accepted'
  table(1) = 0.0_real64
  call ppa_sol_age_afgen2_candidate(table, 0.0_real64, 2, got, next_cursor, status)
  if (status /= PPA_SOL_AGE_INIT_INVALID_INPUT) error stop 'even cursor accepted'
  depth(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_initialize_profile(table, depth, profile, status)
  if (status /= PPA_SOL_AGE_INIT_INVALID_INPUT) error stop 'nonfinite depth accepted'
  print '(a)', 'PPA_SOL_AGE_INIT_INVALID_INPUT_FAIL_CLOSED=PASS'

contains

  subroutine reference_afgen2(values, x, position, y)
    real(real64), intent(in) :: values(:), x
    integer, intent(inout) :: position
    real(real64), intent(out) :: y
    integer :: k
    real(real64) :: slope
    if (values(1) >= x) then
      y = values(2)
      position = 1
      return
    end if
    do k = max(3, position), size(values) - 1, 2
      if (values(k) >= x) then
        slope = (values(k + 1) - values(k - 1)) / (values(k) - values(k - 2))
        y = values(k - 1) + (x - values(k - 2)) * slope
        position = k - 2
        return
      end if
      if (values(k) < values(k - 2)) then
        y = values(k - 1)
        position = k - 2
        return
      end if
    end do
    y = values(size(values))
    position = size(values) - 1
  end subroutine reference_afgen2

end program test_ppa_sol_age_initial_profile_source_oracle

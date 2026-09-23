program test_ppa_low05_hbot_table
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low05_hbot_table
  implicit none
  real(real64), parameter :: dates(4) = [-2.0_real64, 0.0_real64, 3.0_real64, 7.0_real64]
  real(real64) :: heads(4), packed(12), query, actual, expected, saved, replay
  integer :: i, j, status

  heads = [-120.0_real64, -80.0_real64, -10.0_real64, -50.0_real64]
  call check(-3.0_real64, -120.0_real64, 'lower endpoint clamp')
  call check(-2.0_real64, -120.0_real64, 'first knot')
  call check(0.0_real64, -80.0_real64, 'interior knot')
  call check(7.0_real64, -50.0_real64, 'last knot')
  call check(8.0_real64, -50.0_real64, 'upper endpoint clamp')
  call check(1.5_real64, -45.0_real64, 'linear interior interpolation')

  do i = 1, 100000
    do j = 1, 4
      heads(j) = real(mod(i*37 + j*109, 200001) - 100000, real64) / 1000.0_real64
    end do
    query = -3.0_real64 + real(mod(i*7919, 110001), real64) / 10000.0_real64
    packed = 0.0_real64
    do j = 1, 4
      packed(2*j-1) = dates(j)
      packed(2*j) = heads(j)
    end do
    expected = source_afgen(packed, query)
    call evaluate_ppa_low05_hbot_table(dates, heads, query, actual, status)
    if (status /= PPA_LOW05_HBOT_OK .or. transfer(actual, 0_int64) /= transfer(expected, 0_int64)) &
      error stop '100000-vector DATE5/HBOT5 source oracle mismatch'
  end do

  call evaluate_ppa_low05_hbot_table(dates, heads, 1.25_real64, saved, status)
  call evaluate_ppa_low05_hbot_table(dates, [0.0_real64, 1.0_real64, 2.0_real64, 3.0_real64], &
      1.25_real64, replay, status)
  call evaluate_ppa_low05_hbot_table(dates, heads, 1.25_real64, actual, status)
  if (transfer(saved, 0_int64) /= transfer(actual, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(replay, 0_int64)) &
    error stop 'A/B/A replay or fixture failed'
  call evaluate_ppa_low05_hbot_table([0.0_real64, 0.0_real64], [0.0_real64, 1.0_real64], &
      0.5_real64, actual, status)
  if (status /= PPA_LOW05_HBOT_INVALID_INPUT) error stop 'duplicate dates accepted'
  call evaluate_ppa_low05_hbot_table([0.0_real64], [ieee_value(0.0_real64, ieee_quiet_nan)], &
      0.5_real64, actual, status)
  if (status /= PPA_LOW05_HBOT_INVALID_INPUT) error stop 'nonfinite value accepted'

  write(*,'(a)') 'PPA_LOW05_HBOT_DATE5_AFGEN_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW05_HBOT_ENDPOINT_KNOT_AND_LINEAR=PASS'
  write(*,'(a)') 'PPA_LOW05_HBOT_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW05_HBOT_INVALID_TABLE_FAIL_CLOSED=PASS'

contains

  subroutine check(at, want, label)
    real(real64), intent(in) :: at, want
    character(len=*), intent(in) :: label
    call evaluate_ppa_low05_hbot_table(dates, heads, at, actual, status)
    if (status /= PPA_LOW05_HBOT_OK .or. abs(actual-want) > 16.0_real64*epsilon(want)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

  pure real(real64) function source_afgen(table, x) result(y)
    real(real64), intent(in) :: table(:), x
    real(real64) :: slope
    integer :: k
    if (table(1) >= x) then
      y = table(2)
      return
    end if
    do k = 3, size(table)-1, 2
      if (table(k) >= x) then
        slope = (table(k+1)-table(k-1))/(table(k)-table(k-2))
        y = table(k-1)+(x-table(k-2))*slope
        return
      end if
      if (table(k) < table(k-2)) then
        y = table(k-1)
        return
      end if
    end do
    y = table(size(table))
  end function source_afgen

end program test_ppa_low05_hbot_table

program test_ppa_low03_aquifer_table
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low03_aquifer_table
  implicit none
  real(real64), parameter :: dates(4) = [-2.0_real64, 0.0_real64, 3.0_real64, 7.0_real64]
  real(real64) :: heads(4), packed(8), query, actual, expected, saved, replay, alternate
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
      select case (j)
      case (1)
        packed(2*j-1) = -2.0_real64
      case (2)
        packed(2*j-1) = 0.0_real64
      case (3)
        packed(2*j-1) = 3.0_real64
      case (4)
        packed(2*j-1) = 7.0_real64
      end select
      packed(2*j) = real(mod(i*37 + j*109, 110001) - 100000, real64) / 10.0_real64
    end do
    query = -3.0_real64 + real(mod(i*7919, 110001), real64) / 10000.0_real64
    expected = source_afgen(packed, query)
    call evaluate_ppa_low03_aquifer_table(packed(1::2), packed(2::2), query, actual, status)
    if (status /= PPA_LOW03_AQUIFER_TABLE_OK .or. transfer(actual, 0_int64) /= transfer(expected, 0_int64)) &
      error stop '100000-vector SW3=2 HAQUIF source oracle mismatch'
  end do

  call evaluate_ppa_low03_aquifer_table(dates, heads, 1.25_real64, saved, status)
  call evaluate_ppa_low03_aquifer_table(dates, [0.0_real64, 1.0_real64, 2.0_real64, 3.0_real64], &
      1.25_real64, alternate, status)
  call evaluate_ppa_low03_aquifer_table(dates, heads, 1.25_real64, replay, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'

  call evaluate_ppa_low03_aquifer_table([0.0_real64, 0.0_real64], [0.0_real64, 1.0_real64], &
      0.5_real64, actual, status)
  if (status /= PPA_LOW03_AQUIFER_TABLE_INVALID_INPUT) error stop 'duplicate dates accepted'
  call evaluate_ppa_low03_aquifer_table([0.0_real64], [ieee_value(0.0_real64, ieee_quiet_nan)], &
      0.5_real64, actual, status)
  if (status /= PPA_LOW03_AQUIFER_TABLE_INVALID_INPUT) error stop 'nonfinite aquifer head accepted'
  call evaluate_ppa_low03_aquifer_table([0.0_real64], [1000.1_real64], 0.5_real64, actual, status)
  if (status /= PPA_LOW03_AQUIFER_TABLE_INVALID_INPUT) error stop 'aquifer head input range not enforced'

  write(*,'(a)') 'PPA_LOW03_AQUIFER_DATE3_HAQUIF_AFGEN_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW03_AQUIFER_ENDPOINT_KNOT_AND_LINEAR=PASS'
  write(*,'(a)') 'PPA_LOW03_AQUIFER_TABLE_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW03_AQUIFER_INVALID_TABLE_FAIL_CLOSED=PASS'

contains

  subroutine check(at, want, label)
    real(real64), intent(in) :: at, want
    character(len=*), intent(in) :: label
    call evaluate_ppa_low03_aquifer_table(dates, heads, at, actual, status)
    if (status /= PPA_LOW03_AQUIFER_TABLE_OK .or. abs(actual-want) > 16.0_real64*epsilon(want)) then
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

end program test_ppa_low03_aquifer_table

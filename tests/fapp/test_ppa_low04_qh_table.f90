program test_ppa_low04_qh_table
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low04_qh_table
  implicit none
  real(real64), parameter :: htab(4) = [-10.0_real64, -100.0_real64, -1000.0_real64, -2000.0_real64]
  real(real64) :: qtab(4), packed(8), gwl, query, actual, expected, saved, replay, alternate
  integer :: i, j, status

  qtab = [-0.4_real64, -0.2_real64, 0.1_real64, 0.8_real64]
  call check(-1.0_real64, -0.4_real64, 'lower endpoint clamp')
  call check(-10.0_real64, -0.4_real64, 'first knot')
  call check(-100.0_real64, -0.2_real64, 'second knot')
  call check(550.0_real64, -0.05_real64, 'interior interpolation')
  call check(-2000.0_real64, 0.8_real64, 'upper endpoint clamp')

  do i = 1, 100000
    do j = 1, 4
      select case (j)
      case (1)
        packed(2*j-1) = 10.0_real64
      case (2)
        packed(2*j-1) = 100.0_real64
      case (3)
        packed(2*j-1) = 1000.0_real64
      case (4)
        packed(2*j-1) = 2000.0_real64
      end select
      packed(2*j) = real(mod(i*37 + j*109, 200001) - 100000, real64) / 1000.0_real64
    end do
    gwl = real(mod(i*7919, 200001)-100000, real64) / 100.0_real64
    query = abs(gwl)
    expected = source_afgen(packed, query)
    call evaluate_ppa_low04_qh_table(htab, packed(2::2), gwl, actual, status)
    if (status /= PPA_LOW04_QH_OK .or. transfer(actual, 0_int64) /= transfer(expected, 0_int64)) &
      error stop '100000-vector SWBOTB=4 q(h) source oracle mismatch'
  end do

  call evaluate_ppa_low04_qh_table(htab, qtab, -37.0_real64, saved, status)
  call evaluate_ppa_low04_qh_table(htab, [0.0_real64, 0.1_real64, 0.2_real64, 0.3_real64], &
      37.0_real64, alternate, status)
  call evaluate_ppa_low04_qh_table(htab, qtab, 37.0_real64, replay, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'

  call evaluate_ppa_low04_qh_table([0.0_real64, -10.0_real64, -5.0_real64], &
      [0.0_real64, 1.0_real64, 2.0_real64], 3.0_real64, actual, status)
  if (status /= PPA_LOW04_QH_INVALID_INPUT) error stop 'non-monotone absolute htab accepted'
  call evaluate_ppa_low04_qh_table(htab, qtab, ieee_value(0.0_real64, ieee_quiet_nan), actual, status)
  if (status /= PPA_LOW04_QH_INVALID_INPUT) error stop 'nonfinite GWL accepted'

  write(*,'(a)') 'PPA_LOW04_QH_ABS_HTAB_AFGEN_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW04_QH_ENDPOINT_KNOT_AND_LINEAR=PASS'
  write(*,'(a)') 'PPA_LOW04_QH_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW04_QH_INVALID_TABLE_FAIL_CLOSED=PASS'

contains

  subroutine check(water_level, want, label)
    real(real64), intent(in) :: water_level, want
    character(len=*), intent(in) :: label
    call evaluate_ppa_low04_qh_table(htab, qtab, water_level, actual, status)
    if (status /= PPA_LOW04_QH_OK .or. abs(actual-want) > 16.0_real64*epsilon(want)) then
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

end program test_ppa_low04_qh_table

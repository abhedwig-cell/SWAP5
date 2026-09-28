program test_ppa_wu05a3_satflow_outflow_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_satflow_outflow
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: signed_flux(8), expected(8), actual(8), expected_total, actual_total
  integer(int64) :: state, expected_bits, actual_bits
  integer :: i, n, top, bottom, status

  state = 20260923_int64
  do i = 1, vector_count
    n = 1 + modulo(i, size(signed_flux))
    call fill_flux(state, signed_flux(1:n))
    top = 1 + modulo(i+1, n)
    bottom = top + modulo(i+2, n-top+1)
    call source_outflow(bottom, top, signed_flux(1:n), expected(1:n), expected_total)
    call ppa_wu05a3_satflow_outflow(bottom, top, signed_flux(1:n), actual(1:n), actual_total, status)
    call require(status == PPA_WU05A3_SATFLOW_OUTFLOW_OK, 1)
    call require(all(transfer(expected(1:n), [0_int64], n) == transfer(actual(1:n), [0_int64], n)), 2)
    expected_bits = transfer(expected_total, expected_bits)
    actual_bits = transfer(actual_total, actual_bits)
    call require(expected_bits == actual_bits, 3)
  end do

  signed_flux = [1.0_real64, -2.0_real64, -3.0_real64, 4.0_real64, -5.0_real64, 6.0_real64, 7.0_real64, -8.0_real64]
  call ppa_wu05a3_satflow_outflow(3, 2, signed_flux, actual, actual_total, status)
  call require(status == PPA_WU05A3_SATFLOW_OUTFLOW_OK .and. &
       transfer(actual(2),0_int64) == transfer(2.0_real64,0_int64) .and. &
       transfer(actual(3),0_int64) == transfer(3.0_real64,0_int64) .and. &
       transfer(actual_total,0_int64) == transfer(5.0_real64,0_int64), 4)
  call ppa_wu05a3_satflow_outflow(1, 2, signed_flux, actual, actual_total, status)
  call require(status == PPA_WU05A3_SATFLOW_OUTFLOW_INACTIVE .and. &
       transfer(actual_total,0_int64) == 0_int64, 5)

  print '(A)', 'PPA_WU05A3_SATFLOW_OUTFLOW_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU05A3_NEGATIVE_ONLY_SIGN_PARTITION_AND_ORDERED_SUM=PASS'
  print '(A)', 'PPA_WU05A3_SATFLOW_BOTTOM_RANGE_INACTIVE_GATE=PASS'

contains

  subroutine fill_flux(random_state, values)
    integer(int64), intent(inout) :: random_state
    real(real64), intent(out) :: values(:)
    integer :: j
    do j = 1, size(values)
      values(j) = -20.0_real64 + 40.0_real64*next_unit(random_state)
    end do
  end subroutine fill_flux

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64)/1000000.0_real64
  end function next_unit

  subroutine source_outflow(bottom, first, signed, output, total)
    integer, intent(in) :: bottom, first
    real(real64), intent(in) :: signed(:)
    real(real64), intent(out) :: output(:), total
    integer :: j
    output = 0.0_real64
    total = 0.0_real64
    if (bottom < first) return
    do j = first, bottom
      if (signed(j) < 0.0_real64) then
        output(j)=-signed(j)
        total=total+output(j)
      end if
    end do
  end subroutine source_outflow

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(A,I0)') 'PPA_WU05A3_SATFLOW_OUTFLOW_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_satflow_outflow_source_oracle

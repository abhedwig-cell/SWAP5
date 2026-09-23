program test_ppa_wu05a3_rapid_drain_distribution_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_rapid_drain_distribution
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: kd(6), expected_flux(6), actual_flux(6), total_kd, potential_flux
  real(real64) :: expected_total, actual_total
  integer(int64) :: state, expected_bits, actual_bits
  integer :: i, n, top, bottom, status

  state = 20260923_int64
  do i = 1, vector_count
    n = 1 + modulo(i, size(kd))
    call fill_kd(state, kd(1:n))
    top = 1 + modulo(i, n)
    bottom = top + modulo(i+1, n-top+1)
    select case (modulo(i, 3))
    case (0)
      total_kd = 1.0e-15_real64
    case (1)
      total_kd = 1.0e-15_real64 + next_unit(state)
    case default
      total_kd = next_unit(state)*10.0_real64
    end select
    potential_flux = 10.0_real64*next_unit(state)

    call source_distribution(top, bottom, kd(1:n), total_kd, potential_flux, expected_flux(1:n), expected_total)
    call ppa_wu05a3_distribute_rapid_drain_flux(top, bottom, kd(1:n), total_kd, potential_flux, &
                                               actual_flux(1:n), actual_total, status)
    call require(status == PPA_WU05A3_DISTRIBUTION_OK, 1)
    call require(all(transfer(actual_flux(1:n), [0_int64], n) == &
                     transfer(expected_flux(1:n), [0_int64], n)), 2)
    expected_bits = transfer(expected_total, expected_bits)
    actual_bits = transfer(actual_total, actual_bits)
    call require(expected_bits == actual_bits, 3)
  end do

  print '(A)', 'PPA_WU05A3_RAPIDDRAIN_DISTRIBUTION_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU05A3_KD_DISTRIBUTION_THRESHOLD_AND_ZERO_ROUTE=PASS'

contains

  subroutine fill_kd(random_state, values)
    integer(int64), intent(inout) :: random_state
    real(real64), intent(out) :: values(:)
    integer :: j
    do j = 1, size(values)
      values(j) = 10.0_real64*next_unit(random_state)
    end do
  end subroutine fill_kd

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64)/1000000.0_real64
  end function next_unit

  subroutine source_distribution(first, last, values, sum_kd, input_flux, outputs, flux)
    integer, intent(in) :: first, last
    real(real64), intent(in) :: values(:), sum_kd, input_flux
    real(real64), intent(out) :: outputs(:), flux
    integer :: ic
    outputs = 0.0_real64
    flux = input_flux
    do ic = first, last
      if (sum_kd > 1.0e-15_real64) then
        outputs(ic) = input_flux*values(ic)/sum_kd
      else
        outputs(ic) = 0.0_real64
        flux = 0.0_real64
      end if
    end do
  end subroutine source_distribution

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(A,I0)') 'PPA_WU05A3_DISTRIBUTION_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_rapid_drain_distribution_source_oracle

program test_ppa_wu05a3_rapid_drain_kd_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_rapid_drain_kd
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: dz(6), diameter(6), pore_volume(6), component(6), expected_component(6)
  real(real64) :: saturation_fraction, exponent, expected_total, actual_total
  integer(int64) :: state, expected_bits, actual_bits
  integer :: i, n, top, bottom, status

  state = 20260923_int64
  do i = 1, vector_count
    n = 1 + modulo(i, size(dz))
    call fill_inputs(state, dz(1:n), diameter(1:n), pore_volume(1:n))
    top = 1 + modulo(i, n)
    bottom = top + modulo(i+1, n-top+1)
    saturation_fraction = next_unit(state)
    exponent = 0.2_real64 + 3.0_real64*next_unit(state)

    call source_kd(top, bottom, saturation_fraction, exponent, dz(1:n), diameter(1:n), &
                   pore_volume(1:n), expected_component(1:n), expected_total)
    call ppa_wu05a3_rapid_drain_conductivity(top, bottom, saturation_fraction, exponent, &
         dz(1:n), diameter(1:n), pore_volume(1:n), component(1:n), actual_total, status)
    call require(status == PPA_WU05A3_KD_OK, 1)
    call require(all(transfer(component(1:n), [0_int64], n) == &
                     transfer(expected_component(1:n), [0_int64], n)), 2)
    expected_bits = transfer(expected_total, expected_bits)
    actual_bits = transfer(actual_total, actual_bits)
    call require(expected_bits == actual_bits, 3)
  end do

  dz(1:2) = [1.0_real64, 2.0_real64]
  diameter(1:2) = [0.3_real64, 0.5_real64]
  pore_volume(1:2) = [0.1_real64, 0.4_real64]
  call ppa_wu05a3_rapid_drain_conductivity(1, 2, 0.5_real64, 1.0_real64, dz(1:2), diameter(1:2), &
       [1.1_real64, 0.4_real64], component(1:2), actual_total, status)
  actual_bits = transfer(actual_total, actual_bits)
  call require(status == PPA_WU05A3_KD_INVALID_INPUT .and. actual_bits == 0_int64, 4)

  print '(A)', 'PPA_WU05A3_RAPIDDRAIN_KD_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU05A3_TOP_SATURATION_AND_PROFILE_SUM=PASS'
  print '(A)', 'PPA_WU05A3_RAPIDDRAIN_KD_GEOMETRY_GUARD=PASS'

contains

  subroutine fill_inputs(random_state, thickness, diameters, volumes)
    integer(int64), intent(inout) :: random_state
    real(real64), intent(out) :: thickness(:), diameters(:), volumes(:)
    integer :: j
    do j = 1, size(thickness)
      thickness(j) = 0.25_real64 + 10.0_real64*next_unit(random_state)
      diameters(j) = 0.01_real64 + next_unit(random_state)
      volumes(j) = thickness(j) * 0.99_real64 * next_unit(random_state)
    end do
  end subroutine fill_inputs

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64)/1000000.0_real64
  end function next_unit

  subroutine source_kd(top, bottom, sat_fraction, power, thickness, diameters, volumes, by_compartment, total)
    integer, intent(in) :: top, bottom
    real(real64), intent(in) :: sat_fraction, power, thickness(:), diameters(:), volumes(:)
    real(real64), intent(out) :: by_compartment(:), total
    real(real64) :: water_thickness
    integer :: ic
    by_compartment = 0.0_real64
    total = 0.0_real64
    do ic = top, bottom
      water_thickness = diameters(ic) * (1.0_real64 - sqrt(1.0_real64-volumes(ic)/thickness(ic)))
      by_compartment(ic) = ((water_thickness**power)/diameters(ic))*thickness(ic)
      if (ic == top) by_compartment(ic) = sat_fraction*by_compartment(ic)
      total = total + by_compartment(ic)
    end do
  end subroutine source_kd

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(A,I0)') 'PPA_WU05A3_KD_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_rapid_drain_kd_source_oracle

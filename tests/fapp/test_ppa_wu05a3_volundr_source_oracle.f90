program test_ppa_wu05a3_volundr_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_volundr
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: dz(6), pore_volume(6), z_top, z_bottom, expected, actual
  integer(int64) :: state, expected_bits, actual_bits
  integer :: i, n, bottom_compartment, status

  state = 20260923_int64
  do i = 1, vector_count
    n = 1 + modulo(i, size(dz))
    call fill_inputs(state, dz(1:n), pore_volume(1:n))
    z_bottom = -20.0_real64 + 40.0_real64*next_unit(state)
    z_top = z_bottom - 2.0_real64 + 45.0_real64*next_unit(state)
    bottom_compartment = modulo(i, n+1)

    expected = source_volundr(z_top, z_bottom, bottom_compartment, dz(1:n), pore_volume(1:n))
    call ppa_wu05a3_volume_under_level(z_top, z_bottom, bottom_compartment, &
                                      dz(1:n), pore_volume(1:n), actual, status)
    call require(status == PPA_WU05A3_OK, 1)
    expected_bits = transfer(expected, expected_bits)
    actual_bits = transfer(actual, actual_bits)
    call require(actual_bits == expected_bits, 2)
  end do

  ! Source loop does no work when the requested level is at/below the start.
  dz(1:2) = [0.5_real64, 1.5_real64]
  pore_volume(1:2) = [0.2_real64, 0.8_real64]
  call ppa_wu05a3_volume_under_level(2.0_real64, 2.0_real64, 1, dz(1:2), pore_volume(1:2), actual, status)
  actual_bits = transfer(actual, actual_bits)
  call require(status == PPA_WU05A3_OK .and. actual_bits == 0_int64, 3)

  call ppa_wu05a3_volume_under_level(2.0_real64, 0.0_real64, 1, [0.0_real64, 1.0_real64], &
                                    pore_volume(1:2), actual, status)
  actual_bits = transfer(actual, actual_bits)
  call require(status == PPA_WU05A3_INVALID_INPUT .and. actual_bits == 0_int64, 4)
  call ppa_wu05a3_volume_under_level(2.0_real64, 0.0_real64, 1, dz(1:2), &
                                    pore_volume(1:1), actual, status)
  actual_bits = transfer(actual, actual_bits)
  call require(status == PPA_WU05A3_INVALID_INPUT .and. actual_bits == 0_int64, 5)

  print '(A)', 'PPA_WU05A3_VOLUNDR_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU05A3_SOURCE_LOOP_AND_FRACTIONAL_COMPARTMENT=PASS'
  print '(A)', 'PPA_WU05A3_INVALID_SHAPE_AND_GEOMETRY_FAIL_CLOSED=PASS'

contains

  subroutine fill_inputs(random_state, thickness, volumes)
    integer(int64), intent(inout) :: random_state
    real(real64), intent(out) :: thickness(:), volumes(:)
    integer :: j
    do j = 1, size(thickness)
      thickness(j) = 0.25_real64 + 10.0_real64*next_unit(random_state)
      volumes(j) = 0.1_real64 + 2.0_real64*next_unit(random_state)
    end do
  end subroutine fill_inputs

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64)/1000000.0_real64
  end function next_unit

  real(real64) function source_volundr(ztp, zbt, bottom, thickness, mp_volume) result(v)
    real(real64), intent(in) :: ztp, zbt, thickness(:), mp_volume(:)
    integer, intent(in) :: bottom
    real(real64) :: z_help
    integer :: ic
    v = 0.0_real64
    ic = bottom + 1
    z_help = zbt
    do while (z_help < ztp .and. ic > 1)
      ic = ic - 1
      z_help = z_help + thickness(ic)
      v = v + mp_volume(ic)
    end do
    if (v > 0.0_real64) v = v - (z_help-ztp)*mp_volume(ic)/thickness(ic)
  end function source_volundr

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(A,I0)') 'PPA_WU05A3_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_volundr_source_oracle

program test_ppa_wu05a3_drainable_storage_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_drainable_storage
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: dz(6), pore_volume(6), drain_base, macropore_bottom, storage, expected, actual
  integer(int64) :: state, expected_bits, actual_bits
  integer :: i, n, bottom_compartment, status

  state = 20260923_int64
  do i = 1, vector_count
    n = 1 + modulo(i, size(dz))
    call fill_inputs(state, dz(1:n), pore_volume(1:n))
    bottom_compartment = 1 + modulo(i, n)
    macropore_bottom = -20.0_real64 + 40.0_real64*next_unit(state)
    if (modulo(i, 2) == 0) then
      drain_base = macropore_bottom + 0.01_real64 + 10.0_real64*next_unit(state)
    else
      drain_base = macropore_bottom - 10.0_real64*next_unit(state)
    end if
    storage = 4.0_real64*next_unit(state)

    expected = source_drainable(drain_base, macropore_bottom, bottom_compartment, dz(1:n), &
                                pore_volume(1:n), storage)
    call ppa_wu05a3_drainable_storage(drain_base, macropore_bottom, bottom_compartment, &
         dz(1:n), pore_volume(1:n), storage, actual, status)
    call require(status == PPA_WU05A3_STORAGE_OK, 1)
    expected_bits = transfer(expected, expected_bits)
    actual_bits = transfer(actual, actual_bits)
    call require(expected_bits == actual_bits, 2)
  end do

  print '(A)', 'PPA_WU05A3_DRAINABLE_STORAGE_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU05A3_DRAIN_BASE_GATE_AND_STORAGE_CAP=PASS'

contains

  subroutine fill_inputs(random_state, thickness, volumes)
    integer(int64), intent(inout) :: random_state
    real(real64), intent(out) :: thickness(:), volumes(:)
    integer :: j
    do j = 1, size(thickness)
      thickness(j) = 0.25_real64 + 10.0_real64*next_unit(random_state)
      volumes(j) = thickness(j)*0.99_real64*next_unit(random_state)
    end do
  end subroutine fill_inputs

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64)/1000000.0_real64
  end function next_unit

  real(real64) function source_drainable(base, z_bottom, bottom, thickness, volumes, domain_storage) result(value)
    real(real64), intent(in) :: base, z_bottom, thickness(:), volumes(:), domain_storage
    integer, intent(in) :: bottom
    real(real64) :: under_volume
    under_volume = 0.0_real64
    if (z_bottom < base) then
      under_volume = source_volundr(base, z_bottom-0.5_real64*thickness(bottom), bottom, thickness, volumes)
    end if
    value = max(0.0_real64, domain_storage-under_volume)
  end function source_drainable

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
    write(*,'(A,I0)') 'PPA_WU05A3_STORAGE_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_drainable_storage_source_oracle

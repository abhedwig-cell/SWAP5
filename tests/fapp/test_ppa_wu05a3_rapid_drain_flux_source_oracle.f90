program test_ppa_wu05a3_rapid_drain_flux_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_rapid_drain_flux
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: zwalev, drain_base, zbottom, pond, kd, kd_reference, resistance_reference
  real(real64) :: reduction, dt, storage, expected_resistance, expected_flux, actual_resistance, actual_flux
  integer(int64) :: state, expected_bits, actual_bits
  integer :: i, status

  state = 20260923_int64
  do i = 1, vector_count
    drain_base = -20.0_real64 + 40.0_real64*next_unit(state)
    zbottom = drain_base - 5.0_real64 + 10.0_real64*next_unit(state)
    if (modulo(i, 3) == 0) then
      zwalev = -0.5e-7_real64
    else
      zwalev = -2.0_real64 + 4.0_real64*next_unit(state)
    end if
    pond = 0.5_real64*next_unit(state)
    select case (modulo(i, 4))
    case (0)
      kd = 0.0_real64
    case (1)
      kd = 1.0e-10_real64
    case default
      kd = 1.0e-10_real64 + 10.0_real64*next_unit(state)
    end select
    kd_reference = 0.01_real64 + 100.0_real64*next_unit(state)
    resistance_reference = 0.01_real64 + 10.0_real64*next_unit(state)
    reduction = next_unit(state)
    dt = 0.1_real64 + 2.0_real64*next_unit(state)
    storage = 5.0_real64*next_unit(state)

    call source_rapid_drain(zwalev, drain_base, zbottom, pond, kd, kd_reference, resistance_reference, &
                            reduction, dt, storage, expected_resistance, expected_flux)
    call ppa_wu05a3_rapid_drain_flux(zwalev, drain_base, zbottom, pond, kd, kd_reference, resistance_reference, &
         reduction, dt, storage, actual_resistance, actual_flux, status)
    call require(status == PPA_WU05A3_FLUX_OK, 1)
    expected_bits = transfer(expected_resistance, expected_bits)
    actual_bits = transfer(actual_resistance, actual_bits)
    call require(expected_bits == actual_bits, 2)
    expected_bits = transfer(expected_flux, expected_bits)
    actual_bits = transfer(actual_flux, actual_bits)
    call require(expected_bits == actual_bits, 3)
  end do

  print '(A)', 'PPA_WU05A3_RAPIDDRAIN_FLUX_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU05A3_KD_THRESHOLD_AND_POND_HEAD_BRANCHES=PASS'
  print '(A)', 'PPA_WU05A3_REFERENCE_RESISTANCE_AND_STORAGE_CAP=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64)/1000000.0_real64
  end function next_unit

  subroutine source_rapid_drain(zw, zbase, zbt, pnd, conductivity, conductivity_ref, resistance_ref, &
                                fr_reduce, delta_t, available_storage, resistance, outflow)
    real(real64), intent(in) :: zw, zbase, zbt, pnd, conductivity, conductivity_ref, resistance_ref
    real(real64), intent(in) :: fr_reduce, delta_t, available_storage
    real(real64), intent(out) :: resistance, outflow
    real(real64) :: delh, factor
    delh = zw - max(zbase, zbt)
    if (zw > -1.0e-7_real64) delh = delh + pnd
    delh = max(delh, 0.0_real64)
    if (conductivity > 1.0e-10_real64) then
      factor = min(conductivity_ref/conductivity, 1.1_real64)
      resistance = resistance_ref*factor
      outflow = fr_reduce*(delh/resistance)*delta_t
    else
      resistance = 0.0_real64
      outflow = 0.0_real64
    end if
    outflow = min(outflow, available_storage)
  end subroutine source_rapid_drain

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(A,I0)') 'PPA_WU05A3_RAPIDDRAIN_FLUX_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_rapid_drain_flux_source_oracle

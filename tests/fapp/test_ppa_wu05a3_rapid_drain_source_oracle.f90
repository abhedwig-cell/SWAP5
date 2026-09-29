program test_ppa_wu05a3_rapid_drain_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_rapid_drain
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: dz(6), diameter(6), volume(6), flux(6), expected_flux(6)
  real(real64) :: sat, power, storage, zbase, zbottom, zw, pond, kdref, resref, reduction, dt
  real(real64) :: total, resistance, total_kd, expected_total, expected_resistance, expected_kd
  integer(int64) :: state, actual_bits, expected_bits
  integer :: i, n, top, bottom, domain_id, drain_type, status
  logical :: enabled

  state = 20260923_int64
  do i = 1, vector_count
    n = 1 + modulo(i, size(dz))
    call fill_inputs(state, dz(1:n), diameter(1:n), volume(1:n))
    top = 1 + modulo(i, n)
    bottom = top + modulo(i+1, n-top+1)
    domain_id = 1 + modulo(i, 2)
    enabled = modulo(i, 5) /= 0
    drain_type = modulo(i, 3)
    sat = next_unit(state)
    power = 0.2_real64 + 3.0_real64*next_unit(state)
    zbase = -20.0_real64 + 40.0_real64*next_unit(state)
    zbottom = zbase - 5.0_real64 + 10.0_real64*next_unit(state)
    zw = -2.0_real64 + 4.0_real64*next_unit(state)
    pond = 0.5_real64*next_unit(state)
    storage = 5.0_real64*next_unit(state)
    kdref = 0.01_real64 + 100.0_real64*next_unit(state)
    resref = 0.01_real64 + 10.0_real64*next_unit(state)
    reduction = next_unit(state)
    dt = 0.1_real64 + 2.0_real64*next_unit(state)

    call source_rapid_drain(domain_id, top, bottom, enabled, zbase, drain_type, 1, sat, power, dz(1:n), &
         diameter(1:n), volume(1:n), storage, zbottom, zw, pond, kdref, resref, reduction, dt, &
         expected_flux(1:n), expected_total, expected_resistance, expected_kd)
    call ppa_wu05a3_rapid_drain(domain_id, top, bottom, enabled, zbase, drain_type, 1, sat, power, dz(1:n), &
         diameter(1:n), volume(1:n), storage, zbottom, zw, pond, kdref, resref, reduction, dt, &
         flux(1:n), total, resistance, total_kd, status)
    call require(status == expected_status(domain_id, enabled, zbottom, zbase, drain_type, 1), 1)
    call require(all(transfer(flux(1:n), [0_int64], n) == transfer(expected_flux(1:n), [0_int64], n)), 2)
    actual_bits = transfer(total, actual_bits); expected_bits = transfer(expected_total, expected_bits)
    call require(actual_bits == expected_bits, 3)
    actual_bits = transfer(resistance, actual_bits); expected_bits = transfer(expected_resistance, expected_bits)
    call require(actual_bits == expected_bits, 4)
    actual_bits = transfer(total_kd, actual_bits); expected_bits = transfer(expected_kd, expected_bits)
    call require(actual_bits == expected_bits, 5)
  end do

  print '(A)', 'PPA_WU05A3_RAPIDDRAIN_COMPOSED_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU05A3_DOMAIN_SWITCH_AND_DRAIN_TYPE_GATES=PASS'
  print '(A)', 'PPA_WU05A3_KD_STORAGE_HEAD_FLUX_DISTRIBUTION_COMPOSITION=PASS'

contains

  integer function expected_status(id, switch, zb, base, dtype, open_type)
    integer, intent(in) :: id, dtype, open_type
    logical, intent(in) :: switch
    real(real64), intent(in) :: zb, base
    if (id /= 1 .or. .not. switch .or. .not. (zb < base .or. dtype /= open_type)) then
      expected_status = PPA_WU05A3_RAPID_DRAIN_INACTIVE
    else
      expected_status = PPA_WU05A3_RAPID_DRAIN_OK
    end if
  end function expected_status

  subroutine fill_inputs(random_state, thickness, diameters, volumes)
    integer(int64), intent(inout) :: random_state
    real(real64), intent(out) :: thickness(:), diameters(:), volumes(:)
    integer :: j
    do j = 1, size(thickness)
      thickness(j) = 0.25_real64 + 10.0_real64*next_unit(random_state)
      diameters(j) = 0.01_real64 + next_unit(random_state)
      volumes(j) = thickness(j)*0.99_real64*next_unit(random_state)
    end do
  end subroutine fill_inputs

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64)/1000000.0_real64
  end function next_unit

  subroutine source_rapid_drain(id, top, bottom, switch, base, dtype, open_type, sat, power, thickness, diameters, &
       volumes, domain_storage, zbt, zw, pnd, kdref, resref, fr_reduce, delta_t, by_compartment, outflow, resistance, total_kd)
    integer, intent(in) :: id, top, bottom, dtype, open_type
    logical, intent(in) :: switch
    real(real64), intent(in) :: base, sat, power, thickness(:), diameters(:), volumes(:), domain_storage, zbt, zw, pnd
    real(real64), intent(in) :: kdref, resref, fr_reduce, delta_t
    real(real64), intent(out) :: by_compartment(:), outflow, resistance, total_kd
    real(real64) :: by_kd(size(thickness)), drainable, water_thickness, factor, delh
    integer :: ic
    by_compartment = 0.0_real64; outflow = 0.0_real64; resistance = 0.0_real64; total_kd = 0.0_real64
    if (id /= 1) return
    if (.not. switch) return
    if (.not. (zbt < base .or. dtype /= open_type)) return
    by_kd = 0.0_real64
    do ic = top, bottom
      water_thickness = diameters(ic)*(1.0_real64-sqrt(1.0_real64-volumes(ic)/thickness(ic)))
      by_kd(ic) = ((water_thickness**power)/diameters(ic))*thickness(ic)
      if (ic == top) by_kd(ic) = sat*by_kd(ic)
      total_kd = total_kd+by_kd(ic)
    end do
    drainable = 0.0_real64
    if (zbt < base) then
      drainable = source_volundr(base, zbt-0.5_real64*thickness(bottom), bottom, thickness, volumes)
    end if
    drainable = max(0.0_real64, domain_storage-drainable)
    delh = zw-max(base,zbt)
    if (zw > -1.0e-7_real64) delh=delh+pnd
    delh=max(delh,0.0_real64)
    if (total_kd > 1.0e-10_real64) then
      factor=min(kdref/total_kd,1.1_real64)
      resistance=resref*factor
      outflow=fr_reduce*(delh/resistance)*delta_t
    end if
    outflow=min(outflow,drainable)
    do ic=top,bottom
      if (total_kd > 1.0e-15_real64) then
        by_compartment(ic)=outflow*by_kd(ic)/total_kd
      else
        by_compartment(ic)=0.0_real64
        outflow=0.0_real64
      end if
    end do
  end subroutine source_rapid_drain

  real(real64) function source_volundr(ztp, zbt, bottom, thickness, volumes) result(value)
    real(real64), intent(in) :: ztp,zbt,thickness(:),volumes(:)
    integer, intent(in) :: bottom
    real(real64) :: zhelp
    integer :: ic
    value=0.0_real64
    ic=bottom+1
    zhelp=zbt
    do while (zhelp < ztp .and. ic > 1)
      ic=ic-1
      zhelp=zhelp+thickness(ic)
      value=value+volumes(ic)
    end do
    if (value > 0.0_real64) value=value-(zhelp-ztp)*volumes(ic)/thickness(ic)
  end function source_volundr

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(A,I0)') 'PPA_WU05A3_RAPIDDRAIN_COMPOSED_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_rapid_drain_source_oracle

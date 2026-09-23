program test_ppa_wu05a3_satflow_exchange_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_satflow_exchange
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64), parameter :: pi_value = 3.1415926535897932384626433832795_real64
  real(real64) :: matrix_head, reference_level, z, dz, lev, satfr, c_darcy, ksat, diameter, volume
  real(real64) :: shape_factor, reduction, dt, actual_head, expected_head, actual_flux, expected_flux
  real(real64) :: states(4, 2)
  integer :: actual_status, i, branch, compartment, sat_compartment, top_compartment, seepage_switch
  integer(int64) :: state, actual_bits, expected_bits

  states = 0.0_real64
  state = 20260923_int64
  do i = 1, vector_count
    matrix_head = -0.1_real64 + 3.0_real64*next_unit(state)
    reference_level = -2.0_real64 + 4.0_real64*next_unit(state)
    z = -2.0_real64 + 4.0_real64*next_unit(state)
    dz = 0.25_real64 + 5.0_real64*next_unit(state)
    lev = z - dz + 2.0_real64*dz*next_unit(state)
    satfr = next_unit(state)
    c_darcy = 0.01_real64 + 5.0_real64*next_unit(state)
    ksat = 0.01_real64 + 10.0_real64*next_unit(state)
    diameter = 0.01_real64 + 0.5_real64*next_unit(state)
    volume = 0.01_real64 + next_unit(state)
    shape_factor = 0.01_real64 + 2.0_real64*next_unit(state)
    reduction = next_unit(state)
    dt = 0.01_real64 + next_unit(state)
    sat_compartment = 1 + modulo(i, 3)
    top_compartment = 1 + modulo(i+1, 3)
    compartment = 1 + modulo(i+2, 3)
    seepage_switch = modulo(i, 2)

    ! Force the three exchange cases in a deterministic cycle.
    select case (modulo(i, 3))
    case (0)
      matrix_head = 0.2_real64
      reference_level = z + 1.0_real64
    case (1)
      matrix_head = 1.0_real64
      reference_level = z + 0.5_real64
    case default
      matrix_head = 1.0_real64
      reference_level = z - 1.0_real64
    end select

    call source_exchange(matrix_head, reference_level, z, dz, lev, sat_compartment, top_compartment, compartment, &
         satfr, c_darcy, seepage_switch, ksat, diameter, volume, shape_factor, pi_value, reduction, dt, &
         expected_head, expected_flux, branch)
    call ppa_wu05a3_satflow_exchange(matrix_head, reference_level, z, dz, lev, sat_compartment, top_compartment, &
         compartment, satfr, c_darcy, seepage_switch, ksat, diameter, volume, shape_factor, pi_value, reduction, dt, &
         actual_head, actual_flux, actual_status)
    call require(actual_status == PPA_WU05A3_SATFLOW_OK, 1)
    actual_bits = transfer(actual_head, actual_bits); expected_bits = transfer(expected_head, expected_bits)
    call require(actual_bits == expected_bits, 2)
    actual_bits = transfer(actual_flux, actual_bits); expected_bits = transfer(expected_flux, expected_bits)
    call require(actual_bits == expected_bits, 3)
    states(branch, 1+seepage_switch) = states(branch, 1+seepage_switch)+1.0_real64
  end do
  call require(states(1,1) > 0.0_real64 .and. states(2,1) > 0.0_real64 .and. &
       states(3,2) > 0.0_real64 .and. states(4,1) > 0.0_real64, 4)
  call ppa_wu05a3_satflow_exchange(1.0_real64, 1.0_real64+0.5e-8_real64, 0.0_real64, 1.0_real64, &
       0.5_real64, 1, 1, 1, 0.5_real64, 1.0_real64, 0, 1.0_real64, 0.2_real64, 0.1_real64, &
       1.0_real64, pi_value, 1.0_real64, 1.0_real64, actual_head, actual_flux, actual_status)
  call require(actual_status == PPA_WU05A3_SATFLOW_OK .and. transfer(actual_head,0_int64) == 0_int64 .and. &
       transfer(actual_flux,0_int64) == 0_int64, 5)
  call ppa_wu05a3_satflow_exchange(-0.1_real64, 1.0_real64, 0.0_real64, 1.0_real64, &
       0.5_real64, 1, 1, 1, 0.5_real64, 1.0_real64, 0, 1.0_real64, 0.2_real64, 0.1_real64, &
       1.0_real64, pi_value, 1.0_real64, 1.0_real64, actual_head, actual_flux, actual_status)
  call require(actual_status == PPA_WU05A3_SATFLOW_OK .and. transfer(actual_head,0_int64) == 0_int64 .and. &
       transfer(actual_flux,0_int64) == 0_int64, 6)

  print '(A)', 'PPA_WU05A3_SATFLOW_EXCHANGE_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU05A3_SATFLOW_HEAD_DIRECTION_AND_DEADBAND=PASS'
  print '(A)', 'PPA_WU05A3_SATFLOW_DARCY_AND_BOTH_SEEPAGE_ROUTES=PASS'
  print '(A)', 'PPA_WU05A3_SATFLOW_DEADBAND_AND_UNSATURATED_MATRIX_GUARDS=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64)/1000000.0_real64
  end function next_unit

  subroutine source_exchange(hma, ref, elevation, thickness, water_level, sat_comp, top_comp, ic, sat_fraction, &
       darcy, switch, conductivity, dia, pore, shape, pi, fr_reduce, delta_t, delh, flux, flow_branch)
    real(real64), intent(in) :: hma, ref, elevation, thickness, water_level, sat_fraction, darcy, conductivity
    real(real64), intent(in) :: dia, pore, shape, pi, fr_reduce, delta_t
    integer, intent(in) :: sat_comp, top_comp, ic, switch
    real(real64), intent(out) :: delh, flux
    integer, intent(out) :: flow_branch
    real(real64) :: hmp, recres, reshor, resvrt, resrad
    hmp=ref-elevation
    if (hmp < 1.0e-8_real64) hmp=0.0_real64
    delh=hmp-hma
    if (hmp < 1.0e-8_real64 .and. delh > 0.0_real64) delh=0.0_real64
    if (abs(delh) < 1.0e-8_real64) delh=0.0_real64
    if (hma < 0.0_real64) delh=0.0_real64
    flux=0.0_real64
    if (delh > 0.0_real64) then
      flow_branch=1
      recres=darcy
      if (ic == sat_comp) recres=sat_fraction*recres
      flux=-fr_reduce*recres*delh*delta_t
    else if (delh < 0.0_real64) then
      if (hmp > 0.0_real64) then
        flow_branch=2
        recres=darcy
        if (ic == top_comp) recres=recres*(water_level-(elevation-0.5_real64*thickness))/thickness
        flux=-fr_reduce*recres*delh*delta_t
      else if (switch == 1) then
        flow_branch=3
        reshor=dia**2/(8.0_real64*thickness*conductivity)
        resvrt=thickness/conductivity
        resrad=dia*log(10.0_real64)/(pi*conductivity)
        recres=pore/(reshor+resvrt+resrad)
        if (ic == top_comp) recres=recres*(water_level-(elevation-0.5_real64*thickness))/thickness
        flux=-fr_reduce*recres*delh*delta_t
      else
        flow_branch=4
        recres=shape*16.0_real64/dia**2*conductivity*thickness
        if (ic == top_comp) recres=recres*(water_level-(elevation-0.5_real64*thickness))/thickness
        flux=-fr_reduce*recres*delh*delta_t
      end if
    else
      flow_branch=1
    end if
  end subroutine source_exchange

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(A,I0)') 'PPA_WU05A3_SATFLOW_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_satflow_exchange_source_oracle

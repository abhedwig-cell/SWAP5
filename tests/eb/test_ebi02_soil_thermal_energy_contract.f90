program test_ebi02_soil_thermal_energy_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: SOIL_TEMP_OK, soil_temperature_numerical_config_t, &
       soil_temperature_forcing_t, soil_temperature_state_t, soil_temperature_workspace_t, &
       soil_temperature_result_t, soil_temperature_diagnostics_t, initialize_soil_temperature_state
  use mod_restricted_soil_temperature, only: soil_temperature_parameters_t, initialize_soil_temperature_parameters, &
       trial_restricted_soil_temperature
  use mod_soil_thermal_energy_contract
  implicit none

  integer, parameter :: n = 3
  real(real64), parameter :: dz(n) = [4.0_real64, 8.0_real64, 16.0_real64]
  real(real64), parameter :: dist(n) = [2.0_real64, 6.0_real64, 12.0_real64]
  real(real64), parameter :: theta_sat(n) = [0.45_real64, 0.47_real64, 0.50_real64]
  real(real64), parameter :: fq(n) = [0.45_real64, 0.30_real64, 0.18_real64]
  real(real64), parameter :: fc(n) = [0.10_real64, 0.18_real64, 0.24_real64]
  real(real64), parameter :: fo(n) = [0.03_real64, 0.05_real64, 0.08_real64]

  type(soil_temperature_parameters_t) :: parameters
  type(soil_temperature_numerical_config_t) :: numerical
  integer :: status

  call initialize_soil_temperature_parameters(dz, dist, theta_sat, fq, fc, fo, parameters, status)
  call require(status == SOIL_TEMP_OK .and. parameters%ready(), 'parameter initialization')
  numerical%energy_abs_tolerance_j_cm2 = 1.0e-9_real64

  call test_changing_water_content(parameters, numerical)
  call test_constant_water_content_does_not_imply_advection_coverage(parameters, numerical)
  call test_fail_closed_scope_and_consistency(parameters, numerical)

  print '(a)', 'EBI02_SOIL_THERMAL_ENERGY_CONTRACT_TEST PASS'

contains

  subroutine test_changing_water_content(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t) :: h0, h1
    type(soil_temperature_state_t) :: committed, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    type(soil_thermal_energy_interval_t) :: energy
    integer :: s
    real(real64), parameter :: t0 = 12.25_real64, t1 = 12.75_real64

    call make_hydraulic_view([0.12_real64, 0.20_real64, 0.28_real64], h0)
    call make_hydraulic_view([0.18_real64, 0.17_real64, 0.31_real64], h1)
    call initialize_soil_temperature_state([8.0_real64, 10.0_real64, 12.0_real64], committed, s)
    call require(s == SOIL_TEMP_OK, 'changing-theta state init')
    forcing%prescribed_surface_temperature_c = 19.0_real64

    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, committed, t0, t1, workspace, trial, result, diagnostics)
    call require(result%status == SOIL_TEMP_OK .and. result%produced, 'changing-theta restricted trial')
    call require(diagnostics%energy_accounting_complete, 'legacy restricted energy flag preserved')

    call build_restricted_soil_thermal_energy_interval(t0, t1, result, diagnostics, energy, s)
    call require(s == SOIL_THERMAL_ENERGY_OK .and. energy%ready(), 'changing-theta energy view')
    call require(energy%restricted_sensible_conduction_complete(), 'restricted sensible coverage complete')
    call require(.not. energy%full_physical_energy_complete(), 'changing-theta full energy must remain incomplete')
    call require(energy%legacy_restricted_energy_accounting_complete, 'legacy flag visible but scoped')
    call require(energy%coverage%sensible_storage_accounted, 'sensible storage coverage')
    call require(energy%coverage%top_conduction_accounted .and. energy%coverage%bottom_conduction_accounted, &
         'conductive boundary coverage')
    call require(.not. energy%coverage%liquid_advection_accounted, 'liquid advection explicitly uncovered')
    call require(.not. energy%coverage%vapor_transport_accounted, 'vapor transport explicitly uncovered')
    call require(.not. energy%coverage%phase_change_accounted, 'phase change explicitly uncovered')
    call require(.not. energy%coverage%surface_energy_accounted, 'surface energy explicitly uncovered')
    call require(close(energy%sensible_storage_change_j_m2, 1.0e4_real64*result%sensible_storage_change_j_cm2), &
         'storage unit conversion')
    call require(close(energy%top_conductive_energy_into_soil_j_m2, 1.0e4_real64*result%boundary_energy_into_soil_j_cm2), &
         'top conductive energy unit conversion')
    call require(bitwise_equal(energy%bottom_conductive_energy_into_soil_j_m2, 0.0_real64), 'zero bottom conductive energy')
    call require(close(energy%restricted_sensible_residual_j_m2, 1.0e4_real64*result%energy_residual_j_cm2), &
         'restricted residual unit conversion')
    print '(a)', 'EBI02_CHANGING_THETA_RESTRICTED_ONLY=PASS'
    print '(a)', 'EBI02_J_CM2_TO_J_M2_CONVERSION=PASS'
  end subroutine test_changing_water_content

  subroutine test_constant_water_content_does_not_imply_advection_coverage(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t) :: h0, h1
    type(soil_temperature_state_t) :: committed, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    type(soil_thermal_energy_interval_t) :: energy
    integer :: s

    call make_hydraulic_view([0.20_real64, 0.20_real64, 0.20_real64], h0)
    call make_hydraulic_view([0.20_real64, 0.20_real64, 0.20_real64], h1)
    call initialize_soil_temperature_state([11.0_real64, 10.0_real64, 9.0_real64], committed, s)
    forcing%prescribed_surface_temperature_c = 15.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, committed, 20.0_real64, 20.25_real64, &
         workspace, trial, result, diagnostics)
    call require(result%status == SOIL_TEMP_OK, 'constant-theta restricted trial')
    call build_restricted_soil_thermal_energy_interval(20.0_real64, 20.25_real64, result, diagnostics, energy, s)
    call require(s == SOIL_THERMAL_ENERGY_OK, 'constant-theta energy view')
    call require(energy%restricted_sensible_conduction_complete(), 'constant-theta restricted coverage')
    call require(.not. energy%coverage%liquid_advection_accounted, 'constant theta is not liquid-flux evidence')
    call require(.not. energy%full_physical_energy_complete(), 'constant theta is not full energy proof')
    print '(a)', 'EBI02_CONSTANT_THETA_DOES_NOT_IMPLY_ZERO_ADVECTIVE_ENERGY=PASS'
  end subroutine test_constant_water_content_does_not_imply_advection_coverage

  subroutine test_fail_closed_scope_and_consistency(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t) :: h0, h1
    type(soil_temperature_state_t) :: committed, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result, bad_result
    type(soil_temperature_diagnostics_t) :: diagnostics, bad_diagnostics
    type(soil_thermal_energy_interval_t) :: energy
    integer :: s

    call make_hydraulic_view([0.16_real64, 0.22_real64, 0.27_real64], h0)
    call make_hydraulic_view([0.16_real64, 0.22_real64, 0.27_real64], h1)
    call initialize_soil_temperature_state([10.0_real64, 10.0_real64, 10.0_real64], committed, s)
    forcing%prescribed_surface_temperature_c = 21.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, committed, 30.0_real64, 30.5_real64, &
         workspace, trial, result, diagnostics)
    call require(result%status == SOIL_TEMP_OK, 'fail-closed source trial')

    bad_result = result
    bad_result%boundary_energy_into_soil_j_cm2 = bad_result%boundary_energy_into_soil_j_cm2 + 1.0_real64
    call build_restricted_soil_thermal_energy_interval(30.0_real64, 30.5_real64, bad_result, diagnostics, energy, s)
    call require(s == SOIL_THERMAL_ENERGY_INCONSISTENT_ACCOUNTING .and. .not. energy%available, &
         'inconsistent accounting rejected')

    bad_diagnostics = diagnostics
    bad_diagnostics%snow_active = .true.
    call build_restricted_soil_thermal_energy_interval(30.0_real64, 30.5_real64, result, bad_diagnostics, energy, s)
    call require(s == SOIL_THERMAL_ENERGY_UNSUPPORTED_SCOPE .and. .not. energy%available, 'snow scope rejected')

    call build_restricted_soil_thermal_energy_interval(30.5_real64, 30.0_real64, result, diagnostics, energy, s)
    call require(s == SOIL_THERMAL_ENERGY_INVALID_INTERVAL .and. .not. energy%available, 'invalid interval rejected')
    print '(a)', 'EBI02_FAIL_CLOSED_UNSUPPORTED_OR_INCONSISTENT_SCOPE=PASS'
  end subroutine test_fail_closed_scope_and_consistency

  subroutine make_hydraulic_view(theta, view)
    real(real64), intent(in) :: theta(n)
    type(process_hydraulic_view_t), intent(out) :: view
    view%active_nodes = n
    allocate(view%pressure_head(n), view%water_content(n))
    view%pressure_head = -100.0_real64
    view%water_content = theta
    view%ponding_depth = 0.0_real64
    view%groundwater_level = -150.0_real64
  end subroutine make_hydraulic_view

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

  logical function close(a, b) result(equal)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    equal = abs(a-b) <= 128.0_real64*epsilon(1.0_real64)*scale
  end function close

  logical function bitwise_equal(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(kind=8) :: ai, bi
    ai = transfer(a, ai)
    bi = transfer(b, bi)
    equal = ai == bi
  end function bitwise_equal

end program test_ebi02_soil_thermal_energy_contract

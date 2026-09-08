program test_fpm02_snow_process
  use iso_fortran_env, only: real64, int64
  use mod_snow_process
  implicit none

  type(snow_parameters_t) :: p, p_before
  type(snow_state_t) :: committed, checkpoint, candidate, replay, committed_after_accept
  type(snow_state_t), allocatable :: inactive_state
  type(snow_forcing_t) :: f, f_before
  type(snow_flux_result_t) :: flux, replay_flux
  type(snow_diagnostics_t) :: diag, replay_diag

  ! Inactive SNOW is represented by no allocation and no process invocation.
  call assert_true('inactive_zero_state_allocation', .not. allocated(inactive_state))

  call setup_case_a(p, committed, f)
  p_before = p
  f_before = f
  checkpoint = committed
  call evaluate_snow_reference_call(p, committed, f, 100.25_real64, 101.25_real64, candidate, flux, diag)
  call assert_int('case_a_status', diag%status, SNOW_OK)
  call assert_case_a(candidate, flux, diag)
  call assert_state_exact('case_a_committed_not_mutated', committed, checkpoint)
  call assert_parameters_exact('immutable_parameters_not_mutated', p, p_before)
  call assert_forcing_exact('forcing_not_mutated', f, f_before)

  call evaluate_snow_reference_call(p, committed, f, 100.25_real64, 101.25_real64, replay, replay_flux, replay_diag)
  call assert_state_exact('replay_candidate', replay, candidate)
  call assert_flux_exact('replay_flux', replay_flux, flux)
  call assert_diagnostics_exact('replay_diagnostics', replay_diag, diag)

  ! A rejected trial is discarded. The committed checkpoint remains exact.
  call assert_state_exact('rollback_committed_exact', committed, checkpoint)

  ! Commit consists solely of publishing the accepted candidate. Continue from
  ! that state with a second one-call B1.10 interval.
  committed_after_accept = candidate
  call assert_state_exact('commit_accepts_candidate_only', committed_after_accept, candidate)
  call setup_continuation_forcing(f)
  f_before = f
  call evaluate_snow_reference_call(p, committed_after_accept, f, 101.25_real64, 102.25_real64, candidate, flux, diag)
  call assert_int('continuation_status', diag%status, SNOW_OK)
  call assert_case_d2(candidate, flux, diag)
  call assert_state_exact('continuation_committed_not_mutated', committed_after_accept, &
    state_from_bits(int(z'4007FADE0ED9F1CF', int64), int(z'3FC999999999999A', int64)))
  call assert_forcing_exact('continuation_forcing_not_mutated', f, f_before)

  call setup_case_b(p, committed, f)
  call evaluate_snow_reference_call(p, committed, f, 33.25_real64, 34.25_real64, candidate, flux, diag)
  call assert_case_b(candidate, flux, diag)

  call setup_case_c(p, committed, f)
  call evaluate_snow_reference_call(p, committed, f, 90.25_real64, 91.25_real64, candidate, flux, diag)
  call assert_case_c(candidate, flux, diag)

  call setup_case_a(p, committed, f)
  checkpoint = committed
  call evaluate_snow_reference_call(p, committed, f, 1.0_real64, 1.0_real64, candidate, flux, diag)
  call assert_int('invalid_interval_status', diag%status, SNOW_INVALID_INTERVAL)
  call assert_state_exact('invalid_interval_candidate_unchanged', candidate, checkpoint)
  call assert_true('invalid_interval_mass_unavailable', .not. diag%mass%available)

  call evaluate_snow_reference_call(p, committed, f, 1.0_real64, 1.5_real64, candidate, flux, diag)
  call assert_int('subdaily_fail_closed', diag%status, SNOW_UNADMITTED_DURATION)
  call assert_state_exact('subdaily_candidate_unchanged', candidate, checkpoint)
  call assert_true('subdaily_mass_unavailable', .not. diag%mass%available)

  call evaluate_snow_reference_call(p, committed, f, 1.0_real64, 3.0_real64, candidate, flux, diag)
  call assert_int('multiday_fail_closed', diag%status, SNOW_UNADMITTED_DURATION)
  call assert_state_exact('multiday_candidate_unchanged', candidate, checkpoint)
  call assert_true('multiday_mass_unavailable', .not. diag%mass%available)

  print '(A)', 'FPM02_SNOW_PROCESS_PASS'

contains

  subroutine setup_case_a(parameters, state, forcing)
    type(snow_parameters_t), intent(out) :: parameters
    type(snow_state_t), intent(out) :: state
    type(snow_forcing_t), intent(out) :: forcing
    parameters%suppress_sublimation = 0
    parameters%melt_coefficient = 0.15_real64
    state%snow_water_storage = 3.0_real64
    state%liquid_water_storage = 0.1_real64
    forcing%snowfall_input = 0.4_real64
    forcing%rain_on_snow_input = 0.1_real64
    forcing%soil_surface_temperature = 0.0_real64
    forcing%mean_air_temperature = 2.0_real64
    forcing%potential_soil_evaporation = 0.2_real64
    forcing%reduced_soil_evaporation = 0.15_real64
    forcing%ponding_evaporation = 0.25_real64
  end subroutine setup_case_a

  subroutine setup_case_b(parameters, state, forcing)
    type(snow_parameters_t), intent(out) :: parameters
    type(snow_state_t), intent(out) :: state
    type(snow_forcing_t), intent(out) :: forcing
    parameters%suppress_sublimation = 0
    parameters%melt_coefficient = 0.25_real64
    state%snow_water_storage = 0.0_real64
    state%liquid_water_storage = 0.0_real64
    forcing%snowfall_input = 0.5_real64
    forcing%rain_on_snow_input = 0.0_real64
    forcing%soil_surface_temperature = 0.6_real64
    forcing%mean_air_temperature = 3.0_real64
    forcing%potential_soil_evaporation = 0.2_real64
    forcing%reduced_soil_evaporation = 0.15_real64
    forcing%ponding_evaporation = 0.25_real64
  end subroutine setup_case_b

  subroutine setup_case_c(parameters, state, forcing)
    type(snow_parameters_t), intent(out) :: parameters
    type(snow_state_t), intent(out) :: state
    type(snow_forcing_t), intent(out) :: forcing
    parameters%suppress_sublimation = 0
    parameters%melt_coefficient = 0.1_real64
    state%snow_water_storage = 0.1_real64
    state%liquid_water_storage = 0.0_real64
    forcing%snowfall_input = 0.0_real64
    forcing%rain_on_snow_input = 0.0_real64
    forcing%soil_surface_temperature = 0.0_real64
    forcing%mean_air_temperature = 5.0_real64
    forcing%potential_soil_evaporation = 0.2_real64
    forcing%reduced_soil_evaporation = 0.15_real64
    forcing%ponding_evaporation = 0.25_real64
  end subroutine setup_case_c

  subroutine setup_continuation_forcing(forcing)
    type(snow_forcing_t), intent(out) :: forcing
    forcing%snowfall_input = 0.0_real64
    forcing%rain_on_snow_input = 0.05_real64
    forcing%soil_surface_temperature = -0.1_real64
    forcing%mean_air_temperature = -1.0_real64
    forcing%potential_soil_evaporation = 0.1_real64
    forcing%reduced_soil_evaporation = 0.08_real64
    forcing%ponding_evaporation = 0.12_real64
  end subroutine setup_continuation_forcing

  subroutine assert_case_a(state, result, diagnostics)
    type(snow_state_t), intent(in) :: state
    type(snow_flux_result_t), intent(in) :: result
    type(snow_diagnostics_t), intent(in) :: diagnostics
    call assert_real_bits('A_ssnow', state%snow_water_storage, int(z'4007FADE0ED9F1CF', int64))
    call assert_real_bits('A_slw', state%liquid_water_storage, int(z'3FC999999999999A', int64))
    call assert_real_bits('A_melt', result%melt, int(z'3FD35C42BC63A4B5', int64))
    call assert_real_bits('A_subl', result%sublimation, int(z'3FC999999999999A', int64))
    call assert_real_bits('A_peva', result%potential_soil_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('A_empreva', result%reduced_soil_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('A_epond', result%ponding_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('A_mass_residual', diagnostics%mass%unrounded_residual, int(z'BCB8000000000000', int64))
    call assert_mass_mapping('A_mass_mapping', diagnostics, .true.)
  end subroutine assert_case_a

  subroutine assert_case_b(state, result, diagnostics)
    type(snow_state_t), intent(in) :: state
    type(snow_flux_result_t), intent(in) :: result
    type(snow_diagnostics_t), intent(in) :: diagnostics
    call assert_real_bits('B_ssnow', state%snow_water_storage, int(z'0000000000000000', int64))
    call assert_real_bits('B_slw', state%liquid_water_storage, int(z'0000000000000000', int64))
    call assert_real_bits('B_melt', result%melt, int(z'3FE0000000000000', int64))
    call assert_real_bits('B_subl', result%sublimation, int(z'0000000000000000', int64))
    call assert_real_bits('B_peva', result%potential_soil_evaporation, int(z'3FC999999999999A', int64))
    call assert_real_bits('B_empreva', result%reduced_soil_evaporation, int(z'3FC3333333333333', int64))
    call assert_real_bits('B_epond', result%ponding_evaporation, int(z'3FD0000000000000', int64))
    call assert_real_bits('B_mass_residual', diagnostics%mass%unrounded_residual, int(z'0000000000000000', int64))
    call assert_mass_mapping('B_mass_mapping', diagnostics, .true.)
  end subroutine assert_case_b

  subroutine assert_case_c(state, result, diagnostics)
    type(snow_state_t), intent(in) :: state
    type(snow_flux_result_t), intent(in) :: result
    type(snow_diagnostics_t), intent(in) :: diagnostics
    call assert_real_bits('C_ssnow', state%snow_water_storage, int(z'0000000000000000', int64))
    call assert_real_bits('C_slw', state%liquid_water_storage, int(z'0000000000000000', int64))
    call assert_real_bits('C_melt', result%melt, int(z'3FB2B321890A130D', int64))
    call assert_real_bits('C_subl', result%sublimation, int(z'3F9B99E0423E1A3A', int64))
    call assert_real_bits('C_peva', result%potential_soil_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('C_empreva', result%reduced_soil_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('C_epond', result%ponding_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('C_mass_residual', diagnostics%mass%unrounded_residual, int(z'3C80000000000000', int64))
    call assert_true('C_deficit_clamped', diagnostics%snow_deficit_clamped)
    call assert_mass_mapping('C_mass_mapping', diagnostics, .true.)
  end subroutine assert_case_c

  subroutine assert_case_d2(state, result, diagnostics)
    type(snow_state_t), intent(in) :: state
    type(snow_flux_result_t), intent(in) :: result
    type(snow_diagnostics_t), intent(in) :: diagnostics
    call assert_real_bits('D2_ssnow', state%snow_water_storage, int(z'40073B0527716486', int64))
    call assert_real_bits('D2_slw', state%liquid_water_storage, int(z'3FCA68D7EFDD91E6', int64))
    call assert_real_bits('D2_melt', result%melt, int(z'3FA65CA04089B868', int64))
    call assert_real_bits('D2_subl', result%sublimation, int(z'3FB999999999999A', int64))
    call assert_real_bits('D2_peva', result%potential_soil_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('D2_empreva', result%reduced_soil_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('D2_epond', result%ponding_evaporation, int(z'0000000000000000', int64))
    call assert_real_bits('D2_mass_residual', diagnostics%mass%unrounded_residual, int(z'BCBF000000000000', int64))
    call assert_mass_mapping('D2_mass_mapping', diagnostics, .true.)
  end subroutine assert_case_d2

  subroutine assert_mass_mapping(name, diagnostics, expected_available)
    character(len=*), intent(in) :: name
    type(snow_diagnostics_t), intent(in) :: diagnostics
    logical, intent(in) :: expected_available
    if (diagnostics%mass%available .neqv. expected_available) call fail_test(trim(name)//': availability')
  end subroutine assert_mass_mapping

  function state_from_bits(ssnow_bits, slw_bits) result(state)
    integer(int64), intent(in) :: ssnow_bits, slw_bits
    type(snow_state_t) :: state
    state%snow_water_storage = transfer(ssnow_bits, state%snow_water_storage)
    state%liquid_water_storage = transfer(slw_bits, state%liquid_water_storage)
  end function state_from_bits

  subroutine assert_real_bits(name, actual, expected_bits)
    character(len=*), intent(in) :: name
    real(real64), intent(in) :: actual
    integer(int64), intent(in) :: expected_bits
    if (transfer(actual, 0_int64) /= expected_bits) then
      write(*,'(A,1X,A,1X,Z16.16,1X,Z16.16)') 'BIT_MISMATCH', trim(name), &
        transfer(actual, 0_int64), expected_bits
      call fail_test(trim(name))
    end if
  end subroutine assert_real_bits

  subroutine assert_state_exact(name, x, y)
    character(len=*), intent(in) :: name
    type(snow_state_t), intent(in) :: x, y
    call assert_real_bits(trim(name)//'_ssnow', x%snow_water_storage, transfer(y%snow_water_storage, 0_int64))
    call assert_real_bits(trim(name)//'_slw', x%liquid_water_storage, transfer(y%liquid_water_storage, 0_int64))
  end subroutine assert_state_exact

  subroutine assert_parameters_exact(name, x, y)
    character(len=*), intent(in) :: name
    type(snow_parameters_t), intent(in) :: x, y
    if (x%suppress_sublimation /= y%suppress_sublimation) call fail_test(trim(name)//': suppress_sublimation')
    call assert_real_bits(trim(name)//'_melt_coefficient', x%melt_coefficient, transfer(y%melt_coefficient, 0_int64))
  end subroutine assert_parameters_exact

  subroutine assert_forcing_exact(name, x, y)
    character(len=*), intent(in) :: name
    type(snow_forcing_t), intent(in) :: x, y
    call assert_real_bits(trim(name)//'_snowfall', x%snowfall_input, transfer(y%snowfall_input, 0_int64))
    call assert_real_bits(trim(name)//'_rain', x%rain_on_snow_input, transfer(y%rain_on_snow_input, 0_int64))
    call assert_real_bits(trim(name)//'_tsoil', x%soil_surface_temperature, transfer(y%soil_surface_temperature, 0_int64))
    call assert_real_bits(trim(name)//'_tav', x%mean_air_temperature, transfer(y%mean_air_temperature, 0_int64))
    call assert_real_bits(trim(name)//'_peva', x%potential_soil_evaporation, transfer(y%potential_soil_evaporation, 0_int64))
    call assert_real_bits(trim(name)//'_empreva', x%reduced_soil_evaporation, transfer(y%reduced_soil_evaporation, 0_int64))
    call assert_real_bits(trim(name)//'_epond', x%ponding_evaporation, transfer(y%ponding_evaporation, 0_int64))
  end subroutine assert_forcing_exact

  subroutine assert_flux_exact(name, x, y)
    character(len=*), intent(in) :: name
    type(snow_flux_result_t), intent(in) :: x, y
    call assert_real_bits(trim(name)//'_melt', x%melt, transfer(y%melt, 0_int64))
    call assert_real_bits(trim(name)//'_subl', x%sublimation, transfer(y%sublimation, 0_int64))
    call assert_real_bits(trim(name)//'_peva', x%potential_soil_evaporation, transfer(y%potential_soil_evaporation, 0_int64))
    call assert_real_bits(trim(name)//'_empreva', x%reduced_soil_evaporation, transfer(y%reduced_soil_evaporation, 0_int64))
    call assert_real_bits(trim(name)//'_epond', x%ponding_evaporation, transfer(y%ponding_evaporation, 0_int64))
  end subroutine assert_flux_exact

  subroutine assert_diagnostics_exact(name, x, y)
    character(len=*), intent(in) :: name
    type(snow_diagnostics_t), intent(in) :: x, y
    if (x%status /= y%status) call fail_test(trim(name)//': status')
    if (x%snow_deficit_clamped .neqv. y%snow_deficit_clamped) call fail_test(trim(name)//': clamp')
    if (x%mass%available .neqv. y%mass%available) call fail_test(trim(name)//': mass availability')
    call assert_real_bits(trim(name)//'_mass_residual', x%mass%unrounded_residual, &
      transfer(y%mass%unrounded_residual, 0_int64))
  end subroutine assert_diagnostics_exact

  subroutine assert_int(name, actual, expected)
    character(len=*), intent(in) :: name
    integer, intent(in) :: actual, expected
    if (actual /= expected) call fail_test(trim(name))
  end subroutine assert_int

  subroutine assert_true(name, value)
    character(len=*), intent(in) :: name
    logical, intent(in) :: value
    if (.not. value) call fail_test(trim(name))
  end subroutine assert_true

  subroutine fail_test(name)
    character(len=*), intent(in) :: name
    write(*,'(A,1X,A)') 'FAIL', trim(name)
    error stop 1
  end subroutine fail_test

end program test_fpm02_snow_process

program test_fvq16_snow_scientific
  use iso_fortran_env, only: real64, int64
  use mod_snow_process
  use MOD_snow, only: legacy_snow => snow, legacy_swsublim => swsublim, &
       legacy_gsnow => gsnow, legacy_melt => melt, legacy_slw => slw, &
       legacy_snowcoef => snowcoef, legacy_snrai => snrai, &
       legacy_ssnow => ssnow, legacy_subl => subl
  implicit none

  type(snow_parameters_t) :: p
  type(snow_state_t) :: committed, accepted
  type(snow_forcing_t) :: forcing

  call setup_normal(p, committed, forcing)
  call compare_reference_call('normal', p, committed, forcing, 100.25_real64, 101.25_real64, .false., accepted)

  call setup_warm_fresh(p, committed, forcing)
  call compare_reference_call('warm_fresh', p, committed, forcing, 33.25_real64, 34.25_real64, .false., accepted)

  call setup_deficit(p, committed, forcing)
  call compare_reference_call('deficit_clamp', p, committed, forcing, 90.25_real64, 91.25_real64, .true., accepted)

  call setup_sublimation_suppressed(p, committed, forcing)
  call compare_reference_call('sublimation_suppressed', p, committed, forcing, 200.125_real64, 201.125_real64, .false., accepted)

  call test_continuation()
  call test_fail_closed_time_domain()

  print '(A)', 'FVQ16_SNOW_SCIENTIFIC_PASS'

contains

  subroutine compare_reference_call(label, parameters, state, input_forcing, t0, t1, expect_clamp, candidate_out)
    character(len=*), intent(in) :: label
    type(snow_parameters_t), intent(in) :: parameters
    type(snow_state_t), intent(in) :: state
    type(snow_forcing_t), intent(in) :: input_forcing
    real(real64), intent(in) :: t0, t1
    logical, intent(in) :: expect_clamp
    type(snow_state_t), intent(out) :: candidate_out

    type(snow_parameters_t) :: parameters_before
    type(snow_state_t) :: state_before, candidate, replay
    type(snow_forcing_t) :: forcing_before
    type(snow_flux_result_t) :: fluxes, replay_fluxes
    type(snow_diagnostics_t) :: diagnostics, replay_diagnostics
    real(real64) :: legacy_epond, legacy_peva, legacy_empreva
    real(real64) :: expected_change, expected_residual

    parameters_before = parameters
    state_before = state
    forcing_before = input_forcing

    legacy_swsublim = parameters%suppress_sublimation
    legacy_snowcoef = parameters%melt_coefficient
    legacy_ssnow = state%snow_water_storage
    legacy_slw = state%liquid_water_storage
    legacy_gsnow = input_forcing%snowfall_input
    legacy_snrai = input_forcing%rain_on_snow_input
    legacy_epond = input_forcing%ponding_evaporation
    legacy_peva = input_forcing%potential_soil_evaporation
    legacy_empreva = input_forcing%reduced_soil_evaporation

    call legacy_snow(2, input_forcing%soil_surface_temperature, input_forcing%mean_air_temperature, &
                     legacy_epond, legacy_peva, legacy_empreva)

    call evaluate_snow_reference_call(parameters, state, input_forcing, t0, t1, candidate, fluxes, diagnostics)

    call assert_int(label // ':status', diagnostics%status, SNOW_OK)
    call assert_real_bits(label // ':ssnow', candidate%snow_water_storage, legacy_ssnow)
    call assert_real_bits(label // ':slw', candidate%liquid_water_storage, legacy_slw)
    call assert_real_bits(label // ':melt', fluxes%melt, legacy_melt)
    call assert_real_bits(label // ':sublimation', fluxes%sublimation, legacy_subl)
    call assert_real_bits(label // ':peva', fluxes%potential_soil_evaporation, legacy_peva)
    call assert_real_bits(label // ':empreva', fluxes%reduced_soil_evaporation, legacy_empreva)
    call assert_real_bits(label // ':epond', fluxes%ponding_evaporation, legacy_epond)
    call assert_logical(label // ':clamp', diagnostics%snow_deficit_clamped, expect_clamp)

    call assert_parameters_exact(label // ':parameters_immutable', parameters, parameters_before)
    call assert_state_exact(label // ':committed_immutable', state, state_before)
    call assert_forcing_exact(label // ':forcing_immutable', input_forcing, forcing_before)

    call assert_logical(label // ':mass_available', diagnostics%mass%available, .true.)
    expected_change = legacy_ssnow - state%snow_water_storage
    expected_residual = expected_change - &
      (input_forcing%snowfall_input + input_forcing%rain_on_snow_input - legacy_subl - legacy_melt)
    call assert_real_bits(label // ':mass_storage_start', diagnostics%mass%storage_start, state%snow_water_storage)
    call assert_real_bits(label // ':mass_storage_end', diagnostics%mass%storage_end, legacy_ssnow)
    call assert_real_bits(label // ':mass_storage_change', diagnostics%mass%storage_change, expected_change)
    call assert_real_bits(label // ':mass_snowfall_in', diagnostics%mass%snowfall_external_in, input_forcing%snowfall_input)
    call assert_real_bits(label // ':mass_rain_in', diagnostics%mass%rain_external_in, input_forcing%rain_on_snow_input)
    call assert_real_bits(label // ':mass_sublimation_out', diagnostics%mass%sublimation_external_out, legacy_subl)
    call assert_real_bits(label // ':mass_melt_internal', diagnostics%mass%melt_internal_transfer, legacy_melt)
    call assert_real_bits(label // ':mass_residual', diagnostics%mass%unrounded_residual, expected_residual)

    call evaluate_snow_reference_call(parameters, state, input_forcing, t0, t1, replay, replay_fluxes, replay_diagnostics)
    call assert_state_exact(label // ':replay_state', replay, candidate)
    call assert_flux_exact(label // ':replay_flux', replay_fluxes, fluxes)
    call assert_diagnostics_exact(label // ':replay_diagnostics', replay_diagnostics, diagnostics)

    candidate_out = candidate
  end subroutine compare_reference_call

  subroutine test_continuation()
    type(snow_parameters_t) :: parameters
    type(snow_state_t) :: state, first_candidate, second_candidate
    type(snow_forcing_t) :: first_forcing, second_forcing

    call setup_normal(parameters, state, first_forcing)
    call compare_reference_call('continuation_first', parameters, state, first_forcing, &
                                410.375_real64, 411.375_real64, .false., first_candidate)

    second_forcing = snow_forcing_t()
    second_forcing%snowfall_input = 0.1_real64
    second_forcing%rain_on_snow_input = 0.05_real64
    second_forcing%soil_surface_temperature = -0.25_real64
    second_forcing%mean_air_temperature = -1.0_real64
    second_forcing%potential_soil_evaporation = 0.08_real64
    second_forcing%reduced_soil_evaporation = 0.06_real64
    second_forcing%ponding_evaporation = 0.04_real64

    call compare_reference_call('continuation_second', parameters, first_candidate, second_forcing, &
                                411.375_real64, 412.375_real64, .false., second_candidate)
    call assert_true('continuation_state_changed', .not. same_state_bits(first_candidate, second_candidate))
  end subroutine test_continuation

  subroutine test_fail_closed_time_domain()
    type(snow_parameters_t) :: parameters
    type(snow_state_t) :: state, candidate
    type(snow_forcing_t) :: input_forcing
    type(snow_flux_result_t) :: fluxes
    type(snow_diagnostics_t) :: diagnostics

    call setup_normal(parameters, state, input_forcing)

    call evaluate_snow_reference_call(parameters, state, input_forcing, 1.0_real64, 1.0_real64, candidate, fluxes, diagnostics)
    call assert_int('zero_interval_status', diagnostics%status, SNOW_INVALID_INTERVAL)
    call assert_state_exact('zero_interval_state', candidate, state)
    call assert_logical('zero_interval_mass', diagnostics%mass%available, .false.)

    call evaluate_snow_reference_call(parameters, state, input_forcing, 2.0_real64, 1.0_real64, candidate, fluxes, diagnostics)
    call assert_int('negative_interval_status', diagnostics%status, SNOW_INVALID_INTERVAL)
    call assert_state_exact('negative_interval_state', candidate, state)
    call assert_logical('negative_interval_mass', diagnostics%mass%available, .false.)

    call evaluate_snow_reference_call(parameters, state, input_forcing, 10.25_real64, 10.75_real64, candidate, fluxes, diagnostics)
    call assert_int('subdaily_status', diagnostics%status, SNOW_UNADMITTED_DURATION)
    call assert_state_exact('subdaily_state', candidate, state)
    call assert_logical('subdaily_mass', diagnostics%mass%available, .false.)

    call evaluate_snow_reference_call(parameters, state, input_forcing, 10.25_real64, 12.25_real64, candidate, fluxes, diagnostics)
    call assert_int('multiday_status', diagnostics%status, SNOW_UNADMITTED_DURATION)
    call assert_state_exact('multiday_state', candidate, state)
    call assert_logical('multiday_mass', diagnostics%mass%available, .false.)
  end subroutine test_fail_closed_time_domain

  subroutine setup_normal(parameters, state, input_forcing)
    type(snow_parameters_t), intent(out) :: parameters
    type(snow_state_t), intent(out) :: state
    type(snow_forcing_t), intent(out) :: input_forcing
    parameters%suppress_sublimation = 0
    parameters%melt_coefficient = 0.15_real64
    state%snow_water_storage = 3.0_real64
    state%liquid_water_storage = 0.1_real64
    input_forcing = snow_forcing_t()
    input_forcing%snowfall_input = 0.4_real64
    input_forcing%rain_on_snow_input = 0.1_real64
    input_forcing%soil_surface_temperature = 0.0_real64
    input_forcing%mean_air_temperature = 2.0_real64
    input_forcing%potential_soil_evaporation = 0.2_real64
    input_forcing%reduced_soil_evaporation = 0.15_real64
    input_forcing%ponding_evaporation = 0.25_real64
  end subroutine setup_normal

  subroutine setup_warm_fresh(parameters, state, input_forcing)
    type(snow_parameters_t), intent(out) :: parameters
    type(snow_state_t), intent(out) :: state
    type(snow_forcing_t), intent(out) :: input_forcing
    parameters%suppress_sublimation = 0
    parameters%melt_coefficient = 0.25_real64
    state = snow_state_t()
    input_forcing = snow_forcing_t()
    input_forcing%snowfall_input = 0.5_real64
    input_forcing%soil_surface_temperature = 0.6_real64
    input_forcing%mean_air_temperature = 3.0_real64
    input_forcing%potential_soil_evaporation = 0.2_real64
    input_forcing%reduced_soil_evaporation = 0.15_real64
    input_forcing%ponding_evaporation = 0.25_real64
  end subroutine setup_warm_fresh

  subroutine setup_deficit(parameters, state, input_forcing)
    type(snow_parameters_t), intent(out) :: parameters
    type(snow_state_t), intent(out) :: state
    type(snow_forcing_t), intent(out) :: input_forcing
    parameters%suppress_sublimation = 0
    parameters%melt_coefficient = 0.1_real64
    state%snow_water_storage = 0.1_real64
    state%liquid_water_storage = 0.0_real64
    input_forcing = snow_forcing_t()
    input_forcing%soil_surface_temperature = 0.0_real64
    input_forcing%mean_air_temperature = 5.0_real64
    input_forcing%potential_soil_evaporation = 0.2_real64
    input_forcing%reduced_soil_evaporation = 0.15_real64
    input_forcing%ponding_evaporation = 0.25_real64
  end subroutine setup_deficit

  subroutine setup_sublimation_suppressed(parameters, state, input_forcing)
    type(snow_parameters_t), intent(out) :: parameters
    type(snow_state_t), intent(out) :: state
    type(snow_forcing_t), intent(out) :: input_forcing
    parameters%suppress_sublimation = 1
    parameters%melt_coefficient = 0.12_real64
    state%snow_water_storage = 1.5_real64
    state%liquid_water_storage = 0.05_real64
    input_forcing = snow_forcing_t()
    input_forcing%snowfall_input = 0.2_real64
    input_forcing%rain_on_snow_input = 0.15_real64
    input_forcing%soil_surface_temperature = 0.0_real64
    input_forcing%mean_air_temperature = 1.5_real64
    input_forcing%potential_soil_evaporation = 0.3_real64
    input_forcing%reduced_soil_evaporation = 0.2_real64
    input_forcing%ponding_evaporation = 0.1_real64
  end subroutine setup_sublimation_suppressed

  subroutine assert_parameters_exact(label, actual, expected)
    character(len=*), intent(in) :: label
    type(snow_parameters_t), intent(in) :: actual, expected
    call assert_int(label // ':suppress', actual%suppress_sublimation, expected%suppress_sublimation)
    call assert_real_bits(label // ':coef', actual%melt_coefficient, expected%melt_coefficient)
  end subroutine assert_parameters_exact

  subroutine assert_state_exact(label, actual, expected)
    character(len=*), intent(in) :: label
    type(snow_state_t), intent(in) :: actual, expected
    call assert_real_bits(label // ':ssnow', actual%snow_water_storage, expected%snow_water_storage)
    call assert_real_bits(label // ':slw', actual%liquid_water_storage, expected%liquid_water_storage)
  end subroutine assert_state_exact

  subroutine assert_forcing_exact(label, actual, expected)
    character(len=*), intent(in) :: label
    type(snow_forcing_t), intent(in) :: actual, expected
    call assert_real_bits(label // ':snow', actual%snowfall_input, expected%snowfall_input)
    call assert_real_bits(label // ':rain', actual%rain_on_snow_input, expected%rain_on_snow_input)
    call assert_real_bits(label // ':tsoil', actual%soil_surface_temperature, expected%soil_surface_temperature)
    call assert_real_bits(label // ':tair', actual%mean_air_temperature, expected%mean_air_temperature)
    call assert_real_bits(label // ':peva', actual%potential_soil_evaporation, expected%potential_soil_evaporation)
    call assert_real_bits(label // ':empreva', actual%reduced_soil_evaporation, expected%reduced_soil_evaporation)
    call assert_real_bits(label // ':epond', actual%ponding_evaporation, expected%ponding_evaporation)
  end subroutine assert_forcing_exact

  subroutine assert_flux_exact(label, actual, expected)
    character(len=*), intent(in) :: label
    type(snow_flux_result_t), intent(in) :: actual, expected
    call assert_real_bits(label // ':melt', actual%melt, expected%melt)
    call assert_real_bits(label // ':subl', actual%sublimation, expected%sublimation)
    call assert_real_bits(label // ':peva', actual%potential_soil_evaporation, expected%potential_soil_evaporation)
    call assert_real_bits(label // ':empreva', actual%reduced_soil_evaporation, expected%reduced_soil_evaporation)
    call assert_real_bits(label // ':epond', actual%ponding_evaporation, expected%ponding_evaporation)
  end subroutine assert_flux_exact

  subroutine assert_diagnostics_exact(label, actual, expected)
    character(len=*), intent(in) :: label
    type(snow_diagnostics_t), intent(in) :: actual, expected
    call assert_int(label // ':status', actual%status, expected%status)
    call assert_logical(label // ':clamp', actual%snow_deficit_clamped, expected%snow_deficit_clamped)
    call assert_logical(label // ':available', actual%mass%available, expected%mass%available)
    call assert_real_bits(label // ':storage_start', actual%mass%storage_start, expected%mass%storage_start)
    call assert_real_bits(label // ':storage_end', actual%mass%storage_end, expected%mass%storage_end)
    call assert_real_bits(label // ':storage_change', actual%mass%storage_change, expected%mass%storage_change)
    call assert_real_bits(label // ':snow_in', actual%mass%snowfall_external_in, expected%mass%snowfall_external_in)
    call assert_real_bits(label // ':rain_in', actual%mass%rain_external_in, expected%mass%rain_external_in)
    call assert_real_bits(label // ':subl_out', actual%mass%sublimation_external_out, expected%mass%sublimation_external_out)
    call assert_real_bits(label // ':melt_internal', actual%mass%melt_internal_transfer, expected%mass%melt_internal_transfer)
    call assert_real_bits(label // ':residual', actual%mass%unrounded_residual, expected%mass%unrounded_residual)
  end subroutine assert_diagnostics_exact

  logical function same_state_bits(a, b) result(equal)
    type(snow_state_t), intent(in) :: a, b
    equal = transfer(a%snow_water_storage, 0_int64) == transfer(b%snow_water_storage, 0_int64) .and. &
            transfer(a%liquid_water_storage, 0_int64) == transfer(b%liquid_water_storage, 0_int64)
  end function same_state_bits

  subroutine assert_real_bits(label, actual, expected)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: actual, expected
    if (transfer(actual, 0_int64) /= transfer(expected, 0_int64)) then
      write (*,'(A,1X,Z16.16,1X,Z16.16)') trim(label), transfer(actual, 0_int64), transfer(expected, 0_int64)
      error stop 'bitwise real mismatch'
    end if
  end subroutine assert_real_bits

  subroutine assert_int(label, actual, expected)
    character(len=*), intent(in) :: label
    integer, intent(in) :: actual, expected
    if (actual /= expected) then
      write (*,'(A,1X,I0,1X,I0)') trim(label), actual, expected
      error stop 'integer mismatch'
    end if
  end subroutine assert_int

  subroutine assert_logical(label, actual, expected)
    character(len=*), intent(in) :: label
    logical, intent(in) :: actual, expected
    if (actual .neqv. expected) then
      write (*,'(A,1X,L1,1X,L1)') trim(label), actual, expected
      error stop 'logical mismatch'
    end if
  end subroutine assert_logical

  subroutine assert_true(label, condition)
    character(len=*), intent(in) :: label
    logical, intent(in) :: condition
    if (.not. condition) then
      write (*,'(A)') trim(label)
      error stop 'assertion failed'
    end if
  end subroutine assert_true

end program test_fvq16_snow_scientific

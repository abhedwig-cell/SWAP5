module mod_snow_process
  use iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: SNOW_OK = 0
  integer, parameter, public :: SNOW_INVALID_INTERVAL = 1
  integer, parameter, public :: SNOW_UNADMITTED_DURATION = 2

  type, public :: snow_parameters_t
    integer :: suppress_sublimation = 0
    real(real64) :: melt_coefficient = 0.0_real64
  end type

  type, public :: snow_state_t
    real(real64) :: snow_water_storage = 0.0_real64
    real(real64) :: liquid_water_storage = 0.0_real64
  end type

  type, public :: snow_forcing_t
    real(real64) :: snowfall_input = 0.0_real64
    real(real64) :: rain_on_snow_input = 0.0_real64
    real(real64) :: soil_surface_temperature = 0.0_real64
    real(real64) :: mean_air_temperature = 0.0_real64
    real(real64) :: potential_soil_evaporation = 0.0_real64
    real(real64) :: reduced_soil_evaporation = 0.0_real64
    real(real64) :: ponding_evaporation = 0.0_real64
  end type

  type, public :: snow_result_t
    type(snow_state_t) :: candidate_state
    real(real64) :: melt = 0.0_real64
    real(real64) :: sublimation = 0.0_real64
    real(real64) :: potential_soil_evaporation = 0.0_real64
    real(real64) :: reduced_soil_evaporation = 0.0_real64
    real(real64) :: ponding_evaporation = 0.0_real64
    real(real64) :: unrounded_mass_residual = 0.0_real64
    logical :: snow_deficit_clamped = .false.
    integer :: status = SNOW_OK
  end type

  public :: evaluate_snow_reference_call

contains

  pure subroutine evaluate_snow_reference_call(parameters, committed_state, forcing, t0, t1, result)
    type(snow_parameters_t), intent(in) :: parameters
    type(snow_state_t), intent(in) :: committed_state
    type(snow_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    type(snow_result_t), intent(out) :: result
    real(real64) :: smelt, smeltr, snow_deficit, snow_loss, maximum_liquid_storage, liquid_drainage
    real(real64), parameter :: water_heat_capacity = 4180.0_real64
    real(real64), parameter :: latent_heat_melting = 333580.0_real64
    real(real64), parameter :: snow_temperature = 0.0_real64

    result%candidate_state = committed_state
    result%potential_soil_evaporation = forcing%potential_soil_evaporation
    result%reduced_soil_evaporation = forcing%reduced_soil_evaporation
    result%ponding_evaporation = forcing%ponding_evaporation
    if (t1 <= t0) then
      result%status = SNOW_INVALID_INTERVAL
      return
    end if
    ! B1.10 calls this process once per legacy day and contains no dt factor.
    ! Until independent evidence exists, other durations fail closed.
    if (t1 - t0 /= 1.0_real64) then
      result%status = SNOW_UNADMITTED_DURATION
      return
    end if

    result%sublimation = 0.0_real64
    if (parameters%suppress_sublimation == 0) then
      if (result%candidate_state%snow_water_storage > 0.0_real64) then
        result%sublimation = result%potential_soil_evaporation
        result%ponding_evaporation = 0.0_real64
        result%reduced_soil_evaporation = 0.0_real64
        result%potential_soil_evaporation = 0.0_real64
      end if
    end if

    if (forcing%soil_surface_temperature > 0.5_real64 .and. &
        result%candidate_state%snow_water_storage < 1.0e-6_real64 .and. forcing%snowfall_input > 0.0_real64) then
      result%candidate_state%snow_water_storage = 0.0_real64
      result%melt = forcing%snowfall_input
      result%sublimation = 0.0_real64
    else
      smelt = parameters%melt_coefficient * (forcing%mean_air_temperature - snow_temperature)
      if (forcing%rain_on_snow_input > 0.0_real64) then
        smeltr = forcing%rain_on_snow_input * water_heat_capacity * &
          (forcing%mean_air_temperature - snow_temperature) / latent_heat_melting
      else
        smeltr = 0.0_real64
      end if
      result%melt = max(0.0_real64, smelt + smeltr)
      result%candidate_state%snow_water_storage = result%candidate_state%snow_water_storage + &
        forcing%snowfall_input - result%sublimation - result%melt - result%candidate_state%liquid_water_storage
      result%candidate_state%liquid_water_storage = result%candidate_state%liquid_water_storage + forcing%rain_on_snow_input
      maximum_liquid_storage = 0.07_real64 * (result%candidate_state%liquid_water_storage + &
        result%candidate_state%snow_water_storage)
      liquid_drainage = max(0.0_real64, result%candidate_state%liquid_water_storage - maximum_liquid_storage)
      result%candidate_state%liquid_water_storage = result%candidate_state%liquid_water_storage - liquid_drainage
      result%candidate_state%snow_water_storage = result%candidate_state%snow_water_storage + &
        result%candidate_state%liquid_water_storage
      result%melt = result%melt + liquid_drainage
      if (result%candidate_state%snow_water_storage < 0.0_real64) then
        snow_deficit = -result%candidate_state%snow_water_storage
        snow_loss = result%melt + result%sublimation
        result%melt = (1.0_real64 - snow_deficit / snow_loss) * result%melt
        result%sublimation = (1.0_real64 - snow_deficit / snow_loss) * result%sublimation
        result%candidate_state%snow_water_storage = 0.0_real64
        result%candidate_state%liquid_water_storage = 0.0_real64
        result%snow_deficit_clamped = .true.
      end if
    end if
    result%unrounded_mass_residual = result%candidate_state%snow_water_storage - &
      committed_state%snow_water_storage - forcing%snowfall_input - forcing%rain_on_snow_input + &
      result%sublimation + result%melt
  end subroutine
end module mod_snow_process

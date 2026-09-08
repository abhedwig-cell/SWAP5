module mod_snow_process
  use iso_fortran_env, only: real64, int64
  implicit none
  private

  integer, parameter, public :: SNOW_OK = 0
  integer, parameter, public :: SNOW_INVALID_INTERVAL = 1
  integer, parameter, public :: SNOW_UNADMITTED_DURATION = 2

  type, public :: snow_parameters_t
    integer :: suppress_sublimation = 0
    real(real64) :: melt_coefficient = 0.0_real64
  end type snow_parameters_t

  type, public :: snow_state_t
    real(real64) :: snow_water_storage = 0.0_real64
    real(real64) :: liquid_water_storage = 0.0_real64
  end type snow_state_t

  type, public :: snow_forcing_t
    real(real64) :: snowfall_input = 0.0_real64
    real(real64) :: rain_on_snow_input = 0.0_real64
    real(real64) :: soil_surface_temperature = 0.0_real64
    real(real64) :: mean_air_temperature = 0.0_real64
    real(real64) :: potential_soil_evaporation = 0.0_real64
    real(real64) :: reduced_soil_evaporation = 0.0_real64
    real(real64) :: ponding_evaporation = 0.0_real64
  end type snow_forcing_t

  type, public :: snow_flux_result_t
    real(real64) :: melt = 0.0_real64
    real(real64) :: sublimation = 0.0_real64
    real(real64) :: potential_soil_evaporation = 0.0_real64
    real(real64) :: reduced_soil_evaporation = 0.0_real64
    real(real64) :: ponding_evaporation = 0.0_real64
  end type snow_flux_result_t

  ! Component-local mass terms only. F-KT remains authoritative for the
  ! complete interval balance and decides whether all component contributions
  ! required by the composed physical model are present.
  type, public :: snow_mass_contribution_t
    logical :: available = .false.
    real(real64) :: storage_start = 0.0_real64
    real(real64) :: storage_end = 0.0_real64
    real(real64) :: storage_change = 0.0_real64
    real(real64) :: snowfall_external_in = 0.0_real64
    real(real64) :: rain_external_in = 0.0_real64
    real(real64) :: sublimation_external_out = 0.0_real64
    real(real64) :: melt_internal_transfer = 0.0_real64
    real(real64) :: unrounded_residual = 0.0_real64
  end type snow_mass_contribution_t

  type, public :: snow_diagnostics_t
    type(snow_mass_contribution_t) :: mass
    logical :: snow_deficit_clamped = .false.
    integer :: status = SNOW_OK
  end type snow_diagnostics_t

  public :: evaluate_snow_reference_call

contains

  pure subroutine evaluate_snow_reference_call(parameters, committed_state, forcing, t0, t1, &
                                                candidate_state, fluxes, diagnostics)
    type(snow_parameters_t), intent(in) :: parameters
    type(snow_state_t), intent(in) :: committed_state
    type(snow_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    type(snow_state_t), intent(out) :: candidate_state
    type(snow_flux_result_t), intent(out) :: fluxes
    type(snow_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: smelt, smeltr, snow_deficit, snow_loss
    real(real64) :: maximum_liquid_storage, liquid_drainage
    real(real64), parameter :: water_heat_capacity = 4180.0_real64
    real(real64), parameter :: latent_heat_melting = 333580.0_real64
    real(real64), parameter :: snow_temperature = 0.0_real64

    candidate_state = committed_state
    fluxes = snow_flux_result_t()
    diagnostics = snow_diagnostics_t()
    fluxes%potential_soil_evaporation = forcing%potential_soil_evaporation
    fluxes%reduced_soil_evaporation = forcing%reduced_soil_evaporation
    fluxes%ponding_evaporation = forcing%ponding_evaporation

    if (t1 <= t0) then
      diagnostics%status = SNOW_INVALID_INTERVAL
      return
    end if

    ! B1.10 calls Snow(2) once per legacy day and contains no dt factor.
    ! The interface carries generic time, but durations other than one
    ! characterized legacy day remain outside F-PM02 admission.
    if (transfer(t1 - t0, 0_int64) /= transfer(1.0_real64, 0_int64)) then
      diagnostics%status = SNOW_UNADMITTED_DURATION
      return
    end if

    fluxes%sublimation = 0.0_real64
    if (parameters%suppress_sublimation == 0) then
      if (candidate_state%snow_water_storage > 0.0_real64) then
        fluxes%sublimation = fluxes%potential_soil_evaporation
        fluxes%ponding_evaporation = 0.0_real64
        fluxes%reduced_soil_evaporation = 0.0_real64
        fluxes%potential_soil_evaporation = 0.0_real64
      end if
    end if

    if (forcing%soil_surface_temperature > 0.5_real64 .and. &
        candidate_state%snow_water_storage < 1.0e-6_real64 .and. forcing%snowfall_input > 0.0_real64) then
      candidate_state%snow_water_storage = 0.0_real64
      fluxes%melt = forcing%snowfall_input
      fluxes%sublimation = 0.0_real64
    else
      smelt = parameters%melt_coefficient * (forcing%mean_air_temperature - snow_temperature)
      if (forcing%rain_on_snow_input > 0.0_real64) then
        smeltr = forcing%rain_on_snow_input * water_heat_capacity * &
          (forcing%mean_air_temperature - snow_temperature) / latent_heat_melting
      else
        smeltr = 0.0_real64
      end if

      fluxes%melt = max(0.0_real64, smelt + smeltr)
      candidate_state%snow_water_storage = candidate_state%snow_water_storage + &
        forcing%snowfall_input - fluxes%sublimation - fluxes%melt - candidate_state%liquid_water_storage
      candidate_state%liquid_water_storage = candidate_state%liquid_water_storage + forcing%rain_on_snow_input
      maximum_liquid_storage = 0.07_real64 * (candidate_state%liquid_water_storage + &
        candidate_state%snow_water_storage)
      liquid_drainage = max(0.0_real64, candidate_state%liquid_water_storage - maximum_liquid_storage)
      candidate_state%liquid_water_storage = candidate_state%liquid_water_storage - liquid_drainage
      candidate_state%snow_water_storage = candidate_state%snow_water_storage + candidate_state%liquid_water_storage
      fluxes%melt = fluxes%melt + liquid_drainage

      if (candidate_state%snow_water_storage < 0.0_real64) then
        snow_deficit = -candidate_state%snow_water_storage
        snow_loss = fluxes%melt + fluxes%sublimation
        fluxes%melt = (1.0_real64 - snow_deficit / snow_loss) * fluxes%melt
        fluxes%sublimation = (1.0_real64 - snow_deficit / snow_loss) * fluxes%sublimation
        candidate_state%snow_water_storage = 0.0_real64
        candidate_state%liquid_water_storage = 0.0_real64
        diagnostics%snow_deficit_clamped = .true.
      end if
    end if

    diagnostics%mass%available = .true.
    diagnostics%mass%storage_start = committed_state%snow_water_storage
    diagnostics%mass%storage_end = candidate_state%snow_water_storage
    diagnostics%mass%storage_change = candidate_state%snow_water_storage - committed_state%snow_water_storage
    diagnostics%mass%snowfall_external_in = forcing%snowfall_input
    diagnostics%mass%rain_external_in = forcing%rain_on_snow_input
    diagnostics%mass%sublimation_external_out = fluxes%sublimation
    diagnostics%mass%melt_internal_transfer = fluxes%melt
    ! Preserve the exact arithmetic grouping used by the source-bound F-PM01
    ! characterization. No scientific tolerance or rounding is introduced.
    diagnostics%mass%unrounded_residual = diagnostics%mass%storage_change - &
      (forcing%snowfall_input + forcing%rain_on_snow_input - fluxes%sublimation - fluxes%melt)
  end subroutine evaluate_snow_reference_call

end module mod_snow_process

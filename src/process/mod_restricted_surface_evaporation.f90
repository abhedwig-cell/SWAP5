module mod_restricted_surface_evaporation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: SURFACE_EVAP_NOT_RUN = 0
  integer, parameter, public :: SURFACE_EVAP_AVAILABLE = 1
  integer, parameter, public :: SURFACE_EVAP_INVALID_INPUT = 2

  type, public :: surface_evaporation_demand_t
    real(real64) :: bare_soil_demand = 0.0_real64
    real(real64) :: ponded_water_demand = 0.0_real64
  end type surface_evaporation_demand_t

  type, public :: surface_evaporation_hydraulic_input_t
    logical :: surface_is_ponded = .false.
    real(real64) :: evaporation_capacity = 0.0_real64
  end type surface_evaporation_hydraulic_input_t

  type, public :: surface_evaporation_result_t
    integer :: status = SURFACE_EVAP_NOT_RUN
    real(real64) :: bare_soil_evaporation = 0.0_real64
    real(real64) :: ponded_water_evaporation = 0.0_real64
    character(len=24) :: route = 'not-run'
  end type surface_evaporation_result_t

  public :: evaluate_restricted_surface_evaporation

contains

  pure subroutine evaluate_restricted_surface_evaporation(demand, hydraulic, result)
    type(surface_evaporation_demand_t), intent(in) :: demand
    type(surface_evaporation_hydraulic_input_t), intent(in) :: hydraulic
    type(surface_evaporation_result_t), intent(out) :: result

    result = surface_evaporation_result_t()

    if (.not. ieee_is_finite(demand%bare_soil_demand)) then
      result%status = SURFACE_EVAP_INVALID_INPUT
      result%route = 'invalid-input'
      return
    end if
    if (.not. ieee_is_finite(demand%ponded_water_demand)) then
      result%status = SURFACE_EVAP_INVALID_INPUT
      result%route = 'invalid-input'
      return
    end if
    if (.not. ieee_is_finite(hydraulic%evaporation_capacity)) then
      result%status = SURFACE_EVAP_INVALID_INPUT
      result%route = 'invalid-input'
      return
    end if
    if (demand%bare_soil_demand < 0.0_real64) then
      result%status = SURFACE_EVAP_INVALID_INPUT
      result%route = 'invalid-input'
      return
    end if
    if (demand%ponded_water_demand < 0.0_real64) then
      result%status = SURFACE_EVAP_INVALID_INPUT
      result%route = 'invalid-input'
      return
    end if

    if (hydraulic%surface_is_ponded) then
      result%bare_soil_evaporation = 0.0_real64
      result%ponded_water_evaporation = demand%ponded_water_demand
      result%route = 'ponded'
    else
      result%bare_soil_evaporation = min(demand%bare_soil_demand, &
                                         max(0.0_real64, hydraulic%evaporation_capacity))
      result%ponded_water_evaporation = 0.0_real64
      result%route = 'dry'
    end if

    result%status = SURFACE_EVAP_AVAILABLE
  end subroutine evaluate_restricted_surface_evaporation

end module mod_restricted_surface_evaporation

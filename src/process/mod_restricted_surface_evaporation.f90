module mod_restricted_surface_evaporation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: SURFACE_EVAP_NOT_RUN = 0
  integer, parameter, public :: SURFACE_EVAP_AVAILABLE = 1
  integer, parameter, public :: SURFACE_EVAP_INVALID_INPUT = 2

  integer, parameter, public :: BLACK_EVAP_NOT_RUN = 0
  integer, parameter, public :: BLACK_EVAP_AVAILABLE = 1
  integer, parameter, public :: BLACK_EVAP_INVALID_INPUT = 2

  type, public :: black_evaporation_parameters_t
    real(real64) :: cofred = 0.0_real64
  end type black_evaporation_parameters_t

  type, public :: black_evaporation_state_t
    real(real64) :: ldwet = 0.0_real64
  end type black_evaporation_state_t

  type, public :: black_evaporation_forcing_t
    real(real64) :: potential_bare_soil_evaporation = 0.0_real64
    logical :: surface_is_ponded = .false.
    logical :: wetting_reset_event = .false.
  end type black_evaporation_forcing_t

  type, public :: black_evaporation_result_t
    integer :: status = BLACK_EVAP_NOT_RUN
    real(real64) :: empirical_bare_soil_evaporation_demand = 0.0_real64
    type(black_evaporation_state_t) :: candidate_state
    logical :: wetting_reset_applied = .false.
    logical :: ponding_reset_applied = .false.
    character(len=32) :: route = 'not-run'
  end type black_evaporation_result_t

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
  public :: evaluate_black_evaporation_reduction

contains

  pure subroutine evaluate_black_evaporation_reduction(parameters, committed_state, forcing, step_duration, result)
    type(black_evaporation_parameters_t), intent(in) :: parameters
    type(black_evaporation_state_t), intent(in) :: committed_state
    type(black_evaporation_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: step_duration
    type(black_evaporation_result_t), intent(out) :: result

    real(real64) :: trial_ldwet, empirical_demand

    result = black_evaporation_result_t()
    if (.not. ieee_is_finite(parameters%cofred) .or. parameters%cofred < 0.0_real64) then
      result%status = BLACK_EVAP_INVALID_INPUT
      result%route = 'invalid-cofred'
      return
    end if
    if (.not. ieee_is_finite(committed_state%ldwet) .or. committed_state%ldwet < 0.0_real64) then
      result%status = BLACK_EVAP_INVALID_INPUT
      result%route = 'invalid-ldwet'
      return
    end if
    if (.not. ieee_is_finite(forcing%potential_bare_soil_evaporation) .or. &
        forcing%potential_bare_soil_evaporation < 0.0_real64) then
      result%status = BLACK_EVAP_INVALID_INPUT
      result%route = 'invalid-demand'
      return
    end if
    if (.not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64) then
      result%status = BLACK_EVAP_INVALID_INPUT
      result%route = 'invalid-duration'
      return
    end if

    if (forcing%surface_is_ponded) then
      result%empirical_bare_soil_evaporation_demand = forcing%potential_bare_soil_evaporation
      result%candidate_state%ldwet = 0.0_real64
      result%ponding_reset_applied = .true.
      result%route = 'ponded-reset'
      result%status = BLACK_EVAP_AVAILABLE
      return
    end if

    trial_ldwet = committed_state%ldwet
    if (forcing%wetting_reset_event) then
      trial_ldwet = 0.0_real64
      result%wetting_reset_applied = .true.
    end if

    empirical_demand = parameters%cofred * &
         (sqrt(trial_ldwet + step_duration) - sqrt(trial_ldwet)) / step_duration
    if (.not. ieee_is_finite(empirical_demand) .or. empirical_demand < 0.0_real64) then
      result%status = BLACK_EVAP_INVALID_INPUT
      result%route = 'invalid-reduction'
      return
    end if

    result%empirical_bare_soil_evaporation_demand = &
         min(forcing%potential_bare_soil_evaporation, empirical_demand)
    result%candidate_state%ldwet = trial_ldwet + step_duration
    result%route = 'dry-black'
    if (result%wetting_reset_applied) result%route = 'wetting-reset-black'
    result%status = BLACK_EVAP_AVAILABLE
  end subroutine evaluate_black_evaporation_reduction


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

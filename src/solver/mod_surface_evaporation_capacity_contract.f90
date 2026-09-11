module mod_surface_evaporation_capacity_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  implicit none
  private

  integer, parameter, public :: SURFACE_EVAP_CAPACITY_NOT_RUN = 0
  integer, parameter, public :: SURFACE_EVAP_CAPACITY_AVAILABLE = 1
  integer, parameter, public :: SURFACE_EVAP_CAPACITY_INVALID_INPUT = 2
  integer, parameter, public :: SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION = 3

  type, public :: surface_evaporation_capacity_result_t
    integer :: status = SURFACE_EVAP_CAPACITY_NOT_RUN
    real(real64) :: evaporation_capacity = 0.0_real64
    character(len=48) :: route = 'not-run'
  end type surface_evaporation_capacity_result_t

  type, abstract, public :: surface_evaporation_capacity_provider_t
  contains
    procedure(surface_evaporation_capacity_evaluate_ifc), deferred :: evaluate
  end type surface_evaporation_capacity_provider_t

  abstract interface
    subroutine surface_evaporation_capacity_evaluate_ifc(self, base_state, result)
      import :: soil_water_physical_state_t, surface_evaporation_capacity_provider_t, &
           surface_evaporation_capacity_result_t
      class(surface_evaporation_capacity_provider_t), intent(in) :: self
      type(soil_water_physical_state_t), intent(in) :: base_state
      type(surface_evaporation_capacity_result_t), intent(out) :: result
    end subroutine surface_evaporation_capacity_evaluate_ifc
  end interface

end module mod_surface_evaporation_capacity_contract

module mod_fmr_pmdirect_surface_evaporation_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_daily_result_t, pmdirect_swetr0_diagnostics_t, &
       PMDIRECT_SWETR0_OK
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t
  implicit none
  private

  integer, parameter, public :: FMR_PMDIRECT_SURFACE_DEMAND_BINDING_OK = 0
  integer, parameter, public :: FMR_PMDIRECT_SURFACE_DEMAND_UPSTREAM_REJECTED = 1
  integer, parameter, public :: FMR_PMDIRECT_SURFACE_DEMAND_INVALID_DEMAND = 2

  type, public :: fmr_pmdirect_surface_demand_binding_diagnostics_t
    integer :: status = FMR_PMDIRECT_SURFACE_DEMAND_BINDING_OK
    integer :: upstream_status = PMDIRECT_SWETR0_OK
    logical :: upstream_result_accepted = .false.
    logical :: demand_bound = .false.
    logical :: result_produced = .false.
  end type fmr_pmdirect_surface_demand_binding_diagnostics_t

  public :: fmr_bind_pmdirect_surface_evaporation_demand

contains

  subroutine fmr_bind_pmdirect_surface_evaporation_demand(pmdirect_result, pmdirect_diagnostics, demand, diagnostics)
    type(pmdirect_swetr0_daily_result_t), intent(in) :: pmdirect_result
    type(pmdirect_swetr0_diagnostics_t), intent(in) :: pmdirect_diagnostics
    type(surface_evaporation_demand_t), intent(out) :: demand
    type(fmr_pmdirect_surface_demand_binding_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: bare_demand, ponded_demand

    demand = surface_evaporation_demand_t()
    diagnostics = fmr_pmdirect_surface_demand_binding_diagnostics_t()
    diagnostics%upstream_status = pmdirect_diagnostics%status

    if (pmdirect_diagnostics%status /= PMDIRECT_SWETR0_OK .or. &
        .not. pmdirect_diagnostics%daily_result_produced) then
      diagnostics%status = FMR_PMDIRECT_SURFACE_DEMAND_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_result_accepted = .true.

    bare_demand = pmdirect_result%potential_soil_evaporation_cm_per_day
    ponded_demand = pmdirect_result%potential_pond_evaporation_cm_per_day
    if (.not. ieee_is_finite(bare_demand)) then
      diagnostics%status = FMR_PMDIRECT_SURFACE_DEMAND_INVALID_DEMAND
      return
    end if
    if (.not. ieee_is_finite(ponded_demand)) then
      diagnostics%status = FMR_PMDIRECT_SURFACE_DEMAND_INVALID_DEMAND
      return
    end if
    if (bare_demand < 0.0_real64) then
      diagnostics%status = FMR_PMDIRECT_SURFACE_DEMAND_INVALID_DEMAND
      return
    end if
    if (ponded_demand < 0.0_real64) then
      diagnostics%status = FMR_PMDIRECT_SURFACE_DEMAND_INVALID_DEMAND
      return
    end if

    demand%bare_soil_demand = bare_demand
    demand%ponded_water_demand = ponded_demand
    diagnostics%demand_bound = .true.
    diagnostics%result_produced = .true.
  end subroutine fmr_bind_pmdirect_surface_evaporation_demand

end module mod_fmr_pmdirect_surface_evaporation_binding

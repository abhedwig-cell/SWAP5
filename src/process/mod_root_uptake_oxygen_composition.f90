module mod_root_uptake_oxygen_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &
       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, &
       ROOT_UPTAKE_OK
  implicit none
  private

  integer, parameter, public :: ROOT_OXYGEN_COMPOSE_OK = 0
  integer, parameter, public :: ROOT_OXYGEN_COMPOSE_SHAPE = 1
  integer, parameter, public :: ROOT_OXYGEN_COMPOSE_INVALID_FACTOR = 2

  public :: compose_root_sink_with_oxygen_factor
  public :: evaluate_macro_feddes_drought_oxygen_uptake

contains

  subroutine evaluate_macro_feddes_drought_oxygen_uptake(parameters, hydraulic_view, request, oxygen_factor, &
                                                          fluxes, diagnostics, status)
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(root_water_uptake_request_t), intent(in) :: request
    real(real64), intent(in) :: oxygen_factor(:)
    type(root_water_uptake_flux_result_t), intent(out) :: fluxes
    type(root_water_uptake_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status
    type(root_water_uptake_flux_result_t) :: drought_fluxes

    call evaluate_macro_feddes_drought_uptake(parameters, hydraulic_view, request, drought_fluxes, diagnostics)
    if (diagnostics%status /= ROOT_UPTAKE_OK) then
      fluxes = root_water_uptake_flux_result_t()
      status = ROOT_OXYGEN_COMPOSE_SHAPE
      return
    end if

    call compose_root_sink_with_oxygen_factor(drought_fluxes, request%rooted_nodes, oxygen_factor, fluxes, status)
  end subroutine evaluate_macro_feddes_drought_oxygen_uptake


  subroutine compose_root_sink_with_oxygen_factor(base_fluxes, rooted_nodes, oxygen_factor, fluxes, status)
    type(root_water_uptake_flux_result_t), intent(in) :: base_fluxes
    integer, intent(in) :: rooted_nodes
    real(real64), intent(in) :: oxygen_factor(:)
    type(root_water_uptake_flux_result_t), intent(out) :: fluxes
    integer, intent(out) :: status
    integer :: n

    fluxes = root_water_uptake_flux_result_t()
    status = ROOT_OXYGEN_COMPOSE_OK

    if (.not. allocated(base_fluxes%root_extraction_sink)) then
      if (rooted_nodes == 0 .and. size(oxygen_factor) == 0) return
      status = ROOT_OXYGEN_COMPOSE_SHAPE
      return
    end if

    n = size(base_fluxes%root_extraction_sink)
    if (rooted_nodes < 0 .or. rooted_nodes > n .or. size(oxygen_factor) /= rooted_nodes) then
      status = ROOT_OXYGEN_COMPOSE_SHAPE
      return
    end if
    if (rooted_nodes > 0) then
      if (any(.not. ieee_is_finite(oxygen_factor))) then
        status = ROOT_OXYGEN_COMPOSE_INVALID_FACTOR
        return
      end if
      if (any(oxygen_factor < 0.0_real64) .or. any(oxygen_factor > 1.0_real64)) then
        status = ROOT_OXYGEN_COMPOSE_INVALID_FACTOR
        return
      end if
    end if

    allocate(fluxes%root_extraction_sink(n))
    fluxes%root_extraction_sink = base_fluxes%root_extraction_sink
    if (rooted_nodes > 0) then
      fluxes%root_extraction_sink(1:rooted_nodes) = &
        base_fluxes%root_extraction_sink(1:rooted_nodes) * oxygen_factor
    end if
    fluxes%actual_uptake_total = sum(fluxes%root_extraction_sink)
  end subroutine compose_root_sink_with_oxygen_factor

end module mod_root_uptake_oxygen_composition

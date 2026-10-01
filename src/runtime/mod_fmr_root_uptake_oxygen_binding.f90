module mod_fmr_root_uptake_oxygen_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_root_uptake_oxygen_composition, only: compose_root_sink_with_oxygen_factor, ROOT_OXYGEN_COMPOSE_OK
  implicit none
  private

  integer, parameter, public :: FMR_ROOT_OXYGEN_OK = 0
  integer, parameter, public :: FMR_ROOT_OXYGEN_FACTOR_REJECTED = 1

  type, public :: fmr_root_oxygen_binding_diagnostics_t
    integer :: status = FMR_ROOT_OXYGEN_OK
    integer :: composition_status = ROOT_OXYGEN_COMPOSE_OK
    logical :: oxygen_enabled = .false.
    logical :: preservation_route = .false.
  end type

  public :: fmr_apply_root_uptake_oxygen_selection

contains

  subroutine fmr_apply_root_uptake_oxygen_selection(base_fluxes, rooted_nodes, oxygen_enabled, oxygen_factor, &
                                                     fluxes, diagnostics)
    type(root_water_uptake_flux_result_t), intent(in) :: base_fluxes
    integer, intent(in) :: rooted_nodes
    logical, intent(in) :: oxygen_enabled
    real(real64), intent(in), optional :: oxygen_factor(:)
    type(root_water_uptake_flux_result_t), intent(out) :: fluxes
    type(fmr_root_oxygen_binding_diagnostics_t), intent(out) :: diagnostics
    integer :: compose_status

    fluxes = root_water_uptake_flux_result_t()
    diagnostics = fmr_root_oxygen_binding_diagnostics_t()
    diagnostics%oxygen_enabled = oxygen_enabled

    if (.not. oxygen_enabled) then
      fluxes = base_fluxes
      diagnostics%preservation_route = .true.
      return
    end if

    if (.not. present(oxygen_factor)) then
      diagnostics%status = FMR_ROOT_OXYGEN_FACTOR_REJECTED
      return
    end if

    call compose_root_sink_with_oxygen_factor(base_fluxes, rooted_nodes, oxygen_factor, fluxes, compose_status)
    diagnostics%composition_status = compose_status
    if (compose_status /= ROOT_OXYGEN_COMPOSE_OK) then
      diagnostics%status = FMR_ROOT_OXYGEN_FACTOR_REJECTED
      fluxes = root_water_uptake_flux_result_t()
    end if
  end subroutine

end module mod_fmr_root_uptake_oxygen_binding

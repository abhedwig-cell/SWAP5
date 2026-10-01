module mod_fmr_root_uptake_oxygen_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_crop_input_t, &
       fmr_root_uptake_binding_diagnostics_t, fmr_evaluate_committed_root_uptake, FMR_ROOT_UPTAKE_BINDING_OK
  use mod_root_uptake_oxygen_composition, only: compose_root_sink_with_oxygen_factor, ROOT_OXYGEN_COMPOSE_OK
  implicit none
  private

  integer, parameter, public :: FMR_ROOT_OXYGEN_OK = 0
  integer, parameter, public :: FMR_ROOT_OXYGEN_ROOT_REJECTED = 1
  integer, parameter, public :: FMR_ROOT_OXYGEN_FACTOR_REJECTED = 2

  type, public :: fmr_root_oxygen_binding_diagnostics_t
    integer :: status = FMR_ROOT_OXYGEN_OK
    integer :: composition_status = ROOT_OXYGEN_COMPOSE_OK
    logical :: oxygen_enabled = .false.
    logical :: preservation_route = .false.
  end type

  public :: fmr_evaluate_committed_root_uptake_with_oxygen

contains

  subroutine fmr_evaluate_committed_root_uptake_with_oxygen(committed, parameters, crop_input, oxygen_enabled, &
       oxygen_factor, fluxes, process_diagnostics, root_diagnostics, oxygen_diagnostics)
    type(kernel_committed_state_t), intent(in) :: committed
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    type(fmr_root_uptake_crop_input_t), intent(in) :: crop_input
    logical, intent(in) :: oxygen_enabled
    real(real64), intent(in), optional :: oxygen_factor(:)
    type(root_water_uptake_flux_result_t), intent(out) :: fluxes
    type(root_water_uptake_diagnostics_t), intent(out) :: process_diagnostics
    type(fmr_root_uptake_binding_diagnostics_t), intent(out) :: root_diagnostics
    type(fmr_root_oxygen_binding_diagnostics_t), intent(out) :: oxygen_diagnostics

    type(root_water_uptake_flux_result_t) :: base_fluxes
    integer :: compose_status

    fluxes = root_water_uptake_flux_result_t()
    oxygen_diagnostics = fmr_root_oxygen_binding_diagnostics_t()
    oxygen_diagnostics%oxygen_enabled = oxygen_enabled

    call fmr_evaluate_committed_root_uptake(committed, parameters, crop_input, base_fluxes, process_diagnostics, &
                                            root_diagnostics)
    if (root_diagnostics%status /= FMR_ROOT_UPTAKE_BINDING_OK) then
      oxygen_diagnostics%status = FMR_ROOT_OXYGEN_ROOT_REJECTED
      return
    end if

    if (.not. oxygen_enabled) then
      fluxes = base_fluxes
      oxygen_diagnostics%preservation_route = .true.
      return
    end if

    if (.not. present(oxygen_factor)) then
      oxygen_diagnostics%status = FMR_ROOT_OXYGEN_FACTOR_REJECTED
      return
    end if

    call compose_root_sink_with_oxygen_factor(base_fluxes, crop_input%rooted_nodes, oxygen_factor, fluxes, compose_status)
    oxygen_diagnostics%composition_status = compose_status
    if (compose_status /= ROOT_OXYGEN_COMPOSE_OK) then
      oxygen_diagnostics%status = FMR_ROOT_OXYGEN_FACTOR_REJECTED
      fluxes = root_water_uptake_flux_result_t()
      return
    end if
  end subroutine

end module mod_fmr_root_uptake_oxygen_binding

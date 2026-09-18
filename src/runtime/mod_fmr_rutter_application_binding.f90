module mod_fmr_rutter_application_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rutter_interception_process, only: rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, &
       CROP_ROOT_INPUT_OK
  implicit none
  private

  integer, parameter, public :: FMR_RUTTER_BIND_OK = 0
  integer, parameter, public :: FMR_RUTTER_BIND_UPSTREAM_REJECTED = 1
  integer, parameter, public :: FMR_RUTTER_BIND_INVALID_NET_RAIN = 2
  integer, parameter, public :: FMR_RUTTER_BIND_INVALID_NET_IRRIGATION = 3
  integer, parameter, public :: FMR_RUTTER_BIND_INVALID_PTRA = 4
  integer, parameter, public :: FMR_RUTTER_BIND_INVALID_ROOT_GEOMETRY = 5
  integer, parameter, public :: FMR_RUTTER_BIND_ASSEMBLED_ROOT_REJECTED = 6

  type, public :: fmr_rutter_binding_diagnostics_t
    integer :: status = FMR_RUTTER_BIND_OK
    integer :: root_geometry_status = CROP_ROOT_INPUT_OK
    integer :: assembled_root_status = CROP_ROOT_INPUT_OK
    logical :: upstream_accepted = .false.
    logical :: incoming_surface_fluxes_ignored = .false.
    logical :: incoming_ptra_ignored = .false.
    logical :: inactive_crop_zero_applied = .false.
    logical :: result_produced = .false.
  end type

  public :: fmr_bind_rutter_surface_fluxes_to_dynamic_top
  public :: fmr_bind_rutter_ptra_to_root_input

contains

  subroutine fmr_bind_rutter_surface_fluxes_to_dynamic_top(base_request, rutter, upstream, bound_request, diagnostics)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_request
    type(rutter_interval_result_t), intent(in) :: rutter
    type(rutter_diagnostics_t), intent(in) :: upstream
    type(b110_dynamic_top_boundary_request_t), intent(out) :: bound_request
    type(fmr_rutter_binding_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: net_rain, net_irrigation

    bound_request = b110_dynamic_top_boundary_request_t()
    diagnostics = fmr_rutter_binding_diagnostics_t()
    if (upstream%status /= RUTTER_OK .or. .not. upstream%result_produced) then
      diagnostics%status = FMR_RUTTER_BIND_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_accepted = .true.

    net_rain = rutter%net_rain_cm_per_day
    net_irrigation = rutter%net_surface_irrigation_cm_per_day
    if (.not. ieee_is_finite(net_rain) .or. net_rain < 0.0_real64) then
      diagnostics%status = FMR_RUTTER_BIND_INVALID_NET_RAIN
      return
    end if
    if (.not. ieee_is_finite(net_irrigation) .or. net_irrigation < 0.0_real64) then
      diagnostics%status = FMR_RUTTER_BIND_INVALID_NET_IRRIGATION
      return
    end if

    bound_request = base_request
    diagnostics%incoming_surface_fluxes_ignored = .true.
    bound_request%precipitation_rate_cm_per_day = net_rain
    bound_request%irrigation_rate_cm_per_day = net_irrigation
    diagnostics%result_produced = .true.
  end subroutine fmr_bind_rutter_surface_fluxes_to_dynamic_top

  subroutine fmr_bind_rutter_ptra_to_root_input(base_input, active_nodes, rutter, upstream, bound_input, diagnostics)
    type(crop_root_uptake_input_t), intent(in) :: base_input
    integer, intent(in) :: active_nodes
    type(rutter_interval_result_t), intent(in) :: rutter
    type(rutter_diagnostics_t), intent(in) :: upstream
    type(crop_root_uptake_input_t), intent(out) :: bound_input
    type(fmr_rutter_binding_diagnostics_t), intent(out) :: diagnostics
    type(crop_root_uptake_input_t) :: geometry_input
    real(real64) :: ptra
    integer :: contract_status

    bound_input = crop_root_uptake_input_t()
    diagnostics = fmr_rutter_binding_diagnostics_t()
    if (upstream%status /= RUTTER_OK .or. .not. upstream%result_produced) then
      diagnostics%status = FMR_RUTTER_BIND_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_accepted = .true.

    ptra = rutter%potential_transpiration_cm_per_day
    if (.not. ieee_is_finite(ptra) .or. ptra < 0.0_real64) then
      diagnostics%status = FMR_RUTTER_BIND_INVALID_PTRA
      return
    end if

    geometry_input = base_input
    geometry_input%potential_transpiration = 0.0_real64
    diagnostics%incoming_ptra_ignored = .true.
    call validate_crop_root_uptake_input(geometry_input, active_nodes, contract_status)
    diagnostics%root_geometry_status = contract_status
    if (contract_status /= CROP_ROOT_INPUT_OK) then
      diagnostics%status = FMR_RUTTER_BIND_INVALID_ROOT_GEOMETRY
      return
    end if

    bound_input = geometry_input
    if (.not. bound_input%crop_emerged) then
      diagnostics%inactive_crop_zero_applied = .true.
    else
      bound_input%potential_transpiration = ptra
    end if

    call validate_crop_root_uptake_input(bound_input, active_nodes, contract_status)
    diagnostics%assembled_root_status = contract_status
    if (contract_status /= CROP_ROOT_INPUT_OK) then
      bound_input = crop_root_uptake_input_t()
      diagnostics%status = FMR_RUTTER_BIND_ASSEMBLED_ROOT_REJECTED
      diagnostics%inactive_crop_zero_applied = .false.
      return
    end if
    diagnostics%result_produced = .true.
  end subroutine fmr_bind_rutter_ptra_to_root_input
end module mod_fmr_rutter_application_binding

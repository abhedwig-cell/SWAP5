module mod_fmr_reference_et_ptra_root_input_binding
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, &
       CROP_ROOT_INPUT_OK
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, &
       FMR_REFERENCE_ET_BINDING_OK
  implicit none
  private

  integer, parameter, public :: FMR_PTRA_ROOT_INPUT_BINDING_OK = 0
  integer, parameter, public :: FMR_PTRA_ROOT_INPUT_UPSTREAM_ET_REJECTED = 1
  integer, parameter, public :: FMR_PTRA_ROOT_INPUT_INVALID_ROOT_GEOMETRY = 2
  integer, parameter, public :: FMR_PTRA_ROOT_INPUT_ASSEMBLED_INPUT_REJECTED = 3

  type, public :: fmr_ptra_root_input_binding_diagnostics_t
    integer :: status = FMR_PTRA_ROOT_INPUT_BINDING_OK
    integer :: upstream_et_status = FMR_REFERENCE_ET_BINDING_OK
    integer :: root_geometry_status = CROP_ROOT_INPUT_OK
    integer :: assembled_input_status = CROP_ROOT_INPUT_OK
    logical :: upstream_result_accepted = .false.
    logical :: incoming_ptra_ignored = .false.
    logical :: ptra_bound = .false.
    logical :: result_produced = .false.
  end type fmr_ptra_root_input_binding_diagnostics_t

  public :: fmr_bind_reference_et_ptra_to_root_input

contains

  subroutine fmr_bind_reference_et_ptra_to_root_input(base_input, active_nodes, et_result, et_diagnostics, &
                                                       bound_input, diagnostics)
    type(crop_root_uptake_input_t), intent(in) :: base_input
    integer, intent(in) :: active_nodes
    type(reference_et_demand_result_t), intent(in) :: et_result
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: et_diagnostics
    type(crop_root_uptake_input_t), intent(out) :: bound_input
    type(fmr_ptra_root_input_binding_diagnostics_t), intent(out) :: diagnostics

    type(crop_root_uptake_input_t) :: geometry_input
    integer :: contract_status

    bound_input = crop_root_uptake_input_t()
    diagnostics = fmr_ptra_root_input_binding_diagnostics_t()
    diagnostics%upstream_et_status = et_diagnostics%status

    if (et_diagnostics%status /= FMR_REFERENCE_ET_BINDING_OK .or. .not. et_diagnostics%result_produced) then
      diagnostics%status = FMR_PTRA_ROOT_INPUT_UPSTREAM_ET_REJECTED
      return
    end if
    diagnostics%upstream_result_accepted = .true.

    ! potential_transpiration in the incoming crop/root object is deliberately
    ! not authoritative here. Validate only its crop/root geometry by replacing
    ! that transport field with a neutral value before applying the existing
    ! canonical root-input contract.
    geometry_input = base_input
    geometry_input%potential_transpiration = 0.0d0
    diagnostics%incoming_ptra_ignored = .true.

    call validate_crop_root_uptake_input(geometry_input, active_nodes, contract_status)
    diagnostics%root_geometry_status = contract_status
    if (contract_status /= CROP_ROOT_INPUT_OK) then
      diagnostics%status = FMR_PTRA_ROOT_INPUT_INVALID_ROOT_GEOMETRY
      return
    end if

    bound_input = geometry_input
    bound_input%potential_transpiration = et_result%potential_transpiration_cm_per_day
    diagnostics%ptra_bound = .true.

    call validate_crop_root_uptake_input(bound_input, active_nodes, contract_status)
    diagnostics%assembled_input_status = contract_status
    if (contract_status /= CROP_ROOT_INPUT_OK) then
      bound_input = crop_root_uptake_input_t()
      diagnostics%ptra_bound = .false.
      diagnostics%status = FMR_PTRA_ROOT_INPUT_ASSEMBLED_INPUT_REJECTED
      return
    end if

    diagnostics%result_produced = .true.
  end subroutine fmr_bind_reference_et_ptra_to_root_input

end module mod_fmr_reference_et_ptra_root_input_binding

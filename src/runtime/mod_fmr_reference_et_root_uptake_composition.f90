module mod_fmr_reference_et_root_uptake_composition
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t
  use mod_fmr_reference_et_ptra_root_input_binding, only: fmr_ptra_root_input_binding_diagnostics_t, &
       fmr_bind_reference_et_ptra_to_root_input, FMR_PTRA_ROOT_INPUT_BINDING_OK
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_binding_diagnostics_t
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_crop_root_uptake_adapter_diagnostics_t, &
       fmr_evaluate_shared_crop_root_uptake, FMR_CROP_ROOT_ADAPTER_OK
  implicit none
  private

  integer, parameter, public :: FMR_REFERENCE_ET_ROOT_UPTAKE_OK = 0
  integer, parameter, public :: FMR_REFERENCE_ET_ROOT_UPTAKE_PTRA_REJECTED = 1
  integer, parameter, public :: FMR_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_REJECTED = 2

  type, public :: fmr_reference_et_root_uptake_diagnostics_t
    integer :: status = FMR_REFERENCE_ET_ROOT_UPTAKE_OK
    integer :: ptra_binding_status = FMR_PTRA_ROOT_INPUT_BINDING_OK
    integer :: adapter_status = FMR_CROP_ROOT_ADAPTER_OK
    integer :: root_binding_status = 0
    integer :: process_status = 0
    logical :: ptra_binding_called = .false.
    logical :: ptra_bound = .false.
    logical :: root_execution_called = .false.
    logical :: result_produced = .false.
  end type fmr_reference_et_root_uptake_diagnostics_t

  public :: fmr_evaluate_reference_et_root_uptake

contains

  subroutine fmr_evaluate_reference_et_root_uptake(committed, parameters, base_input, et_result, et_diagnostics, &
                                                    fluxes, process_diagnostics, ptra_diagnostics, &
                                                    adapter_diagnostics, binding_diagnostics, diagnostics)
    type(kernel_committed_state_t), intent(in) :: committed
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    type(crop_root_uptake_input_t), intent(in) :: base_input
    type(reference_et_demand_result_t), intent(in) :: et_result
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: et_diagnostics
    type(root_water_uptake_flux_result_t), intent(out) :: fluxes
    type(root_water_uptake_diagnostics_t), intent(out) :: process_diagnostics
    type(fmr_ptra_root_input_binding_diagnostics_t), intent(out) :: ptra_diagnostics
    type(fmr_crop_root_uptake_adapter_diagnostics_t), intent(out) :: adapter_diagnostics
    type(fmr_root_uptake_binding_diagnostics_t), intent(out) :: binding_diagnostics
    type(fmr_reference_et_root_uptake_diagnostics_t), intent(out) :: diagnostics

    type(crop_root_uptake_input_t) :: bound_input

    fluxes = root_water_uptake_flux_result_t()
    process_diagnostics = root_water_uptake_diagnostics_t()
    ptra_diagnostics = fmr_ptra_root_input_binding_diagnostics_t()
    adapter_diagnostics = fmr_crop_root_uptake_adapter_diagnostics_t()
    binding_diagnostics = fmr_root_uptake_binding_diagnostics_t()
    diagnostics = fmr_reference_et_root_uptake_diagnostics_t()

    diagnostics%ptra_binding_called = .true.
    call fmr_bind_reference_et_ptra_to_root_input(base_input, parameters%active_nodes, et_result, et_diagnostics, &
                                                   bound_input, ptra_diagnostics)
    diagnostics%ptra_binding_status = ptra_diagnostics%status
    diagnostics%ptra_bound = ptra_diagnostics%result_produced
    if (ptra_diagnostics%status /= FMR_PTRA_ROOT_INPUT_BINDING_OK .or. .not. ptra_diagnostics%result_produced) then
      diagnostics%status = FMR_REFERENCE_ET_ROOT_UPTAKE_PTRA_REJECTED
      return
    end if

    diagnostics%root_execution_called = .true.
    call fmr_evaluate_shared_crop_root_uptake(committed, parameters, bound_input, fluxes, process_diagnostics, &
                                               binding_diagnostics, adapter_diagnostics)
    diagnostics%adapter_status = adapter_diagnostics%status
    diagnostics%root_binding_status = binding_diagnostics%status
    diagnostics%process_status = process_diagnostics%status
    if (adapter_diagnostics%status /= FMR_CROP_ROOT_ADAPTER_OK) then
      fluxes = root_water_uptake_flux_result_t()
      diagnostics%status = FMR_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_REJECTED
      return
    end if

    diagnostics%result_produced = .true.
  end subroutine fmr_evaluate_reference_et_root_uptake

end module mod_fmr_reference_et_root_uptake_composition

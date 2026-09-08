module mod_fmr_crop_root_uptake_input_adapter
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, &
       CROP_ROOT_INPUT_OK
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_crop_input_t, &
       fmr_root_uptake_binding_diagnostics_t, fmr_evaluate_committed_root_uptake, FMR_ROOT_UPTAKE_BINDING_OK
  implicit none
  private

  integer, parameter, public :: FMR_CROP_ROOT_ADAPTER_OK = 0
  integer, parameter, public :: FMR_CROP_ROOT_ADAPTER_INVALID_CROP_INPUT = 1
  integer, parameter, public :: FMR_CROP_ROOT_ADAPTER_BINDING_REJECTED = 2

  type, public :: fmr_crop_root_uptake_adapter_diagnostics_t
    integer :: status = FMR_CROP_ROOT_ADAPTER_OK
    integer :: crop_contract_status = CROP_ROOT_INPUT_OK
    logical :: adapted = .false.
    logical :: binding_called = .false.
  end type fmr_crop_root_uptake_adapter_diagnostics_t

  public :: fmr_adapt_crop_root_uptake_input
  public :: fmr_evaluate_shared_crop_root_uptake

contains

  subroutine fmr_adapt_crop_root_uptake_input(shared_input, active_nodes, runtime_input, diagnostics)
    type(crop_root_uptake_input_t), intent(in) :: shared_input
    integer, intent(in) :: active_nodes
    type(fmr_root_uptake_crop_input_t), intent(out) :: runtime_input
    type(fmr_crop_root_uptake_adapter_diagnostics_t), intent(out) :: diagnostics

    integer :: crop_status

    runtime_input = fmr_root_uptake_crop_input_t()
    diagnostics = fmr_crop_root_uptake_adapter_diagnostics_t()

    call validate_crop_root_uptake_input(shared_input, active_nodes, crop_status)
    diagnostics%crop_contract_status = crop_status
    if (crop_status /= CROP_ROOT_INPUT_OK) then
      diagnostics%status = FMR_CROP_ROOT_ADAPTER_INVALID_CROP_INPUT
      return
    end if

    runtime_input%crop_emerged = shared_input%crop_emerged
    runtime_input%potential_transpiration = shared_input%potential_transpiration
    runtime_input%rooted_nodes = shared_input%rooted_nodes
    if (allocated(shared_input%cumulative_root_fraction)) then
      allocate(runtime_input%cumulative_root_fraction(size(shared_input%cumulative_root_fraction)))
      runtime_input%cumulative_root_fraction = shared_input%cumulative_root_fraction
    end if

    diagnostics%adapted = .true.
  end subroutine fmr_adapt_crop_root_uptake_input

  subroutine fmr_evaluate_shared_crop_root_uptake(committed, parameters, shared_input, fluxes, process_diagnostics, &
                                                   binding_diagnostics, adapter_diagnostics)
    type(kernel_committed_state_t), intent(in) :: committed
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    type(crop_root_uptake_input_t), intent(in) :: shared_input
    type(root_water_uptake_flux_result_t), intent(out) :: fluxes
    type(root_water_uptake_diagnostics_t), intent(out) :: process_diagnostics
    type(fmr_root_uptake_binding_diagnostics_t), intent(out) :: binding_diagnostics
    type(fmr_crop_root_uptake_adapter_diagnostics_t), intent(out) :: adapter_diagnostics

    type(fmr_root_uptake_crop_input_t) :: runtime_input

    fluxes = root_water_uptake_flux_result_t()
    process_diagnostics = root_water_uptake_diagnostics_t()
    binding_diagnostics = fmr_root_uptake_binding_diagnostics_t()
    adapter_diagnostics = fmr_crop_root_uptake_adapter_diagnostics_t()

    call fmr_adapt_crop_root_uptake_input(shared_input, parameters%active_nodes, runtime_input, adapter_diagnostics)
    if (adapter_diagnostics%status /= FMR_CROP_ROOT_ADAPTER_OK) return

    adapter_diagnostics%binding_called = .true.
    call fmr_evaluate_committed_root_uptake(committed, parameters, runtime_input, fluxes, process_diagnostics, &
                                            binding_diagnostics)
    if (binding_diagnostics%status /= FMR_ROOT_UPTAKE_BINDING_OK) then
      adapter_diagnostics%status = FMR_CROP_ROOT_ADAPTER_BINDING_REJECTED
      return
    end if
  end subroutine fmr_evaluate_shared_crop_root_uptake

end module mod_fmr_crop_root_uptake_input_adapter

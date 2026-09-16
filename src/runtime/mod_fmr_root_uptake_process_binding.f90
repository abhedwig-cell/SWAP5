module mod_fmr_root_uptake_process_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &
       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, &
       ROOT_UPTAKE_OK
  implicit none
  private

  integer, parameter, public :: FMR_ROOT_UPTAKE_BINDING_OK = 0
  integer, parameter, public :: FMR_ROOT_UPTAKE_BINDING_HYDRAULIC_VIEW_UNAVAILABLE = 1
  integer, parameter, public :: FMR_ROOT_UPTAKE_BINDING_PROCESS_REJECTED = 2

  type, public :: fmr_root_uptake_crop_input_t
    logical :: crop_emerged = .false.
    real(real64) :: potential_transpiration = 0.0_real64
    integer :: rooted_nodes = 0
    real(real64), allocatable :: cumulative_root_fraction(:)
  end type fmr_root_uptake_crop_input_t

  type, public :: fmr_root_uptake_binding_diagnostics_t
    integer :: status = FMR_ROOT_UPTAKE_BINDING_OK
    integer :: process_status = ROOT_UPTAKE_OK
    logical :: crop_emerged = .false.
    logical :: inactive_crop_zero_route = .false.
    logical :: hydraulic_view_built = .false.
    logical :: process_called = .false.
  end type fmr_root_uptake_binding_diagnostics_t

  public :: fmr_evaluate_committed_root_uptake

contains

  subroutine fmr_evaluate_committed_root_uptake(committed, parameters, crop_input, fluxes, process_diagnostics, diagnostics)
    type(kernel_committed_state_t), intent(in) :: committed
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    type(fmr_root_uptake_crop_input_t), intent(in) :: crop_input
    type(root_water_uptake_flux_result_t), intent(out) :: fluxes
    type(root_water_uptake_diagnostics_t), intent(out) :: process_diagnostics
    type(fmr_root_uptake_binding_diagnostics_t), intent(out) :: diagnostics

    type(process_hydraulic_view_t) :: view
    type(root_water_uptake_request_t) :: request
    logical :: ok

    fluxes = root_water_uptake_flux_result_t()
    process_diagnostics = root_water_uptake_diagnostics_t()
    diagnostics = fmr_root_uptake_binding_diagnostics_t()
    diagnostics%crop_emerged = crop_input%crop_emerged

    if (.not. crop_input%crop_emerged) then
      request%potential_transpiration = 0.0_real64
      request%rooted_nodes = 0
      diagnostics%process_called = .true.
      call evaluate_macro_feddes_drought_uptake(parameters, view, request, fluxes, process_diagnostics)
      diagnostics%process_status = process_diagnostics%status
      if (process_diagnostics%status /= ROOT_UPTAKE_OK) then
        diagnostics%status = FMR_ROOT_UPTAKE_BINDING_PROCESS_REJECTED
        return
      end if
      diagnostics%inactive_crop_zero_route = .true.
      return
    end if

    request%potential_transpiration = crop_input%potential_transpiration
    request%rooted_nodes = crop_input%rooted_nodes
    if (allocated(crop_input%cumulative_root_fraction)) then
      allocate(request%cumulative_root_fraction(size(crop_input%cumulative_root_fraction)))
      request%cumulative_root_fraction = crop_input%cumulative_root_fraction
    end if

    call fmr_build_committed_process_hydraulic_view(committed, view, ok)
    if (.not. ok) then
      diagnostics%status = FMR_ROOT_UPTAKE_BINDING_HYDRAULIC_VIEW_UNAVAILABLE
      return
    end if
    diagnostics%hydraulic_view_built = .true.

    diagnostics%process_called = .true.
    call evaluate_macro_feddes_drought_uptake(parameters, view, request, fluxes, process_diagnostics)
    diagnostics%process_status = process_diagnostics%status
    if (process_diagnostics%status /= ROOT_UPTAKE_OK) then
      diagnostics%status = FMR_ROOT_UPTAKE_BINDING_PROCESS_REJECTED
      return
    end if
  end subroutine fmr_evaluate_committed_root_uptake

end module mod_fmr_root_uptake_process_binding

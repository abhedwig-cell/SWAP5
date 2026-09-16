module mod_fmr_divdra_runtime_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
       drainage_distribution_diagnostics_t, distribute_single_level_positive_divdra, DRAIN_DIST_OK
  implicit none
  private

  integer, parameter, public :: FMR_DIVDRA_BIND_OK = 0
  integer, parameter, public :: FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND = 1
  integer, parameter, public :: FMR_DIVDRA_BIND_PROCESS_REJECTED = 2
  integer, parameter, public :: FMR_DIVDRA_BIND_INVALID_PROCESS_RESULT = 3

  type, public :: fmr_divdra_binding_diagnostics_t
    integer :: status = FMR_DIVDRA_BIND_OK
    integer :: process_status = DRAIN_DIST_OK
    logical :: process_evaluated = .false.
    logical :: published = .false.
    integer :: drainage_levels = 0
    integer :: active_nodes = 0
    real(real64) :: authoritative_scalar_transfer = 0.0_real64
    type(drainage_distribution_diagnostics_t) :: process
  end type fmr_divdra_binding_diagnostics_t

  public :: fmr_bind_single_level_positive_divdra

contains

  subroutine fmr_bind_single_level_positive_divdra(parameters, hydraulic_view, scalar_transfer, &
       drainage_flux_by_level, diagnostics)
    type(drainage_distribution_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(in) :: scalar_transfer
    real(real64), allocatable, intent(inout) :: drainage_flux_by_level(:,:)
    type(fmr_divdra_binding_diagnostics_t), intent(out) :: diagnostics

    type(drainage_node_transfer_t) :: node_transfer
    type(drainage_distribution_diagnostics_t) :: process_diagnostics
    integer :: n

    diagnostics = fmr_divdra_binding_diagnostics_t()
    diagnostics%authoritative_scalar_transfer = scalar_transfer

    ! Fail closed rather than overwrite a drainage field already materialized
    ! by another runtime component.
    if (allocated(drainage_flux_by_level)) then
      diagnostics%status = FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND
      return
    end if

    call distribute_single_level_positive_divdra(parameters, hydraulic_view, scalar_transfer, &
         node_transfer, process_diagnostics)

    diagnostics%process = process_diagnostics
    diagnostics%process_status = process_diagnostics%status
    diagnostics%process_evaluated = process_diagnostics%evaluated

    if (process_diagnostics%status /= DRAIN_DIST_OK) then
      diagnostics%status = FMR_DIVDRA_BIND_PROCESS_REJECTED
      return
    end if

    n = parameters%active_nodes
    if (n <= 0 .or. .not. allocated(node_transfer%soil_to_drain_rate)) then
      diagnostics%status = FMR_DIVDRA_BIND_INVALID_PROCESS_RESULT
      return
    end if
    if (size(node_transfer%soil_to_drain_rate) /= n) then
      diagnostics%status = FMR_DIVDRA_BIND_INVALID_PROCESS_RESULT
      return
    end if

    ! Publication is deliberately last. The scalar remains the authoritative
    ! mass object; this layer neither renormalizes nor reconstructs it.
    allocate(drainage_flux_by_level(1,n))
    drainage_flux_by_level(1,:) = node_transfer%soil_to_drain_rate

    diagnostics%status = FMR_DIVDRA_BIND_OK
    diagnostics%published = .true.
    diagnostics%drainage_levels = 1
    diagnostics%active_nodes = n
  end subroutine fmr_bind_single_level_positive_divdra

end module mod_fmr_divdra_runtime_binding

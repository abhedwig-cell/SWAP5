module mod_fmr_signed_divdra_runtime_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_frost_divdra_drainage_effect, only: partition_single_level_signed_divdra, FROST_DIVDRA_OK
  implicit none
  private

  integer, parameter, public :: FMR_SIGNED_DIVDRA_BIND_OK = 0
  integer, parameter, public :: FMR_SIGNED_DIVDRA_BIND_TARGET_ALREADY_BOUND = 1
  integer, parameter, public :: FMR_SIGNED_DIVDRA_BIND_PROCESS_REJECTED = 2
  integer, parameter, public :: FMR_SIGNED_DIVDRA_BIND_INVALID_PROCESS_RESULT = 3

  type, public :: fmr_signed_divdra_binding_diagnostics_t
    integer :: status = FMR_SIGNED_DIVDRA_BIND_OK
    integer :: process_status = FROST_DIVDRA_OK
    logical :: process_evaluated = .false.
    logical :: published = .false.
    integer :: drainage_levels = 0
    integer :: active_nodes = 0
    logical :: separate_infiltration = .false.
    real(real64) :: authoritative_scalar_transfer = 0.0_real64
    real(real64) :: closure_correction = 0.0_real64
  end type fmr_signed_divdra_binding_diagnostics_t

  public :: fmr_bind_single_level_signed_divdra

contains

  subroutine fmr_bind_single_level_signed_divdra(parameters, hydraulic_view, scalar_transfer, &
       separate_infiltration, surface_water_level_cm, infiltration_depth_factor, &
       drainage_flux_by_level, diagnostics)
    type(drainage_distribution_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(in) :: scalar_transfer
    logical, intent(in) :: separate_infiltration
    real(real64), intent(in) :: surface_water_level_cm, infiltration_depth_factor
    real(real64), allocatable, intent(inout) :: drainage_flux_by_level(:,:)
    type(fmr_signed_divdra_binding_diagnostics_t), intent(out) :: diagnostics

    real(real64), allocatable :: nodal(:)
    real(real64) :: correction
    integer :: process_status, n

    diagnostics = fmr_signed_divdra_binding_diagnostics_t()
    diagnostics%authoritative_scalar_transfer = scalar_transfer
    diagnostics%separate_infiltration = separate_infiltration

    if (allocated(drainage_flux_by_level)) then
      diagnostics%status = FMR_SIGNED_DIVDRA_BIND_TARGET_ALREADY_BOUND
      return
    end if

    call partition_single_level_signed_divdra(parameters, hydraulic_view%groundwater_level, scalar_transfer, &
         separate_infiltration, surface_water_level_cm, infiltration_depth_factor, nodal, correction, process_status)

    diagnostics%process_status = process_status
    diagnostics%process_evaluated = .true.
    diagnostics%closure_correction = correction
    if (process_status /= FROST_DIVDRA_OK) then
      diagnostics%status = FMR_SIGNED_DIVDRA_BIND_PROCESS_REJECTED
      return
    end if

    n = parameters%active_nodes
    if (n <= 0 .or. .not. allocated(nodal)) then
      diagnostics%status = FMR_SIGNED_DIVDRA_BIND_INVALID_PROCESS_RESULT
      return
    end if
    if (size(nodal) /= n) then
      diagnostics%status = FMR_SIGNED_DIVDRA_BIND_INVALID_PROCESS_RESULT
      return
    end if

    allocate(drainage_flux_by_level(1,n))
    drainage_flux_by_level(1,:) = nodal
    diagnostics%status = FMR_SIGNED_DIVDRA_BIND_OK
    diagnostics%published = .true.
    diagnostics%drainage_levels = 1
    diagnostics%active_nodes = n
  end subroutine fmr_bind_single_level_signed_divdra

end module mod_fmr_signed_divdra_runtime_binding

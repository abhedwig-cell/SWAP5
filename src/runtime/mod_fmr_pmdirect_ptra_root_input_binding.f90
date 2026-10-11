module mod_fmr_pmdirect_ptra_root_input_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, &
       CROP_ROOT_INPUT_OK
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_interval_result_t, pmdirect_swetr0_diagnostics_t, &
       PMDIRECT_SWETR0_OK
  implicit none
  private

  integer, parameter, public :: FMR_PMDIRECT_PTRA_ROOT_BINDING_OK = 0
  integer, parameter, public :: FMR_PMDIRECT_PTRA_ROOT_UPSTREAM_REJECTED = 1
  integer, parameter, public :: FMR_PMDIRECT_PTRA_ROOT_INVALID_ROOT_GEOMETRY = 2
  integer, parameter, public :: FMR_PMDIRECT_PTRA_ROOT_INVALID_PTRA = 3
  integer, parameter, public :: FMR_PMDIRECT_PTRA_ROOT_ASSEMBLED_INPUT_REJECTED = 4

  type, public :: fmr_pmdirect_ptra_root_binding_diagnostics_t
    integer :: status = FMR_PMDIRECT_PTRA_ROOT_BINDING_OK
    integer :: upstream_status = PMDIRECT_SWETR0_OK
    integer :: root_geometry_status = CROP_ROOT_INPUT_OK
    integer :: assembled_input_status = CROP_ROOT_INPUT_OK
    logical :: upstream_result_accepted = .false.
    logical :: incoming_ptra_ignored = .false.
    logical :: inactive_crop_zero_applied = .false.
    logical :: ptra_bound = .false.
    logical :: result_produced = .false.
  end type fmr_pmdirect_ptra_root_binding_diagnostics_t

  public :: fmr_bind_pmdirect_ptra_to_root_input

contains

  subroutine fmr_bind_pmdirect_ptra_to_root_input(base_input, active_nodes, pmdirect_result, pmdirect_diagnostics, &
                                                   bound_input, diagnostics)
    type(crop_root_uptake_input_t), intent(in) :: base_input
    integer, intent(in) :: active_nodes
    type(pmdirect_swetr0_interval_result_t), intent(in) :: pmdirect_result
    type(pmdirect_swetr0_diagnostics_t), intent(in) :: pmdirect_diagnostics
    type(crop_root_uptake_input_t), intent(out) :: bound_input
    type(fmr_pmdirect_ptra_root_binding_diagnostics_t), intent(out) :: diagnostics

    type(crop_root_uptake_input_t) :: geometry_input
    real(real64) :: ptra
    integer :: contract_status

    bound_input = crop_root_uptake_input_t()
    diagnostics = fmr_pmdirect_ptra_root_binding_diagnostics_t()
    diagnostics%upstream_status = pmdirect_diagnostics%status

    if (pmdirect_diagnostics%status /= PMDIRECT_SWETR0_OK .or. &
        .not. pmdirect_diagnostics%interval_result_produced) then
      diagnostics%status = FMR_PMDIRECT_PTRA_ROOT_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_result_accepted = .true.

    ptra = pmdirect_result%potential_transpiration_cm_per_day
    if (.not. ieee_is_finite(ptra)) then
      diagnostics%status = FMR_PMDIRECT_PTRA_ROOT_INVALID_PTRA
      return
    end if
    if (ptra < 0.0_real64) then
      diagnostics%status = FMR_PMDIRECT_PTRA_ROOT_INVALID_PTRA
      return
    end if

    ! The incoming crop/root object owns emergence and root geometry, not the
    ! potential-transpiration demand. Validate only that geometry by replacing
    ! its transport value with the canonical neutral value first.
    geometry_input = base_input
    geometry_input%potential_transpiration = 0.0_real64
    diagnostics%incoming_ptra_ignored = .true.

    call validate_crop_root_uptake_input(geometry_input, active_nodes, contract_status)
    diagnostics%root_geometry_status = contract_status
    if (contract_status /= CROP_ROOT_INPUT_OK) then
      diagnostics%status = FMR_PMDIRECT_PTRA_ROOT_INVALID_ROOT_GEOMETRY
      return
    end if

    bound_input = geometry_input

    ! crop_root_uptake_input_t defines the non-emerged route canonically with
    ! exactly zero potential transpiration and no root geometry. PMdirect can
    ! retain round-off-scale atmospheric canopy demand outside that route; it
    ! must not be promoted into an inactive crop/root contract.
    if (.not. bound_input%crop_emerged) then
      diagnostics%inactive_crop_zero_applied = .true.
    else
      bound_input%potential_transpiration = ptra
      diagnostics%ptra_bound = .true.
    end if

    call validate_crop_root_uptake_input(bound_input, active_nodes, contract_status)
    diagnostics%assembled_input_status = contract_status
    if (contract_status /= CROP_ROOT_INPUT_OK) then
      bound_input = crop_root_uptake_input_t()
      diagnostics%ptra_bound = .false.
      diagnostics%inactive_crop_zero_applied = .false.
      diagnostics%status = FMR_PMDIRECT_PTRA_ROOT_ASSEMBLED_INPUT_REJECTED
      return
    end if

    diagnostics%result_produced = .true.
  end subroutine fmr_bind_pmdirect_ptra_to_root_input

end module mod_fmr_pmdirect_ptra_root_input_binding

module mod_crop_root_uptake_input_assembly
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, &
       CROP_ROOT_INPUT_OK, CROP_ROOT_INPUT_NONFINITE_PTRA, CROP_ROOT_INPUT_NEGATIVE_PTRA
  implicit none
  private

  integer, parameter, public :: CROP_ROOT_ASSEMBLY_OK = 0
  integer, parameter, public :: CROP_ROOT_ASSEMBLY_INVALID_ACTIVE_NODES = 1
  integer, parameter, public :: CROP_ROOT_ASSEMBLY_INVALID_SNAPSHOT = 2
  integer, parameter, public :: CROP_ROOT_ASSEMBLY_INVALID_ET_RESULT = 3
  integer, parameter, public :: CROP_ROOT_ASSEMBLY_OUTPUT_REJECTED = 4

  type, public :: crop_root_state_view_t
    logical :: crop_emerged = .false.
    integer :: rooted_nodes = 0
    real(real64), allocatable :: cumulative_root_fraction(:)
  end type crop_root_state_view_t

  type, public :: root_uptake_et_result_t
    real(real64) :: potential_transpiration = 0.0_real64
  end type root_uptake_et_result_t

  type, public :: crop_root_uptake_assembly_diagnostics_t
    integer :: status = CROP_ROOT_ASSEMBLY_OK
    integer :: crop_contract_status = CROP_ROOT_INPUT_OK
    logical :: snapshot_validated = .false.
    logical :: et_result_consumed = .false.
    logical :: assembled = .false.
  end type crop_root_uptake_assembly_diagnostics_t

  public :: validate_crop_root_state_view
  public :: assemble_crop_root_uptake_input

contains

  subroutine validate_crop_root_state_view(snapshot, active_nodes, status, crop_contract_status)
    type(crop_root_state_view_t), intent(in) :: snapshot
    integer, intent(in) :: active_nodes
    integer, intent(out) :: status
    integer, intent(out), optional :: crop_contract_status

    type(crop_root_uptake_input_t) :: probe
    integer :: contract_status

    status = CROP_ROOT_ASSEMBLY_OK
    contract_status = CROP_ROOT_INPUT_OK

    if (active_nodes <= 0) then
      status = CROP_ROOT_ASSEMBLY_INVALID_ACTIVE_NODES
      if (present(crop_contract_status)) crop_contract_status = contract_status
      return
    end if

    probe%crop_emerged = snapshot%crop_emerged
    probe%potential_transpiration = 0.0_real64
    probe%rooted_nodes = snapshot%rooted_nodes
    if (allocated(snapshot%cumulative_root_fraction)) then
      allocate(probe%cumulative_root_fraction(size(snapshot%cumulative_root_fraction)))
      probe%cumulative_root_fraction = snapshot%cumulative_root_fraction
    end if

    call validate_crop_root_uptake_input(probe, active_nodes, contract_status)
    if (present(crop_contract_status)) crop_contract_status = contract_status
    if (contract_status /= CROP_ROOT_INPUT_OK) status = CROP_ROOT_ASSEMBLY_INVALID_SNAPSHOT
  end subroutine validate_crop_root_state_view

  subroutine assemble_crop_root_uptake_input(snapshot, et_result, active_nodes, input, diagnostics)
    type(crop_root_state_view_t), intent(in) :: snapshot
    type(root_uptake_et_result_t), intent(in) :: et_result
    integer, intent(in) :: active_nodes
    type(crop_root_uptake_input_t), intent(out) :: input
    type(crop_root_uptake_assembly_diagnostics_t), intent(out) :: diagnostics

    integer :: status, contract_status

    input = crop_root_uptake_input_t()
    diagnostics = crop_root_uptake_assembly_diagnostics_t()

    call validate_crop_root_state_view(snapshot, active_nodes, status, contract_status)
    diagnostics%crop_contract_status = contract_status
    if (status /= CROP_ROOT_ASSEMBLY_OK) then
      diagnostics%status = status
      return
    end if
    diagnostics%snapshot_validated = .true.

    ! The inactive route is intentionally independent of ET. This preserves the
    ! already-qualified no-crop/no-root dependency-free path.
    if (.not. snapshot%crop_emerged) then
      diagnostics%assembled = .true.
      return
    end if

    diagnostics%et_result_consumed = .true.
    input%crop_emerged = .true.
    input%potential_transpiration = et_result%potential_transpiration
    input%rooted_nodes = snapshot%rooted_nodes
    if (allocated(snapshot%cumulative_root_fraction)) then
      allocate(input%cumulative_root_fraction(size(snapshot%cumulative_root_fraction)))
      input%cumulative_root_fraction = snapshot%cumulative_root_fraction
    end if

    call validate_crop_root_uptake_input(input, active_nodes, contract_status)
    diagnostics%crop_contract_status = contract_status
    if (contract_status /= CROP_ROOT_INPUT_OK) then
      if (contract_status == CROP_ROOT_INPUT_NONFINITE_PTRA .or. &
          contract_status == CROP_ROOT_INPUT_NEGATIVE_PTRA) then
        diagnostics%status = CROP_ROOT_ASSEMBLY_INVALID_ET_RESULT
      else
        diagnostics%status = CROP_ROOT_ASSEMBLY_OUTPUT_REJECTED
      end if
      input = crop_root_uptake_input_t()
      return
    end if

    diagnostics%assembled = .true.
  end subroutine assemble_crop_root_uptake_input

end module mod_crop_root_uptake_input_assembly

module mod_groundwater_multiswap_types
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_diagnostics_t
  use mod_groundwater_coupling_contract, only: groundwater_interface_state_t, groundwater_interface_residual_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_snapshot_t
  use mod_groundwater_tile_aggregation, only: groundwater_cell_exchange_t
  implicit none
  private

  integer, parameter, public :: GW_MULTI_OK = 0
  integer, parameter, public :: GW_MULTI_INVALID_REQUEST = 1
  integer, parameter, public :: GW_MULTI_INVALID_ORIGIN = 2
  integer, parameter, public :: GW_MULTI_SWAP_CHECKPOINT_FAILED = 3
  integer, parameter, public :: GW_MULTI_GROUNDWATER_CHECKPOINT_FAILED = 4
  integer, parameter, public :: GW_MULTI_PREDICTOR_FORCING_FAILED = 5
  integer, parameter, public :: GW_MULTI_PREDICTOR_SWAP_FAILED = 6
  integer, parameter, public :: GW_MULTI_PREDICTOR_AGGREGATION_FAILED = 7
  integer, parameter, public :: GW_MULTI_PREDICTOR_GROUNDWATER_FAILED = 8
  integer, parameter, public :: GW_MULTI_PREDICTOR_DISCARD_FAILED = 9
  integer, parameter, public :: GW_MULTI_CORRECTOR_FORCING_FAILED = 10
  integer, parameter, public :: GW_MULTI_CORRECTOR_SWAP_FAILED = 11
  integer, parameter, public :: GW_MULTI_CORRECTOR_AGGREGATION_FAILED = 12
  integer, parameter, public :: GW_MULTI_CORRECTOR_GROUNDWATER_FAILED = 13
  integer, parameter, public :: GW_MULTI_INTERFACE_FAILED = 14
  integer, parameter, public :: GW_MULTI_NOT_CONVERGED = 15
  integer, parameter, public :: GW_MULTI_LEDGER_STAGE_FAILED = 16
  integer, parameter, public :: GW_MULTI_GROUNDWATER_PREPARE_FAILED = 17
  integer, parameter, public :: GW_MULTI_LEDGER_PREPARE_FAILED = 18
  integer, parameter, public :: GW_MULTI_PUBLICATION_PREFLIGHT_FAILED = 19
  integer, parameter, public :: GW_MULTI_SWAP_COMMIT_FAILED = 20
  integer, parameter, public :: GW_MULTI_PREPUBLICATION_ABORT_FAILED = 21

  type, public :: groundwater_direct_tile_binding_t
    integer(int64) :: groundwater_cell_id = 0_int64
    integer(int64) :: tile_id = 0_int64
    real(real64) :: area_fraction = 0.0_real64
  contains
    procedure, public :: valid => groundwater_direct_tile_binding_valid
  end type groundwater_direct_tile_binding_t

  type, public :: groundwater_multiswap_diagnostics_t
    character(len=48) :: route = 'not-run'
    character(len=64) :: failure_stage = 'none'
    integer :: failing_tile_index = 0
    integer :: groundwater_status = 0
    integer :: aggregation_status = 0
    integer :: interface_status = 0
    integer :: policy_status = 0
    logical :: predictor_groundwater_completed = .false.
    logical :: corrector_groundwater_completed = .false.
    logical :: head_converged = .false.
    logical :: groundwater_prepared = .false.
    logical :: publication_preflight_passed = .false.
    logical :: groundwater_committed = .false.
    type(kernel_diagnostics_t), allocatable :: predictor_swap(:)
    type(kernel_diagnostics_t), allocatable :: corrector_swap(:)
    integer, allocatable :: ledger_status(:)
    logical, allocatable :: ledger_prepared(:)
    logical, allocatable :: swap_committed(:)
    logical, allocatable :: ledger_committed(:)
  end type groundwater_multiswap_diagnostics_t

  type, public :: groundwater_multiswap_result_t
    integer :: status = GW_MULTI_INVALID_REQUEST
    logical :: completed = .false.
    logical :: committed = .false.
    logical :: request_smaller_window = .false.
    integer(int64) :: groundwater_cell_id = 0_int64
    real(real64) :: predictor_h_groundwater_m = 0.0_real64
    real(real64) :: prescribed_corrector_h_swap_m = 0.0_real64
    real(real64) :: corrector_h_groundwater_m = 0.0_real64
    real(real64) :: accepted_cell_exchange_m = 0.0_real64
    real(real64) :: committed_ledger_increment_m = 0.0_real64
    type(groundwater_cell_exchange_t) :: predictor_aggregate
    type(groundwater_cell_exchange_t) :: corrector_aggregate
    type(groundwater_interface_state_t) :: accepted_interface
    type(groundwater_interface_residual_t) :: residual
    real(real64), allocatable :: tile_weighted_exchange_m(:)
    type(groundwater_interface_mass_snapshot_t), allocatable :: ledger_snapshots(:)
    type(groundwater_multiswap_diagnostics_t) :: diagnostics
  end type groundwater_multiswap_result_t

contains

  pure logical function groundwater_direct_tile_binding_valid(self) result(valid)
    class(groundwater_direct_tile_binding_t), intent(in) :: self

    valid = .false.
    if (self%groundwater_cell_id <= 0_int64) return
    if (self%tile_id <= 0_int64) return
    if (.not. ieee_is_finite(self%area_fraction)) return
    if (self%area_fraction <= 0.0_real64 .or. self%area_fraction > 1.0_real64) return
    valid = .true.
  end function groundwater_direct_tile_binding_valid

end module mod_groundwater_multiswap_types

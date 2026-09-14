module mod_groundwater_coupled_restart
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, &
       KERNEL_PERSISTENCE_SCHEMA_VERSION, KERNEL_PERSISTENCE_OK, export_kernel_committed_state, &
       reconstruct_kernel_persistence_snapshot_trusted, restore_kernel_committed_state
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       groundwater_exchange_checkpoint_t, groundwater_capture_checkpoint, GW_EXCHANGE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, groundwater_interface_mass_restart_record_t, &
       GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  implicit none
  private

  integer, parameter, public :: GW_COUPLED_RESTART_SCHEMA_VERSION = 1
  integer, parameter, public :: GW_COUPLED_RESTART_OK = 0
  integer, parameter, public :: GW_COUPLED_RESTART_INVALID_SOURCE = 1
  integer, parameter, public :: GW_COUPLED_RESTART_INVALID_ORIGIN = 2
  integer, parameter, public :: GW_COUPLED_RESTART_SWAP_REJECTED = 3
  integer, parameter, public :: GW_COUPLED_RESTART_GROUNDWATER_REJECTED = 4
  integer, parameter, public :: GW_COUPLED_RESTART_LEDGER_REJECTED = 5
  integer, parameter, public :: GW_COUPLED_RESTART_PROVENANCE_MISMATCH = 6
  integer, parameter, public :: GW_COUPLED_RESTART_SCHEMA_MISMATCH = 7
  integer, parameter, public :: GW_COUPLED_RESTART_INVALID_RECORD = 8
  integer, parameter, public :: GW_COUPLED_RESTART_TARGET_NOT_FRESH = 9
  integer, parameter, public :: GW_COUPLED_RESTART_ADAPTER_REJECTED = 10

  ! Backend-specific committed continuation state. The runtime never parses this
  ! object and defines no file, byte or path semantics. A concrete groundwater
  ! adapter owns both the state type and any external serializer used across a
  ! process boundary.
  type, abstract, public :: groundwater_restart_state_t
  contains
    procedure(gw_restart_state_clone_ifc), deferred, public :: clone
    procedure(gw_restart_state_valid_ifc), deferred, public :: valid
  end type groundwater_restart_state_t

  ! Adapter is deliberately separate from the exchange service. Runtime/coupler
  ! composition binds both to the same backend instance. This keeps persistence
  ! capability opt-in and does not burden non-coupled or non-restartable services.
  ! Restore callbacks must be atomic with respect to their fresh backend target:
  ! on nonzero status they may not publish a partially restored committed state.
  type, abstract, public :: groundwater_restart_adapter_t
  contains
    procedure(gw_restart_adapter_export_ifc), deferred, public :: export_committed
    procedure(gw_restart_adapter_restore_ifc), deferred, public :: restore_committed
  end type groundwater_restart_adapter_t

  type, public :: groundwater_committed_restart_record_t
    integer :: schema_version = 0
    integer(int64) :: service_id = 0_int64
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: revision = -1_int64
    real(real64) :: committed_time = 0.0_real64
    class(groundwater_restart_state_t), allocatable :: backend_state
  end type groundwater_committed_restart_record_t

  ! Serialization-neutral coupled accepted-boundary record. Only committed
  ! physical continuation and provenance survive. Checkpoints, candidates,
  ! prepared handles, Newton state, Jacobians and worker scratch are absent.
  type, public :: groundwater_coupled_restart_record_t
    integer :: schema_version = 0
    integer :: swap_kernel_schema_version = 0
    integer(int64) :: swap_layout_id = 0_int64
    integer(int64) :: swap_lineage_id = 0_int64
    integer(int64) :: swap_revision = -1_int64
    real(real64) :: accepted_time = 0.0_real64
    class(transaction_state_t), allocatable :: swap_physical_state
    type(groundwater_committed_restart_record_t) :: groundwater
    type(groundwater_interface_mass_restart_record_t) :: ledger
    type(groundwater_coupling_origin_t) :: origin
  end type groundwater_coupled_restart_record_t

  public :: groundwater_export_committed_restart
  public :: groundwater_restore_committed_restart
  public :: export_groundwater_coupled_restart
  public :: restore_groundwater_coupled_restart

  abstract interface
    subroutine gw_restart_state_clone_ifc(self, copy)
      import :: groundwater_restart_state_t
      class(groundwater_restart_state_t), intent(in) :: self
      class(groundwater_restart_state_t), allocatable, intent(out) :: copy
    end subroutine gw_restart_state_clone_ifc

    logical function gw_restart_state_valid_ifc(self) result(valid)
      import :: groundwater_restart_state_t
      class(groundwater_restart_state_t), intent(in) :: self
    end function gw_restart_state_valid_ifc

    subroutine gw_restart_adapter_export_ifc(self, service_id, lineage_id, revision, committed_time, state, status)
      import :: groundwater_restart_adapter_t, groundwater_restart_state_t, int64, real64
      class(groundwater_restart_adapter_t), intent(inout) :: self
      integer(int64), intent(out) :: service_id, lineage_id, revision
      real(real64), intent(out) :: committed_time
      class(groundwater_restart_state_t), allocatable, intent(out) :: state
      integer, intent(out) :: status
    end subroutine gw_restart_adapter_export_ifc

    subroutine gw_restart_adapter_restore_ifc(self, service_id, lineage_id, revision, committed_time, state, status)
      import :: groundwater_restart_adapter_t, groundwater_restart_state_t, int64, real64
      class(groundwater_restart_adapter_t), intent(inout) :: self
      integer(int64), intent(in) :: service_id, lineage_id, revision
      real(real64), intent(in) :: committed_time
      class(groundwater_restart_state_t), intent(in) :: state
      integer, intent(out) :: status
    end subroutine gw_restart_adapter_restore_ifc
  end interface

contains

  subroutine groundwater_export_committed_restart(service, adapter, record, exported, status)
    class(groundwater_preparable_exchange_service_t), intent(inout) :: service
    class(groundwater_restart_adapter_t), intent(inout) :: adapter
    type(groundwater_committed_restart_record_t), intent(out) :: record
    logical, intent(out) :: exported
    integer, intent(out) :: status

    type(groundwater_exchange_checkpoint_t) :: checkpoint
    class(groundwater_restart_state_t), allocatable :: state
    integer(int64) :: service_id, lineage_id, revision
    real(real64) :: committed_time, checkpoint_time
    logical :: checkpoint_time_available
    integer :: exchange_status, adapter_status

    record = groundwater_committed_restart_record_t()
    exported = .false.
    status = GW_COUPLED_RESTART_GROUNDWATER_REJECTED

    call groundwater_capture_checkpoint(service, checkpoint, exchange_status)
    if (exchange_status /= GW_EXCHANGE_OK .or. .not. checkpoint%ready()) return
    call checkpoint%origin_time(checkpoint_time, checkpoint_time_available)
    if (.not. checkpoint_time_available) return

    service_id = 0_int64
    lineage_id = 0_int64
    revision = -1_int64
    committed_time = 0.0_real64
    call adapter%export_committed(service_id, lineage_id, revision, committed_time, state, adapter_status)
    if (adapter_status /= 0) then
      status = GW_COUPLED_RESTART_ADAPTER_REJECTED
      return
    end if
    if (.not. allocated(state)) return
    if (.not. state%valid()) return
    if (service_id <= 0_int64 .or. lineage_id <= 0_int64 .or. revision < 0_int64) return
    if (.not. ieee_is_finite(committed_time)) return

    status = GW_COUPLED_RESTART_PROVENANCE_MISMATCH
    if (service_id /= checkpoint%service_id()) return
    if (lineage_id /= checkpoint%lineage_id()) return
    if (revision /= checkpoint%origin_revision()) return
    if (.not. same_time(committed_time, checkpoint_time)) return

    record%schema_version = GW_COUPLED_RESTART_SCHEMA_VERSION
    record%service_id = service_id
    record%lineage_id = lineage_id
    record%revision = revision
    record%committed_time = committed_time
    call state%clone(record%backend_state)
    if (.not. allocated(record%backend_state)) then
      record = groundwater_committed_restart_record_t()
      status = GW_COUPLED_RESTART_GROUNDWATER_REJECTED
      return
    end if
    if (.not. record%backend_state%valid()) then
      record = groundwater_committed_restart_record_t()
      status = GW_COUPLED_RESTART_GROUNDWATER_REJECTED
      return
    end if

    exported = .true.
    status = GW_COUPLED_RESTART_OK
  end subroutine groundwater_export_committed_restart

  subroutine groundwater_restore_committed_restart(record, service, adapter, restored, status)
    type(groundwater_committed_restart_record_t), intent(in) :: record
    class(groundwater_preparable_exchange_service_t), intent(inout) :: service
    class(groundwater_restart_adapter_t), intent(inout) :: adapter
    logical, intent(out) :: restored
    integer, intent(out) :: status

    type(groundwater_exchange_checkpoint_t) :: checkpoint
    real(real64) :: checkpoint_time
    logical :: checkpoint_time_available
    integer :: adapter_status, exchange_status

    restored = .false.
    status = GW_COUPLED_RESTART_SCHEMA_MISMATCH
    if (record%schema_version /= GW_COUPLED_RESTART_SCHEMA_VERSION) return

    status = GW_COUPLED_RESTART_INVALID_RECORD
    if (record%service_id <= 0_int64 .or. record%lineage_id <= 0_int64 .or. record%revision < 0_int64) return
    if (.not. ieee_is_finite(record%committed_time)) return
    if (.not. allocated(record%backend_state)) return
    if (.not. record%backend_state%valid()) return

    call adapter%restore_committed(record%service_id, record%lineage_id, record%revision, &
         record%committed_time, record%backend_state, adapter_status)
    if (adapter_status /= 0) then
      status = GW_COUPLED_RESTART_ADAPTER_REJECTED
      return
    end if

    call groundwater_capture_checkpoint(service, checkpoint, exchange_status)
    if (exchange_status /= GW_EXCHANGE_OK .or. .not. checkpoint%ready()) then
      status = GW_COUPLED_RESTART_GROUNDWATER_REJECTED
      return
    end if
    call checkpoint%origin_time(checkpoint_time, checkpoint_time_available)
    if (.not. checkpoint_time_available) then
      status = GW_COUPLED_RESTART_GROUNDWATER_REJECTED
      return
    end if
    status = GW_COUPLED_RESTART_PROVENANCE_MISMATCH
    if (checkpoint%service_id() /= record%service_id) return
    if (checkpoint%lineage_id() /= record%lineage_id) return
    if (checkpoint%origin_revision() /= record%revision) return
    if (.not. same_time(checkpoint_time, record%committed_time)) return

    restored = .true.
    status = GW_COUPLED_RESTART_OK
  end subroutine groundwater_restore_committed_restart

  subroutine export_groundwater_coupled_restart(committed, swap_layout_id, groundwater, groundwater_restart, &
       ledger, origin, record, exported, status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: swap_layout_id
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    class(groundwater_restart_adapter_t), intent(inout) :: groundwater_restart
    type(groundwater_interface_mass_ledger_t), intent(in) :: ledger
    type(groundwater_coupling_origin_t), intent(in) :: origin
    type(groundwater_coupled_restart_record_t), intent(out) :: record
    logical, intent(out) :: exported
    integer, intent(out) :: status

    type(groundwater_coupled_restart_record_t) :: candidate
    type(kernel_persistence_snapshot_t) :: swap_snapshot
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    real(real64) :: swap_time
    logical :: ok, time_available, groundwater_ok
    integer :: kernel_status, ledger_status, groundwater_status

    record = groundwater_coupled_restart_record_t()
    exported = .false.
    status = GW_COUPLED_RESTART_INVALID_SOURCE
    if (.not. committed%ready()) return
    if (swap_layout_id <= 0_int64) return
    if (.not. origin%finite_and_structurally_valid()) then
      status = GW_COUPLED_RESTART_INVALID_ORIGIN
      return
    end if

    call ledger%snapshot(ledger_snapshot)
    if (.not. ledger_snapshot%available .or. .not. ledger_snapshot%identity_bound) then
      status = GW_COUPLED_RESTART_LEDGER_REJECTED
      return
    end if
    if (ledger_snapshot%trial_active .or. ledger_snapshot%prepared_active) then
      status = GW_COUPLED_RESTART_LEDGER_REJECTED
      return
    end if
    if (transfer(ledger_snapshot%conservation_residual_m, 0_int64) /= transfer(0.0_real64, 0_int64)) then
      status = GW_COUPLED_RESTART_LEDGER_REJECTED
      return
    end if
    call ledger%export_committed_restart(candidate%ledger, ledger_status)
    if (ledger_status /= GW_MASS_LEDGER_OK) then
      status = GW_COUPLED_RESTART_LEDGER_REJECTED
      return
    end if

    call export_kernel_committed_state(committed, swap_layout_id, swap_snapshot, ok, kernel_status)
    if (.not. ok .or. kernel_status /= KERNEL_PERSISTENCE_OK) then
      status = GW_COUPLED_RESTART_SWAP_REJECTED
      return
    end if
    if (.not. swap_snapshot%time_is_bound()) then
      status = GW_COUPLED_RESTART_SWAP_REJECTED
      return
    end if
    call swap_snapshot%current_time(swap_time, time_available)
    if (.not. time_available .or. .not. ieee_is_finite(swap_time)) then
      status = GW_COUPLED_RESTART_SWAP_REJECTED
      return
    end if
    candidate%swap_kernel_schema_version = swap_snapshot%schema_version()
    candidate%swap_layout_id = swap_snapshot%layout_id()
    candidate%swap_lineage_id = swap_snapshot%current_lineage_id()
    candidate%swap_revision = swap_snapshot%current_revision()
    candidate%accepted_time = swap_time
    call swap_snapshot%snapshot_physical(candidate%swap_physical_state, ok)
    if (.not. ok .or. .not. allocated(candidate%swap_physical_state)) then
      status = GW_COUPLED_RESTART_SWAP_REJECTED
      return
    end if

    call groundwater_export_committed_restart(groundwater, groundwater_restart, candidate%groundwater, &
         groundwater_ok, groundwater_status)
    if (.not. groundwater_ok .or. groundwater_status /= GW_COUPLED_RESTART_OK) then
      status = groundwater_status
      return
    end if

    status = GW_COUPLED_RESTART_PROVENANCE_MISMATCH
    if (candidate%swap_lineage_id /= origin%swap_lineage_id) return
    if (candidate%swap_revision /= origin%swap_revision) return
    if (candidate%groundwater%service_id /= origin%groundwater_service_id) return
    if (candidate%groundwater%lineage_id /= origin%groundwater_lineage_id) return
    if (candidate%groundwater%revision /= origin%groundwater_revision) return
    if (.not. same_time(candidate%accepted_time, origin%accepted_time)) return
    if (.not. same_time(candidate%groundwater%committed_time, origin%accepted_time)) return

    candidate%schema_version = GW_COUPLED_RESTART_SCHEMA_VERSION
    candidate%origin = origin
    record = candidate
    exported = .true.
    status = GW_COUPLED_RESTART_OK
  end subroutine export_groundwater_coupled_restart

  subroutine restore_groundwater_coupled_restart(record, expected_swap_layout_id, committed, groundwater, &
       groundwater_restart, ledger, origin, restored, status)
    type(groundwater_coupled_restart_record_t), intent(in) :: record
    integer(int64), intent(in) :: expected_swap_layout_id
    type(kernel_committed_state_t), intent(inout) :: committed
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    class(groundwater_restart_adapter_t), intent(inout) :: groundwater_restart
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledger
    type(groundwater_coupling_origin_t), intent(inout) :: origin
    logical, intent(out) :: restored
    integer, intent(out) :: status

    type(kernel_persistence_snapshot_t) :: swap_snapshot
    type(kernel_committed_state_t) :: swap_candidate
    type(groundwater_interface_mass_ledger_t) :: ledger_candidate
    type(groundwater_interface_mass_snapshot_t) :: target_ledger_snapshot, restored_ledger_snapshot
    logical :: reconstructed, swap_restored, groundwater_restored
    integer :: kernel_status, ledger_status, groundwater_status

    restored = .false.
    status = GW_COUPLED_RESTART_TARGET_NOT_FRESH
    if (committed%ready()) return
    if (origin%initialized) return
    call ledger%snapshot(target_ledger_snapshot)
    if (.not. target_ledger_snapshot%available) return
    if (target_ledger_snapshot%identity_bound) return
    if (target_ledger_snapshot%trial_active .or. target_ledger_snapshot%prepared_active) return
    if (target_ledger_snapshot%committed_exchange_count /= 0 .or. target_ledger_snapshot%discarded_trial_count /= 0) return
    if (target_ledger_snapshot%committed_swap_outward_exchange_m /= 0.0_real64) return

    status = GW_COUPLED_RESTART_SCHEMA_MISMATCH
    if (record%schema_version /= GW_COUPLED_RESTART_SCHEMA_VERSION) return
    if (record%swap_kernel_schema_version /= KERNEL_PERSISTENCE_SCHEMA_VERSION) return

    status = GW_COUPLED_RESTART_INVALID_RECORD
    if (expected_swap_layout_id <= 0_int64 .or. record%swap_layout_id /= expected_swap_layout_id) return
    if (record%swap_lineage_id <= 0_int64 .or. record%swap_revision < 0_int64) return
    if (.not. ieee_is_finite(record%accepted_time)) return
    if (.not. allocated(record%swap_physical_state)) return
    if (.not. record%origin%finite_and_structurally_valid()) return
    if (.not. coupled_record_provenance_valid(record)) then
      status = GW_COUPLED_RESTART_PROVENANCE_MISMATCH
      return
    end if

    call reconstruct_kernel_persistence_snapshot_trusted(record%swap_kernel_schema_version, record%swap_layout_id, &
         record%swap_lineage_id, record%swap_revision, record%accepted_time, .true., record%swap_physical_state, &
         swap_snapshot, reconstructed, kernel_status)
    if (.not. reconstructed .or. kernel_status /= KERNEL_PERSISTENCE_OK) then
      status = GW_COUPLED_RESTART_SWAP_REJECTED
      return
    end if
    call restore_kernel_committed_state(swap_snapshot, expected_swap_layout_id, swap_candidate, swap_restored, &
         kernel_status, KERNEL_PERSISTENCE_SCHEMA_VERSION)
    if (.not. swap_restored .or. kernel_status /= KERNEL_PERSISTENCE_OK) then
      status = GW_COUPLED_RESTART_SWAP_REJECTED
      return
    end if

    call ledger_candidate%restore_committed_restart(record%ledger, ledger_status)
    if (ledger_status /= GW_MASS_LEDGER_OK) then
      status = GW_COUPLED_RESTART_LEDGER_REJECTED
      return
    end if
    call ledger_candidate%snapshot(restored_ledger_snapshot)
    if (.not. restored_ledger_snapshot%available .or. .not. restored_ledger_snapshot%identity_bound) then
      status = GW_COUPLED_RESTART_LEDGER_REJECTED
      return
    end if
    if (restored_ledger_snapshot%trial_active .or. restored_ledger_snapshot%prepared_active) then
      status = GW_COUPLED_RESTART_LEDGER_REJECTED
      return
    end if
    if (transfer(restored_ledger_snapshot%conservation_residual_m, 0_int64) /= transfer(0.0_real64, 0_int64)) then
      status = GW_COUPLED_RESTART_LEDGER_REJECTED
      return
    end if

    call groundwater_restore_committed_restart(record%groundwater, groundwater, groundwater_restart, &
         groundwater_restored, groundwater_status)
    if (.not. groundwater_restored .or. groundwater_status /= GW_COUPLED_RESTART_OK) then
      status = groundwater_status
      return
    end if

    ! Publish local validated SWAP and ledger candidates only after the external
    ! groundwater restore has completed and its service provenance was re-read.
    ! The origin is published last, so no coupled continuation can observe a
    ! partially assembled accepted boundary.
    committed = swap_candidate
    ledger = ledger_candidate
    origin = record%origin
    restored = .true.
    status = GW_COUPLED_RESTART_OK
  end subroutine restore_groundwater_coupled_restart

  logical function coupled_record_provenance_valid(record) result(valid)
    type(groundwater_coupled_restart_record_t), intent(in) :: record

    valid = .false.
    if (record%groundwater%schema_version /= GW_COUPLED_RESTART_SCHEMA_VERSION) return
    if (record%ledger%schema_version <= 0 .or. .not. record%ledger%available) return
    if (record%swap_lineage_id /= record%origin%swap_lineage_id) return
    if (record%swap_revision /= record%origin%swap_revision) return
    if (record%groundwater%service_id /= record%origin%groundwater_service_id) return
    if (record%groundwater%lineage_id /= record%origin%groundwater_lineage_id) return
    if (record%groundwater%revision /= record%origin%groundwater_revision) return
    if (.not. same_time(record%accepted_time, record%origin%accepted_time)) return
    if (.not. same_time(record%groundwater%committed_time, record%origin%accepted_time)) return
    if (.not. allocated(record%groundwater%backend_state)) return
    if (.not. record%groundwater%backend_state%valid()) return
    valid = .true.
  end function coupled_record_provenance_valid

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

end module mod_groundwater_coupled_restart

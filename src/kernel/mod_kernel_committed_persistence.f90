module mod_kernel_committed_persistence
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reconstruct_committed_state_trusted, &
       KERNEL_TRUSTED_RECONSTRUCTION_OK, KERNEL_TRUSTED_RECONSTRUCTION_INVALID_PROVENANCE, &
       KERNEL_TRUSTED_RECONSTRUCTION_INVALID_PHYSICAL, KERNEL_TRUSTED_RECONSTRUCTION_INVALID_TIME
  implicit none
  private

  integer, parameter, public :: KERNEL_PERSISTENCE_SCHEMA_VERSION = 1

  integer, parameter, public :: KERNEL_PERSISTENCE_OK = 0
  integer, parameter, public :: KERNEL_PERSISTENCE_INVALID_SOURCE = 1
  integer, parameter, public :: KERNEL_PERSISTENCE_INVALID_LAYOUT = 2
  integer, parameter, public :: KERNEL_PERSISTENCE_INVALID_CARRIER = 3
  integer, parameter, public :: KERNEL_PERSISTENCE_SCHEMA_MISMATCH = 4
  integer, parameter, public :: KERNEL_PERSISTENCE_LAYOUT_MISMATCH = 5
  integer, parameter, public :: KERNEL_PERSISTENCE_TARGET_ALREADY_INITIALIZED = 6
  integer, parameter, public :: KERNEL_PERSISTENCE_RESTORE_VALIDATION_FAILED = 7
  integer, parameter, public :: KERNEL_PERSISTENCE_INVALID_PROVENANCE = 8
  integer, parameter, public :: KERNEL_PERSISTENCE_INVALID_PHYSICAL_STATE = 9
  integer, parameter, public :: KERNEL_PERSISTENCE_INVALID_TIME = 10
  integer, parameter, public :: KERNEL_PERSISTENCE_RECONSTRUCTION_FAILED = 11

  ! Serialization-neutral, opaque committed-boundary persistence carrier.
  ! It contains only the already-committed continuation state and provenance.
  ! There is deliberately no file, path, byte-format or solver-scratch state.
  !
  ! The contained kernel_committed_state_t remains opaque: callers cannot set
  ! lineage or revision independently. A trusted adapter may reconstruct this
  ! typed boundary atomically from one fully decoded provenance record plus one
  ! physical continuation state. Parsing and byte-level encoding remain outside
  ! F-KT and outside this module.
  type, public :: kernel_persistence_snapshot_t
    private
    type(kernel_committed_state_t) :: committed_copy
    integer(int64) :: layout_id_value = 0_int64
    integer :: schema_version_value = 0
    logical :: valid = .false.
  contains
    procedure, public :: ready => kernel_persistence_ready
    procedure, public :: schema_version => get_persistence_schema_version
    procedure, public :: layout_id => kernel_persistence_layout_id
    procedure, public :: current_lineage_id => kernel_persistence_lineage_id
    procedure, public :: current_revision => kernel_persistence_revision
    procedure, public :: current_time => kernel_persistence_current_time
    procedure, public :: time_is_bound => kernel_persistence_time_is_bound
    procedure, public :: snapshot_physical => kernel_persistence_snapshot_physical
  end type kernel_persistence_snapshot_t

  public :: export_kernel_committed_state
  public :: reconstruct_kernel_persistence_snapshot_trusted
  public :: restore_kernel_committed_state

contains

  subroutine export_kernel_committed_state(committed, layout_id, snapshot, exported, status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: layout_id
    type(kernel_persistence_snapshot_t), intent(out) :: snapshot
    logical, intent(out) :: exported
    integer, intent(out) :: status

    snapshot = kernel_persistence_snapshot_t()
    exported = .false.
    status = KERNEL_PERSISTENCE_INVALID_SOURCE
    if (.not. committed%ready()) return

    status = KERNEL_PERSISTENCE_INVALID_LAYOUT
    if (layout_id <= 0_int64) return

    ! Intrinsic whole-object assignment deep-copies the allocatable physical
    ! continuation state while preserving F-KT-private provenance fields.
    ! No raw lineage/revision constructor is exposed.
    snapshot%committed_copy = committed
    if (.not. snapshot%committed_copy%ready()) then
      snapshot = kernel_persistence_snapshot_t()
      status = KERNEL_PERSISTENCE_RESTORE_VALIDATION_FAILED
      return
    end if

    snapshot%layout_id_value = layout_id
    snapshot%schema_version_value = KERNEL_PERSISTENCE_SCHEMA_VERSION
    snapshot%valid = .true.
    exported = .true.
    status = KERNEL_PERSISTENCE_OK
  end subroutine export_kernel_committed_state

  ! Trusted adapter bridge. The adapter must already have parsed and validated
  ! its external representation and decoded the concrete physical state. This
  ! routine only reconstructs one atomic committed record and then routes it
  ! through the normal F-KT12 export path. It never performs I/O and never
  ! exposes an independent revision, lineage or time setter.
  subroutine reconstruct_kernel_persistence_snapshot_trusted(schema_version, layout_id, lineage_id, revision, &
       committed_time, time_bound, decoded_physical_state, snapshot, reconstructed, status)
    integer, intent(in) :: schema_version
    integer(int64), intent(in) :: layout_id
    integer(int64), intent(in) :: lineage_id
    integer(int64), intent(in) :: revision
    real(real64), intent(in) :: committed_time
    logical, intent(in) :: time_bound
    class(transaction_state_t), allocatable, intent(in) :: decoded_physical_state
    type(kernel_persistence_snapshot_t), intent(out) :: snapshot
    logical, intent(out) :: reconstructed
    integer, intent(out) :: status
    type(kernel_committed_state_t) :: committed_candidate
    logical :: committed_ok, exported
    integer :: reconstruction_status, export_status

    snapshot = kernel_persistence_snapshot_t()
    reconstructed = .false.

    status = KERNEL_PERSISTENCE_SCHEMA_MISMATCH
    if (schema_version /= KERNEL_PERSISTENCE_SCHEMA_VERSION) return

    status = KERNEL_PERSISTENCE_INVALID_LAYOUT
    if (layout_id <= 0_int64) return

    call kernel_reconstruct_committed_state_trusted(committed_candidate, lineage_id, revision, decoded_physical_state, &
         committed_time, time_bound, committed_ok, reconstruction_status)
    if (.not. committed_ok) then
      select case (reconstruction_status)
      case (KERNEL_TRUSTED_RECONSTRUCTION_INVALID_PROVENANCE)
        status = KERNEL_PERSISTENCE_INVALID_PROVENANCE
      case (KERNEL_TRUSTED_RECONSTRUCTION_INVALID_PHYSICAL)
        status = KERNEL_PERSISTENCE_INVALID_PHYSICAL_STATE
      case (KERNEL_TRUSTED_RECONSTRUCTION_INVALID_TIME)
        status = KERNEL_PERSISTENCE_INVALID_TIME
      case default
        status = KERNEL_PERSISTENCE_RECONSTRUCTION_FAILED
      end select
      return
    end if

    call export_kernel_committed_state(committed_candidate, layout_id, snapshot, exported, export_status)
    if (.not. exported) then
      snapshot = kernel_persistence_snapshot_t()
      status = KERNEL_PERSISTENCE_RECONSTRUCTION_FAILED
      return
    end if
    if (export_status /= KERNEL_PERSISTENCE_OK) then
      snapshot = kernel_persistence_snapshot_t()
      status = KERNEL_PERSISTENCE_RECONSTRUCTION_FAILED
      return
    end if
    if (.not. snapshot%ready()) then
      snapshot = kernel_persistence_snapshot_t()
      status = KERNEL_PERSISTENCE_RECONSTRUCTION_FAILED
      return
    end if

    reconstructed = .true.
    status = KERNEL_PERSISTENCE_OK
  end subroutine reconstruct_kernel_persistence_snapshot_trusted

  subroutine restore_kernel_committed_state(snapshot, expected_layout_id, committed, restored, status, &
       expected_schema_version)
    type(kernel_persistence_snapshot_t), intent(in) :: snapshot
    integer(int64), intent(in) :: expected_layout_id
    type(kernel_committed_state_t), intent(inout) :: committed
    logical, intent(out) :: restored
    integer, intent(out) :: status
    integer, intent(in), optional :: expected_schema_version
    type(kernel_committed_state_t) :: candidate
    integer :: required_schema
    real(real64) :: source_time, candidate_time
    logical :: source_time_available, candidate_time_available

    restored = .false.

    ! Restore is creation of a runtime committed object, not rollback. An
    ! already-initialized authoritative carrier can never be overwritten.
    status = KERNEL_PERSISTENCE_TARGET_ALREADY_INITIALIZED
    if (committed%ready()) return

    status = KERNEL_PERSISTENCE_INVALID_CARRIER
    if (.not. snapshot%ready()) return

    required_schema = KERNEL_PERSISTENCE_SCHEMA_VERSION
    if (present(expected_schema_version)) required_schema = expected_schema_version
    status = KERNEL_PERSISTENCE_SCHEMA_MISMATCH
    if (required_schema /= KERNEL_PERSISTENCE_SCHEMA_VERSION) return
    if (snapshot%schema_version_value /= required_schema) return

    status = KERNEL_PERSISTENCE_LAYOUT_MISMATCH
    if (expected_layout_id <= 0_int64) return
    if (snapshot%layout_id_value /= expected_layout_id) return

    candidate = snapshot%committed_copy
    status = KERNEL_PERSISTENCE_RESTORE_VALIDATION_FAILED
    if (.not. candidate%ready()) return
    if (candidate%current_lineage_id() /= snapshot%committed_copy%current_lineage_id()) return
    if (candidate%current_revision() /= snapshot%committed_copy%current_revision()) return
    if (candidate%time_is_bound() .neqv. snapshot%committed_copy%time_is_bound()) return
    call snapshot%committed_copy%current_time(source_time, source_time_available)
    call candidate%current_time(candidate_time, candidate_time_available)
    if (source_time_available .neqv. candidate_time_available) return
    if (source_time_available) then
      if (transfer(source_time, 0_int64) /= transfer(candidate_time, 0_int64)) return
    end if

    committed = candidate
    if (.not. committed%ready()) return
    if (committed%current_lineage_id() /= snapshot%current_lineage_id()) return
    if (committed%current_revision() /= snapshot%current_revision()) return
    if (committed%time_is_bound() .neqv. snapshot%time_is_bound()) return

    restored = .true.
    status = KERNEL_PERSISTENCE_OK
  end subroutine restore_kernel_committed_state

  logical function kernel_persistence_ready(self) result(is_ready)
    class(kernel_persistence_snapshot_t), intent(in) :: self

    ! Keep impure type-bound validation calls explicitly ordered. Fortran does
    ! not guarantee short-circuit evaluation of logical expressions, and O2
    ! must not be allowed to eliminate a validation call that O0 evaluates.
    is_ready = .false.
    if (.not. self%valid) return
    if (self%schema_version_value /= KERNEL_PERSISTENCE_SCHEMA_VERSION) return
    if (self%layout_id_value <= 0_int64) return
    if (.not. self%committed_copy%ready()) return
    is_ready = .true.
  end function kernel_persistence_ready

  integer function get_persistence_schema_version(self) result(value)
    class(kernel_persistence_snapshot_t), intent(in) :: self
    if (self%ready()) then
      value = self%schema_version_value
    else
      value = 0
    end if
  end function get_persistence_schema_version

  integer(int64) function kernel_persistence_layout_id(self) result(value)
    class(kernel_persistence_snapshot_t), intent(in) :: self
    if (self%ready()) then
      value = self%layout_id_value
    else
      value = 0_int64
    end if
  end function kernel_persistence_layout_id

  integer(int64) function kernel_persistence_lineage_id(self) result(value)
    class(kernel_persistence_snapshot_t), intent(in) :: self
    if (self%ready()) then
      value = self%committed_copy%current_lineage_id()
    else
      value = 0_int64
    end if
  end function kernel_persistence_lineage_id

  integer(int64) function kernel_persistence_revision(self) result(value)
    class(kernel_persistence_snapshot_t), intent(in) :: self
    if (self%ready()) then
      value = self%committed_copy%current_revision()
    else
      value = -1_int64
    end if
  end function kernel_persistence_revision

  subroutine kernel_persistence_current_time(self, value, available)
    class(kernel_persistence_snapshot_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available

    value = 0.0_real64
    available = .false.
    if (.not. self%ready()) return
    call self%committed_copy%current_time(value, available)
  end subroutine kernel_persistence_current_time

  logical function kernel_persistence_time_is_bound(self) result(is_bound)
    class(kernel_persistence_snapshot_t), intent(in) :: self

    is_bound = .false.
    if (.not. self%ready()) return
    is_bound = self%committed_copy%time_is_bound()
  end function kernel_persistence_time_is_bound

  subroutine kernel_persistence_snapshot_physical(self, copy, available)
    class(kernel_persistence_snapshot_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    logical, intent(out) :: available

    available = self%ready()
    if (.not. available) return
    call self%committed_copy%snapshot(copy, available)
  end subroutine kernel_persistence_snapshot_physical

end module mod_kernel_committed_persistence

module mod_fmr_committed_restart
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, &
       KERNEL_PERSISTENCE_SCHEMA_VERSION, KERNEL_PERSISTENCE_OK, &
       export_kernel_committed_state, reconstruct_kernel_persistence_snapshot_trusted, &
       restore_kernel_committed_state
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  implicit none
  private

  integer, parameter, public :: FMR_RESTART_SCHEMA_VERSION = 1
  integer, parameter, public :: FMR_RESTART_OK = 0
  integer, parameter, public :: FMR_RESTART_INVALID_STRUCTURE = 1
  integer, parameter, public :: FMR_RESTART_DUPLICATE_COLUMN = 2
  integer, parameter, public :: FMR_RESTART_COLUMN_NOT_FOUND = 3
  integer, parameter, public :: FMR_RESTART_TEMPLATE_MISMATCH = 4
  integer, parameter, public :: FMR_RESTART_PARAMETER_MISMATCH = 5
  integer, parameter, public :: FMR_RESTART_STATE_NOT_COMMITTED = 6
  integer, parameter, public :: FMR_RESTART_KERNEL_PERSISTENCE_REJECTED = 7
  integer, parameter, public :: FMR_RESTART_TARGET_ALREADY_INITIALIZED = 8
  integer, parameter, public :: FMR_RESTART_SCHEMA_MISMATCH = 9

  ! Adapter-facing, serialization-neutral decoded continuation record.
  !
  ! This is not a file format and it does not define byte-level persistence.
  ! The runtime adapter may encode/decode an equivalent representation outside
  ! the kernel.  Physical committed continuation state is deliberately kept
  ! separate from stable runtime identity.  Immutable parameter data, forcing,
  ! solver/Newton/Jacobian scratch and worker warm starts are not components.
  type, public :: fmr_committed_restart_record_t
    integer :: schema_version = 0
    integer :: kernel_schema_version = 0
    integer(int64) :: column_id = 0_int64
    integer(int64) :: parameter_ref = 0_int64
    type(fmr_template_t) :: template_identity
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: revision = -1_int64
    real(real64) :: committed_time = 0.0_real64
    logical :: time_bound = .false.
    class(transaction_state_t), allocatable :: physical_state
  end type fmr_committed_restart_record_t

  public :: fmr_export_committed_restart
  public :: fmr_restore_committed_restart
  public :: fmr_restart_template_identity_matches

contains

  subroutine fmr_export_committed_restart(columns, templates, state_registry, records, exported, status)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(kernel_committed_state_t), intent(in) :: state_registry(:)
    type(fmr_committed_restart_record_t), allocatable, intent(out) :: records(:)
    logical, intent(out) :: exported
    integer, intent(out) :: status

    type(fmr_committed_restart_record_t), allocatable :: candidate_records(:)
    type(kernel_persistence_snapshot_t) :: snapshot
    integer :: i, template_index, state_index, kernel_status
    logical :: ok, time_available
    real(real64) :: time_value

    exported = .false.
    status = FMR_RESTART_INVALID_STRUCTURE
    if (.not. registry_structure_valid(columns, templates, state_registry)) return

    allocate(candidate_records(size(columns)))
    do i = 1, size(columns)
      template_index = find_template_index(columns(i)%template_id, templates)
      if (template_index == 0) then
        status = FMR_RESTART_TEMPLATE_MISMATCH
        return
      end if
      if (columns(i)%parameter_ref <= 0_int64) then
        status = FMR_RESTART_INVALID_STRUCTURE
        return
      end if
      if (columns(i)%backend_id /= templates(template_index)%compatible_backend_id) then
        status = FMR_RESTART_TEMPLATE_MISMATCH
        return
      end if

      state_index = int(columns(i)%state_handle)
      if (.not. state_registry(state_index)%ready()) then
        status = FMR_RESTART_STATE_NOT_COMMITTED
        return
      end if

      call export_kernel_committed_state(state_registry(state_index), &
           templates(template_index)%state_layout_id, snapshot, ok, kernel_status)
      if (.not. ok .or. kernel_status /= KERNEL_PERSISTENCE_OK) then
        status = FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
        return
      end if

      candidate_records(i)%schema_version = FMR_RESTART_SCHEMA_VERSION
      candidate_records(i)%kernel_schema_version = snapshot%schema_version()
      candidate_records(i)%column_id = columns(i)%column_id
      candidate_records(i)%parameter_ref = columns(i)%parameter_ref
      candidate_records(i)%template_identity = templates(template_index)
      candidate_records(i)%lineage_id = snapshot%current_lineage_id()
      candidate_records(i)%revision = snapshot%current_revision()
      candidate_records(i)%time_bound = snapshot%time_is_bound()
      call snapshot%current_time(time_value, time_available)
      if (time_available .neqv. candidate_records(i)%time_bound) then
        status = FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
        return
      end if
      if (time_available) candidate_records(i)%committed_time = time_value
      call snapshot%snapshot_physical(candidate_records(i)%physical_state, ok)
      if (.not. ok .or. .not. allocated(candidate_records(i)%physical_state)) then
        status = FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
        return
      end if
    end do

    call move_alloc(candidate_records, records)
    exported = .true.
    status = FMR_RESTART_OK
  end subroutine fmr_export_committed_restart

  subroutine fmr_restore_committed_restart(records, columns, templates, state_registry, restored, status)
    type(fmr_committed_restart_record_t), intent(in) :: records(:)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    logical, intent(out) :: restored
    integer, intent(out) :: status

    type(kernel_committed_state_t), allocatable :: candidate_states(:)
    type(kernel_persistence_snapshot_t) :: snapshot
    integer :: i, record_index, template_index, state_index, kernel_status
    logical :: ok

    restored = .false.
    status = FMR_RESTART_INVALID_STRUCTURE
    if (.not. registry_structure_valid(columns, templates, state_registry, allow_uninitialized=.true.)) return
    if (size(records) /= size(columns)) return
    if (.not. records_have_unique_positive_columns(records)) then
      status = FMR_RESTART_DUPLICATE_COLUMN
      return
    end if
    do i = 1, size(state_registry)
      if (state_registry(i)%ready()) then
        status = FMR_RESTART_TARGET_ALREADY_INITIALIZED
        return
      end if
    end do

    allocate(candidate_states(size(state_registry)))
    do i = 1, size(columns)
      record_index = find_record_index(columns(i)%column_id, records)
      if (record_index == 0) then
        status = FMR_RESTART_COLUMN_NOT_FOUND
        return
      end if
      if (records(record_index)%schema_version /= FMR_RESTART_SCHEMA_VERSION .or. &
          records(record_index)%kernel_schema_version /= KERNEL_PERSISTENCE_SCHEMA_VERSION) then
        status = FMR_RESTART_SCHEMA_MISMATCH
        return
      end if

      template_index = find_template_index(columns(i)%template_id, templates)
      if (template_index == 0) then
        status = FMR_RESTART_TEMPLATE_MISMATCH
        return
      end if
      if (.not. fmr_restart_template_identity_matches(records(record_index)%template_identity, &
                                                       templates(template_index))) then
        status = FMR_RESTART_TEMPLATE_MISMATCH
        return
      end if
      if (columns(i)%template_id /= records(record_index)%template_identity%template_id .or. &
          columns(i)%backend_id /= records(record_index)%template_identity%compatible_backend_id) then
        status = FMR_RESTART_TEMPLATE_MISMATCH
        return
      end if
      if (columns(i)%parameter_ref /= records(record_index)%parameter_ref) then
        status = FMR_RESTART_PARAMETER_MISMATCH
        return
      end if
      if (.not. allocated(records(record_index)%physical_state)) then
        status = FMR_RESTART_STATE_NOT_COMMITTED
        return
      end if

      call reconstruct_kernel_persistence_snapshot_trusted( &
           records(record_index)%kernel_schema_version, &
           records(record_index)%template_identity%state_layout_id, &
           records(record_index)%lineage_id, records(record_index)%revision, &
           records(record_index)%committed_time, records(record_index)%time_bound, &
           records(record_index)%physical_state, snapshot, ok, kernel_status)
      if (.not. ok .or. kernel_status /= KERNEL_PERSISTENCE_OK) then
        status = FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
        return
      end if

      state_index = int(columns(i)%state_handle)
      call restore_kernel_committed_state(snapshot, templates(template_index)%state_layout_id, &
           candidate_states(state_index), ok, kernel_status, KERNEL_PERSISTENCE_SCHEMA_VERSION)
      if (.not. ok .or. kernel_status /= KERNEL_PERSISTENCE_OK) then
        status = FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
        return
      end if
    end do

    ! Atomic publication: no target state is changed until every record and
    ! every identity check has succeeded.  Intrinsic assignment deep-copies the
    ! committed physical continuation states into the fresh runtime registry.
    state_registry = candidate_states
    restored = .true.
    status = FMR_RESTART_OK
  end subroutine fmr_restore_committed_restart

  logical function fmr_restart_template_identity_matches(left, right) result(matches)
    type(fmr_template_t), intent(in) :: left, right

    matches = left%template_id == right%template_id .and. &
         left%physics_topology_id == right%physics_topology_id .and. &
         left%vertical_layout_id == right%vertical_layout_id .and. &
         left%state_layout_id == right%state_layout_id .and. &
         left%solver_interface_id == right%solver_interface_id .and. &
         left%optional_state_layout_id == right%optional_state_layout_id .and. &
         left%numerical_continuation_layout_id == right%numerical_continuation_layout_id .and. &
         left%compatible_backend_id == right%compatible_backend_id
  end function fmr_restart_template_identity_matches

  logical function registry_structure_valid(columns, templates, states, allow_uninitialized) result(valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    logical, intent(in), optional :: allow_uninitialized
    logical, allocatable :: state_claimed(:)
    logical :: permit_uninitialized
    integer :: i, j, state_index

    valid = .false.
    permit_uninitialized = .false.
    if (present(allow_uninitialized)) permit_uninitialized = allow_uninitialized
    if (size(columns) /= size(states)) return
    if (size(columns) == 0 .or. size(templates) == 0) return

    do i = 1, size(templates)
      if (templates(i)%template_id <= 0_int64) return
      if (templates(i)%state_layout_id <= 0_int64) return
      if (templates(i)%compatible_backend_id <= 0) return
      do j = i + 1, size(templates)
        if (templates(j)%template_id == templates(i)%template_id) return
      end do
    end do

    allocate(state_claimed(size(states)))
    state_claimed = .false.
    do i = 1, size(columns)
      if (columns(i)%column_id <= 0_int64) return
      do j = i + 1, size(columns)
        if (columns(j)%column_id == columns(i)%column_id) return
      end do
      if (columns(i)%state_handle < 1_int64 .or. columns(i)%state_handle > int(size(states), int64)) return
      state_index = int(columns(i)%state_handle)
      if (state_claimed(state_index)) return
      state_claimed(state_index) = .true.
      if (.not. permit_uninitialized .and. .not. states(state_index)%ready()) return
    end do
    if (.not. all(state_claimed)) return
    valid = .true.
  end function registry_structure_valid

  logical function records_have_unique_positive_columns(records) result(valid)
    type(fmr_committed_restart_record_t), intent(in) :: records(:)
    integer :: i, j

    valid = .false.
    do i = 1, size(records)
      if (records(i)%column_id <= 0_int64) return
      do j = i + 1, size(records)
        if (records(j)%column_id == records(i)%column_id) return
      end do
    end do
    valid = .true.
  end function records_have_unique_positive_columns

  integer function find_template_index(template_id, templates) result(index)
    integer(int64), intent(in) :: template_id
    type(fmr_template_t), intent(in) :: templates(:)
    integer :: i

    index = 0
    do i = 1, size(templates)
      if (templates(i)%template_id == template_id) then
        index = i
        return
      end if
    end do
  end function find_template_index

  integer function find_record_index(column_id, records) result(index)
    integer(int64), intent(in) :: column_id
    type(fmr_committed_restart_record_t), intent(in) :: records(:)
    integer :: i

    index = 0
    do i = 1, size(records)
      if (records(i)%column_id == column_id) then
        index = i
        return
      end if
    end do
  end function find_record_index

end module mod_fmr_committed_restart

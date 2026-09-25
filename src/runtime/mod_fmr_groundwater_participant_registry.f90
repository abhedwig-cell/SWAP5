module mod_fmr_groundwater_participant_registry
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_serialized_reference_backend_t
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, &
       GW_SWAP_PARTICIPANT_OK, GW_SWAP_PARTICIPANT_INVALID_REQUEST
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  implicit none
  private

  integer, parameter, public :: FMR_GW_REGISTRY_OK = 0
  integer, parameter, public :: FMR_GW_REGISTRY_NOT_INITIALIZED = 1
  integer, parameter, public :: FMR_GW_REGISTRY_INVALID_REQUEST = 2
  integer, parameter, public :: FMR_GW_REGISTRY_CAPACITY_EXHAUSTED = 3
  integer, parameter, public :: FMR_GW_REGISTRY_DUPLICATE_TILE = 4
  integer, parameter, public :: FMR_GW_REGISTRY_INVALID_HANDLE = 5
  integer, parameter, public :: FMR_GW_REGISTRY_HANDLE_EXHAUSTED = 6
  integer, parameter, public :: FMR_GW_REGISTRY_PARTICIPANT_FAILED = 7
  integer, parameter, public :: FMR_GW_REGISTRY_RELEASE_BUSY = 8
  integer, parameter, public :: FMR_GW_REGISTRY_REINITIALIZE_BUSY = 9

  type :: fmr_groundwater_participant_slot_t
    logical :: used = .false.
    logical :: active = .false.
    integer(int64) :: handle_id = 0_int64
    integer(int64) :: tile_id = 0_int64
    type(fmr_groundwater_swap_participant_t) :: participant
    type(fmr_serialized_reference_backend_t), pointer :: backend => null()
    type(fmr_b110_physical_parameters_t), pointer :: parameters => null()
    type(kernel_committed_state_t), pointer :: committed => null()
    type(fmr_groundwater_head_forcing_materializer_t), pointer :: materializer => null()
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_head_datum_t) :: datum
    logical :: immutable_parameters = .false.
  end type fmr_groundwater_participant_slot_t

  type, public :: fmr_groundwater_participant_registry_t
    private
    type(fmr_groundwater_participant_slot_t), allocatable :: slots(:)
    integer(int64) :: next_handle = 1_int64
    logical :: initialized = .false.
  contains
    procedure, public :: initialize => registry_initialize
    procedure, public :: bind => registry_bind
    procedure, public :: release => registry_release
    procedure, public :: capture_origin => registry_capture_origin
    procedure, public :: trial_from_origin => registry_trial_from_origin
    procedure, public :: discard_candidate => registry_discard_candidate
    procedure, public :: abandon_origin => registry_abandon_origin
    procedure, public :: publication_ready => registry_publication_ready
    procedure, public :: commit_candidate => registry_commit_candidate
    procedure, public :: identity => registry_identity
    procedure, public :: active_count => registry_active_count
    procedure, public :: capacity => registry_capacity
    procedure, public :: quiescent => registry_quiescent
  end type fmr_groundwater_participant_registry_t

contains

  subroutine registry_initialize(self, capacity, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer, intent(in) :: capacity
    integer, intent(out) :: status

    status = FMR_GW_REGISTRY_INVALID_REQUEST
    if (capacity <= 0) return

    if (allocated(self%slots)) then
      if (any(self%slots%active)) then
        status = FMR_GW_REGISTRY_REINITIALIZE_BUSY
        return
      end if
      deallocate(self%slots)
    end if

    allocate(self%slots(capacity))
    self%initialized = .true.
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_initialize

  subroutine registry_bind(self, tile_id, backend, column, template, parameters, committed, materializer, &
       numerical, datum, handle, status, immutable_parameters)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: tile_id
    type(fmr_serialized_reference_backend_t), target, intent(inout) :: backend
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), target, intent(in) :: parameters
    type(kernel_committed_state_t), target, intent(inout) :: committed
    type(fmr_groundwater_head_forcing_materializer_t), target, intent(in) :: materializer
    type(canonical_numerical_config_t), intent(in) :: numerical
    type(groundwater_head_datum_t), intent(in) :: datum
    integer(int64), intent(out) :: handle
    integer, intent(out) :: status
    logical, intent(in), optional :: immutable_parameters

    integer :: i, slot

    handle = 0_int64
    status = FMR_GW_REGISTRY_NOT_INITIALIZED
    if (.not. self%initialized .or. .not. allocated(self%slots)) return

    status = FMR_GW_REGISTRY_INVALID_REQUEST
    if (tile_id <= 0_int64) return
    if (column%column_id /= tile_id) return
    if (column%template_id /= template%template_id) return
    if (.not. committed%ready()) return
    if (.not. datum%valid()) return
    if (.not. materializer%profile_admitted(parameters)) return

    do i = 1, size(self%slots)
      if (.not. self%slots(i)%active) cycle
      if (self%slots(i)%tile_id == tile_id) then
        status = FMR_GW_REGISTRY_DUPLICATE_TILE
        return
      end if
    end do

    slot = 0
    do i = 1, size(self%slots)
      if (.not. self%slots(i)%used) then
        slot = i
        exit
      end if
    end do
    if (slot <= 0) then
      status = FMR_GW_REGISTRY_CAPACITY_EXHAUSTED
      return
    end if

    if (self%next_handle <= 0_int64 .or. self%next_handle == huge(0_int64)) then
      status = FMR_GW_REGISTRY_HANDLE_EXHAUSTED
      return
    end if

    self%slots(slot)%used = .true.
    self%slots(slot)%active = .true.
    self%slots(slot)%handle_id = self%next_handle
    self%slots(slot)%tile_id = tile_id
    self%slots(slot)%backend => backend
    self%slots(slot)%parameters => parameters
    self%slots(slot)%committed => committed
    self%slots(slot)%materializer => materializer
    self%slots(slot)%column = column
    self%slots(slot)%template = template
    self%slots(slot)%numerical = numerical
    self%slots(slot)%datum = datum
    self%slots(slot)%immutable_parameters = .false.
    if (present(immutable_parameters)) self%slots(slot)%immutable_parameters = immutable_parameters

    handle = self%next_handle
    self%next_handle = self%next_handle + 1_int64
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_bind

  subroutine registry_release(self, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    integer :: idx

    call resolve_handle(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return

    if (self%slots(idx)%participant%has_live_candidate()) then
      status = FMR_GW_REGISTRY_RELEASE_BUSY
      return
    end if

    self%slots(idx)%active = .false.
    nullify(self%slots(idx)%backend)
    nullify(self%slots(idx)%parameters)
    nullify(self%slots(idx)%committed)
    nullify(self%slots(idx)%materializer)
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_release

  subroutine registry_capture_origin(self, handle, participant_status, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: participant_status
    integer, intent(out) :: status

    integer :: idx

    participant_status = GW_SWAP_PARTICIPANT_INVALID_REQUEST
    call resolve_handle(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return
    if (.not. associated(self%slots(idx)%committed)) then
      status = FMR_GW_REGISTRY_INVALID_REQUEST
      return
    end if

    call self%slots(idx)%participant%capture_origin(self%slots(idx)%committed, participant_status)
    if (participant_status /= GW_SWAP_PARTICIPANT_OK) then
      status = FMR_GW_REGISTRY_PARTICIPANT_FAILED
      return
    end if
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_capture_origin

  subroutine registry_trial_from_origin(self, handle, window, prescribed_head_m, trial, participant_status, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: prescribed_head_m
    type(groundwater_swap_trial_t), intent(out) :: trial
    integer, intent(out) :: participant_status
    integer, intent(out) :: status

    integer :: idx

    trial = groundwater_swap_trial_t()
    participant_status = GW_SWAP_PARTICIPANT_INVALID_REQUEST
    call resolve_handle(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return
    if (.not. slot_associations_ready(self%slots(idx))) then
      status = FMR_GW_REGISTRY_INVALID_REQUEST
      return
    end if

    call self%slots(idx)%participant%trial_from_origin(self%slots(idx)%backend, self%slots(idx)%column, &
         self%slots(idx)%template, self%slots(idx)%parameters, self%slots(idx)%committed, &
         self%slots(idx)%materializer, self%slots(idx)%numerical, self%slots(idx)%datum, window, &
         prescribed_head_m, trial, participant_status, &
         trusted_prepared_parameters=self%slots(idx)%immutable_parameters)
    if (participant_status /= GW_SWAP_PARTICIPANT_OK) then
      status = FMR_GW_REGISTRY_PARTICIPANT_FAILED
      return
    end if
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_trial_from_origin

  subroutine registry_discard_candidate(self, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    integer :: idx

    call resolve_handle(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return
    if (.not. associated(self%slots(idx)%backend)) then
      status = FMR_GW_REGISTRY_INVALID_REQUEST
      return
    end if

    call self%slots(idx)%participant%discard_candidate(self%slots(idx)%backend)
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_discard_candidate

  subroutine registry_abandon_origin(self, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    integer :: idx, participant_status

    call resolve_handle(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return
    call self%slots(idx)%participant%abandon_origin(participant_status)
    if (participant_status /= GW_SWAP_PARTICIPANT_OK) then
      status = FMR_GW_REGISTRY_PARTICIPANT_FAILED
      return
    end if
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_abandon_origin

  subroutine registry_publication_ready(self, handle, window, ready, status)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle
    type(groundwater_coupling_window_t), intent(in) :: window
    logical, intent(out) :: ready
    integer, intent(out) :: status

    integer :: idx

    ready = .false.
    call resolve_handle_const(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return
    if (.not. associated(self%slots(idx)%committed)) then
      status = FMR_GW_REGISTRY_INVALID_REQUEST
      return
    end if

    ready = self%slots(idx)%participant%publication_ready(self%slots(idx)%committed, window)
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_publication_ready

  subroutine registry_commit_candidate(self, handle, window, did_commit, participant_status, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    type(groundwater_coupling_window_t), intent(in) :: window
    logical, intent(out) :: did_commit
    integer, intent(out) :: participant_status
    integer, intent(out) :: status

    integer :: idx

    did_commit = .false.
    participant_status = GW_SWAP_PARTICIPANT_INVALID_REQUEST
    call resolve_handle(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return
    if (.not. associated(self%slots(idx)%backend) .or. .not. associated(self%slots(idx)%committed)) then
      status = FMR_GW_REGISTRY_INVALID_REQUEST
      return
    end if

    call self%slots(idx)%participant%commit_candidate(self%slots(idx)%backend, self%slots(idx)%committed, &
         window, did_commit, participant_status)
    if (.not. did_commit .or. participant_status /= GW_SWAP_PARTICIPANT_OK) then
      did_commit = .false.
      status = FMR_GW_REGISTRY_PARTICIPANT_FAILED
      return
    end if
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_commit_candidate

  subroutine registry_identity(self, handle, tile_id, lineage_id, revision, has_origin, has_candidate, status)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle
    integer(int64), intent(out) :: tile_id, lineage_id, revision
    logical, intent(out) :: has_origin, has_candidate
    integer, intent(out) :: status

    integer :: idx

    tile_id = 0_int64
    lineage_id = 0_int64
    revision = -1_int64
    has_origin = .false.
    has_candidate = .false.

    call resolve_handle_const(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return

    tile_id = self%slots(idx)%tile_id
    has_origin = self%slots(idx)%participant%has_origin()
    has_candidate = self%slots(idx)%participant%has_live_candidate()
    if (has_origin) then
      lineage_id = self%slots(idx)%participant%captured_lineage_id()
      revision = self%slots(idx)%participant%captured_revision()
    end if
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_identity

  integer function registry_active_count(self) result(value)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self

    value = 0
    if (.not. self%initialized .or. .not. allocated(self%slots)) return
    value = count(self%slots%active)
  end function registry_active_count

  integer function registry_capacity(self) result(value)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self

    value = 0
    if (.not. allocated(self%slots)) return
    value = size(self%slots)
  end function registry_capacity

  logical function registry_quiescent(self) result(quiescent)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer :: i

    quiescent = .true.
    if (.not. self%initialized .or. .not. allocated(self%slots)) return
    do i = 1, size(self%slots)
      if (.not. self%slots(i)%active) cycle
      if (self%slots(i)%participant%has_live_candidate()) then
        quiescent = .false.
        return
      end if
    end do
  end function registry_quiescent

  subroutine resolve_handle(self, handle, idx, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: idx
    integer, intent(out) :: status

    integer :: i

    idx = 0
    status = FMR_GW_REGISTRY_NOT_INITIALIZED
    if (.not. self%initialized .or. .not. allocated(self%slots)) return
    status = FMR_GW_REGISTRY_INVALID_HANDLE
    if (handle <= 0_int64) return
    if (handle <= int(size(self%slots), int64)) then
      i = int(handle)
      if (self%slots(i)%active .and. self%slots(i)%handle_id == handle) then
        idx = i
        status = FMR_GW_REGISTRY_OK
        return
      end if
    end if
    do i = 1, size(self%slots)
      if (.not. self%slots(i)%active) cycle
      if (self%slots(i)%handle_id == handle) then
        idx = i
        status = FMR_GW_REGISTRY_OK
        return
      end if
    end do
  end subroutine resolve_handle

  subroutine resolve_handle_const(self, handle, idx, status)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: idx
    integer, intent(out) :: status

    integer :: i

    idx = 0
    status = FMR_GW_REGISTRY_NOT_INITIALIZED
    if (.not. self%initialized .or. .not. allocated(self%slots)) return
    status = FMR_GW_REGISTRY_INVALID_HANDLE
    if (handle <= 0_int64) return
    if (handle <= int(size(self%slots), int64)) then
      i = int(handle)
      if (self%slots(i)%active .and. self%slots(i)%handle_id == handle) then
        idx = i
        status = FMR_GW_REGISTRY_OK
        return
      end if
    end if
    do i = 1, size(self%slots)
      if (.not. self%slots(i)%active) cycle
      if (self%slots(i)%handle_id == handle) then
        idx = i
        status = FMR_GW_REGISTRY_OK
        return
      end if
    end do
  end subroutine resolve_handle_const

  logical function slot_associations_ready(slot) result(ready)
    type(fmr_groundwater_participant_slot_t), intent(in) :: slot

    ready = associated(slot%backend) .and. associated(slot%parameters) .and. associated(slot%committed) .and. &
         associated(slot%materializer)
  end function slot_associations_ready

end module mod_fmr_groundwater_participant_registry

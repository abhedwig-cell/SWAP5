module mod_energy_conservation_ledger
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_energy_conservation_types, only: energy_transfer_t, energy_storage_snapshot_t, energy_balance_t, &
       make_energy_transfer, make_energy_storage_snapshot, project_energy_balance, ENERGY_CONSERVATION_OK, &
       ENERGY_EXTERNAL_COMPONENT
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  implicit none
  private

  integer, parameter, public :: ENERGY_LEDGER_OK = 0
  integer, parameter, public :: ENERGY_LEDGER_INVALID_PROVENANCE = 1
  integer, parameter, public :: ENERGY_LEDGER_INVALID_INTERVAL = 2
  integer, parameter, public :: ENERGY_LEDGER_INVALID_STORAGE = 3
  integer, parameter, public :: ENERGY_LEDGER_INVALID_TRANSFER = 4
  integer, parameter, public :: ENERGY_LEDGER_TRIAL_ALREADY_ACTIVE = 5
  integer, parameter, public :: ENERGY_LEDGER_NO_ACTIVE_TRIAL = 6
  integer, parameter, public :: ENERGY_LEDGER_END_STORAGE_REQUIRED = 7
  integer, parameter, public :: ENERGY_LEDGER_ALREADY_PREPARED = 8
  integer, parameter, public :: ENERGY_LEDGER_GENERATION_EXHAUSTED = 9
  integer, parameter, public :: ENERGY_LEDGER_ACCUMULATION_FAILED = 10
  integer, parameter, public :: ENERGY_LEDGER_CAPACITY_EXHAUSTED = 11
  integer, parameter, public :: ENERGY_LEDGER_UNKNOWN_COMPONENT = 12

  type, public :: prepared_energy_trial_t
    private
    logical :: initialized = .false.
    integer(int64) :: generation = 0_int64
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    type(energy_balance_t) :: balance
  contains
    procedure, public :: ready => prepared_energy_ready
  end type prepared_energy_trial_t

  type, public :: energy_commit_record_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    type(energy_balance_t) :: balance
  contains
    procedure, public :: ready => energy_record_ready
    procedure, public :: current_lineage_id => energy_record_lineage_id
    procedure, public :: origin_revision => energy_record_origin_revision
    procedure, public :: committed_revision => energy_record_committed_revision
    procedure, public :: origin_interval => energy_record_origin_interval
    procedure, public :: conservation_balance => energy_record_balance
  end type energy_commit_record_t

  type, public :: energy_trial_ledger_t
    private
    logical :: trial_active = .false.
    logical :: end_storage_available = .false.
    logical :: prepared_active = .false.
    integer(int64) :: preparation_generation = 0_int64
    integer(int64) :: prepared_generation = 0_int64
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    integer(int64), allocatable :: component_ids(:)
    type(energy_storage_snapshot_t) :: initial_snapshot
    type(energy_storage_snapshot_t) :: final_snapshot
    type(energy_transfer_t), allocatable :: transfers(:)
    integer :: transfer_count = 0
  contains
    procedure, public :: begin_trial => energy_ledger_begin_trial
    procedure, public :: record_transfer => energy_ledger_record_transfer
    procedure, public :: set_end_storage => energy_ledger_set_end_storage
    procedure, public :: summarize_control_volume => energy_ledger_summarize_control_volume
    procedure, public :: prepare_trial => energy_ledger_prepare_trial
    procedure, public :: prepared_ready_for_receipt => energy_ledger_prepared_ready_for_receipt
    procedure, public :: commit_prepared => energy_ledger_commit_prepared
    procedure, public :: discard_trial => energy_ledger_discard_trial
    procedure, public :: abort_prepared => energy_ledger_abort_prepared
    procedure, public :: has_active_trial => energy_ledger_has_active_trial
    procedure, public :: has_prepared_trial => energy_ledger_has_prepared_trial
  end type energy_trial_ledger_t

contains

  subroutine energy_ledger_begin_trial(self, lineage_id, origin_revision, t0, t1, component_ids, initial_energy_j_m2, &
                                       status, transfer_capacity)
    class(energy_trial_ledger_t), intent(inout) :: self
    integer(int64), intent(in) :: lineage_id, origin_revision
    real(real64), intent(in) :: t0, t1
    integer(int64), intent(in) :: component_ids(:)
    real(real64), intent(in) :: initial_energy_j_m2(:)
    integer, intent(out) :: status
    integer, intent(in), optional :: transfer_capacity
    integer :: storage_status, capacity
    type(energy_storage_snapshot_t) :: snapshot

    status = ENERGY_LEDGER_ALREADY_PREPARED
    if (self%prepared_active) return
    status = ENERGY_LEDGER_TRIAL_ALREADY_ACTIVE
    if (self%trial_active) return

    status = ENERGY_LEDGER_INVALID_PROVENANCE
    if (lineage_id <= 0_int64 .or. origin_revision < 0_int64) return
    status = ENERGY_LEDGER_INVALID_INTERVAL
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return

    snapshot = make_energy_storage_snapshot(component_ids, initial_energy_j_m2, storage_status)
    status = ENERGY_LEDGER_INVALID_STORAGE
    if (storage_status /= ENERGY_CONSERVATION_OK .or. .not. snapshot%ready()) return

    capacity = max(8, size(component_ids))
    if (present(transfer_capacity)) then
      status = ENERGY_LEDGER_INVALID_TRANSFER
      if (transfer_capacity < 0) return
      capacity = max(1, transfer_capacity)
    end if

    call clear_trial_storage(self)
    allocate(self%component_ids(size(component_ids)), self%transfers(capacity))
    self%component_ids = component_ids
    self%initial_snapshot = snapshot
    self%lineage_id = lineage_id
    self%origin_revision_value = origin_revision
    self%t0_value = t0
    self%t1_value = t1
    self%transfer_count = 0
    self%end_storage_available = .false.
    self%trial_active = .true.
    status = ENERGY_LEDGER_OK
  end subroutine energy_ledger_begin_trial

  subroutine energy_ledger_record_transfer(self, source_component_id, target_component_id, amount_j_m2, status)
    class(energy_trial_ledger_t), intent(inout) :: self
    integer(int64), intent(in) :: source_component_id, target_component_id
    real(real64), intent(in) :: amount_j_m2
    integer, intent(out) :: status
    type(energy_transfer_t) :: transfer_record
    integer :: transfer_status

    status = ENERGY_LEDGER_ALREADY_PREPARED
    if (self%prepared_active) return
    status = ENERGY_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return

    transfer_record = make_energy_transfer(source_component_id, target_component_id, amount_j_m2, transfer_status)
    status = ENERGY_LEDGER_INVALID_TRANSFER
    if (transfer_status /= ENERGY_CONSERVATION_OK .or. .not. transfer_record%ready()) return

    ! Component id zero is the only explicit outside world. Every positive
    ! endpoint must belong to the registered trial snapshot. This prevents a
    ! missing internal energy store from being silently reclassified as a
    ! control-volume boundary flux in the whole-system balance.
    status = ENERGY_LEDGER_UNKNOWN_COMPONENT
    if (source_component_id /= ENERGY_EXTERNAL_COMPONENT) then
      if (.not. registered_component(self, source_component_id)) return
    end if
    if (target_component_id /= ENERGY_EXTERNAL_COMPONENT) then
      if (.not. registered_component(self, target_component_id)) return
    end if

    if (self%transfer_count >= size(self%transfers)) then
      call grow_transfer_capacity(self, status)
      if (status /= ENERGY_LEDGER_OK) return
    end if
    self%transfer_count = self%transfer_count + 1
    self%transfers(self%transfer_count) = transfer_record
    status = ENERGY_LEDGER_OK
  end subroutine energy_ledger_record_transfer

  subroutine energy_ledger_set_end_storage(self, final_energy_j_m2, status)
    class(energy_trial_ledger_t), intent(inout) :: self
    real(real64), intent(in) :: final_energy_j_m2(:)
    integer, intent(out) :: status
    integer :: storage_status
    type(energy_storage_snapshot_t) :: snapshot

    status = ENERGY_LEDGER_ALREADY_PREPARED
    if (self%prepared_active) return
    status = ENERGY_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return

    snapshot = make_energy_storage_snapshot(self%component_ids, final_energy_j_m2, storage_status)
    status = ENERGY_LEDGER_INVALID_STORAGE
    if (storage_status /= ENERGY_CONSERVATION_OK .or. .not. snapshot%ready()) return
    self%final_snapshot = snapshot
    self%end_storage_available = .true.
    status = ENERGY_LEDGER_OK
  end subroutine energy_ledger_set_end_storage

  subroutine energy_ledger_summarize_control_volume(self, control_volume_ids, balance, status)
    class(energy_trial_ledger_t), intent(in) :: self
    integer(int64), intent(in) :: control_volume_ids(:)
    type(energy_balance_t), intent(out) :: balance
    integer, intent(out) :: status
    integer :: balance_status

    balance = energy_balance_t()
    status = ENERGY_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return
    status = ENERGY_LEDGER_END_STORAGE_REQUIRED
    if (.not. self%end_storage_available) return

    call project_energy_balance(self%initial_snapshot, self%final_snapshot, self%transfers(:self%transfer_count), &
         control_volume_ids, balance, balance_status)
    status = ENERGY_LEDGER_ACCUMULATION_FAILED
    if (balance_status /= ENERGY_CONSERVATION_OK .or. .not. balance%available) return
    status = ENERGY_LEDGER_OK
  end subroutine energy_ledger_summarize_control_volume

  subroutine energy_ledger_prepare_trial(self, prepared, status)
    class(energy_trial_ledger_t), intent(inout) :: self
    type(prepared_energy_trial_t), intent(out) :: prepared
    integer, intent(out) :: status
    type(energy_balance_t) :: balance
    integer :: balance_status

    prepared = prepared_energy_trial_t()
    status = ENERGY_LEDGER_ALREADY_PREPARED
    if (self%prepared_active) return
    status = ENERGY_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return
    status = ENERGY_LEDGER_END_STORAGE_REQUIRED
    if (.not. self%end_storage_available) return
    status = ENERGY_LEDGER_GENERATION_EXHAUSTED
    if (self%preparation_generation >= huge(self%preparation_generation)) return

    call project_energy_balance(self%initial_snapshot, self%final_snapshot, self%transfers(:self%transfer_count), &
         self%component_ids, balance, balance_status)
    status = ENERGY_LEDGER_ACCUMULATION_FAILED
    if (balance_status /= ENERGY_CONSERVATION_OK .or. .not. balance%available) return

    self%prepared_generation = self%preparation_generation + 1_int64
    self%preparation_generation = self%prepared_generation
    self%prepared_active = .true.

    prepared%generation = self%prepared_generation
    prepared%lineage_id = self%lineage_id
    prepared%origin_revision_value = self%origin_revision_value
    prepared%t0_value = self%t0_value
    prepared%t1_value = self%t1_value
    prepared%balance = balance
    prepared%initialized = .true.

    call clear_trial_storage(self)
    self%trial_active = .false.
    self%end_storage_available = .false.
    status = ENERGY_LEDGER_OK
  end subroutine energy_ledger_prepare_trial

  logical function energy_ledger_prepared_ready_for_receipt(self, prepared, receipt) result(ready)
    class(energy_trial_ledger_t), intent(in) :: self
    type(prepared_energy_trial_t), intent(in) :: prepared
    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt
    real(real64) :: receipt_t0, receipt_t1
    logical :: interval_available

    ready = .false.
    if (.not. self%prepared_active .or. .not. prepared%ready() .or. .not. receipt%ready()) return
    if (prepared%generation /= self%prepared_generation) return
    if (receipt%current_lineage_id() /= prepared%lineage_id) return
    if (receipt%origin_revision() /= prepared%origin_revision_value) return
    if (receipt%committed_revision() /= prepared%origin_revision_value + 1_int64) return
    call receipt%origin_interval(receipt_t0, receipt_t1, interval_available)
    if (.not. interval_available) return
    if (.not. same_fkt_time(receipt_t0, prepared%t0_value)) return
    if (.not. same_fkt_time(receipt_t1, prepared%t1_value)) return
    ready = .true.
  end function energy_ledger_prepared_ready_for_receipt

  subroutine energy_ledger_commit_prepared(self, prepared, receipt, record)
    class(energy_trial_ledger_t), intent(inout) :: self
    type(prepared_energy_trial_t), intent(inout) :: prepared
    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt
    type(energy_commit_record_t), intent(out) :: record
    real(real64) :: receipt_t0, receipt_t1
    logical :: interval_available

    record = energy_commit_record_t()
    if (.not. self%prepared_ready_for_receipt(prepared, receipt)) then
      error stop 'energy conservation ledger prepared commit invariant violation'
    end if
    call receipt%origin_interval(receipt_t0, receipt_t1, interval_available)
    if (.not. interval_available) error stop 'energy conservation ledger receipt interval invariant violation'

    record%lineage_id = receipt%current_lineage_id()
    record%origin_revision_value = receipt%origin_revision()
    record%committed_revision_value = receipt%committed_revision()
    record%t0_value = receipt_t0
    record%t1_value = receipt_t1
    record%balance = prepared%balance
    record%initialized = .true.

    call clear_prepared(self, prepared)
  end subroutine energy_ledger_commit_prepared

  subroutine energy_ledger_discard_trial(self, status)
    class(energy_trial_ledger_t), intent(inout) :: self
    integer, intent(out) :: status

    status = ENERGY_LEDGER_ALREADY_PREPARED
    if (self%prepared_active) return
    status = ENERGY_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return
    call clear_trial_storage(self)
    self%trial_active = .false.
    self%end_storage_available = .false.
    status = ENERGY_LEDGER_OK
  end subroutine energy_ledger_discard_trial

  subroutine energy_ledger_abort_prepared(self, prepared)
    class(energy_trial_ledger_t), intent(inout) :: self
    type(prepared_energy_trial_t), intent(inout) :: prepared

    if (.not. self%prepared_active .or. .not. prepared%ready()) then
      error stop 'energy conservation ledger prepared abort invariant violation'
    end if
    if (prepared%generation /= self%prepared_generation) then
      error stop 'energy conservation ledger prepared abort generation mismatch'
    end if
    call clear_prepared(self, prepared)
  end subroutine energy_ledger_abort_prepared

  pure logical function energy_ledger_has_active_trial(self) result(active)
    class(energy_trial_ledger_t), intent(in) :: self
    active = self%trial_active
  end function energy_ledger_has_active_trial

  pure logical function energy_ledger_has_prepared_trial(self) result(active)
    class(energy_trial_ledger_t), intent(in) :: self
    active = self%prepared_active
  end function energy_ledger_has_prepared_trial

  pure logical function prepared_energy_ready(self) result(ready)
    class(prepared_energy_trial_t), intent(in) :: self
    ready = self%initialized .and. self%generation > 0_int64 .and. self%lineage_id > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. ieee_is_finite(self%t0_value) .and. &
         ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. self%balance%available
  end function prepared_energy_ready

  pure logical function energy_record_ready(self) result(ready)
    class(energy_commit_record_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         self%balance%available
  end function energy_record_ready

  pure integer(int64) function energy_record_lineage_id(self) result(value)
    class(energy_commit_record_t), intent(in) :: self
    value = self%lineage_id
  end function energy_record_lineage_id

  pure integer(int64) function energy_record_origin_revision(self) result(value)
    class(energy_commit_record_t), intent(in) :: self
    value = self%origin_revision_value
  end function energy_record_origin_revision

  pure integer(int64) function energy_record_committed_revision(self) result(value)
    class(energy_commit_record_t), intent(in) :: self
    value = self%committed_revision_value
  end function energy_record_committed_revision

  subroutine energy_record_origin_interval(self, t0, t1, available)
    class(energy_commit_record_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine energy_record_origin_interval

  subroutine energy_record_balance(self, balance, available)
    class(energy_commit_record_t), intent(in) :: self
    type(energy_balance_t), intent(out) :: balance
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      balance = self%balance
    else
      balance = energy_balance_t()
    end if
  end subroutine energy_record_balance

  pure logical function registered_component(self, component_id) result(found)
    class(energy_trial_ledger_t), intent(in) :: self
    integer(int64), intent(in) :: component_id
    integer :: i

    found = .false.
    if (.not. allocated(self%component_ids)) return
    do i = 1, size(self%component_ids)
      if (self%component_ids(i) == component_id) then
        found = .true.
        return
      end if
    end do
  end function registered_component

  subroutine grow_transfer_capacity(self, status)
    class(energy_trial_ledger_t), intent(inout) :: self
    integer, intent(out) :: status
    type(energy_transfer_t), allocatable :: grown(:)
    integer :: old_capacity, new_capacity

    status = ENERGY_LEDGER_CAPACITY_EXHAUSTED
    if (.not. allocated(self%transfers)) return
    old_capacity = size(self%transfers)
    if (old_capacity > huge(old_capacity) - max(1, old_capacity)) return
    new_capacity = old_capacity + max(1, old_capacity)
    allocate(grown(new_capacity))
    if (self%transfer_count > 0) grown(:self%transfer_count) = self%transfers(:self%transfer_count)
    call move_alloc(grown, self%transfers)
    status = ENERGY_LEDGER_OK
  end subroutine grow_transfer_capacity

  subroutine clear_trial_storage(self)
    class(energy_trial_ledger_t), intent(inout) :: self
    if (allocated(self%component_ids)) deallocate(self%component_ids)
    if (allocated(self%transfers)) deallocate(self%transfers)
    self%initial_snapshot = energy_storage_snapshot_t()
    self%final_snapshot = energy_storage_snapshot_t()
    self%transfer_count = 0
    self%lineage_id = 0_int64
    self%origin_revision_value = -1_int64
    self%t0_value = 0.0_real64
    self%t1_value = 0.0_real64
  end subroutine clear_trial_storage

  subroutine clear_prepared(self, prepared)
    class(energy_trial_ledger_t), intent(inout) :: self
    type(prepared_energy_trial_t), intent(inout) :: prepared
    self%prepared_active = .false.
    self%prepared_generation = 0_int64
    prepared = prepared_energy_trial_t()
  end subroutine clear_prepared

  pure logical function same_fkt_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_fkt_time

end module mod_energy_conservation_ledger

module mod_fmr_groundwater_participant_registry
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t
  use mod_fmr_groundwater_predictor_service, only: build_fmr_groundwater_predictor_response, FMR_GW_PREDICTOR_OK
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       groundwater_interface_state_t, groundwater_interface_lineage_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_prepared_t, groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_swap_predictor_response_t
  implicit none
  private

  integer, parameter, public :: FMR_GW_REGISTRY_OK = 0
  integer, parameter, public :: FMR_GW_REGISTRY_INVALID_CAPACITY = 1
  integer, parameter, public :: FMR_GW_REGISTRY_NOT_INITIALIZED = 2
  integer, parameter, public :: FMR_GW_REGISTRY_FULL = 3
  integer, parameter, public :: FMR_GW_REGISTRY_INVALID_CONTEXT = 4
  integer, parameter, public :: FMR_GW_REGISTRY_DUPLICATE_TILE = 5
  integer, parameter, public :: FMR_GW_REGISTRY_DUPLICATE_SWAP_LINEAGE = 6
  integer, parameter, public :: FMR_GW_REGISTRY_DUPLICATE_LEDGER = 7
  integer, parameter, public :: FMR_GW_REGISTRY_HANDLE_EXHAUSTED = 8
  integer, parameter, public :: FMR_GW_REGISTRY_UNKNOWN_HANDLE = 9
  integer, parameter, public :: FMR_GW_REGISTRY_WINDOW_ACTIVE = 10
  integer, parameter, public :: FMR_GW_REGISTRY_WINDOW_NOT_ACTIVE = 11
  integer, parameter, public :: FMR_GW_REGISTRY_PREDICTOR_FAILED = 12
  integer, parameter, public :: FMR_GW_REGISTRY_ORIGIN_FAILED = 13
  integer, parameter, public :: FMR_GW_REGISTRY_CORRECTOR_FAILED = 14
  integer, parameter, public :: FMR_GW_REGISTRY_LEDGER_FAILED = 15
  integer, parameter, public :: FMR_GW_REGISTRY_NOT_READY = 16
  integer, parameter, public :: FMR_GW_REGISTRY_COMMIT_FAILED = 17
  integer, parameter, public :: FMR_GW_REGISTRY_POST_PUBLICATION = 18
  integer, parameter, public :: FMR_GW_REGISTRY_INVALID_FRACTION = 19

  type :: fmr_groundwater_registry_entry_t
    logical :: bound = .false.
    integer(int64) :: handle = 0_int64
    integer(int64) :: tile_id = 0_int64
    integer(int64) :: swap_lineage_id = 0_int64
    integer(int64) :: ledger_id = 0_int64

    type(fmr_serialized_reference_backend_t), pointer :: predictor_backend => null()
    type(fmr_serialized_reference_backend_t), pointer :: corrector_backend => null()
    type(fmr_logical_column_t), pointer :: column => null()
    type(fmr_template_t), pointer :: template => null()
    type(fmr_b110_physical_parameters_t), pointer :: predictor_parameters => null()
    type(fmr_b110_physical_parameters_t), pointer :: corrector_parameters => null()
    type(fmr_b110_physical_forcing_t), pointer :: base_forcing => null()
    type(kernel_committed_state_t), pointer :: committed => null()
    type(fmr_groundwater_head_forcing_materializer_t), pointer :: materializer => null()
    type(canonical_numerical_config_t), pointer :: predictor_config => null()
    type(canonical_numerical_config_t), pointer :: corrector_config => null()
    type(groundwater_interface_mass_ledger_t), pointer :: ledger => null()

    type(fmr_groundwater_swap_participant_t) :: participant
    type(groundwater_swap_trial_t) :: last_trial
    type(groundwater_interface_mass_prepared_t) :: prepared_ledger
    type(groundwater_coupling_window_t) :: window
    type(groundwater_head_datum_t) :: datum
    type(modflow6_swap_predictor_lineage_t) :: predictor_lineage
    logical :: window_active = .false.
    logical :: ledger_prepared = .false.
    logical :: swap_committed = .false.
  end type fmr_groundwater_registry_entry_t

  type, public :: fmr_groundwater_participant_registry_t
    private
    type(fmr_groundwater_registry_entry_t), allocatable :: entries(:)
    integer(int64) :: next_handle = 1_int64
    logical :: initialized = .false.
  contains
    procedure, public :: initialize => registry_initialize
    procedure, public :: bind_context => registry_bind_context
    procedure, public :: unbind_context => registry_unbind_context
    procedure, public :: begin_window => registry_begin_window
    procedure, public :: corrector_trial => registry_corrector_trial
    procedure, public :: discard_candidate => registry_discard_candidate
    procedure, public :: swap_publication_ready => registry_swap_publication_ready
    procedure, public :: prepare_ledger => registry_prepare_ledger
    procedure, public :: ledger_publication_ready => registry_ledger_publication_ready
    procedure, public :: commit_swap => registry_commit_swap
    procedure, public :: commit_ledger => registry_commit_ledger
    procedure, public :: abort_prepublication => registry_abort_prepublication
    procedure, public :: bound_count => registry_bound_count
    procedure, public :: tile_identity => registry_tile_identity
  end type fmr_groundwater_participant_registry_t

contains

  subroutine registry_initialize(self, capacity, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer, intent(in) :: capacity
    integer, intent(out) :: status

    status = FMR_GW_REGISTRY_INVALID_CAPACITY
    if (capacity <= 0) return
    if (allocated(self%entries)) deallocate(self%entries)
    allocate(self%entries(capacity))
    self%entries = fmr_groundwater_registry_entry_t()
    self%next_handle = 1_int64
    self%initialized = .true.
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_initialize

  subroutine registry_bind_context(self, tile_id, swap_lineage_id, ledger_id, predictor_backend, corrector_backend, &
       column, template, predictor_parameters, corrector_parameters, base_forcing, committed, materializer, &
       predictor_config, corrector_config, ledger, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: tile_id, swap_lineage_id, ledger_id
    type(fmr_serialized_reference_backend_t), target, intent(inout) :: predictor_backend, corrector_backend
    type(fmr_logical_column_t), target, intent(in) :: column
    type(fmr_template_t), target, intent(in) :: template
    type(fmr_b110_physical_parameters_t), target, intent(in) :: predictor_parameters, corrector_parameters
    type(fmr_b110_physical_forcing_t), target, intent(in) :: base_forcing
    type(kernel_committed_state_t), target, intent(inout) :: committed
    type(fmr_groundwater_head_forcing_materializer_t), target, intent(inout) :: materializer
    type(canonical_numerical_config_t), target, intent(in) :: predictor_config, corrector_config
    type(groundwater_interface_mass_ledger_t), target, intent(inout) :: ledger
    integer(int64), intent(out) :: handle
    integer, intent(out) :: status

    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    integer :: i, slot, ledger_status

    handle = 0_int64
    status = FMR_GW_REGISTRY_NOT_INITIALIZED
    if (.not. self%initialized .or. .not. allocated(self%entries)) return

    status = FMR_GW_REGISTRY_INVALID_CONTEXT
    if (tile_id <= 0_int64 .or. swap_lineage_id <= 0_int64 .or. ledger_id <= 0_int64) return
    if (.not. committed%ready()) return
    if (committed%current_lineage_id() /= swap_lineage_id) return
    if (column%column_id /= swap_lineage_id) return
    if (column%template_id /= template%template_id) return
    if (associated_entry_targets_same(predictor_backend, corrector_backend)) return

    do i = 1, size(self%entries)
      if (.not. self%entries(i)%bound) cycle
      if (self%entries(i)%tile_id == tile_id) then
        status = FMR_GW_REGISTRY_DUPLICATE_TILE
        return
      end if
      if (self%entries(i)%swap_lineage_id == swap_lineage_id) then
        status = FMR_GW_REGISTRY_DUPLICATE_SWAP_LINEAGE
        return
      end if
      if (self%entries(i)%ledger_id == ledger_id) then
        status = FMR_GW_REGISTRY_DUPLICATE_LEDGER
        return
      end if
    end do

    slot = first_free_slot(self)
    if (slot <= 0) then
      status = FMR_GW_REGISTRY_FULL
      return
    end if
    if (self%next_handle <= 0_int64 .or. self%next_handle == huge(self%next_handle)) then
      status = FMR_GW_REGISTRY_HANDLE_EXHAUSTED
      return
    end if

    call ledger%snapshot(ledger_snapshot)
    if (ledger_snapshot%trial_active .or. ledger_snapshot%prepared_active) return
    if (.not. ledger_snapshot%identity_bound) then
      call ledger%bind_identity(ledger_id, ledger_status)
      if (ledger_status /= GW_MASS_LEDGER_OK) return
      call ledger%snapshot(ledger_snapshot)
    end if
    if (.not. ledger_snapshot%identity_bound .or. ledger_snapshot%ledger_id /= ledger_id) return

    call clear_entry(self%entries(slot))
    self%entries(slot)%bound = .true.
    self%entries(slot)%handle = self%next_handle
    self%entries(slot)%tile_id = tile_id
    self%entries(slot)%swap_lineage_id = swap_lineage_id
    self%entries(slot)%ledger_id = ledger_id
    self%entries(slot)%predictor_backend => predictor_backend
    self%entries(slot)%corrector_backend => corrector_backend
    self%entries(slot)%column => column
    self%entries(slot)%template => template
    self%entries(slot)%predictor_parameters => predictor_parameters
    self%entries(slot)%corrector_parameters => corrector_parameters
    self%entries(slot)%base_forcing => base_forcing
    self%entries(slot)%committed => committed
    self%entries(slot)%materializer => materializer
    self%entries(slot)%predictor_config => predictor_config
    self%entries(slot)%corrector_config => corrector_config
    self%entries(slot)%ledger => ledger

    handle = self%next_handle
    self%next_handle = self%next_handle + 1_int64
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_bind_context

  subroutine registry_unbind_context(self, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    integer :: index

    index = find_handle(self, handle)
    status = FMR_GW_REGISTRY_UNKNOWN_HANDLE
    if (index <= 0) return
    status = FMR_GW_REGISTRY_WINDOW_ACTIVE
    if (self%entries(index)%window_active) return
    if (self%entries(index)%participant%has_live_candidate()) return
    if (self%entries(index)%ledger_prepared) return
    call clear_entry(self%entries(index))
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_unbind_context

  subroutine registry_begin_window(self, handle, window, datum, qbot_predictor_cm_per_day, accepted_interface, &
       coupling_id, groundwater_service_id, groundwater_lineage_id, groundwater_origin_revision, response, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_head_datum_t), intent(in) :: datum
    real(real64), intent(in) :: qbot_predictor_cm_per_day
    type(groundwater_interface_state_t), intent(in) :: accepted_interface
    integer(int64), intent(in) :: coupling_id, groundwater_service_id, groundwater_lineage_id
    integer(int64), intent(in) :: groundwater_origin_revision
    type(modflow6_swap_predictor_response_t), intent(out) :: response
    integer, intent(out) :: status

    type(modflow6_swap_predictor_lineage_t) :: lineage
    integer :: index, predictor_status, participant_status

    response = modflow6_swap_predictor_response_t()
    index = find_handle(self, handle)
    status = FMR_GW_REGISTRY_UNKNOWN_HANDLE
    if (index <= 0) return

    status = FMR_GW_REGISTRY_WINDOW_ACTIVE
    if (self%entries(index)%window_active) return
    if (self%entries(index)%participant%has_live_candidate()) return
    if (self%entries(index)%ledger_prepared) return

    status = FMR_GW_REGISTRY_INVALID_CONTEXT
    if (coupling_id <= 0_int64 .or. groundwater_service_id <= 0_int64 .or. groundwater_lineage_id <= 0_int64) return
    if (groundwater_origin_revision < 0_int64) return

    lineage%coupling_id = coupling_id
    lineage%swap_lineage_id = self%entries(index)%swap_lineage_id
    lineage%swap_origin_revision = self%entries(index)%committed%current_revision()
    lineage%groundwater_service_id = groundwater_service_id
    lineage%groundwater_lineage_id = groundwater_lineage_id
    lineage%groundwater_origin_revision = groundwater_origin_revision

    call build_fmr_groundwater_predictor_response(self%entries(index)%predictor_backend, &
         self%entries(index)%column, self%entries(index)%template, self%entries(index)%predictor_parameters, &
         self%entries(index)%committed, self%entries(index)%base_forcing, self%entries(index)%predictor_config, &
         datum, window, qbot_predictor_cm_per_day, accepted_interface, lineage, response, predictor_status)
    if (predictor_status /= FMR_GW_PREDICTOR_OK .or. .not. response%valid) then
      status = FMR_GW_REGISTRY_PREDICTOR_FAILED
      return
    end if

    call self%entries(index)%participant%capture_origin(self%entries(index)%committed, participant_status)
    if (participant_status /= GW_SWAP_PARTICIPANT_OK) then
      status = FMR_GW_REGISTRY_ORIGIN_FAILED
      return
    end if

    self%entries(index)%window = window
    self%entries(index)%datum = datum
    self%entries(index)%predictor_lineage = lineage
    self%entries(index)%last_trial = groundwater_swap_trial_t()
    self%entries(index)%prepared_ledger = groundwater_interface_mass_prepared_t()
    self%entries(index)%window_active = .true.
    self%entries(index)%ledger_prepared = .false.
    self%entries(index)%swap_committed = .false.
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_begin_window

  subroutine registry_corrector_trial(self, handle, prescribed_head_m, trial, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    real(real64), intent(in) :: prescribed_head_m
    type(groundwater_swap_trial_t), intent(out) :: trial
    integer, intent(out) :: status

    integer :: index, participant_status

    trial = groundwater_swap_trial_t()
    index = find_handle(self, handle)
    status = FMR_GW_REGISTRY_UNKNOWN_HANDLE
    if (index <= 0) return
    status = FMR_GW_REGISTRY_WINDOW_NOT_ACTIVE
    if (.not. self%entries(index)%window_active .or. self%entries(index)%swap_committed) return

    call self%entries(index)%participant%trial_from_origin(self%entries(index)%corrector_backend, &
         self%entries(index)%column, self%entries(index)%template, self%entries(index)%corrector_parameters, &
         self%entries(index)%committed, self%entries(index)%materializer, self%entries(index)%corrector_config, &
         self%entries(index)%datum, self%entries(index)%window, prescribed_head_m, trial, participant_status)
    if (participant_status /= GW_SWAP_PARTICIPANT_OK .or. .not. trial%valid) then
      status = FMR_GW_REGISTRY_CORRECTOR_FAILED
      return
    end if

    self%entries(index)%last_trial = trial
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_corrector_trial

  subroutine registry_discard_candidate(self, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    integer :: index

    index = find_handle(self, handle)
    status = FMR_GW_REGISTRY_UNKNOWN_HANDLE
    if (index <= 0) return
    status = FMR_GW_REGISTRY_WINDOW_NOT_ACTIVE
    if (.not. self%entries(index)%window_active .or. self%entries(index)%swap_committed) return
    if (self%entries(index)%ledger_prepared) then
      status = FMR_GW_REGISTRY_NOT_READY
      return
    end if

    if (self%entries(index)%participant%has_live_candidate()) then
      call self%entries(index)%participant%discard_candidate(self%entries(index)%corrector_backend)
    end if
    self%entries(index)%last_trial = groundwater_swap_trial_t()
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_discard_candidate

  logical function registry_swap_publication_ready(self, handle) result(ready)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle

    integer :: index

    ready = .false.
    index = find_handle(self, handle)
    if (index <= 0) return
    if (.not. self%entries(index)%window_active .or. self%entries(index)%swap_committed) return
    ready = self%entries(index)%participant%publication_ready(self%entries(index)%committed, self%entries(index)%window)
  end function registry_swap_publication_ready

  subroutine registry_prepare_ledger(self, handle, area_fraction, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    real(real64), intent(in) :: area_fraction
    integer, intent(out) :: status

    type(groundwater_interface_lineage_t) :: lineage
    real(real64) :: weighted_exchange_m
    integer :: index, ledger_status

    index = find_handle(self, handle)
    status = FMR_GW_REGISTRY_UNKNOWN_HANDLE
    if (index <= 0) return
    status = FMR_GW_REGISTRY_WINDOW_NOT_ACTIVE
    if (.not. self%entries(index)%window_active .or. self%entries(index)%swap_committed) return
    status = FMR_GW_REGISTRY_INVALID_FRACTION
    if (.not. ieee_is_finite(area_fraction)) return
    if (area_fraction <= 0.0_real64 .or. area_fraction > 1.0_real64) return
    status = FMR_GW_REGISTRY_NOT_READY
    if (.not. self%entries(index)%last_trial%valid) return
    if (.not. self%entries(index)%participant%publication_ready(self%entries(index)%committed, &
         self%entries(index)%window)) return
    if (self%entries(index)%ledger_prepared) return
    if (self%entries(index)%predictor_lineage%swap_origin_revision == huge(0_int64)) return

    lineage%coupling_id = self%entries(index)%predictor_lineage%coupling_id
    lineage%swap_lineage_id = self%entries(index)%swap_lineage_id
    lineage%swap_origin_revision = self%entries(index)%predictor_lineage%swap_origin_revision
    lineage%groundwater_lineage_id = self%entries(index)%predictor_lineage%groundwater_lineage_id
    lineage%groundwater_origin_revision = self%entries(index)%predictor_lineage%groundwater_origin_revision
    lineage%candidate_revision = self%entries(index)%predictor_lineage%swap_origin_revision + 1_int64

    weighted_exchange_m = area_fraction * self%entries(index)%last_trial%bottom_outward_exchange_cm * 0.01_real64
    call self%entries(index)%ledger%stage_exchange(self%entries(index)%window, lineage, weighted_exchange_m, ledger_status)
    if (ledger_status /= GW_MASS_LEDGER_OK) then
      status = FMR_GW_REGISTRY_LEDGER_FAILED
      return
    end if
    call self%entries(index)%ledger%prepare_trial(self%entries(index)%prepared_ledger, ledger_status)
    if (ledger_status /= GW_MASS_LEDGER_OK) then
      if (self%entries(index)%ledger%has_active_trial()) call self%entries(index)%ledger%discard_trial(ledger_status)
      status = FMR_GW_REGISTRY_LEDGER_FAILED
      return
    end if

    self%entries(index)%ledger_prepared = .true.
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_prepare_ledger

  logical function registry_ledger_publication_ready(self, handle) result(ready)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle

    integer :: index

    ready = .false.
    index = find_handle(self, handle)
    if (index <= 0) return
    if (.not. self%entries(index)%window_active .or. .not. self%entries(index)%ledger_prepared) return
    ready = self%entries(index)%ledger%prepared_ready_for_commit(self%entries(index)%prepared_ledger)
  end function registry_ledger_publication_ready

  subroutine registry_commit_swap(self, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    integer :: index, participant_status
    logical :: did_commit

    index = find_handle(self, handle)
    status = FMR_GW_REGISTRY_UNKNOWN_HANDLE
    if (index <= 0) return
    status = FMR_GW_REGISTRY_WINDOW_NOT_ACTIVE
    if (.not. self%entries(index)%window_active) return
    status = FMR_GW_REGISTRY_POST_PUBLICATION
    if (self%entries(index)%swap_committed) return
    status = FMR_GW_REGISTRY_NOT_READY
    if (.not. self%registry_swap_publication_ready(handle)) return
    if (.not. self%registry_ledger_publication_ready(handle)) return

    call self%entries(index)%participant%commit_candidate(self%entries(index)%corrector_backend, &
         self%entries(index)%committed, self%entries(index)%window, did_commit, participant_status)
    if (.not. did_commit .or. participant_status /= GW_SWAP_PARTICIPANT_OK) then
      status = FMR_GW_REGISTRY_COMMIT_FAILED
      return
    end if

    self%entries(index)%swap_committed = .true.
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_commit_swap

  subroutine registry_commit_ledger(self, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    integer :: index

    index = find_handle(self, handle)
    status = FMR_GW_REGISTRY_UNKNOWN_HANDLE
    if (index <= 0) return
    status = FMR_GW_REGISTRY_WINDOW_NOT_ACTIVE
    if (.not. self%entries(index)%window_active) return
    status = FMR_GW_REGISTRY_NOT_READY
    if (.not. self%entries(index)%swap_committed) return
    if (.not. self%registry_ledger_publication_ready(handle)) return

    call self%entries(index)%ledger%commit_prepared(self%entries(index)%prepared_ledger)
    self%entries(index)%ledger_prepared = .false.
    self%entries(index)%window_active = .false.
    self%entries(index)%last_trial = groundwater_swap_trial_t()
    self%entries(index)%prepared_ledger = groundwater_interface_mass_prepared_t()
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_commit_ledger

  subroutine registry_abort_prepublication(self, handle, status)
    class(fmr_groundwater_participant_registry_t), intent(inout) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    integer :: index, ledger_status

    index = find_handle(self, handle)
    status = FMR_GW_REGISTRY_UNKNOWN_HANDLE
    if (index <= 0) return
    status = FMR_GW_REGISTRY_WINDOW_NOT_ACTIVE
    if (.not. self%entries(index)%window_active) return
    status = FMR_GW_REGISTRY_POST_PUBLICATION
    if (self%entries(index)%swap_committed) return

    if (self%entries(index)%participant%has_live_candidate()) then
      call self%entries(index)%participant%discard_candidate(self%entries(index)%corrector_backend)
    end if

    if (self%entries(index)%ledger_prepared) then
      if (self%entries(index)%ledger%prepared_ready_for_commit(self%entries(index)%prepared_ledger)) then
        call self%entries(index)%ledger%abort_prepared(self%entries(index)%prepared_ledger)
      end if
    else if (self%entries(index)%ledger%has_active_trial()) then
      call self%entries(index)%ledger%discard_trial(ledger_status)
    end if

    self%entries(index)%last_trial = groundwater_swap_trial_t()
    self%entries(index)%prepared_ledger = groundwater_interface_mass_prepared_t()
    self%entries(index)%ledger_prepared = .false.
    self%entries(index)%window_active = .false.
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_abort_prepublication

  pure integer function registry_bound_count(self) result(count)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer :: i

    count = 0
    if (.not. self%initialized .or. .not. allocated(self%entries)) return
    do i = 1, size(self%entries)
      if (self%entries(i)%bound) count = count + 1
    end do
  end function registry_bound_count

  subroutine registry_tile_identity(self, handle, tile_id, swap_lineage_id, ledger_id, available)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle
    integer(int64), intent(out) :: tile_id, swap_lineage_id, ledger_id
    logical, intent(out) :: available

    integer :: index

    tile_id = 0_int64
    swap_lineage_id = 0_int64
    ledger_id = 0_int64
    available = .false.
    index = find_handle(self, handle)
    if (index <= 0) return
    tile_id = self%entries(index)%tile_id
    swap_lineage_id = self%entries(index)%swap_lineage_id
    ledger_id = self%entries(index)%ledger_id
    available = .true.
  end subroutine registry_tile_identity

  pure integer function first_free_slot(self) result(slot)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer :: i

    slot = 0
    if (.not. allocated(self%entries)) return
    do i = 1, size(self%entries)
      if (.not. self%entries(i)%bound) then
        slot = i
        return
      end if
    end do
  end function first_free_slot

  pure integer function find_handle(self, handle) result(index)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle
    integer :: i

    index = 0
    if (handle <= 0_int64) return
    if (.not. self%initialized .or. .not. allocated(self%entries)) return
    do i = 1, size(self%entries)
      if (self%entries(i)%bound .and. self%entries(i)%handle == handle) then
        index = i
        return
      end if
    end do
  end function find_handle

  subroutine clear_entry(entry)
    type(fmr_groundwater_registry_entry_t), intent(inout) :: entry

    nullify(entry%predictor_backend, entry%corrector_backend, entry%column, entry%template, &
         entry%predictor_parameters, entry%corrector_parameters, entry%base_forcing, entry%committed, &
         entry%materializer, entry%predictor_config, entry%corrector_config, entry%ledger)
    entry%bound = .false.
    entry%handle = 0_int64
    entry%tile_id = 0_int64
    entry%swap_lineage_id = 0_int64
    entry%ledger_id = 0_int64
    entry%participant = fmr_groundwater_swap_participant_t()
    entry%last_trial = groundwater_swap_trial_t()
    entry%prepared_ledger = groundwater_interface_mass_prepared_t()
    entry%window = groundwater_coupling_window_t()
    entry%datum = groundwater_head_datum_t()
    entry%predictor_lineage = modflow6_swap_predictor_lineage_t()
    entry%window_active = .false.
    entry%ledger_prepared = .false.
    entry%swap_committed = .false.
  end subroutine clear_entry

  logical function associated_entry_targets_same(a, b) result(same)
    type(fmr_serialized_reference_backend_t), target, intent(inout) :: a, b
    type(fmr_serialized_reference_backend_t), pointer :: pa, pb

    pa => a
    pb => b
    same = associated(pa, pb)
    nullify(pa, pb)
  end function associated_entry_targets_same

end module mod_fmr_groundwater_participant_registry

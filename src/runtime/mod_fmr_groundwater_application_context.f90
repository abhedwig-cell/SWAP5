module mod_fmr_groundwater_application_context
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_application_plan, only: groundwater_application_plan_t, groundwater_application_cell_plan_t, &
       GW_APP_PLAN_OK
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       evaluate_modflow6_linear_boundary_flux_density, reanchor_modflow6_linear_boundary_term, &
       relinearize_modflow6_linear_boundary_term, MODFLOW6_LINEAR_BACKEND_OK
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, &
       FMR_GW_REGISTRY_OK
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t
  use mod_groundwater_tile_aggregation, only: groundwater_tile_exchange_t, groundwater_cell_exchange_t, &
       aggregate_groundwater_cell_tiles, GW_TILE_COMPONENT_SWAP, GW_TILE_AGG_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_prepared_t, groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  implicit none
  private

  real(real64), parameter :: CM_TO_M = 0.01_real64

  integer, parameter, public :: FMR_GW_APP_CONTEXT_OK = 0
  integer, parameter, public :: FMR_GW_APP_CONTEXT_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_GW_APP_CONTEXT_PLAN_FAILED = 2
  integer, parameter, public :: FMR_GW_APP_CONTEXT_HANDLE_FAILED = 3
  integer, parameter, public :: FMR_GW_APP_CONTEXT_LEDGER_FAILED = 4
  integer, parameter, public :: FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED = 5
  integer, parameter, public :: FMR_GW_APP_CONTEXT_AGGREGATION_FAILED = 6
  integer, parameter, public :: FMR_GW_APP_CONTEXT_LINEAR_RESPONSE_FAILED = 7
  integer, parameter, public :: FMR_GW_APP_CONTEXT_PREPARED_BUSY = 8
  integer, parameter, public :: FMR_GW_APP_CONTEXT_PUBLICATION_FAILED = 9

  type, public :: fmr_groundwater_application_context_t
    private
    type(groundwater_application_plan_t), pointer :: plan => null()
    type(fmr_groundwater_participant_registry_t), pointer :: registry => null()
    type(groundwater_interface_mass_ledger_t), pointer :: ledgers(:) => null()
    integer(int64), allocatable :: participant_handles(:)
    integer(int64), allocatable :: expected_swap_origin_revisions(:)
    type(groundwater_topology_tile_t), allocatable :: tiles(:)
    type(groundwater_application_cell_plan_t), allocatable :: cells(:)
    type(modflow6_api_slot_binding_t), allocatable :: bindings(:)
    type(modflow6_linear_boundary_term_t), allocatable :: current_terms(:)
    type(groundwater_swap_trial_t), allocatable :: trials(:)
    logical, allocatable :: trial_valid(:)
    type(groundwater_interface_mass_prepared_t), allocatable :: prepared_ledgers(:)
    logical, allocatable :: ledger_prepared(:)
    type(groundwater_coupling_window_t) :: window
    logical :: bound = .false.
    logical :: published = .false.
  contains
    procedure, public :: bind => application_context_bind
    procedure, public :: ready => application_context_ready
    procedure, public :: tile_count => application_context_tile_count
    procedure, public :: cell_count => application_context_cell_count
    procedure, public :: quiescent => application_context_quiescent
    procedure, public :: copy_plan_view => application_context_copy_plan_view
    procedure, public :: copy_tile_view => application_context_copy_tile_view
    procedure, public :: capture_origins => application_context_capture_origins
    procedure, public :: evaluate_groundwater_fluxes => application_context_evaluate_groundwater_fluxes
    procedure, public :: trial_cell_heads => application_context_trial_cell_heads
    procedure, public :: trial_response_tangents => application_context_trial_response_tangents
    procedure, public :: discard_candidates => application_context_discard_candidates
    procedure, public :: reanchor_terms => application_context_reanchor_terms
    procedure, public :: relinearize_terms => application_context_relinearize_terms
    procedure, public :: swap_preflight => application_context_swap_preflight
    procedure, public :: prepare_ledgers => application_context_prepare_ledgers
    procedure, public :: ledgers_preflight => application_context_ledgers_preflight
    procedure, public :: abort_prepublication => application_context_abort_prepublication
    procedure, public :: commit_swaps => application_context_commit_swaps
    procedure, public :: commit_ledgers => application_context_commit_ledgers
  end type fmr_groundwater_application_context_t

contains

  subroutine application_context_bind(self, plan, registry, participant_handles, ledgers, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    type(groundwater_application_plan_t), target, intent(in) :: plan
    type(fmr_groundwater_participant_registry_t), target, intent(inout) :: registry
    integer(int64), intent(in) :: participant_handles(:)
    type(groundwater_interface_mass_ledger_t), target, intent(inout) :: ledgers(:)
    integer, intent(out) :: status

    type(groundwater_topology_tile_t), allocatable :: tiles(:)
    integer(int64), allocatable :: expected_swap_origin_revisions(:)
    type(groundwater_application_cell_plan_t), allocatable :: cells(:)
    type(modflow6_api_slot_binding_t), allocatable :: bindings(:)
    type(modflow6_linear_boundary_term_t), allocatable :: terms(:)
    type(groundwater_interface_mass_snapshot_t) :: snapshot
    integer(int64) :: tile_id, lineage_id, revision
    logical :: has_origin, has_candidate, available, handles_strictly_increasing
    integer :: i, j, local_status

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (self%bound) return
    if (.not. plan%ready()) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if

    call plan%copy_tiles(tiles, local_status)
    if (local_status /= GW_APP_PLAN_OK .or. .not. allocated(tiles)) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if
    call plan%copy_tile_swap_origin_revisions(expected_swap_origin_revisions, local_status)
    if (local_status /= GW_APP_PLAN_OK .or. .not. allocated(expected_swap_origin_revisions)) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if
    call plan%copy_cells(cells, local_status)
    if (local_status /= GW_APP_PLAN_OK .or. .not. allocated(cells)) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if
    call plan%copy_api_bindings(bindings, local_status)
    if (local_status /= GW_APP_PLAN_OK .or. .not. allocated(bindings)) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if
    call plan%copy_linear_terms(terms, local_status)
    if (local_status /= GW_APP_PLAN_OK .or. .not. allocated(terms)) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if
    call plan%window(self%window, available)
    if (.not. available .or. .not. self%window%valid()) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if

    if (size(participant_handles) /= size(tiles) .or. size(ledgers) /= size(tiles) .or. &
        size(expected_swap_origin_revisions) /= size(tiles)) return
    if (size(cells) /= size(bindings) .or. size(cells) /= size(terms)) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if

    handles_strictly_increasing = .true.
    if (size(participant_handles) > 0) then
      if (participant_handles(1) <= 0_int64) handles_strictly_increasing = .false.
      do i = 2, size(participant_handles)
        if (participant_handles(i) <= 0_int64 .or. participant_handles(i) <= participant_handles(i-1)) then
          handles_strictly_increasing = .false.
          exit
        end if
      end do
    end if

    do i = 1, size(tiles)
      if (participant_handles(i) <= 0_int64) then
        status = FMR_GW_APP_CONTEXT_HANDLE_FAILED
        return
      end if
      if (.not. handles_strictly_increasing) then
        do j = 1, i - 1
          if (participant_handles(j) == participant_handles(i)) then
            status = FMR_GW_APP_CONTEXT_HANDLE_FAILED
            return
          end if
        end do
      end if

      call registry%identity(participant_handles(i), tile_id, lineage_id, revision, &
           has_origin, has_candidate, local_status)
      ! A participant may already hold a captured accepted origin after an
      ! aborted/pre-evaluation context. That is reusable only when it is exactly
      ! the origin carried by the new predictor response. Live candidates are
      ! never reusable across application contexts.
      if (local_status /= FMR_GW_REGISTRY_OK .or. tile_id /= tiles(i)%tile_id .or. has_candidate) then
        status = FMR_GW_APP_CONTEXT_HANDLE_FAILED
        return
      end if
      if (has_origin) then
        if (lineage_id /= tiles(i)%swap_lineage_id .or. revision /= expected_swap_origin_revisions(i)) then
          status = FMR_GW_APP_CONTEXT_HANDLE_FAILED
          return
        end if
      end if

      call ledgers(i)%snapshot(snapshot)
      if (.not. snapshot%available .or. .not. snapshot%identity_bound) then
        status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
        return
      end if
      if (snapshot%ledger_id /= tiles(i)%ledger_id .or. snapshot%trial_active .or. snapshot%prepared_active) then
        status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
        return
      end if
    end do

    do i = 1, size(cells)
      if (.not. cells(i)%valid()) then
        status = FMR_GW_APP_CONTEXT_PLAN_FAILED
        return
      end if
      if (bindings(i)%groundwater_cell_id /= cells(i)%topology%groundwater_cell_id .or. &
          terms(i)%groundwater_cell_id /= cells(i)%topology%groundwater_cell_id) then
        status = FMR_GW_APP_CONTEXT_PLAN_FAILED
        return
      end if
    end do

    allocate(self%participant_handles(size(participant_handles)))
    allocate(self%expected_swap_origin_revisions(size(expected_swap_origin_revisions)))
    allocate(self%tiles(size(tiles)))
    allocate(self%cells(size(cells)))
    allocate(self%bindings(size(bindings)))
    allocate(self%current_terms(size(terms)))
    allocate(self%trials(size(tiles)))
    allocate(self%trial_valid(size(tiles)))
    allocate(self%prepared_ledgers(size(tiles)))
    allocate(self%ledger_prepared(size(tiles)))

    self%participant_handles = participant_handles
    self%expected_swap_origin_revisions = expected_swap_origin_revisions
    self%tiles = tiles
    self%cells = cells
    self%bindings = bindings
    self%current_terms = terms
    self%trial_valid = .false.
    self%ledger_prepared = .false.
    self%plan => plan
    self%registry => registry
    self%ledgers => ledgers
    self%bound = .true.
    self%published = .false.
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_bind

  logical function application_context_ready(self) result(ready)
    class(fmr_groundwater_application_context_t), intent(in) :: self

    ready = self%bound .and. associated(self%plan) .and. associated(self%registry) .and. associated(self%ledgers)
    if (.not. ready) return
    ready = allocated(self%participant_handles) .and. allocated(self%expected_swap_origin_revisions) .and. &
         allocated(self%tiles) .and. allocated(self%cells) .and. &
         allocated(self%bindings) .and. allocated(self%current_terms) .and. allocated(self%trials) .and. &
         allocated(self%trial_valid) .and. allocated(self%prepared_ledgers) .and. allocated(self%ledger_prepared)
    if (.not. ready) return
    ready = self%plan%ready() .and. self%window%valid()
    if (.not. ready) return
    ready = size(self%participant_handles) == size(self%tiles) .and. &
         size(self%expected_swap_origin_revisions) == size(self%tiles) .and. &
         size(self%ledgers) == size(self%tiles) .and. size(self%trials) == size(self%tiles) .and. &
         size(self%trial_valid) == size(self%tiles) .and. &
         size(self%prepared_ledgers) == size(self%tiles) .and. size(self%ledger_prepared) == size(self%tiles) .and. &
         size(self%bindings) == size(self%cells) .and. size(self%current_terms) == size(self%cells)
  end function application_context_ready

  integer function application_context_tile_count(self) result(value)
    class(fmr_groundwater_application_context_t), intent(in) :: self
    value = 0
    if (self%ready()) value = size(self%tiles)
  end function application_context_tile_count

  integer function application_context_cell_count(self) result(value)
    class(fmr_groundwater_application_context_t), intent(in) :: self
    value = 0
    if (self%ready()) value = size(self%cells)
  end function application_context_cell_count

  logical function application_context_quiescent(self) result(quiescent)
    class(fmr_groundwater_application_context_t), intent(in) :: self

    integer(int64) :: tile_id, lineage_id, revision
    logical :: has_origin, has_candidate
    integer :: i, local_status

    quiescent = .false.
    if (.not. self%ready()) return
    if (any(self%trial_valid) .or. any(self%ledger_prepared)) return
    do i = 1, size(self%participant_handles)
      call self%registry%identity(self%participant_handles(i), tile_id, lineage_id, revision, &
           has_origin, has_candidate, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK .or. has_candidate) return
      if (self%ledgers(i)%has_active_trial() .or. self%ledgers(i)%has_prepared_trial()) return
    end do
    quiescent = .true.
  end function application_context_quiescent

  subroutine application_context_copy_plan_view(self, bindings, terms, cell_ids, status)
    class(fmr_groundwater_application_context_t), intent(in) :: self
    type(modflow6_api_slot_binding_t), allocatable, intent(out) :: bindings(:)
    type(modflow6_linear_boundary_term_t), allocatable, intent(out) :: terms(:)
    integer(int64), allocatable, intent(out) :: cell_ids(:)
    integer, intent(out) :: status

    integer :: i

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    allocate(bindings(size(self%bindings)), terms(size(self%current_terms)), cell_ids(size(self%cells)))
    bindings = self%bindings
    terms = self%current_terms
    do i = 1, size(self%cells)
      cell_ids(i) = self%cells(i)%topology%groundwater_cell_id
    end do
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_copy_plan_view

  subroutine application_context_copy_tile_view(self, tiles, participant_handles, status)
    class(fmr_groundwater_application_context_t), intent(in) :: self
    type(groundwater_topology_tile_t), allocatable, intent(out) :: tiles(:)
    integer(int64), allocatable, intent(out) :: participant_handles(:)
    integer, intent(out) :: status

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    allocate(tiles(size(self%tiles)), participant_handles(size(self%participant_handles)))
    tiles = self%tiles
    participant_handles = self%participant_handles
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_copy_tile_view

  subroutine application_context_capture_origins(self, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out) :: status

    integer(int64) :: tile_id, lineage_id, revision
    logical :: has_origin, has_candidate
    integer :: i, participant_status, local_status

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (self%published) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    if (any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if

    do i = 1, size(self%participant_handles)
      call self%registry%capture_origin(self%participant_handles(i), participant_status, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK) then
        status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
        return
      end if
      call self%registry%identity(self%participant_handles(i), tile_id, lineage_id, revision, &
           has_origin, has_candidate, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK .or. .not. has_origin .or. has_candidate .or. &
          tile_id /= self%tiles(i)%tile_id .or. lineage_id /= self%tiles(i)%swap_lineage_id .or. &
          revision /= self%expected_swap_origin_revisions(i)) then
        status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
        return
      end if
    end do
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_capture_origins

  subroutine application_context_evaluate_groundwater_fluxes(self, cell_heads_m, cell_flux_m_per_s, status)
    class(fmr_groundwater_application_context_t), intent(in) :: self
    real(real64), intent(in) :: cell_heads_m(:)
    real(real64), intent(out) :: cell_flux_m_per_s(:)
    integer, intent(out) :: status

    integer :: i, local_status

    cell_flux_m_per_s = 0.0_real64
    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (size(cell_heads_m) /= size(self%cells) .or. size(cell_flux_m_per_s) /= size(self%cells)) return

    do i = 1, size(self%cells)
      call evaluate_modflow6_linear_boundary_flux_density(self%current_terms(i), cell_heads_m(i), &
           cell_flux_m_per_s(i), local_status)
      if (local_status /= MODFLOW6_LINEAR_BACKEND_OK) then
        cell_flux_m_per_s = 0.0_real64
        status = FMR_GW_APP_CONTEXT_LINEAR_RESPONSE_FAILED
        return
      end if
    end do
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_evaluate_groundwater_fluxes

  subroutine application_context_trial_cell_heads(self, cell_heads_m, cell_q_swap_m_per_s, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    real(real64), intent(in) :: cell_heads_m(:)
    real(real64), intent(out) :: cell_q_swap_m_per_s(:)
    integer, intent(out) :: status

    type(groundwater_tile_exchange_t), allocatable :: exchanges(:)
    type(groundwater_cell_exchange_t) :: aggregate
    integer :: i, k, idx, first, last, participant_status, local_status

    cell_q_swap_m_per_s = 0.0_real64
    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (size(cell_heads_m) /= size(self%cells) .or. size(cell_q_swap_m_per_s) /= size(self%cells)) return
    if (self%published) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    if (any(self%trial_valid) .or. any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if

    do i = 1, size(self%cells)
      if (.not. ieee_is_finite(cell_heads_m(i))) return
      first = self%cells(i)%tile_begin
      last = first + self%cells(i)%tile_count - 1
      if (first < 1 .or. last > size(self%tiles) .or. last < first) then
        status = FMR_GW_APP_CONTEXT_PLAN_FAILED
        call discard_live_candidates_internal(self)
        return
      end if
      allocate(exchanges(self%cells(i)%tile_count))
      do k = 1, self%cells(i)%tile_count
        idx = first + k - 1
        call self%registry%trial_from_origin(self%participant_handles(idx), self%window, cell_heads_m(i), &
             self%trials(idx), participant_status, local_status)
        if (local_status /= FMR_GW_REGISTRY_OK .or. .not. self%trials(idx)%valid) then
          status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
          call discard_live_candidates_internal(self)
          deallocate(exchanges)
          return
        end if
        self%trial_valid(idx) = .true.
        exchanges(k)%groundwater_cell_id = self%tiles(idx)%groundwater_cell_id
        exchanges(k)%tile_id = self%tiles(idx)%tile_id
        exchanges(k)%tile_lineage_id = self%tiles(idx)%swap_lineage_id
        exchanges(k)%component_kind = GW_TILE_COMPONENT_SWAP
        exchanges(k)%area_fraction = self%tiles(idx)%area_fraction
        exchanges(k)%q_swap_m_per_s = self%trials(idx)%q_swap_m_per_s
      end do

      call aggregate_groundwater_cell_tiles(self%cells(i)%topology%groundwater_cell_id, exchanges, aggregate, local_status)
      deallocate(exchanges)
      if (local_status /= GW_TILE_AGG_OK .or. .not. aggregate%available) then
        status = FMR_GW_APP_CONTEXT_AGGREGATION_FAILED
        call discard_live_candidates_internal(self)
        return
      end if
      cell_q_swap_m_per_s(i) = aggregate%q_swap_area_weighted_m_per_s
    end do

    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
      call discard_live_candidates_internal(self)
      cell_q_swap_m_per_s = 0.0_real64
      return
    end if
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_trial_cell_heads

  subroutine application_context_trial_response_tangents(self, cell_dq_swap_dh_per_s, status)
    class(fmr_groundwater_application_context_t), intent(in) :: self
    real(real64), intent(out) :: cell_dq_swap_dh_per_s(:)
    integer, intent(out) :: status

    integer :: i, k, idx, first, last
    real(real64) :: tangent

    cell_dq_swap_dh_per_s = 0.0_real64
    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (size(cell_dq_swap_dh_per_s) /= size(self%cells)) return
    if (self%published) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    if (.not. all(self%trial_valid) .or. any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if

    do i = 1, size(self%cells)
      first = self%cells(i)%tile_begin
      last = first + self%cells(i)%tile_count - 1
      if (first < 1 .or. last > size(self%tiles) .or. last < first) then
        status = FMR_GW_APP_CONTEXT_PLAN_FAILED
        return
      end if
      tangent = 0.0_real64
      do k = 1, self%cells(i)%tile_count
        idx = first + k - 1
        if (.not. self%trials(idx)%response_tangent_available) then
          status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
          return
        end if
        if (.not. ieee_is_finite(self%trials(idx)%dq_swap_dh_per_s)) then
          status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
          return
        end if
        tangent = tangent + self%tiles(idx)%area_fraction * self%trials(idx)%dq_swap_dh_per_s
      end do
      if (.not. ieee_is_finite(tangent)) then
        status = FMR_GW_APP_CONTEXT_AGGREGATION_FAILED
        return
      end if
      cell_dq_swap_dh_per_s(i) = tangent
    end do
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_trial_response_tangents

  subroutine application_context_discard_candidates(self, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out) :: status

    integer :: discard_status

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    call discard_live_candidates_internal(self, discard_status)
    if (discard_status /= FMR_GW_APP_CONTEXT_OK .or. any(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
      return
    end if
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_discard_candidates

  subroutine application_context_reanchor_terms(self, cell_heads_m, cell_q_swap_m_per_s, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    real(real64), intent(in) :: cell_heads_m(:)
    real(real64), intent(in) :: cell_q_swap_m_per_s(:)
    integer, intent(out) :: status

    type(modflow6_linear_boundary_term_t), allocatable :: next_terms(:)
    integer :: i, local_status

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (size(cell_heads_m) /= size(self%cells) .or. size(cell_q_swap_m_per_s) /= size(self%cells)) return
    if (self%published) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    if (any(self%trial_valid) .or. any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if

    allocate(next_terms(size(self%current_terms)))
    do i = 1, size(next_terms)
      call reanchor_modflow6_linear_boundary_term(self%current_terms(i), cell_heads_m(i), &
           cell_q_swap_m_per_s(i), next_terms(i), local_status)
      if (local_status /= MODFLOW6_LINEAR_BACKEND_OK) then
        status = FMR_GW_APP_CONTEXT_LINEAR_RESPONSE_FAILED
        return
      end if
    end do
    self%current_terms = next_terms
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_reanchor_terms

  subroutine application_context_relinearize_terms(self, cell_heads_m, cell_q_swap_m_per_s, &
       cell_dq_swap_dh_per_s, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    real(real64), intent(in) :: cell_heads_m(:)
    real(real64), intent(in) :: cell_q_swap_m_per_s(:)
    real(real64), intent(in) :: cell_dq_swap_dh_per_s(:)
    integer, intent(out) :: status

    type(modflow6_linear_boundary_term_t), allocatable :: next_terms(:)
    integer :: i, local_status

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (size(cell_heads_m) /= size(self%cells) .or. size(cell_q_swap_m_per_s) /= size(self%cells) .or. &
        size(cell_dq_swap_dh_per_s) /= size(self%cells)) return
    if (self%published) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    if (any(self%trial_valid) .or. any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if

    allocate(next_terms(size(self%current_terms)))
    do i = 1, size(next_terms)
      call relinearize_modflow6_linear_boundary_term(self%current_terms(i), cell_heads_m(i), &
           cell_q_swap_m_per_s(i), cell_dq_swap_dh_per_s(i), next_terms(i), local_status)
      if (local_status /= MODFLOW6_LINEAR_BACKEND_OK) then
        status = FMR_GW_APP_CONTEXT_LINEAR_RESPONSE_FAILED
        return
      end if
    end do
    self%current_terms = next_terms
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_relinearize_terms

  subroutine application_context_swap_preflight(self, ready, status)
    class(fmr_groundwater_application_context_t), intent(in) :: self
    logical, intent(out) :: ready
    integer, intent(out) :: status

    logical :: participant_ready
    integer :: i, local_status

    ready = .false.
    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (self%published) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
      return
    end if

    do i = 1, size(self%participant_handles)
      call self%registry%publication_ready(self%participant_handles(i), self%window, participant_ready, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK .or. .not. participant_ready) then
        status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
        return
      end if
    end do
    ready = .true.
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_swap_preflight

  subroutine application_context_prepare_ledgers(self, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out) :: status

    type(groundwater_interface_lineage_t) :: lineage
    integer(int64) :: tile_id, swap_lineage_id, swap_revision
    logical :: has_origin, has_candidate
    real(real64) :: weighted_exchange_m
    integer :: i, k, idx, first, last, local_status

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (self%published) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
      return
    end if
    if (any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if

    do i = 1, size(self%cells)
      first = self%cells(i)%tile_begin
      last = first + self%cells(i)%tile_count - 1
      if (first < 1 .or. last > size(self%tiles) .or. last < first) then
        status = FMR_GW_APP_CONTEXT_PLAN_FAILED
        call abort_ledgers_internal(self)
        return
      end if
      if (self%current_terms(i)%groundwater_origin_revision < 0_int64 .or. &
          self%current_terms(i)%groundwater_origin_revision >= huge(0_int64)) then
        status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
        call abort_ledgers_internal(self)
        return
      end if

      do k = 1, self%cells(i)%tile_count
        idx = first + k - 1
        call self%registry%identity(self%participant_handles(idx), tile_id, swap_lineage_id, swap_revision, &
             has_origin, has_candidate, local_status)
        if (local_status /= FMR_GW_REGISTRY_OK .or. .not. has_origin .or. .not. has_candidate .or. &
            tile_id /= self%tiles(idx)%tile_id .or. swap_lineage_id /= self%tiles(idx)%swap_lineage_id .or. &
            swap_revision < 0_int64) then
          status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
          call abort_ledgers_internal(self)
          return
        end if

        lineage = groundwater_interface_lineage_t()
        lineage%coupling_id = self%cells(i)%topology%coupling_id
        lineage%swap_lineage_id = swap_lineage_id
        lineage%swap_origin_revision = swap_revision
        lineage%groundwater_lineage_id = self%cells(i)%topology%groundwater_lineage_id
        lineage%groundwater_origin_revision = self%current_terms(i)%groundwater_origin_revision
        lineage%candidate_revision = self%current_terms(i)%groundwater_origin_revision + 1_int64

        weighted_exchange_m = self%tiles(idx)%area_fraction * self%trials(idx)%bottom_outward_exchange_cm * CM_TO_M
        if (.not. ieee_is_finite(weighted_exchange_m)) then
          status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
          call abort_ledgers_internal(self)
          return
        end if
        call self%ledgers(idx)%stage_exchange(self%window, lineage, weighted_exchange_m, local_status)
        if (local_status /= GW_MASS_LEDGER_OK) then
          status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
          call abort_ledgers_internal(self)
          return
        end if
        call self%ledgers(idx)%prepare_trial(self%prepared_ledgers(idx), local_status)
        if (local_status /= GW_MASS_LEDGER_OK) then
          status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
          call abort_ledgers_internal(self)
          return
        end if
        self%ledger_prepared(idx) = .true.
      end do
    end do
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_prepare_ledgers

  subroutine application_context_ledgers_preflight(self, ready, status)
    class(fmr_groundwater_application_context_t), intent(in) :: self
    logical, intent(out) :: ready
    integer, intent(out) :: status

    integer :: i

    ready = .false.
    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (.not. all(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
      return
    end if
    do i = 1, size(self%ledgers)
      if (.not. self%ledgers(i)%prepared_ready_for_commit(self%prepared_ledgers(i))) then
        status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
        return
      end if
    end do
    ready = .true.
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_ledgers_preflight

  subroutine application_context_abort_prepublication(self, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out) :: status

    integer :: participant_status, ledger_status, origin_status

    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    participant_status = FMR_GW_APP_CONTEXT_OK
    ledger_status = FMR_GW_APP_CONTEXT_OK
    origin_status = FMR_GW_APP_CONTEXT_OK
    call discard_live_candidates_internal(self, participant_status)
    call abort_ledgers_internal(self, ledger_status)
    call abandon_origins_internal(self, origin_status)
    if (participant_status /= FMR_GW_APP_CONTEXT_OK .or. ledger_status /= FMR_GW_APP_CONTEXT_OK .or. &
        origin_status /= FMR_GW_APP_CONTEXT_OK) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_abort_prepublication

  subroutine application_context_commit_swaps(self, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out) :: status

    logical :: ready, did_commit
    integer :: i, participant_status, local_status

    status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
    if (.not. self%ready()) return

    call self%swap_preflight(ready, local_status)
    if (local_status /= FMR_GW_APP_CONTEXT_OK .or. .not. ready) return

    do i = 1, size(self%participant_handles)
      call self%registry%commit_candidate(self%participant_handles(i), self%window, did_commit, participant_status, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK .or. .not. did_commit) return
      self%trial_valid(i) = .false.
    end do
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_commit_swaps

  subroutine application_context_commit_ledgers(self, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out) :: status

    logical :: ready
    integer :: i, local_status

    status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
    if (.not. self%ready()) return
    call self%ledgers_preflight(ready, local_status)
    if (local_status /= FMR_GW_APP_CONTEXT_OK .or. .not. ready) return

    do i = 1, size(self%ledgers)
      call self%ledgers(i)%commit_prepared(self%prepared_ledgers(i))
      self%ledger_prepared(i) = .false.
    end do
    self%published = .true.
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_commit_ledgers

  subroutine discard_live_candidates_internal(self, aggregate_status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out), optional :: aggregate_status

    integer(int64) :: tile_id, lineage_id, revision
    logical :: has_origin, has_candidate
    integer :: i, local_status
    logical :: failed

    failed = .false.
    do i = 1, size(self%participant_handles)
      call self%registry%identity(self%participant_handles(i), tile_id, lineage_id, revision, &
           has_origin, has_candidate, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK) then
        failed = .true.
        cycle
      end if
      if (has_candidate) then
        call self%registry%discard_candidate(self%participant_handles(i), local_status)
        if (local_status /= FMR_GW_REGISTRY_OK) then
          failed = .true.
          cycle
        end if
      end if
      self%trial_valid(i) = .false.
    end do
    if (present(aggregate_status)) then
      if (failed) then
        aggregate_status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
      else
        aggregate_status = FMR_GW_APP_CONTEXT_OK
      end if
    end if
  end subroutine discard_live_candidates_internal

  subroutine abandon_origins_internal(self, aggregate_status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out), optional :: aggregate_status

    integer :: i, local_status
    logical :: failed

    failed = .false.
    do i = 1, size(self%participant_handles)
      call self%registry%abandon_origin(self%participant_handles(i), local_status)
      if (local_status /= FMR_GW_REGISTRY_OK) failed = .true.
    end do
    if (present(aggregate_status)) then
      if (failed) then
        aggregate_status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
      else
        aggregate_status = FMR_GW_APP_CONTEXT_OK
      end if
    end if
  end subroutine abandon_origins_internal

  subroutine abort_ledgers_internal(self, aggregate_status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    integer, intent(out), optional :: aggregate_status

    integer :: i, local_status
    logical :: failed

    failed = .false.
    do i = 1, size(self%ledgers)
      if (self%ledger_prepared(i)) then
        if (self%ledgers(i)%prepared_ready_for_commit(self%prepared_ledgers(i))) then
          call self%ledgers(i)%abort_prepared(self%prepared_ledgers(i))
          self%ledger_prepared(i) = .false.
        else
          failed = .true.
        end if
      else if (self%ledgers(i)%has_active_trial()) then
        call self%ledgers(i)%discard_trial(local_status)
        if (local_status /= GW_MASS_LEDGER_OK) failed = .true.
      end if
    end do
    if (present(aggregate_status)) then
      if (failed) then
        aggregate_status = FMR_GW_APP_CONTEXT_LEDGER_FAILED
      else
        aggregate_status = FMR_GW_APP_CONTEXT_OK
      end if
    end if
  end subroutine abort_ledgers_internal

end module mod_fmr_groundwater_application_context

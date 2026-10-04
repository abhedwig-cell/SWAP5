module mod_strip01_c2e_research_context
  use, intrinsic :: iso_c_binding, only: c_double, c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, &
       GW_SWAP_PARTICIPANT_OK, GW_SWAP_PARTICIPANT_INVALID_REQUEST, GW_SWAP_PARTICIPANT_TRIAL_FAILED, &
       GW_SWAP_PARTICIPANT_ORIGIN_DRIFT, GW_SWAP_PARTICIPANT_CANDIDATE_BUSY, GW_SWAP_PARTICIPANT_COMMIT_FAILED
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, &
       fmr_groundwater_test_participant_t, FMR_GW_REGISTRY_OK
  use mod_fmr_groundwater_application_context, only: fmr_groundwater_application_context_t, FMR_GW_APP_CONTEXT_OK
  use mod_fmr_groundwater_application_c_api, only: register_fmr_groundwater_application_context, FMR_GW_APP_C_API_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK, &
       GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_MODFLOW
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t, &
       groundwater_application_plan_t, materialize_groundwater_application_plan, GW_APP_PLAN_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  implicit none
  private

  integer, parameter :: NPART = 50, MAX_WINDOWS = 256
  integer(int64), parameter :: GW_SERVICE_ID = 9001_int64
  integer :: i
  integer(int64), parameter :: TILE_ID(NPART) = [(610000_int64 + int(i,int64), i=1,NPART)]
  integer(int64), parameter :: LEDGER_ID(NPART) = [(710000_int64 + int(i,int64), i=1,NPART)]
  integer(int64), parameter :: CELL_ID(NPART) = [(7000_int64 + int(i,int64), i=1,NPART)]
  integer(int64), parameter :: COUPLING_ID(NPART) = [(810000_int64 + int(i,int64), i=1,NPART)]
  integer(int64), parameter :: GW_LINEAGE_ID(NPART) = [(910000_int64 + int(i,int64), i=1,NPART)]
  real(real64), parameter :: STORAGE = 0.05_real64, DAY_S = 86400.0_real64

  type, extends(fmr_groundwater_test_participant_t), public :: c2e_dummy_participant_t
    private
    integer(int64) :: tile_id = 0_int64, lineage_id = 0_int64, revision = 0_int64
    real(real64) :: internal_head = -1.0_real64, current_time = 0.0_real64
    real(real64) :: recharge_m_per_day = 0.0_real64, conductance_m2_per_day = 1.0e6_real64
    real(real64) :: origin_head = -1.0_real64, origin_time = 0.0_real64
    real(real64) :: candidate_head = -1.0_real64, candidate_t0 = 0.0_real64, candidate_t1 = 0.0_real64
    real(real64) :: candidate_prescribed_head = -1.0_real64
    logical :: origin_captured = .false., candidate_live = .false., reject_once = .false.
  contains
    procedure :: configure => c2e_dummy_configure
    procedure :: bind_identity => c2e_dummy_bind_identity
    procedure :: capture_origin => c2e_dummy_capture_origin
    procedure :: trial_from_origin => c2e_dummy_trial
    procedure :: discard_candidate => c2e_dummy_discard
    procedure :: abandon_origin => c2e_dummy_abandon
    procedure :: publication_ready => c2e_dummy_publication_ready
    procedure :: commit_candidate => c2e_dummy_commit
    procedure :: identity => c2e_dummy_identity
    procedure :: has_live_candidate => c2e_dummy_has_candidate
  end type c2e_dummy_participant_t

  type(fmr_groundwater_participant_registry_t), target, save :: registries(MAX_WINDOWS)
  type(fmr_groundwater_application_context_t), target, save :: contexts(MAX_WINDOWS)
  type(groundwater_interface_mass_ledger_t), target, save :: ledgers(NPART)
  type(groundwater_application_plan_t), target, save :: plans(MAX_WINDOWS)
  type(c2e_dummy_participant_t), target, save :: participants(NPART,MAX_WINDOWS)
  integer(int64), save :: handles(NPART,MAX_WINDOWS) = 0_int64
  real(real64), save :: committed_dummy_head(NPART) = -1.0_real64
  integer(int64), save :: committed_revision(NPART) = 0_int64
  real(real64), save :: accepted_time = 0.0_real64
  logical, save :: initialized_window(MAX_WINDOWS) = .false.
  logical, save :: ledgers_initialized = .false.

  public :: fgc49d_c2e_begin_c, fgc49d_c2e_state_c

contains

  subroutine c2e_dummy_configure(self, internal_head, revision, current_time, recharge, conductance, reject_once)
    class(c2e_dummy_participant_t), intent(inout) :: self
    real(real64), intent(in) :: internal_head, current_time, recharge, conductance
    integer(int64), intent(in) :: revision
    logical, intent(in) :: reject_once
    self%tile_id = 0_int64
    self%lineage_id = 0_int64
    self%revision = revision
    self%internal_head = internal_head
    self%current_time = current_time
    self%recharge_m_per_day = recharge
    self%conductance_m2_per_day = conductance
    self%origin_captured = .false.
    self%candidate_live = .false.
    self%reject_once = reject_once
  end subroutine c2e_dummy_configure

  subroutine c2e_dummy_bind_identity(self, tile_id, status)
    class(c2e_dummy_participant_t), intent(inout) :: self
    integer(int64), intent(in) :: tile_id
    integer, intent(out) :: status
    status = GW_SWAP_PARTICIPANT_INVALID_REQUEST
    if (tile_id <= 0_int64 .or. self%tile_id /= 0_int64 .or. self%candidate_live .or. self%origin_captured) return
    self%tile_id = tile_id
    self%lineage_id = tile_id
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine c2e_dummy_bind_identity

  subroutine c2e_dummy_capture_origin(self, status)
    class(c2e_dummy_participant_t), intent(inout) :: self
    integer, intent(out) :: status
    status = GW_SWAP_PARTICIPANT_INVALID_REQUEST
    if (self%tile_id <= 0_int64 .or. self%origin_captured .or. self%candidate_live) return
    self%origin_head = self%internal_head
    self%origin_time = self%current_time
    self%origin_captured = .true.
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine c2e_dummy_capture_origin

  subroutine c2e_dummy_trial(self, window, prescribed_head_m, trial, status)
    class(c2e_dummy_participant_t), intent(inout) :: self
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: prescribed_head_m
    type(groundwater_swap_trial_t), intent(out) :: trial
    integer, intent(out) :: status
    real(real64) :: dt, scale, q_m_per_day, tangent_m_per_day

    trial = groundwater_swap_trial_t()
    status = GW_SWAP_PARTICIPANT_INVALID_REQUEST
    if (.not. self%origin_captured .or. self%candidate_live .or. .not. window%valid()) return
    if (abs(window%t0-self%origin_time) > 1.0e-12_real64) then
      status = GW_SWAP_PARTICIPANT_ORIGIN_DRIFT
      return
    end if
    if (self%revision < 0_int64 .or. self%lineage_id <= 0_int64) return
    if (.not. ieee_is_finite(prescribed_head_m) .or. self%conductance_m2_per_day <= 0.0_real64) return
    if (self%reject_once) then
      self%reject_once = .false.
      status = GW_SWAP_PARTICIPANT_TRIAL_FAILED
      return
    end if

    dt = window%t1-window%t0
    scale = 1.0_real64 + self%conductance_m2_per_day*dt/STORAGE
    q_m_per_day = self%conductance_m2_per_day * &
         (self%origin_head + self%recharge_m_per_day*dt/STORAGE - prescribed_head_m) / scale
    tangent_m_per_day = -self%conductance_m2_per_day/scale
    if (.not. ieee_is_finite(q_m_per_day) .or. .not. ieee_is_finite(tangent_m_per_day)) return

    self%candidate_head = self%origin_head + &
         (self%recharge_m_per_day*dt-q_m_per_day*dt)/STORAGE
    self%candidate_t0 = window%t0
    self%candidate_t1 = window%t1
    self%candidate_prescribed_head = prescribed_head_m
    self%candidate_live = .true.
    trial%valid = .true.
    trial%prescribed_head_m = prescribed_head_m
    trial%q_swap_m_per_s = q_m_per_day/DAY_S
    trial%bottom_outward_exchange_cm = -q_m_per_day*dt*100.0_real64
    trial%response_tangent_available = .true.
    trial%dq_swap_dh_per_s = tangent_m_per_day/DAY_S
    trial%response_tangent_refresh_head_m = prescribed_head_m
    trial%response_tangent_provenance = 'c2e-analytic-origin-response'
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine c2e_dummy_trial

  subroutine c2e_dummy_discard(self)
    class(c2e_dummy_participant_t), intent(inout) :: self
    self%candidate_live = .false.
    self%candidate_t0 = 0.0_real64
    self%candidate_t1 = 0.0_real64
  end subroutine c2e_dummy_discard

  subroutine c2e_dummy_abandon(self, status)
    class(c2e_dummy_participant_t), intent(inout) :: self
    integer, intent(out) :: status
    status = GW_SWAP_PARTICIPANT_CANDIDATE_BUSY
    if (self%candidate_live) return
    self%origin_captured = .false.
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine c2e_dummy_abandon

  logical function c2e_dummy_publication_ready(self, window) result(ready)
    class(c2e_dummy_participant_t), intent(in) :: self
    type(groundwater_coupling_window_t), intent(in) :: window
    ready = .false.
    if (.not. self%origin_captured .or. .not. self%candidate_live .or. .not. window%valid()) return
    if (self%revision < 0_int64 .or. self%current_time /= self%origin_time) return
    ready = abs(self%candidate_t0-window%t0) <= 1.0e-12_real64 .and. &
         abs(self%candidate_t1-window%t1) <= 1.0e-12_real64
  end function c2e_dummy_publication_ready

  subroutine c2e_dummy_commit(self, window, did_commit, status)
    class(c2e_dummy_participant_t), intent(inout) :: self
    type(groundwater_coupling_window_t), intent(in) :: window
    logical, intent(out) :: did_commit
    integer, intent(out) :: status
    did_commit = .false.
    status = GW_SWAP_PARTICIPANT_COMMIT_FAILED
    if (.not. self%publication_ready(window)) return
    if (self%revision == huge(0_int64)) return
    self%internal_head = self%candidate_head
    self%current_time = window%t1
    self%revision = self%revision+1_int64
    self%candidate_live = .false.
    self%origin_captured = .false.
    did_commit = .true.
    status = GW_SWAP_PARTICIPANT_OK
  end subroutine c2e_dummy_commit

  subroutine c2e_dummy_identity(self, lineage_id, revision, has_origin, has_candidate)
    class(c2e_dummy_participant_t), intent(in) :: self
    integer(int64), intent(out) :: lineage_id, revision
    logical, intent(out) :: has_origin, has_candidate
    lineage_id = 0_int64
    revision = -1_int64
    has_origin = self%origin_captured
    has_candidate = self%candidate_live
    if (has_origin) then
      lineage_id = self%lineage_id
      revision = self%revision
    end if
  end subroutine c2e_dummy_identity

  logical function c2e_dummy_has_candidate(self)
    class(c2e_dummy_participant_t), intent(in) :: self
    c2e_dummy_has_candidate = self%candidate_live
  end function c2e_dummy_has_candidate

  integer(c_int) function fgc49d_c2e_begin_c(window_index, t0, t1, recharge, conductance, mf_heads, reject_slot, &
       context_handle) bind(C, name='fgc49d_c2e_begin_c') result(c_status)
    integer(c_int), value, intent(in) :: window_index, reject_slot
    real(c_double), value, intent(in) :: t0, t1, recharge, conductance
    real(c_double), intent(in) :: mf_heads(NPART)
    integer(c_int64_t), intent(out) :: context_handle

    type(groundwater_topology_tile_t) :: tiles(NPART)
    type(groundwater_topology_cell_t) :: cells(NPART)
    type(groundwater_tile_predictor_input_t) :: predictors(NPART)
    type(groundwater_cell_area_input_t) :: areas(NPART)
    type(groundwater_topology_t) :: topology
    type(groundwater_interface_mass_snapshot_t) :: snapshot
    type(groundwater_coupling_window_t) :: window
    integer(int64) :: handle
    real(real64) :: h
    integer :: i, status

    c_status = 1_c_int
    context_handle = 0_c_int64_t
    if (window_index < 1 .or. window_index > MAX_WINDOWS) return
    if (initialized_window(window_index)) return
    if (abs(real(t0,real64)-accepted_time) > 1.0e-10_real64) return
    if (t1 <= t0 .or. conductance <= 0.0_c_double) return
    if (reject_slot < 0 .or. reject_slot > NPART) return

    window%t0 = real(t0,real64)
    window%t1 = real(t1,real64)
    call registries(window_index)%initialize(NPART, status)
    if (status /= FMR_GW_REGISTRY_OK) return

    do i = 1, NPART
      call participants(i,window_index)%configure(committed_dummy_head(i), committed_revision(i), accepted_time, &
           real(recharge,real64), real(conductance,real64), i == reject_slot)
      call registries(window_index)%bind_test_participant(TILE_ID(i), participants(i,window_index), &
           handles(i,window_index), status)
      if (status /= FMR_GW_REGISTRY_OK) return
      if (.not. ledgers_initialized) then
        call ledgers(i)%bind_identity(LEDGER_ID(i), status)
        if (status /= GW_MASS_LEDGER_OK) return
      end if

      call make_topology(tiles(i), cells(i), TILE_ID(i), LEDGER_ID(i), CELL_ID(i), COUPLING_ID(i), &
           GW_LINEAGE_ID(i), i)
      h = real(mf_heads(i),real64)
      call make_predictor(predictors(i), TILE_ID(i), COUPLING_ID(i), GW_LINEAGE_ID(i), &
           committed_revision(i), window, h)
      areas(i)%groundwater_cell_id = CELL_ID(i)
      areas(i)%cell_area_m2 = 1.0_real64
    end do
    ledgers_initialized = .true.

    call materialize_groundwater_topology(tiles, cells, topology, status)
    if (status /= GW_TOPOLOGY_OK .or. .not. topology%ready()) return
    call materialize_groundwater_application_plan(topology, predictors, areas, plans(window_index), status)
    if (status /= GW_APP_PLAN_OK .or. .not. plans(window_index)%ready()) return
    call contexts(window_index)%bind(plans(window_index), registries(window_index), handles(:,window_index), &
         ledgers, status)
    if (status /= FMR_GW_APP_CONTEXT_OK .or. .not. contexts(window_index)%ready()) return
    call register_fmr_groundwater_application_context(contexts(window_index), handle, status)
    if (status /= FMR_GW_APP_C_API_OK .or. handle <= 0_int64) return
    context_handle = int(handle,c_int64_t)
    initialized_window(window_index) = .true.
    c_status = 0_c_int
  end function fgc49d_c2e_begin_c

  integer(c_int) function fgc49d_c2e_state_c(window_index, dummy_heads, revisions, ledger_counts) &
       bind(C, name='fgc49d_c2e_state_c') result(c_status)
    integer(c_int), value, intent(in) :: window_index
    real(c_double), intent(out) :: dummy_heads(NPART)
    integer(c_int), intent(out) :: revisions(NPART), ledger_counts(NPART)
    type(groundwater_interface_mass_snapshot_t) :: snapshot
    integer :: i
    c_status = 1_c_int
    if (window_index < 1 .or. window_index > MAX_WINDOWS) return
    if (.not. initialized_window(window_index)) return
    do i = 1, NPART
      dummy_heads(i) = real(participants(i,window_index)%internal_head,c_double)
      revisions(i) = int(participants(i,window_index)%revision,c_int)
      call ledgers(i)%snapshot(snapshot)
      if (.not. snapshot%available) return
      ledger_counts(i) = int(snapshot%committed_exchange_count,c_int)
    end do
    if (all(revisions == int(committed_revision(1),c_int)+1_c_int)) then
      committed_dummy_head = real(dummy_heads,real64)
      committed_revision = int(revisions,int64)
      accepted_time = participants(1,window_index)%current_time
    end if
    c_status = 0_c_int
  end function fgc49d_c2e_state_c

  subroutine make_topology(tile, cell, tile_id, ledger_id, cell_id, coupling_id, gw_lineage_id, slot)
    type(groundwater_topology_tile_t), intent(out) :: tile
    type(groundwater_topology_cell_t), intent(out) :: cell
    integer(int64), intent(in) :: tile_id, ledger_id, cell_id, coupling_id, gw_lineage_id
    integer, intent(in) :: slot
    tile%tile_id = tile_id
    tile%swap_lineage_id = tile_id
    tile%ledger_id = ledger_id
    tile%groundwater_cell_id = cell_id
    tile%area_fraction = 1.0_real64
    cell%groundwater_cell_id = cell_id
    cell%coupling_id = coupling_id
    cell%groundwater_service_id = GW_SERVICE_ID
    cell%groundwater_lineage_id = gw_lineage_id
    cell%package_slot = slot
    cell%modflow_node_id = slot
    cell%storage_state_role = GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE
    cell%drainage_owner = GW_DRAINAGE_OWNER_MODFLOW
  end subroutine make_topology

  subroutine make_predictor(input, tile_id, coupling_id, gw_lineage_id, swap_revision, window, head)
    type(groundwater_tile_predictor_input_t), intent(out) :: input
    integer(int64), intent(in) :: tile_id, coupling_id, gw_lineage_id, swap_revision
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: head
    type(modflow6_swap_predictor_lineage_t) :: lineage
    type(modflow6_derivative_coverage_t) :: coverage
    integer :: status
    input%tile_id = tile_id
    lineage%coupling_id = coupling_id
    lineage%swap_lineage_id = tile_id
    lineage%swap_origin_revision = swap_revision
    lineage%groundwater_service_id = GW_SERVICE_ID
    lineage%groundwater_lineage_id = gw_lineage_id
    lineage%groundwater_origin_revision = 0_int64
    coverage%lower_face_head_semantics_covered = .true.
    coverage%richards_hydraulic_response_covered = .true.
    coverage%constitutive_response_covered = .true.
    call compose_modflow6_swap_predictor_response(window, lineage, 0.0_real64, head, head, -1.0_real64, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, coverage, 'C2E-analytic-test-seed', 'C2E-origin', &
         input%response, status)
    if (status /= MODFLOW6_PREDICTOR_OK .or. .not. input%response%valid) error stop 'C2E predictor construction'
  end subroutine make_predictor

end module mod_strip01_c2e_research_context

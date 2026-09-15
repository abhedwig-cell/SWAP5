module fvq96_external_backend_oracle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_groundwater_external_gateway, only: external_groundwater_backend_t, GW_EXTERNAL_BACKEND_OK
  implicit none
  private

  integer, parameter :: NCELL = 4
  integer(int64), parameter :: CELL_IDS(NCELL) = [17_int64, 29_int64, 37_int64, 41_int64]

  type, extends(external_groundwater_backend_t), public :: oracle_backend_t
    integer(int64) :: revision(NCELL) = 0_int64
    real(real64) :: origin_time(NCELL) = 0.0_real64
    real(real64) :: committed_value(NCELL) = 0.0_real64
    logical :: candidate_active(NCELL) = .false.
    integer(int64) :: candidate_token(NCELL) = 0_int64
    real(real64) :: candidate_t1(NCELL) = 0.0_real64
    real(real64) :: candidate_flux(NCELL) = 0.0_real64
    logical :: prepare_active(NCELL) = .false.
    integer(int64) :: prepare_token(NCELL) = 0_int64
    real(real64) :: last_flux_native(NCELL) = 0.0_real64
    integer :: commit_attempts(NCELL) = 0
    integer :: commit_successes(NCELL) = 0
    integer :: prepared_successes(NCELL) = 0
    logical :: fail_capture = .false.
    logical :: fail_trial = .false.
    logical :: partial_trial = .false.
    logical :: fail_commit = .false.
    logical :: fail_prepare = .false.
  contains
    procedure :: capture => oracle_capture
    procedure :: trial => oracle_trial
    procedure :: commit_candidate => oracle_commit_candidate
    procedure :: discard_candidate => oracle_discard_candidate
    procedure :: prepare => oracle_prepare
    procedure :: commit_prepared => oracle_commit_prepared
    procedure :: abort_prepared => oracle_abort_prepared
    procedure, public :: slot_for => oracle_slot_for
    procedure, public :: checkpoint_token_for => oracle_checkpoint_token_for
  end type oracle_backend_t

contains

  integer function oracle_slot_for(self, cell_id) result(slot)
    class(oracle_backend_t), intent(in) :: self
    integer(int64), intent(in) :: cell_id
    integer :: i
    slot = 0
    do i = 1, NCELL
      if (CELL_IDS(i) == cell_id) then
        slot = i
        return
      end if
    end do
  end function oracle_slot_for

  integer(int64) function oracle_checkpoint_token_for(self, cell_id) result(token)
    class(oracle_backend_t), intent(in) :: self
    integer(int64), intent(in) :: cell_id
    integer :: i
    i = self%slot_for(cell_id)
    token = 0_int64
    if (i <= 0) return
    token = 100000_int64 + 100_int64 * cell_id + self%revision(i)
  end function oracle_checkpoint_token_for

  subroutine oracle_capture(self, cell_id, lineage_id, origin_revision, origin_time, checkpoint_token, status)
    class(oracle_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id
    integer(int64), intent(out) :: lineage_id, origin_revision, checkpoint_token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status
    integer :: i

    lineage_id = 0_int64
    origin_revision = -1_int64
    origin_time = 0.0_real64
    checkpoint_token = 0_int64
    status = 611
    if (self%fail_capture) return
    i = self%slot_for(cell_id)
    if (i <= 0) return
    lineage_id = 700000_int64 + cell_id
    origin_revision = self%revision(i)
    origin_time = self%origin_time(i)
    checkpoint_token = self%checkpoint_token_for(cell_id)
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine oracle_capture

  subroutine oracle_trial(self, cell_id, checkpoint_token, t0, t1, flux_native, candidate_token, head_native, status)
    class(oracle_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token
    real(real64), intent(in) :: t0, t1, flux_native
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: head_native
    integer, intent(out) :: status
    integer :: i

    candidate_token = 0_int64
    head_native = 0.0_real64
    status = 612
    i = self%slot_for(cell_id)
    if (i <= 0) return
    if (checkpoint_token /= self%checkpoint_token_for(cell_id)) return
    if (abs(t0 - self%origin_time(i)) > 1.0e-12_real64 .or. t1 <= t0) return
    if (self%fail_trial) return

    self%last_flux_native(i) = flux_native
    if (self%partial_trial) then
      candidate_token = 300000_int64 + 100_int64 * cell_id + self%revision(i)
      head_native = ieee_value(0.0_real64, ieee_quiet_nan)
      status = GW_EXTERNAL_BACKEND_OK
      return
    end if

    self%candidate_active(i) = .true.
    self%candidate_token(i) = 200000_int64 + 100_int64 * cell_id + 10_int64 * self%revision(i) + 1_int64
    self%candidate_t1(i) = t1
    self%candidate_flux(i) = flux_native
    candidate_token = self%candidate_token(i)
    head_native = 5.0_real64 + real(i - 1, real64)
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine oracle_trial

  subroutine oracle_commit_candidate(self, cell_id, checkpoint_token, candidate_token, status)
    class(oracle_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
    integer, intent(out) :: status
    integer :: i

    status = 613
    i = self%slot_for(cell_id)
    if (i <= 0) return
    self%commit_attempts(i) = self%commit_attempts(i) + 1
    if (self%fail_commit) return
    if (checkpoint_token /= self%checkpoint_token_for(cell_id)) return
    if (.not. self%candidate_active(i)) return
    if (candidate_token /= self%candidate_token(i) .or. candidate_token <= 0_int64) return

    self%revision(i) = self%revision(i) + 1_int64
    self%origin_time(i) = self%candidate_t1(i)
    self%committed_value(i) = self%candidate_flux(i)
    self%candidate_active(i) = .false.
    self%candidate_token(i) = 0_int64
    self%candidate_t1(i) = 0.0_real64
    self%candidate_flux(i) = 0.0_real64
    self%commit_successes(i) = self%commit_successes(i) + 1
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine oracle_commit_candidate

  subroutine oracle_discard_candidate(self, cell_id, candidate_token, status)
    class(oracle_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, candidate_token
    integer, intent(out) :: status
    integer :: i

    status = 614
    i = self%slot_for(cell_id)
    if (i <= 0) return
    if (.not. self%candidate_active(i)) return
    if (candidate_token /= self%candidate_token(i) .or. candidate_token <= 0_int64) return
    self%candidate_active(i) = .false.
    self%candidate_token(i) = 0_int64
    self%candidate_t1(i) = 0.0_real64
    self%candidate_flux(i) = 0.0_real64
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine oracle_discard_candidate

  subroutine oracle_prepare(self, cell_id, checkpoint_token, candidate_token, prepare_token, status)
    class(oracle_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status
    integer :: i

    prepare_token = 0_int64
    status = 615
    i = self%slot_for(cell_id)
    if (i <= 0) return
    if (self%fail_prepare) return
    if (checkpoint_token /= self%checkpoint_token_for(cell_id)) return
    if (.not. self%candidate_active(i)) return
    if (candidate_token /= self%candidate_token(i) .or. candidate_token <= 0_int64) return
    self%prepare_active(i) = .true.
    self%prepare_token(i) = 400000_int64 + 100_int64 * cell_id + self%revision(i)
    prepare_token = self%prepare_token(i)
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine oracle_prepare

  subroutine oracle_commit_prepared(self, cell_id, prepare_token)
    class(oracle_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, prepare_token
    integer :: i

    i = self%slot_for(cell_id)
    if (i <= 0) error stop 9601
    if (.not. self%prepare_active(i) .or. prepare_token /= self%prepare_token(i)) error stop 9602
    self%revision(i) = self%revision(i) + 1_int64
    self%origin_time(i) = self%candidate_t1(i)
    self%committed_value(i) = self%candidate_flux(i)
    self%candidate_active(i) = .false.
    self%candidate_token(i) = 0_int64
    self%candidate_t1(i) = 0.0_real64
    self%candidate_flux(i) = 0.0_real64
    self%prepare_active(i) = .false.
    self%prepare_token(i) = 0_int64
    self%prepared_successes(i) = self%prepared_successes(i) + 1
  end subroutine oracle_commit_prepared

  subroutine oracle_abort_prepared(self, cell_id, prepare_token)
    class(oracle_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, prepare_token
    integer :: i

    i = self%slot_for(cell_id)
    if (i <= 0) error stop 9603
    if (.not. self%prepare_active(i) .or. prepare_token /= self%prepare_token(i)) error stop 9604
    self%candidate_active(i) = .false.
    self%candidate_token(i) = 0_int64
    self%candidate_t1(i) = 0.0_real64
    self%candidate_flux(i) = 0.0_real64
    self%prepare_active(i) = .false.
    self%prepare_token(i) = 0_int64
  end subroutine oracle_abort_prepared

end module fvq96_external_backend_oracle

program test_fvq96_fgc26_external_gateway_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       swap_bottom_pressure_head_cm_to_interface_head_m, interface_head_m_to_swap_bottom_pressure_head_cm, &
       swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, pair_groundwater_flux_from_swap, GW_INTERFACE_OK
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_commit_candidate, &
       groundwater_discard_candidate, groundwater_prepare_candidate, groundwater_commit_prepared, &
       groundwater_abort_prepared, GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED
  use mod_groundwater_external_gateway, only: groundwater_external_gateway_t, groundwater_external_gateway_config_t, &
       bind_groundwater_external_gateway_batch, GW_EXTERNAL_GATEWAY_OK, GW_EXTERNAL_GATEWAY_NOT_QUIESCENT
  use fvq96_external_backend_oracle, only: oracle_backend_t
  implicit none

  type(oracle_backend_t), target :: conv_backend, fail_backend, direct_backend, prepared_backend, batch_backend, shared_backend
  type(groundwater_external_gateway_t) :: conv_gateway, fail_gateway, direct_gateway, prepared_gateway
  type(groundwater_external_gateway_t) :: batch_gateways(2), shared_gateways(2)
  type(groundwater_external_gateway_config_t) :: cfg_a, cfg_b, cfg_c, cfg_d, batch_initial(2), batch_rebind(2)
  type(groundwater_exchange_checkpoint_t) :: cp, cp2, cp_copy
  type(groundwater_exchange_candidate_t) :: cand, cand2, cand_copy
  type(groundwater_exchange_prepared_t) :: prepared, prepared_copy
  type(groundwater_exchange_trial_result_t) :: trial, trial2
  type(groundwater_coupling_window_t) :: window
  type(groundwater_head_datum_t) :: datum
  real(real64) :: h_m, psi_cm, q_swap, q_groundwater
  real(real64), parameter :: FLUX_SCALE_A = 2.0e-7_real64
  real(real64), parameter :: FLUX_SCALE_B = 4.0e-7_real64
  integer :: status
  integer :: swap_physical_sentinel

  swap_physical_sentinel = 314159
  cfg_a = groundwater_external_gateway_config_t(service_id=101_int64, cell_id=17_int64, &
       head_native_to_m_scale=0.25_real64, head_native_zero_m=10.0_real64, &
       flux_native_to_m_per_s_scale=FLUX_SCALE_A, native_flux_sign_relative_to_groundwater=-1)
  cfg_b = groundwater_external_gateway_config_t(service_id=202_int64, cell_id=29_int64, &
       head_native_to_m_scale=0.5_real64, head_native_zero_m=-2.0_real64, &
       flux_native_to_m_per_s_scale=FLUX_SCALE_B, native_flux_sign_relative_to_groundwater=1)
  cfg_c = groundwater_external_gateway_config_t(service_id=303_int64, cell_id=37_int64, &
       head_native_to_m_scale=1.0_real64, head_native_zero_m=0.0_real64, &
       flux_native_to_m_per_s_scale=1.0e-7_real64, native_flux_sign_relative_to_groundwater=1)
  cfg_d = groundwater_external_gateway_config_t(service_id=404_int64, cell_id=41_int64, &
       head_native_to_m_scale=2.0_real64, head_native_zero_m=1.0_real64, &
       flux_native_to_m_per_s_scale=5.0e-8_real64, native_flux_sign_relative_to_groundwater=-1)

  ! Independent conversion oracle: explicit datum H=z+psi, exact SWAP/GW action-reaction,
  ! and non-trivial native head/flux scales/signs.
  call conv_gateway%bind(conv_backend, cfg_a, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'conversion gateway bind')
  datum = groundwater_head_datum_t(available=.true., datum_id=55_int64, bottom_boundary_elevation_m=12.5_real64)
  call swap_bottom_pressure_head_cm_to_interface_head_m(-125.0_real64, datum, h_m, status)
  call require(status == GW_INTERFACE_OK .and. near(h_m, 11.25_real64, 1.0e-13_real64), 'datum conversion')
  call interface_head_m_to_swap_bottom_pressure_head_cm(h_m, datum, psi_cm, status)
  call require(status == GW_INTERFACE_OK .and. near(psi_cm, -125.0_real64, 1.0e-11_real64), 'datum round trip')
  call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(1.728_real64, q_swap, status)
  call require(status == GW_INTERFACE_OK, 'SWAP flux conversion')
  call pair_groundwater_flux_from_swap(q_swap, q_groundwater, status)
  call require(status == GW_INTERFACE_OK .and. q_groundwater == -q_swap .and. q_groundwater == FLUX_SCALE_A, &
       'equal-and-opposite interface mass semantics')
  call groundwater_capture_checkpoint(conv_gateway, cp, status)
  call require(status == GW_EXCHANGE_OK, 'conversion capture')
  window = groundwater_coupling_window_t(t0=0.0_real64, t1=0.125_real64)
  call groundwater_trial_from_checkpoint(conv_gateway, cp, window, q_groundwater, cand, trial, status)
  call require(status == GW_EXCHANGE_OK, 'conversion trial')
  call require(near(conv_backend%last_flux_native(1), -1.0_real64, 1.0e-14_real64), 'native flux sign/scale')
  call require(near(trial%h_groundwater_m, 11.25_real64, 1.0e-13_real64), 'native head zero/scale')
  call groundwater_discard_candidate(conv_gateway, cand, status)
  call require(status == GW_EXCHANGE_OK .and. conv_backend%revision(1) == 0_int64 .and. &
       conv_backend%committed_value(1) == 0.0_real64, 'discard preserves committed state')

  ! Prepare/abort is transactional and blocks rebind until the reservation is released.
  call groundwater_trial_from_checkpoint(conv_gateway, cp, window, q_groundwater, cand, trial, status)
  call require(status == GW_EXCHANGE_OK, 'prepare/abort trial')
  call groundwater_prepare_candidate(conv_gateway, cp, cand, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. .not. conv_gateway%restart_quiescent(), 'prepared quiescence')
  call conv_gateway%bind(conv_backend, cfg_b, status)
  call require(status == GW_EXTERNAL_GATEWAY_NOT_QUIESCENT .and. conv_gateway%configured_cell_id() == 17_int64, &
       'prepared rebind rejected without mutation')
  call groundwater_abort_prepared(conv_gateway, cp, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. conv_gateway%restart_quiescent() .and. &
       conv_backend%revision(1) == 0_int64, 'abort restores quiescence without commit')

  ! Backend failures and partial responses fail closed. Stale external revision fails closed.
  call fail_gateway%bind(fail_backend, cfg_a, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'failure gateway bind')
  fail_backend%fail_capture = .true.
  call groundwater_capture_checkpoint(fail_gateway, cp, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. .not. cp%ready(), 'capture failure closed')
  fail_backend%fail_capture = .false.
  call groundwater_capture_checkpoint(fail_gateway, cp, status)
  call require(status == GW_EXCHANGE_OK, 'failure capture baseline')
  fail_backend%fail_trial = .true.
  call groundwater_trial_from_checkpoint(fail_gateway, cp, window, FLUX_SCALE_A, cand, trial, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. .not. cand%ready() .and. &
       fail_backend%revision(1) == 0_int64, 'trial backend failure closed')
  fail_backend%fail_trial = .false.
  fail_backend%partial_trial = .true.
  call groundwater_trial_from_checkpoint(fail_gateway, cp, window, FLUX_SCALE_A, cand, trial, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. .not. cand%ready() .and. &
       fail_backend%revision(1) == 0_int64 .and. fail_backend%committed_value(1) == 0.0_real64, &
       'partial response closed')
  fail_backend%partial_trial = .false.
  fail_backend%revision(1) = 1_int64
  call groundwater_trial_from_checkpoint(fail_gateway, cp, window, FLUX_SCALE_A, cand, trial, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. .not. cand%ready(), 'stale external revision closed')
  fail_backend%revision(1) = 0_int64

  ! A failed direct commit cannot partially publish; a successful candidate can publish exactly once.
  call direct_gateway%bind(direct_backend, cfg_c, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'direct gateway bind')
  call groundwater_capture_checkpoint(direct_gateway, cp, status)
  call require(status == GW_EXCHANGE_OK, 'direct capture')
  window = groundwater_coupling_window_t(t0=0.0_real64, t1=0.5_real64)
  call groundwater_trial_from_checkpoint(direct_gateway, cp, window, 3.0e-7_real64, cand, trial, status)
  call require(status == GW_EXCHANGE_OK, 'direct trial')
  direct_backend%fail_commit = .true.
  call groundwater_commit_candidate(direct_gateway, cp, cand, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. cp%ready() .and. cand%ready() .and. &
       direct_backend%revision(3) == 0_int64 .and. direct_backend%committed_value(3) == 0.0_real64, &
       'failed direct commit cannot partially publish')
  direct_backend%fail_commit = .false.
  cp_copy = cp
  cand_copy = cand
  call groundwater_commit_candidate(direct_gateway, cp, cand, status)
  call require(status == GW_EXCHANGE_OK .and. direct_backend%commit_successes(3) == 1 .and. &
       direct_backend%revision(3) == 1_int64, 'direct commit succeeds exactly once')
  call groundwater_commit_candidate(direct_gateway, cp_copy, cand_copy, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. direct_backend%commit_successes(3) == 1 .and. &
       direct_backend%revision(3) == 1_int64, 'direct candidate replay closed')

  ! Prepare failure is recoverable; prepared publication is one-shot at the admitted service wrapper.
  call prepared_gateway%bind(prepared_backend, cfg_d, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'prepared gateway bind')
  call groundwater_capture_checkpoint(prepared_gateway, cp, status)
  call require(status == GW_EXCHANGE_OK, 'prepared capture')
  window = groundwater_coupling_window_t(t0=0.0_real64, t1=0.25_real64)
  call groundwater_trial_from_checkpoint(prepared_gateway, cp, window, -1.0e-7_real64, cand, trial, status)
  call require(status == GW_EXCHANGE_OK, 'prepared trial')
  prepared_backend%fail_prepare = .true.
  call groundwater_prepare_candidate(prepared_gateway, cp, cand, prepared, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. cp%ready() .and. cand%ready() .and. &
       prepared_gateway%restart_quiescent(), 'prepare failure closed and reservation cancelled')
  prepared_backend%fail_prepare = .false.
  call groundwater_prepare_candidate(prepared_gateway, cp, cand, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. .not. prepared_gateway%restart_quiescent(), 'prepare succeeds')
  cp_copy = cp
  prepared_copy = prepared
  call groundwater_commit_prepared(prepared_gateway, cp, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. prepared_backend%prepared_successes(4) == 1 .and. &
       prepared_gateway%restart_quiescent(), 'prepared commit once')
  call groundwater_commit_prepared(prepared_gateway, cp_copy, prepared_copy, status)
  call require(status /= GW_EXCHANGE_OK .and. prepared_backend%prepared_successes(4) == 1, &
       'prepared replay rejected before backend publication')

  ! Batch rebind preflights every member before mutating any earlier binding.
  batch_initial = [cfg_a, cfg_b]
  call bind_groundwater_external_gateway_batch(batch_gateways, batch_backend, batch_initial, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'initial batch bind')
  call groundwater_capture_checkpoint(batch_gateways(2), cp, status)
  call require(status == GW_EXCHANGE_OK, 'batch member capture')
  window = groundwater_coupling_window_t(t0=0.0_real64, t1=0.2_real64)
  call groundwater_trial_from_checkpoint(batch_gateways(2), cp, window, FLUX_SCALE_B, cand, trial, status)
  call require(status == GW_EXCHANGE_OK, 'batch member trial')
  call groundwater_prepare_candidate(batch_gateways(2), cp, cand, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. .not. batch_gateways(2)%restart_quiescent(), 'batch member prepare')
  batch_rebind = [cfg_c, cfg_d]
  call bind_groundwater_external_gateway_batch(batch_gateways, batch_backend, batch_rebind, status)
  call require(status == GW_EXTERNAL_GATEWAY_NOT_QUIESCENT .and. &
       batch_gateways(1)%configured_cell_id() == 17_int64 .and. batch_gateways(2)%configured_cell_id() == 29_int64, &
       'batch rebind is preflight atomic')
  call groundwater_abort_prepared(batch_gateways(2), cp, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'batch cleanup abort')

  ! Independently configured gateways can share a backend without cross-talk.
  call shared_gateways(1)%bind(shared_backend, cfg_a, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'shared gateway A bind')
  call shared_gateways(2)%bind(shared_backend, cfg_b, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'shared gateway B bind')
  call groundwater_capture_checkpoint(shared_gateways(1), cp, status)
  call require(status == GW_EXCHANGE_OK, 'shared A capture')
  call groundwater_capture_checkpoint(shared_gateways(2), cp2, status)
  call require(status == GW_EXCHANGE_OK, 'shared B capture')
  window = groundwater_coupling_window_t(t0=0.0_real64, t1=0.1_real64)
  call groundwater_trial_from_checkpoint(shared_gateways(1), cp, window, FLUX_SCALE_A, cand, trial, status)
  call require(status == GW_EXCHANGE_OK, 'shared A trial')
  call groundwater_trial_from_checkpoint(shared_gateways(2), cp2, window, -FLUX_SCALE_B, cand2, trial2, status)
  call require(status == GW_EXCHANGE_OK, 'shared B trial')
  call require(near(shared_backend%last_flux_native(1), -1.0_real64, 1.0e-14_real64) .and. &
       near(shared_backend%last_flux_native(2), -1.0_real64, 1.0e-14_real64), 'shared backend independent native fluxes')
  call require(near(trial%h_groundwater_m, 11.25_real64, 1.0e-13_real64) .and. &
       near(trial2%h_groundwater_m, 1.0_real64, 1.0e-13_real64), 'shared backend independent head conversions')
  call groundwater_trial_from_checkpoint(shared_gateways(2), cp, window, FLUX_SCALE_A, cand_copy, trial2, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. .not. cand_copy%ready(), &
       'foreign checkpoint provenance rejected by external backend')
  call groundwater_discard_candidate(shared_gateways(1), cand, status)
  call require(status == GW_EXCHANGE_OK, 'shared A discard')
  call groundwater_discard_candidate(shared_gateways(2), cand2, status)
  call require(status == GW_EXCHANGE_OK .and. all(shared_backend%revision(1:2) == 0_int64), &
       'shared backend probes leave committed cells unchanged')

  call require(swap_physical_sentinel == 314159, 'qualification probes changed committed SWAP physical sentinel')

  print '(A)', 'FVQ96_DATUM_UNITS_SIGN_ROUNDTRIP=PASS'
  print '(A)', 'FVQ96_EQUAL_OPPOSITE_INTERFACE_MASS=PASS'
  print '(A)', 'FVQ96_TRANSACTION_DISCARD_PREPARE_ABORT=PASS'
  print '(A)', 'FVQ96_BACKEND_PARTIAL_STALE_FAILURES_FAIL_CLOSED=PASS'
  print '(A)', 'FVQ96_PREPARED_QUIESCENCE_REBIND=PASS'
  print '(A)', 'FVQ96_DIRECT_COMMIT_EXACTLY_ONCE=PASS'
  print '(A)', 'FVQ96_BATCH_REBIND_PREFLIGHT_ATOMIC=PASS'
  print '(A)', 'FVQ96_SHARED_BACKEND_NO_CROSSTALK=PASS'
  print '(A)', 'FVQ96_COMMITTED_PHYSICAL_STATE_PROBE=PASS'
  print '(A)', 'F-VQ96 F-GC26 INDEPENDENT BEHAVIOURAL ORACLE PASS'

contains

  pure logical function near(a, b, tol) result(ok)
    real(real64), intent(in) :: a, b, tol
    ok = abs(a - b) <= tol
  end function near

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write (*,'(A,A)') 'FVQ96 ASSERTION FAILED: ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq96_fgc26_external_gateway_independent

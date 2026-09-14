module fgc26_deterministic_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_external_gateway, only: external_groundwater_backend_t, GW_EXTERNAL_BACKEND_OK
  implicit none
  private

  integer, parameter :: MAX_CELLS = 8
  integer, parameter, public :: FAIL_NONE = 0
  integer, parameter, public :: FAIL_CAPTURE = 1
  integer, parameter, public :: FAIL_TRIAL = 2
  integer, parameter, public :: FAIL_PREPARE = 3
  integer, parameter, public :: FAIL_COMMIT = 4
  integer, parameter, public :: FAIL_DISCARD = 5
  integer, parameter, public :: PARTIAL_TRIAL = 6

  type, extends(external_groundwater_backend_t), public :: deterministic_backend_t
    integer(int64) :: revision(MAX_CELLS) = 0_int64
    integer(int64) :: lineage(MAX_CELLS) = 0_int64
    real(real64) :: origin_time(MAX_CELLS) = 0.0_real64
    real(real64) :: head_native(MAX_CELLS) = 0.0_real64
    real(real64) :: last_flux_native(MAX_CELLS) = 0.0_real64
    integer(int64) :: candidate_token(MAX_CELLS) = 0_int64
    integer(int64) :: prepare_token(MAX_CELLS) = 0_int64
    real(real64) :: candidate_t1(MAX_CELLS) = 0.0_real64
    integer(int64) :: next_candidate = 1_int64
    integer(int64) :: next_prepare = 1_int64
    integer :: fail_mode = FAIL_NONE
  contains
    procedure :: initialize => backend_initialize
    procedure :: capture => backend_capture
    procedure :: trial => backend_trial
    procedure :: commit_candidate => backend_commit_candidate
    procedure :: discard_candidate => backend_discard_candidate
    procedure :: prepare => backend_prepare
    procedure :: commit_prepared => backend_commit_prepared
    procedure :: abort_prepared => backend_abort_prepared
  end type deterministic_backend_t

contains

  subroutine backend_initialize(self)
    class(deterministic_backend_t), intent(inout) :: self
    integer :: i

    self%revision = 0_int64
    self%origin_time = 0.0_real64
    self%last_flux_native = 0.0_real64
    self%candidate_token = 0_int64
    self%prepare_token = 0_int64
    self%candidate_t1 = 0.0_real64
    self%next_candidate = 1_int64
    self%next_prepare = 1_int64
    self%fail_mode = FAIL_NONE
    do i = 1, MAX_CELLS
      self%lineage(i) = 1000_int64 + int(i, int64)
      self%head_native(i) = 100.0_real64 + 25.0_real64 * real(i, real64)
    end do
  end subroutine backend_initialize

  integer function cell_index(cell_id) result(idx)
    integer(int64), intent(in) :: cell_id
    idx = int(cell_id)
    if (cell_id < 1_int64 .or. cell_id > int(MAX_CELLS, int64)) idx = 0
  end function cell_index

  integer(int64) function expected_checkpoint_token(self, idx) result(token)
    class(deterministic_backend_t), intent(in) :: self
    integer, intent(in) :: idx
    token = 100000_int64 * int(idx, int64) + self%revision(idx) + 1_int64
  end function expected_checkpoint_token

  subroutine backend_capture(self, cell_id, lineage_id, origin_revision, origin_time, checkpoint_token, status)
    class(deterministic_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id
    integer(int64), intent(out) :: lineage_id, origin_revision, checkpoint_token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status
    integer :: idx

    lineage_id = 0_int64
    origin_revision = -1_int64
    origin_time = 0.0_real64
    checkpoint_token = 0_int64
    if (self%fail_mode == FAIL_CAPTURE) then
      status = 701
      return
    end if
    idx = cell_index(cell_id)
    if (idx == 0) then
      status = 799
      return
    end if
    lineage_id = self%lineage(idx)
    origin_revision = self%revision(idx)
    origin_time = self%origin_time(idx)
    checkpoint_token = expected_checkpoint_token(self, idx)
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_capture

  subroutine backend_trial(self, cell_id, checkpoint_token, t0, t1, flux_native, candidate_token, head_native, status)
    class(deterministic_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token
    real(real64), intent(in) :: t0, t1, flux_native
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: head_native
    integer, intent(out) :: status
    integer :: idx

    candidate_token = 0_int64
    head_native = 0.0_real64
    if (self%fail_mode == FAIL_TRIAL) then
      status = 702
      return
    end if
    idx = cell_index(cell_id)
    if (idx == 0) then
      status = 799
      return
    end if
    if (checkpoint_token /= expected_checkpoint_token(self, idx)) then
      status = 706
      return
    end if
    if (abs(t0 - self%origin_time(idx)) > 1.0e-12_real64 .or. t1 <= t0) then
      status = 708
      return
    end if
    self%last_flux_native(idx) = flux_native
    head_native = self%head_native(idx)
    if (self%fail_mode == PARTIAL_TRIAL) then
      candidate_token = 0_int64
      status = GW_EXTERNAL_BACKEND_OK
      return
    end if
    candidate_token = 200000000_int64 + 10000_int64 * int(idx, int64) + self%next_candidate
    self%next_candidate = self%next_candidate + 1_int64
    self%candidate_token(idx) = candidate_token
    self%candidate_t1(idx) = t1
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_trial

  subroutine backend_commit_candidate(self, cell_id, checkpoint_token, candidate_token, status)
    class(deterministic_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
    integer, intent(out) :: status
    integer :: idx

    if (self%fail_mode == FAIL_COMMIT) then
      status = 703
      return
    end if
    idx = cell_index(cell_id)
    if (idx == 0 .or. checkpoint_token /= expected_checkpoint_token(self, idx) .or. &
        candidate_token /= self%candidate_token(idx) .or. candidate_token <= 0_int64) then
      status = 704
      return
    end if
    self%revision(idx) = self%revision(idx) + 1_int64
    self%origin_time(idx) = self%candidate_t1(idx)
    self%candidate_token(idx) = 0_int64
    self%candidate_t1(idx) = 0.0_real64
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_commit_candidate

  subroutine backend_discard_candidate(self, cell_id, candidate_token, status)
    class(deterministic_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, candidate_token
    integer, intent(out) :: status
    integer :: idx

    if (self%fail_mode == FAIL_DISCARD) then
      status = 705
      return
    end if
    idx = cell_index(cell_id)
    if (idx == 0 .or. candidate_token /= self%candidate_token(idx) .or. candidate_token <= 0_int64) then
      status = 704
      return
    end if
    self%candidate_token(idx) = 0_int64
    self%candidate_t1(idx) = 0.0_real64
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_discard_candidate

  subroutine backend_prepare(self, cell_id, checkpoint_token, candidate_token, prepare_token, status)
    class(deterministic_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status
    integer :: idx

    prepare_token = 0_int64
    if (self%fail_mode == FAIL_PREPARE) then
      status = 707
      return
    end if
    idx = cell_index(cell_id)
    if (idx == 0 .or. checkpoint_token /= expected_checkpoint_token(self, idx) .or. &
        candidate_token /= self%candidate_token(idx) .or. candidate_token <= 0_int64) then
      status = 704
      return
    end if
    prepare_token = 300000000_int64 + 10000_int64 * int(idx, int64) + self%next_prepare
    self%next_prepare = self%next_prepare + 1_int64
    self%prepare_token(idx) = prepare_token
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_prepare

  subroutine backend_commit_prepared(self, cell_id, prepare_token)
    class(deterministic_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, prepare_token
    integer :: idx

    idx = cell_index(cell_id)
    if (idx == 0) error stop 2611
    if (prepare_token /= self%prepare_token(idx) .or. prepare_token <= 0_int64) error stop 2612
    self%revision(idx) = self%revision(idx) + 1_int64
    self%origin_time(idx) = self%candidate_t1(idx)
    self%prepare_token(idx) = 0_int64
    self%candidate_token(idx) = 0_int64
    self%candidate_t1(idx) = 0.0_real64
  end subroutine backend_commit_prepared

  subroutine backend_abort_prepared(self, cell_id, prepare_token)
    class(deterministic_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, prepare_token
    integer :: idx

    idx = cell_index(cell_id)
    if (idx == 0) error stop 2621
    if (prepare_token /= self%prepare_token(idx) .or. prepare_token <= 0_int64) error stop 2622
    self%prepare_token(idx) = 0_int64
    self%candidate_token(idx) = 0_int64
    self%candidate_t1(idx) = 0.0_real64
  end subroutine backend_abort_prepared

end module fgc26_deterministic_backend

program test_fgc26_external_groundwater_adapter_conformance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_discard_candidate, &
       groundwater_prepare_candidate, groundwater_commit_prepared, groundwater_abort_prepared, &
       GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED
  use mod_groundwater_external_gateway, only: groundwater_external_gateway_t, &
       groundwater_external_gateway_config_t, bind_groundwater_external_gateway_batch, &
       GW_EXTERNAL_GATEWAY_OK
  use fgc26_deterministic_backend, only: deterministic_backend_t, FAIL_NONE, FAIL_CAPTURE, FAIL_TRIAL, &
       FAIL_PREPARE, PARTIAL_TRIAL
  implicit none

  type(deterministic_backend_t), target :: backend
  type(groundwater_external_gateway_t) :: gateway, stale_gateway
  type(groundwater_external_gateway_t) :: batch(3)
  type(groundwater_external_gateway_config_t) :: config, batch_config(3)
  type(groundwater_exchange_checkpoint_t) :: checkpoint, stale_checkpoint, current_checkpoint
  type(groundwater_exchange_candidate_t) :: candidate
  type(groundwater_exchange_prepared_t) :: prepared
  type(groundwater_exchange_trial_result_t) :: trial_result
  type(groundwater_coupling_window_t) :: window
  real(real64), parameter :: CM_DAY_TO_M_S = 0.01_real64 / 86400.0_real64
  real(real64) :: origin_time
  logical :: available
  integer(int64) :: revision
  integer :: status, i

  call backend%initialize()

  config = groundwater_external_gateway_config_t(service_id=101_int64, cell_id=1_int64, &
       head_native_to_m_scale=0.01_real64, head_native_zero_m=40.0_real64, &
       flux_native_to_m_per_s_scale=CM_DAY_TO_M_S, native_flux_sign_relative_to_groundwater=-1)
  call gateway%bind(backend, config, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK .and. gateway%ready(), 'gateway bind')
  call stale_gateway%bind(backend, config, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'stale gateway bind')

  call groundwater_capture_checkpoint(stale_gateway, stale_checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'stale checkpoint capture')
  call groundwater_capture_checkpoint(gateway, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'checkpoint capture')

  window = groundwater_coupling_window_t(t0=0.0_real64, t1=0.5_real64)
  call groundwater_trial_from_checkpoint(gateway, checkpoint, window, 2.0_real64 * CM_DAY_TO_M_S, &
       candidate, trial_result, status)
  call require(status == GW_EXCHANGE_OK, 'trial')
  call require_close(backend%last_flux_native(1), -2.0_real64, 1.0e-12_real64, 'flux sign/unit conversion')
  call require_close(trial_result%h_groundwater_m, 41.25_real64, 1.0e-12_real64, 'head datum/unit conversion')
  print '(A)', 'FGC26_DATUM_UNIT_SIGN_ROUND_TRIP=PASS'

  call groundwater_discard_candidate(gateway, candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard')
  call require(backend%revision(1) == 0_int64, 'discard changed committed revision')

  call groundwater_trial_from_checkpoint(gateway, checkpoint, window, 1.0_real64 * CM_DAY_TO_M_S, &
       candidate, trial_result, status)
  call require(status == GW_EXCHANGE_OK, 'trial before abort')
  call groundwater_prepare_candidate(gateway, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. .not. gateway%restart_quiescent(), 'prepare')
  call groundwater_abort_prepared(gateway, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. gateway%restart_quiescent(), 'abort')
  call require(backend%revision(1) == 0_int64, 'abort changed committed revision')

  call groundwater_trial_from_checkpoint(gateway, checkpoint, window, 1.5_real64 * CM_DAY_TO_M_S, &
       candidate, trial_result, status)
  call require(status == GW_EXCHANGE_OK, 'trial before commit')
  call groundwater_prepare_candidate(gateway, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepare before commit')
  call groundwater_commit_prepared(gateway, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. gateway%restart_quiescent(), 'prepared commit')
  call require(backend%revision(1) == 1_int64, 'commit revision')

  call groundwater_capture_checkpoint(gateway, current_checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'post-commit capture')
  revision = current_checkpoint%origin_revision()
  call current_checkpoint%origin_time(origin_time, available)
  call require(revision == 1_int64 .and. available, 'post-commit revision/time')
  call require_close(origin_time, 0.5_real64, 1.0e-12_real64, 'post-commit time')
  print '(A)', 'FGC26_ROLLBACK_RESTART_HANDSHAKE=PASS'
  print '(A)', 'FGC26_PREPARED_PUBLICATION_QUIESCENT=PASS'

  call groundwater_trial_from_checkpoint(stale_gateway, stale_checkpoint, window, CM_DAY_TO_M_S, &
       candidate, trial_result, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. stale_gateway%last_backend_status() == 706, &
       'stale revision did not fail closed')
  print '(A)', 'FGC26_STALE_REVISION_FAIL_CLOSED=PASS'

  window = groundwater_coupling_window_t(t0=0.5_real64, t1=0.75_real64)
  backend%fail_mode = PARTIAL_TRIAL
  call groundwater_trial_from_checkpoint(gateway, current_checkpoint, window, CM_DAY_TO_M_S, &
       candidate, trial_result, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED, 'partial response did not fail closed')
  backend%fail_mode = FAIL_TRIAL
  call groundwater_trial_from_checkpoint(gateway, current_checkpoint, window, CM_DAY_TO_M_S, &
       candidate, trial_result, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. gateway%last_backend_status() == 702, &
       'trial failure did not propagate')
  backend%fail_mode = FAIL_PREPARE
  call groundwater_trial_from_checkpoint(gateway, current_checkpoint, window, CM_DAY_TO_M_S, &
       candidate, trial_result, status)
  call require(status == GW_EXCHANGE_OK, 'trial for prepare failure')
  call groundwater_prepare_candidate(gateway, current_checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. gateway%restart_quiescent(), &
       'prepare failure did not fail closed')
  call groundwater_discard_candidate(gateway, candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard after prepare failure')
  backend%fail_mode = FAIL_CAPTURE
  call groundwater_capture_checkpoint(gateway, checkpoint, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. gateway%last_backend_status() == 701, &
       'capture failure did not propagate')
  backend%fail_mode = FAIL_NONE
  print '(A)', 'FGC26_PARTIAL_RESPONSE_FAIL_CLOSED=PASS'
  print '(A)', 'FGC26_ADAPTER_FAILURE_FAIL_CLOSED=PASS'

  do i = 1, 3
    batch_config(i) = groundwater_external_gateway_config_t(service_id=200_int64 + int(i, int64), &
         cell_id=1_int64 + int(i, int64), head_native_to_m_scale=0.01_real64, &
         head_native_zero_m=40.0_real64 + real(i, real64), flux_native_to_m_per_s_scale=CM_DAY_TO_M_S, &
         native_flux_sign_relative_to_groundwater=1)
  end do
  call bind_groundwater_external_gateway_batch(batch, backend, batch_config, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'batch bind')
  window = groundwater_coupling_window_t(t0=0.0_real64, t1=0.25_real64)
  do i = 1, 3
    call groundwater_capture_checkpoint(batch(i), checkpoint, status)
    call require(status == GW_EXCHANGE_OK, 'batch capture')
    call groundwater_trial_from_checkpoint(batch(i), checkpoint, window, real(i, real64) * CM_DAY_TO_M_S, &
         candidate, trial_result, status)
    call require(status == GW_EXCHANGE_OK, 'batch trial')
    call require_close(backend%last_flux_native(i+1), real(i, real64), 1.0e-12_real64, 'batch flux isolation')
    call groundwater_discard_candidate(batch(i), candidate, status)
    call require(status == GW_EXCHANGE_OK, 'batch discard')
  end do
  call require(all(backend%candidate_token(2:4) == 0_int64), 'batch candidate leakage')
  print '(A)', 'FGC26_MULTI_CELL_BATCH_ISOLATION=PASS'
  print '(A)', 'FGC26_TYPED_SERVICE_CONFORMANCE=PASS'
  print '(A)', 'F-GC26 EXTERNAL GROUNDWATER ADAPTER CONFORMANCE GATE PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write (*,'(A,A)') 'ASSERTION FAILED: ', trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, label)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    call require(abs(actual - expected) <= tolerance, label)
  end subroutine require_close

end program test_fgc26_external_groundwater_adapter_conformance

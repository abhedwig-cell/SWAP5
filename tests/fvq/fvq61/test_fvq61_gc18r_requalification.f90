module mod_fvq61_adversarial_groundwater_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_INVALID_CHECKPOINT, GW_EXCHANGE_INVALID_CANDIDATE, &
       GW_EXCHANGE_STALE_CANDIDATE, GW_EXCHANGE_ALREADY_PREPARED
  implicit none
  private

  type, extends(groundwater_preparable_exchange_service_t), public :: fvq61_backend_t
    integer(int64) :: service_id_value = 6101_int64
    integer(int64) :: lineage_id_value = 6181_int64
    integer(int64) :: committed_revision = 10_int64
    real(real64) :: committed_time = 7300.25_real64
    real(real64) :: committed_head = 4.25_real64
    integer(int64) :: next_checkpoint_token = 900_int64
    integer(int64) :: checkpoint_token = 0_int64
    integer(int64) :: checkpoint_revision = -1_int64
    integer(int64) :: next_candidate_token = 1900_int64
    integer(int64) :: candidate_token = 0_int64
    integer(int64) :: candidate_checkpoint_token = 0_int64
    integer(int64) :: candidate_origin_revision = -1_int64
    real(real64) :: candidate_t1 = 0.0_real64
    real(real64) :: candidate_head = 0.0_real64
    logical :: candidate_active = .false.
    logical :: reservation_active = .false.
    integer(int64) :: reservation_token = 610061_int64
    integer(int64) :: reserved_candidate_token = 0_int64
    integer :: trial_calls = 0
    integer :: prepare_calls = 0
    integer :: prepared_commit_calls = 0
    integer :: prepared_abort_calls = 0
  contains
    procedure :: capture_backend => fvq61_capture
    procedure :: trial_backend => fvq61_trial
    procedure :: commit_backend => fvq61_direct_commit
    procedure :: discard_backend => fvq61_discard
    procedure :: prepare_backend => fvq61_prepare
    procedure :: commit_prepared_backend => fvq61_commit_prepared
    procedure :: abort_prepared_backend => fvq61_abort_prepared
  end type fvq61_backend_t

contains

  subroutine fvq61_capture(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(fvq61_backend_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status

    self%next_checkpoint_token = self%next_checkpoint_token + 1_int64
    self%checkpoint_token = self%next_checkpoint_token
    self%checkpoint_revision = self%committed_revision
    service_id = self%service_id_value
    lineage_id = self%lineage_id_value
    origin_revision = self%committed_revision
    origin_time = self%committed_time
    token = self%checkpoint_token
    status = GW_EXCHANGE_OK
  end subroutine fvq61_capture

  subroutine fvq61_trial(self, checkpoint_token, window, q_groundwater_m_per_s, candidate_token, h_groundwater_m, status)
    class(fvq61_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status

    self%trial_calls = self%trial_calls + 1
    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
    if (self%reservation_active) then
      status = GW_EXCHANGE_ALREADY_PREPARED
      return
    end if
    if (checkpoint_token /= self%checkpoint_token) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (self%checkpoint_revision /= self%committed_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if
    if (q_groundwater_m_per_s /= q_groundwater_m_per_s) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if

    self%next_candidate_token = self%next_candidate_token + 1_int64
    self%candidate_token = self%next_candidate_token
    self%candidate_checkpoint_token = checkpoint_token
    self%candidate_origin_revision = self%committed_revision
    self%candidate_t1 = window%t1
    self%candidate_head = self%committed_head + 0.001_real64 * real(self%trial_calls, real64)
    self%candidate_active = .true.
    candidate_token = self%candidate_token
    h_groundwater_m = self%candidate_head
    status = GW_EXCHANGE_OK
  end subroutine fvq61_trial

  subroutine fvq61_direct_commit(self, checkpoint_token, candidate_token, status)
    class(fvq61_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status

    if (self%reservation_active) then
      status = GW_EXCHANGE_ALREADY_PREPARED
      return
    end if
    if (checkpoint_token /= self%checkpoint_token) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (.not. self%candidate_active .or. candidate_token /= self%candidate_token) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    if (self%candidate_origin_revision /= self%committed_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if
    call publish_candidate(self)
    status = GW_EXCHANGE_OK
  end subroutine fvq61_direct_commit

  subroutine fvq61_discard(self, candidate_token, status)
    class(fvq61_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status

    if (.not. self%candidate_active .or. candidate_token /= self%candidate_token) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    if (self%reservation_active .and. candidate_token == self%reserved_candidate_token) then
      status = GW_EXCHANGE_ALREADY_PREPARED
      return
    end if
    self%candidate_active = .false.
    status = GW_EXCHANGE_OK
  end subroutine fvq61_discard

  subroutine fvq61_prepare(self, checkpoint_token, candidate_token, prepare_token, status)
    class(fvq61_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status

    self%prepare_calls = self%prepare_calls + 1
    prepare_token = 0_int64
    if (self%reservation_active) then
      status = GW_EXCHANGE_ALREADY_PREPARED
      return
    end if
    if (checkpoint_token /= self%checkpoint_token) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (.not. self%candidate_active .or. candidate_token /= self%candidate_token) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    if (self%candidate_checkpoint_token /= checkpoint_token) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    if (self%checkpoint_revision /= self%committed_revision .or. &
        self%candidate_origin_revision /= self%committed_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if

    ! Deliberately reuse the same opaque backend token for every reservation.
    ! Correct replay protection must therefore come from wrapper-owned identity.
    self%reservation_active = .true.
    self%reserved_candidate_token = candidate_token
    prepare_token = self%reservation_token
    status = GW_EXCHANGE_OK
  end subroutine fvq61_prepare

  subroutine fvq61_commit_prepared(self, prepare_token)
    class(fvq61_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (.not. self%reservation_active) error stop 'FVQ61 backend replay reached prepared commit without reservation'
    if (prepare_token /= self%reservation_token) error stop 'FVQ61 backend received wrong prepared commit token'
    if (.not. self%candidate_active .or. self%reserved_candidate_token /= self%candidate_token) &
         error stop 'FVQ61 backend prepared candidate missing'
    if (self%candidate_origin_revision /= self%committed_revision) &
         error stop 'FVQ61 backend prepared candidate stale'
    self%prepared_commit_calls = self%prepared_commit_calls + 1
    call publish_candidate(self)
    self%reservation_active = .false.
    self%reserved_candidate_token = 0_int64
  end subroutine fvq61_commit_prepared

  subroutine fvq61_abort_prepared(self, prepare_token)
    class(fvq61_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (.not. self%reservation_active) error stop 'FVQ61 backend replay reached prepared abort without reservation'
    if (prepare_token /= self%reservation_token) error stop 'FVQ61 backend received wrong prepared abort token'
    self%prepared_abort_calls = self%prepared_abort_calls + 1
    self%reservation_active = .false.
    self%reserved_candidate_token = 0_int64
  end subroutine fvq61_abort_prepared

  subroutine publish_candidate(self)
    class(fvq61_backend_t), intent(inout) :: self

    if (self%committed_revision >= huge(0_int64)) error stop 'FVQ61 fake backend revision overflow'
    self%committed_revision = self%committed_revision + 1_int64
    self%committed_time = self%candidate_t1
    self%committed_head = self%candidate_head
    self%candidate_active = .false.
  end subroutine publish_candidate

end module mod_fvq61_adversarial_groundwater_backend

program test_fvq61_gc18r_requalification
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_discard_candidate, &
       groundwater_prepare_candidate, groundwater_commit_prepared, groundwater_abort_prepared, &
       GW_EXCHANGE_OK, GW_EXCHANGE_STALE_PREPARED, GW_EXCHANGE_REVISION_EXHAUSTED
  use mod_fvq61_adversarial_groundwater_backend, only: fvq61_backend_t
  implicit none

  type(fvq61_backend_t) :: service, near_limit_service, exhausted_service
  type(groundwater_exchange_checkpoint_t) :: checkpoint, stale_abort_checkpoint, stale_commit_checkpoint, &
       near_limit_checkpoint, exhausted_checkpoint
  type(groundwater_exchange_candidate_t) :: candidate, near_limit_candidate, exhausted_candidate
  type(groundwater_exchange_prepared_t) :: prepared, stale_abort_prepared, stale_commit_prepared
  type(groundwater_exchange_trial_result_t) :: result
  type(groundwater_coupling_window_t) :: window, boundary_window
  integer(int64) :: revision_before_commit, revision_after_commit
  integer :: status, abort_calls_before, commit_calls_before, trial_calls_before

  call groundwater_capture_checkpoint(service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture for first reservation')
  window%t0 = service%committed_time
  window%t1 = window%t0 + 0.125_real64
  call groundwater_trial_from_checkpoint(service, checkpoint, window, 1.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK .and. candidate%ready(), 'trial for first reservation')
  call groundwater_prepare_candidate(service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. prepared%ready(), 'first prepare')
  stale_abort_checkpoint = checkpoint
  stale_abort_prepared = prepared

  call groundwater_abort_prepared(service, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'legitimate first abort')
  call require(service%prepared_abort_calls == 1, 'first abort did not reach backend exactly once')
  call require(checkpoint%ready() .and. .not. checkpoint%is_prepared(), 'aborted checkpoint not reusable')

  ! Prepare a new live reservation with exactly the same opaque backend token.
  call groundwater_trial_from_checkpoint(service, checkpoint, window, 2.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial after abort')
  call groundwater_prepare_candidate(service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. service%reservation_active, 'second prepare with reused token')

  abort_calls_before = service%prepared_abort_calls
  call groundwater_abort_prepared(service, stale_abort_checkpoint, stale_abort_prepared, status)
  call require(status == GW_EXCHANGE_STALE_PREPARED, 'copied stale abort did not fail closed')
  call require(service%prepared_abort_calls == abort_calls_before, 'copied stale abort reached backend')
  call require(service%reservation_active, 'copied stale abort destroyed new live reservation')
  call require(prepared%ready() .and. checkpoint%is_prepared(), 'copied stale abort damaged live wrapper handles')

  stale_commit_checkpoint = checkpoint
  stale_commit_prepared = prepared
  revision_before_commit = service%committed_revision
  call groundwater_commit_prepared(service, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'legitimate prepared commit')
  call require(service%prepared_commit_calls == 1, 'prepared commit did not reach backend exactly once')
  call require(service%committed_revision == revision_before_commit + 1_int64, 'legitimate commit revision mismatch')
  revision_after_commit = service%committed_revision

  commit_calls_before = service%prepared_commit_calls
  call groundwater_commit_prepared(service, stale_commit_checkpoint, stale_commit_prepared, status)
  call require(status == GW_EXCHANGE_STALE_PREPARED, 'copied stale commit did not fail closed')
  call require(service%prepared_commit_calls == commit_calls_before, 'copied stale commit reached backend')
  call require(service%committed_revision == revision_after_commit, 'copied stale commit published twice')

  ! The last representable successor must remain valid.
  near_limit_service%committed_revision = huge(0_int64) - 1_int64
  call groundwater_capture_checkpoint(near_limit_service, near_limit_checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'near-limit capture')
  boundary_window%t0 = near_limit_service%committed_time
  boundary_window%t1 = boundary_window%t0 + 0.0625_real64
  call groundwater_trial_from_checkpoint(near_limit_service, near_limit_checkpoint, boundary_window, &
       1.0e-8_real64, near_limit_candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'INT64_MAX-1 to INT64_MAX rejected')
  call require(near_limit_candidate%candidate_revision() == huge(0_int64), 'last legal revision incorrect')
  call require(near_limit_candidate%ready(), 'last legal candidate not ready')
  call groundwater_discard_candidate(near_limit_service, near_limit_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'near-limit candidate discard')

  ! INT64_MAX has no successor. The wrapper must reject before trial_backend.
  exhausted_service%committed_revision = huge(0_int64)
  call groundwater_capture_checkpoint(exhausted_service, exhausted_checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'INT64_MAX capture')
  boundary_window%t0 = exhausted_service%committed_time
  boundary_window%t1 = boundary_window%t0 + 0.0625_real64
  trial_calls_before = exhausted_service%trial_calls
  call groundwater_trial_from_checkpoint(exhausted_service, exhausted_checkpoint, boundary_window, &
       1.0e-8_real64, exhausted_candidate, result, status)
  call require(status == GW_EXCHANGE_REVISION_EXHAUSTED, 'INT64_MAX origin did not fail closed')
  call require(result%status == GW_EXCHANGE_REVISION_EXHAUSTED, 'result omitted revision exhaustion')
  call require(exhausted_service%trial_calls == trial_calls_before, 'revision exhaustion reached backend trial')
  call require(.not. exhausted_candidate%ready(), 'revision-exhausted candidate became ready')

  print '(a)', 'FVQ61_INDEPENDENT_BACKEND=PASS'
  print '(a)', 'FVQ61_COPIED_ABORT_REPLAY_BLOCKED_WITH_TOKEN_REUSE=PASS'
  print '(a)', 'FVQ61_COPIED_COMMIT_REPLAY_BLOCKED=PASS'
  print '(a)', 'FVQ61_NO_DUPLICATE_GROUNDWATER_PUBLICATION=PASS'
  print '(a)', 'FVQ61_INT64_LAST_SUCCESSOR_VALID=PASS'
  print '(a)', 'FVQ61_INT64_EXHAUSTION_PREBACKEND=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FVQ61_FAIL: '//trim(message)
      error stop 61
    end if
  end subroutine require

end program test_fvq61_gc18r_requalification

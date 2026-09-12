module mod_fvq61_adversarial_service
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED
  implicit none
  private

  type, extends(groundwater_preparable_exchange_service_t), public :: adversarial_service_t
    integer(int64) :: service_id = 6101_int64
    integer(int64) :: lineage_id = 6102_int64
    integer(int64) :: committed_revision = 21_int64
    real(real64) :: committed_time = 321.25_real64
    integer(int64) :: checkpoint_token = 6111_int64
    integer(int64) :: candidate_token = 6121_int64
    integer(int64) :: prepare_token = 6131_int64
    logical :: reject_prepare = .false.
    integer :: trial_calls = 0
    integer :: prepare_calls = 0
    integer :: commit_calls = 0
    integer :: abort_calls = 0
    integer :: discard_calls = 0
    real(real64) :: publication_marker = 0.0_real64
  contains
    procedure :: capture_backend => adversarial_capture_backend
    procedure :: trial_backend => adversarial_trial_backend
    procedure :: commit_backend => adversarial_commit_backend
    procedure :: discard_backend => adversarial_discard_backend
    procedure :: prepare_backend => adversarial_prepare_backend
    procedure :: commit_prepared_backend => adversarial_commit_prepared_backend
    procedure :: abort_prepared_backend => adversarial_abort_prepared_backend
  end type adversarial_service_t

contains

  subroutine adversarial_capture_backend(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status
    service_id = self%service_id
    lineage_id = self%lineage_id
    origin_revision = self%committed_revision
    origin_time = self%committed_time
    token = self%checkpoint_token
    status = GW_EXCHANGE_OK
  end subroutine adversarial_capture_backend

  subroutine adversarial_trial_backend(self, checkpoint_token, window, q_groundwater_m_per_s, &
                                       candidate_token, h_groundwater_m, status)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status

    self%trial_calls = self%trial_calls + 1
    if (checkpoint_token /= self%checkpoint_token) error stop 'FVQ61 checkpoint token mismatch'
    if (window%t1 <= window%t0) error stop 'FVQ61 invalid verifier window'
    if (q_groundwater_m_per_s /= q_groundwater_m_per_s) error stop 'FVQ61 invalid verifier flux'
    candidate_token = self%candidate_token
    h_groundwater_m = 6.75_real64
    status = GW_EXCHANGE_OK
  end subroutine adversarial_trial_backend

  subroutine adversarial_commit_backend(self, checkpoint_token, candidate_token, status)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status
    if (checkpoint_token /= self%checkpoint_token .or. candidate_token /= self%candidate_token) &
      error stop 'FVQ61 direct commit token mismatch'
    self%committed_revision = self%committed_revision + 1_int64
    status = GW_EXCHANGE_OK
  end subroutine adversarial_commit_backend

  subroutine adversarial_discard_backend(self, candidate_token, status)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status
    if (candidate_token /= self%candidate_token) error stop 'FVQ61 discard token mismatch'
    self%discard_calls = self%discard_calls + 1
    status = GW_EXCHANGE_OK
  end subroutine adversarial_discard_backend

  subroutine adversarial_prepare_backend(self, checkpoint_token, candidate_token, prepare_token, status)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status
    self%prepare_calls = self%prepare_calls + 1
    if (checkpoint_token /= self%checkpoint_token .or. candidate_token /= self%candidate_token) &
      error stop 'FVQ61 prepare token mismatch'
    if (self%reject_prepare) then
      prepare_token = 0_int64
      status = GW_EXCHANGE_BACKEND_REJECTED
      return
    end if
    ! Intentionally reuse one opaque backend token forever. The verifier backend
    ! provides no one-shot reservation registry of its own.
    prepare_token = self%prepare_token
    status = GW_EXCHANGE_OK
  end subroutine adversarial_prepare_backend

  subroutine adversarial_commit_prepared_backend(self, prepare_token)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token
    if (prepare_token /= self%prepare_token) error stop 'FVQ61 prepared token mismatch'
    self%commit_calls = self%commit_calls + 1
    self%publication_marker = self%publication_marker + 1.0_real64
    self%committed_revision = self%committed_revision + 1_int64
  end subroutine adversarial_commit_prepared_backend

  subroutine adversarial_abort_prepared_backend(self, prepare_token)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token
    if (prepare_token /= self%prepare_token) error stop 'FVQ61 abort token mismatch'
    self%abort_calls = self%abort_calls + 1
  end subroutine adversarial_abort_prepared_backend

end module mod_fvq61_adversarial_service

program test_fvq61_gc18r_r1_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_discard_candidate, &
       groundwater_prepare_candidate, groundwater_commit_prepared, groundwater_abort_prepared, &
       GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED, GW_EXCHANGE_ORIGIN_MISMATCH, &
       GW_EXCHANGE_STALE_PREPARED, GW_EXCHANGE_REVISION_EXHAUSTED
  use mod_fvq61_adversarial_service, only: adversarial_service_t
  implicit none

  type(adversarial_service_t) :: service, abort_service, alias_service, refusal_service
  type(adversarial_service_t) :: service_a, service_b, near_limit_service, exhausted_service
  type(groundwater_exchange_checkpoint_t) :: checkpoint, checkpoint_copy, checkpoint_a, checkpoint_b
  type(groundwater_exchange_checkpoint_t) :: live_checkpoint, stale_checkpoint_copy
  type(groundwater_exchange_candidate_t) :: candidate, candidate_a, near_limit_candidate, exhausted_candidate
  type(groundwater_exchange_prepared_t) :: prepared, prepared_copy, live_prepared, stale_prepared_copy
  type(groundwater_exchange_trial_result_t) :: result
  type(groundwater_coupling_window_t) :: window
  integer :: status, prepare_calls_before, trial_calls_before
  integer(int64) :: revision_after_first, refusal_revision, alias_revision
  real(real64) :: refusal_time

  ! Probe 0: backend prepare refusal leaves checkpoint/candidate reusable and
  ! does not mutate the committed origin.
  refusal_service%reject_prepare = .true.
  call groundwater_capture_checkpoint(refusal_service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture for prepare refusal')
  window%t0 = refusal_service%committed_time
  window%t1 = window%t0 + 0.0625_real64
  refusal_revision = refusal_service%committed_revision
  refusal_time = refusal_service%committed_time
  call groundwater_trial_from_checkpoint(refusal_service, checkpoint, window, 1.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial for prepare refusal')
  call groundwater_prepare_candidate(refusal_service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED, 'prepare refusal status')
  call require(checkpoint%ready() .and. .not. checkpoint%is_prepared(), 'prepare refusal changed checkpoint')
  call require(candidate%ready() .and. .not. prepared%ready(), 'prepare refusal consumed handles')
  call require(refusal_service%committed_revision == refusal_revision .and. &
       refusal_service%committed_time == refusal_time, 'prepare refusal changed committed origin')
  print '(a)', 'FVQ61_PREPARE_REFUSAL_PRESERVES_COMMITTED_STATE=PASS'

  ! Probe 0b: mismatched participant provenance fails before backend prepare.
  service_b%service_id = 6201_int64
  service_b%lineage_id = 6202_int64
  service_b%checkpoint_token = 6211_int64
  service_b%candidate_token = 6221_int64
  service_b%prepare_token = 6231_int64
  call groundwater_capture_checkpoint(service_a, checkpoint_a, status)
  call require(status == GW_EXCHANGE_OK, 'capture participant A')
  window%t0 = service_a%committed_time
  window%t1 = window%t0 + 0.09375_real64
  call groundwater_trial_from_checkpoint(service_a, checkpoint_a, window, 1.5e-7_real64, candidate_a, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial participant A')
  call groundwater_capture_checkpoint(service_b, checkpoint_b, status)
  call require(status == GW_EXCHANGE_OK, 'capture participant B')
  prepare_calls_before = service_a%prepare_calls
  call groundwater_prepare_candidate(service_a, checkpoint_b, candidate_a, prepared, status)
  call require(status == GW_EXCHANGE_ORIGIN_MISMATCH, 'participant mismatch not rejected')
  call require(service_a%prepare_calls == prepare_calls_before, 'participant mismatch reached backend prepare')
  call require(candidate_a%ready() .and. checkpoint_b%ready(), 'participant mismatch consumed handles')
  print '(a)', 'FVQ61_INVALID_PARTICIPANT_REJECTED_BEFORE_PREPARE=PASS'

  ! Probe 1: copied prepared commit must be rejected by the wrapper itself.
  ! The backend intentionally has no one-shot state, so any second backend call
  ! would reproduce the original F-VQ60 B2 defect.
  call groundwater_capture_checkpoint(service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture for copied commit')
  window%t0 = service%committed_time
  window%t1 = window%t0 + 0.1875_real64
  call groundwater_trial_from_checkpoint(service, checkpoint, window, 2.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial for copied commit')
  call groundwater_prepare_candidate(service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepare for copied commit')
  checkpoint_copy = checkpoint
  prepared_copy = prepared
  call groundwater_commit_prepared(service, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. service%commit_calls == 1, 'first prepared publication')
  revision_after_first = service%committed_revision
  call groundwater_commit_prepared(service, checkpoint_copy, prepared_copy, status)
  call require(status == GW_EXCHANGE_STALE_PREPARED, 'copied commit did not fail stale')
  call require(service%commit_calls == 1, 'copied commit reached backend')
  call require(service%committed_revision == revision_after_first, 'copied commit mutated committed revision')
  call require(abs(service%publication_marker - 1.0_real64) < epsilon(1.0_real64), 'duplicate publication marker')
  print '(a)', 'FVQ61_COPIED_COMMIT_REPLAY_REJECTED_BEFORE_BACKEND=PASS'
  print '(a)', 'FVQ61_NO_DUPLICATE_PUBLICATION=PASS'

  ! Probe 2: copied abort likewise must be one-shot at the wrapper boundary.
  call groundwater_capture_checkpoint(abort_service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture for copied abort')
  window%t0 = abort_service%committed_time
  window%t1 = window%t0 + 0.125_real64
  call groundwater_trial_from_checkpoint(abort_service, checkpoint, window, 3.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial for copied abort')
  call groundwater_prepare_candidate(abort_service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepare for copied abort')
  checkpoint_copy = checkpoint
  prepared_copy = prepared
  alias_revision = abort_service%committed_revision
  call groundwater_abort_prepared(abort_service, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. abort_service%abort_calls == 1, 'first abort')
  call require(abort_service%committed_revision == alias_revision, 'abort changed committed revision')
  call groundwater_abort_prepared(abort_service, checkpoint_copy, prepared_copy, status)
  call require(status == GW_EXCHANGE_STALE_PREPARED, 'copied abort did not fail stale')
  call require(abort_service%abort_calls == 1, 'copied abort reached backend')
  call require(abort_service%committed_revision == alias_revision, 'copied abort changed committed state')
  print '(a)', 'FVQ61_COPIED_ABORT_REPLAY_REJECTED_BEFORE_BACKEND=PASS'
  print '(a)', 'FVQ61_ABORT_PRESERVES_COMMITTED_STATE=PASS'

  ! Probe 3: stronger alias test. Abort generation N, then reuse the exact same
  ! backend prepare token in generation N+1. A stale copy from N must not consume
  ! the live N+1 reservation and the live transaction must still commit once.
  call groundwater_capture_checkpoint(alias_service, live_checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture alias transaction')
  window%t0 = alias_service%committed_time
  window%t1 = window%t0 + 0.15625_real64
  call groundwater_trial_from_checkpoint(alias_service, live_checkpoint, window, 2.5e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial alias transaction')
  call groundwater_prepare_candidate(alias_service, live_checkpoint, candidate, live_prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepare alias generation N')
  stale_checkpoint_copy = live_checkpoint
  stale_prepared_copy = live_prepared
  alias_revision = alias_service%committed_revision
  call groundwater_abort_prepared(alias_service, live_checkpoint, live_prepared, status)
  call require(status == GW_EXCHANGE_OK .and. alias_service%abort_calls == 1, 'abort alias generation N')
  call require(alias_service%committed_revision == alias_revision, 'alias abort changed revision')

  call groundwater_trial_from_checkpoint(alias_service, live_checkpoint, window, 2.75e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial alias generation N+1')
  call groundwater_prepare_candidate(alias_service, live_checkpoint, candidate, live_prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepare alias generation N+1')
  call groundwater_abort_prepared(alias_service, stale_checkpoint_copy, stale_prepared_copy, status)
  call require(status == GW_EXCHANGE_STALE_PREPARED, 'stale generation aliased live reservation')
  call require(alias_service%abort_calls == 1, 'stale generation reached abort backend')
  call require(live_checkpoint%ready() .and. live_checkpoint%is_prepared(), 'stale generation damaged live checkpoint')
  call require(live_prepared%ready(), 'stale generation damaged live prepared handle')
  call groundwater_commit_prepared(alias_service, live_checkpoint, live_prepared, status)
  call require(status == GW_EXCHANGE_OK, 'live generation commit after stale replay')
  call require(alias_service%commit_calls == 1, 'live generation publication count')
  call require(alias_service%committed_revision == alias_revision + 1_int64, 'live generation revision')
  print '(a)', 'FVQ61_BACKEND_TOKEN_REUSE_GENERATION_GUARDED=PASS'

  ! Probe 4: the final representable successor remains legal.
  near_limit_service%committed_revision = huge(0_int64) - 1_int64
  call groundwater_capture_checkpoint(near_limit_service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'near-limit capture')
  window%t0 = near_limit_service%committed_time
  window%t1 = window%t0 + 0.03125_real64
  call groundwater_trial_from_checkpoint(near_limit_service, checkpoint, window, 4.0e-8_real64, &
       near_limit_candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'last legal revision advance rejected')
  call require(near_limit_candidate%ready(), 'last legal candidate not ready')
  call require(result%candidate_revision == huge(0_int64), 'last legal candidate revision incorrect')
  call groundwater_discard_candidate(near_limit_service, near_limit_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard last legal candidate')
  print '(a)', 'FVQ61_LAST_LEGAL_REVISION_ADVANCE=PASS'

  ! Probe 5: INT64_MAX has no successor and must fail before trial_backend.
  exhausted_service%committed_revision = huge(0_int64)
  call groundwater_capture_checkpoint(exhausted_service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'exhausted capture')
  window%t0 = exhausted_service%committed_time
  window%t1 = window%t0 + 0.03125_real64
  trial_calls_before = exhausted_service%trial_calls
  call groundwater_trial_from_checkpoint(exhausted_service, checkpoint, window, 5.0e-8_real64, &
       exhausted_candidate, result, status)
  call require(status == GW_EXCHANGE_REVISION_EXHAUSTED, 'revision exhaustion status')
  call require(result%status == GW_EXCHANGE_REVISION_EXHAUSTED, 'revision exhaustion result status')
  call require(.not. exhausted_candidate%ready(), 'revision exhaustion produced ready candidate')
  call require(exhausted_service%trial_calls == trial_calls_before, 'revision exhaustion reached backend trial')
  print '(a)', 'FVQ61_REVISION_EXHAUSTION_FAILS_BEFORE_BACKEND=PASS'

  print '(a)', 'FVQ61_INDEPENDENT_NEGATIVE_PATH_AUDIT=PASS_BLOCKERS_CLOSED'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FVQ61_AUDIT_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fvq61_gc18r_r1_independent

module mod_fvq60_adversarial_service
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       GW_EXCHANGE_OK
  implicit none
  private

  type, extends(groundwater_preparable_exchange_service_t), public :: adversarial_service_t
    integer(int64) :: service_id = 6001_int64
    integer(int64) :: lineage_id = 6002_int64
    integer(int64) :: committed_revision = 12_int64
    real(real64) :: committed_time = 123.25_real64
    integer(int64) :: checkpoint_token = 6101_int64
    integer(int64) :: candidate_token = 6201_int64
    integer(int64) :: prepare_token = 6301_int64
    integer :: commit_calls = 0
    integer :: abort_calls = 0
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
    if (checkpoint_token /= self%checkpoint_token) error stop 'FVQ60 checkpoint token mismatch'
    if (window%t1 <= window%t0) error stop 'FVQ60 invalid verifier window'
    if (q_groundwater_m_per_s /= q_groundwater_m_per_s) error stop 'FVQ60 invalid verifier flux'
    candidate_token = self%candidate_token
    h_groundwater_m = 7.25_real64
    status = GW_EXCHANGE_OK
  end subroutine adversarial_trial_backend

  subroutine adversarial_commit_backend(self, checkpoint_token, candidate_token, status)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status
    if (checkpoint_token /= self%checkpoint_token .or. candidate_token /= self%candidate_token) &
      error stop 'FVQ60 direct commit token mismatch'
    self%committed_revision = self%committed_revision + 1_int64
    status = GW_EXCHANGE_OK
  end subroutine adversarial_commit_backend

  subroutine adversarial_discard_backend(self, candidate_token, status)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status
    if (candidate_token /= self%candidate_token) error stop 'FVQ60 discard token mismatch'
    status = GW_EXCHANGE_OK
  end subroutine adversarial_discard_backend

  subroutine adversarial_prepare_backend(self, checkpoint_token, candidate_token, prepare_token, status)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status
    if (checkpoint_token /= self%checkpoint_token .or. candidate_token /= self%candidate_token) &
      error stop 'FVQ60 prepare token mismatch'
    prepare_token = self%prepare_token
    status = GW_EXCHANGE_OK
  end subroutine adversarial_prepare_backend

  subroutine adversarial_commit_prepared_backend(self, prepare_token)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token
    if (prepare_token /= self%prepare_token) error stop 'FVQ60 prepared token mismatch'
    self%commit_calls = self%commit_calls + 1
    self%publication_marker = self%publication_marker + 1.0_real64
    self%committed_revision = self%committed_revision + 1_int64
  end subroutine adversarial_commit_prepared_backend

  subroutine adversarial_abort_prepared_backend(self, prepare_token)
    class(adversarial_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token
    if (prepare_token /= self%prepare_token) error stop 'FVQ60 abort token mismatch'
    self%abort_calls = self%abort_calls + 1
  end subroutine adversarial_abort_prepared_backend

end module mod_fvq60_adversarial_service

program test_fvq60_gc18r_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_prepare_candidate, &
       groundwater_commit_prepared, groundwater_abort_prepared, GW_EXCHANGE_OK
  use mod_fvq60_adversarial_service, only: adversarial_service_t
  implicit none

  type(adversarial_service_t) :: service, abort_service, overflow_service
  type(groundwater_exchange_checkpoint_t) :: checkpoint, checkpoint_copy
  type(groundwater_exchange_candidate_t) :: candidate
  type(groundwater_exchange_prepared_t) :: prepared, prepared_copy
  type(groundwater_exchange_trial_result_t) :: result
  type(groundwater_coupling_window_t) :: window
  integer :: status
  integer(int64) :: revision_after_first

  ! Probe 1: copied opaque values can replay an already published prepared handle.
  call groundwater_capture_checkpoint(service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture for replay probe')
  window%t0 = service%committed_time
  window%t1 = window%t0 + 0.1875_real64
  call groundwater_trial_from_checkpoint(service, checkpoint, window, 2.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial for replay probe')
  call groundwater_prepare_candidate(service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepare for replay probe')

  checkpoint_copy = checkpoint
  prepared_copy = prepared
  call groundwater_commit_prepared(service, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. service%commit_calls == 1, 'first prepared publication')
  revision_after_first = service%committed_revision

  call groundwater_commit_prepared(service, checkpoint_copy, prepared_copy, status)
  call require(status == GW_EXCHANGE_OK, 'copied stale prepared handle was rejected by wrapper')
  call require(service%commit_calls == 2, 'copied stale prepared handle did not reach backend')
  call require(service%committed_revision == revision_after_first + 1_int64, 'replayed publication did not mutate state twice')
  call require(abs(service%publication_marker - 2.0_real64) < epsilon(1.0_real64), 'publication marker not duplicated')
  print '(a)', 'FVQ60_BLOCKER_COPIED_PREPARED_REPLAY_REACHES_PUBLICATION=REPRODUCED'

  ! Probe 2: a copied prepared handle can replay abort after the original was consumed.
  call groundwater_capture_checkpoint(abort_service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture for abort replay probe')
  window%t0 = abort_service%committed_time
  window%t1 = window%t0 + 0.125_real64
  call groundwater_trial_from_checkpoint(abort_service, checkpoint, window, 3.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial for abort replay probe')
  call groundwater_prepare_candidate(abort_service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepare for abort replay probe')
  checkpoint_copy = checkpoint
  prepared_copy = prepared
  call groundwater_abort_prepared(abort_service, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. abort_service%abort_calls == 1, 'first abort')
  call groundwater_abort_prepared(abort_service, checkpoint_copy, prepared_copy, status)
  call require(status == GW_EXCHANGE_OK .and. abort_service%abort_calls == 2, 'copied stale abort did not replay')
  print '(a)', 'FVQ60_BLOCKER_COPIED_PREPARED_ABORT_REPLAY=REPRODUCED'

  ! Probe 3: INT64_MAX origin revision is accepted even though +1 cannot be represented.
  overflow_service%committed_revision = huge(0_int64)
  call groundwater_capture_checkpoint(overflow_service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'max revision checkpoint unexpectedly rejected')
  window%t0 = overflow_service%committed_time
  window%t1 = window%t0 + 0.25_real64
  call groundwater_trial_from_checkpoint(overflow_service, checkpoint, window, 4.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'max revision trial did not expose unchecked increment')
  call require(candidate%ready(), 'overflowed candidate is not reported ready')
  call require(result%candidate_revision < 0_int64, 'candidate revision did not overflow negative as expected')
  print '(a)', 'FVQ60_BLOCKER_REVISION_OVERFLOW_ACCEPTED=REPRODUCED'

  print '(a)', 'FVQ60_ADVERSARIAL_AUDIT=PASS_BLOCKERS_CONFIRMED'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FVQ60_AUDIT_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fvq60_gc18r_independent

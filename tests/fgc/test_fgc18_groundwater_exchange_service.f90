module mod_fgc18_fake_groundwater_service
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_INVALID_CHECKPOINT, GW_EXCHANGE_INVALID_CANDIDATE, &
       GW_EXCHANGE_STALE_CANDIDATE
  implicit none
  private

  type, extends(groundwater_exchange_service_t), public :: fake_groundwater_service_t
    integer(int64) :: service_id = 71_int64
    integer(int64) :: lineage_id = 901_int64
    integer(int64) :: committed_revision = 4_int64
    real(real64) :: committed_time = 4100.125_real64
    real(real64) :: committed_head_m = 12.25_real64
    integer(int64) :: next_checkpoint_token = 100_int64
    integer(int64) :: active_checkpoint_token = 0_int64
    integer(int64) :: active_checkpoint_revision = -1_int64
    real(real64) :: active_checkpoint_time = 0.0_real64
    integer :: n_candidates = 0
    integer(int64) :: candidate_token(16) = 0_int64
    integer(int64) :: candidate_origin_revision(16) = -1_int64
    real(real64) :: candidate_t1(16) = 0.0_real64
    real(real64) :: candidate_head_m(16) = 0.0_real64
    logical :: candidate_active(16) = .false.
    integer :: trial_calls = 0
    integer :: commit_calls = 0
    integer :: discard_calls = 0
  contains
    procedure :: capture_backend => fake_capture_backend
    procedure :: trial_backend => fake_trial_backend
    procedure :: commit_backend => fake_commit_backend
    procedure :: discard_backend => fake_discard_backend
  end type fake_groundwater_service_t

contains

  subroutine fake_capture_backend(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(fake_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status

    self%next_checkpoint_token = self%next_checkpoint_token + 1_int64
    self%active_checkpoint_token = self%next_checkpoint_token
    self%active_checkpoint_revision = self%committed_revision
    self%active_checkpoint_time = self%committed_time

    service_id = self%service_id
    lineage_id = self%lineage_id
    origin_revision = self%committed_revision
    origin_time = self%committed_time
    token = self%active_checkpoint_token
    status = GW_EXCHANGE_OK
  end subroutine fake_capture_backend

  subroutine fake_trial_backend(self, checkpoint_token, window, q_groundwater_m_per_s, &
                                candidate_token, h_groundwater_m, status)
    class(fake_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status
    integer :: slot

    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
    status = GW_EXCHANGE_INVALID_CHECKPOINT
    if (checkpoint_token /= self%active_checkpoint_token) return
    if (self%committed_revision /= self%active_checkpoint_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if
    if (self%n_candidates >= size(self%candidate_token)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if

    self%trial_calls = self%trial_calls + 1
    self%n_candidates = self%n_candidates + 1
    slot = self%n_candidates
    self%candidate_token(slot) = 1000_int64 + int(slot, int64)
    self%candidate_origin_revision(slot) = self%committed_revision
    self%candidate_t1(slot) = window%t1
    ! Structural fake only. The head value distinguishes candidates but is not
    ! a groundwater-physics model and deliberately makes no constitutive claim.
    self%candidate_head_m(slot) = self%committed_head_m + 0.001_real64 * real(slot, real64)
    self%candidate_active(slot) = .true.

    candidate_token = self%candidate_token(slot)
    h_groundwater_m = self%candidate_head_m(slot)
    if (q_groundwater_m_per_s /= q_groundwater_m_per_s) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    status = GW_EXCHANGE_OK
  end subroutine fake_trial_backend

  subroutine fake_commit_backend(self, checkpoint_token, candidate_token, status)
    class(fake_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status
    integer :: slot

    self%commit_calls = self%commit_calls + 1
    status = GW_EXCHANGE_INVALID_CHECKPOINT
    if (checkpoint_token /= self%active_checkpoint_token) return

    slot = locate_candidate(self, candidate_token)
    status = GW_EXCHANGE_INVALID_CANDIDATE
    if (slot <= 0) return
    if (.not. self%candidate_active(slot)) return

    if (self%candidate_origin_revision(slot) /= self%committed_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if
    if (self%active_checkpoint_revision /= self%committed_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if

    self%committed_head_m = self%candidate_head_m(slot)
    self%committed_time = self%candidate_t1(slot)
    self%committed_revision = self%committed_revision + 1_int64
    self%candidate_active(slot) = .false.
    status = GW_EXCHANGE_OK
  end subroutine fake_commit_backend

  subroutine fake_discard_backend(self, candidate_token, status)
    class(fake_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status
    integer :: slot

    self%discard_calls = self%discard_calls + 1
    slot = locate_candidate(self, candidate_token)
    status = GW_EXCHANGE_INVALID_CANDIDATE
    if (slot <= 0) return
    if (.not. self%candidate_active(slot)) return
    self%candidate_active(slot) = .false.
    status = GW_EXCHANGE_OK
  end subroutine fake_discard_backend

  integer function locate_candidate(self, token) result(slot)
    class(fake_groundwater_service_t), intent(in) :: self
    integer(int64), intent(in) :: token
    integer :: i

    slot = 0
    do i = 1, self%n_candidates
      if (self%candidate_token(i) == token) then
        slot = i
        return
      end if
    end do
  end function locate_candidate

end module mod_fgc18_fake_groundwater_service

program test_fgc18_groundwater_exchange_service
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, &
       groundwater_commit_candidate, groundwater_discard_candidate, &
       GW_EXCHANGE_OK, GW_EXCHANGE_ORIGIN_MISMATCH, GW_EXCHANGE_STALE_CANDIDATE
  use mod_fgc18_fake_groundwater_service, only: fake_groundwater_service_t
  implicit none

  type(fake_groundwater_service_t) :: service
  type(groundwater_exchange_checkpoint_t) :: checkpoint, stale_checkpoint, checkpoint2
  type(groundwater_exchange_candidate_t) :: discarded_candidate, predictor_candidate, corrector_candidate, invalid_candidate
  type(groundwater_exchange_trial_result_t) :: result
  type(groundwater_coupling_window_t) :: window, wrong_window
  real(real64) :: head0, time0, origin_time
  integer(int64) :: revision0
  integer :: status, trials_before
  logical :: available

  call groundwater_capture_checkpoint(service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK .and. checkpoint%ready(), 'capture failed')
  call require(checkpoint%service_id() == 71_int64, 'service id')
  call require(checkpoint%lineage_id() == 901_int64, 'lineage id')
  call require(checkpoint%origin_revision() == 4_int64, 'origin revision')
  call checkpoint%origin_time(origin_time, available)
  call require(available .and. abs(origin_time-4100.125_real64) < 1.0e-12_real64, 'origin time')

  window%t0 = 4100.125_real64
  window%t1 = 4100.3125_real64
  head0 = service%committed_head_m
  time0 = service%committed_time
  revision0 = service%committed_revision

  call groundwater_trial_from_checkpoint(service, checkpoint, window, 2.0e-7_real64, &
       discarded_candidate, result, status)
  call require(status == GW_EXCHANGE_OK .and. discarded_candidate%ready(), 'discard trial failed')
  call require(result%status == GW_EXCHANGE_OK, 'trial result status')
  call require(result%q_groundwater_m_per_s == 2.0e-7_real64, 'trial flux transport')
  call require(service%committed_revision == revision0 .and. service%committed_time == time0 .and. &
       service%committed_head_m == head0, 'trial mutated committed groundwater state')

  call groundwater_discard_candidate(service, discarded_candidate, status)
  call require(status == GW_EXCHANGE_OK .and. .not. discarded_candidate%ready(), 'discard failed')
  call require(service%committed_revision == revision0 .and. service%committed_time == time0 .and. &
       service%committed_head_m == head0, 'discard mutated committed groundwater state')

  call groundwater_trial_from_checkpoint(service, checkpoint, window, 1.0e-7_real64, &
       predictor_candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'predictor trial')
  call groundwater_trial_from_checkpoint(service, checkpoint, window, 1.5e-7_real64, &
       corrector_candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'corrector trial')
  call require(predictor_candidate%origin_revision() == revision0, 'predictor origin')
  call require(corrector_candidate%origin_revision() == revision0, 'corrector origin')
  call require(predictor_candidate%candidate_revision() == revision0+1_int64, 'predictor candidate revision')
  call require(corrector_candidate%candidate_revision() == revision0+1_int64, 'corrector candidate revision')

  stale_checkpoint = checkpoint
  call groundwater_commit_candidate(service, checkpoint, corrector_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'corrector commit')
  call require(.not. checkpoint%ready() .and. .not. corrector_candidate%ready(), 'commit handle invalidation')
  call require(service%committed_revision == revision0+1_int64, 'commit revision')
  call require(abs(service%committed_time-window%t1) < 1.0e-12_real64, 'commit time')

  call groundwater_commit_candidate(service, stale_checkpoint, predictor_candidate, status)
  call require(status == GW_EXCHANGE_STALE_CANDIDATE, 'stale candidate was not rejected')
  call require(service%committed_revision == revision0+1_int64, 'stale commit changed revision')
  call groundwater_discard_candidate(service, predictor_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'stale candidate cleanup')

  call groundwater_capture_checkpoint(service, checkpoint2, status)
  call require(status == GW_EXCHANGE_OK .and. checkpoint2%origin_revision() == revision0+1_int64, 'second capture')
  wrong_window%t0 = window%t1 + 0.01_real64
  wrong_window%t1 = wrong_window%t0 + 0.125_real64
  trials_before = service%trial_calls
  call groundwater_trial_from_checkpoint(service, checkpoint2, wrong_window, 1.0e-7_real64, &
       invalid_candidate, result, status)
  call require(status == GW_EXCHANGE_ORIGIN_MISMATCH, 'wrong-origin window accepted')
  call require(.not. invalid_candidate%ready(), 'invalid candidate published')
  call require(service%trial_calls == trials_before, 'backend called for invalid origin')

  print '(a)', 'FGC18_TRANSACTIONAL_GW_SERVICE=PASS'
  print '(a)', 'FGC18_TRIAL_DOES_NOT_MUTATE_COMMITTED=PASS'
  print '(a)', 'FGC18_DISCARD_LEAVES_COMMITTED=PASS'
  print '(a)', 'FGC18_SAME_ORIGIN_MULTI_TRIAL=PASS'
  print '(a)', 'FGC18_COMMIT_ONCE_AND_STALE_REJECT=PASS'
  print '(a)', 'FGC18_NONMIDNIGHT_GENERIC_WINDOW=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC18_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fgc18_groundwater_exchange_service

module mod_fgc18r_fake_preparable_service
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_INVALID_CHECKPOINT, GW_EXCHANGE_INVALID_CANDIDATE, &
       GW_EXCHANGE_STALE_CANDIDATE, GW_EXCHANGE_ALREADY_PREPARED
  implicit none
  private

  type, extends(groundwater_preparable_exchange_service_t), public :: fake_preparable_service_t
    integer(int64) :: service_id = 1801_int64
    integer(int64) :: lineage_id = 4401_int64
    integer(int64) :: committed_revision = 7_int64
    real(real64) :: committed_time = 5100.375_real64
    real(real64) :: committed_head_m = 8.4_real64
    integer(int64) :: next_checkpoint_token = 200_int64
    integer(int64) :: next_candidate_token = 1000_int64
    integer(int64) :: next_prepare_token = 5000_int64
    integer(int64) :: checkpoint_token(8) = 0_int64
    integer(int64) :: checkpoint_revision(8) = -1_int64
    real(real64) :: checkpoint_time(8) = 0.0_real64
    integer :: n_checkpoints = 0
    integer(int64) :: candidate_token(16) = 0_int64
    integer(int64) :: candidate_checkpoint_token(16) = 0_int64
    integer(int64) :: candidate_origin_revision(16) = -1_int64
    real(real64) :: candidate_t1(16) = 0.0_real64
    real(real64) :: candidate_head_m(16) = 0.0_real64
    logical :: candidate_active(16) = .false.
    integer :: n_candidates = 0
    logical :: reservation_active = .false.
    integer(int64) :: reservation_token = 0_int64
    integer(int64) :: reserved_checkpoint_token = 0_int64
    integer(int64) :: reserved_candidate_token = 0_int64
    integer :: prepare_calls = 0
    integer :: prepared_commit_calls = 0
    integer :: prepared_abort_calls = 0
  contains
    procedure :: capture_backend => fake_capture_backend
    procedure :: trial_backend => fake_trial_backend
    procedure :: commit_backend => fake_commit_backend
    procedure :: discard_backend => fake_discard_backend
    procedure :: prepare_backend => fake_prepare_backend
    procedure :: commit_prepared_backend => fake_commit_prepared_backend
    procedure :: abort_prepared_backend => fake_abort_prepared_backend
  end type fake_preparable_service_t

contains

  subroutine fake_capture_backend(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(fake_preparable_service_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status
    integer :: slot

    if (self%n_checkpoints >= size(self%checkpoint_token)) then
      service_id = 0_int64; lineage_id = 0_int64; origin_revision = -1_int64
      origin_time = 0.0_real64; token = 0_int64; status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    self%n_checkpoints = self%n_checkpoints + 1
    slot = self%n_checkpoints
    self%next_checkpoint_token = self%next_checkpoint_token + 1_int64
    self%checkpoint_token(slot) = self%next_checkpoint_token
    self%checkpoint_revision(slot) = self%committed_revision
    self%checkpoint_time(slot) = self%committed_time
    service_id = self%service_id
    lineage_id = self%lineage_id
    origin_revision = self%committed_revision
    origin_time = self%committed_time
    token = self%checkpoint_token(slot)
    status = GW_EXCHANGE_OK
  end subroutine fake_capture_backend

  subroutine fake_trial_backend(self, checkpoint_token, window, q_groundwater_m_per_s, candidate_token, h_groundwater_m, status)
    class(fake_preparable_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status
    integer :: cslot, kslot

    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
    if (self%reservation_active) then
      status = GW_EXCHANGE_ALREADY_PREPARED
      return
    end if
    kslot = locate_checkpoint(self, checkpoint_token)
    if (kslot <= 0) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (self%checkpoint_revision(kslot) /= self%committed_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if
    if (self%n_candidates >= size(self%candidate_token)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if

    self%n_candidates = self%n_candidates + 1
    cslot = self%n_candidates
    self%next_candidate_token = self%next_candidate_token + 1_int64
    self%candidate_token(cslot) = self%next_candidate_token
    self%candidate_checkpoint_token(cslot) = checkpoint_token
    self%candidate_origin_revision(cslot) = self%committed_revision
    self%candidate_t1(cslot) = window%t1
    self%candidate_head_m(cslot) = self%committed_head_m + 0.002_real64*real(cslot, real64)
    self%candidate_active(cslot) = .true.
    candidate_token = self%candidate_token(cslot)
    h_groundwater_m = self%candidate_head_m(cslot)
    if (q_groundwater_m_per_s /= q_groundwater_m_per_s) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    status = GW_EXCHANGE_OK
  end subroutine fake_trial_backend

  subroutine fake_commit_backend(self, checkpoint_token, candidate_token, status)
    class(fake_preparable_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status
    integer :: cslot, kslot

    if (self%reservation_active) then
      status = GW_EXCHANGE_ALREADY_PREPARED
      return
    end if
    kslot = locate_checkpoint(self, checkpoint_token)
    cslot = locate_candidate(self, candidate_token)
    if (kslot <= 0) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (cslot <= 0 .or. .not. self%candidate_active(cslot)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    if (self%checkpoint_revision(kslot) /= self%committed_revision .or. &
        self%candidate_origin_revision(cslot) /= self%committed_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if
    call publish_candidate(self, cslot)
    status = GW_EXCHANGE_OK
  end subroutine fake_commit_backend

  subroutine fake_discard_backend(self, candidate_token, status)
    class(fake_preparable_service_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status
    integer :: cslot

    cslot = locate_candidate(self, candidate_token)
    if (cslot <= 0 .or. .not. self%candidate_active(cslot)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    if (self%reservation_active .and. candidate_token == self%reserved_candidate_token) then
      status = GW_EXCHANGE_ALREADY_PREPARED
      return
    end if
    self%candidate_active(cslot) = .false.
    status = GW_EXCHANGE_OK
  end subroutine fake_discard_backend

  subroutine fake_prepare_backend(self, checkpoint_token, candidate_token, prepare_token, status)
    class(fake_preparable_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status
    integer :: cslot, kslot

    self%prepare_calls = self%prepare_calls + 1
    prepare_token = 0_int64
    if (self%reservation_active) then
      status = GW_EXCHANGE_ALREADY_PREPARED
      return
    end if
    kslot = locate_checkpoint(self, checkpoint_token)
    cslot = locate_candidate(self, candidate_token)
    if (kslot <= 0) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (cslot <= 0 .or. .not. self%candidate_active(cslot)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    if (self%candidate_checkpoint_token(cslot) /= checkpoint_token) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    if (self%checkpoint_revision(kslot) /= self%committed_revision .or. &
        self%candidate_origin_revision(cslot) /= self%committed_revision) then
      status = GW_EXCHANGE_STALE_CANDIDATE
      return
    end if

    self%next_prepare_token = self%next_prepare_token + 1_int64
    self%reservation_active = .true.
    self%reservation_token = self%next_prepare_token
    self%reserved_checkpoint_token = checkpoint_token
    self%reserved_candidate_token = candidate_token
    prepare_token = self%reservation_token
    status = GW_EXCHANGE_OK
  end subroutine fake_prepare_backend

  subroutine fake_commit_prepared_backend(self, prepare_token)
    class(fake_preparable_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token
    integer :: cslot

    if (.not. self%reservation_active) error stop 'FGC18R invalid prepared commit: no reservation'
    if (prepare_token /= self%reservation_token) error stop 'FGC18R invalid prepared commit token'
    cslot = locate_candidate(self, self%reserved_candidate_token)
    if (cslot <= 0 .or. .not. self%candidate_active(cslot)) error stop 'FGC18R prepared candidate unavailable'
    if (self%candidate_origin_revision(cslot) /= self%committed_revision) error stop 'FGC18R prepared candidate stale'
    self%prepared_commit_calls = self%prepared_commit_calls + 1
    call publish_candidate(self, cslot)
    call clear_reservation(self)
  end subroutine fake_commit_prepared_backend

  subroutine fake_abort_prepared_backend(self, prepare_token)
    class(fake_preparable_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (.not. self%reservation_active) error stop 'FGC18R invalid prepared abort: no reservation'
    if (prepare_token /= self%reservation_token) error stop 'FGC18R invalid prepared abort token'
    self%prepared_abort_calls = self%prepared_abort_calls + 1
    call clear_reservation(self)
  end subroutine fake_abort_prepared_backend

  subroutine publish_candidate(self, cslot)
    class(fake_preparable_service_t), intent(inout) :: self
    integer, intent(in) :: cslot
    self%committed_head_m = self%candidate_head_m(cslot)
    self%committed_time = self%candidate_t1(cslot)
    self%committed_revision = self%committed_revision + 1_int64
    self%candidate_active(cslot) = .false.
  end subroutine publish_candidate

  subroutine clear_reservation(self)
    class(fake_preparable_service_t), intent(inout) :: self
    self%reservation_active = .false.
    self%reservation_token = 0_int64
    self%reserved_checkpoint_token = 0_int64
    self%reserved_candidate_token = 0_int64
  end subroutine clear_reservation

  integer function locate_checkpoint(self, token) result(slot)
    class(fake_preparable_service_t), intent(in) :: self
    integer(int64), intent(in) :: token
    integer :: i
    slot = 0
    do i = 1, self%n_checkpoints
      if (self%checkpoint_token(i) == token) then
        slot = i
        return
      end if
    end do
  end function locate_checkpoint

  integer function locate_candidate(self, token) result(slot)
    class(fake_preparable_service_t), intent(in) :: self
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

end module mod_fgc18r_fake_preparable_service

program test_fgc18r_prepared_commit
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_commit_candidate, &
       groundwater_prepare_candidate, groundwater_commit_prepared, groundwater_abort_prepared, &
       GW_EXCHANGE_OK, GW_EXCHANGE_ALREADY_PREPARED, GW_EXCHANGE_STALE_CANDIDATE
  use mod_fgc18r_fake_preparable_service, only: fake_preparable_service_t
  implicit none

  type(fake_preparable_service_t) :: service
  type(groundwater_exchange_checkpoint_t) :: checkpoint, stale_checkpoint, commit_checkpoint
  type(groundwater_exchange_candidate_t) :: candidate, stale_candidate, commit_candidate, blocked_candidate
  type(groundwater_exchange_prepared_t) :: prepared
  type(groundwater_exchange_trial_result_t) :: result
  type(groundwater_coupling_window_t) :: window, next_window
  integer(int64) :: revision0
  real(real64) :: time0, head0
  integer :: status, prepare_calls_before

  call groundwater_capture_checkpoint(service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'initial checkpoint')
  window%t0 = service%committed_time
  window%t1 = window%t0 + 0.1875_real64
  revision0 = service%committed_revision
  time0 = service%committed_time
  head0 = service%committed_head_m

  call groundwater_trial_from_checkpoint(service, checkpoint, window, 2.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK .and. candidate%ready(), 'trial before prepare')
  call groundwater_prepare_candidate(service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepare failed')
  call require(prepared%ready() .and. checkpoint%is_prepared(), 'prepared handle state')
  call require(.not. candidate%ready(), 'candidate not consumed by prepare')
  call require(service%committed_revision == revision0 .and. service%committed_time == time0 .and. &
       service%committed_head_m == head0, 'prepare mutated committed state')

  prepare_calls_before = service%prepare_calls
  call groundwater_trial_from_checkpoint(service, checkpoint, window, 3.0e-7_real64, blocked_candidate, result, status)
  call require(status == GW_EXCHANGE_ALREADY_PREPARED, 'trial allowed during prepare reservation')
  call require(service%prepare_calls == prepare_calls_before, 'unexpected prepare call count change')

  call groundwater_abort_prepared(service, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'abort failed')
  call require(checkpoint%ready() .and. .not. checkpoint%is_prepared(), 'checkpoint not reusable after abort')
  call require(.not. prepared%ready(), 'prepared handle survived abort')
  call require(service%prepared_abort_calls == 1, 'abort backend count')
  call require(service%committed_revision == revision0 .and. service%committed_time == time0 .and. &
       service%committed_head_m == head0, 'abort mutated committed state')

  call groundwater_trial_from_checkpoint(service, checkpoint, window, 4.0e-7_real64, candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'trial after abort')
  call groundwater_prepare_candidate(service, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'second prepare')
  call groundwater_commit_prepared(service, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK, 'prepared commit wrapper')
  call require(service%prepared_commit_calls == 1, 'prepared commit count')
  call require(service%committed_revision == revision0+1_int64, 'prepared commit revision')
  call require(abs(service%committed_time-window%t1) < 1.0e-12_real64, 'prepared commit time')
  call require(.not. checkpoint%ready() .and. .not. prepared%ready(), 'commit handles not consumed')

  call groundwater_commit_prepared(service, checkpoint, prepared, status)
  call require(status /= GW_EXCHANGE_OK, 'duplicate prepared commit accepted')
  call require(service%prepared_commit_calls == 1, 'duplicate commit reached backend')

  ! Create two independent checkpoints at the same committed revision. Commit
  ! through one, then prove the other candidate is rejected during prepare by
  ! the backend's live revision guard rather than being published.
  call groundwater_capture_checkpoint(service, stale_checkpoint, status)
  call groundwater_capture_checkpoint(service, commit_checkpoint, status)
  next_window%t0 = service%committed_time
  next_window%t1 = next_window%t0 + 0.125_real64
  call groundwater_trial_from_checkpoint(service, stale_checkpoint, next_window, 1.0e-7_real64, &
       stale_candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'stale candidate creation')
  call groundwater_trial_from_checkpoint(service, commit_checkpoint, next_window, 1.5e-7_real64, &
       commit_candidate, result, status)
  call require(status == GW_EXCHANGE_OK, 'commit candidate creation')
  call groundwater_commit_candidate(service, commit_checkpoint, commit_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'independent direct commit')
  prepare_calls_before = service%prepare_calls
  call groundwater_prepare_candidate(service, stale_checkpoint, stale_candidate, prepared, status)
  call require(status == GW_EXCHANGE_STALE_CANDIDATE, 'stale candidate prepared')
  call require(.not. prepared%ready() .and. stale_candidate%ready(), 'failed prepare consumed candidate')
  call require(service%prepare_calls == prepare_calls_before+1, 'stale prepare did not reach backend guard')

  print '(a)', 'FGC18R_PREPARE_ABORT_NO_PUBLICATION=PASS'
  print '(a)', 'FGC18R_PREPARE_BLOCKS_NEW_TRIAL=PASS'
  print '(a)', 'FGC18R_PREPARED_COMMIT_ONCE=PASS'
  print '(a)', 'FGC18R_STALE_PREPARE_REJECTED=PASS'
  print '(a)', 'FGC18R_NO_RECOVERABLE_FINAL_COMMIT_STATUS=PASS'
  print '(a)', 'FGC18R_BASE_SERVICE_ABI_RETAINED=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC18R_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fgc18r_prepared_commit

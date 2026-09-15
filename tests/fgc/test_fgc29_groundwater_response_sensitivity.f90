module mod_fgc29_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_INVALID_CHECKPOINT, GW_EXCHANGE_INVALID_CANDIDATE, &
       GW_EXCHANGE_STALE_CANDIDATE
  use mod_groundwater_response_sensitivity_contract, only: groundwater_response_sensitivity_provider_t, &
       GW_RESPONSE_PROVIDER_AVAILABLE, GW_RESPONSE_PROVIDER_UNAVAILABLE, &
       GW_RESPONSE_PROVIDER_NONSMOOTH, GW_RESPONSE_PROVIDER_ERROR
  implicit none
  private

  integer, parameter, public :: PROVIDER_MODE_AVAILABLE = 0
  integer, parameter, public :: PROVIDER_MODE_UNAVAILABLE = 1
  integer, parameter, public :: PROVIDER_MODE_NONSMOOTH = 2
  integer, parameter, public :: PROVIDER_MODE_ERROR = 3
  integer, parameter, public :: PROVIDER_MODE_NONFINITE = 4

  type, extends(groundwater_exchange_service_t), public :: smooth_groundwater_service_t
    integer(int64) :: service_id = 2901_int64
    integer(int64) :: lineage_id = 29001_int64
    integer(int64) :: committed_revision = 12_int64
    real(real64) :: committed_time = 6200.375_real64
    real(real64) :: committed_head_m = 7.25_real64
    real(real64) :: alpha_s = 2.0e6_real64
    real(real64) :: beta_s2_per_m = 5.0e12_real64
    integer(int64) :: next_checkpoint_token = 100_int64
    integer(int64) :: next_candidate_token = 1000_int64
    integer(int64) :: checkpoint_token(8) = 0_int64
    integer(int64) :: checkpoint_revision(8) = -1_int64
    real(real64) :: checkpoint_time(8) = 0.0_real64
    integer :: n_checkpoints = 0
    integer(int64) :: candidate_token(32) = 0_int64
    integer(int64) :: candidate_checkpoint_token(32) = 0_int64
    integer(int64) :: candidate_origin_revision(32) = -1_int64
    real(real64) :: candidate_t1(32) = 0.0_real64
    real(real64) :: candidate_q(32) = 0.0_real64
    real(real64) :: candidate_h(32) = 0.0_real64
    logical :: candidate_active(32) = .false.
    integer :: n_candidates = 0
    integer :: trial_calls = 0
    integer :: commit_calls = 0
    integer :: discard_calls = 0
  contains
    procedure :: capture_backend => fixture_capture_backend
    procedure :: trial_backend => fixture_trial_backend
    procedure :: commit_backend => fixture_commit_backend
    procedure :: discard_backend => fixture_discard_backend
  end type smooth_groundwater_service_t

  type, extends(groundwater_response_sensitivity_provider_t), public :: analytic_response_provider_t
    integer :: mode = PROVIDER_MODE_AVAILABLE
    integer :: calls = 0
    real(real64) :: alpha_s = 2.0e6_real64
    real(real64) :: beta_s2_per_m = 5.0e12_real64
  contains
    procedure :: evaluate_response_sensitivity => fixture_response_sensitivity
  end type analytic_response_provider_t

contains

  subroutine fixture_capture_backend(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(smooth_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status
    integer :: slot

    if (self%n_checkpoints >= size(self%checkpoint_token)) then
      service_id = 0_int64
      lineage_id = 0_int64
      origin_revision = -1_int64
      origin_time = 0.0_real64
      token = 0_int64
      status = GW_EXCHANGE_INVALID_CHECKPOINT
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
  end subroutine fixture_capture_backend

  subroutine fixture_trial_backend(self, checkpoint_token, window, q_groundwater_m_per_s, &
       candidate_token, h_groundwater_m, status)
    class(smooth_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status
    integer :: kslot, cslot

    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
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
    self%candidate_q(cslot) = q_groundwater_m_per_s
    self%candidate_h(cslot) = self%committed_head_m + self%alpha_s*q_groundwater_m_per_s + &
         self%beta_s2_per_m*q_groundwater_m_per_s*q_groundwater_m_per_s
    self%candidate_active(cslot) = .true.
    self%trial_calls = self%trial_calls + 1

    candidate_token = self%candidate_token(cslot)
    h_groundwater_m = self%candidate_h(cslot)
    status = GW_EXCHANGE_OK
  end subroutine fixture_trial_backend

  subroutine fixture_commit_backend(self, checkpoint_token, candidate_token, status)
    class(smooth_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status
    integer :: kslot, cslot

    self%commit_calls = self%commit_calls + 1
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

    self%committed_head_m = self%candidate_h(cslot)
    self%committed_time = self%candidate_t1(cslot)
    self%committed_revision = self%committed_revision + 1_int64
    self%candidate_active(cslot) = .false.
    status = GW_EXCHANGE_OK
  end subroutine fixture_commit_backend

  subroutine fixture_discard_backend(self, candidate_token, status)
    class(smooth_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status
    integer :: cslot

    self%discard_calls = self%discard_calls + 1
    cslot = locate_candidate(self, candidate_token)
    if (cslot <= 0 .or. .not. self%candidate_active(cslot)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    self%candidate_active(cslot) = .false.
    status = GW_EXCHANGE_OK
  end subroutine fixture_discard_backend

  subroutine fixture_response_sensitivity(self, service_id, lineage_id, origin_revision, &
       candidate_revision, window, q_groundwater_m_per_s, h_groundwater_m, &
       dh_groundwater_dq_groundwater_s, outcome)
    class(analytic_response_provider_t), intent(inout) :: self
    integer(int64), intent(in) :: service_id, lineage_id, origin_revision, candidate_revision
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s, h_groundwater_m
    real(real64), intent(out) :: dh_groundwater_dq_groundwater_s
    integer, intent(out) :: outcome

    self%calls = self%calls + 1
    dh_groundwater_dq_groundwater_s = 0.0_real64
    if (service_id /= 2901_int64 .or. lineage_id /= 29001_int64) then
      outcome = GW_RESPONSE_PROVIDER_ERROR
      return
    end if
    if (origin_revision /= 12_int64 .or. candidate_revision /= 13_int64) then
      outcome = GW_RESPONSE_PROVIDER_ERROR
      return
    end if
    if (.not. window%valid() .or. h_groundwater_m /= h_groundwater_m) then
      outcome = GW_RESPONSE_PROVIDER_ERROR
      return
    end if

    select case (self%mode)
    case (PROVIDER_MODE_AVAILABLE)
      dh_groundwater_dq_groundwater_s = self%alpha_s + 2.0_real64*self%beta_s2_per_m*q_groundwater_m_per_s
      outcome = GW_RESPONSE_PROVIDER_AVAILABLE
    case (PROVIDER_MODE_UNAVAILABLE)
      outcome = GW_RESPONSE_PROVIDER_UNAVAILABLE
    case (PROVIDER_MODE_NONSMOOTH)
      outcome = GW_RESPONSE_PROVIDER_NONSMOOTH
    case (PROVIDER_MODE_NONFINITE)
      dh_groundwater_dq_groundwater_s = ieee_value(0.0_real64, ieee_quiet_nan)
      outcome = GW_RESPONSE_PROVIDER_AVAILABLE
    case default
      outcome = GW_RESPONSE_PROVIDER_ERROR
    end select
  end subroutine fixture_response_sensitivity

  integer function locate_checkpoint(self, token) result(slot)
    class(smooth_groundwater_service_t), intent(in) :: self
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
    class(smooth_groundwater_service_t), intent(in) :: self
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

end module mod_fgc29_fixture

program test_fgc29_groundwater_response_sensitivity
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_discard_candidate, GW_EXCHANGE_OK
  use mod_groundwater_response_sensitivity_contract, only: groundwater_response_sensitivity_t, &
       groundwater_query_response_sensitivity, GW_RESPONSE_OK, GW_RESPONSE_INVALID_CANDIDATE, &
       GW_RESPONSE_PROVENANCE_MISMATCH, GW_RESPONSE_UNAVAILABLE, GW_RESPONSE_INVALID_DERIVATIVE, &
       GW_RESPONSE_PROVIDER_REJECTED, GW_RESPONSE_PROVIDER_UNAVAILABLE, GW_RESPONSE_PROVIDER_NONSMOOTH
  use mod_fgc29_fixture, only: smooth_groundwater_service_t, analytic_response_provider_t, &
       PROVIDER_MODE_AVAILABLE, PROVIDER_MODE_UNAVAILABLE, PROVIDER_MODE_NONSMOOTH, &
       PROVIDER_MODE_ERROR, PROVIDER_MODE_NONFINITE
  implicit none

  type(smooth_groundwater_service_t) :: service
  type(analytic_response_provider_t) :: provider
  type(groundwater_exchange_checkpoint_t) :: checkpoint
  type(groundwater_exchange_candidate_t) :: center_candidate, plus_candidate, minus_candidate, retry_candidate
  type(groundwater_exchange_trial_result_t) :: center_trial, plus_trial, minus_trial, retry_trial, bad_trial
  type(groundwater_response_sensitivity_t) :: response, response_repeat
  type(groundwater_coupling_window_t) :: window
  real(real64), parameter :: q0 = 2.0e-7_real64
  real(real64), parameter :: dq = 1.0e-9_real64
  real(real64) :: expected, finite_difference, head0, time0
  integer(int64) :: revision0
  integer :: status, calls_before

  window%t0 = 6200.375_real64
  window%t1 = 6200.8125_real64
  head0 = service%committed_head_m
  time0 = service%committed_time
  revision0 = service%committed_revision

  call groundwater_capture_checkpoint(service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK .and. checkpoint%ready(), 'checkpoint capture')
  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0, center_candidate, center_trial, status)
  call require(status == GW_EXCHANGE_OK .and. center_candidate%ready(), 'center trial')

  provider%mode = PROVIDER_MODE_AVAILABLE
  call groundwater_query_response_sensitivity(provider, checkpoint, center_candidate, center_trial, response, status)
  expected = service%alpha_s + 2.0_real64*service%beta_s2_per_m*q0
  call require(status == GW_RESPONSE_OK .and. response%available, 'available response')
  call require(abs(response%dh_groundwater_dq_groundwater_s-expected) <= 1.0e-12_real64*abs(expected), &
       'analytic response value')
  call require(response%groundwater_service_id == checkpoint%service_id(), 'service provenance')
  call require(response%groundwater_lineage_id == checkpoint%lineage_id(), 'lineage provenance')
  call require(response%origin_revision == revision0, 'origin revision provenance')
  call require(response%candidate_revision == center_candidate%candidate_revision(), 'candidate revision provenance')
  call require(response%window%t0 == window%t0 .and. response%window%t1 == window%t1, 'window provenance')
  call require(response%q_groundwater_m_per_s == q0, 'evaluation flux provenance')
  call require(service%committed_revision == revision0 .and. service%committed_time == time0 .and. &
       service%committed_head_m == head0, 'response query mutated committed groundwater state')
  print '(a)', 'FGC29_PROVENANCE_BOUND_RESPONSE=PASS'

  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0+dq, plus_candidate, plus_trial, status)
  call require(status == GW_EXCHANGE_OK, 'plus finite-difference trial')
  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0-dq, minus_candidate, minus_trial, status)
  call require(status == GW_EXCHANGE_OK, 'minus finite-difference trial')
  finite_difference = (plus_trial%h_groundwater_m-minus_trial%h_groundwater_m)/(2.0_real64*dq)
  call require(abs(response%dh_groundwater_dq_groundwater_s-finite_difference) <= &
       2.0e-8_real64*max(1.0_real64,abs(finite_difference)), 'independent centered finite-difference reference')
  call groundwater_discard_candidate(service, plus_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard plus reference candidate')
  call groundwater_discard_candidate(service, minus_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard minus reference candidate')
  call require(service%committed_revision == revision0 .and. service%committed_time == time0 .and. &
       service%committed_head_m == head0, 'finite-difference reference mutated committed state')
  print '(a)', 'FGC29_INDEPENDENT_FD_REFERENCE=PASS'

  call groundwater_query_response_sensitivity(provider, checkpoint, center_candidate, center_trial, response_repeat, status)
  call require(status == GW_RESPONSE_OK, 'repeat query')
  call require(response_repeat%dh_groundwater_dq_groundwater_s == response%dh_groundwater_dq_groundwater_s, &
       'repeat response determinism')
  print '(a)', 'FGC29_DETERMINISTIC_RESPONSE=PASS'

  calls_before = provider%calls
  bad_trial = center_trial
  bad_trial%window%t1 = bad_trial%window%t1 + 0.01_real64
  call groundwater_query_response_sensitivity(provider, checkpoint, center_candidate, bad_trial, response_repeat, status)
  call require(status == GW_RESPONSE_PROVENANCE_MISMATCH .and. .not. response_repeat%available, &
       'mismatched window did not fail closed')
  call require(provider%calls == calls_before, 'provider called before provenance rejection')
  print '(a)', 'FGC29_PROVENANCE_MISMATCH_FAIL_CLOSED=PASS'

  call groundwater_query_response_sensitivity(checkpoint=checkpoint, candidate=center_candidate, &
       trial_result=center_trial, response=response_repeat, status=status)
  call require(status == GW_RESPONSE_UNAVAILABLE .and. .not. response_repeat%available .and. &
       response_repeat%provider_outcome == GW_RESPONSE_PROVIDER_UNAVAILABLE, 'missing provider not explicit unavailable')
  print '(a)', 'FGC29_OPTIONAL_PROVIDER_UNAVAILABLE=PASS'

  call groundwater_discard_candidate(service, center_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard center candidate')
  calls_before = provider%calls
  call groundwater_query_response_sensitivity(provider, checkpoint, center_candidate, center_trial, response_repeat, status)
  call require(status == GW_RESPONSE_INVALID_CANDIDATE .and. .not. response_repeat%available, &
       'discarded candidate response leaked')
  call require(provider%calls == calls_before, 'provider called for discarded candidate')
  print '(a)', 'FGC29_DISCARDED_TRIAL_ZERO_RESPONSE_LEAKAGE=PASS'

  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0, retry_candidate, retry_trial, status)
  call require(status == GW_EXCHANGE_OK .and. retry_candidate%ready(), 'retry trial')

  provider%mode = PROVIDER_MODE_NONSMOOTH
  call groundwater_query_response_sensitivity(provider, checkpoint, retry_candidate, retry_trial, response_repeat, status)
  call require(status == GW_RESPONSE_UNAVAILABLE .and. .not. response_repeat%available .and. &
       response_repeat%provider_outcome == GW_RESPONSE_PROVIDER_NONSMOOTH, 'nonsmooth response did not fail closed')
  print '(a)', 'FGC29_NONSMOOTH_FAIL_CLOSED=PASS'

  provider%mode = PROVIDER_MODE_UNAVAILABLE
  call groundwater_query_response_sensitivity(provider, checkpoint, retry_candidate, retry_trial, response_repeat, status)
  call require(status == GW_RESPONSE_UNAVAILABLE .and. .not. response_repeat%available, 'unavailable response')
  print '(a)', 'FGC29_PROVIDER_UNAVAILABLE_FAIL_CLOSED=PASS'

  provider%mode = PROVIDER_MODE_ERROR
  call groundwater_query_response_sensitivity(provider, checkpoint, retry_candidate, retry_trial, response_repeat, status)
  call require(status == GW_RESPONSE_PROVIDER_REJECTED .and. .not. response_repeat%available, 'provider error')
  print '(a)', 'FGC29_PROVIDER_ERROR_FAIL_CLOSED=PASS'

  provider%mode = PROVIDER_MODE_NONFINITE
  call groundwater_query_response_sensitivity(provider, checkpoint, retry_candidate, retry_trial, response_repeat, status)
  call require(status == GW_RESPONSE_INVALID_DERIVATIVE .and. .not. response_repeat%available, 'nonfinite derivative')
  print '(a)', 'FGC29_NONFINITE_DERIVATIVE_FAIL_CLOSED=PASS'

  call groundwater_discard_candidate(service, retry_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'retry discard')
  call require(service%committed_revision == revision0 .and. service%committed_time == time0 .and. &
       service%committed_head_m == head0, 'qualification mutated committed groundwater state')
  call require(service%commit_calls == 0, 'qualification committed groundwater candidate')
  print '(a)', 'FGC29_NO_COMMITTED_STATE_MUTATION=PASS'
  print '(a)', 'FGC29_OWNER_ORACLE=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC29_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fgc29_groundwater_response_sensitivity

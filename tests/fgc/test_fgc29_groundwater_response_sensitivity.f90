module mod_fgc29_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan
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
    integer :: n_checkpoints = 0
    integer(int64) :: candidate_token(64) = 0_int64
    integer(int64) :: candidate_checkpoint_token(64) = 0_int64
    integer(int64) :: candidate_origin_revision(64) = -1_int64
    real(real64) :: candidate_t1(64) = 0.0_real64
    real(real64) :: candidate_head_m(64) = 0.0_real64
    logical :: candidate_active(64) = .false.
    integer :: n_candidates = 0
    integer :: trial_calls = 0
    integer :: commit_calls = 0
    integer :: discard_calls = 0
  contains
    procedure :: capture_backend => fake_capture_backend
    procedure :: trial_backend => fake_trial_backend
    procedure :: commit_backend => fake_commit_backend
    procedure :: discard_backend => fake_discard_backend
  end type smooth_groundwater_service_t

  type, extends(groundwater_response_sensitivity_provider_t), public :: analytic_response_provider_t
    integer :: mode = PROVIDER_MODE_AVAILABLE
    integer :: calls = 0
    real(real64) :: alpha_s = 2.0e6_real64
    real(real64) :: beta_s2_per_m = 5.0e12_real64
  contains
    procedure :: evaluate_response_sensitivity => fake_response_sensitivity
  end type analytic_response_provider_t

contains

  subroutine fake_capture_backend(self, service_id, lineage_id, origin_revision, origin_time, token, status)
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
    service_id = self%service_id
    lineage_id = self%lineage_id
    origin_revision = self%committed_revision
    origin_time = self%committed_time
    token = self%checkpoint_token(slot)
    status = GW_EXCHANGE_OK
  end subroutine fake_capture_backend

  subroutine fake_trial_backend(self, checkpoint_token, window, q_groundwater_m_per_s, &
       candidate_token, h_groundwater_m, status)
    class(smooth_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status
    integer :: cslot, kslot

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
    self%candidate_head_m(cslot) = self%committed_head_m + self%alpha_s*q_groundwater_m_per_s + &
         self%beta_s2_per_m*q_groundwater_m_per_s*q_groundwater_m_per_s
    self%candidate_active(cslot) = .true.
    self%trial_calls = self%trial_calls + 1
    candidate_token = self%candidate_token(cslot)
    h_groundwater_m = self%candidate_head_m(cslot)
    status = GW_EXCHANGE_OK
  end subroutine fake_trial_backend

  subroutine fake_commit_backend(self, checkpoint_token, candidate_token, status)
    class(smooth_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status
    integer :: cslot, kslot

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
    self%committed_head_m = self%candidate_head_m(cslot)
    self%committed_time = self%candidate_t1(cslot)
    self%committed_revision = self%committed_revision + 1_int64
    self%candidate_active(cslot) = .false.
    status = GW_EXCHANGE_OK
  end subroutine fake_commit_backend

  subroutine fake_discard_backend(self, candidate_token, status)
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
  end subroutine fake_discard_backend

  subroutine fake_response_sensitivity(self, service_id, lineage_id, origin_revision, candidate_revision, &
       window, q_groundwater_m_per_s, h_groundwater_m, dh_groundwater_dq_groundwater_s, outcome)
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
    if (.not. window%valid() .or. .not. ieee_is_finite(h_groundwater_m)) then
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
  end subroutine fake_response_sensitivity

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
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_discard_candidate, &
       GW_EXCHANGE_OK, GW_EXCHANGE_ORIGIN_MISMATCH
  use mod_groundwater_response_sensitivity_contract, only: groundwater_response_sensitivity_t, &
       groundwater_trial_with_response_sensitivity, GW_RESPONSE_OK, GW_RESPONSE_INVALID_TRIAL, &
       GW_RESPONSE_UNAVAILABLE, GW_RESPONSE_INVALID_DERIVATIVE, GW_RESPONSE_PROVIDER_REJECTED, &
       GW_RESPONSE_PROVIDER_UNAVAILABLE, GW_RESPONSE_PROVIDER_NONSMOOTH
  use mod_fgc29_fixture, only: smooth_groundwater_service_t, analytic_response_provider_t, &
       PROVIDER_MODE_AVAILABLE, PROVIDER_MODE_UNAVAILABLE, PROVIDER_MODE_NONSMOOTH, &
       PROVIDER_MODE_ERROR, PROVIDER_MODE_NONFINITE
  implicit none

  type(smooth_groundwater_service_t) :: service
  type(analytic_response_provider_t) :: provider
  type(groundwater_exchange_checkpoint_t) :: checkpoint
  type(groundwater_exchange_candidate_t) :: candidate, plus_candidate, minus_candidate
  type(groundwater_exchange_trial_result_t) :: trial, plus_trial, minus_trial
  type(groundwater_response_sensitivity_t) :: first_response, response
  type(groundwater_coupling_window_t) :: window, wrong_window
  real(real64), parameter :: q0 = 2.0e-7_real64
  real(real64), parameter :: dq = 1.0e-9_real64
  real(real64) :: expected, finite_difference, head0, time0, retry_q
  integer(int64) :: revision0
  integer :: exchange_status, response_status, status, provider_calls_before

  window%t0 = 6200.375_real64
  window%t1 = 6200.8125_real64
  head0 = service%committed_head_m
  time0 = service%committed_time
  revision0 = service%committed_revision

  call groundwater_capture_checkpoint(service, checkpoint, status)
  call require(status == GW_EXCHANGE_OK .and. checkpoint%ready(), 'checkpoint capture')

  provider%mode = PROVIDER_MODE_AVAILABLE
  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, q0, candidate, trial, &
       first_response, exchange_status, response_status, provider=provider)
  expected = service%alpha_s + 2.0_real64*service%beta_s2_per_m*q0
  call require(exchange_status == GW_EXCHANGE_OK, 'center exchange')
  call require(response_status == GW_RESPONSE_OK .and. first_response%available, 'center response')
  call require(abs(first_response%dh_groundwater_dq_groundwater_s-expected) <= 1.0e-12_real64*abs(expected), &
       'analytic response value')
  call require(first_response%groundwater_service_id == checkpoint%service_id(), 'service provenance')
  call require(first_response%groundwater_lineage_id == checkpoint%lineage_id(), 'lineage provenance')
  call require(first_response%origin_revision == revision0, 'origin revision provenance')
  call require(first_response%candidate_revision == candidate%candidate_revision(), 'candidate revision provenance')
  call require(same_bits(first_response%window%t0, window%t0) .and. &
       same_bits(first_response%window%t1, window%t1), 'window provenance')
  call require(same_bits(first_response%q_groundwater_m_per_s, q0), 'evaluation flux provenance')
  call require(committed_unchanged(service, revision0, time0, head0), 'response trial mutated committed state')
  print '(a)', 'FGC29_ATOMIC_TRIAL_RESPONSE_BINDING=PASS'
  print '(a)', 'FGC29_PROVENANCE_BOUND_RESPONSE=PASS'

  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0+dq, plus_candidate, plus_trial, status)
  call require(status == GW_EXCHANGE_OK, 'plus finite-difference trial')
  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0-dq, minus_candidate, minus_trial, status)
  call require(status == GW_EXCHANGE_OK, 'minus finite-difference trial')
  finite_difference = (plus_trial%h_groundwater_m-minus_trial%h_groundwater_m)/(2.0_real64*dq)
  call require(abs(first_response%dh_groundwater_dq_groundwater_s-finite_difference) <= &
       2.0e-8_real64*max(1.0_real64,abs(finite_difference)), 'independent centered finite-difference reference')
  call groundwater_discard_candidate(service, plus_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard plus reference')
  call groundwater_discard_candidate(service, minus_candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard minus reference')
  call require(committed_unchanged(service, revision0, time0, head0), 'FD reference mutated committed state')
  print '(a)', 'FGC29_INDEPENDENT_FD_REFERENCE=PASS'

  call groundwater_discard_candidate(service, candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard first response candidate')
  retry_q = q0 + 4.0e-8_real64
  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, retry_q, candidate, trial, &
       response, exchange_status, response_status, provider=provider)
  expected = service%alpha_s + 2.0_real64*service%beta_s2_per_m*retry_q
  call require(exchange_status == GW_EXCHANGE_OK .and. response_status == GW_RESPONSE_OK, 'retry response')
  call require(same_bits(response%q_groundwater_m_per_s, retry_q), 'retry evaluation point')
  call require(abs(response%dh_groundwater_dq_groundwater_s-expected) <= 1.0e-12_real64*abs(expected), &
       'retry derivative')
  call require(.not. same_bits(response%dh_groundwater_dq_groundwater_s, &
       first_response%dh_groundwater_dq_groundwater_s), 'stale response leaked into retry')
  call groundwater_discard_candidate(service, candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard retry')
  print '(a)', 'FGC29_RETRY_REPLACES_RESPONSE_WITH_ZERO_STALE_LEAKAGE=PASS'

  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, q0, candidate, trial, &
       response, exchange_status, response_status, provider=provider)
  call require(exchange_status == GW_EXCHANGE_OK .and. response_status == GW_RESPONSE_OK, 'repeat response')
  call require(same_bits(response%dh_groundwater_dq_groundwater_s, &
       first_response%dh_groundwater_dq_groundwater_s), 'deterministic replay')
  call groundwater_discard_candidate(service, candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard repeat')
  print '(a)', 'FGC29_DETERMINISTIC_RESPONSE=PASS'

  wrong_window = window
  wrong_window%t0 = wrong_window%t0 + 0.01_real64
  wrong_window%t1 = wrong_window%t1 + 0.01_real64
  provider_calls_before = provider%calls
  call groundwater_trial_with_response_sensitivity(service, checkpoint, wrong_window, q0, candidate, trial, &
       response, exchange_status, response_status, provider=provider)
  call require(exchange_status == GW_EXCHANGE_ORIGIN_MISMATCH, 'wrong origin accepted')
  call require(response_status == GW_RESPONSE_INVALID_TRIAL .and. .not. response%available, &
       'rejected trial published response')
  call require(.not. candidate%ready(), 'rejected trial published candidate')
  call require(provider%calls == provider_calls_before, 'provider called after rejected groundwater trial')
  print '(a)', 'FGC29_REJECTED_TRIAL_ZERO_RESPONSE=PASS'

  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, q0, candidate, trial, &
       response, exchange_status, response_status)
  call require(exchange_status == GW_EXCHANGE_OK, 'optional-provider exchange')
  call require(response_status == GW_RESPONSE_UNAVAILABLE .and. .not. response%available .and. &
       response%provider_outcome == GW_RESPONSE_PROVIDER_UNAVAILABLE, 'missing provider not explicit unavailable')
  call groundwater_discard_candidate(service, candidate, status)
  call require(status == GW_EXCHANGE_OK, 'discard no-provider candidate')
  print '(a)', 'FGC29_OPTIONAL_PROVIDER_UNAVAILABLE=PASS'

  provider%mode = PROVIDER_MODE_NONSMOOTH
  call case_expect_response(service, provider, checkpoint, window, q0, GW_RESPONSE_UNAVAILABLE, &
       GW_RESPONSE_PROVIDER_NONSMOOTH, 'nonsmooth')
  print '(a)', 'FGC29_NONSMOOTH_FAIL_CLOSED=PASS'

  provider%mode = PROVIDER_MODE_UNAVAILABLE
  call case_expect_response(service, provider, checkpoint, window, q0, GW_RESPONSE_UNAVAILABLE, &
       GW_RESPONSE_PROVIDER_UNAVAILABLE, 'unavailable')
  print '(a)', 'FGC29_PROVIDER_UNAVAILABLE_FAIL_CLOSED=PASS'

  provider%mode = PROVIDER_MODE_ERROR
  call case_expect_response(service, provider, checkpoint, window, q0, GW_RESPONSE_PROVIDER_REJECTED, &
       -1, 'provider error')
  print '(a)', 'FGC29_PROVIDER_ERROR_FAIL_CLOSED=PASS'

  provider%mode = PROVIDER_MODE_NONFINITE
  call case_expect_response(service, provider, checkpoint, window, q0, GW_RESPONSE_INVALID_DERIVATIVE, &
       -1, 'nonfinite')
  print '(a)', 'FGC29_NONFINITE_DERIVATIVE_FAIL_CLOSED=PASS'

  call require(committed_unchanged(service, revision0, time0, head0), 'qualification mutated committed state')
  call require(service%commit_calls == 0, 'qualification committed groundwater candidate')
  print '(a)', 'FGC29_NO_COMMITTED_STATE_MUTATION=PASS'
  print '(a)', 'FGC29_OWNER_ORACLE=PASS'

contains

  subroutine case_expect_response(service_local, provider_local, checkpoint_local, window_local, q, &
       expected_status, expected_outcome, label)
    type(smooth_groundwater_service_t), intent(inout) :: service_local
    type(analytic_response_provider_t), intent(inout) :: provider_local
    type(groundwater_exchange_checkpoint_t), intent(in) :: checkpoint_local
    type(groundwater_coupling_window_t), intent(in) :: window_local
    real(real64), intent(in) :: q
    integer, intent(in) :: expected_status, expected_outcome
    character(len=*), intent(in) :: label
    type(groundwater_exchange_candidate_t) :: local_candidate
    type(groundwater_exchange_trial_result_t) :: local_trial
    type(groundwater_response_sensitivity_t) :: local_response
    integer :: ex_status, resp_status, cleanup_status

    call groundwater_trial_with_response_sensitivity(service_local, checkpoint_local, window_local, q, &
         local_candidate, local_trial, local_response, ex_status, resp_status, provider=provider_local)
    call require(ex_status == GW_EXCHANGE_OK, trim(label)//' exchange')
    call require(resp_status == expected_status .and. .not. local_response%available, trim(label)//' status')
    if (expected_outcome >= 0) call require(local_response%provider_outcome == expected_outcome, trim(label)//' outcome')
    call groundwater_discard_candidate(service_local, local_candidate, cleanup_status)
    call require(cleanup_status == GW_EXCHANGE_OK, trim(label)//' discard')
  end subroutine case_expect_response

  pure logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  pure logical function committed_unchanged(service_local, revision, time, head) result(equal)
    type(smooth_groundwater_service_t), intent(in) :: service_local
    integer(int64), intent(in) :: revision
    real(real64), intent(in) :: time, head
    equal = service_local%committed_revision == revision .and. &
         same_bits(service_local%committed_time, time) .and. same_bits(service_local%committed_head_m, head)
  end function committed_unchanged

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC29_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fgc29_groundwater_response_sensitivity

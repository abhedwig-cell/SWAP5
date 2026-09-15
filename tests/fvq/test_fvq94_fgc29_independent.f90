module mod_fvq94_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_INVALID_CHECKPOINT, GW_EXCHANGE_INVALID_CANDIDATE, GW_EXCHANGE_STALE_CANDIDATE
  use mod_groundwater_response_sensitivity_contract, only: groundwater_response_sensitivity_provider_t, &
       GW_RESPONSE_PROVIDER_AVAILABLE, GW_RESPONSE_PROVIDER_NONSMOOTH
  implicit none
  private

  integer, parameter, public :: VQ94_PROVIDER_AVAILABLE = 0
  integer, parameter, public :: VQ94_PROVIDER_NONSMOOTH = 1
  integer, parameter, public :: VQ94_PROVIDER_NONFINITE = 2

  type, extends(groundwater_exchange_service_t), public :: verifier_groundwater_service_t
    integer(int64) :: service_id = 9401_int64
    integer(int64) :: lineage_id = 94001_int64
    integer(int64) :: committed_revision = 27_int64
    real(real64) :: committed_time = 91.125_real64
    real(real64) :: committed_head_m = 13.75_real64
    real(real64) :: a_s = -1.7e6_real64
    real(real64) :: b_s2_per_m = 8.0e11_real64
    integer(int64) :: checkpoint_token = 0_int64
    integer(int64) :: next_candidate_token = 5000_int64
    integer(int64) :: candidate_token(64) = 0_int64
    real(real64) :: candidate_t1(64) = 0.0_real64
    real(real64) :: candidate_h(64) = 0.0_real64
    logical :: active(64) = .false.
    integer :: n_candidates = 0
    integer :: trial_calls = 0
    integer :: commit_calls = 0
  contains
    procedure :: capture_backend => verifier_capture
    procedure :: trial_backend => verifier_trial
    procedure :: commit_backend => verifier_commit
    procedure :: discard_backend => verifier_discard
  end type verifier_groundwater_service_t

  type, extends(groundwater_response_sensitivity_provider_t), public :: verifier_response_provider_t
    integer :: mode = VQ94_PROVIDER_AVAILABLE
    integer :: calls = 0
    real(real64) :: a_s = -1.7e6_real64
    real(real64) :: b_s2_per_m = 8.0e11_real64
  contains
    procedure :: evaluate_response_sensitivity => verifier_response
  end type verifier_response_provider_t

contains

  subroutine verifier_capture(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(verifier_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status

    self%checkpoint_token = 940000_int64 + self%committed_revision
    service_id = self%service_id
    lineage_id = self%lineage_id
    origin_revision = self%committed_revision
    origin_time = self%committed_time
    token = self%checkpoint_token
    status = GW_EXCHANGE_OK
  end subroutine verifier_capture

  subroutine verifier_trial(self, checkpoint_token, window, q_groundwater_m_per_s, &
       candidate_token, h_groundwater_m, status)
    class(verifier_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status
    integer :: slot

    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
    if (checkpoint_token /= self%checkpoint_token) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    if (self%n_candidates >= size(self%candidate_token)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if

    self%n_candidates = self%n_candidates + 1
    slot = self%n_candidates
    self%next_candidate_token = self%next_candidate_token + 1_int64
    self%candidate_token(slot) = self%next_candidate_token
    self%candidate_t1(slot) = window%t1
    self%candidate_h(slot) = self%committed_head_m + self%a_s*q_groundwater_m_per_s + &
         self%b_s2_per_m*q_groundwater_m_per_s*q_groundwater_m_per_s
    self%active(slot) = .true.
    self%trial_calls = self%trial_calls + 1
    candidate_token = self%candidate_token(slot)
    h_groundwater_m = self%candidate_h(slot)
    status = GW_EXCHANGE_OK
  end subroutine verifier_trial

  subroutine verifier_commit(self, checkpoint_token, candidate_token, status)
    class(verifier_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status
    integer :: slot

    self%commit_calls = self%commit_calls + 1
    if (checkpoint_token /= self%checkpoint_token) then
      status = GW_EXCHANGE_INVALID_CHECKPOINT
      return
    end if
    slot = locate_candidate(self, candidate_token)
    if (slot <= 0 .or. .not. self%active(slot)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    self%committed_head_m = self%candidate_h(slot)
    self%committed_time = self%candidate_t1(slot)
    self%committed_revision = self%committed_revision + 1_int64
    self%active(slot) = .false.
    status = GW_EXCHANGE_OK
  end subroutine verifier_commit

  subroutine verifier_discard(self, candidate_token, status)
    class(verifier_groundwater_service_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status
    integer :: slot

    slot = locate_candidate(self, candidate_token)
    if (slot <= 0 .or. .not. self%active(slot)) then
      status = GW_EXCHANGE_INVALID_CANDIDATE
      return
    end if
    self%active(slot) = .false.
    status = GW_EXCHANGE_OK
  end subroutine verifier_discard

  subroutine verifier_response(self, service_id, lineage_id, origin_revision, candidate_revision, &
       window, q_groundwater_m_per_s, h_groundwater_m, derivative, outcome)
    class(verifier_response_provider_t), intent(inout) :: self
    integer(int64), intent(in) :: service_id, lineage_id, origin_revision, candidate_revision
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s, h_groundwater_m
    real(real64), intent(out) :: derivative
    integer, intent(out) :: outcome

    self%calls = self%calls + 1
    derivative = 0.0_real64
    if (service_id /= 9401_int64 .or. lineage_id /= 94001_int64 .or. &
        origin_revision /= 27_int64 .or. candidate_revision /= 28_int64) then
      outcome = GW_RESPONSE_PROVIDER_NONSMOOTH
      return
    end if
    if (.not. window%valid()) then
      outcome = GW_RESPONSE_PROVIDER_NONSMOOTH
      return
    end if
    if (h_groundwater_m < -huge(1.0_real64)) then
      outcome = GW_RESPONSE_PROVIDER_NONSMOOTH
      return
    end if

    select case (self%mode)
    case (VQ94_PROVIDER_AVAILABLE)
      derivative = self%a_s + 2.0_real64*self%b_s2_per_m*q_groundwater_m_per_s
      outcome = GW_RESPONSE_PROVIDER_AVAILABLE
    case (VQ94_PROVIDER_NONSMOOTH)
      outcome = GW_RESPONSE_PROVIDER_NONSMOOTH
    case default
      derivative = ieee_value(0.0_real64, ieee_quiet_nan)
      outcome = GW_RESPONSE_PROVIDER_AVAILABLE
    end select
  end subroutine verifier_response

  integer function locate_candidate(self, token) result(slot)
    class(verifier_groundwater_service_t), intent(in) :: self
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

end module mod_fvq94_fixture

program test_fvq94_fgc29_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_trial_result_t, groundwater_capture_checkpoint, &
       groundwater_trial_from_checkpoint, groundwater_discard_candidate, GW_EXCHANGE_OK, GW_EXCHANGE_ORIGIN_MISMATCH
  use mod_groundwater_response_sensitivity_contract, only: groundwater_response_sensitivity_t, &
       groundwater_trial_with_response_sensitivity, GW_RESPONSE_OK, GW_RESPONSE_INVALID_TRIAL, &
       GW_RESPONSE_UNAVAILABLE, GW_RESPONSE_INVALID_DERIVATIVE, GW_RESPONSE_PROVIDER_NONSMOOTH
  use mod_fvq94_fixture, only: verifier_groundwater_service_t, verifier_response_provider_t, &
       VQ94_PROVIDER_AVAILABLE, VQ94_PROVIDER_NONSMOOTH, VQ94_PROVIDER_NONFINITE
  implicit none

  type(verifier_groundwater_service_t) :: service
  type(verifier_response_provider_t) :: provider
  type(groundwater_exchange_checkpoint_t) :: checkpoint
  type(groundwater_exchange_candidate_t) :: candidate, fd_candidate(4)
  type(groundwater_exchange_trial_result_t) :: trial, fd_trial(4)
  type(groundwater_response_sensitivity_t) :: response_a, response_b
  type(groundwater_coupling_window_t) :: window, wrong_window
  real(real64), parameter :: q0 = -2.5e-7_real64
  real(real64), parameter :: dq = 2.0e-9_real64
  real(real64) :: expected, fd5, q_retry, head0, time0
  integer(int64) :: revision0
  integer :: ex_status, response_status, status, calls_before, trials_before, i

  window%t0 = 91.125_real64
  window%t1 = 93.6875_real64
  head0 = service%committed_head_m
  time0 = service%committed_time
  revision0 = service%committed_revision

  call groundwater_capture_checkpoint(service, checkpoint, status)
  call assert_true(status == GW_EXCHANGE_OK .and. checkpoint%ready(), 'capture')

  provider%mode = VQ94_PROVIDER_AVAILABLE
  trials_before = service%trial_calls
  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, q0, candidate, trial, &
       response_a, ex_status, response_status, provider=provider)
  call assert_true(ex_status == GW_EXCHANGE_OK .and. response_status == GW_RESPONSE_OK, 'native response')
  call assert_true(service%trial_calls == trials_before + 1, 'native response added extra groundwater trial')
  expected = service%a_s + 2.0_real64*service%b_s2_per_m*q0
  call assert_true(abs(response_a%dh_groundwater_dq_groundwater_s-expected) <= &
       2.0e-13_real64*max(1.0_real64,abs(expected)), 'analytic tangent')
  call assert_true(response_a%groundwater_service_id == checkpoint%service_id(), 'service provenance')
  call assert_true(response_a%groundwater_lineage_id == checkpoint%lineage_id(), 'lineage provenance')
  call assert_true(response_a%origin_revision == revision0, 'origin provenance')
  call assert_true(response_a%candidate_revision == candidate%candidate_revision(), 'candidate provenance')
  call assert_true(bits_equal(response_a%window%t0, window%t0) .and. &
       bits_equal(response_a%window%t1, window%t1), 'window provenance')
  call assert_true(committed_equal(service, revision0, time0, head0), 'native query mutated committed state')
  print '(a)', 'FVQ94_ATOMIC_NATIVE_SINGLE_TRIAL=PASS'
  print '(a)', 'FVQ94_EXACT_PROVENANCE=PASS'

  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0-2.0_real64*dq, &
       fd_candidate(1), fd_trial(1), status)
  call assert_true(status == GW_EXCHANGE_OK, 'fd -2')
  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0-dq, fd_candidate(2), fd_trial(2), status)
  call assert_true(status == GW_EXCHANGE_OK, 'fd -1')
  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0+dq, fd_candidate(3), fd_trial(3), status)
  call assert_true(status == GW_EXCHANGE_OK, 'fd +1')
  call groundwater_trial_from_checkpoint(service, checkpoint, window, q0+2.0_real64*dq, &
       fd_candidate(4), fd_trial(4), status)
  call assert_true(status == GW_EXCHANGE_OK, 'fd +2')
  fd5 = (fd_trial(1)%h_groundwater_m - 8.0_real64*fd_trial(2)%h_groundwater_m + &
       8.0_real64*fd_trial(3)%h_groundwater_m - fd_trial(4)%h_groundwater_m)/(12.0_real64*dq)
  call assert_true(abs(response_a%dh_groundwater_dq_groundwater_s-fd5) <= &
       5.0e-8_real64*max(1.0_real64,abs(fd5)), 'five-point finite-difference reference')
  do i = 1, 4
    call groundwater_discard_candidate(service, fd_candidate(i), status)
    call assert_true(status == GW_EXCHANGE_OK, 'fd discard')
  end do
  print '(a)', 'FVQ94_INDEPENDENT_FIVE_POINT_FD=PASS'

  call groundwater_discard_candidate(service, candidate, status)
  call assert_true(status == GW_EXCHANGE_OK, 'discard first native candidate')
  q_retry = 1.25e-7_real64
  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, q_retry, candidate, trial, &
       response_b, ex_status, response_status, provider=provider)
  call assert_true(ex_status == GW_EXCHANGE_OK .and. response_status == GW_RESPONSE_OK, 'retry native response')
  call assert_true(bits_equal(response_b%q_groundwater_m_per_s, q_retry), 'retry evaluation point')
  call assert_true(.not. bits_equal(response_a%dh_groundwater_dq_groundwater_s, &
       response_b%dh_groundwater_dq_groundwater_s), 'retry inherited stale derivative')
  call groundwater_discard_candidate(service, candidate, status)
  call assert_true(status == GW_EXCHANGE_OK, 'discard retry')
  print '(a)', 'FVQ94_RETRY_ZERO_STALE_CONTRIBUTION=PASS'

  wrong_window = window
  wrong_window%t0 = wrong_window%t0 + 0.125_real64
  wrong_window%t1 = wrong_window%t1 + 0.125_real64
  calls_before = provider%calls
  call groundwater_trial_with_response_sensitivity(service, checkpoint, wrong_window, q0, candidate, trial, &
       response_b, ex_status, response_status, provider=provider)
  call assert_true(ex_status == GW_EXCHANGE_ORIGIN_MISMATCH, 'wrong-origin trial accepted')
  call assert_true(response_status == GW_RESPONSE_INVALID_TRIAL .and. .not. response_b%available, &
       'rejected trial published response')
  call assert_true(provider%calls == calls_before, 'provider called after rejected trial')
  print '(a)', 'FVQ94_REJECTED_TRIAL_ZERO_RESPONSE=PASS'

  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, q0, candidate, trial, &
       response_b, ex_status, response_status)
  call assert_true(ex_status == GW_EXCHANGE_OK .and. response_status == GW_RESPONSE_UNAVAILABLE .and. &
       .not. response_b%available, 'missing provider did not fail closed')
  call groundwater_discard_candidate(service, candidate, status)
  call assert_true(status == GW_EXCHANGE_OK, 'discard unavailable-provider candidate')
  print '(a)', 'FVQ94_UNSUPPORTED_PROVIDER_FAIL_CLOSED=PASS'

  provider%mode = VQ94_PROVIDER_NONSMOOTH
  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, q0, candidate, trial, &
       response_b, ex_status, response_status, provider=provider)
  call assert_true(ex_status == GW_EXCHANGE_OK .and. response_status == GW_RESPONSE_UNAVAILABLE .and. &
       response_b%provider_outcome == GW_RESPONSE_PROVIDER_NONSMOOTH, 'nonsmooth provider')
  call groundwater_discard_candidate(service, candidate, status)
  call assert_true(status == GW_EXCHANGE_OK, 'discard nonsmooth candidate')
  print '(a)', 'FVQ94_NONSMOOTH_FAIL_CLOSED=PASS'

  provider%mode = VQ94_PROVIDER_NONFINITE
  call groundwater_trial_with_response_sensitivity(service, checkpoint, window, q0, candidate, trial, &
       response_b, ex_status, response_status, provider=provider)
  call assert_true(ex_status == GW_EXCHANGE_OK .and. response_status == GW_RESPONSE_INVALID_DERIVATIVE .and. &
       .not. response_b%available, 'nonfinite derivative accepted')
  call groundwater_discard_candidate(service, candidate, status)
  call assert_true(status == GW_EXCHANGE_OK, 'discard nonfinite candidate')
  print '(a)', 'FVQ94_NONFINITE_FAIL_CLOSED=PASS'

  call assert_true(committed_equal(service, revision0, time0, head0), 'verifier mutated committed groundwater state')
  call assert_true(service%commit_calls == 0, 'verifier committed groundwater candidate')
  print '(a)', 'FVQ94_COMMITTED_STATE_UNCHANGED=PASS'
  print '(a)', 'FVQ94_INDEPENDENT_ORACLE=PASS'

contains

  pure logical function bits_equal(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function bits_equal

  pure logical function committed_equal(service_local, revision, time, head) result(equal)
    type(verifier_groundwater_service_t), intent(in) :: service_local
    integer(int64), intent(in) :: revision
    real(real64), intent(in) :: time, head
    equal = service_local%committed_revision == revision .and. &
         bits_equal(service_local%committed_time, time) .and. bits_equal(service_local%committed_head_m, head)
  end function committed_equal

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'FVQ94_FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine assert_true

end program test_fvq94_fgc29_independent

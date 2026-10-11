module mod_groundwater_response_sensitivity_contract
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_service_t, &
       groundwater_exchange_checkpoint_t, groundwater_exchange_candidate_t, &
       groundwater_exchange_trial_result_t, groundwater_trial_from_checkpoint, GW_EXCHANGE_OK
  implicit none
  private

  integer, parameter, public :: GW_RESPONSE_OK = 0
  integer, parameter, public :: GW_RESPONSE_INVALID_CHECKPOINT = 1
  integer, parameter, public :: GW_RESPONSE_INVALID_CANDIDATE = 2
  integer, parameter, public :: GW_RESPONSE_INVALID_TRIAL = 3
  integer, parameter, public :: GW_RESPONSE_PROVENANCE_MISMATCH = 4
  integer, parameter, public :: GW_RESPONSE_UNAVAILABLE = 5
  integer, parameter, public :: GW_RESPONSE_INVALID_DERIVATIVE = 6
  integer, parameter, public :: GW_RESPONSE_PROVIDER_REJECTED = 7

  integer, parameter, public :: GW_RESPONSE_PROVIDER_AVAILABLE = 0
  integer, parameter, public :: GW_RESPONSE_PROVIDER_UNAVAILABLE = 1
  integer, parameter, public :: GW_RESPONSE_PROVIDER_NONSMOOTH = 2
  integer, parameter, public :: GW_RESPONSE_PROVIDER_ERROR = 3

  type, public :: groundwater_response_sensitivity_t
    integer :: status = GW_RESPONSE_UNAVAILABLE
    integer :: provider_outcome = GW_RESPONSE_PROVIDER_UNAVAILABLE
    logical :: available = .false.
    real(real64) :: dh_groundwater_dq_groundwater_s = 0.0_real64
    real(real64) :: q_groundwater_m_per_s = 0.0_real64
    real(real64) :: h_groundwater_m = 0.0_real64
    type(groundwater_coupling_window_t) :: window
    integer(int64) :: groundwater_service_id = 0_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    integer(int64) :: candidate_revision = -1_int64
  end type groundwater_response_sensitivity_t

  ! Optional companion capability for F-GC18-style groundwater services.
  ! The public path creates the groundwater trial and its response in one call.
  ! This makes the response belong by construction to the exact candidate/trial
  ! pair returned by that invocation; callers cannot relabel an older response
  ! as belonging to another live retry candidate.
  !
  ! Implementations provide only a tangent at the already evaluated trial point.
  ! They do not create an additional groundwater trial and do not own commit,
  ! rollback, mass accounting, finite differences or coupling iteration policy.
  type, abstract, public :: groundwater_response_sensitivity_provider_t
  contains
    procedure(gw_response_sensitivity_provider_ifc), deferred, public :: evaluate_response_sensitivity
  end type groundwater_response_sensitivity_provider_t

  public :: groundwater_trial_with_response_sensitivity

  abstract interface
    subroutine gw_response_sensitivity_provider_ifc(self, service_id, lineage_id, origin_revision, &
         candidate_revision, window, q_groundwater_m_per_s, h_groundwater_m, &
         dh_groundwater_dq_groundwater_s, outcome)
      import :: groundwater_response_sensitivity_provider_t, groundwater_coupling_window_t, int64, real64
      class(groundwater_response_sensitivity_provider_t), intent(inout) :: self
      integer(int64), intent(in) :: service_id, lineage_id, origin_revision, candidate_revision
      type(groundwater_coupling_window_t), intent(in) :: window
      real(real64), intent(in) :: q_groundwater_m_per_s, h_groundwater_m
      real(real64), intent(out) :: dh_groundwater_dq_groundwater_s
      integer, intent(out) :: outcome
    end subroutine gw_response_sensitivity_provider_ifc
  end interface

contains

  subroutine groundwater_trial_with_response_sensitivity(service, checkpoint, window, q_groundwater_m_per_s, &
       candidate, trial_result, response, exchange_status, response_status, provider)
    class(groundwater_exchange_service_t), intent(inout) :: service
    type(groundwater_exchange_checkpoint_t), intent(in) :: checkpoint
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    type(groundwater_exchange_candidate_t), intent(out) :: candidate
    type(groundwater_exchange_trial_result_t), intent(out) :: trial_result
    type(groundwater_response_sensitivity_t), intent(out) :: response
    integer, intent(out) :: exchange_status, response_status
    class(groundwater_response_sensitivity_provider_t), intent(inout), optional :: provider

    response = groundwater_response_sensitivity_t()
    call groundwater_trial_from_checkpoint(service, checkpoint, window, q_groundwater_m_per_s, &
         candidate, trial_result, exchange_status)
    if (exchange_status /= GW_EXCHANGE_OK) then
      response%status = GW_RESPONSE_INVALID_TRIAL
      response_status = GW_RESPONSE_INVALID_TRIAL
      return
    end if

    if (present(provider)) then
      call bind_response_sensitivity(provider, checkpoint, candidate, trial_result, response, response_status)
    else
      call bind_response_sensitivity(checkpoint=checkpoint, candidate=candidate, trial_result=trial_result, &
           response=response, status=response_status)
    end if
  end subroutine groundwater_trial_with_response_sensitivity

  subroutine bind_response_sensitivity(provider, checkpoint, candidate, trial_result, response, status)
    class(groundwater_response_sensitivity_provider_t), intent(inout), optional :: provider
    type(groundwater_exchange_checkpoint_t), intent(in) :: checkpoint
    type(groundwater_exchange_candidate_t), intent(in) :: candidate
    type(groundwater_exchange_trial_result_t), intent(in) :: trial_result
    type(groundwater_response_sensitivity_t), intent(out) :: response
    integer, intent(out) :: status

    type(groundwater_coupling_window_t) :: candidate_window
    real(real64) :: derivative
    logical :: candidate_window_available
    integer :: outcome

    response = groundwater_response_sensitivity_t()
    status = GW_RESPONSE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready()) then
      response%status = status
      return
    end if

    status = GW_RESPONSE_INVALID_CANDIDATE
    if (.not. candidate%ready()) then
      response%status = status
      return
    end if

    if (candidate%service_id() /= checkpoint%service_id() .or. &
        candidate%lineage_id() /= checkpoint%lineage_id() .or. &
        candidate%origin_revision() /= checkpoint%origin_revision()) then
      status = GW_RESPONSE_PROVENANCE_MISMATCH
      response%status = status
      return
    end if

    call candidate%origin_window(candidate_window, candidate_window_available)
    if (.not. candidate_window_available) then
      status = GW_RESPONSE_INVALID_CANDIDATE
      response%status = status
      return
    end if

    status = GW_RESPONSE_INVALID_TRIAL
    if (trial_result%status /= GW_EXCHANGE_OK) then
      response%status = status
      return
    end if
    if (.not. trial_result%window%valid()) then
      response%status = status
      return
    end if
    if (.not. ieee_is_finite(trial_result%q_groundwater_m_per_s) .or. &
        .not. ieee_is_finite(trial_result%h_groundwater_m)) then
      response%status = status
      return
    end if

    if (.not. same_response_time(trial_result%window%t0, candidate_window%t0) .or. &
        .not. same_response_time(trial_result%window%t1, candidate_window%t1) .or. &
        trial_result%groundwater_lineage_id /= candidate%lineage_id() .or. &
        trial_result%origin_revision /= candidate%origin_revision() .or. &
        trial_result%candidate_revision /= candidate%candidate_revision()) then
      status = GW_RESPONSE_PROVENANCE_MISMATCH
      response%status = status
      return
    end if

    response%q_groundwater_m_per_s = trial_result%q_groundwater_m_per_s
    response%h_groundwater_m = trial_result%h_groundwater_m
    response%window = candidate_window
    response%groundwater_service_id = checkpoint%service_id()
    response%groundwater_lineage_id = checkpoint%lineage_id()
    response%origin_revision = checkpoint%origin_revision()
    response%candidate_revision = candidate%candidate_revision()

    if (.not. present(provider)) then
      status = GW_RESPONSE_UNAVAILABLE
      response%status = status
      response%provider_outcome = GW_RESPONSE_PROVIDER_UNAVAILABLE
      return
    end if

    derivative = 0.0_real64
    outcome = GW_RESPONSE_PROVIDER_ERROR
    call provider%evaluate_response_sensitivity(response%groundwater_service_id, response%groundwater_lineage_id, &
         response%origin_revision, response%candidate_revision, response%window, &
         response%q_groundwater_m_per_s, response%h_groundwater_m, derivative, outcome)
    response%provider_outcome = outcome

    select case (outcome)
    case (GW_RESPONSE_PROVIDER_AVAILABLE)
      if (.not. ieee_is_finite(derivative)) then
        status = GW_RESPONSE_INVALID_DERIVATIVE
        response%status = status
        return
      end if
      response%dh_groundwater_dq_groundwater_s = derivative
      response%available = .true.
      response%status = GW_RESPONSE_OK
      status = GW_RESPONSE_OK
    case (GW_RESPONSE_PROVIDER_UNAVAILABLE, GW_RESPONSE_PROVIDER_NONSMOOTH)
      response%dh_groundwater_dq_groundwater_s = 0.0_real64
      response%available = .false.
      response%status = GW_RESPONSE_UNAVAILABLE
      status = GW_RESPONSE_UNAVAILABLE
    case default
      response%dh_groundwater_dq_groundwater_s = 0.0_real64
      response%available = .false.
      response%status = GW_RESPONSE_PROVIDER_REJECTED
      status = GW_RESPONSE_PROVIDER_REJECTED
    end select
  end subroutine bind_response_sensitivity

  pure logical function same_response_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_response_time

end module mod_groundwater_response_sensitivity_contract

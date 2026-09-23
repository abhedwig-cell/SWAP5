module mod_fmr_hupsel_management_demand_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_parameters_t, &
       tcs1_dcs2_sprinkling_request_t, tcs1_dcs2_sprinkling_state_t, tcs1_dcs2_sprinkling_result_t, &
       tcs1_dcs2_sprinkling_diagnostics_t, evaluate_tcs1_dcs2_sprinkling_interval, &
       TCS1_DCS2_OK, TCS1_DCS2_SPLIT_REQUIRED
  use mod_fmr_hupsel_management_transaction, only: fmr_hupsel_management_persistence_t
  implicit none
  private

  integer, parameter, public :: FMR_RM_DEMAND_OK = 0
  integer, parameter, public :: FMR_RM_DEMAND_INVALID_ORIGIN = 1
  integer, parameter, public :: FMR_RM_DEMAND_INVALID_REQUEST = 2
  integer, parameter, public :: FMR_RM_DEMAND_DECISION_FAILED = 3
  integer, parameter, public :: FMR_RM_DEMAND_ACTIVE_EVENT_NOT_ADMITTED = 4

  type, public :: fmr_hupsel_management_demand_receipt_t
    logical :: valid = .false.
    integer(int64) :: management_lineage_id = 0_int64
    integer(int64) :: management_origin_revision = -1_int64
    integer(int64) :: crop_origin_revision = -1_int64
    real(real64) :: management_t0 = 0.0_real64
    real(real64) :: management_t1 = 0.0_real64
    logical :: irrigation_requested = .false.
    real(real64) :: requested_depth_cm = 0.0_real64
    real(real64) :: gross_application_rate_cm_per_day = 0.0_real64
    real(real64) :: event_duration_day = 0.0_real64
    real(real64) :: application_t1 = 0.0_real64
    integer :: candidate_dayfix = 0
    logical :: candidate_active_event = .false.
    real(real64) :: candidate_active_event_start = 0.0_real64
    real(real64) :: candidate_active_event_end = 0.0_real64
  contains
    procedure, public :: ready => fmr_hupsel_management_demand_receipt_ready
  end type fmr_hupsel_management_demand_receipt_t

  public :: derive_fmr_hupsel_management_demand

contains

  pure logical function fmr_hupsel_management_demand_receipt_ready(self) result(ready)
    class(fmr_hupsel_management_demand_receipt_t), intent(in) :: self

    ready = self%valid
    if (.not. ready) return
    ready = self%management_lineage_id > 0_int64 .and. self%management_origin_revision >= 0_int64 .and. &
         self%crop_origin_revision >= 0_int64
    if (.not. ready) return
    ready = ieee_is_finite(self%management_t0) .and. ieee_is_finite(self%management_t1) .and. &
         self%management_t1 > self%management_t0
    if (.not. ready) return
    ready = ieee_is_finite(self%requested_depth_cm) .and. self%requested_depth_cm >= 0.0_real64 .and. &
         ieee_is_finite(self%gross_application_rate_cm_per_day) .and. &
         ieee_is_finite(self%event_duration_day) .and. self%event_duration_day >= 0.0_real64 .and. &
         ieee_is_finite(self%application_t1)
    if (.not. ready) return

    if (self%irrigation_requested) then
      ready = self%requested_depth_cm > 0.0_real64 .and. self%gross_application_rate_cm_per_day > 0.0_real64 .and. &
           self%event_duration_day > 0.0_real64 .and. self%application_t1 > self%management_t0 .and. &
           self%application_t1 <= self%management_t1
    else
      ready = abs(self%requested_depth_cm) <= epsilon(1.0_real64) .and. &
           abs(self%gross_application_rate_cm_per_day) <= epsilon(1.0_real64) .and. &
           abs(self%event_duration_day) <= epsilon(1.0_real64) .and. &
           abs(self%application_t1-self%management_t0) <= &
             64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(self%management_t0))
    end if
  end function fmr_hupsel_management_demand_receipt_ready

  subroutine derive_fmr_hupsel_management_demand(parameters, accepted, request, management_lineage_id, &
       management_origin_revision, crop_origin_revision, receipt, status)
    type(tcs1_dcs2_sprinkling_parameters_t), intent(in) :: parameters
    type(fmr_hupsel_management_persistence_t), intent(in) :: accepted
    type(tcs1_dcs2_sprinkling_request_t), intent(in) :: request
    integer(int64), intent(in) :: management_lineage_id
    integer(int64), intent(in) :: management_origin_revision
    integer(int64), intent(in) :: crop_origin_revision
    type(fmr_hupsel_management_demand_receipt_t), intent(out) :: receipt
    integer, intent(out) :: status

    type(tcs1_dcs2_sprinkling_request_t) :: bounded_request
    type(tcs1_dcs2_sprinkling_state_t) :: candidate
    type(tcs1_dcs2_sprinkling_result_t) :: result
    type(tcs1_dcs2_sprinkling_diagnostics_t) :: diagnostics
    logical :: accepted_ready

    receipt = fmr_hupsel_management_demand_receipt_t()
    status = FMR_RM_DEMAND_INVALID_ORIGIN

    accepted_ready = accepted%ready()
    if (.not. accepted_ready) return
    if (management_lineage_id <= 0_int64 .or. management_origin_revision < 0_int64 .or. crop_origin_revision < 0_int64) return
    if (accepted%irrigation%active_event) then
      status = FMR_RM_DEMAND_ACTIVE_EVENT_NOT_ADMITTED
      return
    end if

    status = FMR_RM_DEMAND_INVALID_REQUEST
    if (.not. ieee_is_finite(request%t0) .or. .not. ieee_is_finite(request%t1) .or. request%t1 <= request%t0) return

    bounded_request = request
    call evaluate_tcs1_dcs2_sprinkling_interval(parameters, accepted%irrigation, bounded_request, &
         candidate, result, diagnostics)

    if (diagnostics%status == TCS1_DCS2_SPLIT_REQUIRED) then
      if (.not. ieee_is_finite(diagnostics%split_time)) then
        status = FMR_RM_DEMAND_DECISION_FAILED
        return
      end if
      if (diagnostics%split_time <= request%t0 .or. diagnostics%split_time > request%t1) then
        status = FMR_RM_DEMAND_DECISION_FAILED
        return
      end if
      bounded_request%t1 = diagnostics%split_time
      call evaluate_tcs1_dcs2_sprinkling_interval(parameters, accepted%irrigation, bounded_request, &
           candidate, result, diagnostics)
    end if

    if (diagnostics%status /= TCS1_DCS2_OK) then
      status = FMR_RM_DEMAND_DECISION_FAILED
      return
    end if

    receipt%management_lineage_id = management_lineage_id
    receipt%management_origin_revision = management_origin_revision
    receipt%crop_origin_revision = crop_origin_revision
    receipt%management_t0 = request%t0
    receipt%management_t1 = request%t1
    receipt%irrigation_requested = result%event_started
    receipt%application_t1 = request%t0
    if (result%event_started) then
      receipt%requested_depth_cm = result%event_depth_cm
      receipt%gross_application_rate_cm_per_day = result%gross_surface_rate_cm_per_day
      receipt%event_duration_day = result%event_duration_day
      receipt%application_t1 = bounded_request%t1
    end if
    receipt%candidate_dayfix = candidate%dayfix
    receipt%candidate_active_event = candidate%active_event
    receipt%candidate_active_event_start = candidate%active_event_start
    receipt%candidate_active_event_end = candidate%active_event_end
    receipt%valid = .true.

    if (.not. receipt%ready()) then
      receipt = fmr_hupsel_management_demand_receipt_t()
      status = FMR_RM_DEMAND_DECISION_FAILED
      return
    end if
    status = FMR_RM_DEMAND_OK
  end subroutine derive_fmr_hupsel_management_demand

end module mod_fmr_hupsel_management_demand_receipt

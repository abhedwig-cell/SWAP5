module mod_rfm_surface_event_age
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: RFM_SURFACE_EVENT_AGE_NOT_RUN = 0
  integer, parameter, public :: RFM_SURFACE_EVENT_AGE_AVAILABLE = 1
  integer, parameter, public :: RFM_SURFACE_EVENT_AGE_INVALID = 2

  type, public :: rfm_surface_event_age_request_t
    real(real64) :: accepted_age_day = 0.0_real64
    real(real64) :: step_duration_day = 0.0_real64
    logical :: event_active = .false.
  contains
    procedure, public :: valid => event_age_request_valid
  end type rfm_surface_event_age_request_t

  type, public :: rfm_surface_event_age_result_t
    integer :: status = RFM_SURFACE_EVENT_AGE_NOT_RUN
    real(real64) :: evaluation_age_day = 0.0_real64
    real(real64) :: candidate_age_day = 0.0_real64
  contains
    procedure, public :: same_values => event_age_result_same_values
  end type rfm_surface_event_age_result_t

  public :: evaluate_rfm_surface_event_age

contains

  pure logical function event_age_request_valid(self) result(ok)
    class(rfm_surface_event_age_request_t), intent(in) :: self

    ok = ieee_is_finite(self%accepted_age_day) .and. self%accepted_age_day >= 0.0_real64 .and. &
         ieee_is_finite(self%step_duration_day) .and. self%step_duration_day > 0.0_real64
  end function event_age_request_valid

  pure subroutine evaluate_rfm_surface_event_age(request,result)
    type(rfm_surface_event_age_request_t), intent(in) :: request
    type(rfm_surface_event_age_result_t), intent(out) :: result

    result = rfm_surface_event_age_result_t()
    if (.not.request%valid()) then
      result%status = RFM_SURFACE_EVENT_AGE_INVALID
      return
    end if

    if (request%event_active) then
      result%evaluation_age_day = request%accepted_age_day + 0.5_real64*request%step_duration_day
      result%candidate_age_day = request%accepted_age_day + request%step_duration_day
      if (.not.ieee_is_finite(result%evaluation_age_day) .or. &
          .not.ieee_is_finite(result%candidate_age_day)) then
        result = rfm_surface_event_age_result_t(status=RFM_SURFACE_EVENT_AGE_INVALID)
        return
      end if
    end if

    result%status = RFM_SURFACE_EVENT_AGE_AVAILABLE
  end subroutine evaluate_rfm_surface_event_age

  pure logical function event_age_result_same_values(self,other) result(same)
    class(rfm_surface_event_age_result_t), intent(in) :: self
    type(rfm_surface_event_age_result_t), intent(in) :: other

    same = self%status == other%status .and. &
         transfer(self%evaluation_age_day,0_int64) == transfer(other%evaluation_age_day,0_int64) .and. &
         transfer(self%candidate_age_day,0_int64) == transfer(other%candidate_age_day,0_int64)
  end function event_age_result_same_values

end module mod_rfm_surface_event_age

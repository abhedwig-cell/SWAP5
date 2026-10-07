module mod_crop_calendar_end_event
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: CROP_END_OK = 0
  integer, parameter, public :: CROP_END_INVALID_INPUT = 1

  integer, parameter, public :: CROP_END_BY_CALENDAR = 0
  integer, parameter, public :: CROP_END_BY_DVS_OR_CALENDAR = 1

  type, public :: crop_end_event_request_t
    integer :: mode = CROP_END_BY_CALENDAR
    real(real64) :: current_time_day = 0.0_real64
    real(real64) :: configured_crop_end_day = 0.0_real64
    real(real64) :: development_stage = 0.0_real64
    real(real64) :: development_stage_end = 2.0_real64
  end type crop_end_event_request_t

  type, public :: crop_end_event_result_t
    logical :: end_crop = .false.
    logical :: calendar_triggered = .false.
    logical :: development_triggered = .false.
  end type crop_end_event_result_t

  public :: evaluate_crop_end_event

contains

  subroutine evaluate_crop_end_event(request, result, status)
    type(crop_end_event_request_t), intent(in) :: request
    type(crop_end_event_result_t), intent(out) :: result
    integer, intent(out) :: status

    result = crop_end_event_result_t()
    status = CROP_END_INVALID_INPUT

    if (request%mode /= CROP_END_BY_CALENDAR .and. request%mode /= CROP_END_BY_DVS_OR_CALENDAR) return
    if (.not. ieee_is_finite(request%current_time_day) .or. &
        .not. ieee_is_finite(request%configured_crop_end_day)) return
    if (.not. ieee_is_finite(request%development_stage) .or. &
        .not. ieee_is_finite(request%development_stage_end)) return
    if (request%development_stage < 0.0_real64 .or. request%development_stage_end < 0.0_real64) return

    ! Pinned B1.11 fixed.f90 and wofost.f90 both test the daily crop-end
    ! event at t1900 == cropend(icrop)+1 within 0.1 day tolerance.
    result%calendar_triggered = abs(request%current_time_day - request%configured_crop_end_day - 1.0_real64) < 0.1_real64

    if (request%mode == CROP_END_BY_DVS_OR_CALENDAR) then
      result%development_triggered = request%development_stage >= request%development_stage_end
    end if
    result%end_crop = result%calendar_triggered .or. result%development_triggered
    status = CROP_END_OK
  end subroutine evaluate_crop_end_event

end module mod_crop_calendar_end_event

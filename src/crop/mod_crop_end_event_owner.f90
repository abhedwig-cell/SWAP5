module mod_crop_end_event_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: CROP_END_EVENT_OK = 0
  integer, parameter, public :: CROP_END_EVENT_INVALID_INPUT = 1

  type, public :: crop_end_event_request_t
    real(real64) :: current_time_t1900 = 0.0_real64
    real(real64) :: scheduled_crop_end_t1900 = 0.0_real64
    logical :: development_stage_harvest_enabled = .false.
    real(real64) :: development_stage = 0.0_real64
    real(real64) :: development_stage_end = 2.0_real64
  end type crop_end_event_request_t

  type, public :: crop_end_event_result_t
    logical :: crop_end_due = .false.
    logical :: due_to_calendar = .false.
    logical :: due_to_development_stage = .false.
  end type crop_end_event_result_t

  public :: evaluate_crop_end_event

contains

  subroutine evaluate_crop_end_event(request, result, status)
    type(crop_end_event_request_t), intent(in) :: request
    type(crop_end_event_result_t), intent(out) :: result
    integer, intent(out) :: status

    result = crop_end_event_result_t()
    status = CROP_END_EVENT_INVALID_INPUT

    if (.not. ieee_is_finite(request%current_time_t1900)) return
    if (.not. ieee_is_finite(request%scheduled_crop_end_t1900)) return
    if (.not. ieee_is_finite(request%development_stage)) return
    if (.not. ieee_is_finite(request%development_stage_end)) return
    if (request%development_stage < 0.0_real64) return
    if (request%development_stage_end < 0.0_real64 .or. request%development_stage_end > 2.0_real64) return

    ! Pinned B1.11 fixed.f90 and wofost.f90 task=4:
    ! ABS(T1900 - CROPEND(ICROP) - 1) < 0.1
    result%due_to_calendar = abs(request%current_time_t1900 - &
         request%scheduled_crop_end_t1900 - 1.0_real64) < 0.1_real64

    if (request%development_stage_harvest_enabled) then
      result%due_to_development_stage = request%development_stage >= request%development_stage_end
    end if

    result%crop_end_due = result%due_to_calendar .or. result%due_to_development_stage
    status = CROP_END_EVENT_OK
  end subroutine evaluate_crop_end_event

end module mod_crop_end_event_owner

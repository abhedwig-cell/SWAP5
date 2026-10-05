module mod_fmr_irrigation_restart
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_state_t, IRRIGATION_EVENT_NONE, &
       IRRIGATION_EVENT_FIXED, IRRIGATION_EVENT_SCHEDULED
  implicit none
  private

  integer, parameter, public :: IRRIGATION_RESTART_OK = 0
  integer, parameter, public :: IRRIGATION_RESTART_INVALID = 1
  integer, parameter, public :: IRRIGATION_RESTART_SCHEMA = 1

  type, public :: irrigation_restart_record_t
    integer :: schema = 0
    integer :: next_fixed_event_index = 1
    integer :: tcs6_weekly_day_counter = 0
    logical :: active_event = .false.
    integer :: active_event_origin = IRRIGATION_EVENT_NONE
    integer :: active_event_index = 0
    real(real64) :: active_event_start = 0.0_real64
    real(real64) :: active_event_end = 0.0_real64
  end type irrigation_restart_record_t

  public :: export_irrigation_restart, restore_irrigation_restart

contains

  pure subroutine export_irrigation_restart(state, record, status)
    type(irrigation_state_t), intent(in) :: state
    type(irrigation_restart_record_t), intent(out) :: record
    integer, intent(out) :: status

    record = irrigation_restart_record_t()
    status = IRRIGATION_RESTART_INVALID
    if (.not. valid_state(state)) return
    record%schema = IRRIGATION_RESTART_SCHEMA
    record%next_fixed_event_index = state%next_fixed_event_index
    record%tcs6_weekly_day_counter = state%tcs6_weekly_day_counter
    record%active_event = state%active_event
    record%active_event_origin = state%active_event_origin
    record%active_event_index = state%active_event_index
    record%active_event_start = state%active_event_start
    record%active_event_end = state%active_event_end
    status = IRRIGATION_RESTART_OK
  end subroutine export_irrigation_restart

  pure subroutine restore_irrigation_restart(record, state, status)
    type(irrigation_restart_record_t), intent(in) :: record
    type(irrigation_state_t), intent(out) :: state
    integer, intent(out) :: status

    state = irrigation_state_t()
    status = IRRIGATION_RESTART_INVALID
    if (record%schema /= IRRIGATION_RESTART_SCHEMA) return
    state%next_fixed_event_index = record%next_fixed_event_index
    state%tcs6_weekly_day_counter = record%tcs6_weekly_day_counter
    state%active_event = record%active_event
    state%active_event_origin = record%active_event_origin
    state%active_event_index = record%active_event_index
    state%active_event_start = record%active_event_start
    state%active_event_end = record%active_event_end
    if (.not. valid_state(state)) then
      state = irrigation_state_t()
      return
    end if
    status = IRRIGATION_RESTART_OK
  end subroutine restore_irrigation_restart

  pure logical function valid_state(state)
    type(irrigation_state_t), intent(in) :: state

    valid_state = .false.
    if (state%next_fixed_event_index < 1) return
    if (state%tcs6_weekly_day_counter < 0 .or. state%tcs6_weekly_day_counter > 6) return
    if (state%active_event) then
      if (.not. ieee_is_finite(state%active_event_start) .or. &
          .not. ieee_is_finite(state%active_event_end)) return
      if (state%active_event_end <= state%active_event_start) return
      select case (state%active_event_origin)
      case (IRRIGATION_EVENT_FIXED)
        if (state%active_event_index < 1 .or. &
            state%next_fixed_event_index /= state%active_event_index + 1) return
      case (IRRIGATION_EVENT_SCHEDULED)
        if (state%active_event_index /= 0) return
      case default
        return
      end select
    else
      if (state%active_event_origin /= IRRIGATION_EVENT_NONE .or. state%active_event_index /= 0) return
    end if
    valid_state = .true.
  end function valid_state

end module mod_fmr_irrigation_restart

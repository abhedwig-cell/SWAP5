module mod_fmr_tillage_event_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_tillage_constitutive_process, only: select_tillage_start_event, TILLAGE_OK
  implicit none
  private

  integer, parameter, public :: TILLAGE_OWNER_OK = 0
  integer, parameter, public :: TILLAGE_OWNER_INVALID = 1
  integer, parameter, public :: TILLAGE_OWNER_SPLIT_REQUIRED = 2
  integer, parameter, public :: TILLAGE_OWNER_SCHEMA = 1

  type, public :: tillage_owner_state_t
    integer :: next_event = 1
    integer :: previous_event = 0
    real(real64) :: accepted_net_rain_since_event_cm = 0.0_real64
  end type

  type, public :: tillage_owner_restart_t
    integer :: schema = 0
    integer :: next_event = 1
    integer :: previous_event = 0
    real(real64) :: accepted_net_rain_since_event_cm = 0.0_real64
  end type

  public :: initialize_tillage_owner, advance_tillage_owner
  public :: export_tillage_owner, restore_tillage_owner

contains

  pure subroutine initialize_tillage_owner(event_days, start_day, state, status)
    real(real64), intent(in) :: event_days(:), start_day
    type(tillage_owner_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer :: selection_status

    state = tillage_owner_state_t()
    status = TILLAGE_OWNER_INVALID
    call select_tillage_start_event(event_days,start_day,state%next_event,state%previous_event,selection_status)
    if (selection_status /= TILLAGE_OK) then
      state = tillage_owner_state_t()
      return
    end if
    status = TILLAGE_OWNER_OK
  end subroutine

  pure subroutine advance_tillage_owner(event_days, t0, t1, accepted_rain_cm, committed, candidate, &
                                        event_index, status)
    real(real64), intent(in) :: event_days(:), t0, t1, accepted_rain_cm
    type(tillage_owner_state_t), intent(in) :: committed
    type(tillage_owner_state_t), intent(out) :: candidate
    integer, intent(out) :: event_index, status
    integer :: i

    candidate = committed
    event_index = 0
    status = TILLAGE_OWNER_INVALID
    if (.not. valid_state(committed,size(event_days))) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. &
        .not. ieee_is_finite(accepted_rain_cm)) return
    if (t1 <= t0 .or. accepted_rain_cm < 0.0_real64) return
    if (any(.not. ieee_is_finite(event_days))) return
    do i = 2, size(event_days)
      if (event_days(i) <= event_days(i-1)) return
    end do
    if (committed%next_event <= size(event_days)) then
      if (event_days(committed%next_event) < t0) return
      if (event_days(committed%next_event) > t0 .and. event_days(committed%next_event) < t1) then
        status = TILLAGE_OWNER_SPLIT_REQUIRED
        return
      end if
      if (event_days(committed%next_event) == t0) then
        event_index = committed%next_event
        candidate%next_event = event_index + 1
        candidate%previous_event = event_index
        candidate%accepted_net_rain_since_event_cm = 0.0_real64
      end if
    end if
    candidate%accepted_net_rain_since_event_cm = &
         candidate%accepted_net_rain_since_event_cm + accepted_rain_cm
    if (.not. ieee_is_finite(candidate%accepted_net_rain_since_event_cm)) then
      candidate = committed
      event_index = 0
      return
    end if
    status = TILLAGE_OWNER_OK
  end subroutine

  pure subroutine export_tillage_owner(state, event_count, record, status)
    type(tillage_owner_state_t), intent(in) :: state
    integer, intent(in) :: event_count
    type(tillage_owner_restart_t), intent(out) :: record
    integer, intent(out) :: status

    record = tillage_owner_restart_t()
    status = TILLAGE_OWNER_INVALID
    if (.not. valid_state(state,event_count)) return
    record%schema = TILLAGE_OWNER_SCHEMA
    record%next_event = state%next_event
    record%previous_event = state%previous_event
    record%accepted_net_rain_since_event_cm = state%accepted_net_rain_since_event_cm
    status = TILLAGE_OWNER_OK
  end subroutine

  pure subroutine restore_tillage_owner(record, event_count, state, status)
    type(tillage_owner_restart_t), intent(in) :: record
    integer, intent(in) :: event_count
    type(tillage_owner_state_t), intent(out) :: state
    integer, intent(out) :: status

    state = tillage_owner_state_t()
    status = TILLAGE_OWNER_INVALID
    if (record%schema /= TILLAGE_OWNER_SCHEMA) return
    state%next_event = record%next_event
    state%previous_event = record%previous_event
    state%accepted_net_rain_since_event_cm = record%accepted_net_rain_since_event_cm
    if (valid_state(state,event_count)) then
      status = TILLAGE_OWNER_OK
    else
      state = tillage_owner_state_t()
    end if
  end subroutine

  pure logical function valid_state(state,event_count)
    type(tillage_owner_state_t), intent(in) :: state
    integer, intent(in) :: event_count
    valid_state = .false.
    if (event_count < 1) return
    if (state%next_event < 1 .or. state%next_event > event_count + 1) return
    if (state%previous_event /= state%next_event - 1) return
    if (.not. ieee_is_finite(state%accepted_net_rain_since_event_cm)) return
    if (state%accepted_net_rain_since_event_cm < 0.0_real64) return
    valid_state = .true.
  end function
end module

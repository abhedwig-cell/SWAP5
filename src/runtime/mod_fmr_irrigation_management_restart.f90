module mod_fmr_irrigation_management_restart
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: IRRIGATION_EVENT_NONE, IRRIGATION_EVENT_FIXED, IRRIGATION_EVENT_SCHEDULED
  use mod_fmr_scheduled_management_irrigation_application, only: fmr_irrigation_management_state_t
  implicit none
  private

  integer, parameter, public :: FMR_IRR_MGMT_RESTART_SCHEMA = 1
  integer, parameter, public :: FMR_IRR_MGMT_RESTART_OK = 0
  integer, parameter, public :: FMR_IRR_MGMT_RESTART_INVALID = 1
  integer, parameter, public :: FMR_IRR_MGMT_RESTART_SCHEMA_MISMATCH = 2

  type, public :: fmr_irrigation_management_restart_record_t
    integer :: schema = 0
    integer :: next_fixed_event_index = 1
    integer :: weekly_day_counter = 366
    logical :: active_event = .false.
    integer :: active_event_origin = IRRIGATION_EVENT_NONE
    integer :: active_event_index = 0
    real(real64) :: active_event_start = 0.0_real64
    real(real64) :: active_event_end = 0.0_real64
    real(real64) :: active_event_rate_cm_per_day = 0.0_real64
  end type

  public :: export_fmr_irrigation_management_restart
  public :: restore_fmr_irrigation_management_restart

contains

  pure subroutine export_fmr_irrigation_management_restart(state, record, status)
    type(fmr_irrigation_management_state_t), intent(in) :: state
    type(fmr_irrigation_management_restart_record_t), intent(out) :: record
    integer, intent(out) :: status
    record = fmr_irrigation_management_restart_record_t()
    status = FMR_IRR_MGMT_RESTART_INVALID
    if (.not. valid_state(state)) return
    record%schema = FMR_IRR_MGMT_RESTART_SCHEMA
    record%next_fixed_event_index = state%event%next_fixed_event_index
    record%weekly_day_counter = state%policy%weekly_day_counter
    record%active_event = state%event%active_event
    record%active_event_origin = state%event%active_event_origin
    record%active_event_index = state%event%active_event_index
    record%active_event_start = state%event%active_event_start
    record%active_event_end = state%event%active_event_end
    record%active_event_rate_cm_per_day = state%event%active_event_rate_cm_per_day
    status = FMR_IRR_MGMT_RESTART_OK
  end subroutine

  pure subroutine restore_fmr_irrigation_management_restart(record, state, status)
    type(fmr_irrigation_management_restart_record_t), intent(in) :: record
    type(fmr_irrigation_management_state_t), intent(out) :: state
    integer, intent(out) :: status
    state = fmr_irrigation_management_state_t()
    status = FMR_IRR_MGMT_RESTART_INVALID
    if (record%schema /= FMR_IRR_MGMT_RESTART_SCHEMA) then
      status = FMR_IRR_MGMT_RESTART_SCHEMA_MISMATCH
      return
    end if
    state%event%next_fixed_event_index = record%next_fixed_event_index
    state%policy%weekly_day_counter = record%weekly_day_counter
    state%event%active_event = record%active_event
    state%event%active_event_origin = record%active_event_origin
    state%event%active_event_index = record%active_event_index
    state%event%active_event_start = record%active_event_start
    state%event%active_event_end = record%active_event_end
    state%event%active_event_rate_cm_per_day = record%active_event_rate_cm_per_day
    if (.not. valid_state(state)) then
      state = fmr_irrigation_management_state_t()
      return
    end if
    status = FMR_IRR_MGMT_RESTART_OK
  end subroutine

  pure logical function valid_state(state) result(ok)
    type(fmr_irrigation_management_state_t), intent(in) :: state
    ok = .false.
    if (state%policy%weekly_day_counter < 0) return
    if (state%policy%weekly_day_counter > 6 .and. state%policy%weekly_day_counter /= 366) return
    if (state%event%next_fixed_event_index < 1) return
    if (state%event%active_event) then
      if (.not. ieee_is_finite(state%event%active_event_start) .or. &
          .not. ieee_is_finite(state%event%active_event_end)) return
      if (state%event%active_event_end <= state%event%active_event_start) return
      select case (state%event%active_event_origin)
      case (IRRIGATION_EVENT_FIXED)
        if (state%event%active_event_index < 1 .or. &
            state%event%next_fixed_event_index /= state%event%active_event_index + 1) return
        if (abs(state%event%active_event_rate_cm_per_day) > epsilon(1.0_real64)) return
      case (IRRIGATION_EVENT_SCHEDULED)
        if (state%event%active_event_index /= 0) return
        if (.not. ieee_is_finite(state%event%active_event_rate_cm_per_day) .or. &
            state%event%active_event_rate_cm_per_day <= 0.0_real64) return
      case default
        return
      end select
    else
      if (state%event%active_event_origin /= IRRIGATION_EVENT_NONE .or. state%event%active_event_index /= 0) return
      if (.not. ieee_is_finite(state%event%active_event_rate_cm_per_day)) return
      if (abs(state%event%active_event_rate_cm_per_day) > epsilon(1.0_real64)) return
    end if
    ok = .true.
  end function
end module mod_fmr_irrigation_management_restart

module mod_fmr_crop_calendar_restart
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_calendar_management_process, only: crop_calendar_management_state_t
  implicit none
  private
  integer, parameter, public :: CROP_CALENDAR_RESTART_SCHEMA = 1
  integer, parameter, public :: CROP_CALENDAR_RESTART_OK = 0
  integer, parameter, public :: CROP_CALENDAR_RESTART_INVALID = 1
  type, public :: crop_calendar_restart_record_t
    integer :: schema = 0
    integer :: crop_event_id = 0
    logical :: prepared = .false.
    logical :: sown = .false.
    logical :: emerged = .false.
    integer :: preparation_delay_days = 0
    integer :: sowing_delay_days = 0
    real(real64) :: germination_temperature_sum = 0.0_real64
  end type
  public :: export_crop_calendar_restart, restore_crop_calendar_restart
contains
  pure subroutine export_crop_calendar_restart(state,crop_event_id,record,status)
    type(crop_calendar_management_state_t), intent(in) :: state
    integer, intent(in) :: crop_event_id
    type(crop_calendar_restart_record_t), intent(out) :: record
    integer, intent(out) :: status
    record = crop_calendar_restart_record_t()
    status = CROP_CALENDAR_RESTART_INVALID
    if (crop_event_id < 1 .or. .not. valid_state(state)) return
    record%schema = CROP_CALENDAR_RESTART_SCHEMA
    record%crop_event_id = crop_event_id
    record%prepared = state%prepared
    record%sown = state%sown
    record%emerged = state%emerged
    record%preparation_delay_days = state%preparation_delay_days
    record%sowing_delay_days = state%sowing_delay_days
    record%germination_temperature_sum = state%germination_temperature_sum
    status = CROP_CALENDAR_RESTART_OK
  end subroutine

  pure subroutine restore_crop_calendar_restart(record,expected_crop_event_id,state,status)
    type(crop_calendar_restart_record_t), intent(in) :: record
    integer, intent(in) :: expected_crop_event_id
    type(crop_calendar_management_state_t), intent(out) :: state
    integer, intent(out) :: status
    state = crop_calendar_management_state_t()
    status = CROP_CALENDAR_RESTART_INVALID
    if (record%schema /= CROP_CALENDAR_RESTART_SCHEMA .or. &
        expected_crop_event_id < 1 .or. record%crop_event_id /= expected_crop_event_id) return
    state%prepared = record%prepared
    state%sown = record%sown
    state%emerged = record%emerged
    state%preparation_delay_days = record%preparation_delay_days
    state%sowing_delay_days = record%sowing_delay_days
    state%germination_temperature_sum = record%germination_temperature_sum
    if (valid_state(state)) then
      status = CROP_CALENDAR_RESTART_OK
    else
      state = crop_calendar_management_state_t()
    end if
  end subroutine

  pure logical function valid_state(state)
    type(crop_calendar_management_state_t), intent(in) :: state
    valid_state = .false.
    if (state%sown .and. .not. state%prepared) return
    if (state%emerged .and. .not. state%sown) return
    if (state%preparation_delay_days < 0 .or. state%sowing_delay_days < 0) return
    if (.not. ieee_is_finite(state%germination_temperature_sum)) return
    if (state%germination_temperature_sum < 0.0_real64) return
    valid_state = .true.
  end function
end module

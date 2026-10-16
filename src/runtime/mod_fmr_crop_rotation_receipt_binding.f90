module mod_fmr_crop_rotation_receipt_binding
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_rotation_calendar, only: crop_calendar_t
  use mod_crop_rotation_transition, only: crop_rotation_checkpoint_t, crop_rotation_candidate_t, &
       propose_crop_rotation_transition, accept_crop_rotation_transition, ROT_TRANS_OK
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t
  use mod_fmr_wofost_crop_event_lifecycle, only: reconcile_committed_crop_event_receipt, FMR_WOF39_OK
  implicit none
  private
  integer, parameter, public :: CROP_ROT_RECEIPT_OK=0, CROP_ROT_RECEIPT_INVALID=1
  integer, parameter, public :: CROP_ROT_RECEIPT_TIME=2, CROP_ROT_RECEIPT_EVENT=3
  integer, parameter, public :: CROP_ROT_RECEIPT_TRANSITION=4
  public :: reconcile_committed_crop_rotation_transition
contains
  ! Atomic publication of derived calendar and accepted-window state only.
  ! Physical F-KT state is immutable and the matching committed event receipt
  ! is the sole authority for retiring its source window.
  subroutine reconcile_committed_crop_rotation_transition(calendar,calendar_state,window, &
       committed_crop,accepted,status)
    type(crop_calendar_t), intent(in) :: calendar
    type(crop_rotation_checkpoint_t), intent(inout) :: calendar_state
    type(fmr_wofost_accepted_window_t), intent(inout) :: window
    type(kernel_committed_state_t), intent(in) :: committed_crop
    logical, intent(out) :: accepted
    integer, intent(out) :: status
    type(crop_rotation_checkpoint_t) :: trial_calendar
    type(fmr_wofost_accepted_window_t) :: trial_window
    type(crop_rotation_candidate_t) :: candidate
    real(real64) :: target_time
    integer :: trial_status, retirement_status
    logical :: retired, current_time_available
    accepted=.false.
    status=CROP_ROT_RECEIPT_INVALID
    if(.not.calendar%ready()) return
    if(.not.calendar_state%ready()) return
    if(.not.committed_crop%ready()) return
    if(.not.committed_crop%time_is_bound()) return
    call committed_crop%current_time(target_time,current_time_available)
    if(.not.current_time_available) return
    if(target_time<=calendar_state%time()) then
      status=CROP_ROT_RECEIPT_TIME
      return
    end if
    trial_calendar=calendar_state
    trial_window=window
    call propose_crop_rotation_transition(calendar,trial_calendar,target_time,candidate,trial_status)
    if(trial_status/=ROT_TRANS_OK) then
      status=CROP_ROT_RECEIPT_TRANSITION
      return
    end if
    call reconcile_committed_crop_event_receipt(trial_window,committed_crop,retired,retirement_status)
    if(retirement_status/=FMR_WOF39_OK.or..not.retired) then
      status=CROP_ROT_RECEIPT_EVENT
      return
    end if
    call accept_crop_rotation_transition(trial_calendar,candidate,trial_status)
    if(trial_status/=ROT_TRANS_OK) then
      status=CROP_ROT_RECEIPT_TRANSITION
      return
    end if
    ! Both updates become externally visible together only after success.
    calendar_state=trial_calendar
    window=trial_window
    accepted=.true.
    status=CROP_ROT_RECEIPT_OK
  end subroutine
end module mod_fmr_crop_rotation_receipt_binding

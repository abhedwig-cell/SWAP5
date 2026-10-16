module mod_crop_rotation_lifecycle_preflight
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_rotation_calendar, only: crop_calendar_t, CROP_CAL_OK, CROP_CAL_OUTSIDE
  use mod_crop_rotation_transition, only: crop_rotation_checkpoint_t, &
       crop_rotation_candidate_t, propose_crop_rotation_transition, ROT_TRANS_OK
  implicit none
  private
  integer, parameter, public :: CROP_LIFE_OK=0, CROP_LIFE_INVALID=1
  integer, parameter, public :: CROP_LIFE_TIME=2, CROP_LIFE_TRANSITION=3
  integer, parameter, public :: CROP_LIFE_NONE=0, CROP_LIFE_ENTER=1
  integer, parameter, public :: CROP_LIFE_EXIT=2, CROP_LIFE_SWITCH=3
  type, public :: crop_lifecycle_preflight_t
    integer :: action=CROP_LIFE_NONE
    integer :: previous_crop=0
    integer :: next_crop=0
    integer(int64) :: origin_revision=-1_int64
    real(real64) :: origin_time=0.0_real64
    real(real64) :: target_time=0.0_real64
    logical :: valid=.false.
  end type
  public :: inspect_crop_lifecycle
contains
  ! Read-only intent. This is scheduling evidence, never physical crop authority.
  ! A start/end boundary may lie between checkpoints; no sow/harvest is
  ! inferred as already performed without an accepted crop-owner event.
  subroutine inspect_crop_lifecycle(calendar,checkpoint,target_time,plan,status)
    type(crop_calendar_t), intent(in) :: calendar
    type(crop_rotation_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: target_time
    type(crop_lifecycle_preflight_t), intent(out) :: plan
    integer, intent(out) :: status
    type(crop_rotation_candidate_t) :: candidate
    integer :: selection_status,transition_status,crop
    logical :: active,starts_today
    plan=crop_lifecycle_preflight_t()
    status=CROP_LIFE_INVALID
    if(.not.calendar%ready()) return
    if(.not.checkpoint%ready()) return
    if(.not.ieee_is_finite(target_time)) return
    if(target_time<=checkpoint%time()) then
      status=CROP_LIFE_TIME
      return
    end if
    call propose_crop_rotation_transition(calendar,checkpoint,target_time,candidate,transition_status)
    if(transition_status/=ROT_TRANS_OK) then
      status=CROP_LIFE_TRANSITION
      return
    end if
    call calendar%select_at(target_time,crop,active,starts_today,selection_status)
    if(selection_status/=CROP_CAL_OK.and.selection_status/=CROP_CAL_OUTSIDE) return
    plan%previous_crop=checkpoint%crop()
    plan%next_crop=crop
    plan%origin_revision=checkpoint%serial()
    plan%origin_time=checkpoint%time()
    plan%target_time=target_time
    if(plan%previous_crop==0.and.crop>0) then
      plan%action=CROP_LIFE_ENTER
    else if(plan%previous_crop>0.and.crop==0) then
      plan%action=CROP_LIFE_EXIT
    else if(plan%previous_crop>0.and.crop>0.and.plan%previous_crop/=crop) then
      plan%action=CROP_LIFE_SWITCH
    end if
    plan%valid=.true.
    status=CROP_LIFE_OK
  end subroutine
end module mod_crop_rotation_lifecycle_preflight

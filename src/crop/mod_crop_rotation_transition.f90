module mod_crop_rotation_transition
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_rotation_calendar, only: crop_calendar_t, CROP_CAL_OK, CROP_CAL_OUTSIDE
  implicit none
  private
  integer, parameter, public :: ROT_TRANS_OK=0, ROT_TRANS_INVALID=1, ROT_TRANS_STALE=2
  integer, parameter, public :: ROT_TRANS_TIME=3
  type, public :: crop_rotation_checkpoint_t
    private
    logical :: initialized=.false.
    integer :: active_crop=0
    integer(int64) :: revision=0_int64
    real(real64) :: committed_time=0.0_real64
  contains
    procedure :: ready => checkpoint_ready
    procedure :: crop => checkpoint_crop
    procedure :: time => checkpoint_time
    procedure :: serial => checkpoint_serial
  end type
  type, public :: crop_rotation_candidate_t
    private
    logical :: valid=.false.
    integer :: target_crop=0
    integer(int64) :: origin_revision=-1_int64
    real(real64) :: origin_time=0.0_real64, target_time=0.0_real64
  end type
  public :: initialize_crop_rotation_checkpoint, propose_crop_rotation_transition
  public :: accept_crop_rotation_transition
contains
  subroutine initialize_crop_rotation_checkpoint(calendar,time,state,status)
    type(crop_calendar_t),intent(in) :: calendar
    real(real64),intent(in) :: time
    type(crop_rotation_checkpoint_t),intent(out) :: state
    integer,intent(out) :: status
    integer :: idx,cs
    logical :: active,begins
    status=ROT_TRANS_INVALID
    call calendar%select_at(time,idx,active,begins,cs)
    if(cs/=CROP_CAL_OK.and.cs/=CROP_CAL_OUTSIDE) return
    state%initialized=.true.
    state%active_crop=idx
    state%committed_time=time
    state%revision=0_int64
    status=ROT_TRANS_OK
  end subroutine
  subroutine propose_crop_rotation_transition(calendar,committed,time,candidate,status)
    type(crop_calendar_t),intent(in) :: calendar
    type(crop_rotation_checkpoint_t),intent(in) :: committed
    real(real64),intent(in) :: time
    type(crop_rotation_candidate_t),intent(out) :: candidate
    integer,intent(out) :: status
    integer :: idx,cs
    logical :: active,begins
    status=ROT_TRANS_INVALID
    if(.not.committed%ready().or..not.ieee_is_finite(time)) return
    if(time<=committed%committed_time) then
      status=ROT_TRANS_TIME
      return
    end if
    call calendar%select_at(time,idx,active,begins,cs)
    if(cs/=CROP_CAL_OK.and.cs/=CROP_CAL_OUTSIDE) return
    if(idx/=0.and.committed%active_crop>idx) then
      status=ROT_TRANS_TIME
      return
    end if
    candidate%valid=.true.
    candidate%target_crop=idx
    candidate%origin_revision=committed%revision
    candidate%origin_time=committed%committed_time
    candidate%target_time=time
    status=ROT_TRANS_OK
  end subroutine
  subroutine accept_crop_rotation_transition(committed,candidate,status)
    type(crop_rotation_checkpoint_t),intent(inout) :: committed
    type(crop_rotation_candidate_t),intent(in) :: candidate
    integer,intent(out) :: status
    status=ROT_TRANS_INVALID
    if(.not.committed%ready().or..not.candidate%valid) return
    if(candidate%origin_revision/=committed%revision.or. &
       candidate%origin_time/=committed%committed_time) then
      status=ROT_TRANS_STALE
      return
    end if
    if(candidate%target_time<=committed%committed_time.or. &
       committed%revision==huge(committed%revision)) then
      status=ROT_TRANS_TIME
      return
    end if
    committed%active_crop=candidate%target_crop
    committed%committed_time=candidate%target_time
    committed%revision=committed%revision+1_int64
    status=ROT_TRANS_OK
  end subroutine
  logical function checkpoint_ready(self)
    class(crop_rotation_checkpoint_t),intent(in) :: self
    checkpoint_ready=self%initialized.and.self%revision>=0_int64.and. &
      ieee_is_finite(self%committed_time).and.self%active_crop>=0
  end function
  integer function checkpoint_crop(self)
    class(crop_rotation_checkpoint_t),intent(in) :: self
    checkpoint_crop=self%active_crop
  end function
  real(real64) function checkpoint_time(self)
    class(crop_rotation_checkpoint_t),intent(in) :: self
    checkpoint_time=self%committed_time
  end function
  integer(int64) function checkpoint_serial(self)
    class(crop_rotation_checkpoint_t),intent(in) :: self
    checkpoint_serial=self%revision
  end function
end module mod_crop_rotation_transition

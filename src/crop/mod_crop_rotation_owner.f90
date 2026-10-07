module mod_crop_rotation_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  integer, parameter, public :: CROP_ROTATION_OK=0
  integer, parameter, public :: CROP_ROTATION_INVALID_SCHEDULE=1
  integer, parameter, public :: CROP_ROTATION_INVALID_STATE=2
  integer, parameter, public :: CROP_ROTATION_INVALID_TIME=3

  type, public :: crop_rotation_entry_t
    real(real64) :: start_day=0.0_real64
    real(real64) :: end_day=0.0_real64
    integer :: crop_key=0
    integer :: crop_type=0
  contains
    procedure, public :: validate=>crop_rotation_entry_validate
  end type

  type, public :: crop_rotation_schedule_t
    type(crop_rotation_entry_t), allocatable :: entries(:)
  contains
    procedure, public :: ready=>crop_rotation_schedule_ready
    procedure, public :: count=>crop_rotation_schedule_count
  end type

  type, extends(transaction_state_t), public :: crop_rotation_state_t
    integer :: current_crop_index=1
    logical :: crop_calendar_active=.false.
    logical :: exhausted=.false.
  contains
    procedure :: clone=>crop_rotation_clone
    procedure, public :: validate=>crop_rotation_state_validate
  end type

  type, public :: crop_rotation_day_result_t
    integer :: crop_index=0
    integer :: crop_key=0
    integer :: crop_type=0
    logical :: crop_calendar_active=.false.
    logical :: start_rotation=.false.
    logical :: bind_crop_parameters=.false.
    logical :: reset_preemergence=.false.
    logical :: reset_active_crop_flags=.false.
  end type

  public :: initialize_crop_rotation_owner
  public :: evaluate_crop_rotation_day

contains

  integer function crop_rotation_entry_validate(self) result(status)
    class(crop_rotation_entry_t), intent(in) :: self
    status=CROP_ROTATION_INVALID_SCHEDULE
    if(.not.ieee_is_finite(self%start_day).or..not.ieee_is_finite(self%end_day))return
    if(self%start_day<1.0_real64.or.self%end_day<1.0_real64)return
    if((self%end_day-self%start_day+1.0_real64)<0.5_real64)return
    if(self%crop_key<=0)return
    if(self%crop_type<1.or.self%crop_type>2)return
    status=CROP_ROTATION_OK
  end function

  logical function crop_rotation_schedule_ready(self) result(ready)
    class(crop_rotation_schedule_t), intent(in) :: self
    integer :: i
    ready=.false.
    if(.not.allocated(self%entries))return
    if(size(self%entries)<=0)return
    do i=1,size(self%entries)
      if(self%entries(i)%validate()/=CROP_ROTATION_OK)return
      if(i<size(self%entries))then
        ! Pinned B1.11 croprotation source requires next start to be at least
        ! 0.5 day later than the previous end.
        if((self%entries(i+1)%start_day-self%entries(i)%end_day)<0.5_real64)return
      end if
    end do
    ready=.true.
  end function

  integer function crop_rotation_schedule_count(self) result(n)
    class(crop_rotation_schedule_t), intent(in) :: self
    n=0
    if(self%ready())n=size(self%entries)
  end function

  integer function crop_rotation_state_validate(self) result(status)
    class(crop_rotation_state_t), intent(in) :: self
    status=CROP_ROTATION_INVALID_STATE
    if(self%current_crop_index<1)return
    status=CROP_ROTATION_OK
  end function

  subroutine crop_rotation_clone(self,copy)
    class(crop_rotation_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(crop_rotation_state_t::copy)
    select type(t=>copy)
    type is(crop_rotation_state_t)
      t%current_crop_index=self%current_crop_index
      t%crop_calendar_active=self%crop_calendar_active
      t%exhausted=self%exhausted
    class default
      error stop 'crop rotation clone failure'
    end select
  end subroutine

  subroutine initialize_crop_rotation_owner(schedule,start_time,state,result,status)
    type(crop_rotation_schedule_t), intent(in) :: schedule
    real(real64), intent(in) :: start_time
    type(crop_rotation_state_t), intent(out) :: state
    type(crop_rotation_day_result_t), intent(out) :: result
    integer, intent(out) :: status

    state=crop_rotation_state_t()
    result=crop_rotation_day_result_t()
    status=CROP_ROTATION_INVALID_SCHEDULE
    if(.not.schedule%ready())return
    status=CROP_ROTATION_INVALID_TIME
    if(.not.ieee_is_finite(start_time))return

    call locate_crop(schedule,1,start_time,state)
    call build_day_result(schedule,state,start_time,.true.,result)
    status=state%validate()
  end subroutine

  subroutine evaluate_crop_rotation_day(schedule,committed,current_time,initialization_phase,candidate,result,status)
    type(crop_rotation_schedule_t), intent(in) :: schedule
    type(crop_rotation_state_t), intent(in) :: committed
    real(real64), intent(in) :: current_time
    logical, intent(in) :: initialization_phase
    type(crop_rotation_state_t), intent(out) :: candidate
    type(crop_rotation_day_result_t), intent(out) :: result
    integer, intent(out) :: status

    candidate=committed
    result=crop_rotation_day_result_t()
    status=CROP_ROTATION_INVALID_SCHEDULE
    if(.not.schedule%ready())return
    status=committed%validate()
    if(status/=CROP_ROTATION_OK)return
    status=CROP_ROTATION_INVALID_TIME
    if(.not.ieee_is_finite(current_time))return

    call locate_crop(schedule,committed%current_crop_index,current_time,candidate)
    call build_day_result(schedule,candidate,current_time,initialization_phase,result)
    status=candidate%validate()
  end subroutine

  subroutine locate_crop(schedule,start_index,current_time,state)
    type(crop_rotation_schedule_t), intent(in) :: schedule
    integer, intent(in) :: start_index
    real(real64), intent(in) :: current_time
    type(crop_rotation_state_t), intent(inout) :: state

    integer :: i,n
    logical :: active

    n=size(schedule%entries)
    i=max(1,min(start_index,n))
    active=.false.

    ! Typed bounded equivalent of B1.11 find_active_crop(). During fallow the
    ! cursor advances to the next upcoming crop; after the last season it stays
    ! at the last entry and marks exhausted once time has passed its window.
    do
      if(current_time < schedule%entries(i)%start_day-0.1_real64)exit
      if(current_time-schedule%entries(i)%start_day > -0.1_real64 .and. &
         current_time-schedule%entries(i)%end_day < 0.1_real64)then
        active=.true.
        exit
      end if
      if(i>=n)exit
      i=i+1
    end do

    state%current_crop_index=i
    state%crop_calendar_active=active
    state%exhausted=(i==n .and. .not.active .and. current_time-schedule%entries(n)%end_day>=0.1_real64)
  end subroutine

  subroutine build_day_result(schedule,state,current_time,initialization_phase,result)
    type(crop_rotation_schedule_t), intent(in) :: schedule
    type(crop_rotation_state_t), intent(in) :: state
    real(real64), intent(in) :: current_time
    logical, intent(in) :: initialization_phase
    type(crop_rotation_day_result_t), intent(out) :: result

    type(crop_rotation_entry_t) :: entry

    result=crop_rotation_day_result_t()
    if(state%current_crop_index<1.or.state%current_crop_index>size(schedule%entries))return
    entry=schedule%entries(state%current_crop_index)
    result%crop_index=state%current_crop_index
    result%crop_key=entry%crop_key
    result%crop_type=entry%crop_type
    result%crop_calendar_active=state%crop_calendar_active

    ! Pinned B1.11 start flag uses the much tighter 1e-3 day equality.
    result%start_rotation=abs(current_time-entry%start_day)<1.0e-3_real64

    if(state%crop_calendar_active .and. (initialization_phase .or. result%start_rotation))then
      result%bind_crop_parameters=.true.
      if(.not.initialization_phase)then
        result%reset_preemergence=.true.
        result%reset_active_crop_flags=.true.
      end if
    end if
  end subroutine

end module mod_crop_rotation_owner

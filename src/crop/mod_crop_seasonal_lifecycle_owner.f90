module mod_crop_seasonal_lifecycle_owner
  use mod_transaction_reference, only: transaction_state_t
  use mod_crop_rotation_owner, only: crop_rotation_schedule_t, crop_rotation_state_t, crop_rotation_day_result_t, &
       initialize_crop_rotation_owner, evaluate_crop_rotation_day, CROP_ROTATION_OK
  use mod_crop_preemergence_owner, only: crop_preemergence_parameters_t, crop_preemergence_state_t, &
       crop_preemergence_daily_forcing_t, crop_preemergence_diagnostics_t, &
       initialize_crop_preemergence_owner, evaluate_crop_preemergence_day, PREEMERGENCE_OK
  implicit none
  private

  integer, parameter, public :: CROP_SEASON_OK=0
  integer, parameter, public :: CROP_SEASON_INVALID_ROTATION=1
  integer, parameter, public :: CROP_SEASON_INVALID_STATE=2
  integer, parameter, public :: CROP_SEASON_PARAMETER_KEY_MISMATCH=3
  integer, parameter, public :: CROP_SEASON_PREEMERGENCE_ERROR=4
  integer, parameter, public :: CROP_SEASON_INVALID_HARVEST=5
  integer, parameter, public :: CROP_SEASON_MISSING_HARVEST=6

  type, extends(transaction_state_t), public :: crop_seasonal_lifecycle_state_t
    logical :: initialized=.false.
    type(crop_rotation_state_t) :: rotation
    type(crop_preemergence_state_t), allocatable :: preemergence
    integer :: bound_crop_key=0
    logical :: crop_emerged=.false.
    logical :: crop_harvested=.false.
  contains
    procedure :: clone=>crop_seasonal_lifecycle_clone
    procedure, public :: validate=>crop_seasonal_lifecycle_validate
    procedure, public :: preemergence_active=>crop_seasonal_preemergence_active
  end type

  type, public :: crop_seasonal_lifecycle_result_t
    type(crop_seasonal_lifecycle_state_t) :: candidate
    integer :: current_crop_key=0
    integer :: current_crop_type=0
    logical :: crop_calendar_active=.false.
    logical :: bind_crop_parameters=.false.
    logical :: reset_crop_owner=.false.
    logical :: start_crop_emergence=.false.
    logical :: retire_crop_owner=.false.
    logical :: preemergence_advanced=.false.
    real(8) :: preemergence_development_stage_marker=0.d0
  end type

  public :: initialize_crop_seasonal_lifecycle
  public :: evaluate_crop_seasonal_lifecycle_day

contains

  subroutine crop_seasonal_lifecycle_clone(self,copy)
    class(crop_seasonal_lifecycle_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(crop_seasonal_lifecycle_state_t::copy)
    select type(t=>copy)
    type is(crop_seasonal_lifecycle_state_t)
      t%initialized=self%initialized
      t%rotation=self%rotation
      if(allocated(self%preemergence))then
        allocate(t%preemergence)
        t%preemergence=self%preemergence
      end if
      t%bound_crop_key=self%bound_crop_key
      t%crop_emerged=self%crop_emerged
      t%crop_harvested=self%crop_harvested
    class default
      error stop 'crop seasonal lifecycle clone failure'
    end select
  end subroutine

  integer function crop_seasonal_lifecycle_validate(self) result(status)
    class(crop_seasonal_lifecycle_state_t), intent(in) :: self
    status=CROP_SEASON_INVALID_STATE
    if(.not.self%initialized)return
    if(self%rotation%validate()/=CROP_ROTATION_OK)return
    if(self%crop_emerged.and.self%crop_harvested)return
    if(self%bound_crop_key<0)return
    if(allocated(self%preemergence))then
      if(self%preemergence%validate()/=PREEMERGENCE_OK)return
      if(self%bound_crop_key<=0.or.self%crop_emerged.or.self%crop_harvested)return
    end if
    if((self%crop_emerged.or.self%crop_harvested).and.self%bound_crop_key<=0)return
    status=CROP_SEASON_OK
  end function

  logical function crop_seasonal_preemergence_active(self) result(active)
    class(crop_seasonal_lifecycle_state_t), intent(in) :: self
    active=self%initialized.and.allocated(self%preemergence)
  end function

  subroutine initialize_crop_seasonal_lifecycle(schedule,start_time,state,status)
    type(crop_rotation_schedule_t), intent(in) :: schedule
    real(8), intent(in) :: start_time
    type(crop_seasonal_lifecycle_state_t), intent(out) :: state
    integer, intent(out) :: status
    type(crop_rotation_day_result_t) :: rotation_result
    integer :: rotation_status

    state=crop_seasonal_lifecycle_state_t()
    call initialize_crop_rotation_owner(schedule,start_time,state%rotation,rotation_result,rotation_status)
    if(rotation_status/=CROP_ROTATION_OK)then
      status=CROP_SEASON_INVALID_ROTATION
      return
    end if
    state%initialized=.true.
    status=state%validate()
  end subroutine

  subroutine evaluate_crop_seasonal_lifecycle_day(schedule,committed,current_time,initialization_phase, &
       bound_crop_key,preemergence_parameters,preemergence_forcing,harvest_committed,result,status)
    type(crop_rotation_schedule_t), intent(in) :: schedule
    type(crop_seasonal_lifecycle_state_t), intent(in) :: committed
    real(8), intent(in) :: current_time
    logical, intent(in) :: initialization_phase
    integer, intent(in) :: bound_crop_key
    type(crop_preemergence_parameters_t), intent(in) :: preemergence_parameters
    type(crop_preemergence_daily_forcing_t), intent(in) :: preemergence_forcing
    logical, intent(in) :: harvest_committed
    type(crop_seasonal_lifecycle_result_t), intent(out) :: result
    integer, intent(out) :: status

    type(crop_rotation_day_result_t) :: rr
    type(crop_preemergence_state_t) :: pre_candidate
    type(crop_preemergence_diagnostics_t) :: pre_diag
    integer :: local_status
    logical :: season_binding

    result=crop_seasonal_lifecycle_result_t()
    result%candidate=committed
    status=committed%validate()
    if(status/=CROP_SEASON_OK)return

    call evaluate_crop_rotation_day(schedule,committed%rotation,current_time,initialization_phase, &
         result%candidate%rotation,rr,local_status)
    if(local_status/=CROP_ROTATION_OK)then
      status=CROP_SEASON_INVALID_ROTATION
      return
    end if
    result%current_crop_key=rr%crop_key
    result%current_crop_type=rr%crop_type
    result%crop_calendar_active=rr%crop_calendar_active

    if(harvest_committed)then
      if(.not.committed%crop_emerged)then
        status=CROP_SEASON_INVALID_HARVEST
        return
      end if
      result%candidate%crop_emerged=.false.
      result%candidate%crop_harvested=.true.
      if(allocated(result%candidate%preemergence))deallocate(result%candidate%preemergence)
      result%retire_crop_owner=.true.
    end if

    ! Outside a crop-calendar window, a still-emerged crop indicates that the
    ! crop-end owner was not committed. Fail closed rather than silently
    ! dropping crop state at a schedule boundary.
    if(.not.rr%crop_calendar_active)then
      if(result%candidate%crop_emerged)then
        status=CROP_SEASON_MISSING_HARVEST
        return
      end if
      status=result%candidate%validate()
      return
    end if

    season_binding=rr%start_rotation.or.(initialization_phase.and.result%candidate%bound_crop_key==0)
    if(season_binding)then
      if(bound_crop_key/=rr%crop_key.or.bound_crop_key<=0)then
        status=CROP_SEASON_PARAMETER_KEY_MISMATCH
        return
      end if
      result%candidate%bound_crop_key=bound_crop_key
      result%candidate%crop_emerged=.false.
      result%candidate%crop_harvested=.false.
      if(allocated(result%candidate%preemergence))deallocate(result%candidate%preemergence)
      allocate(result%candidate%preemergence)
      call initialize_crop_preemergence_owner(preemergence_parameters,result%candidate%preemergence,local_status)
      if(local_status/=PREEMERGENCE_OK)then
        status=CROP_SEASON_PREEMERGENCE_ERROR
        return
      end if
      result%bind_crop_parameters=.true.
      result%reset_crop_owner=.true.

      ! B1.11 cropemergence checks immediately after initialization. If all
      ! selectors are already complete, emergence starts in this same call.
      if(preemergence_complete(result%candidate%preemergence))then
        result%candidate%crop_emerged=.true.
        result%start_crop_emergence=.true.
        deallocate(result%candidate%preemergence)
        status=result%candidate%validate()
        return
      end if

      ! Otherwise task-3 progress occurs today, but source does not repeat the
      ! emergence check after that update. Completion becomes emergence on the
      ! next daily lifecycle call.
      call evaluate_crop_preemergence_day(preemergence_parameters,result%candidate%preemergence, &
           preemergence_forcing,pre_candidate,pre_diag,local_status)
      if(local_status/=PREEMERGENCE_OK)then
        status=CROP_SEASON_PREEMERGENCE_ERROR
        return
      end if
      result%candidate%preemergence=pre_candidate
      result%preemergence_advanced=.true.
      result%preemergence_development_stage_marker=pre_candidate%development_stage_marker
      status=result%candidate%validate()
      return
    end if

    if(result%candidate%crop_harvested)then
      status=result%candidate%validate()
      return
    end if

    if(result%candidate%crop_emerged)then
      status=result%candidate%validate()
      return
    end if

    if(.not.allocated(result%candidate%preemergence))then
      status=CROP_SEASON_INVALID_STATE
      return
    end if
    if(result%candidate%bound_crop_key/=rr%crop_key.or.bound_crop_key/=rr%crop_key)then
      status=CROP_SEASON_PARAMETER_KEY_MISMATCH
      return
    end if

    ! First source action each day is the previous-day completion check.
    if(preemergence_complete(result%candidate%preemergence))then
      result%candidate%crop_emerged=.true.
      result%start_crop_emergence=.true.
      deallocate(result%candidate%preemergence)
      status=result%candidate%validate()
      return
    end if

    call evaluate_crop_preemergence_day(preemergence_parameters,result%candidate%preemergence, &
         preemergence_forcing,pre_candidate,pre_diag,local_status)
    if(local_status/=PREEMERGENCE_OK)then
      status=CROP_SEASON_PREEMERGENCE_ERROR
      return
    end if
    result%candidate%preemergence=pre_candidate
    result%preemergence_advanced=.true.
    result%preemergence_development_stage_marker=pre_candidate%development_stage_marker
    status=result%candidate%validate()
  end subroutine

  logical function preemergence_complete(state) result(done)
    type(crop_preemergence_state_t), intent(in) :: state
    done=state%preparation_complete.and.state%sowing_complete.and.state%germination_complete
  end function

end module mod_crop_seasonal_lifecycle_owner

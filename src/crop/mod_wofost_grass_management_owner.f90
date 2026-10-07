module mod_wofost_grass_management_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  implicit none
  private

  integer, parameter, public :: GRASS_MGMT_OK=0
  integer, parameter, public :: GRASS_MGMT_INVALID_PARAMETERS=1
  integer, parameter, public :: GRASS_MGMT_INVALID_STATE=2
  integer, parameter, public :: GRASS_MGMT_INVALID_CROP=3
  integer, parameter, public :: GRASS_MGMT_INVALID_FORCING=4
  integer, parameter, public :: GRASS_MGMT_TABLE_ERROR=5
  integer, parameter, public :: GRASS_MGMT_INVALID_RESULT=6

  integer, parameter, public :: GRASS_EVENT_GRAZE=1
  integer, parameter, public :: GRASS_EVENT_MOW=2
  integer, parameter, public :: GRASS_EVENT_GRAZE_DEWOOL=3
  integer, parameter, public :: GRASS_TRIGGER_BIOMASS=1
  integer, parameter, public :: GRASS_TRIGGER_DATE=2

  type, public :: grass_management_parameters_t
    integer :: trigger_mode=GRASS_TRIGGER_BIOMASS
    integer, allocatable :: event_sequence(:)
    real(real64), allocatable :: event_date_day(:)
    type(wofost_rate_table_t) :: mowing_biomass_trigger_by_day
    type(wofost_rate_table_t) :: grazing_biomass_trigger_by_day
    integer :: maximum_growth_days_mowing=0
    integer :: maximum_growth_days_grazing=0
    real(real64) :: mowing_residual_biomass=0.0_real64
    logical :: mowing_loss_enabled=.false.
    type(wofost_rate_table_t) :: mowing_loss_fraction_by_head
    type(wofost_rate_table_t) :: mowing_delay_by_removed_biomass
    real(real64) :: grazing_uptake_per_day=0.0_real64
    real(real64) :: grazing_fixed_loss_per_day=0.0_real64
    real(real64) :: grazing_residual_biomass=0.0_real64
    integer :: grazing_days=0
    logical :: grazing_loss_enabled=.false.
    ! Pinned B1.11 management_event uses local DMLoss uninitialised when
    ! SW_LOSSGRZ=0. This typed migration therefore supports only the
    ! source-defined SW_LOSSGRZ=1 branch until a reference-defect disposition
    ! explicitly authorizes a repair.
    type(wofost_rate_table_t) :: grazing_treading_loss_fraction_by_head
    real(real64) :: dewooling_residual_biomass=0.0_real64
    type(wofost_rate_table_t) :: leaf_partition_by_dvs
    type(wofost_rate_table_t) :: stem_partition_by_dvs
    type(wofost_rate_table_t) :: specific_leaf_area_by_dvs
  contains
    procedure, public :: ready=>grass_management_parameters_ready
  end type

  type, extends(transaction_state_t), public :: grass_management_state_t
    logical :: potential=.false.
    logical :: mowing_active=.false.
    logical :: grazing_active=.false.
    logical :: cut_ends_today=.false.
    integer :: event_index=1
    integer :: days_since_cut=0
    integer :: growth_delay_days=0
    integer :: grazing_day_count=0
    real(real64) :: dead_leaf_biomass=0.0_real64
    real(real64) :: dead_stem_biomass=0.0_real64
    real(real64) :: harvest_biomass_today=0.0_real64
    real(real64) :: loss_biomass_today=0.0_real64
  contains
    procedure :: clone=>grass_management_clone
    procedure, public :: validate=>grass_management_validate
  end type

  type, public :: grass_management_forcing_t
    real(real64) :: current_time_day=0.0_real64
    integer :: day_of_year=1
    real(real64) :: mowing_average_head_cm=0.0_real64
    real(real64) :: grazing_average_head_cm=0.0_real64
  end type

  type, public :: grass_management_result_t
    type(grass_management_state_t) :: candidate_management
    type(wofost_crop_owner_state_t) :: candidate_crop
    logical :: harvest_event=.false.
    logical :: crop_growth_may_continue=.true.
    real(real64) :: removed_total_biomass=0.0_real64
    real(real64) :: harvested_biomass=0.0_real64
    real(real64) :: lost_biomass=0.0_real64
    real(real64) :: fixed_grazing_loss_removed=0.0_real64
  end type

  public :: initialize_grass_management_state
  public :: evaluate_grass_management_day

contains

  logical function grass_management_parameters_ready(self) result(ready)
    class(grass_management_parameters_t), intent(in) :: self
    integer :: i
    ready=.false.
    if(self%trigger_mode/=GRASS_TRIGGER_BIOMASS .and. self%trigger_mode/=GRASS_TRIGGER_DATE)return
    if(.not.allocated(self%event_sequence))return
    if(size(self%event_sequence)<=0)return
    do i=1,size(self%event_sequence)
      if(self%event_sequence(i)<GRASS_EVENT_GRAZE .or. self%event_sequence(i)>GRASS_EVENT_GRAZE_DEWOOL)return
    end do
    if(self%trigger_mode==GRASS_TRIGGER_DATE)then
      if(.not.allocated(self%event_date_day))return
      if(size(self%event_date_day)<size(self%event_sequence))return
      if(any(.not.ieee_is_finite(self%event_date_day(1:size(self%event_sequence)))))return
    else
      if(.not.self%mowing_biomass_trigger_by_day%ready())return
      if(.not.self%grazing_biomass_trigger_by_day%ready())return
    end if
    if(self%maximum_growth_days_mowing<0.or.self%maximum_growth_days_grazing<0)return
    if(.not.finite_nonnegative(self%mowing_residual_biomass))return
    if(.not.finite_nonnegative(self%grazing_uptake_per_day))return
    if(.not.finite_nonnegative(self%grazing_fixed_loss_per_day))return
    if(.not.finite_nonnegative(self%grazing_residual_biomass))return
    if(self%grazing_days<1)return
    if(.not.finite_nonnegative(self%dewooling_residual_biomass))return
    if(.not.self%leaf_partition_by_dvs%ready())return
    if(.not.self%stem_partition_by_dvs%ready())return
    if(.not.self%specific_leaf_area_by_dvs%ready())return
    if(self%mowing_loss_enabled)then
      if(.not.self%mowing_loss_fraction_by_head%ready())return
    end if
    if(.not.self%mowing_delay_by_removed_biomass%ready())return
    if(.not.self%grazing_loss_enabled)return
    if(.not.self%grazing_treading_loss_fraction_by_head%ready())return
    ready=.true.
  end function

  integer function grass_management_validate(self) result(status)
    class(grass_management_state_t), intent(in) :: self
    status=GRASS_MGMT_INVALID_STATE
    if(self%event_index<1.or.self%days_since_cut<0.or.self%growth_delay_days<0.or.self%grazing_day_count<0)return
    if(.not.finite_nonnegative(self%dead_leaf_biomass))return
    if(.not.finite_nonnegative(self%dead_stem_biomass))return
    if(.not.finite_nonnegative(self%harvest_biomass_today))return
    if(.not.finite_nonnegative(self%loss_biomass_today))return
    status=GRASS_MGMT_OK
  end function

  subroutine grass_management_clone(self,copy)
    class(grass_management_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(grass_management_state_t::copy)
    select type(t=>copy)
    type is(grass_management_state_t)
      t%potential=self%potential;t%mowing_active=self%mowing_active;t%grazing_active=self%grazing_active
      t%cut_ends_today=self%cut_ends_today;t%event_index=self%event_index;t%days_since_cut=self%days_since_cut
      t%growth_delay_days=self%growth_delay_days;t%grazing_day_count=self%grazing_day_count
      t%dead_leaf_biomass=self%dead_leaf_biomass;t%dead_stem_biomass=self%dead_stem_biomass
      t%harvest_biomass_today=self%harvest_biomass_today;t%loss_biomass_today=self%loss_biomass_today
    class default
      error stop 'grass management clone failure'
    end select
  end subroutine

  subroutine initialize_grass_management_state(parameters,potential,current_time_day,state,status)
    type(grass_management_parameters_t), intent(in) :: parameters
    logical, intent(in) :: potential
    real(real64), intent(in) :: current_time_day
    type(grass_management_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer :: i

    state=grass_management_state_t()
    status=GRASS_MGMT_INVALID_PARAMETERS
    if(.not.parameters%ready())return
    if(.not.ieee_is_finite(current_time_day))then;status=GRASS_MGMT_INVALID_FORCING;return;end if
    state%potential=potential
    state%event_index=1
    if(parameters%trigger_mode==GRASS_TRIGGER_DATE)then
      do i=1,size(parameters%event_sequence)
        if(current_time_day<=parameters%event_date_day(i))exit
        state%event_index=i+1
      end do
      state%event_index=min(state%event_index,size(parameters%event_sequence))
    end if
    status=state%validate()
  end subroutine

  subroutine evaluate_grass_management_day(parameters,committed_management,committed_crop,forcing,result,status)
    type(grass_management_parameters_t), intent(in) :: parameters
    type(grass_management_state_t), intent(in) :: committed_management
    type(wofost_crop_owner_state_t), intent(in) :: committed_crop
    type(grass_management_forcing_t), intent(in) :: forcing
    type(grass_management_result_t), intent(out) :: result
    integer, intent(out) :: status

    integer :: event_kind,table_status
    real(real64) :: living_leaf,living_stem,living_storage,living_above,total_above
    real(real64) :: trigger,loss_fraction,extra_treading,twgrz,event_fraction,removed_leaf
    real(real64) :: removal,ratio,delay_value

    result=grass_management_result_t()
    result%candidate_management=committed_management
    result%candidate_crop=committed_crop
    status=GRASS_MGMT_INVALID_PARAMETERS
    if(.not.parameters%ready())return
    status=committed_management%validate();if(status/=GRASS_MGMT_OK)return
    if(committed_crop%validate()/=WOFOST_CROP_OWNER_OK.or..not.committed_crop%crop_emerged)then
      status=GRASS_MGMT_INVALID_CROP;return
    end if
    if(.not.ieee_is_finite(forcing%current_time_day).or.forcing%day_of_year<1.or.forcing%day_of_year>366.or. &
       .not.ieee_is_finite(forcing%mowing_average_head_cm).or..not.ieee_is_finite(forcing%grazing_average_head_cm))then
      status=GRASS_MGMT_INVALID_FORCING;return
    end if
    if(committed_management%event_index>size(parameters%event_sequence))then
      status=GRASS_MGMT_OK;return
    end if

    result%candidate_management%harvest_biomass_today=0.0_real64
    result%candidate_management%loss_biomass_today=0.0_real64
    result%candidate_management%cut_ends_today=.false.
    result%candidate_management%days_since_cut=committed_management%days_since_cut+1

    living_leaf=committed_crop%biomass%living_leaf_biomass()
    living_stem=committed_crop%biomass%stem_biomass
    living_storage=committed_crop%biomass%storage_biomass
    living_above=living_stem+living_leaf+living_storage
    total_above=living_above+committed_management%dead_stem_biomass+committed_management%dead_leaf_biomass
    if(total_above<=0.0_real64)then;status=GRASS_MGMT_OK;return;end if

    event_kind=parameters%event_sequence(committed_management%event_index)
    result%candidate_management%mowing_active=.false.
    if(.not.committed_management%grazing_active)result%candidate_management%grazing_active=.false.

    select case(event_kind)
    case(GRASS_EVENT_MOW)
      if(parameters%trigger_mode==GRASS_TRIGGER_BIOMASS)then
        call parameters%mowing_biomass_trigger_by_day%evaluate(real(forcing%day_of_year,real64),trigger,table_status)
        if(table_status/=WOFOST_RATE_TABLE_OK)then;status=GRASS_MGMT_TABLE_ERROR;return;end if
        if(total_above>trigger .or. (result%candidate_management%days_since_cut>parameters%maximum_growth_days_mowing .and. &
           committed_management%event_index>1))result%candidate_management%mowing_active=.true.
      else
        if(forcing%current_time_day>parameters%event_date_day(committed_management%event_index)) &
          result%candidate_management%mowing_active=.true.
      end if
      if(result%candidate_management%mowing_active)then
        result%harvest_event=.not.committed_management%potential
        call apply_mowing_reset(parameters,parameters%mowing_residual_biomass,result%candidate_crop, &
             result%candidate_management,status)
        if(status/=GRASS_MGMT_OK)return
        removal=max(0.0_real64,total_above-min(living_above,parameters%mowing_residual_biomass))
        loss_fraction=0.0_real64
        if(parameters%mowing_loss_enabled)then
          call parameters%mowing_loss_fraction_by_head%evaluate(forcing%mowing_average_head_cm,loss_fraction,table_status)
          if(table_status/=WOFOST_RATE_TABLE_OK)then;status=GRASS_MGMT_TABLE_ERROR;return;end if
        end if
        result%lost_biomass=removal*loss_fraction
        result%harvested_biomass=removal-result%lost_biomass
        call parameters%mowing_delay_by_removed_biomass%evaluate(removal,delay_value,table_status)
        if(table_status/=WOFOST_RATE_TABLE_OK)then;status=GRASS_MGMT_TABLE_ERROR;return;end if
        result%candidate_management%growth_delay_days=int(delay_value)
        result%candidate_management%cut_ends_today=.true.
        result%crop_growth_may_continue=.false.
      end if

    case(GRASS_EVENT_GRAZE,GRASS_EVENT_GRAZE_DEWOOL)
      if(.not.committed_management%grazing_active)then
        if(parameters%trigger_mode==GRASS_TRIGGER_BIOMASS)then
          call parameters%grazing_biomass_trigger_by_day%evaluate(real(forcing%day_of_year,real64),trigger,table_status)
          if(table_status/=WOFOST_RATE_TABLE_OK)then;status=GRASS_MGMT_TABLE_ERROR;return;end if
          if(total_above>trigger .or. (result%candidate_management%days_since_cut>parameters%maximum_growth_days_grazing .and. &
             committed_management%event_index>1))result%candidate_management%grazing_active=.true.
        else
          if(forcing%current_time_day>parameters%event_date_day(committed_management%event_index)) &
             result%candidate_management%grazing_active=.true.
        end if
      end if
      if(result%candidate_management%grazing_active)then
        result%harvest_event=.not.committed_management%potential
        extra_treading=0.0_real64
        if(parameters%grazing_loss_enabled)then
          call parameters%grazing_treading_loss_fraction_by_head%evaluate(forcing%grazing_average_head_cm,loss_fraction,table_status)
          if(table_status/=WOFOST_RATE_TABLE_OK)then;status=GRASS_MGMT_TABLE_ERROR;return;end if
          extra_treading=total_above*loss_fraction
        end if
        twgrz=parameters%grazing_uptake_per_day+parameters%grazing_fixed_loss_per_day+extra_treading
        if(twgrz<=0.0_real64)then;status=GRASS_MGMT_INVALID_PARAMETERS;return;end if
        event_fraction=min(1.0_real64,max(0.0_real64,total_above-parameters%grazing_residual_biomass)/twgrz)
        removal=twgrz*event_fraction
        ratio=removal/total_above
        result%candidate_crop%biomass%stem_biomass=max(0.0_real64,living_stem*(1.0_real64-ratio))
        result%candidate_management%dead_stem_biomass=max(0.0_real64,committed_management%dead_stem_biomass*(1.0_real64-ratio))
        result%candidate_management%dead_leaf_biomass=max(0.0_real64,committed_management%dead_leaf_biomass*(1.0_real64-ratio))
        removed_leaf=living_leaf*ratio
        call remove_oldest_leaf_biomass(result%candidate_crop,removed_leaf,status)
        if(status/=GRASS_MGMT_OK)return

        result%harvested_biomass=parameters%grazing_uptake_per_day*event_fraction
        result%lost_biomass=extra_treading*event_fraction
        result%fixed_grazing_loss_removed=parameters%grazing_fixed_loss_per_day*event_fraction
        result%removed_total_biomass=removal
        result%candidate_management%grazing_day_count=committed_management%grazing_day_count+1
        if(result%candidate_management%grazing_day_count>=parameters%grazing_days.or.event_fraction<1.0_real64) &
           result%candidate_management%cut_ends_today=.true.

        if(event_kind==GRASS_EVENT_GRAZE_DEWOOL.and.result%candidate_management%cut_ends_today.and. &
           total_above>=parameters%dewooling_residual_biomass)then
          call apply_mowing_reset(parameters,parameters%dewooling_residual_biomass,result%candidate_crop, &
               result%candidate_management,status)
          if(status/=GRASS_MGMT_OK)return
          result%candidate_management%growth_delay_days=1
          result%crop_growth_may_continue=.false.
        end if
      end if
    end select

    if(result%removed_total_biomass<=0.0_real64) &
      result%removed_total_biomass=result%harvested_biomass+result%lost_biomass
    result%candidate_management%harvest_biomass_today=result%harvested_biomass
    result%candidate_management%loss_biomass_today=result%lost_biomass

    if(result%candidate_management%cut_ends_today)then
      result%candidate_management%mowing_active=.false.
      result%candidate_management%grazing_active=.false.
      result%candidate_management%event_index=committed_management%event_index+1
      result%candidate_management%days_since_cut=0
      result%candidate_management%grazing_day_count=0
    end if

    if(result%candidate_crop%validate()/=WOFOST_CROP_OWNER_OK.or.result%candidate_management%validate()/=GRASS_MGMT_OK)then
      status=GRASS_MGMT_INVALID_RESULT;return
    end if
    status=GRASS_MGMT_OK
  end subroutine

  subroutine apply_mowing_reset(parameters,dmrest,crop,management,status)
    type(grass_management_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: dmrest
    type(wofost_crop_owner_state_t), intent(inout) :: crop
    type(grass_management_state_t), intent(inout) :: management
    integer, intent(out) :: status
    real(real64) :: wlv,wst,fl,fs,sla,new_wlv,new_wst
    integer :: n,table_status

    status=GRASS_MGMT_INVALID_CROP
    if(.not.finite_nonnegative(dmrest))return
    if(.not.parameters%ready())then
      status=GRASS_MGMT_INVALID_PARAMETERS
      return
    end if

    call parameters%leaf_partition_by_dvs%evaluate(crop%development_stage,fl,table_status)
    if(table_status/=WOFOST_RATE_TABLE_OK)then;status=GRASS_MGMT_TABLE_ERROR;return;end if
    call parameters%stem_partition_by_dvs%evaluate(crop%development_stage,fs,table_status)
    if(table_status/=WOFOST_RATE_TABLE_OK)then;status=GRASS_MGMT_TABLE_ERROR;return;end if
    call parameters%specific_leaf_area_by_dvs%evaluate(crop%development_stage,sla,table_status)
    if(table_status/=WOFOST_RATE_TABLE_OK)then;status=GRASS_MGMT_TABLE_ERROR;return;end if
    if(fl<=0.0_real64.or.fs<0.0_real64.or.sla<0.0_real64)then
      status=GRASS_MGMT_INVALID_PARAMETERS
      return
    end if

    wlv=crop%biomass%living_leaf_biomass()
    wst=crop%biomass%stem_biomass

    ! Literal B1.11 mowing_event: reset living WLV/WST to DMREST using the
    ! current DVS FLTB/FSTB ratio. Storage organs and root biomass are untouched.
    if(dmrest<(wlv+wst))then
      new_wlv=min(dmrest,wlv+wst)/(1.0_real64+(fs/fl))
      new_wst=(fs/fl)*new_wlv
      crop%biomass%stem_biomass=new_wst
      if(.not.allocated(crop%biomass%leaf_biomass))then
        status=GRASS_MGMT_INVALID_CROP
        return
      end if
      crop%biomass%leaf_biomass=0.0_real64
      crop%biomass%leaf_biomass(1)=new_wlv
    end if

    management%dead_leaf_biomass=0.0_real64
    management%dead_stem_biomass=0.0_real64

    if(.not.allocated(crop%biomass%leaf_biomass).or. &
       .not.allocated(crop%biomass%specific_leaf_area).or. &
       .not.allocated(crop%biomass%leaf_age))then
      status=GRASS_MGMT_INVALID_CROP
      return
    end if
    n=size(crop%biomass%leaf_biomass)
    if(n<1.or.size(crop%biomass%specific_leaf_area)/=n.or.size(crop%biomass%leaf_age)/=n)then
      status=GRASS_MGMT_INVALID_CROP
      return
    end if

    ! Source resets to one active cohort, SLA(1)=AFGEN(SLATB,DVS),
    ! all leaf ages/dead pools to zero, and LAIEXP=LASUM.
    wlv=crop%biomass%living_leaf_biomass()
    crop%biomass%leaf_biomass=0.0_real64
    crop%biomass%leaf_biomass(1)=wlv
    crop%biomass%specific_leaf_area=0.0_real64
    crop%biomass%specific_leaf_area(1)=sla
    crop%biomass%leaf_age=0.0_real64
    crop%biomass%exponential_leaf_area_index=crop%biomass%leaf_area_sum()

    status=GRASS_MGMT_OK
  end subroutine apply_mowing_reset

  subroutine remove_oldest_leaf_biomass(crop,amount,status)
    type(wofost_crop_owner_state_t), intent(inout) :: crop
    real(real64), intent(in) :: amount
    integer, intent(out) :: status
    real(real64) :: remaining
    integer :: i
    status=GRASS_MGMT_INVALID_CROP
    if(.not.finite_nonnegative(amount))return
    if(.not.allocated(crop%biomass%leaf_biomass))then
      if(abs(amount)<=tiny(1.0_real64))status=GRASS_MGMT_OK
      return
    end if
    remaining=amount
    do i=size(crop%biomass%leaf_biomass),1,-1
      if(remaining<=0.0_real64)exit
      if(remaining>=crop%biomass%leaf_biomass(i))then
        remaining=remaining-crop%biomass%leaf_biomass(i)
        crop%biomass%leaf_biomass(i)=0.0_real64
      else
        crop%biomass%leaf_biomass(i)=crop%biomass%leaf_biomass(i)-remaining
        remaining=0.0_real64
      end if
    end do
    if(remaining>256.0_real64*epsilon(1.0_real64))return
    status=GRASS_MGMT_OK
  end subroutine

  pure logical function finite_nonnegative(value) result(ok)
    real(real64), intent(in) :: value
    ok=ieee_is_finite(value).and.value>=0.0_real64
  end function

end module mod_wofost_grass_management_owner

module mod_crop_preemergence_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  integer, parameter, public :: PREEMERGENCE_OK=0
  integer, parameter, public :: PREEMERGENCE_INVALID_PARAMETERS=1
  integer, parameter, public :: PREEMERGENCE_INVALID_STATE=2
  integer, parameter, public :: PREEMERGENCE_INVALID_FORCING=3

  integer, parameter, public :: GERMINATION_OFF=0
  integer, parameter, public :: GERMINATION_TEMPERATURE=1
  integer, parameter, public :: GERMINATION_TEMPERATURE_WATER=2

  type, public :: crop_preemergence_parameters_t
    logical :: preparation_enabled=.false.
    real(real64) :: preparation_head_threshold_cm=0.0_real64
    integer :: maximum_preparation_delay_days=1

    logical :: sowing_enabled=.false.
    real(real64) :: sowing_head_threshold_cm=0.0_real64
    real(real64) :: sowing_temperature_threshold_c=0.0_real64
    integer :: maximum_sowing_delay_days=1

    integer :: germination_mode=GERMINATION_OFF
    real(real64) :: optimal_emergence_temperature_sum=0.0_real64 ! TSUMEMEOPT
    real(real64) :: germination_base_temperature_c=0.0_real64     ! TBASEM
    real(real64) :: germination_effective_max_temperature_c=0.0_real64 ! TEFFMX
    real(real64) :: dry_germination_head_cm=-1000.0_real64       ! HDRYGERM
    real(real64) :: wet_germination_head_cm=-100.0_real64        ! HWETGERM
    real(real64) :: germination_head_slope=1.0_real64             ! AGERM
  contains
    procedure, public :: ready=>crop_preemergence_parameters_ready
  end type

  type, extends(transaction_state_t), public :: crop_preemergence_state_t
    logical :: preparation_complete=.true.
    logical :: sowing_complete=.true.
    logical :: germination_complete=.true.
    integer :: preparation_delay_days=0
    integer :: sowing_delay_days=0
    real(real64) :: germination_temperature_sum=0.0_real64
    real(real64) :: development_stage_marker=0.0_real64
  contains
    procedure :: clone=>crop_preemergence_clone
    procedure, public :: validate=>crop_preemergence_validate
  end type

  type, public :: crop_preemergence_daily_forcing_t
    real(real64) :: preparation_average_head_cm=0.0_real64
    real(real64) :: sowing_average_head_cm=0.0_real64
    real(real64) :: sowing_soil_temperature_c=0.0_real64
    real(real64) :: germination_average_head_cm=-100.0_real64
    real(real64) :: average_air_temperature_c=0.0_real64
  end type

  type, public :: crop_preemergence_diagnostics_t
    logical :: preparation_delayed=.false.
    logical :: sowing_delayed=.false.
    logical :: germination_delayed=.false.
    real(real64) :: effective_germination_requirement=0.0_real64
    real(real64) :: germination_temperature_increment=0.0_real64
  end type

  public :: initialize_crop_preemergence_owner
  public :: evaluate_crop_preemergence_day

contains

  logical function crop_preemergence_parameters_ready(self) result(ready)
    class(crop_preemergence_parameters_t), intent(in) :: self
    ready=.false.
    if(self%maximum_preparation_delay_days<1.or.self%maximum_preparation_delay_days>366)return
    if(self%maximum_sowing_delay_days<1.or.self%maximum_sowing_delay_days>366)return
    if(.not.ieee_is_finite(self%preparation_head_threshold_cm))return
    if(.not.ieee_is_finite(self%sowing_head_threshold_cm))return
    if(.not.ieee_is_finite(self%sowing_temperature_threshold_c))return
    if(self%germination_mode<GERMINATION_OFF.or.self%germination_mode>GERMINATION_TEMPERATURE_WATER)return
    if(self%germination_mode>=GERMINATION_TEMPERATURE)then
      if(.not.ieee_is_finite(self%optimal_emergence_temperature_sum).or.self%optimal_emergence_temperature_sum<0.0_real64)return
      if(.not.ieee_is_finite(self%germination_base_temperature_c))return
      if(.not.ieee_is_finite(self%germination_effective_max_temperature_c))return
      if(self%germination_effective_max_temperature_c<self%germination_base_temperature_c)return
    end if
    if(self%germination_mode==GERMINATION_TEMPERATURE_WATER)then
      if(.not.ieee_is_finite(self%dry_germination_head_cm).or..not.ieee_is_finite(self%wet_germination_head_cm))return
      if(self%dry_germination_head_cm>=0.0_real64.or.self%wet_germination_head_cm>=0.0_real64)return
      if(self%dry_germination_head_cm>=self%wet_germination_head_cm)return
      if(.not.ieee_is_finite(self%germination_head_slope).or.self%germination_head_slope<=0.0_real64)return
    end if
    ready=.true.
  end function

  integer function crop_preemergence_validate(self) result(status)
    class(crop_preemergence_state_t), intent(in) :: self
    status=PREEMERGENCE_INVALID_STATE
    if(self%preparation_delay_days<0.or.self%sowing_delay_days<0)return
    if(.not.ieee_is_finite(self%germination_temperature_sum).or.self%germination_temperature_sum<0.0_real64)return
    if(.not.ieee_is_finite(self%development_stage_marker))return
    if(self%development_stage_marker < -0.3_real64 .or. self%development_stage_marker > 0.0_real64)return
    status=PREEMERGENCE_OK
  end function

  subroutine crop_preemergence_clone(self,copy)
    class(crop_preemergence_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(crop_preemergence_state_t::copy)
    select type(t=>copy)
    type is(crop_preemergence_state_t)
      t%preparation_complete=self%preparation_complete
      t%sowing_complete=self%sowing_complete
      t%germination_complete=self%germination_complete
      t%preparation_delay_days=self%preparation_delay_days
      t%sowing_delay_days=self%sowing_delay_days
      t%germination_temperature_sum=self%germination_temperature_sum
      t%development_stage_marker=self%development_stage_marker
    class default
      error stop 'preemergence clone failure'
    end select
  end subroutine

  subroutine initialize_crop_preemergence_owner(parameters,state,status)
    type(crop_preemergence_parameters_t), intent(in) :: parameters
    type(crop_preemergence_state_t), intent(out) :: state
    integer, intent(out) :: status
    state=crop_preemergence_state_t()
    status=PREEMERGENCE_INVALID_PARAMETERS
    if(.not.parameters%ready())return
    state%preparation_complete=.not.parameters%preparation_enabled
    state%sowing_complete=.not.parameters%sowing_enabled
    state%germination_complete=parameters%germination_mode==GERMINATION_OFF
    state%preparation_delay_days=0
    state%sowing_delay_days=0
    state%germination_temperature_sum=0.0_real64
    state%development_stage_marker=0.0_real64
    status=state%validate()
  end subroutine

  subroutine evaluate_crop_preemergence_day(parameters,committed,forcing,candidate,diagnostics,status)
    type(crop_preemergence_parameters_t), intent(in) :: parameters
    type(crop_preemergence_state_t), intent(in) :: committed
    type(crop_preemergence_daily_forcing_t), intent(in) :: forcing
    type(crop_preemergence_state_t), intent(out) :: candidate
    type(crop_preemergence_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    real(real64) :: dh, dtemp, h_avg, pf_avg
    real(real64) :: tsum_req, bgerm, cgerm, thermal_increment

    candidate=committed
    diagnostics=crop_preemergence_diagnostics_t()
    status=PREEMERGENCE_INVALID_PARAMETERS
    if(.not.parameters%ready())return
    status=committed%validate()
    if(status/=PREEMERGENCE_OK)return
    status=PREEMERGENCE_INVALID_FORCING
    if(.not.ieee_is_finite(forcing%preparation_average_head_cm).or. &
       .not.ieee_is_finite(forcing%sowing_average_head_cm).or. &
       .not.ieee_is_finite(forcing%sowing_soil_temperature_c).or. &
       .not.ieee_is_finite(forcing%germination_average_head_cm).or. &
       .not.ieee_is_finite(forcing%average_air_temperature_c))return

    ! Pinned B1.11 preparation(task=3). While delayed, DVS=-0.3.
    if(.not.candidate%preparation_complete)then
      dh=forcing%preparation_average_head_cm-parameters%preparation_head_threshold_cm
      candidate%preparation_complete=.true.
      if(dh>0.0_real64.and.candidate%preparation_delay_days<parameters%maximum_preparation_delay_days)then
        candidate%development_stage_marker=-0.3_real64
        candidate%preparation_complete=.false.
        candidate%preparation_delay_days=candidate%preparation_delay_days+1
        diagnostics%preparation_delayed=.true.
      end if
      ! Source assigns DELAY_SOW=DELAY_PREP on every preparation update.
      candidate%sowing_delay_days=candidate%preparation_delay_days
    end if

    if(.not.candidate%preparation_complete)then
      status=candidate%validate()
      return
    end if

    ! Pinned B1.11 sowing(task=3). Temperature and wetness both gate sowing.
    if(.not.candidate%sowing_complete)then
      dh=forcing%sowing_average_head_cm-parameters%sowing_head_threshold_cm
      dtemp=forcing%sowing_soil_temperature_c-parameters%sowing_temperature_threshold_c
      candidate%sowing_complete=.true.
      if((dtemp<0.0_real64.or.dh>0.0_real64).and. &
         candidate%sowing_delay_days<parameters%maximum_sowing_delay_days)then
        candidate%development_stage_marker=-0.2_real64
        candidate%sowing_complete=.false.
        candidate%sowing_delay_days=candidate%sowing_delay_days+1
        diagnostics%sowing_delayed=.true.
      end if
    end if

    if(.not.candidate%sowing_complete)then
      status=candidate%validate()
      return
    end if

    if(parameters%germination_mode==GERMINATION_OFF)then
      candidate%germination_complete=.true.
      candidate%development_stage_marker=0.0_real64
      status=candidate%validate()
      return
    end if

    ! Pinned B1.11 germination(task=3).
    if(.not.candidate%germination_complete)then
      tsum_req=parameters%optimal_emergence_temperature_sum
      if(parameters%germination_mode==GERMINATION_TEMPERATURE_WATER)then
        h_avg=forcing%germination_average_head_cm
        pf_avg=log10(max(1.0_real64,-h_avg))
        cgerm=-(parameters%optimal_emergence_temperature_sum - &
                parameters%germination_head_slope*log10(-parameters%dry_germination_head_cm))
        bgerm= (parameters%optimal_emergence_temperature_sum + &
                parameters%germination_head_slope*log10(-parameters%wet_germination_head_cm))
        if(h_avg<parameters%dry_germination_head_cm)then
          tsum_req=parameters%germination_head_slope*pf_avg-cgerm
        else if(h_avg<=parameters%wet_germination_head_cm)then
          tsum_req=parameters%optimal_emergence_temperature_sum
        else
          tsum_req=-parameters%germination_head_slope*pf_avg+bgerm
        end if
      end if
      diagnostics%effective_germination_requirement=tsum_req

      thermal_increment=0.0_real64
      if(forcing%average_air_temperature_c>parameters%germination_base_temperature_c)then
        if(forcing%average_air_temperature_c<parameters%germination_effective_max_temperature_c)then
          thermal_increment=forcing%average_air_temperature_c-parameters%germination_base_temperature_c
        else
          thermal_increment=parameters%germination_effective_max_temperature_c-parameters%germination_base_temperature_c
        end if
        if(tsum_req>=0.1_real64)then
          thermal_increment=(parameters%optimal_emergence_temperature_sum/tsum_req)*thermal_increment
        end if
      end if
      diagnostics%germination_temperature_increment=thermal_increment
      candidate%germination_temperature_sum=candidate%germination_temperature_sum+thermal_increment

      candidate%germination_complete=.true.
      if(candidate%germination_temperature_sum<parameters%optimal_emergence_temperature_sum)then
        if(parameters%optimal_emergence_temperature_sum>0.0_real64)then
          candidate%development_stage_marker=-0.1_real64*max(1.0_real64- &
               candidate%germination_temperature_sum/parameters%optimal_emergence_temperature_sum,0.0_real64)
        else
          candidate%development_stage_marker=0.0_real64
        end if
        candidate%germination_complete=.false.
        diagnostics%germination_delayed=.true.
      else
        candidate%development_stage_marker=0.0_real64
      end if
    end if

    status=candidate%validate()
  end subroutine

end module mod_crop_preemergence_owner

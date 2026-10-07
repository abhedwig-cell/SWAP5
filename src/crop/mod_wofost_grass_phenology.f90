module mod_wofost_grass_phenology
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: GRASS_PHENOLOGY_OK=0
  integer, parameter, public :: GRASS_PHENOLOGY_INVALID_PARAMETERS=1
  integer, parameter, public :: GRASS_PHENOLOGY_INVALID_STATE=2
  integer, parameter, public :: GRASS_PHENOLOGY_INVALID_FORCING=3

  integer, parameter, public :: GRASS_TSUM_ALWAYS=0
  integer, parameter, public :: GRASS_TSUM_AIR_THRESHOLD=1
  integer, parameter, public :: GRASS_TSUM_SOIL_PERSISTENCE=2

  type, public :: grass_phenology_parameters_t
    integer :: temperature_sum_mode=GRASS_TSUM_ALWAYS ! SWTSUM
    real(real64) :: soil_temperature_threshold_c=0.0_real64 ! TEMPTSUM
    integer :: soil_temperature_days_required=0 ! T_TEMPTSUM
  contains
    procedure, public :: ready=>grass_phenology_parameters_ready
  end type

  type, public :: grass_phenology_state_t
    integer :: qualifying_soil_temperature_days=0 ! T_TSUMCUM
  contains
    procedure, public :: validate=>grass_phenology_state_validate
  end type

  type, public :: grass_phenology_daily_result_t
    real(real64) :: temperature_sum_increment=0.0_real64
    real(real64) :: development_rate=2.0_real64/366.0_real64
    logical :: development_enabled=.false.
    type(grass_phenology_state_t) :: candidate_state
  end type

  public :: evaluate_grass_phenology_day

contains

  logical function grass_phenology_parameters_ready(self) result(ready)
    class(grass_phenology_parameters_t), intent(in) :: self
    ready=.false.
    if(self%temperature_sum_mode<GRASS_TSUM_ALWAYS .or. self%temperature_sum_mode>GRASS_TSUM_SOIL_PERSISTENCE)return
    if(.not.ieee_is_finite(self%soil_temperature_threshold_c))return
    if(self%temperature_sum_mode==GRASS_TSUM_SOIL_PERSISTENCE)then
      if(self%soil_temperature_days_required<1)return
    end if
    ready=.true.
  end function

  integer function grass_phenology_state_validate(self) result(status)
    class(grass_phenology_state_t), intent(in) :: self
    status=GRASS_PHENOLOGY_INVALID_STATE
    if(self%qualifying_soil_temperature_days<0)return
    status=GRASS_PHENOLOGY_OK
  end function

  subroutine evaluate_grass_phenology_day(parameters,committed,current_temperature_sum, &
       average_air_temperature_c,soil_temperature_c,result,status)
    type(grass_phenology_parameters_t), intent(in) :: parameters
    type(grass_phenology_state_t), intent(in) :: committed
    real(real64), intent(in) :: current_temperature_sum,average_air_temperature_c,soil_temperature_c
    type(grass_phenology_daily_result_t), intent(out) :: result
    integer, intent(out) :: status

    result=grass_phenology_daily_result_t()
    result%candidate_state=committed
    status=GRASS_PHENOLOGY_INVALID_PARAMETERS
    if(.not.parameters%ready())return
    status=committed%validate()
    if(status/=GRASS_PHENOLOGY_OK)return
    status=GRASS_PHENOLOGY_INVALID_FORCING
    if(.not.ieee_is_finite(current_temperature_sum).or.current_temperature_sum<0.0_real64)return
    if(.not.ieee_is_finite(average_air_temperature_c).or..not.ieee_is_finite(soil_temperature_c))return

    ! Pinned B1.11 update_dvs_rate(), SWWOFOST=3.
    result%temperature_sum_increment=max(0.0_real64,average_air_temperature_c)
    select case(parameters%temperature_sum_mode)
    case(GRASS_TSUM_AIR_THRESHOLD)
      if(current_temperature_sum+result%temperature_sum_increment>=200.0_real64)result%development_enabled=.true.
    case(GRASS_TSUM_SOIL_PERSISTENCE)
      if(soil_temperature_c-parameters%soil_temperature_threshold_c>=0.0_real64)then
        result%candidate_state%qualifying_soil_temperature_days=committed%qualifying_soil_temperature_days+1
      end if
      if(result%candidate_state%qualifying_soil_temperature_days>=parameters%soil_temperature_days_required) &
        result%development_enabled=.true.
    case default
      result%development_enabled=.true.
    end select

    status=result%candidate_state%validate()
  end subroutine

end module mod_wofost_grass_phenology

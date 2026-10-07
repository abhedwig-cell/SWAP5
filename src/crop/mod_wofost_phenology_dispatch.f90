module mod_wofost_phenology_dispatch
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_phenology_rate_contract, only: wofost_phenology_rate_t, WOFOST_PHENOLOGY_RATE_OK
  use mod_wofost_soybean_phenology_factors, only: soybean_phenology_parameters_t, &
       soybean_daily_development_rate, SOY_PHENOLOGY_OK
  use mod_wofost_vernalisation_phenology, only: wofost_vernalisation_parameters_t, &
       wofost_vernalisation_daily_result_t, evaluate_wofost_idsl2_daily_candidate, WOFOST_VERN_OK
  implicit none
  private

  integer, parameter, public :: WOFOST_PHENOLOGY_CLASSIC = 0
  integer, parameter, public :: WOFOST_PHENOLOGY_SOYBEAN = 1
  integer, parameter, public :: WOFOST_PHENOLOGY_VERNALISATION = 2

  integer, parameter, public :: WOFOST_PHENOLOGY_DISPATCH_OK=0
  integer, parameter, public :: WOFOST_PHENOLOGY_DISPATCH_INVALID_OWNER=1
  integer, parameter, public :: WOFOST_PHENOLOGY_DISPATCH_INVALID_REQUEST=2
  integer, parameter, public :: WOFOST_PHENOLOGY_DISPATCH_COMPONENT_ERROR=3
  integer, parameter, public :: WOFOST_PHENOLOGY_DISPATCH_MISSING_STATE=4

  type, public :: wofost_phenology_request_t
    integer :: mode=WOFOST_PHENOLOGY_CLASSIC
    real(real64) :: average_temperature_c=0.0_real64
    real(real64) :: photoperiod_factor=1.0_real64
    real(real64) :: temperature_sum_increment=0.0_real64
    real(real64) :: vegetative_temperature_sum_required=0.0_real64
    real(real64) :: latitude_degrees=0.0_real64
    integer :: day_of_year=1
  end type

  type, public :: wofost_phenology_dispatch_result_t
    logical :: override_available=.false.
    type(wofost_phenology_rate_t) :: rate
    logical :: vernalisation_candidate_available=.false.
    type(wofost_vernalisation_daily_result_t) :: vernalisation
  end type

  public :: resolve_wofost_phenology

contains

  subroutine resolve_wofost_phenology(owner,request,soybean_parameters,vernalisation_parameters,result,status)
    type(wofost_crop_owner_state_t), intent(in) :: owner
    type(wofost_phenology_request_t), intent(in) :: request
    type(soybean_phenology_parameters_t), intent(in), optional :: soybean_parameters
    type(wofost_vernalisation_parameters_t), intent(in), optional :: vernalisation_parameters
    type(wofost_phenology_dispatch_result_t), intent(out) :: result
    integer, intent(out) :: status

    integer :: component_status
    logical :: anthesis_candidate,anthesis_triggered
    real(real64) :: dtsum,dvr

    result=wofost_phenology_dispatch_result_t()
    status=WOFOST_PHENOLOGY_DISPATCH_INVALID_OWNER
    if(owner%validate()/=WOFOST_CROP_OWNER_OK)return
    if(.not.owner%crop_emerged)then
      status=WOFOST_PHENOLOGY_DISPATCH_OK
      return
    end if

    status=WOFOST_PHENOLOGY_DISPATCH_INVALID_REQUEST
    if(.not.ieee_is_finite(request%average_temperature_c))return

    select case(request%mode)
    case(WOFOST_PHENOLOGY_CLASSIC)
      ! No override: the admitted IDSL0/1 finalizer remains authoritative.
      status=WOFOST_PHENOLOGY_DISPATCH_OK
      return

    case(WOFOST_PHENOLOGY_SOYBEAN)
      if(.not.present(soybean_parameters))return
      if(.not.ieee_is_finite(request%latitude_degrees).or.abs(request%latitude_degrees)>90.0_real64)return
      if(request%day_of_year<1.or.request%day_of_year>366)return
      call soybean_daily_development_rate(soybean_parameters,owner%development_stage,request%average_temperature_c, &
           request%latitude_degrees,request%day_of_year, &
           owner%evolution_continuation%anthesis_reached,dtsum,dvr,anthesis_candidate,anthesis_triggered,component_status)
      if(component_status/=SOY_PHENOLOGY_OK)then
        status=WOFOST_PHENOLOGY_DISPATCH_COMPONENT_ERROR
        return
      end if
      result%rate%temperature_sum_increment=dtsum
      result%rate%development_rate=dvr
      result%override_available=.true.

    case(WOFOST_PHENOLOGY_VERNALISATION)
      if(.not.present(vernalisation_parameters))return
      if(.not.allocated(owner%vernalisation))then
        status=WOFOST_PHENOLOGY_DISPATCH_MISSING_STATE
        return
      end if
      if(.not.ieee_is_finite(request%photoperiod_factor).or.request%photoperiod_factor<0.0_real64.or. &
           request%photoperiod_factor>1.0_real64)return
      if(.not.ieee_is_finite(request%temperature_sum_increment).or.request%temperature_sum_increment<0.0_real64)return
      if(.not.ieee_is_finite(request%vegetative_temperature_sum_required).or. &
           request%vegetative_temperature_sum_required<=0.0_real64)return
      call evaluate_wofost_idsl2_daily_candidate(vernalisation_parameters,owner%vernalisation,owner%development_stage, &
           request%average_temperature_c,request%photoperiod_factor,request%temperature_sum_increment, &
           request%vegetative_temperature_sum_required,result%vernalisation,component_status)
      if(component_status/=WOFOST_VERN_OK)then
        status=WOFOST_PHENOLOGY_DISPATCH_COMPONENT_ERROR
        return
      end if
      result%rate%temperature_sum_increment=request%temperature_sum_increment
      result%rate%development_rate=result%vernalisation%development_rate
      result%override_available=.true.
      result%vernalisation_candidate_available=.true.

    case default
      return
    end select

    if(result%rate%validate()/=WOFOST_PHENOLOGY_RATE_OK)then
      result=wofost_phenology_dispatch_result_t()
      status=WOFOST_PHENOLOGY_DISPATCH_COMPONENT_ERROR
      return
    end if
    status=WOFOST_PHENOLOGY_DISPATCH_OK
  end subroutine

end module mod_wofost_phenology_dispatch

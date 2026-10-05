module mod_crop_calendar_management_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_CALENDAR_OK = 0
  integer, parameter, public :: CROP_CALENDAR_INVALID = 1

  type, public :: crop_calendar_management_parameters_t
    integer :: preparation_mode = 0
    integer :: sowing_mode = 0
    integer :: germination_mode = 0
    integer :: maximum_preparation_delay = 0
    integer :: maximum_sowing_delay = 0
    real(real64) :: preparation_head_limit_cm = 0.0_real64
    real(real64) :: sowing_head_limit_cm = 0.0_real64
    real(real64) :: sowing_temperature_c = 0.0_real64
    real(real64) :: optimum_emergence_temperature_sum = 0.0_real64
    real(real64) :: base_temperature_c = 0.0_real64
    real(real64) :: maximum_effective_temperature_c = 0.0_real64
    real(real64) :: dry_germination_head_cm = -1000.0_real64
    real(real64) :: wet_germination_head_cm = -1.0_real64
    real(real64) :: germination_head_coefficient = 0.0_real64
  end type

  type, public :: crop_calendar_management_state_t
    logical :: prepared = .false.
    logical :: sown = .false.
    logical :: emerged = .false.
    integer :: preparation_delay_days = 0
    integer :: sowing_delay_days = 0
    real(real64) :: germination_temperature_sum = 0.0_real64
  end type

  type, public :: crop_calendar_management_observation_t
    real(real64) :: preparation_average_head_cm = 0.0_real64
    real(real64) :: sowing_average_head_cm = 0.0_real64
    real(real64) :: germination_average_head_cm = 0.0_real64
    real(real64) :: sowing_soil_temperature_c = 0.0_real64
    real(real64) :: daily_mean_air_temperature_c = 0.0_real64
  end type

  public :: advance_crop_calendar_day
contains
  pure subroutine advance_crop_calendar_day(parameters, observation, committed, candidate, status)
    type(crop_calendar_management_parameters_t), intent(in) :: parameters
    type(crop_calendar_management_observation_t), intent(in) :: observation
    type(crop_calendar_management_state_t), intent(in) :: committed
    type(crop_calendar_management_state_t), intent(out) :: candidate
    integer, intent(out) :: status
    real(real64) :: requisite_sum, pf, dry_intercept, wet_intercept, effective_temp

    candidate = committed
    status = CROP_CALENDAR_INVALID
    if (parameters%preparation_mode < 0 .or. parameters%preparation_mode > 1 .or. &
        parameters%sowing_mode < 0 .or. parameters%sowing_mode > 1 .or. &
        parameters%germination_mode < 0 .or. parameters%germination_mode > 2) return
    if (parameters%maximum_preparation_delay < 0 .or. parameters%maximum_sowing_delay < 0) return
    if (committed%preparation_delay_days < 0 .or. committed%sowing_delay_days < 0 .or. &
        committed%germination_temperature_sum < 0.0_real64) return
    if (committed%sown .and. .not. committed%prepared) return
    if (committed%emerged .and. .not. committed%sown) return
    if (.not. all(ieee_is_finite([observation%preparation_average_head_cm, &
         observation%sowing_average_head_cm,observation%germination_average_head_cm, &
         observation%sowing_soil_temperature_c,observation%daily_mean_air_temperature_c, &
         parameters%preparation_head_limit_cm,parameters%sowing_head_limit_cm, &
         parameters%sowing_temperature_c,parameters%optimum_emergence_temperature_sum, &
         parameters%base_temperature_c,parameters%maximum_effective_temperature_c, &
         parameters%dry_germination_head_cm,parameters%wet_germination_head_cm, &
         parameters%germination_head_coefficient,committed%germination_temperature_sum]))) return
    if (parameters%sowing_mode == 1 .and. &
        parameters%maximum_effective_temperature_c <= parameters%base_temperature_c) return
    if (parameters%germination_mode > 0) then
      if (parameters%optimum_emergence_temperature_sum <= 0.0_real64 .or. &
          parameters%maximum_effective_temperature_c <= parameters%base_temperature_c) return
    end if
    if (parameters%germination_mode == 2) then
      if (parameters%dry_germination_head_cm >= parameters%wet_germination_head_cm .or. &
          parameters%wet_germination_head_cm >= 0.0_real64 .or. &
          parameters%germination_head_coefficient <= 0.0_real64) return
    end if

    if (.not. committed%prepared) then
      if (parameters%preparation_mode == 1 .and. &
          observation%preparation_average_head_cm > parameters%preparation_head_limit_cm .and. &
          committed%preparation_delay_days < parameters%maximum_preparation_delay) then
        candidate%preparation_delay_days = committed%preparation_delay_days + 1
      else
        candidate%prepared = .true.
      end if
      status = CROP_CALENDAR_OK
      return
    end if
    if (.not. committed%sown) then
      if (parameters%sowing_mode == 1 .and. &
          (observation%sowing_average_head_cm > parameters%sowing_head_limit_cm .or. &
           observation%sowing_soil_temperature_c < parameters%sowing_temperature_c) .and. &
          committed%sowing_delay_days < parameters%maximum_sowing_delay) then
        candidate%sowing_delay_days = committed%sowing_delay_days + 1
      else
        candidate%sown = .true.
      end if
      status = CROP_CALENDAR_OK
      return
    end if
    if (committed%emerged) then
      status = CROP_CALENDAR_OK
      return
    end if
    if (parameters%germination_mode == 0) then
      candidate%emerged = .true.
      status = CROP_CALENDAR_OK
      return
    end if

    requisite_sum = parameters%optimum_emergence_temperature_sum
    if (parameters%germination_mode == 2) then
      pf = log10(max(1.0_real64,-observation%germination_average_head_cm))
      dry_intercept = -(requisite_sum-parameters%germination_head_coefficient* &
           log10(-parameters%dry_germination_head_cm))
      wet_intercept = requisite_sum+parameters%germination_head_coefficient* &
           log10(-parameters%wet_germination_head_cm)
      if (observation%germination_average_head_cm < parameters%dry_germination_head_cm) then
        requisite_sum = parameters%germination_head_coefficient*pf-dry_intercept
      else if (observation%germination_average_head_cm > parameters%wet_germination_head_cm) then
        requisite_sum = -parameters%germination_head_coefficient*pf+wet_intercept
      end if
    end if
    effective_temp = min(observation%daily_mean_air_temperature_c, &
         parameters%maximum_effective_temperature_c)-parameters%base_temperature_c
    if (effective_temp > 0.0_real64) then
      if (requisite_sum < 0.1_real64) then
        candidate%germination_temperature_sum = committed%germination_temperature_sum+effective_temp
      else
        candidate%germination_temperature_sum = committed%germination_temperature_sum+ &
             parameters%optimum_emergence_temperature_sum/requisite_sum*effective_temp
      end if
    end if
    if (.not. ieee_is_finite(candidate%germination_temperature_sum)) then
      candidate = committed
      return
    end if
    candidate%emerged = candidate%germination_temperature_sum >= parameters%optimum_emergence_temperature_sum
    status = CROP_CALENDAR_OK
  end subroutine
end module

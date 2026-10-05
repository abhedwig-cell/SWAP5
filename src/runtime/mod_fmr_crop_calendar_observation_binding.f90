module mod_fmr_crop_calendar_observation_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_calendar_management_process, only: crop_calendar_management_observation_t
  implicit none
  private
  integer, parameter, public :: CROP_OBSERVATION_OK = 0
  integer, parameter, public :: CROP_OBSERVATION_INVALID = 1
  public :: bind_crop_calendar_observation
contains
  pure subroutine bind_crop_calendar_observation(thickness_cm,head_cm,soil_temperature_c, &
       preparation_depth_cm,sowing_depth_cm,germination_depth_cm,temperature_depth_cm, &
       daily_air_temperature_c,observation,status)
    real(real64), intent(in) :: thickness_cm(:),head_cm(:),soil_temperature_c(:)
    real(real64), intent(in) :: preparation_depth_cm,sowing_depth_cm,germination_depth_cm
    real(real64), intent(in) :: temperature_depth_cm,daily_air_temperature_c
    type(crop_calendar_management_observation_t), intent(out) :: observation
    integer, intent(out) :: status
    integer :: i
    real(real64) :: bottom
    logical :: ok

    observation = crop_calendar_management_observation_t()
    status = CROP_OBSERVATION_INVALID
    if (size(thickness_cm) < 1 .or. size(head_cm) /= size(thickness_cm) .or. &
        size(soil_temperature_c) /= size(thickness_cm)) return
    if (any(.not. ieee_is_finite(thickness_cm)) .or. any(thickness_cm <= 0.0_real64) .or. &
        any(.not. ieee_is_finite(head_cm)) .or. any(.not. ieee_is_finite(soil_temperature_c)) .or. &
        .not. all(ieee_is_finite([preparation_depth_cm,sowing_depth_cm,germination_depth_cm, &
        temperature_depth_cm,daily_air_temperature_c]))) return
    if (min(preparation_depth_cm,sowing_depth_cm,germination_depth_cm,temperature_depth_cm) < 0.0_real64) return
    bottom = sum(thickness_cm)
    if (max(preparation_depth_cm,sowing_depth_cm,germination_depth_cm,temperature_depth_cm) > bottom) return
    call weighted_head(preparation_depth_cm,thickness_cm,head_cm, &
         observation%preparation_average_head_cm,ok)
    if (.not. ok) return
    call weighted_head(sowing_depth_cm,thickness_cm,head_cm,observation%sowing_average_head_cm,ok)
    if (.not. ok) return
    call weighted_head(germination_depth_cm,thickness_cm,head_cm, &
         observation%germination_average_head_cm,ok)
    if (.not. ok) return
    bottom = 0.0_real64
    do i=1,size(thickness_cm)
      bottom = bottom+thickness_cm(i)
      if (temperature_depth_cm <= bottom) exit
    end do
    observation%sowing_soil_temperature_c = soil_temperature_c(i)
    observation%daily_mean_air_temperature_c = daily_air_temperature_c
    status = CROP_OBSERVATION_OK
  end subroutine

  pure subroutine weighted_head(depth,thickness,head,average,ok)
    real(real64), intent(in) :: depth,thickness(:),head(:)
    real(real64), intent(out) :: average
    logical, intent(out) :: ok
    real(real64) :: remaining,taken,mean_pf
    integer :: i
    ok = .false.
    average = 0.0_real64
    if (depth == 0.0_real64) then
      average = -max(1.0_real64,-head(1))
    else
      remaining = depth
      mean_pf = 0.0_real64
      do i=1,size(thickness)
        taken = min(remaining,thickness(i))
        mean_pf = mean_pf+log10(max(1.0_real64,-head(i)))*taken/depth
        remaining = remaining-taken
        if (remaining <= 0.0_real64) exit
      end do
      average = -10.0_real64**mean_pf
    end if
    ok = ieee_is_finite(average)
  end subroutine
end module

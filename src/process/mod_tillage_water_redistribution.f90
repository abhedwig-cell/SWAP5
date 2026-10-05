module mod_tillage_water_redistribution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: TILLAGE_WATER_OK = 0
  integer, parameter, public :: TILLAGE_WATER_INVALID = 1
  integer, parameter, public :: TILLAGE_WATER_SIMPLE = 1
  integer, parameter, public :: TILLAGE_WATER_PROFILE = 2

  type, public :: tillage_water_result_t
    real(real64), allocatable :: water_content(:)
    real(real64) :: ponding_depth_cm = 0.0_real64
    real(real64) :: soil_storage_before_cm = 0.0_real64
    real(real64) :: soil_storage_after_cm = 0.0_real64
    real(real64) :: mass_residual_cm = 0.0_real64
  end type tillage_water_result_t

  public :: redistribute_tillage_water

contains

  pure subroutine redistribute_tillage_water(mode, old_theta, new_retention_at_old_head, theta_residual, &
                                              theta_saturated, thickness_cm, old_pond_cm, result, status)
    integer, intent(in) :: mode
    real(real64), intent(in) :: old_theta(:), new_retention_at_old_head(:)
    real(real64), intent(in) :: theta_residual(:), theta_saturated(:), thickness_cm(:), old_pond_cm
    type(tillage_water_result_t), intent(out) :: result
    integer, intent(out) :: status
    real(real64) :: difference, capacity, fraction, room, addition
    integer :: i, n

    result = tillage_water_result_t()
    status = TILLAGE_WATER_INVALID
    n = size(old_theta)
    if (mode /= TILLAGE_WATER_SIMPLE .and. mode /= TILLAGE_WATER_PROFILE) return
    if (n < 1 .or. size(new_retention_at_old_head) /= n .or. size(theta_residual) /= n .or. &
        size(theta_saturated) /= n .or. size(thickness_cm) /= n) return
    if (.not. ieee_is_finite(old_pond_cm) .or. old_pond_cm < 0.0_real64) return
    if (any(.not. ieee_is_finite(old_theta)) .or. any(.not. ieee_is_finite(new_retention_at_old_head)) .or. &
        any(.not. ieee_is_finite(theta_residual)) .or. any(.not. ieee_is_finite(theta_saturated)) .or. &
        any(.not. ieee_is_finite(thickness_cm))) return
    if (any(thickness_cm <= 0.0_real64) .or. any(theta_residual < 0.0_real64) .or. &
        any(theta_saturated <= theta_residual) .or. any(theta_saturated > 1.0_real64)) return
    if (any(old_theta < theta_residual) .or. any(old_theta > 1.0_real64)) return
    if (mode == TILLAGE_WATER_PROFILE) then
      if (any(new_retention_at_old_head < theta_residual) .or. &
          any(new_retention_at_old_head > theta_saturated)) return
    end if

    result%soil_storage_before_cm = sum(old_theta*thickness_cm)
    result%ponding_depth_cm = old_pond_cm
    allocate(result%water_content(n))
    select case (mode)
    case (TILLAGE_WATER_SIMPLE)
      result%water_content = min(old_theta,theta_saturated)
      difference = max(0.0_real64, result%soil_storage_before_cm - sum(result%water_content*thickness_cm))
      ! Preserve the source's bottom-up placement, with the missing thickness
      ! factor supplied so every transfer is a depth of water.
      do i = n, 1, -1
        room = (theta_saturated(i)-result%water_content(i))*thickness_cm(i)
        addition = min(difference,room)
        result%water_content(i) = result%water_content(i) + addition/thickness_cm(i)
        difference = difference - addition
      end do
      result%ponding_depth_cm = result%ponding_depth_cm + difference
    case (TILLAGE_WATER_PROFILE)
      result%water_content = new_retention_at_old_head
      difference = result%soil_storage_before_cm - sum(result%water_content*thickness_cm)
      if (difference >= 0.0_real64) then
        capacity = sum((theta_saturated-result%water_content)*thickness_cm)
        if (capacity > 0.0_real64) then
          fraction = min(1.0_real64,difference/capacity)
          result%water_content = result%water_content + fraction*(theta_saturated-result%water_content)
          difference = difference - fraction*capacity
        end if
        result%ponding_depth_cm = result%ponding_depth_cm + difference
      else
        capacity = sum((result%water_content-theta_residual)*thickness_cm)
        if (capacity <= 0.0_real64 .or. -difference > capacity) then
          result = tillage_water_result_t()
          return
        end if
        fraction = -difference/capacity
        result%water_content = result%water_content - fraction*(result%water_content-theta_residual)
      end if
    end select

    result%soil_storage_after_cm = sum(result%water_content*thickness_cm)
    result%mass_residual_cm = result%soil_storage_after_cm + result%ponding_depth_cm - &
                              result%soil_storage_before_cm - old_pond_cm
    if (.not. ieee_is_finite(result%mass_residual_cm)) then
      result = tillage_water_result_t()
      return
    end if
    if (abs(result%mass_residual_cm) > 1.0e-12_real64* &
        max(1.0_real64,result%soil_storage_before_cm+old_pond_cm)) then
      result = tillage_water_result_t()
      return
    end if
    status = TILLAGE_WATER_OK
  end subroutine redistribute_tillage_water

end module mod_tillage_water_redistribution

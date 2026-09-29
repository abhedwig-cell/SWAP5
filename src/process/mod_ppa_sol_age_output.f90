module mod_ppa_sol_age_output
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_OUTPUT_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_OUTPUT_INVALID_INPUT = 1
  public :: ppa_sol_age_output_increments

contains

  pure subroutine ppa_sol_age_output_increments(updated_age, previous_age, top_water_flux, root_water_flux, &
       lateral_water_flux, bottom_water_flux, interval_days, top_upward_increment, root_increment, &
       lateral_increment, bottom_increment, status)
    real(real64), intent(in) :: updated_age(:), previous_age(:), top_water_flux, root_water_flux(:)
    real(real64), intent(in) :: lateral_water_flux(:,:), bottom_water_flux, interval_days
    real(real64), intent(out) :: top_upward_increment, root_increment, lateral_increment(:), bottom_increment
    integer, intent(out) :: status
    integer :: n, level, i
    real(real64) :: mean_age

    top_upward_increment = 0.0_real64
    root_increment = 0.0_real64
    lateral_increment = 0.0_real64
    bottom_increment = 0.0_real64
    status = PPA_SOL_AGE_OUTPUT_INVALID_INPUT
    n = size(updated_age)
    if (n <= 0 .or. size(previous_age) /= n .or. size(root_water_flux) /= n .or. &
        size(lateral_water_flux, 2) /= n .or. size(lateral_increment) /= size(lateral_water_flux, 1)) return
    if (.not. ieee_is_finite(top_water_flux) .or. .not. ieee_is_finite(bottom_water_flux) .or. &
        .not. ieee_is_finite(interval_days) .or. .not. all(ieee_is_finite(updated_age)) .or. &
        .not. all(ieee_is_finite(previous_age)) .or. .not. all(ieee_is_finite(root_water_flux)) .or. &
        .not. all(ieee_is_finite(lateral_water_flux))) return
    if (interval_days <= 0.0_real64) return

    top_upward_increment = max(0.0_real64, top_water_flux) * &
         0.5_real64 * (updated_age(1) + previous_age(1)) * interval_days
    do i = 1, n
      mean_age = 0.5_real64 * (updated_age(i) + previous_age(i))
      root_increment = root_increment + root_water_flux(i) * mean_age * interval_days
      do level = 1, size(lateral_water_flux, 1)
        lateral_increment(level) = lateral_increment(level) + &
             lateral_water_flux(level, i) * mean_age * interval_days
      end do
    end do
    bottom_increment = -min(bottom_water_flux, 0.0_real64) * &
         0.5_real64 * (updated_age(n) + previous_age(n)) * interval_days
    if (.not. ieee_is_finite(top_upward_increment) .or. .not. ieee_is_finite(root_increment) .or. &
        .not. all(ieee_is_finite(lateral_increment)) .or. .not. ieee_is_finite(bottom_increment)) then
      top_upward_increment = 0.0_real64
      root_increment = 0.0_real64
      lateral_increment = 0.0_real64
      bottom_increment = 0.0_real64
      return
    end if
    status = PPA_SOL_AGE_OUTPUT_OK
  end subroutine ppa_sol_age_output_increments

end module mod_ppa_sol_age_output

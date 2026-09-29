module mod_ppa_sol_age_gwl1m
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_GWL1M_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_GWL1M_INVALID_INPUT = 1
  public :: ppa_sol_age_gwl1m_candidate

contains

  pure subroutine ppa_sol_age_gwl1m_candidate(cell_top, cell_bottom, age_concentration, saturated_water_content, &
       water_table_elevation, no_value, mean_age, denominator, status)
    real(real64), intent(in) :: cell_top(:), cell_bottom(:), age_concentration(:), saturated_water_content(:)
    real(real64), intent(in) :: water_table_elevation, no_value
    real(real64), intent(out) :: mean_age, denominator
    integer, intent(out) :: status
    real(real64) :: clipped_top, clipped_bottom, overlap, weighted_age
    integer :: n, i

    mean_age = no_value
    denominator = 0.0_real64
    status = PPA_SOL_AGE_GWL1M_INVALID_INPUT
    n = size(cell_top)
    if (n <= 0 .or. size(cell_bottom) /= n .or. size(age_concentration) /= n .or. &
        size(saturated_water_content) /= n) return
    if (.not. ieee_is_finite(water_table_elevation) .or. .not. ieee_is_finite(no_value) .or. &
        .not. all(ieee_is_finite(cell_top)) .or. .not. all(ieee_is_finite(cell_bottom)) .or. &
        .not. all(ieee_is_finite(age_concentration)) .or. .not. all(ieee_is_finite(saturated_water_content))) return
    if (any(cell_top <= cell_bottom) .or. any(saturated_water_content < 0.0_real64)) return

    denominator = 0.0_real64
    weighted_age = 0.0_real64
    do i = 1, n
      clipped_top = cell_top(i)
      clipped_bottom = cell_bottom(i)
      if (water_table_elevation < clipped_top) clipped_top = water_table_elevation
      if (water_table_elevation - 100.0_real64 > clipped_bottom) clipped_bottom = water_table_elevation - 100.0_real64
      overlap = clipped_top - clipped_bottom
      if (overlap < 0.0_real64) then
        mean_age = no_value
        denominator = 0.0_real64
        return
      end if
      weighted_age = weighted_age + overlap * age_concentration(i) * saturated_water_content(i)
      denominator = denominator + overlap * saturated_water_content(i)
    end do
    mean_age = no_value
    if (denominator > 1.0e-12_real64) mean_age = weighted_age / denominator
    if (.not. ieee_is_finite(mean_age) .or. .not. ieee_is_finite(denominator)) then
      mean_age = no_value
      denominator = 0.0_real64
      return
    end if
    status = PPA_SOL_AGE_GWL1M_OK
  end subroutine ppa_sol_age_gwl1m_candidate

end module mod_ppa_sol_age_gwl1m

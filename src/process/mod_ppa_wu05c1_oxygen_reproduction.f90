module mod_ppa_wu05c1_oxygen_reproduction
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05C1_OK = 0
  integer, parameter, public :: PPA_WU05C1_INVALID_INPUT = 1

  public :: evaluate_ppa_wu05c1_oxygen_reproduction

contains

  subroutine evaluate_ppa_wu05c1_oxygen_reproduction(oxygen_slope, oxygen_intercept, theta, theta_s, &
      tsoil, node_depth_cm, dz_cm, bottom_coordinate_cm, node, factor, status)
    real(real64), intent(in) :: oxygen_slope(6), oxygen_intercept(6)
    real(real64), intent(in) :: theta(:), theta_s(:), tsoil(:), node_depth_cm(:), dz_cm(:), bottom_coordinate_cm(:)
    integer, intent(in) :: node
    real(real64), intent(out) :: factor
    integer, intent(out) :: status

    real(real64) :: gas_filled_porosity, soil_temp, depth_ss, sum_porosity
    real(real64) :: mean_gas_filled_porosity, intercept, slope
    integer :: i, n

    factor = 0.0_real64
    status = PPA_WU05C1_INVALID_INPUT
    n = size(theta)
    if (n <= 0 .or. node < 1 .or. node > n) return
    if (size(theta_s) /= n .or. size(tsoil) /= n .or. size(node_depth_cm) /= n .or. &
        size(dz_cm) /= n .or. size(bottom_coordinate_cm) /= n) return
    if (any(.not. ieee_is_finite(oxygen_slope)) .or. any(.not. ieee_is_finite(oxygen_intercept))) return
    if (any(.not. ieee_is_finite(theta(1:node))) .or. any(.not. ieee_is_finite(theta_s(1:node))) .or. &
        any(.not. ieee_is_finite(dz_cm(1:node)))) return
    if (.not. ieee_is_finite(tsoil(node)) .or. .not. ieee_is_finite(node_depth_cm(node)) .or. &
        .not. ieee_is_finite(bottom_coordinate_cm(node))) return
    if (bottom_coordinate_cm(node) >= 0.0_real64) return

    ! Preserve B1.11 OxygenReproFunction operation order and clipping semantics.
    gas_filled_porosity = dmax1(0.0_real64, theta_s(node) - theta(node))
    soil_temp = tsoil(node) + 273.0_real64
    depth_ss = -node_depth_cm(node) * 0.01_real64

    if (gas_filled_porosity < 1.0e-10_real64) then
      factor = 0.0_real64
      status = PPA_WU05C1_OK
      return
    end if

    sum_porosity = 0.0_real64
    do i = 1, node
      sum_porosity = sum_porosity + (theta_s(i) - theta(i)) * dz_cm(i)
    end do
    mean_gas_filled_porosity = sum_porosity / (-bottom_coordinate_cm(node))

    intercept = oxygen_intercept(1)*soil_temp**2 + oxygen_intercept(2)*depth_ss**2 + &
        oxygen_intercept(3)*soil_temp + oxygen_intercept(4)*depth_ss + &
        oxygen_intercept(5)*soil_temp*depth_ss + oxygen_intercept(6)
    slope = oxygen_slope(1)*soil_temp**2 + oxygen_slope(2)*depth_ss**2 + &
        oxygen_slope(3)*soil_temp + oxygen_slope(4)*depth_ss + &
        oxygen_slope(5)*soil_temp*depth_ss + oxygen_slope(6)
    factor = intercept + slope*mean_gas_filled_porosity
    if (factor > 1.0_real64) factor = 1.0_real64
    if (factor < 0.0_real64) factor = 0.0_real64

    if (.not. ieee_is_finite(factor)) then
      factor = 0.0_real64
      status = PPA_WU05C1_INVALID_INPUT
      return
    end if
    status = PPA_WU05C1_OK
  end subroutine evaluate_ppa_wu05c1_oxygen_reproduction

end module mod_ppa_wu05c1_oxygen_reproduction

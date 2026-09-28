module mod_ppa_wu05c3a_oxygen_cache_algebra
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05C3A_OK = 0
  integer, parameter, public :: PPA_WU05C3A_INVALID_INPUT = 1
  public :: evaluate_ppa_wu05c3a_oxygen_cache_algebra

contains

  subroutine evaluate_ppa_wu05c3a_oxygen_cache_algebra(campbell_h100, campbell_h500, &
      theta100, theta500, theta_gfp100, theta_s, theta_r, alpha, gen_n, gen_m, &
      campbell_b, gfp100, d_soil_term1, d_soil_term2, capac_term, nmin1, mplus1, status)
    real(real64), intent(in) :: campbell_h100, campbell_h500
    real(real64), intent(in) :: theta100, theta500, theta_gfp100, theta_s, theta_r
    real(real64), intent(in) :: alpha, gen_n, gen_m
    real(real64), intent(out) :: campbell_b, gfp100, d_soil_term1, d_soil_term2
    real(real64), intent(out) :: capac_term, nmin1, mplus1
    integer, intent(out) :: status

    real(real64) :: log10h100, log10h500, theta_log_difference

    campbell_b = 0.0_real64
    gfp100 = 0.0_real64
    d_soil_term1 = 0.0_real64
    d_soil_term2 = 0.0_real64
    capac_term = 0.0_real64
    nmin1 = 0.0_real64
    mplus1 = 0.0_real64
    status = PPA_WU05C3A_INVALID_INPUT

    if (.not. all(ieee_is_finite([campbell_h100, campbell_h500, theta100, theta500, &
        theta_gfp100, theta_s, theta_r, alpha, gen_n, gen_m]))) return
    if (campbell_h100 >= 0.0_real64 .or. campbell_h500 >= 0.0_real64) return
    if (theta100 <= 0.0_real64 .or. theta500 <= 0.0_real64) return
    log10h100 = log10(-campbell_h100)
    log10h500 = log10(-campbell_h500)
    theta_log_difference = log10(theta100) - log10(theta500)
    if (abs(theta_log_difference) <= tiny(theta_log_difference)) return

    ! Keep B1.11 calc_ini_pars expression order; outputs are transient values, not a stored cache.
    campbell_b = (log10h500-log10h100) / theta_log_difference
    if (abs(campbell_b) <= tiny(campbell_b)) then
      campbell_b = 0.0_real64
      return
    end if
    gfp100 = theta_s - theta_gfp100
    d_soil_term1 = 2.0_real64*(gfp100**3) + 0.04_real64*gfp100
    d_soil_term2 = 2.0_real64 + 3.0_real64/campbell_b
    capac_term = (theta_s-theta_r) * 0.01_real64 * alpha * gen_n * gen_m
    nmin1 = gen_n - 1.0_real64
    mplus1 = gen_m + 1.0_real64

    if (.not. all(ieee_is_finite([campbell_b, gfp100, d_soil_term1, d_soil_term2, &
        capac_term, nmin1, mplus1]))) then
      campbell_b = 0.0_real64
      gfp100 = 0.0_real64
      d_soil_term1 = 0.0_real64
      d_soil_term2 = 0.0_real64
      capac_term = 0.0_real64
      nmin1 = 0.0_real64
      mplus1 = 0.0_real64
      return
    end if
    status = PPA_WU05C3A_OK
  end subroutine evaluate_ppa_wu05c3a_oxygen_cache_algebra

end module mod_ppa_wu05c3a_oxygen_cache_algebra

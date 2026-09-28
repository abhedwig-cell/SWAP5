module mod_ppa_low03_cval_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW03_CVAL_OK = 0
  integer, parameter, public :: PPA_LOW03_CVAL_INVALID_INPUT = 1
  public :: evaluate_ppa_low03_cval_profile

contains

  ! B1.11 SWBOTB3RESVERT source calculation over top-to-bottom compartments.
  ! Vertical conductivity and geometry remain explicit inputs owned by profile physics.
  subroutine evaluate_ppa_low03_cval_profile(sw_res_vert, ztop_cp, zbot_cp, dz, &
                                             vertical_conductivity, gwl_mean, cval, status)
    integer, intent(in) :: sw_res_vert
    real(real64), intent(in) :: ztop_cp(:), zbot_cp(:), dz(:), vertical_conductivity(:), gwl_mean
    real(real64), intent(out) :: cval
    integer, intent(out) :: status
    integer :: node, i, n
    real(real64) :: saturated_thickness

    cval = 0.0_real64
    status = PPA_LOW03_CVAL_INVALID_INPUT
    if (sw_res_vert < 0 .or. sw_res_vert > 1) return
    if (.not. ieee_is_finite(gwl_mean)) return
    if (sw_res_vert == 1) then
      status = PPA_LOW03_CVAL_OK
      return
    end if

    n = size(ztop_cp)
    if (n == 0 .or. size(zbot_cp) /= n .or. size(dz) /= n .or. &
        size(vertical_conductivity) /= n) return
    if (.not. all(ieee_is_finite(ztop_cp)) .or. .not. all(ieee_is_finite(zbot_cp)) .or. &
        .not. all(ieee_is_finite(dz)) .or. .not. all(ieee_is_finite(vertical_conductivity))) return
    if (any(ztop_cp <= zbot_cp) .or. any(dz <= 0.0_real64) .or. &
        any(vertical_conductivity <= 0.0_real64)) return
    if (any(ztop_cp(2:) >= ztop_cp(:n-1)) .or. any(zbot_cp(2:) >= zbot_cp(:n-1))) return
    if (any(abs(zbot_cp(:n-1)-ztop_cp(2:)) > &
        32.0_real64*epsilon(1.0_real64)*max(1.0_real64, abs(ztop_cp(2:))))) return
    if (gwl_mean < zbot_cp(n) .or. gwl_mean > ztop_cp(1)) return

    node = n
    do while (node > 1)
      if (gwl_mean <= ztop_cp(node)) exit
      node = node - 1
    end do
    saturated_thickness = gwl_mean - zbot_cp(node)
    if (saturated_thickness < 0.0_real64 .or. saturated_thickness > dz(node)) return
    cval = saturated_thickness / vertical_conductivity(node)
    do i = node + 1, n
      cval = cval + dz(i) / vertical_conductivity(i)
    end do
    if (.not. ieee_is_finite(cval) .or. cval < 0.0_real64) then
      cval = 0.0_real64
      return
    end if
    status = PPA_LOW03_CVAL_OK
  end subroutine evaluate_ppa_low03_cval_profile

end module mod_ppa_low03_cval_profile

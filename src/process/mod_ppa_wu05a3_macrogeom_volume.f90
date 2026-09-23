! PPA-WU05-A3 isolated source oracle for B1.11 MACROGEOM volume integrals.
! It deliberately owns no macropore state and is not a production runtime route.
module mod_ppa_wu05a3_macrogeom_volume
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MACROGEOM_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MACROGEOM_INVALID = 1_int32
  public :: ppa_wu05a3_macrogeom_volume

contains

  subroutine ppa_wu05a3_macrogeom_volume(z_top, z_bottom, z_ah, z_ic, z_st, z_sp, &
      rz_ah, spoint, powm, swpowm, pow_mb50, original_node_z, pp_ic_surface, &
      rel_mb, rel_mb_static, rel_ic, rel_ic_static, status)
    real(real64), intent(in) :: z_top, z_bottom, z_ah, z_ic, z_st, z_sp
    real(real64), intent(in) :: rz_ah, spoint, powm, pow_mb50, original_node_z, pp_ic_surface
    integer(int32), intent(in) :: swpowm
    real(real64), intent(out) :: rel_mb, rel_mb_static, rel_ic, rel_ic_static
    integer(int32), intent(out) :: status
    real(real64) :: z_mid, dz_cp, dz_ah_ic, dz_ic_st, nm_z_top, nm_z_bot
    real(real64) :: nn_z_top, nn_z_bot, z_top_bottom_sum, alfa, alfa_static
    real(real64) :: beta, beta_static, pm, sm, pp_mb_surface, exponent

    status = PPA_WU05A3_MACROGEOM_INVALID
    rel_mb = 0.0_real64
    rel_mb_static = 0.0_real64
    rel_ic = 0.0_real64
    rel_ic_static = 0.0_real64
    dz_ah_ic = 0.0_real64
    dz_ic_st = 0.0_real64
    nm_z_top = 0.0_real64
    nm_z_bot = 0.0_real64
    nn_z_top = 0.0_real64
    nn_z_bot = 0.0_real64
    alfa = 0.0_real64
    alfa_static = 0.0_real64
    beta = 0.0_real64
    beta_static = 0.0_real64
    if (.not. all(ieee_is_finite([z_top,z_bottom,z_ah,z_ic,z_st,z_sp,rz_ah, &
        spoint,powm,pow_mb50,original_node_z,pp_ic_surface]))) return
    if (z_top <= z_bottom .or. z_ah >= 0.0_real64 .or. z_ic >= z_ah .or. &
        z_st >= 0.0_real64 .or. z_sp > z_ah .or. z_sp < z_ic) return
    if (rz_ah < 0.0_real64 .or. rz_ah > 1.0_real64 .or. &
        spoint < 0.0_real64 .or. spoint > 1.0_real64 .or. &
        pp_ic_surface < 0.0_real64 .or. pp_ic_surface > 1.0_real64) return
    if (powm <= 0.0_real64 .or. (swpowm /= 0 .and. swpowm /= 1)) return
    if (pow_mb50 <= -1.0_real64) return

    z_mid = (z_top + z_bottom) / 2.0_real64
    dz_cp = z_top - z_bottom
    if (z_mid < z_ah .and. z_mid > z_ic) then
      dz_ah_ic = z_ah - z_ic
      nm_z_top = max(0.0_real64, z_ah-z_top) / dz_ah_ic
      nm_z_bot = (z_ah-z_bottom) / dz_ah_ic
    else if (z_mid < z_ic .and. z_mid > z_st) then
      dz_ic_st = z_ic - z_st
      nn_z_top = max(0.0_real64, z_ic-z_top) / dz_ic_st
      nn_z_bot = (z_ic-z_bottom) / dz_ic_st
    end if
    z_top_bottom_sum = z_top + z_bottom

    if (z_mid > z_ic) then
      alfa = dz_cp
    else if (z_mid > z_st) then
      exponent = pow_mb50 + 1.0_real64
      alfa = dz_ic_st / exponent * &
          ((1.0_real64-nn_z_top)**exponent - (1.0_real64-nn_z_bot)**exponent)
    else
      alfa = 0.0_real64
    end if
    alfa_static = alfa
    if (original_node_z < z_st) alfa_static = 0.0_real64

    if (z_mid > z_ah) then
      beta = dz_cp * (1.0_real64-z_top_bottom_sum*rz_ah/(2.0_real64*z_ah))
    else if (z_mid > z_ic) then
      if (z_mid > z_sp) then
        sm = (spoint**(1.0_real64-powm))/(powm+1.0_real64)
        beta = (1.0_real64-rz_ah) * (dz_cp + dz_ah_ic*sm * &
            (nm_z_top**(powm+1.0_real64)-nm_z_bot**(powm+1.0_real64)))
      else
        pm = powm
        if (swpowm == 1) pm = 1.0_real64/powm
        sm = ((1.0_real64-spoint)**(1.0_real64-pm))/(pm+1.0_real64)
        beta = (1.0_real64-rz_ah) * (dz_ah_ic*sm * &
            ((1.0_real64-nm_z_top)**(pm+1.0_real64) - &
             (1.0_real64-nm_z_bot)**(pm+1.0_real64)))
      end if
    else
      beta = 0.0_real64
    end if
    if (original_node_z < z_ic) beta = 0.0_real64
    beta_static = beta
    if (original_node_z < z_st) beta_static = 0.0_real64

    pp_mb_surface = 1.0_real64 - pp_ic_surface
    rel_mb = alfa*pp_mb_surface
    rel_mb_static = alfa_static*pp_mb_surface
    rel_ic = beta*pp_ic_surface
    rel_ic_static = beta_static*pp_ic_surface
    status = PPA_WU05A3_MACROGEOM_OK
  end subroutine ppa_wu05a3_macrogeom_volume

end module mod_ppa_wu05a3_macrogeom_volume

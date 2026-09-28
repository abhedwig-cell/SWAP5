module mod_ppa_low03_cauchy_flux
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW03_CAUCHY_OK = 0
  integer, parameter, public :: PPA_LOW03_CAUCHY_INVALID_INPUT = 1
  public :: evaluate_ppa_low03_cauchy_flux

contains

  ! Explicit SWBOTB=3 source law. Profile C-value is supplied by its
  ! hydraulic-profile owner; SWBOTB3RESVERT=1 is represented by C=0.
  subroutine evaluate_ppa_low03_cauchy_flux(sw_extra_flux, gwl, hdrain, shape, deepgw, &
                                            rimlay, cval_profile, extra_flux, qbot, status)
    integer, intent(in) :: sw_extra_flux
    real(real64), intent(in) :: gwl, hdrain, shape, deepgw, rimlay, cval_profile, extra_flux
    real(real64), intent(out) :: qbot
    integer, intent(out) :: status
    real(real64) :: gwl_mean, denominator, base_flux

    qbot = 0.0_real64
    status = PPA_LOW03_CAUCHY_INVALID_INPUT
    if (sw_extra_flux < 0 .or. sw_extra_flux > 1) return
    if (.not. all(ieee_is_finite([gwl, hdrain, shape, deepgw, rimlay, cval_profile, extra_flux]))) return
    if (hdrain < -10000.0_real64 .or. hdrain > 0.0_real64) return
    if (shape < 0.0_real64 .or. shape > 1.0_real64) return
    if (deepgw < -10000.0_real64 .or. deepgw > 1000.0_real64) return
    if (rimlay < 0.0_real64 .or. rimlay > 100000.0_real64) return
    if (cval_profile < 0.0_real64) return
    if (sw_extra_flux == 1) then
      if (extra_flux < -100.0_real64 .or. extra_flux > 100.0_real64) return
    end if

    gwl_mean = hdrain + shape * (gwl - hdrain)
    denominator = rimlay + cval_profile
    if (.not. ieee_is_finite(gwl_mean) .or. .not. ieee_is_finite(denominator)) return
    if (denominator <= 0.0_real64) return
    base_flux = (deepgw - gwl_mean) / denominator
    if (.not. ieee_is_finite(base_flux)) return
    qbot = base_flux
    if (sw_extra_flux == 1) qbot = qbot + extra_flux
    if (.not. ieee_is_finite(qbot)) then
      qbot = 0.0_real64
      return
    end if
    status = PPA_LOW03_CAUCHY_OK
  end subroutine evaluate_ppa_low03_cauchy_flux

end module mod_ppa_low03_cauchy_flux

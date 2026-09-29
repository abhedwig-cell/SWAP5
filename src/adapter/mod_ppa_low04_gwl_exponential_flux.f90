module mod_ppa_low04_gwl_exponential_flux
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW04_GWL_OK = 0
  integer, parameter, public :: PPA_LOW04_GWL_INVALID_INPUT = 1
  public :: evaluate_ppa_low04_gwl_exponential_flux

contains

  subroutine evaluate_ppa_low04_gwl_exponential_flux(sw_cofqhc, cofqha, cofqhb, cofqhc, gwl, qbot, status)
    integer, intent(in) :: sw_cofqhc
    real(real64), intent(in) :: cofqha, cofqhb, cofqhc, gwl
    real(real64), intent(out) :: qbot
    integer, intent(out) :: status
    real(real64) :: exponent, exponential_term

    qbot = 0.0_real64
    status = PPA_LOW04_GWL_INVALID_INPUT
    if (sw_cofqhc < 0 .or. sw_cofqhc > 1) return
    if (.not. all(ieee_is_finite([cofqha, cofqhb, cofqhc, gwl]))) return
    if (cofqha < -100.0_real64 .or. cofqha > 100.0_real64) return
    if (cofqhb < -1.0_real64 .or. cofqhb > 1.0_real64) return
    if (sw_cofqhc == 1) then
      if (cofqhc < -10.0_real64 .or. cofqhc > 10.0_real64) return
    end if

    exponent = cofqhb * abs(gwl)
    if (.not. ieee_is_finite(exponent) .or. exponent > log(huge(1.0_real64))) return
    if (cofqha == 0.0_real64) then
      exponential_term = 0.0_real64
    else
      if (log(abs(cofqha)) + exponent > log(huge(1.0_real64))) return
      exponential_term = cofqha * exp(exponent)
    end if
    qbot = exponential_term
    if (sw_cofqhc == 1) qbot = qbot + cofqhc
    if (.not. ieee_is_finite(qbot)) then
      qbot = 0.0_real64
      return
    end if
    status = PPA_LOW04_GWL_OK
  end subroutine evaluate_ppa_low04_gwl_exponential_flux

end module mod_ppa_low04_gwl_exponential_flux

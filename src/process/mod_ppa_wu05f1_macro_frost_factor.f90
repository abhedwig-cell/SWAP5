module mod_ppa_wu05f1_macro_frost_factor
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05F1_OK = 0
  integer, parameter, public :: PPA_WU05F1_INVALID_INPUT = 1
  public :: ppa_wu05f1_macro_frost_factor

contains

  subroutine ppa_wu05f1_macro_frost_factor(sw_frost, soil_temperature, factor, status)
    integer, intent(in) :: sw_frost
    real(real64), intent(in) :: soil_temperature
    real(real64), intent(out) :: factor
    integer, intent(out) :: status

    factor = 1.0_real64
    status = PPA_WU05F1_INVALID_INPUT
    if (.not. ieee_is_finite(soil_temperature)) return
    if (sw_frost < 0 .or. sw_frost > 1) return

    status = PPA_WU05F1_OK
    if (sw_frost == 1 .and. soil_temperature < 0.0_real64) factor = 0.0_real64
  end subroutine ppa_wu05f1_macro_frost_factor

end module mod_ppa_wu05f1_macro_frost_factor

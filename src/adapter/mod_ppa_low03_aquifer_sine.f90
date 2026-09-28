module mod_ppa_low03_aquifer_sine
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW03_AQUIFER_OK = 0
  integer, parameter, public :: PPA_LOW03_AQUIFER_INVALID_INPUT = 1
  public :: evaluate_ppa_low03_aquifer_sine

contains

  ! B1.11 SWBOTB=3, SW3=1 deep-aquifer head forcing.
  subroutine evaluate_ppa_low03_aquifer_sine(aqave, aqamp, aqtmax, aqper, time_day, deepgw, status)
    real(real64), intent(in) :: aqave, aqamp, aqtmax, aqper, time_day
    real(real64), intent(out) :: deepgw
    integer, intent(out) :: status
    real(real64) :: twopi

    deepgw = 0.0_real64
    status = PPA_LOW03_AQUIFER_INVALID_INPUT
    if (.not. all(ieee_is_finite([aqave, aqamp, aqtmax, aqper, time_day]))) return
    if (aqave < -10000.0_real64 .or. aqave > 1000.0_real64) return
    if (aqamp < 0.0_real64 .or. aqamp > 1000.0_real64) return
    if (aqtmax < 0.0_real64 .or. aqtmax > 366.0_real64) return
    if (aqper <= 0.0_real64 .or. aqper > 366.0_real64) return

    twopi = 8.0_real64 * atan(1.0_real64)
    deepgw = aqave + aqamp * cos(twopi/aqper * (time_day - aqtmax))
    if (.not. ieee_is_finite(deepgw)) then
      deepgw = 0.0_real64
      return
    end if
    status = PPA_LOW03_AQUIFER_OK
  end subroutine evaluate_ppa_low03_aquifer_sine

end module mod_ppa_low03_aquifer_sine

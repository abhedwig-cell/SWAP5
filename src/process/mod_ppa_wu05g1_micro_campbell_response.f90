module mod_ppa_wu05g1_micro_campbell_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05G1_OK = 0
  integer, parameter, public :: PPA_WU05G1_INVALID_INPUT = 1
  public :: ppa_wu05g1_campbell_leaf_response

contains

  subroutine ppa_wu05g1_campbell_leaf_response(xp, dpl, tpot, plhalf, camp_a, sw_o2ect, alpha_total, &
      tact, status)
    real(real64), intent(in) :: xp, dpl, tpot, plhalf, camp_a, alpha_total
    integer, intent(in) :: sw_o2ect
    real(real64), intent(out) :: tact
    integer, intent(out) :: status
    real(real64) :: base, exponent

    tact = 0.0_real64
    status = PPA_WU05G1_INVALID_INPUT
    if (.not. all(ieee_is_finite([xp, dpl, tpot, plhalf, camp_a, alpha_total]))) return
    if (tpot < 0.0_real64 .or. plhalf <= 0.0_real64 .or. camp_a < 1.0_real64 .or. camp_a > 500.0_real64) return
    if (sw_o2ect < 0 .or. sw_o2ect > 3) return

    if (xp + dpl < 0.0_real64) then
      tact = tpot
      status = PPA_WU05G1_OK
      return
    end if

    base = (xp + dpl) * plhalf
    if (sw_o2ect >= 3) then
      if (alpha_total <= 0.0_real64) return
      base = (xp + dpl) * (plhalf / alpha_total)
    end if
    if (.not. ieee_is_finite(base) .or. base < 0.0_real64) return
    if (base > 1.0_real64) then
      if (log(base) > log(huge(1.0_real64)) / camp_a) return
    end if

    exponent = base ** camp_a
    if (.not. ieee_is_finite(exponent)) return
    tact = tpot / (1.0_real64 + exponent)
    if (.not. ieee_is_finite(tact)) then
      tact = 0.0_real64
      return
    end if
    status = PPA_WU05G1_OK
  end subroutine ppa_wu05g1_campbell_leaf_response

end module mod_ppa_wu05g1_micro_campbell_response

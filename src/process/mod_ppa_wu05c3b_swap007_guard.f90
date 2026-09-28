module mod_ppa_wu05c3b_swap007_guard
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05C3B_OK = 0
  integer, parameter, public :: PPA_WU05C3B_INVALID_INPUT = 1
  public :: evaluate_ppa_wu05c3b_swap007_guard

contains

  subroutine evaluate_ppa_wu05c3b_swap007_guard(l, fi, fi_a, counter_macro_sub, lnew, restart_required, status)
    real(real64), intent(in) :: l, fi, fi_a
    integer, intent(in) :: counter_macro_sub
    real(real64), intent(out) :: lnew
    logical, intent(out) :: restart_required
    integer, intent(out) :: status

    lnew = 0.0_real64
    restart_required = .false.
    status = PPA_WU05C3B_INVALID_INPUT
    if (.not. all(ieee_is_finite([l, fi, fi_a])) .or. counter_macro_sub < 0) return

    ! Byte-pinned B1.11 SWAP-007 condition and update; no alternate solver policy.
    if (abs(fi_a) > max(tiny(1.0_real64), abs(fi)/huge(1.0_real64))) then
      lnew = abs(l - (fi / fi_a))
    else
      lnew = huge(1.0_real64)
    end if
    restart_required = lnew > 1.0e3_real64 .or. counter_macro_sub > 100
    status = PPA_WU05C3B_OK
  end subroutine evaluate_ppa_wu05c3b_swap007_guard

end module mod_ppa_wu05c3b_swap007_guard

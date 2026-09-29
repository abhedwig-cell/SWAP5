module mod_ppa_wu05g2_micro_stress_aggregate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05G2_OK = 0
  integer, parameter, public :: PPA_WU05G2_INVALID_INPUT = 1
  public :: ppa_wu05g2_micro_stress_aggregate

contains

  subroutine ppa_wu05g2_micro_stress_aggregate(sw_alptot, alpwet, alpsol, alpfrs, alptot, status)
    integer, intent(in) :: sw_alptot
    real(real64), intent(in) :: alpwet(:), alpsol(:), alpfrs(:)
    real(real64), intent(out) :: alptot(:)
    integer, intent(out) :: status
    real(real64) :: factor, product
    integer :: node

    alptot = 1.0_real64
    status = PPA_WU05G2_INVALID_INPUT
    if (size(alpwet) == 0 .or. size(alpsol) /= size(alpwet) .or. size(alpfrs) /= size(alpwet) .or. &
        size(alptot) /= size(alpwet)) return
    if (sw_alptot < 1 .or. sw_alptot > 3) return
    if (.not. all(ieee_is_finite(alpwet)) .or. .not. all(ieee_is_finite(alpsol)) .or. &
        .not. all(ieee_is_finite(alpfrs))) return
    if (minval(alpwet) < 0.0_real64 .or. maxval(alpwet) > 1.0_real64 .or. &
        minval(alpsol) < 0.0_real64 .or. maxval(alpsol) > 1.0_real64 .or. &
        minval(alpfrs) < 0.0_real64 .or. maxval(alpfrs) > 1.0_real64) return

    if (sw_alptot == 1) then
      alptot = alpwet * alpsol * alpfrs
    else if (sw_alptot == 2) then
      alptot = min(alpwet, alpsol, alpfrs)
    else
      product = 1.0_real64
      do node = 1, size(alpwet)
        factor = alpwet(node) * alpsol(node) * alpfrs(node)
        if (factor > 0.0_real64) product = product * factor
      end do
      if (.not. ieee_is_finite(product)) return
      alptot = product
    end if
    status = PPA_WU05G2_OK
  end subroutine ppa_wu05g2_micro_stress_aggregate

end module mod_ppa_wu05g2_micro_stress_aggregate

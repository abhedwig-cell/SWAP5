module mod_ppa_wu05c2_feddes_wetness
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05C2_OK = 0
  integer, parameter, public :: PPA_WU05C2_INVALID_INPUT = 1

  public :: evaluate_ppa_wu05c2_feddes_wetness

contains

  subroutine evaluate_ppa_wu05c2_feddes_wetness(pressure_head, hlim1, hlim2, factor, status)
    real(real64), intent(in) :: pressure_head, hlim1, hlim2
    real(real64), intent(out) :: factor
    integer, intent(out) :: status

    factor = 0.0_real64
    status = PPA_WU05C2_INVALID_INPUT
    if (.not. ieee_is_finite(pressure_head) .or. .not. ieee_is_finite(hlim1) .or. &
        .not. ieee_is_finite(hlim2)) return

    ! Exact B1.11 source order: alpwet starts at one, then the wet-end zero branch overrides.
    factor = 1.0_real64
    if (pressure_head <= hlim1 .and. pressure_head > hlim2) then
      factor = (hlim1 - pressure_head) / (hlim1 - hlim2)
    end if
    if (pressure_head > hlim1) factor = 0.0_real64
    status = PPA_WU05C2_OK
  end subroutine evaluate_ppa_wu05c2_feddes_wetness

end module mod_ppa_wu05c2_feddes_wetness

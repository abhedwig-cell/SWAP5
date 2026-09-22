module mod_ppa_wu05e1_salinity_factor
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05E1_OK = 0
  integer, parameter, public :: PPA_WU05E1_INVALID_INPUT = 1
  public :: ppa_wu05e1_maas_hoffman_factor

contains

  subroutine ppa_wu05e1_maas_hoffman_factor(sw_salinity, cml, saltmax, saltslope, factor, status)
    integer, intent(in) :: sw_salinity
    real(real64), intent(in) :: cml, saltmax, saltslope
    real(real64), intent(out) :: factor
    integer, intent(out) :: status

    factor = 1.0_real64
    status = PPA_WU05E1_INVALID_INPUT
    if (.not. ieee_is_finite(cml) .or. .not. ieee_is_finite(saltmax) .or. &
        .not. ieee_is_finite(saltslope)) return
    if (sw_salinity < 0 .or. sw_salinity > 1) return
    if (saltmax < 0.0_real64 .or. saltmax > 100.0_real64) return
    if (saltslope < 0.0_real64 .or. saltslope > 1.0_real64) return

    status = PPA_WU05E1_OK
    if (sw_salinity == 0) return

    ! Exact B1.11 Maas-Hoffman rule: strict threshold, linear decline, lower clamp.
    if (cml > saltmax) then
      factor = 1.0_real64 - (cml - saltmax) * saltslope
      factor = max(0.0_real64, factor)
    end if
  end subroutine ppa_wu05e1_maas_hoffman_factor

end module mod_ppa_wu05e1_salinity_factor

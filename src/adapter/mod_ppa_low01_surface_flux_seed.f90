module mod_ppa_low01_surface_flux_seed
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW01_SEED_OK = 0
  integer, parameter, public :: PPA_LOW01_SEED_INVALID_INPUT = 1
  public :: evaluate_ppa_low01_surface_flux_seed

contains

  ! B1.11 HeadCalc top-flux terms before the qv profile (pond is post-pondrunoff).
  subroutine evaluate_ppa_low01_surface_flux_seed(nraidt, nird, melt, armp_ss, runon, reva, epd, &
      pond, pond_previous, dt, runots, q0, qv1, status)
    real(real64), intent(in) :: nraidt, nird, melt, armp_ss, runon, reva, epd
    real(real64), intent(in) :: pond, pond_previous, dt, runots
    real(real64), intent(out) :: q0, qv1
    integer, intent(out) :: status

    q0 = 0.0_real64
    qv1 = 0.0_real64
    status = PPA_LOW01_SEED_INVALID_INPUT
    if (.not. all(ieee_is_finite([nraidt, nird, melt, armp_ss, runon, reva, epd, &
                                  pond, pond_previous, dt, runots]))) return
    if (dt <= 0.0_real64) return

    q0 = (nraidt+nird+melt)*(1.0_real64-armp_ss)+runon-reva-epd
    qv1 = -q0+(pond-pond_previous)/dt+runots/dt
    if (.not. all(ieee_is_finite([q0, qv1]))) then
      q0 = 0.0_real64
      qv1 = 0.0_real64
      return
    end if
    status = PPA_LOW01_SEED_OK
  end subroutine evaluate_ppa_low01_surface_flux_seed

end module mod_ppa_low01_surface_flux_seed

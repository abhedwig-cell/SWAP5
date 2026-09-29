module mod_ppa_low01_surface_gwl_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_low01_surface_flux_seed, only: evaluate_ppa_low01_surface_flux_seed, PPA_LOW01_SEED_OK
  use mod_ppa_low01_gwl_surface_profile, only: evaluate_ppa_low01_gwl_surface_profile, PPA_LOW01_SURFACE_OK
  implicit none
  private

  integer, parameter, public :: PPA_LOW01_SURFACE_COMPOSITION_OK = 0
  integer, parameter, public :: PPA_LOW01_SURFACE_COMPOSITION_INVALID = 1
  public :: evaluate_ppa_low01_surface_gwl_composition

contains

  ! Numerically compose the B1.11 surface-GWL top-flux seed and saturated profile.
  ! All source/pond/profile state is explicit input; this routine owns none of it.
  subroutine evaluate_ppa_low01_surface_gwl_composition(gwlinp, nraidt, nird, melt, armp_ss, &
      runon, reva, epd, pond, pond_previous, dt, runots, dz, macro_fraction, theta, theta_previous, &
      sink, source, qrot, disnod, kmean, q0, qv, head, qbot, status)
    real(real64), intent(in) :: gwlinp, nraidt, nird, melt, armp_ss, runon, reva, epd
    real(real64), intent(in) :: pond, pond_previous, dt, runots, dz(:), macro_fraction(:)
    real(real64), intent(in) :: theta(:), theta_previous(:), sink(:), source(:), qrot(:), disnod(:), kmean(:)
    real(real64), intent(out) :: q0, qv(:), head(:), qbot
    integer, intent(out) :: status
    real(real64) :: qv1
    integer :: local_status

    q0 = 0.0_real64
    qv = 0.0_real64
    head = 0.0_real64
    qbot = 0.0_real64
    status = PPA_LOW01_SURFACE_COMPOSITION_INVALID
    call evaluate_ppa_low01_surface_flux_seed(nraidt, nird, melt, armp_ss, runon, reva, epd, &
        pond, pond_previous, dt, runots, q0, qv1, local_status)
    if (local_status /= PPA_LOW01_SEED_OK) return
    call evaluate_ppa_low01_gwl_surface_profile(gwlinp, qv1, dt, dz, macro_fraction, theta, &
        theta_previous, sink, source, qrot, disnod, kmean, qv, head, qbot, local_status)
    if (local_status /= PPA_LOW01_SURFACE_OK) then
      q0 = 0.0_real64
      qv = 0.0_real64
      head = 0.0_real64
      qbot = 0.0_real64
      return
    end if
    status = PPA_LOW01_SURFACE_COMPOSITION_OK
  end subroutine evaluate_ppa_low01_surface_gwl_composition

end module mod_ppa_low01_surface_gwl_composition

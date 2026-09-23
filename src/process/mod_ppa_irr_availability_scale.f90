module mod_ppa_irr_availability_scale
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  public :: scale_surface_irrigation_availability

contains

  pure subroutine scale_surface_irrigation_availability(surface_rate, event_duration, irrigation_rate, &
                                                        availability_fraction, scaled_rate, scaled_duration)
    real(real64), intent(in) :: surface_rate, event_duration, irrigation_rate, availability_fraction
    real(real64), intent(out) :: scaled_rate, scaled_duration

    ! Source: B1.11 SWAP/irrigation.f90 Irrigation task 4, lines 632-637.
    scaled_rate = surface_rate * availability_fraction
    scaled_duration = event_duration
    if (irrigation_rate > 0.0_real64) scaled_duration = scaled_duration * availability_fraction
  end subroutine scale_surface_irrigation_availability

end module mod_ppa_irr_availability_scale

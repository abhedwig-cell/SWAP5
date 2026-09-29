module mod_ppa_solute_transport_flux
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: PPA_SOLUTE_TRANSPORT_FLUX_OK = 0
  integer, parameter, public :: PPA_SOLUTE_TRANSPORT_FLUX_INVALID_INPUT = 1
  public :: ppa_solute_face_flux_amount
contains
  pure subroutine ppa_solute_face_flux_amount(water_flux, mobile_face_concentration, &
       volumetric_water_content, dispersion_coefficient, concentration_right, concentration_left, &
       face_distance, interval_days, solute_flux_amount, status)
    real(real64), intent(in) :: water_flux, mobile_face_concentration, volumetric_water_content
    real(real64), intent(in) :: dispersion_coefficient, concentration_right, concentration_left
    real(real64), intent(in) :: face_distance, interval_days
    real(real64), intent(out) :: solute_flux_amount
    integer, intent(out) :: status
    real(real64) :: advective_flux, theta_dispersion, concentration_gradient
    real(real64) :: dispersive_flux, total_flux

    solute_flux_amount = 0.0_real64
    status = PPA_SOLUTE_TRANSPORT_FLUX_INVALID_INPUT
    if (.not. all(ieee_is_finite([water_flux,mobile_face_concentration,volumetric_water_content, &
        dispersion_coefficient,concentration_right,concentration_left,face_distance,interval_days]))) return
    if (volumetric_water_content < 0.0_real64 .or. dispersion_coefficient < 0.0_real64 .or. &
        concentration_right < 0.0_real64 .or. concentration_left < 0.0_real64 .or. &
        face_distance <= 0.0_real64 .or. interval_days <= 0.0_real64) return

    ! Source: B1.11 solute.f90 task 2 internal-face cfluxb equation.
    if (abs(water_flux) > 1.0_real64 .and. abs(mobile_face_concentration) > 1.0_real64) then
      if (abs(water_flux) > huge(1.0_real64)/abs(mobile_face_concentration)) return
    end if
    advective_flux = water_flux*mobile_face_concentration

    if (volumetric_water_content > 1.0_real64 .and. dispersion_coefficient > 1.0_real64) then
      if (volumetric_water_content > huge(1.0_real64)/dispersion_coefficient) return
    end if
    theta_dispersion = volumetric_water_content*dispersion_coefficient
    if (concentration_right > 0.0_real64 .and. concentration_left < 0.0_real64) then
      if (concentration_right > huge(1.0_real64)+concentration_left) return
    end if
    concentration_gradient = concentration_right-concentration_left
    if (theta_dispersion > 1.0_real64 .and. abs(concentration_gradient) > 1.0_real64) then
      if (theta_dispersion > huge(1.0_real64)/abs(concentration_gradient)) return
    end if
    dispersive_flux = theta_dispersion*concentration_gradient
    if (face_distance < 1.0_real64) then
      if (abs(dispersive_flux) > huge(1.0_real64)*face_distance) return
    end if
    dispersive_flux = dispersive_flux/face_distance
    if (advective_flux > 0.0_real64 .and. dispersive_flux > 0.0_real64) then
      if (advective_flux > huge(1.0_real64)-dispersive_flux) return
    else if (advective_flux < 0.0_real64 .and. dispersive_flux < 0.0_real64) then
      if (advective_flux < -huge(1.0_real64)-dispersive_flux) return
    end if
    total_flux = advective_flux+dispersive_flux
    if (interval_days > 1.0_real64) then
      if (abs(total_flux) > huge(1.0_real64)/interval_days) return
    end if
    solute_flux_amount = total_flux*interval_days
    if (.not. ieee_is_finite(solute_flux_amount)) then
      solute_flux_amount = 0.0_real64
      return
    end if
    status = PPA_SOLUTE_TRANSPORT_FLUX_OK
  end subroutine ppa_solute_face_flux_amount
end module mod_ppa_solute_transport_flux

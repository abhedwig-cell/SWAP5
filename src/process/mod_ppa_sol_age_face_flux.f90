module mod_ppa_sol_age_face_flux
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_FACE_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_FACE_INVALID_INPUT = 1
  public :: ppa_sol_age_face_flux_amount

contains

  pure subroutine ppa_sol_age_face_flux_amount(water_flux, mobile_face_age, volumetric_water_content, &
       age_dispersion, age_right, age_left, face_distance, interval_days, age_flux_amount, status)
    real(real64), intent(in) :: water_flux, mobile_face_age, volumetric_water_content
    real(real64), intent(in) :: age_dispersion, age_right, age_left, face_distance, interval_days
    real(real64), intent(out) :: age_flux_amount
    integer, intent(out) :: status

    age_flux_amount = 0.0_real64
    status = PPA_SOL_AGE_FACE_INVALID_INPUT
    if (.not. all(ieee_is_finite([water_flux, mobile_face_age, volumetric_water_content, age_dispersion, &
        age_right, age_left, face_distance, interval_days]))) return
    if (volumetric_water_content <= 0.0_real64 .or. age_dispersion < 0.0_real64 .or. &
        face_distance <= 0.0_real64 .or. interval_days <= 0.0_real64) return

    ! Source: exact B1.11 SWAP/solute.f90 AgeTracer task-2 internal-face equation.
    age_flux_amount = (water_flux * mobile_face_age + volumetric_water_content * age_dispersion * &
         (age_right - age_left) / face_distance) * interval_days
    if (.not. ieee_is_finite(age_flux_amount)) then
      age_flux_amount = 0.0_real64
      return
    end if
    status = PPA_SOL_AGE_FACE_OK
  end subroutine ppa_sol_age_face_flux_amount

end module mod_ppa_sol_age_face_flux

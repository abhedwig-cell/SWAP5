module mod_b1_10_trial_mass
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  type, public :: b1_10_trial_mass_t
    logical :: active = .false.
    logical :: complete = .false.
    real(real64) :: total_in = 0.0_real64
    real(real64) :: total_out = 0.0_real64
    real(real64) :: rain = 0.0_real64
    real(real64) :: irrigation = 0.0_real64
    real(real64) :: runon = 0.0_real64
    real(real64) :: ssdi = 0.0_real64
    real(real64) :: bottom_in = 0.0_real64
    real(real64) :: drainage_in = 0.0_real64
    real(real64) :: inundation = 0.0_real64
    real(real64) :: interception = 0.0_real64
    real(real64) :: runoff = 0.0_real64
    real(real64) :: root_uptake = 0.0_real64
    real(real64) :: pond_evaporation = 0.0_real64
    real(real64) :: soil_evaporation = 0.0_real64
    real(real64) :: drainage_out = 0.0_real64
    real(real64) :: bottom_out = 0.0_real64
  end type b1_10_trial_mass_t

  public :: begin_b1_10_trial_mass, invalidate_b1_10_trial_mass
  public :: record_b1_10_trial_mass_step, record_b1_10_trial_interception_loss

contains

  subroutine begin_b1_10_trial_mass(mass)
    type(b1_10_trial_mass_t), intent(inout) :: mass
    mass = b1_10_trial_mass_t()
    mass%active = .true.
    mass%complete = .true.
  end subroutine begin_b1_10_trial_mass

  subroutine invalidate_b1_10_trial_mass(mass)
    type(b1_10_trial_mass_t), intent(inout) :: mass
    if (mass%active) mass%complete = .false.
  end subroutine invalidate_b1_10_trial_mass

  subroutine record_b1_10_trial_mass_step(mass, rain, irrigation, runon, ssdi, bottom_flux, drainage_in, drainage_out, &
                                          interception, runoff, root_uptake, pond_evaporation, soil_evaporation)
    type(b1_10_trial_mass_t), intent(inout) :: mass
    real(real64), intent(in) :: rain, irrigation, runon, ssdi, bottom_flux
    real(real64), intent(in) :: drainage_in, drainage_out, interception, runoff
    real(real64), intent(in) :: root_uptake, pond_evaporation, soil_evaporation
    if (.not. mass%active) return
    mass%rain = mass%rain + rain
    mass%irrigation = mass%irrigation + irrigation
    mass%runon = mass%runon + runon
    mass%ssdi = mass%ssdi + ssdi
    mass%drainage_in = mass%drainage_in + drainage_in
    mass%drainage_out = mass%drainage_out + drainage_out
    mass%interception = mass%interception + interception
    mass%root_uptake = mass%root_uptake + root_uptake
    mass%pond_evaporation = mass%pond_evaporation + pond_evaporation
    mass%soil_evaporation = mass%soil_evaporation + soil_evaporation
    if (bottom_flux >= 0.0_real64) then
      mass%bottom_in = mass%bottom_in + bottom_flux
    else
      mass%bottom_out = mass%bottom_out - bottom_flux
    end if
    if (runoff >= 0.0_real64) then
      mass%runoff = mass%runoff + runoff
    else
      mass%inundation = mass%inundation - runoff
    end if
    mass%total_in = mass%rain + mass%irrigation + mass%runon + mass%ssdi + mass%bottom_in + mass%drainage_in + mass%inundation
    mass%total_out = mass%interception + mass%runoff + mass%root_uptake + mass%pond_evaporation + mass%soil_evaporation + &
                     mass%drainage_out + mass%bottom_out
  end subroutine record_b1_10_trial_mass_step

  subroutine record_b1_10_trial_interception_loss(mass, loss)
    type(b1_10_trial_mass_t), intent(inout) :: mass
    real(real64), intent(in) :: loss
    if (.not. mass%active) return
    mass%interception = mass%interception + loss
    mass%total_out = mass%total_out + loss
  end subroutine record_b1_10_trial_interception_loss

end module mod_b1_10_trial_mass

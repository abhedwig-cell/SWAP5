module mod_ppa_solute_aquifer_update
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: PPA_SOLUTE_AQUIFER_UPDATE_OK=0
  integer, parameter, public :: PPA_SOLUTE_AQUIFER_UPDATE_INVALID_INPUT=1
  public :: ppa_solute_aquifer_update
contains
  pure subroutine ppa_solute_aquifer_update(swbr,substep_days,saturated_storage_per_area, &
       aquifer_thickness,drain_flux_total,drainage_mass,decay_rate,drain_concentration,seep_concentration, &
       surface_cumulative_mass,next_drain_concentration,next_seep_concentration,next_surface_cumulative_mass,status)
    integer,intent(in)::swbr
    real(real64),intent(in)::substep_days,saturated_storage_per_area,aquifer_thickness
    real(real64),intent(in)::drain_flux_total,drainage_mass,decay_rate,drain_concentration,seep_concentration
    real(real64),intent(in)::surface_cumulative_mass
    real(real64),intent(out)::next_drain_concentration,next_seep_concentration,next_surface_cumulative_mass
    integer,intent(out)::status

    next_drain_concentration=drain_concentration
    next_seep_concentration=seep_concentration
    next_surface_cumulative_mass=surface_cumulative_mass
    status=PPA_SOLUTE_AQUIFER_UPDATE_INVALID_INPUT
    if(.not.all(ieee_is_finite([substep_days,saturated_storage_per_area,aquifer_thickness, &
         drain_flux_total,drainage_mass,decay_rate,drain_concentration,seep_concentration,surface_cumulative_mass])))return
    if(abs(drain_concentration)>1.0e12_real64.or.abs(seep_concentration)>1.0e12_real64.or. &
         abs(surface_cumulative_mass)>1.0e18_real64)return
    status=PPA_SOLUTE_AQUIFER_UPDATE_OK
    if(swbr/=1)return
    status=PPA_SOLUTE_AQUIFER_UPDATE_INVALID_INPUT
    if(substep_days<=0.0_real64.or.substep_days>1.0e4_real64.or. &
         saturated_storage_per_area<1.0e-12_real64.or.saturated_storage_per_area>1.0e3_real64.or. &
         aquifer_thickness<1.0e-12_real64.or.aquifer_thickness>1.0e3_real64.or. &
         abs(drain_flux_total)>1.0e6_real64.or.abs(drainage_mass)>1.0e12_real64.or. &
         decay_rate<0.0_real64.or.decay_rate>1.0e6_real64)return

    ! Source: B1.11 solute.f90 task 2, swbr==1 aquifer update and following sqsur booking.
    if(drain_flux_total>0.0_real64)then
      next_drain_concentration=drain_concentration+substep_days/saturated_storage_per_area * &
           ((drainage_mass-drain_flux_total*drain_concentration)/aquifer_thickness- &
           decay_rate*drain_concentration*saturated_storage_per_area)
    else
      next_drain_concentration=drain_concentration+substep_days/saturated_storage_per_area * &
           (drainage_mass/aquifer_thickness-decay_rate*drain_concentration*saturated_storage_per_area)
    end if
    next_seep_concentration=next_drain_concentration
    next_surface_cumulative_mass=surface_cumulative_mass+ &
         drain_flux_total*next_drain_concentration*substep_days
    if(.not.all(ieee_is_finite([next_drain_concentration,next_seep_concentration,next_surface_cumulative_mass])))then
      next_drain_concentration=drain_concentration
      next_seep_concentration=seep_concentration
      next_surface_cumulative_mass=surface_cumulative_mass
      status=PPA_SOLUTE_AQUIFER_UPDATE_INVALID_INPUT
      return
    end if
    status=PPA_SOLUTE_AQUIFER_UPDATE_OK
  end subroutine ppa_solute_aquifer_update
end module mod_ppa_solute_aquifer_update

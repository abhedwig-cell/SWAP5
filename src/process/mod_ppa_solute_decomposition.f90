module mod_ppa_solute_decomposition
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public::PPA_SOLUTE_DECOMPOSITION_OK=0
  integer,parameter,public::PPA_SOLUTE_DECOMPOSITION_INVALID_INPUT=1
  public::ppa_solute_decomposition_rate
contains
  pure subroutine ppa_solute_decomposition_rate(depth_potential, heat_enabled, soil_temperature, &
       temperature_factor, water_content, minimum_water_content, dryness_exponent, &
       mobile_concentration, adsorbed_reference_coefficient, reference_concentration, freundlich_exponent, &
       decomposition_rate, status)
    real(real64),intent(in)::depth_potential,soil_temperature,temperature_factor
    real(real64),intent(in)::water_content,minimum_water_content,dryness_exponent,mobile_concentration
    real(real64),intent(in)::adsorbed_reference_coefficient,reference_concentration,freundlich_exponent
    logical,intent(in)::heat_enabled
    real(real64),intent(out)::decomposition_rate
    integer,intent(out)::status
    real(real64)::ftemp,ftheta,decact,concentration_ratio

    decomposition_rate=0.0_real64
    status=PPA_SOLUTE_DECOMPOSITION_INVALID_INPUT
    if(.not.all(ieee_is_finite([depth_potential,soil_temperature,temperature_factor,water_content, &
         minimum_water_content,dryness_exponent,mobile_concentration,adsorbed_reference_coefficient, &
         reference_concentration,freundlich_exponent])))return
    if(depth_potential<0.0_real64.or.depth_potential>10.0_real64.or.temperature_factor<0.0_real64.or. &
         temperature_factor>0.5_real64.or.water_content<0.0_real64.or.water_content>1.0_real64.or. &
         minimum_water_content<=0.0_real64.or.minimum_water_content>0.4_real64.or. &
         dryness_exponent<0.0_real64.or.dryness_exponent>2.0_real64.or.mobile_concentration<0.0_real64.or. &
         mobile_concentration>1000.0_real64.or.adsorbed_reference_coefficient<0.0_real64.or. &
         adsorbed_reference_coefficient>1.0e7_real64.or.reference_concentration<=1.0e-12_real64.or. &
         reference_concentration>1000.0_real64.or.freundlich_exponent<0.0_real64.or. &
         freundlich_exponent>10.0_real64)return

    ! Source: B1.11 solute.f90 task 2 decomposition activity and ctrans term.
    ftemp=0.0_real64
    if(heat_enabled)then
      if(soil_temperature<35.0_real64)then
        ftemp=exp(temperature_factor*(soil_temperature-20.0_real64))
      else
        ftemp=exp(temperature_factor*15.0_real64)
      end if
    end if
    ftheta=min(1.0_real64,(water_content/minimum_water_content)**dryness_exponent)
    decact=depth_potential*ftemp*ftheta
    if(reference_concentration<1.0_real64)then
      if(mobile_concentration>huge(1.0_real64)*reference_concentration)return
    end if
    concentration_ratio=mobile_concentration/reference_concentration
    if(concentration_ratio>1.0_real64.and.freundlich_exponent>0.0_real64)then
      if(freundlich_exponent>log(huge(1.0_real64))/log(concentration_ratio))return
    end if
    decomposition_rate=decact*water_content*mobile_concentration+ &
         decact*adsorbed_reference_coefficient*(concentration_ratio**freundlich_exponent)
    if(.not.ieee_is_finite(decomposition_rate))then
      decomposition_rate=0.0_real64
      return
    end if
    status=PPA_SOLUTE_DECOMPOSITION_OK
  end subroutine ppa_solute_decomposition_rate
end module mod_ppa_solute_decomposition

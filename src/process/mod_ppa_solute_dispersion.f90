module mod_ppa_solute_dispersion
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public::PPA_SOLUTE_DISPERSION_OK=0
  integer,parameter,public::PPA_SOLUTE_DISPERSION_INVALID_INPUT=1
  public::ppa_solute_dispersion_coefficient
contains
  pure subroutine ppa_solute_dispersion_coefficient(water_flux,volumetric_water_content, &
       water_diffusion_coefficient,longitudinal_dispersivity,interval_days,diffusion, &
       pore_velocity,dispersion, status)
    real(real64),intent(in)::water_flux,volumetric_water_content,water_diffusion_coefficient
    real(real64),intent(in)::longitudinal_dispersivity,interval_days
    real(real64),intent(out)::diffusion,pore_velocity,dispersion
    integer,intent(out)::status
    real(real64)::velocity_square,base_dispersion,correction

    diffusion=0.0_real64
    pore_velocity=0.0_real64
    dispersion=0.0_real64
    status=PPA_SOLUTE_DISPERSION_INVALID_INPUT
    if(.not.all(ieee_is_finite([water_flux,volumetric_water_content,water_diffusion_coefficient, &
         longitudinal_dispersivity,interval_days])))return
    if(volumetric_water_content<=0.0_real64.or.volumetric_water_content>1.0_real64.or. &
         water_diffusion_coefficient<0.0_real64.or.water_diffusion_coefficient>10.0_real64.or. &
         longitudinal_dispersivity<0.0_real64.or.longitudinal_dispersivity>100.0_real64.or. &
         interval_days<=0.0_real64)return

    ! Source: B1.11 solute.f90 task 2 diffus, vpore, dispr1 and dtsolu correction.
    diffusion=water_diffusion_coefficient*volumetric_water_content**2.33_real64
    if(volumetric_water_content<1.0_real64)then
      if(abs(water_flux)>huge(1.0_real64)*volumetric_water_content)return
    end if
    pore_velocity=abs(water_flux)/volumetric_water_content
    if(pore_velocity>sqrt(huge(1.0_real64)))return
    velocity_square=pore_velocity*pore_velocity
    if(longitudinal_dispersivity>1.0_real64.and.pore_velocity>1.0_real64)then
      if(longitudinal_dispersivity>huge(1.0_real64)/pore_velocity)return
    end if
    base_dispersion=diffusion+longitudinal_dispersivity*pore_velocity
    if(interval_days>2.0_real64)then
      if(velocity_square>huge(1.0_real64)/(0.5_real64*interval_days))return
    end if
    correction=0.5_real64*interval_days*velocity_square
    if(base_dispersion>huge(1.0_real64)-correction)return
    dispersion=base_dispersion+correction
    if(.not.all(ieee_is_finite([diffusion,pore_velocity,dispersion])))then
      diffusion=0.0_real64
      pore_velocity=0.0_real64
      dispersion=0.0_real64
      return
    end if
    status=PPA_SOLUTE_DISPERSION_OK
  end subroutine ppa_solute_dispersion_coefficient
end module mod_ppa_solute_dispersion

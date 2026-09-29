module mod_ppa_solute_root_uptake
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public::PPA_SOLUTE_ROOT_UPTAKE_OK=0
  integer,parameter,public::PPA_SOLUTE_ROOT_UPTAKE_INVALID_INPUT=1
  public::ppa_solute_root_uptake
contains
  pure subroutine ppa_solute_root_uptake(crop_scaling, root_water_flux, mobile_concentration, &
       layer_thickness, interval_days, uptake_rate, uptake_amount, status)
    real(real64),intent(in)::crop_scaling,root_water_flux,mobile_concentration,layer_thickness,interval_days
    real(real64),intent(out)::uptake_rate,uptake_amount
    integer,intent(out)::status
    real(real64)::rate_numerator,amount_rate

    uptake_rate=0.0_real64
    uptake_amount=0.0_real64
    status=PPA_SOLUTE_ROOT_UPTAKE_INVALID_INPUT
    if(.not.all(ieee_is_finite([crop_scaling,root_water_flux,mobile_concentration, &
         layer_thickness,interval_days])))return
    if(crop_scaling<0.0_real64.or.crop_scaling>10.0_real64.or.root_water_flux<0.0_real64.or. &
         mobile_concentration<0.0_real64.or.layer_thickness<=0.0_real64.or.interval_days<=0.0_real64)return

    ! Source: B1.11 solute.f90 task 2 `crot` and cumulative `rottot` increments.
    if(crop_scaling>1.0_real64.and.root_water_flux>1.0_real64)then
      if(crop_scaling>huge(1.0_real64)/root_water_flux)return
    end if
    rate_numerator=crop_scaling*root_water_flux
    if(rate_numerator>1.0_real64.and.mobile_concentration>1.0_real64)then
      if(rate_numerator>huge(1.0_real64)/mobile_concentration)return
    end if
    rate_numerator=rate_numerator*mobile_concentration
    if(layer_thickness<1.0_real64)then
      if(rate_numerator>huge(1.0_real64)*layer_thickness)return
    end if
    uptake_rate=rate_numerator/layer_thickness

    amount_rate=rate_numerator
    if(interval_days>1.0_real64)then
      if(amount_rate>huge(1.0_real64)/interval_days)return
    end if
    uptake_amount=amount_rate*interval_days
    if(.not.all(ieee_is_finite([uptake_rate,uptake_amount])))then
      uptake_rate=0.0_real64
      uptake_amount=0.0_real64
      return
    end if
    status=PPA_SOLUTE_ROOT_UPTAKE_OK
  end subroutine ppa_solute_root_uptake
end module mod_ppa_solute_root_uptake

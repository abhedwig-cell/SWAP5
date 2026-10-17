module mod_b111_pond_source_aligned_candidate
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::ALIGNED_OK=0,ALIGNED_INVALID=1,ALIGNED_WATER=2
 type,public::aligned_pond_receipt_t
  integer::status=ALIGNED_INVALID
  real(real64)::mass_end=0d0,soil_transfer=0d0,external_input=0d0,water_residual=0d0,mass_residual=0d0
 end type
 public::evaluate_aligned_pond
contains
 pure subroutine evaluate_aligned_pond(depth0,mass0,dt,rain,irrigation,evaporation, &
      infiltration,rain_c,irrigation_c,deposit_rate,depth1,r)
  real(real64),intent(in)::depth0,mass0,dt,rain,irrigation,evaporation,infiltration
  real(real64),intent(in)::rain_c,irrigation_c,deposit_rate,depth1
  type(aligned_pond_receipt_t),intent(out)::r
  real(real64)::mass_available,denom,scale
  r=aligned_pond_receipt_t()
  if(.not.all(ieee_is_finite([depth0,mass0,dt,rain,irrigation,evaporation, &
       infiltration,rain_c,irrigation_c,deposit_rate,depth1])))return
  if(min(depth0,mass0,rain,irrigation,evaporation,infiltration,rain_c, &
       irrigation_c,deposit_rate,depth1)<0d0.or.dt<=0d0.or.dt>1d3)return
  if(maxval([depth0,mass0,rain,irrigation,evaporation,infiltration,rain_c, &
       irrigation_c,deposit_rate,depth1])>1d8)return
  r%water_residual=depth1-depth0-(rain+irrigation-evaporation-infiltration)*dt
  r%status=ALIGNED_WATER
  if(abs(r%water_residual)>1d-10)return
  r%external_input=(rain*rain_c+irrigation*irrigation_c+deposit_rate)*dt
  mass_available=mass0+r%external_input
  denom=depth1+infiltration*dt
  if(denom<=0d0)then
    if(infiltration>0d0)return
    r%soil_transfer=0d0
  else
    r%soil_transfer=mass_available*(infiltration*dt)/denom
  end if
  if(r%soil_transfer>mass_available)return
  r%mass_end=mass_available-r%soil_transfer
  scale=max(1d0,mass_available)
  r%mass_residual=r%mass_end+r%soil_transfer-mass_available
  if(abs(r%mass_residual)>8192d0*epsilon(1d0)*scale)return
  r%status=ALIGNED_OK
 end subroutine
end module

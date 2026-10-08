module mod_b111_soil_n_rate_factors
 use iso_fortran_env, only: real64
 use ieee_arithmetic, only: ieee_is_finite
 implicit none
 private
 integer,parameter,public::B111_NRATE_OK=0,B111_NRATE_INVALID=1
 type,public::b111_soil_n_rate_result_t
   integer::status=B111_NRATE_OK
   real(real64)::temperature_factor=0d0
   real(real64)::wfps=0d0
   real(real64)::nitrification_moisture_factor=0d0
   real(real64)::denitrification_moisture_factor=0d0
   real(real64)::respiration_factor=0d0
   real(real64)::nitrification_rate_constant=0d0
   real(real64)::denitrification_rate_constant=0d0
 end type
 public::evaluate_b111_soil_n_rate_constants
contains
 pure subroutine evaluate_b111_soil_n_rate_constants(temp,temp_ref,wfrac_t,wfrac_t0,wfrac_sat, &
      wfpscrit2,cdissi,cdissi_half,nitrif_ref,denitr_ref,result)
  real(real64),intent(in)::temp,temp_ref,wfrac_t,wfrac_t0,wfrac_sat,wfpscrit2
  real(real64),intent(in)::cdissi,cdissi_half,nitrif_ref,denitr_ref
  type(b111_soil_n_rate_result_t),intent(out)::result
  real(real64)::r1,r2
  result=b111_soil_n_rate_result_t()
  if(.not.all(ieee_is_finite([temp,temp_ref,wfrac_t,wfrac_t0,wfrac_sat,wfpscrit2, &
       cdissi,cdissi_half,nitrif_ref,denitr_ref])))then
    result%status=B111_NRATE_INVALID;return
  end if
  if(wfrac_t<0d0.or.wfrac_t0<0d0.or.wfrac_sat<=0d0.or.wfpscrit2<0d0.or.wfpscrit2>=1d0.or. &
     cdissi<0d0.or.cdissi_half<0d0.or.nitrif_ref<0d0.or.denitr_ref<0d0)then
    result%status=B111_NRATE_INVALID;return
  end if
  r1=1d0/(1d0+exp(-0.26d0*(temp-17d0)))-1d0/(1d0+exp(-0.77d0*(temp-41.9d0)))
  r2=1d0/(1d0+exp(-0.26d0*(temp_ref-17d0)))-1d0/(1d0+exp(-0.77d0*(temp_ref-41.9d0)))
  if(.not.ieee_is_finite(r2).or.abs(r2)<=tiny(1d0))then
    result%status=B111_NRATE_INVALID;return
  end if
  result%temperature_factor=r1/r2
  result%wfps=0.5d0*(wfrac_t+wfrac_t0)/wfrac_sat
  result%nitrification_moisture_factor=0.9d0/(1d0+exp(-15d0*(result%wfps-0.45d0)))+0.1d0- &
       1d0/(1d0+exp(-50d0*(result%wfps-0.95d0)))
  result%denitrification_moisture_factor=(max(result%wfps-wfpscrit2,0d0)/(1d0-wfpscrit2))**2
  if(cdissi_half+cdissi>0d0)then
    result%respiration_factor=cdissi/(cdissi_half+cdissi)
  else
    result%respiration_factor=0d0
  end if
  result%nitrification_rate_constant=nitrif_ref*result%temperature_factor* &
       result%nitrification_moisture_factor
  result%denitrification_rate_constant=denitr_ref*result%temperature_factor* &
       result%denitrification_moisture_factor*result%respiration_factor
  if(.not.all(ieee_is_finite([result%temperature_factor,result%wfps, &
       result%nitrification_moisture_factor,result%denitrification_moisture_factor, &
       result%respiration_factor,result%nitrification_rate_constant,result%denitrification_rate_constant])))then
    result=b111_soil_n_rate_result_t();result%status=B111_NRATE_INVALID;return
  end if
  if(result%nitrification_rate_constant<0d0.or.result%denitrification_rate_constant<0d0)then
    result=b111_soil_n_rate_result_t();result%status=B111_NRATE_INVALID;return
  end if
  result%status=B111_NRATE_OK
 end subroutine
end module

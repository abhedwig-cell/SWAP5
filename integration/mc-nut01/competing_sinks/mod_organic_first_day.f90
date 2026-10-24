module mod_organic_first_day
 use iso_fortran_env,only:real64
 use mod_soil_n_pool_state
 use mod_b111_soil_organic_turnover
 use mod_multipool_limited_organic
 use mod_b111_soil_n_daily_candidate,only:b111_soil_n_rate_environment_t
 use mod_b111_soil_n_rate_factors
 use mod_b111_soil_n_storage_conversion
 use mod_b111_soil_n_daily_exchange
 implicit none
 private
 type,public::organic_first_receipt_t
  integer::status=1
  type(multipool_receipt_t)::organic
  type(b111_soil_n_rate_result_t)::rates
  type(b111_soil_n_exchange_result_t)::exchange
  type(soil_n_receipt_t)::budget
 end type
 public::evaluate_organic_first_day
contains
 subroutine evaluate_organic_first_day(p,s,k,e,forcing,c,r)
  type(soil_n_inventory_parameters_t),intent(in)::p
  type(soil_n_pool_state_t),intent(in)::s
  type(b111_organic_turnover_parameters_t),intent(in)::k
  type(b111_soil_n_rate_environment_t),intent(in)::e
  type(b111_soil_n_exchange_forcing_t),intent(in)::forcing
  type(soil_n_pool_state_t),intent(out)::c
  type(organic_first_receipt_t),intent(out)::r
  type(soil_n_pool_state_t)::organic
  type(b111_soil_n_exchange_forcing_t)::f
  type(b111_soil_n_concentration_state_t)::initial
  type(soil_n_transfer_t)::transfer
  real(real64)::nh4,no3
  integer::code
  c=s;r=organic_first_receipt_t()
  if(abs(forcing%dt_day-1d0)>64d0*epsilon(1d0))return
  call advance_multipool_limited(p,s,k,forcing%dt_day,1d-12,1d-9,organic,r%organic)
  if(r%organic%status/=0)return
  r%status=2
  call evaluate_b111_soil_n_rate_constants(e%temperature_c,e%temperature_reference_c, &
   forcing%wfrac_t,forcing%wfrac_t0,e%wfrac_sat,e%wfpscrit2,r%organic%carbon,e%cdissi_half_kg_m2, &
   e%nitrification_ref_per_day,e%denitrification_ref_per_day,r%rates)
  if(r%rates%status/=0)return
  r%status=3
  call b111_soil_n_concentrations_from_mass(p%depth_m,forcing%wfrac_t0,forcing%drybd,forcing%sorpcoef, &
   organic%ammonium_n_kg_m2,organic%nitrate_n_kg_m2,initial)
  if(initial%status/=0)return
  f=forcing;f%depth_m=p%depth_m;f%nminer_kg_m3=0d0
  f%ratecon_nitrif=r%rates%nitrification_rate_constant;f%ratecon_denitr=r%rates%denitrification_rate_constant
  r%status=4
  call evaluate_b111_soil_n_daily_exchange(f,initial%cnh4_kg_m3,initial%cno3_kg_m3,r%exchange)
  if(r%exchange%status/=0)return
  r%status=5
  call b111_soil_n_mass_from_concentrations(p%depth_m,f%wfrac_t,f%drybd,f%sorpcoef, &
   r%exchange%cnh4_end,r%exchange%cno3_end,nh4,no3,code)
  if(code/=0)return
  transfer%fom_delta_kg_m3=organic%fom_kg_m3-s%fom_kg_m3
  transfer%biomass_delta_kg_m3=organic%biomass_kg_m3-s%biomass_kg_m3
  transfer%humus_delta_kg_m3=organic%humus_kg_m3-s%humus_kg_m3
  transfer%ammonium_n_delta_kg_m2=nh4-s%ammonium_n_kg_m2
  transfer%nitrate_n_delta_kg_m2=no3-s%nitrate_n_kg_m2
  transfer%external_n_input_kg_m2=r%exchange%external_input_kg_m2
  transfer%external_n_output_kg_m2=r%exchange%external_output_kg_m2
  r%status=6
  call apply_soil_n_transfer(p,s,transfer,c,r%budget)
  if(r%budget%status/=0)return
  r%status=0
 end subroutine
end module

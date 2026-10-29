! Source grass day-end composition. Existing crop owner and WOFOST physiology
! remain authoritative; an inactive source growth gate does not age or replace
! the leaf cohorts. Publication belongs to the enclosing crop transaction.
module mod_wofost_grass_daily_growth
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_wofost_crop_owner_state,only:wofost_crop_owner_state_t,WOFOST_CROP_OWNER_OK
 use mod_wofost_grass_development,only:grass_development_candidate_t
 use mod_wofost_rate_parameters,only:wofost_rate_parameter_bundle_t,wofost_rate_scalar_parameters_t
 use mod_wofost_one_day_rate_state_view,only:wofost_one_day_rate_state_view_t
 use mod_wofost_prepare_assimilation,only:wofost_prepare_assimilation_result_t
 use mod_wofost_finalize_rates,only:wofost_finalize_rate_forcing_t,finalize_wofost_one_day_rates,WOFOST_FINALIZE_RATES_OK
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_window_context_t, &
  wofost_one_day_update_parameters_t,wofost_accepted_window_aggregates_t,wofost_one_day_rate_packet_t, &
  wofost_one_day_diagnostics_t,finalize_wofost_one_day_candidate,WOFOST_ONE_DAY_OK,b110_relative_transpiration
 implicit none
 private
 integer,parameter,public::GRASS_DAILY_OK=0,GRASS_DAILY_INVALID=1,GRASS_DAILY_PHYSIOLOGY_REJECTED=2
 public::complete_grass_daily_candidate
contains
 subroutine complete_grass_daily_candidate(prepared,context,view,parameters,assimilation,forcing, &
      update_parameters,aggregates,development,candidate,rates,status)
  type(wofost_crop_owner_state_t),intent(in)::prepared
  type(wofost_one_day_window_context_t),intent(in)::context
  type(wofost_one_day_rate_state_view_t),intent(in)::view
  type(wofost_rate_parameter_bundle_t),intent(in)::parameters
  type(wofost_prepare_assimilation_result_t),intent(in)::assimilation
  type(wofost_finalize_rate_forcing_t),intent(in)::forcing
  type(wofost_one_day_update_parameters_t),intent(in)::update_parameters
  type(wofost_accepted_window_aggregates_t),intent(in)::aggregates
  type(grass_development_candidate_t),intent(in)::development
  type(wofost_crop_owner_state_t),intent(out)::candidate
  type(wofost_one_day_rate_packet_t),intent(out)::rates
  integer,intent(out)::status
  type(wofost_rate_scalar_parameters_t)::s
  type(wofost_one_day_diagnostics_t)::diagnostic
  type(wofost_crop_owner_state_t)::trial
  integer::code
  candidate=wofost_crop_owner_state_t();rates=wofost_one_day_rate_packet_t();status=GRASS_DAILY_INVALID
  if(.not.parameters%ready().or..not.development%valid)return
  s=parameters%scalar_view()
  if(.not.s%grass_development.or..not.update_parameters%grass_development)return
  if(prepared%validate()/=WOFOST_CROP_OWNER_OK.or..not.prepared%crop_emerged)return
  if(.not.allocated(prepared%evolution_continuation))return
  if(.not.context%active.or..not.ieee_is_finite(context%t0).or..not.ieee_is_finite(context%t1))return
  if(context%t1-context%t0/=1d0)return
  if(.not.ieee_is_finite(forcing%average_temperature))return
  if(development%temperature_sum_increment/=max(0d0,forcing%average_temperature))return
  if(development%development_rate/=2d0/366d0)return
  if(.not.ieee_is_finite(update_parameters%development_stage_end).or.update_parameters%development_stage_end<0d0)return
  if(.not.all(ieee_is_finite([aggregates%potential_transpiration,aggregates%actual_root_uptake])))return
  if(min(aggregates%potential_transpiration,aggregates%actual_root_uptake)<0d0)return
  if(.not.development%growth_enabled)then
   ! Original update_wofost still advances TSUM/DVS when grass biomass is dormant.
   trial=prepared
   trial%evolution_continuation%temperature_sum=trial%evolution_continuation%temperature_sum+development%temperature_sum_increment
   trial%development_stage=min(trial%development_stage+development%development_rate,update_parameters%development_stage_end)
   rates%temperature_sum_increment=development%temperature_sum_increment
   rates%development_rate=development%development_rate
   rates%relative_transpiration_used=b110_relative_transpiration(aggregates)
  else
   call finalize_wofost_one_day_rates(view,parameters,assimilation,aggregates,forcing,rates,code,development)
   if(code/=WOFOST_FINALIZE_RATES_OK)then
    status=GRASS_DAILY_PHYSIOLOGY_REJECTED;return
   end if
   call finalize_wofost_one_day_candidate(prepared,context,update_parameters,aggregates,rates,trial,diagnostic,code)
   if(code/=WOFOST_ONE_DAY_OK)then
    status=GRASS_DAILY_PHYSIOLOGY_REJECTED;return
   end if
  end if
  if(trial%validate()/=WOFOST_CROP_OWNER_OK)return
  candidate=trial;status=GRASS_DAILY_OK
 end subroutine
end module

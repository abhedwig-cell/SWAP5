! Observation after a successful daily joint publication; no physical mutation.
module mod_crop_soil_n_output_observation
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_crop_extended_output
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_b111_soil_n_reactive_owner,only:reactive_state_t
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
 use mod_soil_n_pool_state,only:soil_n_pool_state_t
 use mod_crop_senescence_residue,only:crop_residue_pending_t
 use mod_fmr_crop_soil_n_senescence_application,only:senescence_joint_result_t
 use mod_fmr_crop_soil_n_joint_application,only:JOINT_OK,crop_soil_n_joint_states_match
 use mod_fmr_crop_soil_n_thermal_application,only:thermal_crop_soil_states_match
 implicit none
 private
 public::observe_accepted_crop_soil_n_day
contains
 subroutine observe_accepted_crop_soil_n_day(output,water_before,soil_before,water_after,soil_after, &
     result,t0,t1,report,row,status,thermal)
  type(crop_ext_state_t),intent(inout)::output
  type(kernel_committed_state_t),intent(in)::water_before,water_after
  type(crop_soil_state_t),intent(in)::soil_before,soil_after
  type(senescence_joint_result_t),intent(in)::result
  real(real64),intent(in)::t0,t1
  logical,intent(in)::report
  type(crop_ext_row_t),intent(out)::row
  integer,intent(out)::status
  logical,intent(in),optional::thermal
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(soil_n_pool_state_t)::pools
  type(crop_residue_pending_t)::pending
  real(real64)::clock,theta,dm(4),n(4),up(2)
  integer(int64)::revision
  logical::has,thermal_states
  row=crop_ext_row_t();status=CROP_EXT_INVALID
  if(.not.all(ieee_is_finite([t0,t1])))return
  if(t1-t0/=1d0)return
  if(result%status/=JOINT_OK.or.result%joint%status/=JOINT_OK.or.result%joint%joint%status/=JOINT_OK)return
  if(result%senescence%status/=0.or.result%joint%joint%chemical%status/=0)return
  thermal_states=.false.;if(present(thermal))thermal_states=thermal
  if(thermal_states)then
   if(.not.thermal_crop_soil_states_match(water_before,soil_before))return
   if(.not.thermal_crop_soil_states_match(water_after,soil_after))return
  else
   if(.not.crop_soil_n_joint_states_match(water_before,soil_before))return
   if(.not.crop_soil_n_joint_states_match(water_after,soil_after))return
  end if
  if(water_after%current_revision()<=water_before%current_revision())return
  call soil_before%snapshot(soil,crop)
  if(crop%harvested().or.crop%harvest_retired())return
  call soil%snapshot(clock,theta,pools,revision)
  if(clock/=t0)return
  call soil_after%snapshot(soil,crop)
  if(crop%harvested().or.crop%harvest_retired())return
  call soil%snapshot(clock,theta,pools,revision)
  if(clock/=t1)return
  dm=0d0;n=0d0
  call soil_before%pending_snapshot(pending,has)
  if(has)then
   if(.not.pending%valid().or.pending%clock/=t0)return
   dm(1:3)=pending%dry_matter_kg_ha;n(1:3)=pending%nitrogen_kg_ha
  end if
  ! The two actual integrated soil-debit terms, not fixation or total crop uptake.
  associate(exchange=>result%joint%joint%chemical%soil%process%exchange)
   if(exchange%status/=0)return
   up=[exchange%nh4_crop_uptake_kg_m2,exchange%no3_crop_uptake_kg_m2]
  end associate
  call observe_crop_ext(output,t0,t1,up,dm,n,report,row,status)
 end subroutine
end module

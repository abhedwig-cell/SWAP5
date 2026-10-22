! Capture original current-day idw/iNLOSS before their physical incorporation.
module mod_crop_soil_n_saved_harvest
 use iso_fortran_env,only:real64
 use mod_crop_ext_saved_residue
 use mod_soil_n_crop_extended_output
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_crop_soil_n_joint_application,only:crop_soil_n_joint_states_match
 use mod_b111_soil_n_reactive_owner,only:reactive_state_t
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t,wofost81_harvest_record_t
 use mod_crop_senescence_residue,only:crop_residue_pending_t
 implicit none
 private
 public::capture_crop_soil_n_saved_harvest
contains
 subroutine capture_crop_soil_n_saved_harvest(water,chemical,output,saved,status)
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(in)::chemical
  type(crop_ext_state_t),intent(in)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  integer,intent(out)::status
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(wofost81_harvest_record_t)::h
  type(crop_residue_pending_t)::pending
  real(real64)::v(9),o(17),clock,dm(4),n(4)
  logical::ready,has
  status=CROP_EXT_INVALID
  call saved%snapshot(v,ready);if(ready)return
  if(.not.crop_soil_n_joint_states_match(water,chemical))return
  call output%snapshot(o(1),o(2:9),o(10:17),ready);if(.not.ready)return
  call water%current_time(clock,ready);if(.not.ready)return
  if(clock/=o(1))return
  call chemical%snapshot(soil,crop);call crop%harvest_snapshot(h,has)
  if(.not.has)return
  if(h%pending_incorporated.or.h%clock/=clock)return
  dm=h%pending_dm;n=h%pending_n
  call chemical%pending_snapshot(pending,has)
  if(has)then
   if(.not.pending%valid().or.pending%clock/=clock)return
   dm(1:3)=dm(1:3)+pending%dry_matter_kg_ha
   n(1:3)=n(1:3)+pending%nitrogen_kg_ha
  end if
  call restore_crop_ext_saved_residue([clock,dm,n],saved,status)
 end subroutine
end module

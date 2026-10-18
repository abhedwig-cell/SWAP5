! Candidate composite read: stage all three disk owners before publishing any.
! Existing S5AJ0001 writer/reader is not changed.
module mod_b111_age_triplet_disk
 use, intrinsic :: iso_fortran_env, only: int64,real64
 use mod_kernel_transactions, only: kernel_committed_state_t
 use mod_fmr_runtime_core, only: fmr_logical_column_t,fmr_template_t
 use mod_b111_age_tracer_substep, only: b111_age_tracer_substep_forcing_t
 use mod_fmr_b111_age_route, only: age_state_t
 use mod_fmr_b111_age_joint_application, only: age_joint_states_match,JOINT_OK
 use mod_b111_surface_age_owner, only: surface_age_owner_t,snapshot_surface_age_owner
 use mod_age_joint_restart_file, only: read_age_joint_restart_file
 use mod_b111_surface_age_disk, only: read_surface_age_disk,AGE_DISK_OK
 implicit none
 private
 integer,parameter,public::TRIPLET_DISK_OK=0,TRIPLET_DISK_REJECT=1
 public::restore_age_triplet_disk
contains
 subroutine restore_age_triplet_disk(joint_path,surface_path,column,template,water_id,soil_age_id, &
       surface_id,p,water,soil_age,surface_age,status)
  character(*),intent(in)::joint_path,surface_path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,soil_age_id,surface_id
  type(b111_age_tracer_substep_forcing_t),intent(in)::p
  type(kernel_committed_state_t),intent(inout)::water
  type(age_state_t),intent(inout)::soil_age
  type(surface_age_owner_t),intent(inout)::surface_age
  integer,intent(out)::status
  type(kernel_committed_state_t)::water_trial
  type(age_state_t)::soil_trial
  type(surface_age_owner_t)::surface_trial
  real(real64)::clock,depth,stock
  integer(int64)::revision
  logical::available
  integer::code
  status=TRIPLET_DISK_REJECT
  if(water%ready().or.soil_age%ready())return
  call snapshot_surface_age_owner(surface_age,clock,depth,stock,revision,available)
  if(available)return
  call read_surface_age_disk(surface_path,surface_id,surface_trial,code)
  if(code/=AGE_DISK_OK)return
  call read_age_joint_restart_file(joint_path,column,template,water_id,soil_age_id,p, &
       water_trial,soil_trial,code,surface_trial)
  if(code/=JOINT_OK)return
  if(.not.age_joint_states_match(water_trial,soil_trial,surface_trial))return
  water=water_trial
  soil_age=soil_trial
  surface_age=surface_trial
  status=TRIPLET_DISK_OK
 end subroutine
end module

module mod_research_restart_bridge
 use iso_fortran_env,only:int64,real64
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_fmr_b111_matrix_solute_route,only:matrix_solute_state_t,reconstruct_matrix_solute_trusted,MATRIX_OK
 use mod_matrix_joint_restart_file,only:write_matrix_joint_restart_file,read_matrix_joint_restart_file
 use mod_research_joint_reactive_fct,only:research_chemical_t
 use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
 use mod_solute_mobile_salt_state,only:mobile_salt_state_t
 use mod_solute_compartment_state,only:solute_compartment_state_t
 implicit none
 private
 integer(int64),parameter::CHEMICAL_ID=680001_int64
 public::write_research_payload,read_research_payload
contains
 subroutine write_research_payload(path,column,template,water_id,water,chemical,model,status)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(kernel_committed_state_t),intent(in)::water
  type(research_chemical_t),intent(in)::chemical
  type(b111_reactive_solute_substep_forcing_t),intent(in)::model
  integer,intent(out)::status
  type(matrix_solute_state_t)::validated
  logical::exists
  status=1
  inquire(file=path,exist=exists);if(exists)return
  if(.not.water%ready().or..not.allocated(chemical%water))return
  if(any([chemical%companion%pond_mass,chemical%companion%aquifer_mass, &
   chemical%companion%age_pond_previous_concentration]/=0d0).or.any(chemical%companion%age_amount/=0d0))return
  call reconstruct_matrix_solute_trusted(model,CHEMICAL_ID,water%current_revision(),chemical%clock,chemical%water, &
   chemical%mobile%concentration_mg_cm3,chemical%mobile%mass_mg_cm2,chemical%companion%sorbed_matrix_mass,validated,status)
  if(status/=MATRIX_OK)return
  call write_matrix_joint_restart_file(path,column,template,water_id,water,validated,status)
 end subroutine
 subroutine read_research_payload(path,column,template,water_id,model,water,chemical,status)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(b111_reactive_solute_substep_forcing_t),intent(in)::model
  type(kernel_committed_state_t),intent(inout)::water
  type(research_chemical_t),intent(inout)::chemical
  integer,intent(out)::status
  type(kernel_committed_state_t)::trial_water
  type(matrix_solute_state_t)::validated
  type(research_chemical_t)::trial
  integer(int64)::revision
  status=1
  if(water%ready().or.allocated(chemical%water))return
  call read_matrix_joint_restart_file(path,column,template,water_id,CHEMICAL_ID,model,trial_water,validated,status)
  if(status/=0)return
  call validated%snapshot(trial%clock,trial%water,trial%mobile,trial%companion,revision)
  status=1
  if(.not.allocated(trial%water))return
  if(revision/=trial_water%current_revision())return
  water=trial_water;chemical=trial;status=0
 end subroutine
end module

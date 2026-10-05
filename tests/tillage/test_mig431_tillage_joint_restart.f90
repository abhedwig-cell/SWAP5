program test_mig431_tillage_joint_restart
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t,fmr_template_t,FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_state_t,fmr_new_b110_committed_state
  use mod_fmr_tillage_profile_restart, only: tillage_profile_state_t
  use mod_fmr_tillage_event_owner, only: initialize_tillage_owner,TILLAGE_OWNER_OK
  use mod_fmr_tillage_joint_restart
  implicit none
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters,wrong
  type(fmr_b110_physical_state_t) :: state
  type(kernel_committed_state_t) :: original,recovered
  type(tillage_profile_state_t) :: profile,recovered_profile
  type(tillage_joint_restart_t) :: bundle,corrupt
  logical :: ok
  integer :: code
  real(real64) :: head(2)

  column%column_id=31_int64
  column%template_id=1905_int64
  column%parameter_ref=18_int64
  column%state_handle=1_int64
  column%forcing_handle=1_int64
  column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  template%template_id=1905_int64
  template%physics_topology_id=190501_int64
  template%vertical_layout_id=190502_int64
  template%state_layout_id=190503_int64
  template%solver_interface_id=190504_int64
  template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  parameters%parameter_set_id=18_int64
  parameters%active_nodes=2
  allocate(parameters%cofgen(41,2))
  parameters%cofgen=0.0_real64
  parameters%cofgen(1,:)=0.06_real64
  parameters%cofgen(2,:)=0.42_real64
  parameters%cofgen(3,:)=7.0_real64
  parameters%cofgen(4,:)=0.025_real64
  parameters%cofgen(5,:)=0.5_real64
  parameters%cofgen(6,:)=2.0_real64
  parameters%cofgen(7,:)=0.5_real64
  head=[-10.0_real64,-20.0_real64]
  state%active_nodes=2
  allocate(state%pressure_head(2),state%water_content(2))
  state%pressure_head=head
  state%water_content=0.06_real64+0.36_real64*(1.0_real64+(0.025_real64*abs(head))**2)**(-0.5_real64)
  call fmr_new_b110_committed_state(original,31_int64,state,2.0_real64,ok)
  if(.not. ok) error stop 1
  call initialize_tillage_owner([3.0_real64],2.0_real64,profile%owner,code)
  if(code /= TILLAGE_OWNER_OK) error stop 2
  profile%water_content=state%water_content
  profile%pressure_head_cm=state%pressure_head
  profile%ponding_depth_cm=state%ponding_depth
  profile%density=[1200.0_real64,1400.0_real64]
  profile%event_density=profile%density
  allocate(profile%vg(2))
  profile%vg%theta_residual=0.06_real64
  profile%vg%theta_saturated=0.42_real64
  profile%vg%saturated_conductivity=7.0_real64
  profile%vg%alpha=0.025_real64
  profile%vg%lambda=0.5_real64
  profile%vg%n=2.0_real64
  profile%vg%m=0.5_real64
  call export_tillage_joint_restart(column,template,parameters,original,profile,1,987_int64,bundle,code)
  if(code /= TILLAGE_JOINT_RESTART_OK) error stop 3
  wrong=parameters
  wrong%cofgen(4,1)=0.03_real64
  call restore_tillage_joint_restart(bundle,column,template,wrong,1,987_int64, &
       recovered,recovered_profile,ok,code)
  if(ok .or. recovered%ready()) error stop 4
  corrupt=bundle
  corrupt%management%water_content(1)=0.1_real64
  call restore_tillage_joint_restart(corrupt,column,template,parameters,1,987_int64, &
       recovered,recovered_profile,ok,code)
  if(ok .or. recovered%ready()) error stop 5
  call restore_tillage_joint_restart(bundle,column,template,parameters,1,988_int64, &
       recovered,recovered_profile,ok,code)
  if(ok .or. recovered%ready()) error stop 6
  call restore_tillage_joint_restart(bundle,column,template,parameters,1,987_int64, &
       recovered,recovered_profile,ok,code)
  if(.not. ok .or. code /= TILLAGE_JOINT_RESTART_OK .or. .not. recovered%ready()) error stop 7
  if(recovered%current_lineage_id() /= 31_int64 .or. &
       recovered%current_revision() /= original%current_revision()) error stop 8
  if(any(recovered_profile%water_content /= profile%water_content)) error stop 9
  print '(a)', 'F_MIG431_TILLAGE_JOINT_RESTART_O0_O2=PASS'
end program

program test_crop_certified_hydrothermal_forcing
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_kernel_transactions, only: kernel_committed_state_t,kernel_parameter_identity_t, &
       kernel_reconstruct_committed_state_trusted,KERNEL_TRUSTED_RECONSTRUCTION_OK
 use mod_transaction_reference, only: transaction_state_t
 use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_physical_parameters_t,fmr_new_b110_committed_state
 use mod_soil_temperature_contract, only: initialize_soil_temperature_state,SOIL_TEMP_OK
 use mod_fmr_crop_certified_hydrothermal_forcing
 implicit none
 type(kernel_committed_state_t):: committed,plain,restarted
 type(fmr_b110_physical_state_t):: physical
 type(fmr_b110_physical_parameters_t):: p
 type(kernel_parameter_identity_t):: persisted
 class(transaction_state_t), allocatable:: snapshot
 integer:: st,node
 logical:: ok,available,reconstructed
 real(real64):: prep,sow,temp
 physical%active_nodes=2
 physical%pressure_head=[-100.0_real64,-1000.0_real64]
 physical%water_content=[0.2_real64,0.3_real64]
 allocate(physical%soil_temperature)
 call initialize_soil_temperature_state([8.0_real64,12.0_real64],physical%soil_temperature,st)
 if(st/=SOIL_TEMP_OK) error stop 1
 p%parameter_set_id=91_int64
 p%active_nodes=2
 p%z=[-5.0_real64,-20.0_real64]
 p%dz=[10.0_real64,20.0_real64]
 p%soil_temperature_active=.true.
 call fmr_new_b110_committed_state(plain,21_int64,physical,3.0_real64,ok)
 if(.not.ok) error stop 2
 call sample_certified_committed_crop_hydrothermal_forcing(plain,21_int64,0_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,prep,sow,temp,node,st)
 if(st/=CROP_CERT_FORCE_UNCERTIFIED) error stop 3
 call fmr_new_b110_committed_state(committed,21_int64,physical,3.0_real64,ok,parameters=p)
 if(.not.ok) error stop 4
 call sample_certified_committed_crop_hydrothermal_forcing(committed,21_int64,0_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,prep,sow,temp,node,st)
 if(st/=CROP_CERT_FORCE_OK.or.node/=2.or.temp/=12.0_real64) error stop 5
 if(abs(prep+100.0_real64)>1.0e-11_real64) error stop 6
 if(abs(sow+10.0_real64**(7.0_real64/3.0_real64))>1.0e-10_real64) error stop 7
 call sample_certified_committed_crop_hydrothermal_forcing(committed,21_int64,1_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,prep,sow,temp,node,st)
 if(st/=CROP_CERT_FORCE_STALE.or.prep/=0.0_real64) error stop 8
 call sample_certified_committed_crop_hydrothermal_forcing(committed,21_int64,0_int64,3.0_real64, &
      -10.0_real64,-35.0_real64,-15.0_real64,prep,sow,temp,node,st)
 if(st/=CROP_CERT_FORCE_GRID.or.node/=0) error stop 9
 call committed%certified_parameter_identity(persisted,available)
 if(.not.available) error stop 10
 call committed%snapshot(snapshot,available)
 if(.not.available) error stop 11
 call kernel_reconstruct_committed_state_trusted(restarted,21_int64,0_int64,snapshot,3.0_real64, &
      .true.,reconstructed,st,parameters=p,persisted_identity=persisted)
 if(.not.reconstructed.or.st/=KERNEL_TRUSTED_RECONSTRUCTION_OK) error stop 12
 call sample_certified_committed_crop_hydrothermal_forcing(restarted,21_int64,0_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,prep,sow,temp,node,st)
 if(st/=CROP_CERT_FORCE_OK.or.node/=2.or.temp/=12.0_real64) error stop 13
 print '(a)','CROP_CERTIFIED_HYDROTHERMAL_FORCING=PASS'
end program

program test_crop_certified_sowing_source
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_transaction_reference, only: transaction_state_t
 use mod_kernel_transactions, only: kernel_committed_state_t,kernel_parameter_identity_t, &
     kernel_reconstruct_committed_state_trusted, KERNEL_TRUSTED_RECONSTRUCTION_OK
 use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
     fmr_b110_physical_parameters_t,fmr_new_b110_committed_state
 use mod_soil_temperature_contract, only: initialize_soil_temperature_state,SOIL_TEMP_OK
 use mod_fmr_crop_certified_sowing_source
 implicit none
 type(kernel_committed_state_t):: committed,plain,restarted
 type(fmr_b110_physical_state_t):: physical,cold
 type(fmr_b110_physical_parameters_t):: p
 type(kernel_parameter_identity_t):: identity
 class(transaction_state_t),allocatable:: snapshot,malformed
 integer:: st,node
 logical:: ok,available,reconstructed
 real(real64):: head,temp
 physical%active_nodes=2
 physical%pressure_head=[-50.0_real64,-100.0_real64]
 physical%water_content=[0.20_real64,0.30_real64]
 allocate(physical%soil_temperature)
 call initialize_soil_temperature_state([8.0_real64,12.0_real64],physical%soil_temperature,st)
 if(st/=SOIL_TEMP_OK) error stop 1
 p%parameter_set_id=81_int64
 p%active_nodes=2
 p%z=[-5.0_real64,-20.0_real64]
 p%dz=[10.0_real64,20.0_real64]
 p%soil_temperature_active=.true.
 call fmr_new_b110_committed_state(plain,10_int64,physical,7.0_real64,ok)
 if(.not.ok) error stop 2
 call sample_certified_committed_sowing_source(plain,10_int64,0_int64,7.0_real64, &
      -15.0_real64,node,head,temp,st)
 if(st/=CROP_CERT_SOW_UNCERTIFIED.or.node/=0) error stop 3
 call fmr_new_b110_committed_state(committed,10_int64,physical,7.0_real64,ok,parameters=p)
 if(.not.ok) error stop 4
 call sample_certified_committed_sowing_source(committed,10_int64,0_int64,7.0_real64, &
      -15.0_real64,node,head,temp,st)
 if(st/=CROP_CERT_SOW_OK.or.node/=2.or.head/=-100.0_real64.or.temp/=12.0_real64) error stop 5
 call sample_certified_committed_sowing_source(committed,10_int64,0_int64,7.0_real64, &
      -31.0_real64,node,head,temp,st)
 if(st/=CROP_CERT_SOW_GRID.or.node/=0) error stop 6
 call sample_certified_committed_sowing_source(committed,10_int64,1_int64,7.0_real64, &
      -15.0_real64,node,head,temp,st)
 if(st/=CROP_CERT_SOW_PHYSICAL.or.head/=0.0_real64) error stop 7
 call sample_certified_committed_sowing_source(committed,11_int64,0_int64,7.0_real64, &
      -15.0_real64,node,head,temp,st)
 if(st/=CROP_CERT_SOW_PHYSICAL) error stop 8
 call sample_certified_committed_sowing_source(committed,10_int64,0_int64,8.0_real64, &
      -15.0_real64,node,head,temp,st)
 if(st/=CROP_CERT_SOW_PHYSICAL) error stop 9
 call committed%certified_parameter_identity(identity,available)
 if(.not.available) error stop 10
 if(.not.fmr_b110_certified_candidate_layout_matches(identity,physical)) &
     error stop 'valid thermal candidate rejected'
 cold=physical
 call initialize_soil_temperature_state([8.0_real64],cold%soil_temperature,st)
 if(st/=SOIL_TEMP_OK) error stop 'malformed heat fixture failed'
 if(fmr_b110_certified_candidate_layout_matches(identity,cold)) &
     error stop 'one-node heat continuation passed two-node certificate'
 call committed%snapshot(snapshot,available)
 if(.not.available) error stop 11
 cold=physical
 deallocate(cold%soil_temperature)
 allocate(malformed,source=cold)
 call kernel_reconstruct_committed_state_trusted(restarted,10_int64,0_int64,malformed,7.0_real64, &
      .true.,reconstructed,st,parameters=p,persisted_identity=identity)
 if(reconstructed) error stop 'heat-missing certified restart accepted'
 call kernel_reconstruct_committed_state_trusted(restarted,10_int64,0_int64,snapshot,7.0_real64, &
      .true.,reconstructed,st,parameters=p,persisted_identity=identity)
 if(.not.reconstructed.or.st/=KERNEL_TRUSTED_RECONSTRUCTION_OK) error stop 12
 call sample_certified_committed_sowing_source(restarted,10_int64,0_int64,7.0_real64, &
      -15.0_real64,node,head,temp,st)
 if(st/=CROP_CERT_SOW_OK.or.node/=2.or.head/=-100.0_real64.or.temp/=12.0_real64) error stop 13
 print '(a)','CROP_CERTIFIED_SOW_SOURCE=PASS'
end program

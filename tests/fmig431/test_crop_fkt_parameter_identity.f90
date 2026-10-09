program test_crop_fkt_parameter_identity
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_transaction_reference, only: transaction_state_t
 use mod_kernel_transactions, only: kernel_committed_state_t, kernel_parameter_identity_t, &
      kernel_reconstruct_committed_state_trusted, KERNEL_TRUSTED_RECONSTRUCTION_OK
 use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
      fmr_b110_physical_parameters_t, fmr_new_b110_committed_state
 implicit none
 type(kernel_committed_state_t):: committed,restarted
 type(fmr_b110_physical_state_t):: source
 type(fmr_b110_physical_parameters_t):: p,q
 type(kernel_parameter_identity_t):: origin,changed
 class(transaction_state_t),allocatable:: physical
 logical:: ok,available,reconstructed
 integer:: status
 source%active_nodes=2
 source%pressure_head=[-50.0_real64,-100.0_real64]
 source%water_content=[0.2_real64,0.3_real64]
 p%parameter_set_id=71_int64
 p%active_nodes=2
 p%z=[-5.0_real64,-20.0_real64]
 p%dz=[10.0_real64,20.0_real64]
 call fmr_new_b110_committed_state(committed,10_int64,source,7.0_real64,ok,parameters=p)
 if(.not.ok) error stop 'certified init failed'
 call committed%certified_parameter_identity(origin,available)
 if(.not.available.or..not.origin%valid) error stop 'missing F-KT certificate'
 if(origin%parameter_set_id/=71_int64.or.any(origin%dz/=p%dz)) error stop 'bad certificate'
 q=p
 call q%capture_identity(changed,available)
 if(.not.available.or..not.origin%matches(changed)) error stop 'matching grid rejected'
 q%parameter_set_id=72_int64
 call q%capture_identity(changed,available)
 if(.not.available) error stop 'second valid ID missing'
 if(origin%matches(changed)) error stop 'different ID admitted'
 q=p
 q%dz=[15.0_real64,15.0_real64]
 q%z=[-7.5_real64,-22.5_real64]
 call q%capture_identity(changed,available)
 if(.not.available) error stop 'second valid equal-sized grid missing'
 if(origin%matches(changed)) error stop 'different equal-sized grid admitted'
 q=p
 q%soil_temperature_active=.true.
 call q%capture_identity(changed,available)
 if(origin%matches(changed)) error stop 'heat switch admitted'
 q=p
 q%dz=[20.0_real64,10.0_real64]
 call q%capture_identity(changed,available)
 if(available) error stop 'inconsistent midpoint grid certified'
 call committed%snapshot(physical,available)
 if(.not.available) error stop 'missing snapshot'
 call kernel_reconstruct_committed_state_trusted(restarted,10_int64,0_int64,physical,7.0_real64, &
      .true.,reconstructed,status,parameters=p)
 if(reconstructed) error stop 'restart without original certificate accepted'
 q=p
 q%parameter_set_id=72_int64
 call kernel_reconstruct_committed_state_trusted(restarted,10_int64,0_int64,physical,7.0_real64, &
      .true.,reconstructed,status,parameters=q,persisted_identity=origin)
 if(reconstructed) error stop 'restart with changed parameter ID accepted'
 q=p
 q%dz=[15.0_real64,15.0_real64]
 q%z=[-7.5_real64,-22.5_real64]
 call kernel_reconstruct_committed_state_trusted(restarted,10_int64,0_int64,physical,7.0_real64, &
      .true.,reconstructed,status,parameters=q,persisted_identity=origin)
 if(reconstructed) error stop 'restart with changed equal-sized grid accepted'
 call kernel_reconstruct_committed_state_trusted(restarted,10_int64,0_int64,physical,7.0_real64, &
      .true.,reconstructed,status,parameters=p,persisted_identity=origin)
 if(.not.reconstructed.or.status/=KERNEL_TRUSTED_RECONSTRUCTION_OK) error stop 'certified restart failed'
 call restarted%certified_parameter_identity(changed,available)
 if(.not.available.or..not.origin%matches(changed)) error stop 'restart dropped certificate'
 q=p
 q%parameter_set_id=0_int64
 call fmr_new_b110_committed_state(committed,10_int64,source,7.0_real64,ok,parameters=q)
 if(ok) error stop 'invalid parameter identity accepted'
 call committed%certified_parameter_identity(changed,available)
 if(available) error stop 'failed initialization published identity'
 print '(a)','CROP_FKT_PARAMETER_IDENTITY=PASS'
end program

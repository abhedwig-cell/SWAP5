program zero_restart
 use iso_fortran_env, only: real64,int64
 use mod_transaction_reference, only: transaction_state_t
 use mod_wofost_crop_owner_state
 use mod_fmr_wofost_crop_transaction
 use mod_kernel_transactions, only: kernel_committed_state_t
 use mod_fwof40_external_crop_restart_adapter
 implicit none
 type(wofost_crop_owner_state_t)::owner
 type(fmr_wofost_crop_transaction_state_t)::tx
 type(kernel_committed_state_t)::committed
 class(transaction_state_t),allocatable::payload
 logical::ok
 integer::st
 owner%crop_emerged=.true.;owner%development_stage=0.5_real64
 allocate(owner%biomass)
 owner%biomass%root_biomass=20;owner%biomass%stem_biomass=30;owner%biomass%storage_biomass=5
 owner%biomass%leaf_biomass=[10.0_real64]
 owner%biomass%specific_leaf_area=[0.02_real64];owner%biomass%leaf_age=[0.0_real64]
 call initialize_fmr_wofost_crop_transaction_state(owner,tx,st)
 if(st/=0)error stop 'zero state'
 call tx%clone(payload)
 call committed%initialize(91001_int64,payload,ok,10.0_real64)
 if(.not.ok)error stop 'zero committed'
 call write_fwof40_crop_restart_artifact('zero.restart',committed,ok,st)
 if(.not.ok.or.st/=0)error stop 'zero restart'
 print '(a)','ZERO_COUNTER_EXISTING_CODEC_WRITER=PASS'
end program

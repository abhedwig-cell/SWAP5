program test_crop_atomic_accepted_hydroheat
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_kernel_transactions, only: kernel_committed_state_t
 use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
 use mod_soil_temperature_contract, only: initialize_soil_temperature_state,SOIL_TEMP_OK
 use mod_fmr_crop_atomic_accepted_hydroheat
 implicit none
 type(kernel_committed_state_t):: committed
 type(fmr_b110_physical_state_t):: state
 integer:: st
 logical:: ok
 real(real64):: h,t
 call sample_committed_crop_hydroheat(committed,10_int64,0_int64,7.0_real64,1,h,t,st)
 if(st/=CROP_HYDROHEAT_INVALID) error stop 1
 state%active_nodes=2
 state%pressure_head=[-20.0_real64,-100.0_real64]
 state%water_content=[0.25_real64,0.30_real64]
 call fmr_new_b110_committed_state(committed,10_int64,state,7.0_real64,ok)
 if(.not.ok) error stop 2
 call sample_committed_crop_hydroheat(committed,10_int64,0_int64,7.0_real64,1,h,t,st)
 if(st/=CROP_HYDROHEAT_ABSENT) error stop 3
 allocate(state%soil_temperature)
 call initialize_soil_temperature_state([8.0_real64,12.0_real64],state%soil_temperature,st)
 if(st/=SOIL_TEMP_OK) error stop 4
 call fmr_new_b110_committed_state(committed,10_int64,state,7.0_real64,ok)
 if(.not.ok) error stop 5
 call sample_committed_crop_hydroheat(committed,10_int64,0_int64,7.0_real64,2,h,t,st)
 if(st/=CROP_HYDROHEAT_OK.or.h/=-100.0_real64.or.t/=12.0_real64) error stop 6
 call sample_committed_crop_hydroheat(committed,11_int64,0_int64,7.0_real64,2,h,t,st)
 if(st/=CROP_HYDROHEAT_STALE.or.h/=0.0_real64.or.t/=0.0_real64) error stop 7
 call sample_committed_crop_hydroheat(committed,10_int64,1_int64,7.0_real64,2,h,t,st)
 if(st/=CROP_HYDROHEAT_STALE) error stop 8
 call sample_committed_crop_hydroheat(committed,10_int64,0_int64,8.0_real64,2,h,t,st)
 if(st/=CROP_HYDROHEAT_STALE) error stop 9
 call sample_committed_crop_hydroheat(committed,10_int64,0_int64,7.0_real64,3,h,t,st)
 if(st/=CROP_HYDROHEAT_NODE.or.h/=0.0_real64.or.t/=0.0_real64) error stop 10
 print '(a)','SW431_CROP_ATOMIC_HYDROHEAT=PASS'
end program

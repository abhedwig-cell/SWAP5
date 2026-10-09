program test_crop_accepted_soil_temperature
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_soil_temperature_contract, only: initialize_soil_temperature_state, SOIL_TEMP_OK
  use mod_fmr_crop_accepted_soil_temperature
  implicit none
  type(kernel_committed_state_t) :: committed
  type(fmr_b110_physical_state_t) :: source
  integer :: status
  logical :: ok
  real(real64) :: sampled
  call sample_committed_crop_soil_temperature(committed,10_int64,0_int64,7.0_real64,1,sampled,status)
  if(status/=CROP_ACCEPTED_TEMP_INVALID) error stop 'uninitialized F-KT accepted'
  source%active_nodes=2
  source%pressure_head=[-50.0_real64,-100.0_real64]
  source%water_content=[0.20_real64,0.30_real64]
  call fmr_new_b110_committed_state(committed,10_int64,source,7.0_real64,ok)
  if(.not.ok) error stop 'cold F-KT initialization failed'
  call sample_committed_crop_soil_temperature(committed,10_int64,0_int64,7.0_real64,1,sampled,status)
  if(status/=CROP_ACCEPTED_TEMP_ABSENT) error stop 'missing heat falsely permitted'
  allocate(source%soil_temperature)
  call initialize_soil_temperature_state([8.0_real64,12.0_real64],source%soil_temperature,status)
  if(status/=SOIL_TEMP_OK) error stop 'heat state initialization failed'
  call fmr_new_b110_committed_state(committed,10_int64,source,7.0_real64,ok)
  if(.not.ok) error stop 'thermal F-KT initialization failed'
  call sample_committed_crop_soil_temperature(committed,10_int64,0_int64,7.0_real64,2,sampled,status)
  if(status/=CROP_ACCEPTED_TEMP_OK.or.abs(sampled-12.0_real64)>1.0e-12_real64) &
       error stop 'accepted heat snapshot mismatch'
  call sample_committed_crop_soil_temperature(committed,11_int64,0_int64,7.0_real64,2,sampled,status)
  if(status/=CROP_ACCEPTED_TEMP_MISMATCH) error stop 'foreign lineage admitted'
  call sample_committed_crop_soil_temperature(committed,10_int64,1_int64,7.0_real64,2,sampled,status)
  if(status/=CROP_ACCEPTED_TEMP_MISMATCH) error stop 'stale revision admitted'
  call sample_committed_crop_soil_temperature(committed,10_int64,0_int64,8.0_real64,2,sampled,status)
  if(status/=CROP_ACCEPTED_TEMP_MISMATCH) error stop 'wrong time admitted'
  call sample_committed_crop_soil_temperature(committed,10_int64,0_int64,7.0_real64,3,sampled,status)
  if(status/=CROP_ACCEPTED_TEMP_NODE) error stop 'invalid heat node admitted'
  print '(a)', 'SW431_CROP_ACCEPTED_THERMAL_FKT=PASS'
end program

program test_crop_accepted_hydraulic_provenance
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_crop_accepted_hydraulic_provenance, only: &
       crop_accepted_hydraulic_provenance_t, bind_committed_crop_hydraulic_provenance, &
       CROP_HYD_PROV_INVALID, CROP_HYD_PROV_OK, CROP_HYD_PROV_MISMATCH
  use mod_fmr_crop_accepted_head_depth_binding, only: propose_committed_crop_head_depth_average, &
       CROP_HEAD_DEPTH_OK, CROP_HEAD_DEPTH_PROVENANCE, CROP_HEAD_DEPTH_GRID
  implicit none
  type(kernel_committed_state_t) :: committed
  type(fmr_b110_physical_state_t) :: source
  type(crop_accepted_hydraulic_provenance_t) :: view
  integer :: status
  logical :: ok
  real(real64) :: avg
  call bind_committed_crop_hydraulic_provenance(committed,1_int64,0_int64,0.0_real64,view,status)
  if(status/=CROP_HYD_PROV_INVALID.or.view%valid) error stop 'uninitialized F-KT incorrectly admitted'
  source%active_nodes=2
  source%pressure_head=[-50.0_real64,-100.0_real64]
  source%water_content=[0.20_real64,0.30_real64]
  call fmr_new_b110_committed_state(committed,11_int64,source,7.0_real64,ok)
  if(.not.ok) error stop 'valid B110 F-KT fixture could not initialize'
  call bind_committed_crop_hydraulic_provenance(committed,11_int64,0_int64,7.0_real64,view,status)
  if(status/=CROP_HYD_PROV_OK.or..not.view%valid) error stop 'accepted F-KT snapshot rejected'
  if(view%hydraulic%active_nodes/=2) error stop 'accepted node count mismatched'
  if(any(view%hydraulic%pressure_head/=source%pressure_head)) error stop 'pressure heads mismatched'
  if(any(view%hydraulic%water_content/=source%water_content)) error stop 'water contents mismatched'
  call bind_committed_crop_hydraulic_provenance(committed,12_int64,0_int64,7.0_real64,view,status)
  if(status/=CROP_HYD_PROV_MISMATCH.or.view%valid) error stop 'foreign lineage admitted'
  call bind_committed_crop_hydraulic_provenance(committed,11_int64,1_int64,7.0_real64,view,status)
  if(status/=CROP_HYD_PROV_MISMATCH.or.view%valid) error stop 'stale revision admitted'
  call bind_committed_crop_hydraulic_provenance(committed,11_int64,0_int64,8.0_real64,view,status)
  if(status/=CROP_HYD_PROV_MISMATCH.or.view%valid) error stop 'wrong committed time admitted'
  call bind_committed_crop_hydraulic_provenance(committed,-1_int64,0_int64,7.0_real64,view,status)
  if(status/=CROP_HYD_PROV_INVALID.or.view%valid) error stop 'invalid lineage admitted'
  call propose_committed_crop_head_depth_average(committed,11_int64,0_int64,7.0_real64, &
       -15.0_real64,[10.0_real64,20.0_real64],avg,status)
  if(status/=CROP_HEAD_DEPTH_OK) error stop 'read-only accepted depth failed'
  if(abs(avg + 50.0_real64**(2.0_real64/3.0_real64)*100.0_real64**(1.0_real64/3.0_real64))>1.0e-10_real64) &
       error stop 'B1.11 weighted pF mismatch'
  call propose_committed_crop_head_depth_average(committed,12_int64,0_int64,7.0_real64, &
       -15.0_real64,[10.0_real64,20.0_real64],avg,status)
  if(status/=CROP_HEAD_DEPTH_PROVENANCE) error stop 'foreign lineage permitted'
  call propose_committed_crop_head_depth_average(committed,11_int64,0_int64,7.0_real64, &
       -15.0_real64,[10.0_real64],avg,status)
  if(status/=CROP_HEAD_DEPTH_GRID) error stop 'dimension mismatch permitted'
  call propose_committed_crop_head_depth_average(committed,11_int64,0_int64,7.0_real64, &
       -40.0_real64,[10.0_real64,20.0_real64],avg,status)
  if(status/=CROP_HEAD_DEPTH_GRID) error stop 'out of grid permitted'
  print '(a)', 'SW431_CROP_ACCEPTED_HEAD_DEPTH=PASS'
  print '(a)', 'SW431_CROP_ACCEPTED_HYDRAULIC_INVALID=PASS'
  print '(a)', 'SW431_CROP_ACCEPTED_HYDRAULIC_POSITIVE=PASS'
end program

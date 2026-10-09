program test_crop_accepted_hydraulic_provenance
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_crop_accepted_hydraulic_provenance, only: &
       crop_accepted_hydraulic_provenance_t, bind_committed_crop_hydraulic_provenance, &
       CROP_HYD_PROV_INVALID
  implicit none
  type(kernel_committed_state_t) :: committed
  type(crop_accepted_hydraulic_provenance_t) :: view
  integer :: status
  call bind_committed_crop_hydraulic_provenance(committed,1_int64,0_int64,0.0_real64,view,status)
  if(status/=CROP_HYD_PROV_INVALID.or.view%valid) error stop 'uninitialized F-KT incorrectly admitted'
  call bind_committed_crop_hydraulic_provenance(committed,-1_int64,0_int64,0.0_real64,view,status)
  if(status/=CROP_HYD_PROV_INVALID.or.view%valid) error stop 'invalid lineage incorrectly admitted'
  print '(a)', 'SW431_CROP_ACCEPTED_HYDRAULIC_INVALID=PASS'
end program

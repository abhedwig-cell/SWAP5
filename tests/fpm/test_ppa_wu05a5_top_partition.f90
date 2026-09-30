program test_ppa_wu05a5_top_partition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_request_t, &
       macropore_top_partition_result_t, evaluate_macropore_top_partition, &
       apply_accepted_top_partition
  implicit none

  type(macropore_top_partition_request_t) :: request
  type(macropore_top_partition_result_t) :: result
  type(macropore_continuation_state_t) :: macro
  logical :: ok

  request%num_domains=3
  request%top_node=1
  allocate(request%requested_vertical_cm(3),request%requested_lateral_cm(3), &
       request%available_capacity_cm(3),request%domain_fraction(3))
  request%requested_vertical_cm=[0.10_real64,0.15_real64,0.25_real64]
  request%requested_lateral_cm=0.0_real64
  request%available_capacity_cm=[0.02_real64,0.02_real64,0.02_real64]
  request%domain_fraction=[0.2_real64,0.3_real64,0.5_real64]

  call evaluate_macropore_top_partition(request,result)
  if(.not.result%valid) error stop 'A5 partition invalid'
  if(abs(result%accepted_total_cm-0.06_real64)>1.0e-12_real64) error stop 'A5 accepted total'
  if(abs(result%returned_surface_cm-0.44_real64)>1.0e-12_real64) error stop 'A5 returned surface'
  if(abs(result%receipt_residual_cm)>1.0e-12_real64) error stop 'A5 receipt residual'

  call macro%initialize(3,2,ok)
  if(.not.ok) error stop 'A5 macro init'
  macro%volume_domain_cp(:,1)=0.02_real64
  macro%volume_domain_cp(:,2)=0.20_real64
  macro%water_domain_cp=0.0_real64

  call apply_accepted_top_partition(result,macro,ok)
  if(.not.ok) error stop 'A5 apply partition'
  if(abs(sum(macro%water_domain_cp(:,1))-0.06_real64)>1.0e-12_real64) &
       error stop 'A5 candidate top receipt'

  print '(a)', 'PPA_WU05A5_TOP_PARTITION=PASS'
end program test_ppa_wu05a5_top_partition

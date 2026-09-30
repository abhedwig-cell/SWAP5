program test_macropore_dynamic_crack
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_dynamic_crack, only: macropore_dynamic_crack_request_t, &
       macropore_dynamic_crack_result_t, evaluate_macropore_dynamic_crack
  implicit none
  type(macropore_dynamic_crack_request_t)::request
  type(macropore_dynamic_crack_result_t)::result

  request%num_nodes=3
  allocate(request%theta_previous(3),request%theta_current(3),request%theta_s(3),request%theta_crack(3), &
       request%dz(3),request%shrinkage_relative(3),request%matrix_fraction(3),request%geometry_factor(3), &
       request%minimum_subsidence_cm(3),request%prior_dynamic_volume_cm(3))
  request%theta_previous=0.30_real64
  request%theta_current=0.35_real64
  request%theta_s=0.45_real64
  request%theta_crack=0.30_real64
  request%dz=10.0_real64
  request%shrinkage_relative=0.05_real64
  request%matrix_fraction=0.92_real64
  request%geometry_factor=3.0_real64
  request%minimum_subsidence_cm=0.0_real64
  request%prior_dynamic_volume_cm=0.0_real64

  call evaluate_macropore_dynamic_crack(request,result)
  if(.not.result%valid)error stop 'dynamic crack invalid'
  if(abs(result%dynamic_volume_cm(2))>1.0e-15_real64)error stop 'fresh crack should close'

  request%prior_dynamic_volume_cm(2)=0.08_real64
  call evaluate_macropore_dynamic_crack(request,result)
  if(abs(result%dynamic_volume_cm(2)-0.30928072600977707_real64)>1.0e-12_real64) &
       error stop 'historic crack oracle'

  request%prior_dynamic_volume_cm=0.0_real64
  request%prior_dynamic_volume_cm(1)=0.08_real64
  call evaluate_macropore_dynamic_crack(request,result)
  if(abs(result%dynamic_volume_cm(2)-0.30928072600977707_real64)>1.0e-12_real64) &
       error stop 'neighbor crack oracle'

  print '(a)', 'PPA_WU05A7_DYNAMIC_CRACK=PASS'
end program test_macropore_dynamic_crack

program test_ppa_wu05_migmac01_covering_layer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_covering_layer_input, only: covering_layer_input_request_t, evaluate_covering_layer_input
  implicit none
  type(covering_layer_input_request_t) :: req
  real(real64), allocatable :: q(:)
  logical :: ok

  req%top_node=3
  req%step_duration_day=0.1_real64
  req%matrix_head_above_cm=3.0_real64
  req%dz_above_cm=2.0_real64
  req%minimum_polygon_diameter_cm=10.0_real64
  req%covering_layer_ksat_cm_per_day=5.0_real64
  req%total_macropore_volume_top_cm=0.2_real64
  req%domain_top_volume_cm=[0.12_real64,0.08_real64]
  call evaluate_covering_layer_input(req,q,ok)
  if(.not.ok) error stop 1
  if(abs(q(1)-0.11023356798381329_real64)>5e-14_real64) error stop 2
  if(abs(q(2)-0.07348904532254219_real64)>5e-14_real64) error stop 3
  if(abs(sum(q)-0.18372261330635548_real64)>5e-14_real64) error stop 4

  req%matrix_head_above_cm=0.0_real64
  call evaluate_covering_layer_input(req,q,ok)
  if(.not.ok .or. any(q/=0.0_real64)) error stop 5

  req%matrix_head_above_cm=-1.0_real64
  call evaluate_covering_layer_input(req,q,ok)
  if(.not.ok .or. any(q/=0.0_real64)) error stop 6

  req%matrix_head_above_cm=3.0_real64
  req%total_macropore_volume_top_cm=1.0_real64
  call evaluate_covering_layer_input(req,q,ok)
  if(ok) error stop 7

  write(*,'(a)') 'PPA_WU05_MIGMAC01_COVERING_LAYER_OPERATOR=PASS'
end program test_ppa_wu05_migmac01_covering_layer

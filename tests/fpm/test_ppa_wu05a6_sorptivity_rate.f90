program test_ppa_wu05a6_sorptivity_rate
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_sorptivity_rate, only: sorptivity_rate_request_t, &
       sorptivity_rate_result_t, evaluate_sorptivity_rate
  implicit none

  type(sorptivity_rate_request_t) :: request
  type(sorptivity_rate_result_t) :: result
  integer, parameter :: nd=2,n=4

  request%num_domains=nd
  request%num_nodes=n
  request%top_node=1
  request%swmbf=1
  request%matrix_top_saturated_node=5
  request%step_duration=0.1_real64
  request%flow_reduction=1.0_real64

  allocate(request%bottom_domain(nd),request%top_water_node(nd),request%theta(n),request%theta_s(n), &
       request%theta_r(n),request%dz(n),request%diameter(n),request%wall_correction(n), &
       request%sorptivity_max(n),request%sorptivity_alpha(n),request%domain_fraction(nd,n), &
       request%wet_fraction(nd,n),request%history_sorptivity(nd,n),request%history_theta_ref(nd,n), &
       request%history_absorption_time(nd,n))

  request%bottom_domain=[4,3]
  request%top_water_node=[1,1]
  request%theta=0.16_real64
  request%theta_s=0.45_real64
  request%theta_r=0.05_real64
  request%dz=10.0_real64
  request%diameter=4.0_real64
  request%wall_correction=0.95_real64
  request%sorptivity_max=0.5_real64
  request%sorptivity_alpha=0.5_real64
  request%domain_fraction(1,:)=[0.2_real64,0.3_real64,0.5_real64,1.0_real64]
  request%domain_fraction(2,:)=[0.8_real64,0.7_real64,0.5_real64,0.0_real64]
  request%wet_fraction=1.0_real64
  request%history_sorptivity=0.0_real64
  request%history_theta_ref=0.0_real64
  request%history_absorption_time=0.0_real64

  call evaluate_sorptivity_rate(request,result)
  if(.not.result%valid) error stop 'A6 sorptivity fresh invalid'
  if(abs(result%amount_cm(1,1)-0.25579532833888896_real64)>1.0e-12_real64) &
       error stop 'A6 sorptivity fresh oracle'
  if(result%end_event(1,1)) error stop 'A6 sorptivity fresh event flag'

  request%history_absorption_time(1,1)=0.5_real64
  request%history_theta_ref(1,1)=0.47_real64
  request%history_sorptivity(1,1)=0.42_real64
  call evaluate_sorptivity_rate(request,result)
  if(abs(result%amount_cm(1,1)-0.05644339970236335_real64)>1.0e-12_real64) &
       error stop 'A6 sorptivity aged oracle'

  request%history_absorption_time=0.0_real64
  request%history_theta_ref=0.0_real64
  request%history_sorptivity=0.0_real64
  request%wet_fraction(2,1)=0.5_real64
  call evaluate_sorptivity_rate(request,result)
  if(abs(result%amount_cm(2,1)-0.5_real64*4.0_real64*result%amount_cm(1,1))>1.0e-10_real64) &
       error stop 'A6 sorptivity interface wet fraction'

  request%theta(1)=request%theta_s(1)-1.0e-9_real64
  call evaluate_sorptivity_rate(request,result)
  if(abs(result%amount_cm(1,1))>1.0e-15_real64) error stop 'A6 sorptivity wet matrix'

  request%theta=0.16_real64
  request%sorptivity_max(1)=1.0e9_real64
  call evaluate_sorptivity_rate(request,result)
  if(abs(result%amount_cm(1,1)-1000.0_real64)>1.0e-10_real64) &
       error stop 'A6 sorptivity peak cap'

  print '(a)', 'PPA_WU05A6_SORPTIVITY_RATE=PASS'
end program test_ppa_wu05a6_sorptivity_rate

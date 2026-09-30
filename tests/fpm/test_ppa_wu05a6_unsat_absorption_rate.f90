program test_ppa_wu05a6_unsat_absorption_rate
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_unsat_absorption_rate, only: unsat_absorption_request_t, &
       unsat_absorption_result_t, evaluate_unsat_absorption
  implicit none

  type(unsat_absorption_request_t) :: request
  type(unsat_absorption_result_t) :: result
  integer, parameter :: nd=1,n=3

  request%sorptivity%num_domains=nd
  request%sorptivity%num_nodes=n
  request%sorptivity%top_node=1
  request%sorptivity%swmbf=1
  request%sorptivity%matrix_top_saturated_node=4
  request%sorptivity%step_duration=0.1_real64
  request%sorptivity%flow_reduction=1.0_real64

  allocate(request%sorptivity%bottom_domain(nd),request%sorptivity%top_water_node(nd), &
       request%sorptivity%theta(n),request%sorptivity%theta_s(n),request%sorptivity%theta_r(n), &
       request%sorptivity%dz(n),request%sorptivity%diameter(n),request%sorptivity%wall_correction(n), &
       request%sorptivity%sorptivity_max(n),request%sorptivity%sorptivity_alpha(n), &
       request%sorptivity%domain_fraction(nd,n),request%sorptivity%wet_fraction(nd,n), &
       request%sorptivity%history_sorptivity(nd,n),request%sorptivity%history_theta_ref(nd,n), &
       request%sorptivity%history_absorption_time(nd,n),request%pressure_head(n),request%elevation(n), &
       request%conductivity(n),request%entry_head(n),request%groundwater_level_domain(nd), &
       request%sorp_fac_parallel(n))

  request%sorptivity%bottom_domain=3
  request%sorptivity%top_water_node=1
  request%sorptivity%theta=0.16_real64
  request%sorptivity%theta_s=0.45_real64
  request%sorptivity%theta_r=0.05_real64
  request%sorptivity%dz=10.0_real64
  request%sorptivity%diameter=4.0_real64
  request%sorptivity%wall_correction=0.95_real64
  request%sorptivity%sorptivity_max=0.5_real64
  request%sorptivity%sorptivity_alpha=0.5_real64
  request%sorptivity%domain_fraction=0.2_real64
  request%sorptivity%wet_fraction=1.0_real64
  request%sorptivity%history_sorptivity=0.0_real64
  request%sorptivity%history_theta_ref=0.0_real64
  request%sorptivity%history_absorption_time=0.0_real64

  request%shape_factor=1.0_real64
  request%pressure_head=-100.0_real64
  request%elevation=[-40.0_real64,-50.0_real64,-60.0_real64]
  request%conductivity=0.01_real64
  request%entry_head=-1.0_real64
  request%groundwater_level_domain=-20.0_real64
  request%sorp_fac_parallel=0.5_real64

  call evaluate_unsat_absorption(request,result)
  if(.not.result%valid) error stop 'A6 R1b strong invalid'
  if(.not.result%selected_by_sorptivity(1,2)) error stop 'A6 R1b strong should select sorptivity'
  if(abs(result%selected_amount_cm(1,2)-0.25579532833888896_real64)>1.0e-12_real64) &
       error stop 'A6 R1b sorptivity winner amount'
  if(result%end_event(1,2)) error stop 'A6 R1b sorptivity event flag'

  request%sorptivity%sorptivity_max=0.05_real64
  call evaluate_unsat_absorption(request,result)
  if(result%selected_by_sorptivity(1,2)) error stop 'A6 R1b weak should select Darcy'
  if(abs(result%selected_amount_cm(1,2)-0.07465449431073919_real64)>1.0e-12_real64) &
       error stop 'A6 R1b Darcy winner amount'
  if(.not.result%end_event(1,2)) error stop 'A6 R1b Darcy should end sorptivity event'

  request%sorptivity%flow_reduction=0.8_real64
  call evaluate_unsat_absorption(request,result)
  if(abs(result%selected_amount_cm(1,2)-0.8_real64*0.07465449431073919_real64)>1.0e-12_real64) &
       error stop 'A6 R1b flow reduction'

  request%pressure_head(2)=0.0_real64
  call evaluate_unsat_absorption(request,result)
  if(.not.result%selected_by_sorptivity(1,2)) error stop 'A6 R1b Darcy should disable above entry condition'

  print '(a)', 'PPA_WU05A6_UNSAT_ABSORPTION=PASS'
end program test_ppa_wu05a6_unsat_absorption_rate

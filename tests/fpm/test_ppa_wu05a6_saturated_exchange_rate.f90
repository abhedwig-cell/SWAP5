program test_ppa_wu05a6_saturated_exchange_rate
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t, &
       saturated_exchange_result_t, evaluate_saturated_exchange
  implicit none

  type(saturated_exchange_request_t)::request
  type(saturated_exchange_result_t)::result
  integer,parameter::nd=1,n=3

  request%num_domains=nd
  request%num_nodes=n
  request%matrix_top_saturated_node=1
  request%matrix_bottom_saturated_node=3
  request%swsep=0
  request%matrix_level=5.0_real64
  request%step_duration=0.1_real64
  request%flow_reduction=1.0_real64
  request%shape_factor=1.0_real64

  allocate(request%bottom_domain(nd),request%top_macro_saturated_node(nd), &
       request%macro_saturated_fraction(nd),request%macro_reference_level(nd),request%z(n), &
       request%dz(n),request%matrix_head(n),request%ksat_horizontal(n),request%diameter(n), &
       request%domain_fraction(nd,n),request%cdarcy(nd,n))

  request%bottom_domain=3
  request%top_macro_saturated_node=1
  request%macro_saturated_fraction=1.0_real64
  request%macro_reference_level=10.0_real64
  request%z=[0.0_real64,0.0_real64,10.0_real64]
  request%dz=10.0_real64
  request%matrix_head=[2.0_real64,20.0_real64,5.0_real64]
  request%ksat_horizontal=0.1_real64
  request%diameter=4.0_real64
  request%domain_fraction=0.2_real64
  request%cdarcy=0.01_real64

  call evaluate_saturated_exchange(request,result)
  if(.not.result%valid)error stop 'A6 SATFLOW invalid'
  if(abs(result%macro_to_matrix_amount_cm(1,1)-0.008_real64)>1.0e-12_real64) &
       error stop 'A6 SATFLOW macro to matrix'
  if(abs(result%matrix_to_macro_amount_cm(1,2)-0.010_real64)>1.0e-12_real64) &
       error stop 'A6 SATFLOW matrix to macro Darcy'
  if(abs(result%matrix_to_macro_amount_cm(1,3)-0.5_real64)>1.0e-12_real64) &
       error stop 'A6 SATFLOW seepage Youngs'
  if(abs(result%qexc_to_matrix_rate_cm_per_day(1,1)-0.08_real64)>1.0e-12_real64) &
       error stop 'A6 SATFLOW qexc sign out'
  if(abs(result%qexc_to_matrix_rate_cm_per_day(1,2)+0.10_real64)>1.0e-12_real64) &
       error stop 'A6 SATFLOW qexc sign in'

  request%matrix_head(1)=-2.0_real64
  call evaluate_saturated_exchange(request,result)
  if(abs(result%signed_matrix_to_macro_amount_cm(1,1))>1.0e-15_real64) &
       error stop 'A6 SATFLOW negative matrix head should disable'

  print '(a)', 'PPA_WU05A6_SATURATED_EXCHANGE=PASS'
end program test_ppa_wu05a6_saturated_exchange_rate

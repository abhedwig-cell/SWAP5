program test_ppa_wu05a6_top_inflow_limiter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_top_inflow_limiter, only: standard_inflow_limit_request_t, &
       standard_inflow_limit_result_t, evaluate_standard_inflow_limit
  implicit none

  type(standard_inflow_limit_request_t)::request
  type(standard_inflow_limit_result_t)::result
  integer,parameter::nd=3

  request%num_domains=nd
  allocate(request%accepted_storage_cm(nd),request%maximum_storage_cm(nd),request%minimum_storage_cm(nd), &
       request%potential_top_vertical_cm(nd),request%potential_top_lateral_cm(nd), &
       request%potential_interflow_sat_cm(nd),request%potential_matrix_sat_cm(nd), &
       request%potential_outflow_cm(nd),request%redistribution_capacity_cm(nd), &
       request%top_domain_fraction(nd))

  request%accepted_storage_cm=[0.18_real64,0.10_real64,0.02_real64]
  request%maximum_storage_cm=[0.20_real64,0.30_real64,0.30_real64]
  request%minimum_storage_cm=[0.00_real64,0.12_real64,0.00_real64]
  request%potential_top_vertical_cm=[0.10_real64,0.06_real64,0.04_real64]
  request%potential_top_lateral_cm=[0.05_real64,0.03_real64,0.02_real64]
  request%potential_interflow_sat_cm=[0.02_real64,0.01_real64,0.00_real64]
  request%potential_matrix_sat_cm=[0.03_real64,0.02_real64,0.01_real64]
  request%potential_outflow_cm=[0.01_real64,0.02_real64,0.01_real64]
  request%redistribution_capacity_cm=[0.0_real64,0.08_real64,0.20_real64]
  request%top_domain_fraction=[0.2_real64,0.3_real64,0.5_real64]

  call evaluate_standard_inflow_limit(request,result)
  if(.not.result%valid)error stop 'A6 R5 limiter invalid'

  ! Domain 1: WaTmp=0.37, max=0.20, total inflow=0.20 -> FrIn=0.15.
  if(abs(result%inflow_fraction(1)-0.15_real64)>1.0e-12_real64) &
       error stop 'A6 R5 domain1 inflow fraction'
  if(abs(result%accepted_interflow_sat_cm(1)-0.003_real64)>1.0e-12_real64) &
       error stop 'A6 R5 interflow scaled with common factor'
  if(abs(result%accepted_matrix_sat_cm(1)-0.0045_real64)>1.0e-12_real64) &
       error stop 'A6 R5 matrix saturated scaled with common factor'

  if(result%redistributed_total_cm<=0.0_real64)error stop 'A6 R5 no redistribution'
  if(abs(result%top_receipt_residual_cm)>1.0e-12_real64)error stop 'A6 R5 top receipt residual'
  if(result%returned_surface_cm<0.0_real64)error stop 'A6 R5 returned surface negative'
  if(any(result%outflow_fraction<0.0_real64) .or. any(result%outflow_fraction>1.0_real64)) &
       error stop 'A6 R5 outflow fraction bounds'

  ! No-capacity case returns rejected top to surface.
  request%redistribution_capacity_cm=0.0_real64
  call evaluate_standard_inflow_limit(request,result)
  if(.not.result%valid)error stop 'A6 R5 no capacity invalid'
  if(abs(result%returned_surface_cm-result%rejected_top_before_redistribution_cm)>1.0e-12_real64) &
       error stop 'A6 R5 returned rejected top'

  ! Explicit outflow-excess case: storage+in-out falls below minimum.
  request%accepted_storage_cm=[0.10_real64,0.05_real64,0.10_real64]
  request%minimum_storage_cm=[0.08_real64,0.10_real64,0.08_real64]
  request%maximum_storage_cm=[0.30_real64,0.30_real64,0.30_real64]
  request%potential_top_vertical_cm=0.0_real64
  request%potential_top_lateral_cm=0.0_real64
  request%potential_interflow_sat_cm=0.0_real64
  request%potential_matrix_sat_cm=0.0_real64
  request%potential_outflow_cm=[0.05_real64,0.10_real64,0.05_real64]
  request%redistribution_capacity_cm=0.0_real64
  call evaluate_standard_inflow_limit(request,result)
  if(.not.result%valid)error stop 'A6 R5 outflow limiter invalid'
  if(abs(result%outflow_fraction(2)-0.5_real64)>1.0e-12_real64) &
       error stop 'A6 R5 outflow fraction source rule'

  print '(a)', 'PPA_WU05A6_TOP_INFLOW_LIMITER=PASS'
end program test_ppa_wu05a6_top_inflow_limiter

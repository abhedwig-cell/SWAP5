program test_ppa_wu05a6_vertical_flux_reconstruction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_vertical_flux_reconstruction, only: vertical_flux_reconstruction_request_t, &
       vertical_flux_reconstruction_result_t, reconstruct_vertical_flux
  implicit none

  type(vertical_flux_reconstruction_request_t)::request
  type(vertical_flux_reconstruction_result_t)::result
  integer,parameter::nd=2,n=4
  real(real64)::domain_balance

  request%num_domains=nd
  request%num_nodes=n
  request%top_node=1
  request%step_duration=0.1_real64
  allocate(request%bottom_domain(nd),request%top_inflow_rate(nd),request%previous_water_cm(nd,n), &
       request%current_water_cm(nd,n),request%exchange_to_matrix_rate(nd,n), &
       request%external_outflow_rate(nd,n))

  request%bottom_domain=[4,3]
  request%top_inflow_rate=[0.60_real64,0.20_real64]
  request%previous_water_cm=0.0_real64
  request%current_water_cm=0.0_real64
  request%exchange_to_matrix_rate=0.0_real64
  request%external_outflow_rate=0.0_real64

  request%previous_water_cm(1,:)=[0.0_real64,0.0_real64,0.20_real64,0.27_real64]
  request%current_water_cm(1,:)=[0.0_real64,0.01_real64,0.24_real64,0.27_real64]
  request%exchange_to_matrix_rate(1,:)=[0.01_real64,0.02_real64,0.03_real64,0.04_real64]
  request%external_outflow_rate(1,4)=0.05_real64

  request%previous_water_cm(2,1:3)=[0.05_real64,0.10_real64,0.15_real64]
  request%current_water_cm(2,1:3)=[0.055_real64,0.105_real64,0.15_real64]
  request%exchange_to_matrix_rate(2,1:3)=[0.01_real64,-0.02_real64,0.00_real64]

  call reconstruct_vertical_flux(request,result)
  if(.not.result%valid)error stop 'A6 R6 reconstruction invalid'
  if(result%max_local_residual_rate>1.0e-12_real64)error stop 'A6 R6 local residual'

  domain_balance=(sum(request%current_water_cm(1,:))-sum(request%previous_water_cm(1,:))) / &
       request%step_duration
  if(abs(domain_balance - (request%top_inflow_rate(1)-result%vertical_face_rate(1,5) - &
       sum(request%exchange_to_matrix_rate(1,:))-sum(request%external_outflow_rate(1,:))))>1.0e-12_real64) &
       error stop 'A6 R6 whole domain balance'

  if(abs(result%local_residual_rate(1,2))>1.0e-12_real64 .or. &
     abs(result%local_residual_rate(1,3))>1.0e-12_real64) &
       error stop 'A6 R6 moving interface local balance'

  request%external_outflow_rate(1,4)=0.0_real64
  call reconstruct_vertical_flux(request,result)
  if(result%max_local_residual_rate>1.0e-12_real64)error stop 'A6 R6 no-external residual'

  print '(a)', 'PPA_WU05A6_VERTICAL_FLUX_RECONSTRUCTION=PASS'
end program test_ppa_wu05a6_vertical_flux_reconstruction

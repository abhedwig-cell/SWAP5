program test_swap431_root_oxygen_repro_response
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_root_oxygen_reproduction_response
  implicit none
  type(root_oxygen_reproduction_parameters_t)::p
  real(real64)::theta(2),thetas(2),tsoil(2),z(2),zbot(2),dz(2),factor
  integer::status
  real(real64),parameter::tol=1.0e-12_real64
  theta=[0.30_real64,0.25_real64];thetas=[0.40_real64,0.40_real64]
  tsoil=[10.0_real64,12.0_real64];z=[-5.0_real64,-15.0_real64]
  zbot=[-10.0_real64,-20.0_real64];dz=10.0_real64
  p%intercept=0.0_real64;p%slope=0.0_real64;p%intercept(6)=0.2_real64;p%slope(6)=2.0_real64
  p%saturated_water_content=thetas;p%z_cm=z;p%zbotcp_cm=zbot;p%dz_cm=dz
  call evaluate_root_oxygen_reproduction_factor(p,theta,tsoil,2,factor,status)
  if(status/=ROOT_OXYGEN_REPRO_OK.or.abs(factor-0.45_real64)>tol)error stop 1
  theta(2)=0.45_real64
  call evaluate_root_oxygen_reproduction_factor(p,theta,tsoil,2,factor,status)
  if(status/=ROOT_OXYGEN_REPRO_OK.or.abs(factor)>tol)error stop 2
  theta(2)=0.25_real64;p%intercept(6)=2.0_real64;p%slope(6)=0.0_real64
  call evaluate_root_oxygen_reproduction_factor(p,theta,tsoil,1,factor,status)
  if(status/=ROOT_OXYGEN_REPRO_OK.or.abs(factor-1.0_real64)>tol)error stop 3
  p%intercept(6)=-1.0_real64
  call evaluate_root_oxygen_reproduction_factor(p,theta,tsoil,1,factor,status)
  if(status/=ROOT_OXYGEN_REPRO_OK.or.abs(factor)>tol)error stop 4
  print '(a)','SW431_ROOT_OXYGEN_REPRO_RESPONSE=PASS'
end program

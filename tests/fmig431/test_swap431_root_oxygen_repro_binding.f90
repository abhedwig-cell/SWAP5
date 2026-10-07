program test_swap431_root_oxygen_repro_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_bartholomeus_contract
  implicit none
  type(fmr_bartholomeus_parameters_t)::p
  real(real64)::cofgen(7,3),z(3),dz(3),slope(6),intercept(6)
  integer::status

  cofgen=0.0_real64
  cofgen(2,:)=[0.40_real64,0.42_real64,0.44_real64]
  z=[-5.0_real64,-15.0_real64,-30.0_real64]
  dz=[10.0_real64,10.0_real64,20.0_real64]
  slope=[0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,2.0_real64]
  intercept=[0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.2_real64]

  call construct_fmr_reproduction_oxygen_parameters(slope,intercept,cofgen,z,dz,p,status)
  if(status/=FMR_REPRO_BIND_OK)error stop 1
  if(.not.allocated(p%reproduction))error stop 2
  if(.not.valid_fmr_bartholomeus_parameters(p,3))error stop 3
  if(.not.matches_reproduction_hydraulic_owner(p,cofgen,z,dz))error stop 4
  if(any(abs(p%reproduction%zbotcp_cm-[-10.0_real64,-20.0_real64,-40.0_real64])>1e-12_real64))error stop 5

  dz(2)=0.0_real64
  call construct_fmr_reproduction_oxygen_parameters(slope,intercept,cofgen,z,dz,p,status)
  if(status/=FMR_REPRO_BIND_INVALID_INPUT.or.allocated(p%reproduction))error stop 6

  dz=[10.0_real64,10.0_real64,20.0_real64]
  cofgen(2,2)=1.2_real64
  call construct_fmr_reproduction_oxygen_parameters(slope,intercept,cofgen,z,dz,p,status)
  if(status/=FMR_REPRO_BIND_INVALID_INPUT.or.allocated(p%reproduction))error stop 7

  print '(a)','SW431_ROOT_OXYGEN_REPRO_BINDING=PASS'
end program

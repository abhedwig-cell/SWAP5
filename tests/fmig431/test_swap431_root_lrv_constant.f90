program test_swap431_root_lrv_constant
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_crop_root_length_density_constant
  implicit none
  type(wofost_rate_table_t) :: table, floor_table
  real(real64), allocatable :: lrv(:)
  real(real64) :: z(4)
  integer :: status

  z=[-5.0_real64,-15.0_real64,-25.0_real64,-35.0_real64]
  call construct_wofost_rate_table([0.0_real64,0.5_real64,1.0_real64], &
       [0.0_real64,0.04_real64,0.0_real64],table,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 1
  call evaluate_constant_absolute_root_length_density(table,z,2,-20.0_real64,lrv,status)
  if(status/=ROOT_LRV_CONSTANT_OK)error stop 2
  if(maxval(abs(lrv-[0.02_real64,0.02_real64,0.0_real64,0.0_real64]))>1.0e-12_real64)error stop 3

  call construct_wofost_rate_table([0.0_real64,1.0_real64],[0.0_real64,0.0_real64],floor_table,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 4
  call evaluate_constant_absolute_root_length_density(floor_table,z,2,-20.0_real64,lrv,status)
  if(status/=ROOT_LRV_CONSTANT_OK)error stop 5
  if(any(abs(lrv(1:2)-ROOT_LRV_CONSTANT_FLOOR)>1.0e-12_real64))error stop 6
  if(any(lrv(3:4)/=0.0_real64))error stop 7

  call evaluate_constant_absolute_root_length_density(table,z,0,-20.0_real64,lrv,status)
  if(status/=ROOT_LRV_CONSTANT_OK.or.any(lrv/=0.0_real64))error stop 8
  print '(a)','SW431_ROOT_LRV_CONSTANT_COMPONENT=PASS'
end program

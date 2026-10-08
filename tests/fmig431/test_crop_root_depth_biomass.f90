program test_crop_root_depth_biomass
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_crop_root_depth_biomass
  implicit none
  type(wofost_rate_table_t) :: table
  integer :: status
  real(real64) :: depth

  call construct_wofost_rate_table([0.0_real64,100.0_real64,300.0_real64], &
       [10.0_real64,30.0_real64,90.0_real64],table,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 1

  call evaluate_crop_root_depth_biomass(table,50.0_real64,80.0_real64,depth,status)
  if(status/=CROP_ROOT_DEPTH_BIOMASS_OK.or.abs(depth-20.0_real64)>1.0e-12_real64)error stop 2

  call evaluate_crop_root_depth_biomass(table,300.0_real64,80.0_real64,depth,status)
  if(status/=CROP_ROOT_DEPTH_BIOMASS_OK.or.abs(depth-80.0_real64)>1.0e-12_real64)error stop 3

  call evaluate_crop_root_depth_biomass(table,500.0_real64,100.0_real64,depth,status)
  if(status/=CROP_ROOT_DEPTH_BIOMASS_OK.or.abs(depth-90.0_real64)>1.0e-12_real64)error stop 4

  print '(a)','SW431_CROP_ROOTGROW_BIOMASS_COMPONENT=PASS'
end program

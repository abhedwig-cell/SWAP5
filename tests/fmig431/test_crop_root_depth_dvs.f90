program test_crop_root_depth_dvs
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_crop_root_depth_dvs
  implicit none
  type(wofost_rate_table_t) :: table
  integer :: status
  real(real64) :: depth

  call construct_wofost_rate_table([0.0_real64,1.0_real64,2.0_real64], &
       [10.0_real64,40.0_real64,100.0_real64],table,status)
  if (status /= WOFOST_RATE_TABLE_OK) error stop 1

  call evaluate_crop_root_depth_dvs(table,0.5_real64,80.0_real64,depth,status)
  if (status /= CROP_ROOT_DEPTH_DVS_OK .or. abs(depth-25.0_real64)>1.0e-12_real64) error stop 2

  call evaluate_crop_root_depth_dvs(table,2.0_real64,80.0_real64,depth,status)
  if (status /= CROP_ROOT_DEPTH_DVS_OK .or. abs(depth-80.0_real64)>1.0e-12_real64) error stop 3

  call evaluate_crop_root_depth_dvs(table,-1.0_real64,80.0_real64,depth,status)
  if (status /= CROP_ROOT_DEPTH_DVS_OK .or. abs(depth-10.0_real64)>1.0e-12_real64) error stop 4

  print '(a)','SW431_CROP_ROOTGROW_DVS_COMPONENT=PASS'
end program test_crop_root_depth_dvs

program test_crop_b111_pressure_head_average
  use iso_fortran_env, only: real64
  use mod_crop_b111_pressure_head_average
  implicit none
  real(real64) :: avg
  integer :: status
  call compute_b111_pressure_head_average(-15.0_real64,[10.0_real64,20.0_real64], &
       [-100.0_real64,-1000.0_real64],avg,status)
  if(status/=CROP_HAVG_OK) error stop 1
  if(abs(avg+10.0_real64**(7.0_real64/3.0_real64))>1.0e-10_real64) error stop 2
  call compute_b111_pressure_head_average(0.0_real64,[10.0_real64],[-0.5_real64],avg,status)
  if(status/=CROP_HAVG_OK.or.abs(avg+1.0_real64)>1.0e-12_real64) error stop 3
  call compute_b111_pressure_head_average(-40.0_real64,[10.0_real64,20.0_real64], &
       [-100.0_real64,-1000.0_real64],avg,status)
  if(status/=CROP_HAVG_INVALID) error stop 4
  call compute_b111_pressure_head_average(-0.5e-6_real64,[10.0_real64],[-100.0_real64],avg,status)
  if(status/=CROP_HAVG_OK.or.abs(avg+100.0_real64)>1.0e-11_real64) error stop 5
  call compute_b111_pressure_head_average(-1.0e-6_real64,[10.0_real64],[-100.0_real64],avg,status)
  if(status/=CROP_HAVG_OK.or.abs(avg+100.0_real64)>1.0e-11_real64) error stop 6
  call compute_b111_pressure_head_average(-10.0_real64,[10.0_real64,20.0_real64], &
       [-100.0_real64,-1000.0_real64],avg,status)
  if(status/=CROP_HAVG_OK.or.abs(avg+100.0_real64)>1.0e-11_real64) error stop 7
  print '(a)','CROP_HAVG_B111=PASS'
end program

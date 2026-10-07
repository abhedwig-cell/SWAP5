program test_mc_irr01_availability_scaling
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_availability_scaling
  implicit none
  type(irrigation_availability_result_t) :: y
  integer :: st
  real(real64), parameter :: tol=1.0e-12_real64

  call apply_legacy_irrigation_availability(0.48_real64,0.25_real64,0.48_real64,0.5_real64,y,st)
  if(st/=IRR_AVAIL_OK) error stop 1
  if(abs(y%scaled_rate_cm_per_day-0.24_real64)>tol) error stop 2
  if(abs(y%scaled_duration_day-0.125_real64)>tol) error stop 3
  if(abs(y%delivered_amount_cm-0.03_real64)>tol) error stop 4

  ! With positive configured IRR_RATE both rate and duration are scaled,
  ! so delivered volume scales with F_IRR_AVAIL squared.
  if(abs(y%delivered_amount_cm-(0.48_real64*0.25_real64*0.25_real64))>tol) error stop 5

  call apply_legacy_irrigation_availability(0.12_real64,1.0_real64,0.0_real64,0.5_real64,y,st)
  if(st/=IRR_AVAIL_OK) error stop 6
  if(abs(y%scaled_rate_cm_per_day-0.06_real64)>tol) error stop 7
  if(abs(y%scaled_duration_day-1.0_real64)>tol) error stop 8
  if(abs(y%delivered_amount_cm-0.06_real64)>tol) error stop 9

  call apply_legacy_irrigation_availability(0.48_real64,0.25_real64,0.48_real64,-0.1_real64,y,st)
  if(st/=IRR_AVAIL_INVALID) error stop 10

  print '(A)','MC_IRR01_AVAIL_LITERAL_SCALING=PASS'
  print '(A)','MC_IRR01_AVAIL_POSITIVE_RATE_QUADRATIC_VOLUME=PASS'
  print '(A)','MC_IRR01_AVAIL_ZERO_RATE_LINEAR_VOLUME=PASS'
end program test_mc_irr01_availability_scaling

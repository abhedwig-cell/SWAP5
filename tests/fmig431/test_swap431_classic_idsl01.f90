program test_swap431_classic_idsl01
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_wofost_classic_phenology_rate
  implicit none
  real(real64) :: dvr, nanv
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64
  nanv=ieee_value(0.0_real64,ieee_quiet_nan)

  ! IDSL0 has no photoperiod dependency.
  call evaluate_wofost_classic_idsl01_rate(0,0.2_real64,10.0_real64,100.0_real64,200.0_real64, &
       nanv,nanv,nanv,dvr,status)
  if(status/=WOFOST_CLASSIC_PHENOLOGY_OK.or.abs(dvr-0.1_real64)>tol) error stop 1

  ! IDSL1 exact clamp boundaries and interior.
  call evaluate_wofost_classic_idsl01_rate(1,0.2_real64,10.0_real64,100.0_real64,200.0_real64, &
       8.0_real64,8.0_real64,12.0_real64,dvr,status)
  if(status/=WOFOST_CLASSIC_PHENOLOGY_OK.or.abs(dvr)>tol) error stop 2

  call evaluate_wofost_classic_idsl01_rate(1,0.2_real64,10.0_real64,100.0_real64,200.0_real64, &
       10.0_real64,8.0_real64,12.0_real64,dvr,status)
  if(status/=WOFOST_CLASSIC_PHENOLOGY_OK.or.abs(dvr-0.05_real64)>tol) error stop 3

  call evaluate_wofost_classic_idsl01_rate(1,0.2_real64,10.0_real64,100.0_real64,200.0_real64, &
       12.0_real64,8.0_real64,12.0_real64,dvr,status)
  if(status/=WOFOST_CLASSIC_PHENOLOGY_OK.or.abs(dvr-0.1_real64)>tol) error stop 4

  call evaluate_wofost_classic_idsl01_rate(1,0.2_real64,10.0_real64,100.0_real64,200.0_real64, &
       16.0_real64,8.0_real64,12.0_real64,dvr,status)
  if(status/=WOFOST_CLASSIC_PHENOLOGY_OK.or.abs(dvr-0.1_real64)>tol) error stop 5

  ! Generative phase is TSUMAM-only in pinned source.
  call evaluate_wofost_classic_idsl01_rate(1,1.2_real64,10.0_real64,100.0_real64,200.0_real64, &
       8.0_real64,8.0_real64,12.0_real64,dvr,status)
  if(status/=WOFOST_CLASSIC_PHENOLOGY_OK.or.abs(dvr-0.05_real64)>tol) error stop 6

  print '(a)','SW431_CROP_CLASSIC_IDSL01=PASS'
end program

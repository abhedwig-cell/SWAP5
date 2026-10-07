program test_swap431_grass_phenology
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_grass_phenology
  implicit none
  type(grass_phenology_parameters_t) :: p
  type(grass_phenology_state_t) :: s
  type(grass_phenology_daily_result_t) :: r
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  ! SWTSUM=0: development always enabled, DTSUM=max(0,TAV), DVR=2/366.
  p%temperature_sum_mode=GRASS_TSUM_ALWAYS
  call evaluate_grass_phenology_day(p,s,0.0_real64,-3.0_real64,0.0_real64,r,status)
  if(status/=GRASS_PHENOLOGY_OK.or..not.r%development_enabled) error stop 1
  if(abs(r%temperature_sum_increment)>tol) error stop 2
  if(abs(r%development_rate-2.0_real64/366.0_real64)>tol) error stop 3

  ! SWTSUM=1: source threshold is TSUM + today's DTSUM >= 200.
  p%temperature_sum_mode=GRASS_TSUM_AIR_THRESHOLD
  call evaluate_grass_phenology_day(p,s,190.0_real64,9.0_real64,0.0_real64,r,status)
  if(status/=GRASS_PHENOLOGY_OK.or.r%development_enabled) error stop 4
  call evaluate_grass_phenology_day(p,s,190.0_real64,10.0_real64,0.0_real64,r,status)
  if(status/=GRASS_PHENOLOGY_OK.or..not.r%development_enabled) error stop 5

  ! SWTSUM=2: qualifying warm-soil days accumulate and are not reset by a cold day.
  p%temperature_sum_mode=GRASS_TSUM_SOIL_PERSISTENCE
  p%soil_temperature_threshold_c=5.0_real64
  p%soil_temperature_days_required=2
  s%qualifying_soil_temperature_days=0
  call evaluate_grass_phenology_day(p,s,0.0_real64,8.0_real64,5.0_real64,r,status)
  if(status/=GRASS_PHENOLOGY_OK.or.r%development_enabled) error stop 6
  if(r%candidate_state%qualifying_soil_temperature_days/=1) error stop 7
  s=r%candidate_state
  call evaluate_grass_phenology_day(p,s,8.0_real64,8.0_real64,4.9_real64,r,status)
  if(status/=GRASS_PHENOLOGY_OK.or.r%development_enabled) error stop 8
  if(r%candidate_state%qualifying_soil_temperature_days/=1) error stop 9
  s=r%candidate_state
  call evaluate_grass_phenology_day(p,s,16.0_real64,8.0_real64,6.0_real64,r,status)
  if(status/=GRASS_PHENOLOGY_OK.or..not.r%development_enabled) error stop 10
  if(r%candidate_state%qualifying_soil_temperature_days/=2) error stop 11

  print '(a)','SW431_CROP_GRASS_PHENOLOGY=PASS'
end program

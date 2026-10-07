program test_swap431_fixed_crop_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_fixed_crop_owner
  implicit none

  type(fixed_crop_parameters_t) :: p
  type(fixed_crop_owner_state_t) :: s,c
  type(fixed_crop_daily_forcing_t) :: f
  type(fixed_crop_daily_diagnostics_t) :: d
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  call construct_wofost_rate_table([0.0_real64,1.0_real64,2.0_real64], &
       [0.5_real64,3.0_real64,0.0_real64],p%leaf_area_by_dvs,status)
  if(status/=WOFOST_RATE_TABLE_OK) error stop 1
  call construct_wofost_rate_table([0.0_real64,1.0_real64,2.0_real64], &
       [10.0_real64,30.0_real64,5.0_real64],p%root_biomass_by_dvs,status)
  if(status/=WOFOST_RATE_TABLE_OK) error stop 2
  p%root_biomass_enabled=.true.

  ! IDEV=1: hydrologically relevant DVS/LAI/WRT are defined. Pinned B1.11
  ! leaves TBASE unassigned, so TSUM itself is deliberately not fabricated.
  p%development_mode=FIXED_CROP_IDEV_CALENDAR
  p%lifecycle_days=10
  call initialize_fixed_crop_owner(p,.true.,s,status)
  if(status/=FIXED_CROP_OK) error stop 3
  f%average_temperature_c=20.0_real64
  call evaluate_fixed_crop_daily_candidate(p,s,f,c,d,status)
  if(status/=FIXED_CROP_OK.or..not.d%candidate_built) error stop 4
  if(abs(c%development_stage-0.2_real64)>tol) error stop 5
  if(abs(c%temperature_sum)>tol.or.d%temperature_sum_source_defined) error stop 6
  if(abs(d%development_increment-0.2_real64)>tol.or.abs(d%temperature_sum_increment)>tol) error stop 7
  if(abs(c%leaf_area_index-1.0_real64)>tol) error stop 8
  if(abs(c%root_biomass-14.0_real64)>tol.or.abs(d%root_growth-4.0_real64)>tol) error stop 9

  ! IDEV=2 pre-anthesis.
  p%development_mode=FIXED_CROP_IDEV_THERMAL
  p%base_temperature_c=5.0_real64
  p%temperature_sum_emergence_to_anthesis=100.0_real64
  p%temperature_sum_anthesis_to_maturity=200.0_real64
  call initialize_fixed_crop_owner(p,.true.,s,status)
  if(status/=FIXED_CROP_OK) error stop 10
  f%average_temperature_c=15.0_real64
  call evaluate_fixed_crop_daily_candidate(p,s,f,c,d,status)
  if(status/=FIXED_CROP_OK.or.abs(c%development_stage-0.1_real64)>tol) error stop 11
  if(abs(c%temperature_sum-10.0_real64)>tol.or..not.d%temperature_sum_source_defined) error stop 12

  ! IDEV=2 generative branch uses TSUMAM.
  s=c
  s%development_stage=1.2_real64
  s%temperature_sum=100.0_real64
  call evaluate_fixed_crop_daily_candidate(p,s,f,c,d,status)
  if(status/=FIXED_CROP_OK.or.abs(d%development_increment-0.05_real64)>tol) error stop 13
  if(abs(c%development_stage-1.25_real64)>tol.or.abs(c%temperature_sum-110.0_real64)>tol) error stop 14

  ! Inactive owner is a strict no-op.
  s%crop_emerged=.false.
  call evaluate_fixed_crop_daily_candidate(p,s,f,c,d,status)
  if(status/=FIXED_CROP_OK.or..not.d%candidate_built) error stop 15
  if(abs(c%development_stage-s%development_stage)>tol) error stop 16

  print '(a)','SW431_CROP_FIXED_OWNER=PASS'
end program

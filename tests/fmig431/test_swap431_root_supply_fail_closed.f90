program test_swap431_root_supply_fail_closed
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_root_depth_rate_owner
  use mod_crop_adaptive_root_profile_owner
  use mod_fmr_root_depth_supply_composition
  implicit none
  type(crop_root_depth_rate_parameters_t) :: p
  type(fmr_root_supply_parameters_t) :: sp
  type(crop_root_depth_rate_state_t) :: committed, candidate
  type(crop_root_depth_rate_daily_forcing_t) :: forcing
  type(adaptive_root_profile_state_t) :: profile
  type(fmr_root_supply_diagnostics_t) :: diagnostics
  integer :: status
  real(real64), parameter :: tol=1.e-12_real64

  p%initial_root_depth_cm=20._real64
  p%maximum_root_depth_cm=100._real64
  p%maximum_daily_extension_cm=5._real64
  p%actual_extension_mode=CROP_ROOT_RATE_UNSCALED
  sp%minimum_extension_cm=1._real64
  sp%drought_extension_threshold=0.5_real64
  sp%negligible_extension_cm=0.01_real64
  committed%actual_root_depth_cm=20._real64
  committed%potential_root_depth_cm=20._real64
  profile%root_biomass_by_node=[5._real64,5._real64,5._real64]
  forcing%potential_transpiration=5._real64
  forcing%actual_root_uptake=4._real64
  forcing%actual_root_growth=3._real64
  forcing%potential_root_growth=4._real64
  forcing%rootzone_drought_uptake_factor_available=.false.

  call evaluate_swrd2_supply_limited_candidate(p,sp,committed,forcing,profile, &
       [0._real64,-10._real64,-20._real64],[-10._real64,-20._real64,-30._real64], &
       candidate,diagnostics,status)
  if(status/=FMR_ROOT_SUPPLY_MISSING_DROUGHT) error stop 1
  if(abs(candidate%actual_root_depth_cm-committed%actual_root_depth_cm)>tol) error stop 2
  if(abs(candidate%potential_root_depth_cm-committed%potential_root_depth_cm)>tol) error stop 3

  forcing%rootzone_drought_uptake_factor_available=.true.
  forcing%rootzone_drought_uptake_factor_integral=0.9_real64
  call evaluate_swrd2_supply_limited_candidate(p,sp,committed,forcing,profile, &
       [0._real64,-10._real64,-20._real64],[-10._real64,-20._real64,-30._real64], &
       candidate,diagnostics,status)
  if(status/=FMR_ROOT_SUPPLY_OK) error stop 4
  if(.not.diagnostics%supply_evaluated) error stop 5
  if(candidate%actual_root_depth_cm<=committed%actual_root_depth_cm) error stop 6
  if(candidate%potential_root_depth_cm<=committed%potential_root_depth_cm) error stop 7

  print '(a)','SW431_ROOT_SUPPLY_FAIL_CLOSED=PASS'
end program

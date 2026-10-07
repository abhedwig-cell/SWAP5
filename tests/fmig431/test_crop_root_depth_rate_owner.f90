program test_crop_root_depth_rate_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_crop_root_depth_rate_owner
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  implicit none

  type(crop_root_depth_rate_parameters_t) :: p
  type(crop_root_depth_rate_state_t) :: s0,s1,s2
  type(crop_root_depth_rate_daily_forcing_t) :: f
  type(crop_root_depth_rate_diagnostics_t) :: d1,d2
  type(wofost_rate_table_t) :: density
  type(crop_root_uptake_input_t) :: input
  class(transaction_state_t), allocatable :: copy
  real(real64) :: zbot(5)
  integer :: status
  logical :: available
  real(real64), parameter :: tol=1.0e-12_real64

  p%initial_root_depth_cm=10.0_real64
  p%maximum_root_depth_cm=40.0_real64
  p%maximum_daily_extension_cm=5.0_real64
  p%actual_extension_mode=CROP_ROOT_RATE_UNSCALED
  p%require_root_growth=.true.
  p%negligible_transpiration=1.0e-10_real64
  p%negligible_root_growth=1.0e-12_real64
  p%negligible_extension=1.0e-8_real64

  call initialize_crop_root_depth_rate_state(p,s0,status)
  if(status/=CROP_ROOT_RATE_OK)error stop 1
  if(abs(s0%actual_root_depth_cm-10.0_real64)>tol.or.abs(s0%potential_root_depth_cm-10.0_real64)>tol)error stop 2

  f%potential_transpiration=0.4_real64
  f%actual_root_uptake=0.2_real64
  f%actual_root_growth=2.0_real64
  f%potential_root_growth=3.0_real64
  call evaluate_crop_root_depth_rate_candidate(p,s0,f,s1,d1,status)
  if(status/=CROP_ROOT_RATE_OK.or..not.d1%candidate_built)error stop 3
  if(abs(s1%actual_root_depth_cm-15.0_real64)>tol.or.abs(s1%potential_root_depth_cm-15.0_real64)>tol)error stop 4

  ! Same committed checkpoint gives the same candidate.
  call evaluate_crop_root_depth_rate_candidate(p,s0,f,s2,d2,status)
  if(status/=CROP_ROOT_RATE_OK)error stop 5
  if(abs(s2%actual_root_depth_cm-s1%actual_root_depth_cm)>tol.or. &
     abs(s2%potential_root_depth_cm-s1%potential_root_depth_cm)>tol)error stop 6
  if(abs(s0%actual_root_depth_cm-10.0_real64)>tol)error stop 7

  ! SWDMI2RD=1 scales only actual extension by IQROT/IPTRA.
  p%actual_extension_mode=CROP_ROOT_RATE_WATER_SCALED
  call evaluate_crop_root_depth_rate_candidate(p,s0,f,s1,d1,status)
  if(status/=CROP_ROOT_RATE_OK)error stop 8
  if(abs(s1%potential_root_depth_cm-15.0_real64)>tol)error stop 9
  if(abs(s1%actual_root_depth_cm-12.5_real64)>tol)error stop 10
  if(abs(d1%water_scaling_factor-0.5_real64)>tol)error stop 11

  ! Zero transpiration blocks potential and actual extension before division.
  f%potential_transpiration=0.0_real64
  f%actual_root_uptake=0.0_real64
  call evaluate_crop_root_depth_rate_candidate(p,s0,f,s1,d1,status)
  if(status/=CROP_ROOT_RATE_OK)error stop 12
  if(abs(s1%actual_root_depth_cm-10.0_real64)>tol.or.abs(s1%potential_root_depth_cm-10.0_real64)>tol)error stop 13

  ! Root-growth supply gate blocks independently for actual and potential.
  f%potential_transpiration=0.4_real64
  f%actual_root_uptake=0.2_real64
  f%actual_root_growth=0.0_real64
  f%potential_root_growth=3.0_real64
  call evaluate_crop_root_depth_rate_candidate(p,s0,f,s1,d1,status)
  if(status/=CROP_ROOT_RATE_OK)error stop 14
  if(abs(s1%actual_root_depth_cm-10.0_real64)>tol.or.abs(s1%potential_root_depth_cm-15.0_real64)>tol)error stop 15

  ! Clone is the restart/checkpoint payload: exactly two continuation values.
  call s1%clone(copy)
  select type (typed => copy)
  type is (crop_root_depth_rate_state_t)
    if(abs(typed%actual_root_depth_cm-s1%actual_root_depth_cm)>tol.or. &
       abs(typed%potential_root_depth_cm-s1%potential_root_depth_cm)>tol)error stop 16
  class default
    error stop 17
  end select

  ! Actual accepted depth feeds the existing static root profile.
  call construct_wofost_rate_table([0.0_real64,0.5_real64,1.0_real64], &
       [2.0_real64,1.0_real64,0.0_real64],density,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 18
  zbot=[-10.0_real64,-20.0_real64,-30.0_real64,-40.0_real64,-50.0_real64]
  call s1%derive_root_uptake_input(density,40.0_real64,zbot,input,available,status)
  if(status/=CROP_ROOT_RATE_OK.or..not.available)error stop 19
  if(input%rooted_nodes/=1)error stop 20

  print '(a)','SW431_CROP_ROOTGROW_RATE_OWNER=PASS'
end program

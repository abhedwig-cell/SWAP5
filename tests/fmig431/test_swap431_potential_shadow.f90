program test_swap431_potential_shadow
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_crop_owner_state
  use mod_wofost_potential_shadow_state
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t
  implicit none

  type(wofost_crop_owner_state_t) :: actual, temp
  type(wofost_potential_shadow_state_t) :: shadow
  type(wofost_one_day_rate_state_view_t) :: view
  class(transaction_state_t), allocatable :: copy
  logical :: available
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  actual%crop_emerged=.true.
  actual%development_stage=0.4_real64
  allocate(actual%biomass,actual%evolution_continuation)
  actual%biomass%root_biomass=20.0_real64
  actual%biomass%stem_biomass=30.0_real64
  actual%biomass%storage_biomass=5.0_real64
  actual%biomass%exponential_leaf_area_index=2.0_real64
  actual%biomass%leaf_biomass=[10.0_real64]
  actual%biomass%specific_leaf_area=[0.02_real64]
  actual%biomass%leaf_age=[1.0_real64]
  actual%evolution_continuation%temperature_sum=100.0_real64
  actual%evolution_continuation%anthesis_reached=.false.
  if(actual%validate()/=WOFOST_CROP_OWNER_OK) error stop 1

  call initialize_wofost_potential_shadow_from_actual(actual,shadow,status)
  if(status/=WOFOST_POTENTIAL_SHADOW_OK.or..not.shadow%active) error stop 2
  if(abs(shadow%root_biomass()-20.0_real64)>tol) error stop 3

  ! Diverge potential biomass while shared phenology remains actual-owned.
  shadow%biomass%root_biomass=25.0_real64
  shadow%biomass%stem_biomass=40.0_real64
  call shadow%materialize_owner(actual,temp,available,status)
  if(status/=WOFOST_POTENTIAL_SHADOW_OK.or..not.available) error stop 4
  if(abs(temp%development_stage-actual%development_stage)>tol) error stop 5
  if(abs(temp%evolution_continuation%temperature_sum-actual%evolution_continuation%temperature_sum)>tol) error stop 6
  if(abs(temp%biomass%root_biomass-25.0_real64)>tol) error stop 7
  if(abs(actual%biomass%root_biomass-20.0_real64)>tol) error stop 8

  call shadow%assemble_rate_state_view(actual,0.01_real64,0.02_real64,view,available,status)
  if(status/=WOFOST_POTENTIAL_SHADOW_OK.or..not.available) error stop 9
  if(abs(view%development_stage-0.4_real64)>tol) error stop 10
  if(abs(view%actual_root_biomass-25.0_real64)>tol) error stop 11

  ! Absorbing an evolved temporary owner updates only shadow biomass/carryover.
  temp%development_stage=0.9_real64
  temp%biomass%root_biomass=27.0_real64
  call shadow%absorb_owner(temp,status)
  if(status/=WOFOST_POTENTIAL_SHADOW_OK) error stop 12
  if(abs(shadow%root_biomass()-27.0_real64)>tol) error stop 13
  if(abs(actual%development_stage-0.4_real64)>tol) error stop 14
  if(abs(actual%evolution_continuation%temperature_sum-100.0_real64)>tol) error stop 15

  call shadow%clone(copy)
  select type(t=>copy)
  type is(wofost_potential_shadow_state_t)
    if(.not.t%active) error stop 16
    if(abs(t%root_biomass()-27.0_real64)>tol) error stop 16
  class default
    error stop 17
  end select

  ! A transaction snapshot must own an independent biomass allocation.
  shadow%biomass%root_biomass=35.0_real64
  select type(t=>copy)
  type is(wofost_potential_shadow_state_t)
    if(abs(t%root_biomass()-27.0_real64)>tol) error stop 18
  class default
    error stop 19
  end select
  if(abs(actual%biomass%root_biomass-20.0_real64)>tol) error stop 20

  print '(a)','SW431_CROP_POTENTIAL_SHADOW=PASS'
end program

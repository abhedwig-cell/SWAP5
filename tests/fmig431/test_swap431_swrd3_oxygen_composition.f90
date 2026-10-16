program test_swap431_swrd3_oxygen_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_potential_shadow_state, only: wofost_potential_shadow_state_t, &
       initialize_wofost_potential_shadow_from_actual, WOFOST_POTENTIAL_SHADOW_OK
  use mod_crop_root_depth_biomass, only: crop_root_depth_biomass_result_t
  use mod_crop_root_anaerobic_extension_gate, only: root_extension_allowed_by_daily_oxygen, ROOT_ANOX_GATE_OK
  implicit none

  type(wofost_crop_owner_state_t) :: owner
  type(wofost_potential_shadow_state_t) :: shadow
  type(wofost_rate_table_t) :: rlwtb
  type(crop_root_depth_biomass_result_t) :: before, after
  integer :: status
  logical :: available, growth_allowed
  real(real64), parameter :: tol=1.0e-12_real64
  real(real64) :: grrt, drrt, net_root_change

  call construct_wofost_rate_table([0.0_real64,100.0_real64,300.0_real64], &
       [10.0_real64,50.0_real64,150.0_real64],rlwtb,status)
  if(status/=WOFOST_RATE_TABLE_OK) error stop 1

  owner%crop_emerged=.true.
  owner%development_stage=0.5_real64
  allocate(owner%biomass,owner%evolution_continuation)
  owner%biomass%root_biomass=100.0_real64
  owner%biomass%stem_biomass=50.0_real64
  owner%biomass%storage_biomass=0.0_real64
  owner%biomass%exponential_leaf_area_index=1.0_real64
  owner%evolution_continuation%temperature_sum=50.0_real64
  if(owner%validate()/=WOFOST_CROP_OWNER_OK) error stop 2

  call initialize_wofost_potential_shadow_from_actual(owner,shadow,status)
  if(status/=WOFOST_POTENTIAL_SHADOW_OK) error stop 3
  shadow%biomass%root_biomass=100.0_real64

  call owner%derive_biomass_root_depth(rlwtb,200.0_real64,300.0_real64,shadow%root_biomass(),before,available,status)
  if(status/=WOFOST_CROP_OWNER_OK.or..not.available) error stop 4
  if(abs(before%actual_root_depth_cm-50.0_real64)>tol.or.abs(before%potential_root_depth_cm-50.0_real64)>tol) error stop 5

  ! Pinned B1.11 actual SWRD3 gate: below AERATECRIT, actual GRRT is forced
  ! to zero but root death remains. Potential crop is not oxygen-gated.
  call root_extension_allowed_by_daily_oxygen(.true.,0.20_real64,0.40_real64,growth_allowed,status)
  if(status/=ROOT_ANOX_GATE_OK.or.growth_allowed) error stop 6
  grrt=20.0_real64
  drrt=5.0_real64
  if(.not.growth_allowed) grrt=0.0_real64
  net_root_change=grrt-drrt
  owner%biomass%root_biomass=owner%biomass%root_biomass+net_root_change

  ! Potential branch keeps its source gross/root death trajectory.
  shadow%biomass%root_biomass=shadow%biomass%root_biomass+(20.0_real64-5.0_real64)

  call owner%derive_biomass_root_depth(rlwtb,200.0_real64,300.0_real64,shadow%root_biomass(),after,available,status)
  if(status/=WOFOST_CROP_OWNER_OK.or..not.available) error stop 7
  if(after%actual_root_depth_cm>=before%actual_root_depth_cm) error stop 8
  if(after%potential_root_depth_cm<=before%potential_root_depth_cm) error stop 9
  if(abs(owner%biomass%root_biomass-95.0_real64)>tol) error stop 10
  if(abs(shadow%root_biomass()-115.0_real64)>tol) error stop 11

  ! Equality at AERATECRIT permits actual gross root growth.
  call root_extension_allowed_by_daily_oxygen(.true.,0.40_real64,0.40_real64,growth_allowed,status)
  if(status/=ROOT_ANOX_GATE_OK.or..not.growth_allowed) error stop 12

  print '(a)','SW431_SWRD3_OXYGEN_COMPOSITION=PASS'
end program

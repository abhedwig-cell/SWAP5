program test_swap431_potential_shadow_pre_event_restart
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_potential_shadow_state, only: wofost_potential_shadow_state_t
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t, &
       fmr_wofost_crop_transaction_persistence_t, fmr_wofost_root_growth_carrier_t, &
       initialize_fmr_wofost_crop_transaction_state, export_fmr_wofost_crop_transaction_persistence, &
       reconstruct_fmr_wofost_crop_transaction_from_persistence, FMR_WOF38_OK, FMR_WOFOST_CROP_PERSISTENCE_OK
  implicit none

  type(wofost_crop_owner_state_t) :: owner, restored_owner
  type(wofost_potential_shadow_state_t) :: shadow
  type(fmr_wofost_crop_transaction_state_t) :: state, restored
  type(fmr_wofost_crop_transaction_persistence_t) :: view
  type(fmr_wofost_root_growth_carrier_t) :: growth
  integer :: status
  logical :: ok, available, state_ready, state_shadow_enabled, view_ready, restored_ready, restored_shadow_enabled, restored_receipt_ready
  real(real64), parameter :: tol=1.0e-12_real64

  owner%crop_emerged=.true.
  owner%development_stage=0.0_real64
  allocate(owner%biomass,owner%evolution_continuation)
  owner%biomass%root_biomass=10.0_real64
  owner%biomass%stem_biomass=20.0_real64
  owner%biomass%storage_biomass=0.0_real64
  owner%biomass%exponential_leaf_area_index=0.5_real64
  owner%biomass%leaf_biomass=[5.0_real64]
  owner%biomass%specific_leaf_area=[0.1_real64]
  owner%biomass%leaf_age=[0.0_real64]
  owner%evolution_continuation%temperature_sum=0.0_real64
  owner%evolution_continuation%minimum_temperature_history=0.0_real64
  owner%evolution_continuation%minimum_temperature_history_count=0
  owner%evolution_continuation%anthesis_reached=.false.
  if(owner%validate()/=WOFOST_CROP_OWNER_OK) error stop 1

  call initialize_fmr_wofost_crop_transaction_state(owner,state,status,enable_potential_shadow=.true.)
  state_ready=state%ready()
  state_shadow_enabled=state%potential_shadow_enabled()
  if(status/=FMR_WOF38_OK.or..not.state_ready.or..not.state_shadow_enabled) error stop 2

  ! Before the first accepted daily event, no GRRT/GRRTPOT receipt exists.
  call state%snapshot_root_growth(growth,available)
  if(available) error stop 3
  if(state%receipt_ready()) error stop 4

  call export_fmr_wofost_crop_transaction_persistence(state,view,ok,status)
  view_ready=view%ready()
  if(.not.ok.or.status/=FMR_WOFOST_CROP_PERSISTENCE_OK.or..not.view_ready) error stop 5
  if(.not.view%potential_shadow_present.or..not.view%root_growth_carrier_present) error stop 6
  if(view%root_growth_carrier%valid.or.view%receipt_present) error stop 7

  call reconstruct_fmr_wofost_crop_transaction_from_persistence(view,restored,ok,status)
  restored_ready=restored%ready()
  if(.not.ok.or.status/=FMR_WOFOST_CROP_PERSISTENCE_OK.or..not.restored_ready) error stop 8
  restored_shadow_enabled=restored%potential_shadow_enabled()
  restored_receipt_ready=restored%receipt_ready()
  if(.not.restored_shadow_enabled.or.restored_receipt_ready) error stop 9

  call restored%snapshot_potential_shadow(shadow,available)
  if(.not.available.or..not.shadow%active) error stop 10
  if(abs(shadow%root_biomass()-10.0_real64)>tol) error stop 11

  call restored%snapshot_root_growth(growth,available)
  if(available) error stop 12

  call restored%snapshot_owner(restored_owner,available)
  if(.not.available.or.abs(restored_owner%biomass%root_biomass-10.0_real64)>tol) error stop 13

  print '(a)','SW431_CROP_POTENTIAL_SHADOW_PRE_EVENT_RESTART=PASS'
end program

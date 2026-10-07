program test_swap431_wofost_vernalisation_persistence
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_crop_owner_state
  use mod_fmr_wofost_crop_transaction
  implicit none

  type(wofost_crop_owner_state_t) :: owner, restored_owner, plain_owner
  type(fmr_wofost_crop_transaction_state_t) :: tx, restored_tx
  type(fmr_wofost_crop_transaction_persistence_t) :: view
  class(transaction_state_t), allocatable :: clone
  integer :: status
  logical :: ok, available
  real(real64), parameter :: tol=1.0e-12_real64

  owner%crop_emerged=.true.
  owner%development_stage=0.25_real64
  allocate(owner%biomass,owner%evolution_continuation,owner%vernalisation)
  owner%biomass%root_biomass=10.0_real64
  owner%biomass%stem_biomass=20.0_real64
  owner%biomass%storage_biomass=0.0_real64
  owner%biomass%exponential_leaf_area_index=1.0_real64
  owner%evolution_continuation%temperature_sum=120.0_real64
  owner%evolution_continuation%anthesis_reached=.false.
  owner%vernalisation%accumulated_units=17.5_real64
  owner%vernalisation%vernalised=.false.
  if(owner%validate()/=WOFOST_CROP_OWNER_OK) error stop 1

  call owner%clone(clone)
  select type(c=>clone)
  type is(wofost_crop_owner_state_t)
    if(.not.allocated(c%vernalisation)) error stop 2
    if(abs(c%vernalisation%accumulated_units-17.5_real64)>tol.or.c%vernalisation%vernalised) error stop 3
  class default
    error stop 4
  end select

  call initialize_fmr_wofost_crop_transaction_state(owner,tx,status)
  if(status/=FMR_WOF38_OK) error stop 5
  call export_fmr_wofost_crop_transaction_persistence(tx,view,ok,status)
  if(.not.ok.or.status/=FMR_WOFOST_CROP_PERSISTENCE_OK.or..not.view%ready()) error stop 6
  if(.not.allocated(view%owner%vernalisation)) error stop 7
  if(abs(view%owner%vernalisation%accumulated_units-17.5_real64)>tol) error stop 8

  call reconstruct_fmr_wofost_crop_transaction_from_persistence(view,restored_tx,ok,status)
  if(.not.ok.or.status/=FMR_WOFOST_CROP_PERSISTENCE_OK) error stop 9
  call restored_tx%snapshot_owner(restored_owner,available)
  if(.not.available.or..not.allocated(restored_owner%vernalisation)) error stop 10
  if(abs(restored_owner%vernalisation%accumulated_units-17.5_real64)>tol.or. &
       restored_owner%vernalisation%vernalised) error stop 11

  ! IDSL0/1 owners incur no hidden vernalisation state.
  plain_owner%crop_emerged=.true.
  plain_owner%development_stage=0.25_real64
  allocate(plain_owner%biomass,plain_owner%evolution_continuation)
  plain_owner%biomass%root_biomass=10.0_real64
  plain_owner%biomass%stem_biomass=20.0_real64
  plain_owner%biomass%storage_biomass=0.0_real64
  plain_owner%biomass%exponential_leaf_area_index=1.0_real64
  if(plain_owner%validate()/=WOFOST_CROP_OWNER_OK.or.plain_owner%vernalisation_available()) error stop 12

  print '(a)','SW431_CROP_VERNALISATION_PERSISTENCE=PASS'
end program

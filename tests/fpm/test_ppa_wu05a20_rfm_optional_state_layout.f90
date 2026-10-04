program test_ppa_wu05a20_rfm_optional_state_layout
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_RFM, fmr_optional_state_layout_known, &
       FMR_SOLUTE_STATE_LAYOUT_NONE, FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED, &
       FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, fmr_template_t, fmr_solute_state_layout_known
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_rfm_state_t, &
       fmr_new_b110_rfm_committed_state
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmr_committed_restart, only: fmr_restart_template_identity_matches
  use mod_rfm_physical_state, only: rfm_physical_state_t, copy_rfm_physical_state
  implicit none

  type(fmr_b110_physical_state_t) :: base, salt_physical, salt_disabled_physical
  type(fmr_template_t) :: salt_template, disabled_template
  type(rfm_physical_state_t) :: rfm, expected_rfm
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  class(transaction_state_t), allocatable :: snapshot, checkpoint_snapshot
  logical :: ok, available

  call require(FMR_OPTIONAL_STATE_LAYOUT_RFM == 505002_int64, 'A20 layout id')
  call require(fmr_optional_state_layout_known(FMR_OPTIONAL_STATE_LAYOUT_RFM), 'A20 layout unknown')
  call require(.not. fmr_optional_state_layout_known(505003_int64), 'A20 nearby optional layout unknown admitted')
  call require(fmr_solute_state_layout_known(FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED), &
       'A20 mobile salt layout unknown')
  call require(fmr_solute_state_layout_known(FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE), &
       'A20 macro salt layout unknown')
  call require(.not. fmr_solute_state_layout_known(505005_int64), 'A20 unknown salt layout admitted')

  base%active_nodes = 2
  allocate(base%pressure_head(2), base%water_content(2))
  base%pressure_head = [-50.0_real64, -75.0_real64]
  base%water_content = [0.31_real64, 0.29_real64]
  base%ponding_depth = 0.0_real64
  base%groundwater_level = -150.0_real64
  allocate(base%salt)
  base%salt%mass_mg_cm2 = [0.05_real64,0.12_real64]
  call require(base%salt%ready(2), 'A20 salt state ready')

  call rfm%initialize(3, ok)
  call require(ok, 'A20 rfm init')
  rfm%mb_water_cm = 0.4_real64
  rfm%endpoint_water_cm = [0.1_real64, 0.2_real64, 0.3_real64]
  rfm%tau_surface_day = 0.25_real64
  call copy_rfm_physical_state(rfm, expected_rfm, ok)
  call require(ok, 'A20 expected copy')

  call fmr_new_b110_rfm_committed_state(committed, 2020_int64, base, rfm, 12.5_real64, ok)
  call require(ok .and. committed%ready(), 'A20 committed init')
  call require(committed%current_lineage_id() == 2020_int64, 'A20 lineage')
  call require(committed%current_revision() == 0_int64, 'A20 initial revision')

  ! Caller-owned sources must no longer alias committed state.
  base%pressure_head = 999.0_real64
  base%water_content = 0.0_real64
  rfm%mb_water_cm = 9.0_real64
  rfm%endpoint_water_cm = 9.0_real64
  rfm%tau_surface_day = 9.0_real64

  call committed%snapshot(snapshot, available)
  call require(available .and. allocated(snapshot), 'A20 committed snapshot')
  select type (typed => snapshot)
  type is (fmr_b110_rfm_state_t)
    call require(all(typed%pressure_head == [-50.0_real64,-75.0_real64]), 'A20 base head clone')
    call require(all(typed%water_content == [0.31_real64,0.29_real64]), 'A20 base theta clone')
    call require(typed%ponding_depth == 0.0_real64, 'A20 pond clone')
    call require(typed%groundwater_level == -150.0_real64, 'A20 gwl clone')
    call require(typed%rfm%same_values(expected_rfm), 'A20 RFM committed clone')
    call require(allocated(typed%salt), 'A20 salinity clone present')
    call require(all(typed%salt%mass_mg_cm2 == [0.05_real64,0.12_real64]), 'A20 salinity clone values')
  class default
    call require(.false., 'A20 wrong committed carrier type')
  end select

  call committed%capture_checkpoint(checkpoint, available)
  call require(available .and. checkpoint%ready(), 'A20 checkpoint capture')
  call checkpoint%snapshot(checkpoint_snapshot, available)
  call require(available .and. allocated(checkpoint_snapshot), 'A20 checkpoint snapshot')
  select type (typed => checkpoint_snapshot)
  type is (fmr_b110_rfm_state_t)
    call require(all(typed%pressure_head == [-50.0_real64,-75.0_real64]), 'A20 checkpoint base')
    call require(typed%rfm%same_values(expected_rfm), 'A20 checkpoint RFM clone')
  class default
    call require(.false., 'A20 wrong checkpoint carrier type')
  end select

  ! Snapshot mutation cannot affect checkpoint-owned state.
  select type (typed => snapshot)
  type is (fmr_b110_rfm_state_t)
    typed%pressure_head = -1.0_real64
    typed%rfm%mb_water_cm = 7.0_real64
    typed%salt%mass_mg_cm2 = -1.0_real64
  end select
  deallocate(checkpoint_snapshot)
  call checkpoint%snapshot(checkpoint_snapshot, available)
  call require(available, 'A20 second checkpoint snapshot')
  select type (typed => checkpoint_snapshot)
  type is (fmr_b110_rfm_state_t)
    call require(all(typed%pressure_head == [-50.0_real64,-75.0_real64]), 'A20 checkpoint isolation')
    call require(typed%rfm%same_values(expected_rfm), 'A20 RFM checkpoint isolation')
    call require(all(typed%salt%mass_mg_cm2 == [0.05_real64,0.12_real64]), 'A20 salinity checkpoint isolation')
  class default
    call require(.false., 'A20 second checkpoint carrier type')
  end select

  ! Salt mass is an independent template axis and is cloned within the
  ! same physical object as admitted hydraulic optional state.
  salt_physical%active_nodes = 2
  allocate(salt_physical%pressure_head(2),salt_physical%water_content(2),salt_physical%salt)
  salt_physical%pressure_head = [-10.0_real64,-20.0_real64]
  salt_physical%water_content = [0.3_real64,0.25_real64]
  salt_physical%salt%mass_mg_cm2 = [0.2_real64,0.1_real64]
  salt_template%template_id = 1_int64
  salt_template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  salt_template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
  salt_template%solute_state_layout_id = FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
  call require(fmr_restart_state_matches_template(salt_physical,salt_template), &
       'A20 matching salinity state layout')
  salt_disabled_physical%active_nodes = 2
  allocate(salt_disabled_physical%pressure_head(2),salt_disabled_physical%water_content(2))
  salt_disabled_physical%pressure_head = salt_physical%pressure_head
  salt_disabled_physical%water_content = salt_physical%water_content
  call require(.not. fmr_restart_state_matches_template(salt_physical,disabled_template), &
       'A20 disabled template rejects allocated salinity')
  disabled_template = salt_template
  disabled_template%solute_state_layout_id = FMR_SOLUTE_STATE_LAYOUT_NONE
  call require(fmr_restart_state_matches_template(salt_disabled_physical,disabled_template), &
       'A20 disabled salinity layout matches absent component')
  call require(.not. fmr_restart_template_identity_matches(salt_template,disabled_template), &
       'A20 restart identity includes independent salinity layout')

  print '(a)', 'PPA_WU05A20_RFM_OPTIONAL_STATE_LAYOUT=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU05A20_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a20_rfm_optional_state_layout

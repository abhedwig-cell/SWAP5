program test_ppa_wu05a20_rfm_optional_state_layout
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_RFM, fmr_optional_state_layout_known
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_rfm_state_t, &
       fmr_new_b110_rfm_committed_state
  use mod_rfm_physical_state, only: rfm_physical_state_t, copy_rfm_physical_state
  implicit none

  type(fmr_b110_physical_state_t) :: base
  type(rfm_physical_state_t) :: rfm, expected_rfm
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  class(transaction_state_t), allocatable :: snapshot, checkpoint_snapshot
  logical :: ok, available

  call require(FMR_OPTIONAL_STATE_LAYOUT_RFM == 505002_int64, 'A20 layout id')
  call require(fmr_optional_state_layout_known(FMR_OPTIONAL_STATE_LAYOUT_RFM), 'A20 layout unknown')
  call require(.not. fmr_optional_state_layout_known(505003_int64), 'A20 nearby unknown admitted')

  base%active_nodes = 2
  allocate(base%pressure_head(2), base%water_content(2))
  base%pressure_head = [-50.0_real64, -75.0_real64]
  base%water_content = [0.31_real64, 0.29_real64]
  base%ponding_depth = 0.0_real64
  base%groundwater_level = -150.0_real64

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
  end select
  deallocate(checkpoint_snapshot)
  call checkpoint%snapshot(checkpoint_snapshot, available)
  call require(available, 'A20 second checkpoint snapshot')
  select type (typed => checkpoint_snapshot)
  type is (fmr_b110_rfm_state_t)
    call require(all(typed%pressure_head == [-50.0_real64,-75.0_real64]), 'A20 checkpoint isolation')
    call require(typed%rfm%same_values(expected_rfm), 'A20 RFM checkpoint isolation')
  class default
    call require(.false., 'A20 second checkpoint carrier type')
  end select

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

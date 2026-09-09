program fkt13_consumer
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t, &
       CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, restore_kernel_committed_state, &
       KERNEL_PERSISTENCE_OK
  use mod_fkt05_test_model, only: fkt05_state_t, fkt05_parameters_t, fkt05_forcing_t
  use mod_fkt12_mass_complete_test_model, only: fkt12_mass_complete_model_t
  use mod_fkt13_process_support
  use mod_fkt13_persistence_adapter, only: fkt13_read_artifact, FKT13_ADAPTER_OK
  implicit none

  type(kernel_persistence_snapshot_t) :: snapshot
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_executor_t) :: kernel
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(fkt12_mass_complete_model_t), target :: model
  type(fkt05_parameters_t) :: parameters
  type(fkt05_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(canonical_mass_accounting_t) :: mass_t2
  class(transaction_state_t), allocatable :: physical
  logical :: imported, restored, available, committed_ok
  integer :: adapter_status, persistence_status, commit_status
  real(real64) :: carrier_water, restored_water, checkpoint_time, final_water
  character(len=1024) :: artifact_path

  if (command_argument_count() /= 1) error stop 'FKT13 consumer requires artifact path'
  call get_command_argument(1, artifact_path)
  if (len_trim(artifact_path) == 0) error stop 'FKT13 consumer artifact path empty'

  call fkt13_read_artifact(trim(artifact_path), FKT13_LAYOUT_ID, snapshot, imported, adapter_status)
  if (.not. imported .or. adapter_status /= FKT13_ADAPTER_OK) error stop 'FKT13 consumer adapter import failed'
  if (.not. snapshot%ready()) error stop 'FKT13 consumer reconstructed snapshot not ready'
  if (snapshot%current_lineage_id() /= FKT13_LINEAGE_ID) error stop 'FKT13 consumer snapshot lineage mismatch'
  if (snapshot%current_revision() /= 1_int64) error stop 'FKT13 consumer snapshot revision mismatch'

  call snapshot%snapshot_physical(physical, available)
  if (.not. available) error stop 'FKT13 consumer carrier physical unavailable'
  select type (physical)
  type is (fkt05_state_t)
    carrier_water = physical%water
  class default
    error stop 'FKT13 consumer carrier physical type mismatch'
  end select

  call restore_kernel_committed_state(snapshot, FKT13_LAYOUT_ID, committed, restored, persistence_status)
  if (.not. restored .or. persistence_status /= KERNEL_PERSISTENCE_OK) error stop 'FKT13 consumer restore failed'
  restored_water = fkt13_committed_water(committed)
  if (transfer(restored_water, 0_int64) /= transfer(carrier_water, 0_int64)) &
       error stop 'FKT13 reconstruction or restore created physical transfer'
  if (committed%current_lineage_id() /= FKT13_LINEAGE_ID) error stop 'FKT13 restored lineage mismatch'
  if (committed%current_revision() /= 1_int64) error stop 'FKT13 restored revision mismatch'
  if (transfer(fkt13_committed_time(committed), 0_int64) /= transfer(FKT13_T1, 0_int64)) &
       error stop 'FKT13 restored time mismatch'
  write(*,'(A)') 'FKT13_RECONSTRUCTION_RESTORE_ZERO_TRANSFER=PASS'

  call committed%capture_checkpoint(checkpoint, available)
  if (.not. available) error stop 'FKT13 next checkpoint unavailable'
  if (checkpoint%origin_revision() /= 1_int64) error stop 'FKT13 checkpoint origin revision mismatch'
  call checkpoint%current_time(checkpoint_time, available)
  if (.not. available) error stop 'FKT13 checkpoint time unavailable'
  if (transfer(checkpoint_time, 0_int64) /= transfer(FKT13_T1, 0_int64)) &
       error stop 'FKT13 checkpoint time mismatch'

  call fkt13_setup(parameters, forcing, config)
  call kernel%bind_model(model)
  call kernel%advance_interval(parameters, committed, forcing, config, FKT13_T1, FKT13_T2, &
       result, candidate, diagnostics, checkpoint)
  if (result%status /= CANONICAL_STATUS_COMPLETED) error stop 'FKT13 restored continuation failed'
  if (.not. candidate%ready()) error stop 'FKT13 restored candidate not ready'
  if (candidate%origin_revision() /= 1_int64) error stop 'FKT13 restored candidate origin revision mismatch'
  if (candidate%current_lineage_id() /= FKT13_LINEAGE_ID) error stop 'FKT13 restored candidate lineage mismatch'

  call kernel%commit_candidate(committed, candidate, diagnostics, committed_ok, commit_status, mass_t2)
  if (.not. committed_ok .or. commit_status /= KERNEL_COMMIT_STATUS_COMMITTED) &
       error stop 'FKT13 restored T2 commit failed'
  if (committed%current_revision() /= 2_int64) error stop 'FKT13 restored revision did not continue monotonically'
  if (committed%current_lineage_id() /= FKT13_LINEAGE_ID) error stop 'FKT13 restored lineage changed'
  if (transfer(fkt13_committed_time(committed), 0_int64) /= transfer(FKT13_T2, 0_int64)) &
       error stop 'FKT13 restored T2 time mismatch'

  final_water = fkt13_committed_water(committed)
  if (.not. mass_t2%complete) error stop 'FKT13 restored mass ledger incomplete'
  if (transfer(mass_t2%residual, 0_int64) /= transfer(0.0_real64, 0_int64)) &
       error stop 'FKT13 restored mass residual nonzero'
  if (transfer(mass_t2%storage_start, 0_int64) /= transfer(restored_water, 0_int64)) &
       error stop 'FKT13 restored storage start double-counted or reset'
  if (transfer(mass_t2%storage_end, 0_int64) /= transfer(final_water, 0_int64)) &
       error stop 'FKT13 restored storage end mismatch'

  write(*,'(A)') 'FKT13_NEXT_CHECKPOINT_AND_CANDIDATE_PROVENANCE_EXACT=PASS'
  write(*,'(A)') 'FKT13_MASS_CONTINUATION_WITHOUT_STORAGE_RESET=PASS'
  call fkt13_print_endpoint(committed, mass_t2)
end program fkt13_consumer

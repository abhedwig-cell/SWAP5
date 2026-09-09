program fkt13_producer
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, export_kernel_committed_state, &
       KERNEL_PERSISTENCE_OK
  use mod_fkt05_test_model, only: fkt05_parameters_t, fkt05_forcing_t
  use mod_fkt12_mass_complete_test_model, only: fkt12_mass_complete_model_t
  use mod_fkt13_process_support
  use mod_fkt13_persistence_adapter, only: fkt13_write_artifact, FKT13_ADAPTER_OK
  implicit none

  type(kernel_committed_state_t) :: committed
  type(kernel_executor_t) :: kernel
  type(fkt12_mass_complete_model_t), target :: model
  type(fkt05_parameters_t) :: parameters
  type(fkt05_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(canonical_mass_accounting_t) :: mass_t1
  type(kernel_persistence_snapshot_t) :: snapshot
  logical :: exported, written
  integer :: persistence_status, adapter_status
  character(len=1024) :: artifact_path

  if (command_argument_count() /= 1) error stop 'FKT13 producer requires artifact path'
  call get_command_argument(1, artifact_path)
  if (len_trim(artifact_path) == 0) error stop 'FKT13 producer artifact path empty'

  call fkt13_new_initial_committed(committed)
  call fkt13_setup(parameters, forcing, config)
  call kernel%bind_model(model)
  call fkt13_advance_and_commit(kernel, committed, parameters, forcing, config, FKT13_T0, FKT13_T1, mass_t1)

  if (committed%current_revision() /= 1_int64) error stop 'FKT13 producer revision mismatch'
  if (committed%current_lineage_id() /= FKT13_LINEAGE_ID) error stop 'FKT13 producer lineage mismatch'
  if (.not. mass_t1%complete) error stop 'FKT13 producer mass incomplete'

  call export_kernel_committed_state(committed, FKT13_LAYOUT_ID, snapshot, exported, persistence_status)
  if (.not. exported .or. persistence_status /= KERNEL_PERSISTENCE_OK) &
       error stop 'FKT13 producer typed export failed'
  if (.not. snapshot%ready()) error stop 'FKT13 producer snapshot not ready'

  call fkt13_write_artifact(trim(artifact_path), snapshot, written, adapter_status)
  if (.not. written .or. adapter_status /= FKT13_ADAPTER_OK) error stop 'FKT13 producer artifact write failed'

  write(*,'(A)') 'FKT13_PRODUCER_T1_EXPORT_AND_EXTERNAL_WRITE=PASS'
end program fkt13_producer

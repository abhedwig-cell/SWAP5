program fgc24_export_probe
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_capture_checkpoint
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_coupled_restart, only: groundwater_restart_state_t, groundwater_committed_restart_record_t, &
       groundwater_coupled_restart_record_t, groundwater_export_committed_restart, export_groundwater_coupled_restart
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_parameters_t, dummy_model_t, &
       dummy_materializer_t, dummy_groundwater_service_t, setup_common
  use mod_fgc24_coupled_restart_test, only: dummy_groundwater_restart_adapter_t, run_one_window, SWAP_LAYOUT_ID
  implicit none

  type(kernel_executor_t) :: executor
  type(kernel_committed_state_t) :: committed
  type(dummy_model_t), target :: model
  type(dummy_parameters_t) :: parameters
  type(dummy_materializer_t) :: materializer
  type(dummy_groundwater_service_t), target :: groundwater
  type(dummy_groundwater_restart_adapter_t) :: adapter
  type(groundwater_interface_mass_ledger_t) :: ledger
  type(groundwater_head_datum_t) :: datum
  type(groundwater_head_convergence_policy_t) :: policy
  type(groundwater_coupling_window_t) :: window
  type(groundwater_coupling_origin_t) :: origin
  type(canonical_numerical_config_t) :: numerical
  type(groundwater_exchange_checkpoint_t) :: checkpoint
  type(groundwater_committed_restart_record_t) :: groundwater_record
  type(groundwater_coupled_restart_record_t) :: record
  class(transaction_state_t), allocatable :: initial_state
  class(groundwater_restart_state_t), allocatable :: adapter_state
  integer(int64) :: service_id, lineage_id, revision
  real(real64) :: checkpoint_time, adapter_time
  logical :: initialized, exported, checkpoint_time_available
  integer :: status, checkpoint_status, adapter_status

  call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
       committed, initial_state, initialized, status)
  if (.not. initialized) error stop 'F-GC24 probe setup failed'
  call run_one_window(executor, parameters, committed, materializer, numerical, groundwater, ledger, datum, policy, &
       window, origin)
  adapter%target => groundwater

  call groundwater_capture_checkpoint(groundwater, checkpoint, checkpoint_status)
  call checkpoint%origin_time(checkpoint_time, checkpoint_time_available)
  write(*,'(A,I0,A,L1,A,I0,A,I0,A,I0,A,ES24.15)') 'FGC24_CHECKPOINT status=', checkpoint_status, &
       ' ready=', checkpoint%ready(), ' service=', checkpoint%service_id(), ' lineage=', checkpoint%lineage_id(), &
       ' revision=', checkpoint%origin_revision(), ' time=', checkpoint_time
  write(*,'(A,L1)') 'FGC24_CHECKPOINT_TIME_AVAILABLE=', checkpoint_time_available

  service_id = 0_int64
  lineage_id = 0_int64
  revision = -1_int64
  adapter_time = 0.0_real64
  call adapter%export_committed(service_id, lineage_id, revision, adapter_time, adapter_state, adapter_status)
  write(*,'(A,I0,A,L1,A,I0,A,I0,A,I0,A,ES24.15)') 'FGC24_ADAPTER status=', adapter_status, &
       ' allocated=', allocated(adapter_state), ' service=', service_id, ' lineage=', lineage_id, &
       ' revision=', revision, ' time=', adapter_time
  if (allocated(adapter_state)) write(*,'(A,L1)') 'FGC24_ADAPTER_STATE_VALID=', adapter_state%valid()

  call groundwater_export_committed_restart(groundwater, adapter, groundwater_record, exported, status)
  write(*,'(A,I0,A,L1,A,L1)') 'FGC24_GW_EXPORT status=', status, ' exported=', exported, &
       ' state_allocated=', allocated(groundwater_record%backend_state)

  call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, adapter, ledger, origin, record, &
       exported, status)
  write(*,'(A,I0,A,L1)') 'FGC24_PROBE_STATUS=', status, ' EXPORTED=', exported
end program fgc24_export_probe

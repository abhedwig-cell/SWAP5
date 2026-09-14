program fgc24_export_probe
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_coupled_restart, only: groundwater_coupled_restart_record_t, export_groundwater_coupled_restart
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
  type(groundwater_coupled_restart_record_t) :: record
  class(transaction_state_t), allocatable :: initial_state
  logical :: initialized, exported
  integer :: status

  call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
       committed, initial_state, initialized, status)
  if (.not. initialized) error stop 'F-GC24 probe setup failed'
  call run_one_window(executor, parameters, committed, materializer, numerical, groundwater, ledger, datum, policy, &
       window, origin)
  adapter%target => groundwater
  call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, adapter, ledger, origin, record, &
       exported, status)
  write(*,'(A,I0,A,L1)') 'FGC24_PROBE_STATUS=', status, ' EXPORTED=', exported
end program fgc24_export_probe

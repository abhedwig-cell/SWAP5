program test_fvq86_fgc24_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_prepare_candidate, &
       groundwater_abort_prepared, GW_EXCHANGE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t, groundwater_pc_result_t, &
       run_restricted_groundwater_coupling_window, GW_PC_OK
  use mod_groundwater_coupled_restart, only: groundwater_coupled_restart_record_t, &
       export_groundwater_coupled_restart, restore_groundwater_coupled_restart, &
       GW_COUPLED_RESTART_OK, GW_COUPLED_RESTART_INVALID_RECORD, &
       GW_COUPLED_RESTART_PROVENANCE_MISMATCH, GW_COUPLED_RESTART_ADAPTER_REJECTED, &
       GW_COUPLED_RESTART_TARGET_NOT_FRESH, GW_COUPLED_RESTART_SERVICE_NOT_QUIESCENT
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_state_t, dummy_parameters_t, dummy_model_t, &
       dummy_materializer_t, dummy_groundwater_service_t, setup_common
  use mod_fgc24_coupled_restart_test, only: dummy_groundwater_restart_adapter_t, SWAP_LAYOUT_ID
  implicit none

  character(len=64) :: mode

  mode = 'oracle'
  call get_command_argument(1, mode)
  select case (trim(mode))
  case ('oracle', '')
    call run_independent_oracle()
  case ('postcondition')
    call run_independent_postcondition_failure()
  case default
    error stop 'F-VQ86 unknown mode'
  end select

contains

  subroutine run_independent_oracle()
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed, fresh_committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t), target :: groundwater, fresh_groundwater
    type(dummy_groundwater_restart_adapter_t) :: adapter, fresh_adapter
    type(groundwater_interface_mass_ledger_t) :: ledger, fresh_ledger
    type(groundwater_interface_mass_snapshot_t) :: snap
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin, fresh_origin
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_pc_result_t) :: pc
    type(groundwater_coupled_restart_record_t) :: record, bad_record
    type(groundwater_exchange_checkpoint_t) :: checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_prepared_t) :: prepared
    type(groundwater_exchange_trial_result_t) :: trial_result
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized, exported, restored
    integer :: status, calls_before

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call require(initialized .and. status == GW_MASS_LEDGER_OK, 'source setup')

    ! Independent wrapper-level quiescence adversary. A live prepared publication
    ! reservation must block restart even though it is not persisted in the record.
    call groundwater_capture_checkpoint(groundwater, checkpoint, status)
    call require(status == GW_EXCHANGE_OK .and. checkpoint%ready(), 'capture for quiescence adversary')
    call groundwater_trial_from_checkpoint(groundwater, checkpoint, window, 0.0_real64, candidate, trial_result, status)
    call require(status == GW_EXCHANGE_OK .and. candidate%ready(), 'trial for quiescence adversary')
    call groundwater_prepare_candidate(groundwater, checkpoint, candidate, prepared, status)
    call require(status == GW_EXCHANGE_OK .and. prepared%ready(), 'prepare quiescence adversary')
    call require(.not. groundwater%restart_quiescent(), 'prepared reservation visible to restart seam')
    adapter%target => groundwater
    call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, adapter, ledger, origin, &
         record, exported, status)
    call require(.not. exported .and. status == GW_COUPLED_RESTART_SERVICE_NOT_QUIESCENT, &
         'prepared reservation fails restart export closed')
    call groundwater_abort_prepared(groundwater, checkpoint, prepared, status)
    call require(status == GW_EXCHANGE_OK .and. groundwater%restart_quiescent(), 'abort restores quiescence')

    ! Build an accepted coupling boundary through the real restricted PC runtime.
    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, pc)
    call require(pc%status == GW_PC_OK .and. pc%committed, 'accepted source coupling window')
    call require(transfer(pc%ledger_snapshot%conservation_residual_m, 0_int64) == transfer(0.0_real64, 0_int64), &
         'source interface action-reaction mass is exact')

    call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, adapter, ledger, origin, &
         record, exported, status)
    call require(exported .and. status == GW_COUPLED_RESTART_OK, 'clean committed restart export')
    call require(allocated(record%swap_physical_state), 'SWAP physical continuation present')
    call require(allocated(record%groundwater%backend_state), 'groundwater committed continuation present')
    call require(record%origin%swap_revision == record%swap_revision, 'SWAP provenance bound in record')
    call require(record%origin%groundwater_revision == record%groundwater%revision, &
         'groundwater provenance bound in record')
    call require(transfer(record%origin%accepted_time, 0_int64) == transfer(record%accepted_time, 0_int64), &
         'accepted time bound exactly in record')

    ! Wrong layout is a recoverable pre-publication rejection and may not call the
    ! external restart adapter.
    call reset_fresh(fresh_committed, fresh_groundwater, fresh_ledger, fresh_origin, fresh_adapter)
    call restore_groundwater_coupled_restart(record, SWAP_LAYOUT_ID + 1_int64, fresh_committed, fresh_groundwater, &
         fresh_adapter, fresh_ledger, fresh_origin, restored, status)
    call require(.not. restored .and. status == GW_COUPLED_RESTART_INVALID_RECORD, 'wrong layout rejected')
    call require(fresh_adapter%restore_calls == 0, 'wrong layout rejected before backend publication')
    call require(.not. fresh_committed%ready() .and. .not. fresh_origin%initialized, &
         'wrong layout leaves local committed carriers unpublished')

    ! Cross-carrier time tampering must be rejected before the external backend.
    bad_record = record
    bad_record%accepted_time = bad_record%accepted_time + 0.125_real64
    call reset_fresh(fresh_committed, fresh_groundwater, fresh_ledger, fresh_origin, fresh_adapter)
    call restore_groundwater_coupled_restart(bad_record, SWAP_LAYOUT_ID, fresh_committed, fresh_groundwater, &
         fresh_adapter, fresh_ledger, fresh_origin, restored, status)
    call require(.not. restored .and. status == GW_COUPLED_RESTART_PROVENANCE_MISMATCH, 'time tamper rejected')
    call require(fresh_adapter%restore_calls == 0, 'time tamper rejected before backend publication')

    ! Adapter rejection is still recoverable because its contract promises no
    ! external publication on nonzero status. Local carriers must remain empty.
    call reset_fresh(fresh_committed, fresh_groundwater, fresh_ledger, fresh_origin, fresh_adapter)
    fresh_adapter%fail_restore = .true.
    call restore_groundwater_coupled_restart(record, SWAP_LAYOUT_ID, fresh_committed, fresh_groundwater, &
         fresh_adapter, fresh_ledger, fresh_origin, restored, status)
    call require(.not. restored .and. status == GW_COUPLED_RESTART_ADAPTER_REJECTED, 'adapter rejection propagated')
    call require(fresh_adapter%restore_calls == 1, 'adapter rejection attempted exactly once')
    call require(.not. fresh_committed%ready() .and. .not. fresh_origin%initialized, &
         'adapter rejection leaves SWAP and origin unpublished')
    call fresh_ledger%snapshot(snap)
    call require(.not. snap%identity_bound .and. snap%committed_exchange_count == 0, &
         'adapter rejection leaves ledger unpublished')

    ! Successful restore publishes the complete coupled accepted boundary exactly
    ! once and must not resurrect transient candidate state.
    call reset_fresh(fresh_committed, fresh_groundwater, fresh_ledger, fresh_origin, fresh_adapter)
    call restore_groundwater_coupled_restart(record, SWAP_LAYOUT_ID, fresh_committed, fresh_groundwater, &
         fresh_adapter, fresh_ledger, fresh_origin, restored, status)
    call require(restored .and. status == GW_COUPLED_RESTART_OK, 'fresh coupled restore')
    call require(fresh_committed%ready() .and. fresh_origin%initialized, 'local committed carriers published')
    call require(fresh_adapter%restore_calls == 1, 'successful backend restore exactly once')
    call require(fresh_groundwater%last_candidate_token == 0_int64, 'candidate token not resurrected')
    call require(transfer(fresh_groundwater%pending_t1, 0_int64) == transfer(0.0_real64, 0_int64), &
         'pending trial time not resurrected')
    call fresh_ledger%snapshot(snap)
    call require(snap%identity_bound, 'restored ledger identity bound')
    call require(transfer(snap%conservation_residual_m, 0_int64) == transfer(0.0_real64, 0_int64), &
         'restored interface mass remains exact')
    call require(snap%committed_exchange_count == record%ledger%committed_exchange_count, &
         'restored committed exchange count exact')
    call require(transfer(snap%committed_swap_outward_exchange_m, 0_int64) == &
         transfer(record%ledger%committed_swap_outward_exchange_m, 0_int64), 'restored committed exchange total exact')

    calls_before = fresh_adapter%restore_calls
    call restore_groundwater_coupled_restart(record, SWAP_LAYOUT_ID, fresh_committed, fresh_groundwater, &
         fresh_adapter, fresh_ledger, fresh_origin, restored, status)
    call require(.not. restored .and. status == GW_COUPLED_RESTART_TARGET_NOT_FRESH, &
         'second restore into published target rejected')
    call require(fresh_adapter%restore_calls == calls_before, 'replay rejection occurs before backend republish')

    write(*,'(A)') 'FVQ86_PREPARED_RESERVATION_FAIL_CLOSED=PASS'
    write(*,'(A)') 'FVQ86_PROVENANCE_AND_LAYOUT_PREPUBLICATION_REJECTION=PASS'
    write(*,'(A)') 'FVQ86_ADAPTER_REJECTION_LOCAL_ATOMICITY=PASS'
    write(*,'(A)') 'FVQ86_COMMITTED_RESTORE_EXACTLY_ONCE=PASS'
    write(*,'(A)') 'FVQ86_TRANSIENT_TOKEN_NONRESURRECTION=PASS'
    write(*,'(A)') 'FVQ86_EXACT_INTERFACE_MASS_RESTORE=PASS'
    write(*,'(A,I0,A,I0,A,I0)') 'FVQ86_ORACLE swap_revision=', record%swap_revision, &
         ' gw_revision=', record%groundwater%revision, ' exchange_count=', record%ledger%committed_exchange_count
  end subroutine run_independent_oracle

  subroutine run_independent_postcondition_failure()
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed, fresh_committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t), target :: groundwater, fresh_groundwater
    type(dummy_groundwater_restart_adapter_t) :: adapter, violating_adapter
    type(groundwater_interface_mass_ledger_t) :: ledger, fresh_ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin, fresh_origin
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_pc_result_t) :: pc
    type(groundwater_coupled_restart_record_t) :: record
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized, exported, restored
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call require(initialized .and. status == GW_MASS_LEDGER_OK, 'postcondition source setup')
    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, pc)
    call require(pc%status == GW_PC_OK .and. pc%committed, 'postcondition accepted source')
    adapter%target => groundwater
    call export_groundwater_coupled_restart(committed, SWAP_LAYOUT_ID, groundwater, adapter, ledger, origin, &
         record, exported, status)
    call require(exported .and. status == GW_COUPLED_RESTART_OK, 'postcondition restart export')

    call reset_fresh(fresh_committed, fresh_groundwater, fresh_ledger, fresh_origin, violating_adapter)
    violating_adapter%violate_success_postcondition = .true.
    call restore_groundwater_coupled_restart(record, SWAP_LAYOUT_ID, fresh_committed, fresh_groundwater, &
         violating_adapter, fresh_ledger, fresh_origin, restored, status)
    error stop 'F-VQ86 FAIL: successful adapter postcondition violation returned recoverably'
  end subroutine run_independent_postcondition_failure

  subroutine reset_fresh(committed, groundwater, ledger, origin, adapter)
    type(kernel_committed_state_t), intent(out) :: committed
    type(dummy_groundwater_service_t), target, intent(out) :: groundwater
    type(groundwater_interface_mass_ledger_t), intent(out) :: ledger
    type(groundwater_coupling_origin_t), intent(out) :: origin
    type(dummy_groundwater_restart_adapter_t), intent(out) :: adapter

    committed = kernel_committed_state_t()
    groundwater = dummy_groundwater_service_t()
    ledger = groundwater_interface_mass_ledger_t()
    origin = groundwater_coupling_origin_t()
    adapter = dummy_groundwater_restart_adapter_t()
    adapter%target => groundwater
  end subroutine reset_fresh

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      write(*,'(A)') 'F-VQ86 FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fvq86_fgc24_independent

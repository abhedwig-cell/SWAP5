module mod_groundwater_multiswap_coupler
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_candidate_state_t, kernel_executor_t, kernel_result_t
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       evaluate_groundwater_interface_residual, GW_INTERFACE_OK
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, GW_HEAD_POLICY_OK
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       groundwater_exchange_checkpoint_t, groundwater_exchange_candidate_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_discard_candidate, &
       GW_EXCHANGE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, &
       GW_MULTI_OK, GW_MULTI_INVALID_REQUEST, GW_MULTI_INVALID_ORIGIN, GW_MULTI_SWAP_CHECKPOINT_FAILED, &
       GW_MULTI_GROUNDWATER_CHECKPOINT_FAILED, GW_MULTI_PREDICTOR_FORCING_FAILED, GW_MULTI_PREDICTOR_SWAP_FAILED, &
       GW_MULTI_PREDICTOR_AGGREGATION_FAILED, GW_MULTI_PREDICTOR_GROUNDWATER_FAILED, &
       GW_MULTI_PREDICTOR_DISCARD_FAILED, GW_MULTI_CORRECTOR_FORCING_FAILED, GW_MULTI_CORRECTOR_SWAP_FAILED, &
       GW_MULTI_CORRECTOR_AGGREGATION_FAILED, GW_MULTI_CORRECTOR_GROUNDWATER_FAILED, GW_MULTI_INTERFACE_FAILED, &
       GW_MULTI_NOT_CONVERGED, GW_MULTI_PREPUBLICATION_ABORT_FAILED
  use mod_groundwater_multiswap_topology, only: build_canonical_tile_order, multiswap_origins_consistent, &
       same_multiswap_time
  use mod_groundwater_multiswap_swap_phase, only: validate_multiswap_area_topology, run_multiswap_swap_phase, &
       GW_MULTI_PHASE_OK, GW_MULTI_PHASE_FORCING_FAILED, GW_MULTI_PHASE_SWAP_FAILED, &
       GW_MULTI_PHASE_EXCHANGE_FAILED, GW_MULTI_PHASE_AGGREGATION_FAILED
  use mod_groundwater_multiswap_transaction, only: rollback_multiswap_candidates, &
       discard_multiswap_groundwater_and_swap
  use mod_groundwater_multiswap_publication, only: publish_multiswap_cell_transaction
  implicit none
  private

  public :: run_restricted_groundwater_multiswap_cell_window

contains

  subroutine run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, &
       materializer, numerical, groundwater, ledgers, datum, head_policy, window, origins, result)
    type(kernel_executor_t), intent(inout) :: executor
    class(kernel_parameters_t), intent(in) :: parameters(:)
    type(kernel_committed_state_t), intent(inout) :: committed(:)
    type(groundwater_direct_tile_binding_t), intent(in) :: bindings(:)
    class(groundwater_swap_forcing_materializer_t), intent(in) :: materializer
    type(canonical_numerical_config_t), intent(in) :: numerical
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledgers(:)
    type(groundwater_head_datum_t), intent(in) :: datum
    type(groundwater_head_convergence_policy_t), intent(in) :: head_policy
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_coupling_origin_t), intent(inout) :: origins(:)
    type(groundwater_multiswap_result_t), intent(out) :: result

    type(kernel_checkpoint_t), allocatable :: checkpoints(:)
    type(kernel_candidate_state_t), allocatable :: predictor_candidates(:), corrector_candidates(:)
    type(kernel_result_t), allocatable :: predictor_results(:), corrector_results(:)
    type(groundwater_exchange_checkpoint_t) :: groundwater_checkpoint
    type(groundwater_exchange_candidate_t) :: predictor_groundwater_candidate, corrector_groundwater_candidate
    type(groundwater_exchange_trial_result_t) :: predictor_groundwater_result, corrector_groundwater_result
    integer, allocatable :: order(:)
    real(real64) :: swap_time, groundwater_time
    logical :: checkpoint_ok, swap_time_available, groundwater_time_available, converged
    integer :: n, i, k, idx, status, phase_status, failing_index, cleanup_status

    result = groundwater_multiswap_result_t()
    result%diagnostics%route = 'restricted-multiswap-pc1'
    n = size(bindings)
    if (n <= 0 .or. size(parameters) /= n .or. size(committed) /= n .or. size(ledgers) /= n .or. &
        size(origins) /= n) then
      call fail_main(result, GW_MULTI_INVALID_REQUEST, .false., 'shape-contract')
      return
    end if
    if (.not. window%valid() .or. .not. datum%valid() .or. .not. head_policy%valid()) then
      call fail_main(result, GW_MULTI_INVALID_REQUEST, .false., 'request-contract')
      return
    end if

    allocate(checkpoints(n), predictor_candidates(n), corrector_candidates(n), predictor_results(n), corrector_results(n))
    allocate(order(n), result%tile_weighted_exchange_m(n), result%ledger_snapshots(n))
    allocate(result%diagnostics%predictor_swap(n), result%diagnostics%corrector_swap(n), &
             result%diagnostics%ledger_status(n), result%diagnostics%ledger_prepared(n), &
             result%diagnostics%swap_committed(n), result%diagnostics%ledger_committed(n))
    result%tile_weighted_exchange_m = 0.0_real64
    result%diagnostics%ledger_status = 0
    result%diagnostics%ledger_prepared = .false.
    result%diagnostics%swap_committed = .false.
    result%diagnostics%ledger_committed = .false.

    call build_canonical_tile_order(bindings, order, status)
    if (status /= GW_MULTI_OK) then
      call fail_main(result, GW_MULTI_INVALID_REQUEST, .false., 'tile-topology')
      return
    end if
    result%groundwater_cell_id = bindings(order(1))%groundwater_cell_id

    do i = 1, n
      if (.not. origins(i)%finite_and_structurally_valid()) then
        result%diagnostics%failing_tile_index = i
        call fail_main(result, GW_MULTI_INVALID_ORIGIN, .false., 'origin-structure')
        return
      end if
      if (.not. materializer%profile_admitted(parameters(i))) then
        result%diagnostics%failing_tile_index = i
        call fail_main(result, GW_MULTI_INVALID_REQUEST, .false., 'restricted-profile')
        return
      end if
      if (.not. ledgers(i)%has_identity() .or. ledgers(i)%has_active_trial() .or. ledgers(i)%has_prepared_trial()) then
        result%diagnostics%failing_tile_index = i
        call fail_main(result, GW_MULTI_INVALID_ORIGIN, .false., 'ledger-origin')
        return
      end if
    end do
    if (.not. multiswap_origins_consistent(origins, order, window)) then
      call fail_main(result, GW_MULTI_INVALID_ORIGIN, .false., 'cell-origin-consistency')
      return
    end if

    do k = 1, n
      idx = order(k)
      call committed(idx)%capture_checkpoint(checkpoints(idx), checkpoint_ok)
      if (.not. checkpoint_ok .or. .not. checkpoints(idx)%ready()) then
        result%diagnostics%failing_tile_index = idx
        call fail_main(result, GW_MULTI_SWAP_CHECKPOINT_FAILED, .true., 'swap-checkpoint')
        return
      end if
      call checkpoints(idx)%current_time(swap_time, swap_time_available)
      if (.not. swap_time_available .or. .not. same_multiswap_time(swap_time, window%t0)) then
        result%diagnostics%failing_tile_index = idx
        call fail_main(result, GW_MULTI_INVALID_ORIGIN, .false., 'swap-origin-time')
        return
      end if
      if (checkpoints(idx)%current_lineage_id() /= origins(idx)%swap_lineage_id .or. &
          checkpoints(idx)%origin_revision() /= origins(idx)%swap_revision) then
        result%diagnostics%failing_tile_index = idx
        call fail_main(result, GW_MULTI_INVALID_ORIGIN, .false., 'swap-origin-provenance')
        return
      end if
    end do

    call groundwater_capture_checkpoint(groundwater, groundwater_checkpoint, status)
    result%diagnostics%groundwater_status = status
    if (status /= GW_EXCHANGE_OK .or. .not. groundwater_checkpoint%ready()) then
      call fail_main(result, GW_MULTI_GROUNDWATER_CHECKPOINT_FAILED, .true., 'groundwater-checkpoint')
      return
    end if
    call groundwater_checkpoint%origin_time(groundwater_time, groundwater_time_available)
    if (.not. groundwater_time_available .or. .not. same_multiswap_time(groundwater_time, window%t0)) then
      call fail_main(result, GW_MULTI_INVALID_ORIGIN, .false., 'groundwater-origin-time')
      return
    end if
    do i = 1, n
      if (groundwater_checkpoint%service_id() /= origins(i)%groundwater_service_id .or. &
          groundwater_checkpoint%lineage_id() /= origins(i)%groundwater_lineage_id .or. &
          groundwater_checkpoint%origin_revision() /= origins(i)%groundwater_revision) then
        result%diagnostics%failing_tile_index = i
        call fail_main(result, GW_MULTI_INVALID_ORIGIN, .false., 'groundwater-origin-provenance')
        return
      end if
    end do

    call validate_multiswap_area_topology(bindings, origins, order, result%groundwater_cell_id, &
         result%predictor_aggregate, status)
    result%diagnostics%aggregation_status = status
    if (status /= 0) then
      call fail_main(result, GW_MULTI_INVALID_REQUEST, .false., 'tile-area-closure')
      return
    end if

    call run_multiswap_swap_phase(executor, parameters, committed, checkpoints, bindings, origins, order, &
         materializer, numerical, datum, window, origins(order(1))%accepted_h_groundwater_m, predictor_candidates, &
         predictor_results, result%diagnostics%predictor_swap, result%predictor_aggregate, failing_index, phase_status)
    if (phase_status /= GW_MULTI_PHASE_OK) then
      result%diagnostics%failing_tile_index = failing_index
      call rollback_multiswap_candidates(executor, predictor_candidates, result%diagnostics%predictor_swap)
      select case (phase_status)
      case (GW_MULTI_PHASE_FORCING_FAILED)
        call fail_main(result, GW_MULTI_PREDICTOR_FORCING_FAILED, .true., 'predictor-forcing')
      case (GW_MULTI_PHASE_AGGREGATION_FAILED)
        call fail_main(result, GW_MULTI_PREDICTOR_AGGREGATION_FAILED, .true., 'predictor-aggregation')
      case (GW_MULTI_PHASE_SWAP_FAILED, GW_MULTI_PHASE_EXCHANGE_FAILED)
        call fail_main(result, GW_MULTI_PREDICTOR_SWAP_FAILED, .true., 'predictor-swap')
      end select
      return
    end if

    call groundwater_trial_from_checkpoint(groundwater, groundwater_checkpoint, window, &
         result%predictor_aggregate%q_groundwater_area_weighted_m_per_s, predictor_groundwater_candidate, &
         predictor_groundwater_result, status)
    result%diagnostics%groundwater_status = status
    if (status /= GW_EXCHANGE_OK .or. .not. predictor_groundwater_candidate%ready()) then
      call rollback_multiswap_candidates(executor, predictor_candidates, result%diagnostics%predictor_swap)
      call fail_main(result, GW_MULTI_PREDICTOR_GROUNDWATER_FAILED, .true., 'predictor-groundwater')
      return
    end if
    result%diagnostics%predictor_groundwater_completed = .true.
    result%predictor_h_groundwater_m = predictor_groundwater_result%h_groundwater_m

    call groundwater_discard_candidate(groundwater, predictor_groundwater_candidate, cleanup_status)
    call rollback_multiswap_candidates(executor, predictor_candidates, result%diagnostics%predictor_swap)
    if (cleanup_status /= GW_EXCHANGE_OK) then
      result%diagnostics%groundwater_status = cleanup_status
      call fail_main(result, GW_MULTI_PREDICTOR_DISCARD_FAILED, .true., 'predictor-discard')
      return
    end if

    call run_multiswap_swap_phase(executor, parameters, committed, checkpoints, bindings, origins, order, &
         materializer, numerical, datum, window, result%predictor_h_groundwater_m, corrector_candidates, &
         corrector_results, result%diagnostics%corrector_swap, result%corrector_aggregate, failing_index, phase_status)
    if (phase_status /= GW_MULTI_PHASE_OK) then
      result%diagnostics%failing_tile_index = failing_index
      call rollback_multiswap_candidates(executor, corrector_candidates, result%diagnostics%corrector_swap)
      select case (phase_status)
      case (GW_MULTI_PHASE_FORCING_FAILED)
        call fail_main(result, GW_MULTI_CORRECTOR_FORCING_FAILED, .true., 'corrector-forcing')
      case (GW_MULTI_PHASE_AGGREGATION_FAILED)
        call fail_main(result, GW_MULTI_CORRECTOR_AGGREGATION_FAILED, .true., 'corrector-aggregation')
      case (GW_MULTI_PHASE_SWAP_FAILED, GW_MULTI_PHASE_EXCHANGE_FAILED)
        call fail_main(result, GW_MULTI_CORRECTOR_SWAP_FAILED, .true., 'corrector-swap')
      end select
      return
    end if

    call groundwater_trial_from_checkpoint(groundwater, groundwater_checkpoint, window, &
         result%corrector_aggregate%q_groundwater_area_weighted_m_per_s, corrector_groundwater_candidate, &
         corrector_groundwater_result, status)
    result%diagnostics%groundwater_status = status
    if (status /= GW_EXCHANGE_OK .or. .not. corrector_groundwater_candidate%ready()) then
      call rollback_multiswap_candidates(executor, corrector_candidates, result%diagnostics%corrector_swap)
      call fail_main(result, GW_MULTI_CORRECTOR_GROUNDWATER_FAILED, .true., 'corrector-groundwater')
      return
    end if
    result%diagnostics%corrector_groundwater_completed = .true.
    result%prescribed_corrector_h_swap_m = result%predictor_h_groundwater_m
    result%corrector_h_groundwater_m = corrector_groundwater_result%h_groundwater_m

    result%accepted_interface%h_swap_m = result%prescribed_corrector_h_swap_m
    result%accepted_interface%h_groundwater_m = result%corrector_h_groundwater_m
    result%accepted_interface%q_swap_m_per_s = result%corrector_aggregate%q_swap_area_weighted_m_per_s
    result%accepted_interface%q_groundwater_m_per_s = result%corrector_aggregate%q_groundwater_area_weighted_m_per_s
    call evaluate_groundwater_interface_residual(result%accepted_interface, result%residual, status)
    result%diagnostics%interface_status = status
    if (status /= GW_INTERFACE_OK .or. abs(result%residual%flux_residual_m_per_s) > 0.0_real64) then
      call discard_multiswap_groundwater_and_swap(groundwater, corrector_groundwater_candidate, cleanup_status, &
           executor, corrector_candidates, result%diagnostics%corrector_swap)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_main(result, GW_MULTI_PREPUBLICATION_ABORT_FAILED, .true., 'interface-discard')
      else
        call fail_main(result, GW_MULTI_INTERFACE_FAILED, .true., 'interface-residual')
      end if
      return
    end if

    call head_policy%evaluate(result%residual%head_residual_m, converged, status)
    result%diagnostics%policy_status = status
    result%diagnostics%head_converged = converged .and. status == GW_HEAD_POLICY_OK
    if (status /= GW_HEAD_POLICY_OK .or. .not. converged) then
      call discard_multiswap_groundwater_and_swap(groundwater, corrector_groundwater_candidate, cleanup_status, &
           executor, corrector_candidates, result%diagnostics%corrector_swap)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_main(result, GW_MULTI_PREPUBLICATION_ABORT_FAILED, .true., 'head-policy-discard')
      else if (status /= GW_HEAD_POLICY_OK) then
        call fail_main(result, GW_MULTI_INTERFACE_FAILED, .true., 'head-policy')
      else
        call fail_main(result, GW_MULTI_NOT_CONVERGED, .true., 'head-not-converged')
      end if
      return
    end if

    call publish_multiswap_cell_transaction(executor, committed, bindings, order, groundwater, groundwater_checkpoint, &
         corrector_groundwater_candidate, corrector_groundwater_result, ledgers, window, origins, corrector_candidates, &
         corrector_results, result)
  end subroutine run_restricted_groundwater_multiswap_cell_window

  subroutine fail_main(result, status, request_smaller_window, stage)
    type(groundwater_multiswap_result_t), intent(inout) :: result
    integer, intent(in) :: status
    logical, intent(in) :: request_smaller_window
    character(len=*), intent(in) :: stage

    result%status = status
    result%completed = .false.
    result%committed = .false.
    result%request_smaller_window = request_smaller_window
    result%diagnostics%failure_stage = stage
  end subroutine fail_main

end module mod_groundwater_multiswap_coupler

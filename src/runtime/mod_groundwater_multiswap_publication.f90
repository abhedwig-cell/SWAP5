module mod_groundwater_multiswap_publication
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t, kernel_executor_t, &
       kernel_result_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       groundwater_exchange_checkpoint_t, groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, &
       groundwater_exchange_trial_result_t, groundwater_prepare_candidate, groundwater_commit_prepared, &
       GW_EXCHANGE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_prepared_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, &
       GW_MULTI_OK, GW_MULTI_LEDGER_STAGE_FAILED, GW_MULTI_GROUNDWATER_PREPARE_FAILED, &
       GW_MULTI_LEDGER_PREPARE_FAILED, GW_MULTI_PUBLICATION_PREFLIGHT_FAILED, GW_MULTI_SWAP_COMMIT_FAILED, &
       GW_MULTI_PREPUBLICATION_ABORT_FAILED
  use mod_groundwater_multiswap_topology, only: stage_multiswap_tile_ledger, make_multiswap_next_origin, &
       stable_ordered_sum, committed_ledger_total, same_multiswap_mass
  use mod_groundwater_multiswap_transaction, only: multiswap_publication_preflight, &
       rollback_multiswap_candidates, discard_multiswap_groundwater_and_swap, discard_multiswap_active_ledgers, &
       abort_or_discard_multiswap_ledgers, abort_multiswap_prepared_groundwater
  implicit none
  private

  real(real64), parameter :: CM_TO_M = 0.01_real64

  public :: publish_multiswap_cell_transaction

contains

  subroutine publish_multiswap_cell_transaction(executor, committed, bindings, order, groundwater, groundwater_checkpoint, &
       groundwater_candidate, groundwater_result, ledgers, window, origins, swap_candidates, swap_results, result)
    type(kernel_executor_t), intent(inout) :: executor
    type(kernel_committed_state_t), intent(inout) :: committed(:)
    type(groundwater_direct_tile_binding_t), intent(in) :: bindings(:)
    integer, intent(in) :: order(:)
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    type(groundwater_exchange_checkpoint_t), intent(inout) :: groundwater_checkpoint
    type(groundwater_exchange_candidate_t), intent(inout) :: groundwater_candidate
    type(groundwater_exchange_trial_result_t), intent(in) :: groundwater_result
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledgers(:)
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_coupling_origin_t), intent(inout) :: origins(:)
    type(kernel_candidate_state_t), intent(inout) :: swap_candidates(:)
    type(kernel_result_t), intent(in) :: swap_results(:)
    type(groundwater_multiswap_result_t), intent(inout) :: result

    type(groundwater_exchange_prepared_t) :: prepared_groundwater
    type(groundwater_interface_mass_prepared_t), allocatable :: prepared_ledgers(:)
    type(groundwater_coupling_origin_t), allocatable :: next_origins(:)
    real(real64), allocatable :: initial_mass(:)
    real(real64) :: weighted_exchange_m, initial_total, final_total
    logical :: did_commit
    integer :: n, i, k, idx, status, cleanup_status, commit_status, committed_count

    n = size(bindings)
    allocate(prepared_ledgers(n), next_origins(n), initial_mass(n))
    initial_mass = 0.0_real64

    do i = 1, n
      call ledgers(i)%snapshot(result%ledger_snapshots(i))
      if (.not. result%ledger_snapshots(i)%available) then
        result%diagnostics%failing_tile_index = i
        call fail_publication(result, GW_MULTI_LEDGER_STAGE_FAILED, 'ledger-snapshot')
        return
      end if
      initial_mass(i) = result%ledger_snapshots(i)%committed_swap_outward_exchange_m
    end do

    do k = 1, n
      idx = order(k)
      weighted_exchange_m = bindings(idx)%area_fraction * swap_results(idx)%bottom_outward_exchange_native * CM_TO_M
      if (.not. ieee_is_finite(weighted_exchange_m)) then
        result%diagnostics%failing_tile_index = idx
        call discard_multiswap_groundwater_and_swap(groundwater, groundwater_candidate, cleanup_status, executor, &
             swap_candidates, result%diagnostics%corrector_swap)
        call fail_publication(result, GW_MULTI_LEDGER_STAGE_FAILED, 'weighted-exchange')
        return
      end if
      result%tile_weighted_exchange_m(idx) = weighted_exchange_m
      call stage_multiswap_tile_ledger(ledgers(idx), window, origins(idx), groundwater_result, weighted_exchange_m, status)
      result%diagnostics%ledger_status(idx) = status
      if (status /= GW_MASS_LEDGER_OK) then
        result%diagnostics%failing_tile_index = idx
        call discard_multiswap_active_ledgers(ledgers, result%diagnostics%ledger_status)
        call discard_multiswap_groundwater_and_swap(groundwater, groundwater_candidate, cleanup_status, executor, &
             swap_candidates, result%diagnostics%corrector_swap)
        if (cleanup_status /= GW_EXCHANGE_OK) then
          call fail_publication(result, GW_MULTI_PREPUBLICATION_ABORT_FAILED, 'ledger-stage-discard')
        else
          call fail_publication(result, GW_MULTI_LEDGER_STAGE_FAILED, 'ledger-stage')
        end if
        return
      end if
    end do
    result%accepted_cell_exchange_m = stable_ordered_sum(result%tile_weighted_exchange_m, order)

    call groundwater_prepare_candidate(groundwater, groundwater_checkpoint, groundwater_candidate, &
         prepared_groundwater, status)
    result%diagnostics%groundwater_status = status
    if (status /= GW_EXCHANGE_OK) then
      call discard_multiswap_active_ledgers(ledgers, result%diagnostics%ledger_status)
      call rollback_multiswap_candidates(executor, swap_candidates, result%diagnostics%corrector_swap)
      call fail_publication(result, GW_MULTI_GROUNDWATER_PREPARE_FAILED, 'groundwater-prepare')
      return
    end if
    result%diagnostics%groundwater_prepared = .true.

    do k = 1, n
      idx = order(k)
      call ledgers(idx)%prepare_trial(prepared_ledgers(idx), status)
      result%diagnostics%ledger_status(idx) = status
      if (status /= GW_MASS_LEDGER_OK) then
        result%diagnostics%failing_tile_index = idx
        call abort_multiswap_prepared_groundwater(groundwater, groundwater_checkpoint, prepared_groundwater, cleanup_status)
        call abort_or_discard_multiswap_ledgers(ledgers, prepared_ledgers, result%diagnostics%ledger_status)
        call rollback_multiswap_candidates(executor, swap_candidates, result%diagnostics%corrector_swap)
        if (cleanup_status /= GW_EXCHANGE_OK) then
          call fail_publication(result, GW_MULTI_PREPUBLICATION_ABORT_FAILED, 'ledger-prepare-abort')
        else
          call fail_publication(result, GW_MULTI_LEDGER_PREPARE_FAILED, 'ledger-prepare')
        end if
        return
      end if
      result%diagnostics%ledger_prepared(idx) = .true.
    end do

    do i = 1, n
      call make_multiswap_next_origin(origins(i), window, committed(i), groundwater_result, next_origins(i), status)
      if (status /= GW_MULTI_OK) then
        result%diagnostics%failing_tile_index = i
        call abort_multiswap_prepared_groundwater(groundwater, groundwater_checkpoint, prepared_groundwater, cleanup_status)
        call abort_or_discard_multiswap_ledgers(ledgers, prepared_ledgers, result%diagnostics%ledger_status)
        call rollback_multiswap_candidates(executor, swap_candidates, result%diagnostics%corrector_swap)
        call fail_publication(result, GW_MULTI_PUBLICATION_PREFLIGHT_FAILED, 'next-origin')
        return
      end if
    end do

    if (.not. multiswap_publication_preflight(committed, swap_candidates, window, groundwater_checkpoint, &
         prepared_groundwater, ledgers, prepared_ledgers, next_origins)) then
      call abort_multiswap_prepared_groundwater(groundwater, groundwater_checkpoint, prepared_groundwater, cleanup_status)
      call abort_or_discard_multiswap_ledgers(ledgers, prepared_ledgers, result%diagnostics%ledger_status)
      call rollback_multiswap_candidates(executor, swap_candidates, result%diagnostics%corrector_swap)
      if (cleanup_status /= GW_EXCHANGE_OK) then
        call fail_publication(result, GW_MULTI_PREPUBLICATION_ABORT_FAILED, 'publication-preflight-abort')
      else
        call fail_publication(result, GW_MULTI_PUBLICATION_PREFLIGHT_FAILED, 'publication-preflight')
      end if
      return
    end if
    result%diagnostics%publication_preflight_passed = .true.

    committed_count = 0
    do k = 1, n
      idx = order(k)
      call executor%commit_candidate(committed(idx), swap_candidates(idx), result%diagnostics%corrector_swap(idx), &
           did_commit, commit_status)
      if (.not. did_commit .or. commit_status /= KERNEL_COMMIT_STATUS_COMMITTED) then
        result%diagnostics%failing_tile_index = idx
        if (committed_count > 0) then
          error stop 'F-GC25 atomic cell publication invariant: late SWAP commit failed after prior tile publication'
        end if
        call abort_multiswap_prepared_groundwater(groundwater, groundwater_checkpoint, prepared_groundwater, cleanup_status)
        call abort_or_discard_multiswap_ledgers(ledgers, prepared_ledgers, result%diagnostics%ledger_status)
        call rollback_multiswap_candidates(executor, swap_candidates, result%diagnostics%corrector_swap)
        if (cleanup_status /= GW_EXCHANGE_OK) then
          call fail_publication(result, GW_MULTI_PREPUBLICATION_ABORT_FAILED, 'swap-commit-abort')
        else
          call fail_publication(result, GW_MULTI_SWAP_COMMIT_FAILED, 'swap-commit')
        end if
        return
      end if
      committed_count = committed_count + 1
      result%diagnostics%swap_committed(idx) = .true.
    end do

    call groundwater_commit_prepared(groundwater, groundwater_checkpoint, prepared_groundwater, status)
    if (status /= GW_EXCHANGE_OK) then
      error stop 'F-GC25 atomic cell publication invariant: groundwater commit failed after SWAP tile publication'
    end if
    result%diagnostics%groundwater_status = status
    result%diagnostics%groundwater_committed = .true.

    do k = 1, n
      idx = order(k)
      call ledgers(idx)%commit_prepared(prepared_ledgers(idx))
      result%diagnostics%ledger_committed(idx) = .true.
    end do
    origins = next_origins

    do i = 1, n
      call ledgers(i)%snapshot(result%ledger_snapshots(i))
      if (.not. result%ledger_snapshots(i)%available .or. &
          abs(result%ledger_snapshots(i)%conservation_residual_m) > 0.0_real64) then
        error stop 'F-GC25 hard mass invariant: committed tile interface ledger is not exactly conservative'
      end if
    end do
    initial_total = stable_ordered_sum(initial_mass, order)
    final_total = committed_ledger_total(result%ledger_snapshots, order)
    result%committed_ledger_increment_m = final_total - initial_total
    if (.not. same_multiswap_mass(result%committed_ledger_increment_m, result%accepted_cell_exchange_m)) then
      error stop 'F-GC25 hard mass invariant: cell ledger increment differs from accepted area-weighted transfer'
    end if

    result%status = GW_MULTI_OK
    result%completed = .true.
    result%committed = .true.
    result%request_smaller_window = .false.
    result%diagnostics%route = 'restricted-multiswap-pc1-committed'
    result%diagnostics%failure_stage = 'none'
  end subroutine publish_multiswap_cell_transaction

  subroutine fail_publication(result, status, stage)
    type(groundwater_multiswap_result_t), intent(inout) :: result
    integer, intent(in) :: status
    character(len=*), intent(in) :: stage

    result%status = status
    result%completed = .false.
    result%committed = .false.
    result%request_smaller_window = .true.
    result%diagnostics%failure_stage = stage
  end subroutine fail_publication

end module mod_groundwater_multiswap_publication

module mod_groundwater_multiswap_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t, kernel_executor_t, &
       kernel_diagnostics_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       groundwater_exchange_checkpoint_t, groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, &
       groundwater_discard_candidate, groundwater_abort_prepared, GW_EXCHANGE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_prepared_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_topology, only: same_multiswap_time
  implicit none
  private

  public :: multiswap_publication_preflight
  public :: rollback_multiswap_candidates
  public :: discard_multiswap_groundwater_and_swap
  public :: discard_multiswap_active_ledgers
  public :: abort_or_discard_multiswap_ledgers
  public :: abort_multiswap_prepared_groundwater

contains

  logical function multiswap_publication_preflight(committed, candidates, window, groundwater_checkpoint, &
       prepared_groundwater, ledgers, prepared_ledgers, next_origins) result(ready)
    type(kernel_committed_state_t), intent(in) :: committed(:)
    type(kernel_candidate_state_t), intent(in) :: candidates(:)
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_exchange_checkpoint_t), intent(in) :: groundwater_checkpoint
    type(groundwater_exchange_prepared_t), intent(in) :: prepared_groundwater
    type(groundwater_interface_mass_ledger_t), intent(in) :: ledgers(:)
    type(groundwater_interface_mass_prepared_t), intent(in) :: prepared_ledgers(:)
    type(groundwater_coupling_origin_t), intent(in) :: next_origins(:)

    type(groundwater_coupling_window_t) :: prepared_window
    real(real64) :: committed_time, candidate_t0, candidate_t1
    logical :: committed_time_available, interval_available, prepared_window_available
    integer(int64) :: current_revision
    integer :: i

    ready = .false.
    if (size(committed) /= size(candidates)) return
    if (size(committed) /= size(ledgers)) return
    if (size(committed) /= size(prepared_ledgers)) return
    if (size(committed) /= size(next_origins)) return

    do i = 1, size(committed)
      if (.not. committed(i)%ready()) return
      if (.not. candidates(i)%ready()) return
      current_revision = committed(i)%current_revision()
      if (current_revision < 0_int64) return
      if (current_revision >= huge(0_int64)) return
      if (candidates(i)%current_lineage_id() /= committed(i)%current_lineage_id()) return
      if (candidates(i)%origin_revision() /= current_revision) return
      call committed(i)%current_time(committed_time, committed_time_available)
      if (.not. committed_time_available) return
      if (.not. same_multiswap_time(committed_time, window%t0)) return
      call candidates(i)%origin_interval(candidate_t0, candidate_t1, interval_available)
      if (.not. interval_available) return
      if (.not. same_multiswap_time(candidate_t0, window%t0)) return
      if (.not. same_multiswap_time(candidate_t1, window%t1)) return
      if (.not. ledgers(i)%prepared_ready_for_commit(prepared_ledgers(i))) return
      if (.not. next_origins(i)%finite_and_structurally_valid()) return
      if (.not. same_multiswap_time(next_origins(i)%accepted_time, window%t1)) return
      if (next_origins(i)%swap_revision /= current_revision + 1_int64) return
    end do

    if (.not. groundwater_checkpoint%ready()) return
    if (.not. groundwater_checkpoint%is_prepared()) return
    if (.not. prepared_groundwater%ready()) return
    if (prepared_groundwater%service_id() /= groundwater_checkpoint%service_id()) return
    if (prepared_groundwater%lineage_id() /= groundwater_checkpoint%lineage_id()) return
    if (prepared_groundwater%origin_revision() /= groundwater_checkpoint%origin_revision()) return
    call prepared_groundwater%origin_window(prepared_window, prepared_window_available)
    if (.not. prepared_window_available) return
    if (.not. same_multiswap_time(prepared_window%t0, window%t0)) return
    if (.not. same_multiswap_time(prepared_window%t1, window%t1)) return
    do i = 1, size(next_origins)
      if (next_origins(i)%groundwater_revision /= prepared_groundwater%candidate_revision()) return
    end do
    ready = .true.
  end function multiswap_publication_preflight

  subroutine rollback_multiswap_candidates(executor, candidates, diagnostics)
    type(kernel_executor_t), intent(inout) :: executor
    type(kernel_candidate_state_t), intent(inout) :: candidates(:)
    type(kernel_diagnostics_t), intent(inout) :: diagnostics(:)
    integer :: i

    do i = 1, size(candidates)
      if (candidates(i)%ready()) call executor%rollback_candidate(candidates(i), diagnostics(i))
    end do
  end subroutine rollback_multiswap_candidates

  subroutine discard_multiswap_groundwater_and_swap(groundwater, groundwater_candidate, groundwater_status, &
       executor, candidates, diagnostics)
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    type(groundwater_exchange_candidate_t), intent(inout) :: groundwater_candidate
    integer, intent(out) :: groundwater_status
    type(kernel_executor_t), intent(inout) :: executor
    type(kernel_candidate_state_t), intent(inout) :: candidates(:)
    type(kernel_diagnostics_t), intent(inout) :: diagnostics(:)

    groundwater_status = GW_EXCHANGE_OK
    if (groundwater_candidate%ready()) then
      call groundwater_discard_candidate(groundwater, groundwater_candidate, groundwater_status)
    end if
    call rollback_multiswap_candidates(executor, candidates, diagnostics)
  end subroutine discard_multiswap_groundwater_and_swap

  subroutine discard_multiswap_active_ledgers(ledgers, ledger_status)
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledgers(:)
    integer, intent(inout) :: ledger_status(:)
    integer :: i, status

    do i = 1, size(ledgers)
      if (ledgers(i)%has_active_trial()) then
        call ledgers(i)%discard_trial(status)
        ledger_status(i) = status
      end if
    end do
  end subroutine discard_multiswap_active_ledgers

  subroutine abort_or_discard_multiswap_ledgers(ledgers, prepared, ledger_status)
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledgers(:)
    type(groundwater_interface_mass_prepared_t), intent(inout) :: prepared(:)
    integer, intent(inout) :: ledger_status(:)
    integer :: i, status

    do i = 1, size(ledgers)
      if (prepared(i)%ready()) then
        if (ledgers(i)%has_prepared_trial()) then
          call ledgers(i)%abort_prepared(prepared(i))
          ledger_status(i) = GW_MASS_LEDGER_OK
          cycle
        end if
      end if
      if (ledgers(i)%has_active_trial()) then
        call ledgers(i)%discard_trial(status)
        ledger_status(i) = status
      end if
    end do
  end subroutine abort_or_discard_multiswap_ledgers

  subroutine abort_multiswap_prepared_groundwater(groundwater, checkpoint, prepared, status)
    class(groundwater_preparable_exchange_service_t), intent(inout) :: groundwater
    type(groundwater_exchange_checkpoint_t), intent(inout) :: checkpoint
    type(groundwater_exchange_prepared_t), intent(inout) :: prepared
    integer, intent(out) :: status

    status = GW_EXCHANGE_OK
    if (.not. prepared%ready()) return
    if (.not. checkpoint%is_prepared()) return
    call groundwater_abort_prepared(groundwater, checkpoint, prepared, status)
  end subroutine abort_multiswap_prepared_groundwater

end module mod_groundwater_multiswap_transaction

module mod_fmr_wofost_crop_event_lifecycle
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_crop_event_token_t, fmr_wofost_crop_event_identity_t, &
       prepare_wofost_crop_event_delivery, identify_wofost_crop_event, &
       commit_wofost_crop_event_delivery, FMR_WOFOST_LINEAGE_OK
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t
  implicit none
  private

  integer, parameter, public :: FMR_WOF39_OK = 0
  integer, parameter, public :: FMR_WOF39_INVALID_WINDOW = 1
  integer, parameter, public :: FMR_WOF39_INVALID_COMMITTED_STATE = 2
  integer, parameter, public :: FMR_WOF39_NO_MATCHING_COMMITTED_RECEIPT = 3
  integer, parameter, public :: FMR_WOF39_RETIREMENT_REJECTED = 4
  integer, parameter, public :: FMR_WOF39_ALREADY_RETIRED = 5

  public :: reconcile_committed_crop_event_receipt

contains

  ! Reconcile one complete source accepted window with crop publication that
  ! has already been committed atomically by F-KT/F-WOF38. This operation is
  ! deliberately derived lifecycle housekeeping. It never publishes crop
  ! physics and cannot mutate the committed F-KT carrier, crop owner, receipt,
  ! lineage, revision, or committed time.
  !
  ! No matching committed receipt means zero window mutation. A matching
  ! receipt authorizes only the existing validated legacy delivery-token path,
  ! which retires event_delivered/cache state so event_due becomes false.
  subroutine reconcile_committed_crop_event_receipt(window, committed_crop, retired, status)
    type(fmr_wofost_accepted_window_t), intent(inout) :: window
    type(kernel_committed_state_t), intent(in) :: committed_crop
    logical, intent(out) :: retired
    integer, intent(out) :: status
    type(fmr_wofost_crop_event_token_t) :: token
    type(fmr_wofost_crop_event_identity_t) :: identity
    class(transaction_state_t), allocatable :: committed_snapshot
    logical :: event_available, snapshot_available
    integer :: lineage_status

    retired = .false.
    status = FMR_WOF39_INVALID_WINDOW
    if (.not. window%ready()) return

    ! Idempotent replay is a strict no-op. Do not require a new crop snapshot
    ! after retirement because the legacy cache is already in its terminal
    ! state and carries no publication authority.
    if (window%delivery_committed()) then
      status = FMR_WOF39_ALREADY_RETIRED
      return
    end if
    if (.not. window%complete()) return

    status = FMR_WOF39_INVALID_COMMITTED_STATE
    if (.not. committed_crop%ready()) return

    ! Freeze the exact source event identity without mutating the window.
    call prepare_wofost_crop_event_delivery(window, token=token, available=event_available, &
         status=lineage_status, aggregates=unused_aggregates())
    if (lineage_status /= FMR_WOFOST_LINEAGE_OK .or. .not. event_available .or. .not. token%ready()) then
      status = FMR_WOF39_RETIREMENT_REJECTED
      return
    end if
    call identify_wofost_crop_event(token, identity, lineage_status)
    if (lineage_status /= FMR_WOFOST_LINEAGE_OK .or. .not. identity%ready()) then
      status = FMR_WOF39_RETIREMENT_REJECTED
      return
    end if

    ! Snapshot is a clone. The authoritative committed carrier is intent(in)
    ! and therefore cannot be changed by lifecycle reconciliation.
    call committed_crop%snapshot(committed_snapshot, snapshot_available)
    if (.not. snapshot_available) return

    status = FMR_WOF39_NO_MATCHING_COMMITTED_RECEIPT
    select type (crop_state => committed_snapshot)
    type is (fmr_wofost_crop_transaction_state_t)
      if (.not. crop_state%ready()) then
        status = FMR_WOF39_INVALID_COMMITTED_STATE
        return
      end if
      if (.not. crop_state%receipt_ready()) return
      if (.not. crop_state%consumed_event(identity)) return
    class default
      status = FMR_WOF39_INVALID_COMMITTED_STATE
      return
    end select

    call commit_wofost_crop_event_delivery(window, token, lineage_status)
    if (lineage_status /= FMR_WOFOST_LINEAGE_OK) then
      status = FMR_WOF39_RETIREMENT_REJECTED
      return
    end if

    retired = .true.
    status = FMR_WOF39_OK
  end subroutine reconcile_committed_crop_event_receipt

  ! Small helper only to satisfy the existing delivery-token constructor while
  ! keeping lifecycle code uninterested in the aggregate payload itself.
  function unused_aggregates() result(value)
    use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t
    type(wofost_accepted_window_aggregates_t) :: value
    value = wofost_accepted_window_aggregates_t()
  end function unused_aggregates

end module mod_fmr_wofost_crop_event_lifecycle

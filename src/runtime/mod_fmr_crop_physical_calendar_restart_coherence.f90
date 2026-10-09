module mod_fmr_crop_physical_calendar_restart_coherence
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_rotation_calendar, only: crop_calendar_t, CROP_CAL_OK, CROP_CAL_OUTSIDE
  use mod_crop_rotation_transition, only: crop_rotation_checkpoint_t
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t, &
       fmr_wofost_crop_transaction_persistence_t
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_crop_event_identity_t, &
       reconstruct_wofost_crop_event_identity_from_persistence, FMR_WOFOST_LINEAGE_OK
  implicit none
  private
  integer, parameter, public :: CROP_RESTART_PAIR_OK=0
  integer, parameter, public :: CROP_RESTART_PAIR_INVALID=1
  integer, parameter, public :: CROP_RESTART_PAIR_TIME=2
  integer, parameter, public :: CROP_RESTART_PAIR_CALENDAR=3
  integer, parameter, public :: CROP_RESTART_PAIR_RECEIPT=4
  public :: validate_committed_crop_calendar_restart_pair
contains
  ! Read-only post-event gate: this does not serialize or publish a crop, and
  ! cannot turn a derived calendar checkpoint into a physical crop transition.
  ! Only the active-crop, exactly contemporaneous receipt boundary is covered.
  subroutine validate_committed_crop_calendar_restart_pair(committed, view, calendar, &
       checkpoint, status)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_wofost_crop_transaction_persistence_t), intent(in) :: view
    type(crop_calendar_t), intent(in) :: calendar
    type(crop_rotation_checkpoint_t), intent(in) :: checkpoint
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: snapshot
    type(fmr_wofost_crop_event_identity_t) :: identity
    real(real64) :: physical_time
    integer :: crop, calendar_status, identity_status
    logical :: available, active, begins

    status=CROP_RESTART_PAIR_INVALID
    if(.not.committed%ready().or..not.committed%time_is_bound()) return
    if(.not.view%ready().or..not.view%lifecycle_present.or..not.view%receipt_present) return
    if(.not.calendar%ready().or..not.checkpoint%ready()) return

    call committed%current_time(physical_time,available)
    if(.not.available) return
    if(transfer(physical_time,0_int64)/=transfer(checkpoint%time(),0_int64)) then
      status=CROP_RESTART_PAIR_TIME
      return
    end if
    if(transfer(physical_time,0_int64)/=transfer(view%receipt%t1,0_int64)) then
      status=CROP_RESTART_PAIR_TIME
      return
    end if

    call calendar%select_at(physical_time,crop,active,begins,calendar_status)
    status=CROP_RESTART_PAIR_CALENDAR
    if(calendar_status/=CROP_CAL_OK.and.calendar_status/=CROP_CAL_OUTSIDE) return
    ! A fallow, harvest or direct crop switch needs its own source-bound
    ! teardown/initialization authority and is deliberately not covered.
    if(.not.active.or.crop<=0) return
    if(crop/=checkpoint%crop()) return

    call reconstruct_wofost_crop_event_identity_from_persistence(view%receipt,identity,identity_status)
    status=CROP_RESTART_PAIR_RECEIPT
    if(identity_status/=FMR_WOFOST_LINEAGE_OK.or..not.identity%ready()) return
    call committed%snapshot(snapshot,available)
    if(.not.available) return
    select type (physical=>snapshot)
    type is (fmr_wofost_crop_transaction_state_t)
      if(.not.physical%ready()) return
      if(.not.physical%consumed_event(identity)) return
    class default
      return
    end select
    status=CROP_RESTART_PAIR_OK
  end subroutine
end module

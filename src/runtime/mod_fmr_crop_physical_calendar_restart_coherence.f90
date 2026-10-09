module mod_fmr_crop_physical_calendar_restart_coherence
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_rotation_calendar, only: crop_calendar_t, CROP_CAL_OK, CROP_CAL_OUTSIDE
  use mod_crop_rotation_transition, only: crop_rotation_checkpoint_t, &
       crop_rotation_checkpoint_persistence_t, export_crop_rotation_checkpoint_persistence, &
       reconstruct_crop_rotation_checkpoint_persistence, ROT_TRANS_OK
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t, &
       fmr_wofost_crop_transaction_persistence_t, &
       reconstruct_fmr_wofost_crop_transaction_from_persistence, FMR_WOFOST_CROP_PERSISTENCE_OK
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_crop_event_identity_t, &
       reconstruct_wofost_crop_event_identity_from_persistence, FMR_WOFOST_LINEAGE_OK
  implicit none
  private
  integer, parameter, public :: CROP_RESTART_PAIR_OK=0
  integer, parameter, public :: CROP_RESTART_PAIR_INVALID=1
  integer, parameter, public :: CROP_RESTART_PAIR_TIME=2
  integer, parameter, public :: CROP_RESTART_PAIR_CALENDAR=3
  integer, parameter, public :: CROP_RESTART_PAIR_RECEIPT=4
  type, public :: fmr_crop_physical_calendar_restart_bundle_t
    logical :: valid=.false.
    integer(int64) :: fkt_lineage=0_int64
    integer(int64) :: fkt_revision=-1_int64
    real(real64) :: accepted_time=0.0_real64
    type(fmr_wofost_crop_transaction_persistence_t) :: crop
    type(crop_rotation_checkpoint_persistence_t) :: calendar
  contains
    procedure :: ready => crop_restart_bundle_ready
  end type
  public :: validate_committed_crop_calendar_restart_pair
  public :: export_committed_crop_calendar_restart_bundle
  public :: reconstruct_committed_crop_calendar_restart_bundle
contains
  logical function crop_restart_bundle_ready(self) result(ready)
    class(fmr_crop_physical_calendar_restart_bundle_t), intent(in) :: self
    ready=.false.
    if(.not.self%valid.or.self%fkt_lineage<=0_int64.or.self%fkt_revision<0_int64) return
    if(.not.self%crop%ready().or..not.self%calendar%ready()) return
    if(.not.self%crop%receipt_present.or..not.self%crop%lifecycle_present) return
    if(transfer(self%accepted_time,0_int64)/=transfer(self%calendar%time,0_int64)) return
    if(transfer(self%accepted_time,0_int64)/=transfer(self%crop%receipt%t1,0_int64)) return
    ready=.true.
  end function

  ! Export a coherent, serialization-neutral pair only from one already
  ! accepted F-KT physical receipt and one matching derived calendar.
  subroutine export_committed_crop_calendar_restart_bundle(committed,view,calendar,checkpoint, &
       bundle,status)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_wofost_crop_transaction_persistence_t), intent(in) :: view
    type(crop_calendar_t), intent(in) :: calendar
    type(crop_rotation_checkpoint_t), intent(in) :: checkpoint
    type(fmr_crop_physical_calendar_restart_bundle_t), intent(out) :: bundle
    integer, intent(out) :: status
    logical :: exported,available
    real(real64) :: time
    bundle=fmr_crop_physical_calendar_restart_bundle_t()
    call validate_committed_crop_calendar_restart_pair(committed,view,calendar,checkpoint,status)
    if(status/=CROP_RESTART_PAIR_OK) return
    call export_crop_rotation_checkpoint_persistence(checkpoint,bundle%calendar,exported)
    status=CROP_RESTART_PAIR_INVALID
    if(.not.exported) return
    call committed%current_time(time,available)
    if(.not.available) return
    bundle%crop=view
    bundle%accepted_time=time
    bundle%fkt_revision=committed%current_revision()
    bundle%fkt_lineage=committed%current_lineage_id()
    bundle%valid=.true.
    if(.not.bundle%ready()) then
      bundle=fmr_crop_physical_calendar_restart_bundle_t()
      return
    end if
    status=CROP_RESTART_PAIR_OK
  end subroutine

  ! The F-KT carrier is independently reconstructed by its owning runtime.
  ! This routine validates the supplied carrier and rebuilds only its paired
  ! crop and derived calendar views; it never commits to F-KT.
  subroutine reconstruct_committed_crop_calendar_restart_bundle(bundle,calendar,committed, &
       crop_state,checkpoint,status)
    type(fmr_crop_physical_calendar_restart_bundle_t), intent(in) :: bundle
    type(crop_calendar_t), intent(in) :: calendar
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_wofost_crop_transaction_state_t), intent(out) :: crop_state
    type(crop_rotation_checkpoint_t), intent(out) :: checkpoint
    integer, intent(out) :: status
    type(fmr_wofost_crop_transaction_state_t) :: trial_crop
    type(crop_rotation_checkpoint_t) :: trial_calendar
    real(real64) :: time
    logical :: available,reconstructed
    integer :: crop_status,calendar_status
    crop_state=fmr_wofost_crop_transaction_state_t()
    checkpoint=crop_rotation_checkpoint_t()
    status=CROP_RESTART_PAIR_INVALID
    if(.not.bundle%ready().or..not.committed%ready().or..not.committed%time_is_bound()) return
    if(bundle%fkt_revision/=committed%current_revision()) return
    if(bundle%fkt_lineage/=committed%current_lineage_id()) return
    call committed%current_time(time,available)
    if(.not.available) return
    if(transfer(time,0_int64)/=transfer(bundle%accepted_time,0_int64)) then
      status=CROP_RESTART_PAIR_TIME
      return
    end if
    call reconstruct_crop_rotation_checkpoint_persistence(calendar,bundle%calendar, &
         trial_calendar,calendar_status)
    status=CROP_RESTART_PAIR_CALENDAR
    if(calendar_status/=ROT_TRANS_OK) return
    call reconstruct_fmr_wofost_crop_transaction_from_persistence(bundle%crop, &
         trial_crop,reconstructed,crop_status)
    status=CROP_RESTART_PAIR_RECEIPT
    if(crop_status/=FMR_WOFOST_CROP_PERSISTENCE_OK.or..not.reconstructed) return
    call validate_committed_crop_calendar_restart_pair(committed,bundle%crop,calendar, &
         trial_calendar,status)
    if(status/=CROP_RESTART_PAIR_OK) return
    crop_state=trial_crop
    checkpoint=trial_calendar
  end subroutine

  ! Read-only post-event gate
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

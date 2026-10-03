module mod_fmr_interception_source_window_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_interception_source_window_runtime, only: interception_source_window_t, interception_progress_t, &
       interception_trial_t, interception_restart_t, initialize_interception_window, &
       initialize_interception_progress, prepare_interception_trial, accept_interception_trial, &
       export_interception_restart, restore_interception_restart, INTWIN_OK
  implicit none
  private

  integer, parameter, public :: FMR_INTWIN_OK = 0
  integer, parameter, public :: FMR_INTWIN_INVALID_OWNER = 1
  integer, parameter, public :: FMR_INTWIN_INVALID_RESULT = 2
  integer, parameter, public :: FMR_INTWIN_RESULT_ID_MISMATCH = 3
  integer, parameter, public :: FMR_INTWIN_RESULT_TIME_MISMATCH = 4
  integer, parameter, public :: FMR_INTWIN_NO_ACCEPTED_COMMIT = 5
  integer, parameter, public :: FMR_INTWIN_RUNTIME_REJECTED = 6
  integer, parameter, public :: FMR_INTWIN_RESTART_MISMATCH = 7
  integer, parameter :: FMR_INTWIN_RESTART_SCHEMA = 1

  ! Runtime-owned provenance/progress. This is deliberately outside physical
  ! FMR state; the host persists it alongside the matching committed restart.
  type, public :: fmr_interception_source_window_t
    private
    logical :: initialized = .false.
    integer(int64) :: column_id = 0_int64
    type(interception_source_window_t) :: window
    type(interception_progress_t) :: progress
    logical :: trial_pending = .false.
    real(real64) :: requested_t1 = 0.0_real64
    type(interception_trial_t) :: pending_trial
  end type fmr_interception_source_window_t

  ! Serialization-neutral companion record. committed_time must match the
  ! accepted source-window endpoint and the corresponding FMR restart record.
  type, public :: fmr_interception_source_window_restart_t
    integer :: schema_version = 0
    integer(int64) :: column_id = 0_int64
    real(real64) :: committed_time = 0.0_real64
    type(interception_restart_t) :: source_window
  end type fmr_interception_source_window_restart_t

  public :: initialize_fmr_interception_source_window
  public :: prepare_fmr_interception_source_window_trial
  public :: accept_fmr_interception_source_window_result
  public :: fmr_interception_source_window_progress
  public :: export_fmr_interception_source_window_restart
  public :: restore_fmr_interception_source_window

contains

  subroutine initialize_fmr_interception_source_window(column_id, window_id, t0, t1, aggregate, owner, status)
    integer(int64), intent(in) :: column_id, window_id
    real(real64), intent(in) :: t0, t1, aggregate
    type(fmr_interception_source_window_t), intent(out) :: owner
    integer, intent(out) :: status
    integer :: runtime_status

    owner = fmr_interception_source_window_t()
    status = FMR_INTWIN_INVALID_OWNER
    if (column_id <= 0_int64) return
    call initialize_interception_window(window_id, t0, t1, aggregate, owner%window, runtime_status)
    if (runtime_status /= INTWIN_OK) return
    call initialize_interception_progress(owner%window, owner%progress, runtime_status)
    if (runtime_status /= INTWIN_OK) return
    owner%column_id = column_id
    owner%initialized = .true.
    status = FMR_INTWIN_OK
  end subroutine initialize_fmr_interception_source_window

  subroutine prepare_fmr_interception_source_window_trial(owner, requested_t1, amount, status)
    type(fmr_interception_source_window_t), intent(inout) :: owner
    real(real64), intent(in) :: requested_t1
    real(real64), intent(out) :: amount
    integer, intent(out) :: status
    integer :: runtime_status

    amount = 0.0_real64
    status = FMR_INTWIN_INVALID_OWNER
    if (.not. owner_ready(owner)) return
    call prepare_interception_trial(owner%window, owner%progress, requested_t1, owner%pending_trial, runtime_status)
    if (runtime_status /= INTWIN_OK) then
      status = FMR_INTWIN_RUNTIME_REJECTED
      return
    end if
    owner%requested_t1 = requested_t1
    owner%trial_pending = .true.
    amount = owner%pending_trial%apportioned_amount()
    status = FMR_INTWIN_OK
  end subroutine prepare_fmr_interception_source_window_trial

  ! Call after an FMR interval result is available. Map the result fields:
  ! column_id, requested_t0/t1, committed, accepted_substeps, initial/final
  ! revisions, and final committed time/bound. A rejected hydraulic trial
  ! cannot advance interception progress. A partially committed call advances
  ! only to its reported final committed endpoint.
  subroutine accept_fmr_interception_source_window_result(owner, column_id, requested_t0, requested_t1, &
       committed, accepted_substeps, initial_revision, final_revision, final_committed_time, &
       final_committed_time_bound, accepted_amount, status)
    type(fmr_interception_source_window_t), intent(inout) :: owner
    integer(int64), intent(in) :: column_id, initial_revision, final_revision
    real(real64), intent(in) :: requested_t0, requested_t1, final_committed_time
    integer, intent(in) :: accepted_substeps
    logical, intent(in) :: committed, final_committed_time_bound
    real(real64), intent(out) :: accepted_amount
    integer, intent(out) :: status

    real(real64) :: origin
    type(interception_trial_t) :: accepted_trial
    integer :: runtime_status

    accepted_amount = 0.0_real64
    status = FMR_INTWIN_INVALID_OWNER
    if (.not. owner_ready(owner) .or. .not. owner%trial_pending) return
    if (column_id /= owner%column_id) then
      status = FMR_INTWIN_RESULT_ID_MISMATCH
      return
    end if

    origin = owner%progress%accepted_time()
    status = FMR_INTWIN_INVALID_RESULT
    if (.not. all(ieee_is_finite([requested_t0, requested_t1, final_committed_time]))) return
    if (.not. same_time(requested_t0, origin) .or. &
        .not. same_time(requested_t1, owner%requested_t1)) then
      status = FMR_INTWIN_RESULT_TIME_MISMATCH
      return
    end if
    if (.not. committed) then
      status = FMR_INTWIN_NO_ACCEPTED_COMMIT
      return
    end if
    if (.not. final_committed_time_bound .or. accepted_substeps < 1 .or. final_revision <= initial_revision) return
    if (final_committed_time <= origin .or. final_committed_time > owner%requested_t1) return

    call prepare_interception_trial(owner%window, owner%progress, final_committed_time, accepted_trial, runtime_status)
    if (runtime_status /= INTWIN_OK) then
      status = FMR_INTWIN_RUNTIME_REJECTED
      return
    end if
    accepted_amount = accepted_trial%apportioned_amount()
    call accept_interception_trial(owner%window, accepted_trial, owner%progress, runtime_status)
    if (runtime_status /= INTWIN_OK) then
      accepted_amount = 0.0_real64
      status = FMR_INTWIN_RUNTIME_REJECTED
      return
    end if
    owner%trial_pending = .false.
    owner%pending_trial = interception_trial_t()
    owner%requested_t1 = 0.0_real64
    status = FMR_INTWIN_OK
  end subroutine accept_fmr_interception_source_window_result

  subroutine fmr_interception_source_window_progress(owner, accepted_time, accepted_amount, complete, status)
    type(fmr_interception_source_window_t), intent(in) :: owner
    real(real64), intent(out) :: accepted_time, accepted_amount
    logical, intent(out) :: complete
    integer, intent(out) :: status

    accepted_time = 0.0_real64
    accepted_amount = 0.0_real64
    complete = .false.
    status = FMR_INTWIN_INVALID_OWNER
    if (.not. owner_ready(owner)) return
    accepted_time = owner%progress%accepted_time()
    accepted_amount = owner%progress%accepted_amount(owner%window)
    complete = owner%progress%complete(owner%window)
    status = FMR_INTWIN_OK
  end subroutine fmr_interception_source_window_progress

  subroutine export_fmr_interception_source_window_restart(owner, committed_time, record, status)
    type(fmr_interception_source_window_t), intent(in) :: owner
    real(real64), intent(in) :: committed_time
    type(fmr_interception_source_window_restart_t), intent(out) :: record
    integer, intent(out) :: status
    integer :: runtime_status

    record = fmr_interception_source_window_restart_t()
    status = FMR_INTWIN_INVALID_OWNER
    if (.not. owner_ready(owner) .or. .not. ieee_is_finite(committed_time)) return
    if (.not. same_time(committed_time, owner%progress%accepted_time())) then
      status = FMR_INTWIN_RESTART_MISMATCH
      return
    end if
    call export_interception_restart(owner%window, owner%progress, record%source_window, runtime_status)
    if (runtime_status /= INTWIN_OK) then
      status = FMR_INTWIN_RUNTIME_REJECTED
      return
    end if
    record%schema_version = FMR_INTWIN_RESTART_SCHEMA
    record%column_id = owner%column_id
    record%committed_time = committed_time
    status = FMR_INTWIN_OK
  end subroutine export_fmr_interception_source_window_restart

  subroutine restore_fmr_interception_source_window(record, owner, status)
    type(fmr_interception_source_window_restart_t), intent(in) :: record
    type(fmr_interception_source_window_t), intent(out) :: owner
    integer, intent(out) :: status
    integer :: runtime_status

    owner = fmr_interception_source_window_t()
    status = FMR_INTWIN_RESTART_MISMATCH
    if (record%schema_version /= FMR_INTWIN_RESTART_SCHEMA .or. record%column_id <= 0_int64) return
    if (.not. ieee_is_finite(record%committed_time)) return
    if (.not. same_time(record%committed_time, record%source_window%accepted_until)) return
    call restore_interception_restart(record%source_window, owner%window, owner%progress, runtime_status)
    if (runtime_status /= INTWIN_OK) then
      status = FMR_INTWIN_RUNTIME_REJECTED
      return
    end if
    owner%column_id = record%column_id
    owner%initialized = .true.
    status = FMR_INTWIN_OK
  end subroutine restore_fmr_interception_source_window

  logical function owner_ready(owner) result(ready)
    type(fmr_interception_source_window_t), intent(in) :: owner
    ready = owner%initialized .and. owner%column_id > 0_int64 .and. owner%window%valid() .and. &
         owner%progress%valid_for(owner%window)
  end function owner_ready

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

end module mod_fmr_interception_source_window_binding

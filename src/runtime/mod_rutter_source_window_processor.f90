module mod_rutter_source_window_processor
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_interception_source_window_runtime, only: interception_source_window_t, interception_progress_t, &
       interception_trial_t, interception_restart_t, INTWIN_OK, initialize_interception_progress, &
       prepare_interception_trial, accept_interception_trial, export_interception_restart, &
       restore_interception_restart
  use mod_rutter_interception_process, only: rutter_state_t, rutter_interval_input_t, &
       rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK
  use mod_rutter_event_integrator, only: evaluate_rutter_forcing_interval
  implicit none
  private

  integer, parameter, public :: RUTTER_WINDOW_OK = 0
  integer, parameter, public :: RUTTER_WINDOW_INVALID = 1
  integer, parameter, public :: RUTTER_WINDOW_REJECTED = 2
  integer, parameter, public :: RUTTER_WINDOW_ORDER = 3
  integer, parameter, public :: RUTTER_WINDOW_RESTART_SCHEMA = 1

  type, public :: rutter_source_state_t
    private
    type(rutter_state_t) :: canopy
    type(interception_source_window_t) :: window
    type(interception_progress_t) :: progress
  contains
    procedure, public :: canopy_storage => source_canopy_storage
    procedure, public :: accepted_until => source_accepted_until
    procedure, public :: source_window_initialized => source_window_initialized
    procedure, public :: same_source_candidate => source_same_candidate
  end type

  type, public :: rutter_source_trial_t
    private
    logical :: ready = .false.
    real(real64) :: origin_canopy_storage = 0.0_real64
    real(real64) :: candidate_canopy_storage = 0.0_real64
    type(interception_trial_t) :: source_progress_trial
  end type

  type, public :: rutter_source_restart_t
    integer :: schema = 0
    real(real64) :: canopy_storage_cm = 0.0_real64
    type(interception_restart_t) :: source_progress
  end type

  public :: initialize_rutter_source_state, initialize_rutter_canopy_state, prepare_rutter_source_trial
  public :: accept_rutter_source_trial, export_rutter_source_restart, restore_rutter_source_restart

contains

  subroutine initialize_rutter_source_state(window, canopy_storage_cm, state, status)
    type(interception_source_window_t), intent(in) :: window
    real(real64), intent(in) :: canopy_storage_cm
    type(rutter_source_state_t), intent(out) :: state
    integer, intent(out) :: status
    state = rutter_source_state_t()
    status = RUTTER_WINDOW_INVALID
    if (.not. window%valid() .or. .not. ieee_is_finite(canopy_storage_cm) .or. canopy_storage_cm < 0.0_real64) return
    state%canopy%canopy_storage_cm = canopy_storage_cm
    state%window = window
    call initialize_interception_progress(window, state%progress, status)
    if (status /= INTWIN_OK) state = rutter_source_state_t()
  end subroutine initialize_rutter_source_state

  subroutine initialize_rutter_canopy_state(canopy_storage_cm, state, status)
    real(real64), intent(in) :: canopy_storage_cm
    type(rutter_source_state_t), intent(out) :: state
    integer, intent(out) :: status
    state = rutter_source_state_t()
    status = RUTTER_WINDOW_INVALID
    if (.not. ieee_is_finite(canopy_storage_cm) .or. canopy_storage_cm < 0.0_real64) return
    state%canopy%canopy_storage_cm = canopy_storage_cm
    status = RUTTER_WINDOW_OK
  end subroutine initialize_rutter_canopy_state

  subroutine prepare_rutter_source_trial(window, accepted_state, endpoint, forcing_template, result, trial, &
                                         diagnostics, status)
    type(interception_source_window_t), intent(in) :: window
    type(rutter_source_state_t), intent(in) :: accepted_state
    real(real64), intent(in) :: endpoint
    type(rutter_interval_input_t), intent(in) :: forcing_template
    type(rutter_interval_result_t), intent(out) :: result
    type(rutter_source_trial_t), intent(out) :: trial
    type(rutter_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status
    type(interception_trial_t) :: source_trial
    type(interception_progress_t) :: source_progress
    type(rutter_interval_input_t) :: interval_input
    real(real64) :: interval_days, rain_amount

    result = rutter_interval_result_t()
    trial = rutter_source_trial_t()
    diagnostics = rutter_diagnostics_t()
    status = RUTTER_WINDOW_INVALID
    if (.not. window%valid()) return
    source_progress = accepted_state%progress
    if (.not. source_progress%valid_for(window)) then
      if (.not. accepted_state%window%valid()) then
        status = RUTTER_WINDOW_REJECTED
        return
      end if
      if (.not. accepted_state%progress%valid_for(accepted_state%window) .or. &
          .not. accepted_state%progress%complete(accepted_state%window)) then
        status = RUTTER_WINDOW_REJECTED
        return
      end if
      call initialize_interception_progress(window, source_progress, status)
      if (status /= INTWIN_OK) then
        status = RUTTER_WINDOW_REJECTED
        return
      end if
    end if
    call prepare_interception_trial(window, source_progress, endpoint, source_trial, status)
    if (status /= INTWIN_OK) then
      status = RUTTER_WINDOW_ORDER
      return
    end if

    interval_days = endpoint - source_progress%accepted_time()
    if (.not. ieee_is_finite(interval_days) .or. interval_days <= 0.0_real64) then
      status = RUTTER_WINDOW_INVALID
      return
    end if
    rain_amount = source_trial%apportioned_amount()
    interval_input = forcing_template
    interval_input%gross_rain_cm_per_day = rain_amount / interval_days
    interval_input%interval_days = interval_days
    call evaluate_rutter_forcing_interval(accepted_state%canopy, interval_input, result, diagnostics)
    if (diagnostics%status /= RUTTER_OK .or. .not. diagnostics%result_produced) then
      status = RUTTER_WINDOW_REJECTED
      return
    end if

    trial%ready = .true.
    trial%origin_canopy_storage = accepted_state%canopy%canopy_storage_cm
    trial%candidate_canopy_storage = result%candidate_state%canopy_storage_cm
    trial%source_progress_trial = source_trial
    status = RUTTER_WINDOW_OK
  end subroutine prepare_rutter_source_trial

  subroutine accept_rutter_source_trial(window, accepted_state, trial, committed_state, status)
    type(interception_source_window_t), intent(in) :: window
    type(rutter_source_state_t), intent(in) :: accepted_state
    type(rutter_source_trial_t), intent(in) :: trial
    type(rutter_source_state_t), intent(out) :: committed_state
    integer, intent(out) :: status
    type(interception_progress_t) :: candidate_progress

    committed_state = accepted_state
    status = RUTTER_WINDOW_REJECTED
    if (.not. trial%ready) return
    if (.not. same_storage(trial%origin_canopy_storage, accepted_state%canopy%canopy_storage_cm)) return
    if (.not. ieee_is_finite(trial%candidate_canopy_storage) .or. trial%candidate_canopy_storage < 0.0_real64) return
    candidate_progress = accepted_state%progress
    if (.not. candidate_progress%valid_for(window)) then
      if (.not. accepted_state%window%valid() .or. &
          .not. accepted_state%progress%valid_for(accepted_state%window) .or. &
          .not. accepted_state%progress%complete(accepted_state%window)) return
      call initialize_interception_progress(window, candidate_progress, status)
      if (status /= INTWIN_OK) return
    end if
    call accept_interception_trial(window, trial%source_progress_trial, candidate_progress, status)
    if (status /= INTWIN_OK) then
      committed_state = accepted_state
      status = RUTTER_WINDOW_ORDER
      return
    end if
    committed_state%canopy%canopy_storage_cm = trial%candidate_canopy_storage
    committed_state%window = window
    committed_state%progress = candidate_progress
    status = RUTTER_WINDOW_OK
  end subroutine accept_rutter_source_trial

  subroutine export_rutter_source_restart(window, state, record, status)
    type(interception_source_window_t), intent(in) :: window
    type(rutter_source_state_t), intent(in) :: state
    type(rutter_source_restart_t), intent(out) :: record
    integer, intent(out) :: status
    record = rutter_source_restart_t()
    status = RUTTER_WINDOW_REJECTED
    if (.not. state%progress%valid_for(window) .or. .not. ieee_is_finite(state%canopy%canopy_storage_cm) .or. &
        state%canopy%canopy_storage_cm < 0.0_real64) return
    call export_interception_restart(window, state%progress, record%source_progress, status)
    if (status /= INTWIN_OK) then
      record = rutter_source_restart_t()
      status = RUTTER_WINDOW_REJECTED
      return
    end if
    record%schema = RUTTER_WINDOW_RESTART_SCHEMA
    record%canopy_storage_cm = state%canopy%canopy_storage_cm
    status = RUTTER_WINDOW_OK
  end subroutine export_rutter_source_restart

  subroutine restore_rutter_source_restart(record, window, state, status)
    type(rutter_source_restart_t), intent(in) :: record
    type(interception_source_window_t), intent(out) :: window
    type(rutter_source_state_t), intent(out) :: state
    integer, intent(out) :: status
    type(interception_progress_t) :: progress

    window = interception_source_window_t()
    state = rutter_source_state_t()
    status = RUTTER_WINDOW_INVALID
    if (record%schema /= RUTTER_WINDOW_RESTART_SCHEMA .or. &
        .not. ieee_is_finite(record%canopy_storage_cm) .or. record%canopy_storage_cm < 0.0_real64) return
    call restore_interception_restart(record%source_progress, window, progress, status)
    if (status /= INTWIN_OK) then
      status = RUTTER_WINDOW_INVALID
      return
    end if
    state%canopy%canopy_storage_cm = record%canopy_storage_cm
    state%window = window
    state%progress = progress
    status = RUTTER_WINDOW_OK
  end subroutine restore_rutter_source_restart

  pure real(real64) function source_canopy_storage(self)
    class(rutter_source_state_t), intent(in) :: self
    source_canopy_storage = self%canopy%canopy_storage_cm
  end function source_canopy_storage

  pure real(real64) function source_accepted_until(self)
    class(rutter_source_state_t), intent(in) :: self
    source_accepted_until = self%progress%accepted_time()
  end function source_accepted_until

  pure logical function source_window_initialized(self)
    class(rutter_source_state_t), intent(in) :: self
    source_window_initialized = self%window%valid()
  end function source_window_initialized

  logical function source_same_candidate(self, other)
    class(rutter_source_state_t), intent(in) :: self
    type(rutter_source_state_t), intent(in) :: other
    type(rutter_source_restart_t) :: left, right
    integer :: left_status, right_status

    source_same_candidate = .false.
    call export_rutter_source_restart(self%window, self, left, left_status)
    call export_rutter_source_restart(other%window, other, right, right_status)
    if (left_status /= RUTTER_WINDOW_OK .or. right_status /= RUTTER_WINDOW_OK) return
    source_same_candidate = self%canopy%canopy_storage_cm == other%canopy%canopy_storage_cm .and. &
         left%schema == right%schema .and. left%source_progress%schema == right%source_progress%schema .and. &
         left%source_progress%id == right%source_progress%id .and. &
         left%source_progress%t0 == right%source_progress%t0 .and. &
         left%source_progress%t1 == right%source_progress%t1 .and. &
         left%source_progress%aggregate == right%source_progress%aggregate .and. &
         left%source_progress%accepted_until == right%source_progress%accepted_until
  end function source_same_candidate

  pure logical function same_storage(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      same_storage = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    same_storage = abs(a - b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_storage

end module mod_rutter_source_window_processor

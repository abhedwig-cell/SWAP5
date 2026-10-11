module mod_b1_10_recoverable_interval_executor
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: fillen
  use swap_exchange, only: swap_input, swap_output
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, &
       a23bu_reset_attempt_diagnostics, a23bu_reset_attempt_control
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t, begin_b1_10_trial_mass, invalidate_b1_10_trial_mass
  use mod_b1_10_interval_seam, only: b1_10_interval_seam_t, begin_b1_10_interval
  use mod_b1_10_trial_status, only: b1_10_trial_status_t, &
       B1_10_TRIAL_STATUS_SUCCESS, B1_10_TRIAL_STATUS_RETRYABLE_NUMERICAL, B1_10_TRIAL_STATUS_FATAL_CONTRACT, &
       B1_10_TRIAL_REASON_NONE, B1_10_TRIAL_REASON_RICHARDS_TERMINAL_NONCONVERGENCE, &
       B1_10_TRIAL_REASON_INVALID_INTERVAL, B1_10_TRIAL_REASON_INTERVAL_NOT_PREPARED, B1_10_TRIAL_REASON_INCOMPLETE_RETURN
  implicit none
  private

  public :: run_b1_10_recoverable_interval

  interface
    subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker, trial_mass, interval)
      use MOD_arrays, only: fillen
      use swap_exchange, only: swap_input, swap_output
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
      use mod_b1_10_interval_seam, only: b1_10_interval_seam_t
      integer, intent(in) :: iCaller, iTask
      real(8), intent(inout) :: tstart_in, tend_in
      character(len=fillen), intent(in), optional :: swp_file
      character(len=fillen), intent(in), optional :: outfile
      type(swap_input), intent(in), optional :: toswap
      type(swap_output), intent(out), optional :: fromswap
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(b1_10_trial_mass_t), intent(inout), optional :: trial_mass
      type(b1_10_interval_seam_t), intent(inout), optional :: interval
    end subroutine SWAP
  end interface

contains

  subroutine run_b1_10_recoverable_interval(t0, t1, worker, trial_mass, status)
    real(real64), intent(in) :: t0, t1
    type(a23bu_worker_context_t), intent(inout) :: worker
    type(b1_10_trial_mass_t), intent(out) :: trial_mass
    type(b1_10_trial_status_t), intent(out) :: status
    type(b1_10_interval_seam_t) :: interval
    real(real64) :: legacy_t0, legacy_t1

    status = b1_10_trial_status_t()
    trial_mass = b1_10_trial_mass_t()
    if (t1 <= t0) then
      status%code = B1_10_TRIAL_STATUS_FATAL_CONTRACT
      status%reason = B1_10_TRIAL_REASON_INVALID_INTERVAL
      return
    end if

    call a23bu_reset_attempt_diagnostics(worker)
    call a23bu_reset_attempt_control(worker)
    ! F-CI13 observes HeadCalc's existing terminal-nonconvergence marker.
    ! Reset only warning bookkeeping; macropore nstep/history remains untouched.
    worker%history%iwarn = 0
    worker%history%flwarn = .true.
    call begin_b1_10_trial_mass(trial_mass)
    call begin_b1_10_interval(interval, t0, t1)
    legacy_t0 = t0
    legacy_t1 = t1

    call SWAP(0, 22, legacy_t0, legacy_t1, worker=worker, trial_mass=trial_mass, interval=interval)
    if (.not. interval%prepared) then
      call invalidate_b1_10_trial_mass(trial_mass)
      status%code = B1_10_TRIAL_STATUS_FATAL_CONTRACT
      status%reason = B1_10_TRIAL_REASON_INTERVAL_NOT_PREPARED
      return
    end if

    call SWAP(0, 2, legacy_t0, legacy_t1, worker=worker, trial_mass=trial_mass, interval=interval)

    if (worker%history%iwarn > 0) then
      call invalidate_b1_10_trial_mass(trial_mass)
      status%code = B1_10_TRIAL_STATUS_RETRYABLE_NUMERICAL
      status%reason = B1_10_TRIAL_REASON_RICHARDS_TERMINAL_NONCONVERGENCE
      return
    end if

    if (.not. interval%complete .or. .not. trial_mass%active .or. .not. trial_mass%complete) then
      call invalidate_b1_10_trial_mass(trial_mass)
      status%code = B1_10_TRIAL_STATUS_FATAL_CONTRACT
      status%reason = B1_10_TRIAL_REASON_INCOMPLETE_RETURN
      return
    end if

    status%code = B1_10_TRIAL_STATUS_SUCCESS
    status%reason = B1_10_TRIAL_REASON_NONE
  end subroutine run_b1_10_recoverable_interval

end module mod_b1_10_recoverable_interval_executor

module mod_b1_10_physical_interval_executor
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: fillen
  use swap_exchange, only: swap_input, swap_output
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, &
       a23bu_reset_attempt_diagnostics, a23bu_reset_attempt_control
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t, begin_b1_10_trial_mass
  use mod_b1_10_interval_seam, only: b1_10_interval_seam_t, begin_b1_10_interval
  implicit none
  private

  public :: run_b1_10_physical_interval

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

  subroutine run_b1_10_physical_interval(t0, t1, worker, trial_mass, normal_return)
    real(real64), intent(in) :: t0, t1
    type(a23bu_worker_context_t), intent(inout) :: worker
    type(b1_10_trial_mass_t), intent(out) :: trial_mass
    logical, intent(out) :: normal_return
    type(b1_10_interval_seam_t) :: interval
    real(real64) :: legacy_t0, legacy_t1

    normal_return = .false.
    trial_mass = b1_10_trial_mass_t()
    if (t1 <= t0) return

    call a23bu_reset_attempt_diagnostics(worker)
    call a23bu_reset_attempt_control(worker)
    call begin_b1_10_trial_mass(trial_mass)
    call begin_b1_10_interval(interval, t0, t1)
    legacy_t0 = t0
    legacy_t1 = t1

    call SWAP(0, 22, legacy_t0, legacy_t1, worker=worker, trial_mass=trial_mass, interval=interval)
    if (.not. interval%prepared) return
    call SWAP(0, 2, legacy_t0, legacy_t1, worker=worker, trial_mass=trial_mass, interval=interval)

    normal_return = interval%complete .and. trial_mass%active .and. trial_mass%complete
  end subroutine run_b1_10_physical_interval

end module mod_b1_10_physical_interval_executor

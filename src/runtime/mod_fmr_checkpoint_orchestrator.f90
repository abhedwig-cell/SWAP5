module mod_fmr_checkpoint_orchestrator
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_executor_t, kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t
  implicit none
  private

  public :: fmr_capture_checkpoint
  public :: fmr_trial_from_checkpoint
  public :: fmr_commit_candidate
  public :: fmr_discard_candidate

contains

  subroutine fmr_capture_checkpoint(committed_state, checkpoint, ok)
    type(kernel_committed_state_t), intent(in) :: committed_state
    type(kernel_checkpoint_t), intent(out) :: checkpoint
    logical, intent(out) :: ok

    call committed_state%capture_checkpoint(checkpoint, ok)
  end subroutine fmr_capture_checkpoint

  subroutine fmr_trial_from_checkpoint(kernel, parameters, committed_state, forcing, numerical_config, &
                                       t0, t1, checkpoint, result, candidate_state, diagnostics)
    type(kernel_executor_t), intent(inout) :: kernel
    class(kernel_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed_state
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate_state
    type(kernel_diagnostics_t), intent(out) :: diagnostics

    call kernel%advance_interval(parameters, committed_state, forcing, numerical_config, t0, t1, &
         result, candidate_state, diagnostics, checkpoint)
  end subroutine fmr_trial_from_checkpoint

  subroutine fmr_commit_candidate(kernel, committed_state, candidate_state, diagnostics, did_commit, commit_status)
    type(kernel_executor_t), intent(inout) :: kernel
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(kernel_candidate_state_t), intent(inout) :: candidate_state
    type(kernel_diagnostics_t), intent(inout) :: diagnostics
    logical, intent(out) :: did_commit
    integer, intent(out), optional :: commit_status

    call kernel%commit_candidate(committed_state, candidate_state, diagnostics, did_commit, commit_status)
  end subroutine fmr_commit_candidate

  subroutine fmr_discard_candidate(kernel, candidate_state, diagnostics)
    type(kernel_executor_t), intent(inout) :: kernel
    type(kernel_candidate_state_t), intent(inout) :: candidate_state
    type(kernel_diagnostics_t), intent(inout) :: diagnostics

    call kernel%rollback_candidate(candidate_state, diagnostics)
  end subroutine fmr_discard_candidate

end module mod_fmr_checkpoint_orchestrator

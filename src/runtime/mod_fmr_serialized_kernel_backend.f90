module mod_fmr_serialized_kernel_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_canonical_interval_runtime, only: canonical_subinterval_target_selector
  use mod_kernel_transactions, only: kernel_model_t, kernel_parameters_t, kernel_committed_state_t, &
       kernel_checkpoint_t, kernel_executor_t, kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t, &
       KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_trial_from_checkpoint, &
       fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  implicit none
  private

  ! Explicit resolved-only serialized backend identity.  F-ROSS06 does not add
  ! this backend to the registry-backed MultiSWAP dispatcher; callers must bind
  ! one already-qualified kernel model explicitly at the resolved worker seam.
  integer, parameter, public :: FMR_BACKEND_SERIALIZED_INJECTED_KERNEL = 4

  integer, parameter, public :: FMR_SERIALIZED_KERNEL_OK = 0
  integer, parameter, public :: FMR_SERIALIZED_KERNEL_ROUTING_REJECTED = 1
  integer, parameter, public :: FMR_SERIALIZED_KERNEL_CHECKPOINT_FAILED = 2
  integer, parameter, public :: FMR_SERIALIZED_KERNEL_TRIAL_REJECTED = 3
  integer, parameter, public :: FMR_SERIALIZED_KERNEL_MASS_INCOMPLETE = 4
  integer, parameter, public :: FMR_SERIALIZED_KERNEL_CANDIDATE_INVALID = 5
  integer, parameter, public :: FMR_SERIALIZED_KERNEL_COMMIT_REJECTED = 6

  type, public :: fmr_serialized_kernel_execution_result_t
    integer :: status = FMR_SERIALIZED_KERNEL_ROUTING_REJECTED
    logical :: admission_assessed = .false.
    logical :: admitted = .false.
    logical :: completed = .false.
    logical :: committed = .false.
    integer :: commit_status = -1
    integer(int64) :: initial_revision = -1_int64
    integer(int64) :: final_revision = -1_int64
    real(real64) :: final_committed_time = 0.0_real64
    logical :: final_committed_time_bound = .false.
    type(kernel_result_t) :: kernel
    type(kernel_diagnostics_t) :: diagnostics
  end type fmr_serialized_kernel_execution_result_t

  type, public :: fmr_serialized_kernel_backend_t
    private
    type(kernel_executor_t) :: executor
    logical :: initialized = .false.
  contains
    procedure, public :: initialize => fmr_serialized_kernel_backend_initialize
    procedure, public :: execute => fmr_serialized_kernel_backend_execute
  end type fmr_serialized_kernel_backend_t

contains

  subroutine fmr_serialized_kernel_backend_initialize(self, model, valid)
    class(fmr_serialized_kernel_backend_t), intent(inout) :: self
    class(kernel_model_t), target, intent(inout) :: model
    logical, intent(out) :: valid

    self%initialized = .false.
    call self%executor%bind_model(model)
    self%initialized = .true.
    valid = .true.
  end subroutine fmr_serialized_kernel_backend_initialize

  subroutine fmr_serialized_kernel_backend_execute(self, column, template, parameters, forcing, committed_state, &
                                                    numerical_config, t0, t1, result, target_selector)
    class(fmr_serialized_kernel_backend_t), intent(inout) :: self
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    class(kernel_parameters_t), intent(in) :: parameters
    class(canonical_forcing_t), intent(in) :: forcing
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_kernel_execution_result_t), intent(out) :: result
    procedure(canonical_subinterval_target_selector), optional :: target_selector

    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: kernel_result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: checkpoint_ok, did_commit, time_available
    integer :: commit_status

    result = fmr_serialized_kernel_execution_result_t()
    result%initial_revision = committed_state%current_revision()

    if (.not. self%initialized .or. .not. resolved_routing_valid(column, template)) then
      result%status = FMR_SERIALIZED_KERNEL_ROUTING_REJECTED
      call capture_final_provenance(committed_state, result)
      return
    end if

    call fmr_capture_checkpoint(committed_state, checkpoint, checkpoint_ok)
    if (.not. checkpoint_ok) then
      result%status = FMR_SERIALIZED_KERNEL_CHECKPOINT_FAILED
      call capture_final_provenance(committed_state, result)
      return
    end if

    if (present(target_selector)) then
      call fmr_trial_from_checkpoint(self%executor, parameters, committed_state, forcing, numerical_config, &
           t0, t1, checkpoint, kernel_result, candidate, diagnostics, target_selector)
    else
      call fmr_trial_from_checkpoint(self%executor, parameters, committed_state, forcing, numerical_config, &
           t0, t1, checkpoint, kernel_result, candidate, diagnostics)
    end if

    result%kernel = kernel_result
    result%diagnostics = diagnostics
    result%admission_assessed = diagnostics%admission_rejections > 0 .or. &
         diagnostics%transaction_calls > 0 .or. kernel_result%completed
    result%admitted = result%admission_assessed .and. diagnostics%admission_rejections == 0 .and. &
         kernel_result%status /= KERNEL_STATUS_NOT_ADMITTED

    if (.not. kernel_result%completed) then
      if (candidate%ready()) call fmr_discard_candidate(self%executor, candidate, diagnostics)
      result%diagnostics = diagnostics
      result%status = FMR_SERIALIZED_KERNEL_TRIAL_REJECTED
      call capture_final_provenance(committed_state, result)
      return
    end if

    if (.not. kernel_result%mass%complete .or. &
        kernel_result%mass%missing_contribution_mask /= TX_MASS_MISSING_NONE) then
      if (candidate%ready()) call fmr_discard_candidate(self%executor, candidate, diagnostics)
      result%diagnostics = diagnostics
      result%status = FMR_SERIALIZED_KERNEL_MASS_INCOMPLETE
      call capture_final_provenance(committed_state, result)
      return
    end if

    if (.not. candidate%ready()) then
      result%status = FMR_SERIALIZED_KERNEL_CANDIDATE_INVALID
      call capture_final_provenance(committed_state, result)
      return
    end if

    call fmr_commit_candidate(self%executor, committed_state, candidate, diagnostics, did_commit, commit_status)
    result%commit_status = commit_status
    result%diagnostics = diagnostics
    if (.not. did_commit) then
      if (candidate%ready()) call fmr_discard_candidate(self%executor, candidate, diagnostics)
      result%diagnostics = diagnostics
      result%status = FMR_SERIALIZED_KERNEL_COMMIT_REJECTED
      call capture_final_provenance(committed_state, result)
      return
    end if

    result%status = FMR_SERIALIZED_KERNEL_OK
    result%completed = .true.
    result%committed = .true.
    call capture_final_provenance(committed_state, result)
    call committed_state%current_time(result%final_committed_time, time_available)
    result%final_committed_time_bound = time_available
  end subroutine fmr_serialized_kernel_backend_execute

  logical function resolved_routing_valid(column, template) result(valid)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template

    valid = column%column_id > 0_int64 .and. column%template_id > 0_int64 .and. &
         template%template_id == column%template_id .and. &
         column%backend_id == FMR_BACKEND_SERIALIZED_INJECTED_KERNEL .and. &
         template%compatible_backend_id == FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
  end function resolved_routing_valid

  subroutine capture_final_provenance(committed_state, result)
    type(kernel_committed_state_t), intent(in) :: committed_state
    type(fmr_serialized_kernel_execution_result_t), intent(inout) :: result
    real(real64) :: committed_time
    logical :: available

    result%final_revision = committed_state%current_revision()
    call committed_state%current_time(committed_time, available)
    result%final_committed_time_bound = available
    if (available) result%final_committed_time = committed_time
  end subroutine capture_final_provenance

end module mod_fmr_serialized_kernel_backend

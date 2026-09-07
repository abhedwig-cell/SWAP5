module mod_kernel_transactions
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t, &
       canonical_mass_accounting_t, canonical_run_diagnostics_t, canonical_result_t, canonical_physical_model_t, &
       CANONICAL_STATUS_INVALID_REQUEST
  use mod_canonical_interval_runtime, only: run_canonical_interval
  implicit none
  private

  integer, parameter, public :: KERNEL_STATUS_NOT_BOUND = 100
  integer, parameter, public :: KERNEL_STATUS_NOT_ADMITTED = 101

  type, abstract, public :: kernel_parameters_t
  end type kernel_parameters_t

  type, public :: kernel_candidate_state_t
    class(transaction_state_t), allocatable :: state
    logical :: valid = .false.
    real(real64) :: origin_t0 = 0.0_real64
    real(real64) :: origin_t1 = 0.0_real64
  end type kernel_candidate_state_t

  type, public :: kernel_result_t
    integer :: status = CANONICAL_STATUS_INVALID_REQUEST
    logical :: completed = .false.
    real(real64) :: requested_t0 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
    real(real64) :: completed_t = 0.0_real64
    type(canonical_mass_accounting_t) :: mass
  end type kernel_result_t

  type, public :: kernel_diagnostics_t
    integer :: transaction_calls = 0
    integer :: accepted_substeps = 0
    integer :: attempts = 0
    integer :: retries = 0
    integer :: trial_rollbacks = 0
    integer :: solver_rejections = 0
    integer :: temporal_rejections = 0
    integer :: mass_rejections = 0
    integer :: candidate_materializations = 0
    integer :: candidate_rollbacks = 0
    integer :: committed_state_mutations = 0
    integer :: admission_rejections = 0
    real(real64) :: max_abs_step_mass_residual = 0.0_real64
  end type kernel_diagnostics_t

  ! F-KT owns this generic physical-model seam. Implementations may delegate
  ! soil-water work to F-SI, but solver-internal arrays and scratch are not
  ! part of this contract. Model instances are worker/job-local execution
  ! objects, never persistent column state.
  type, abstract, extends(canonical_physical_model_t), public :: kernel_model_t
  contains
    procedure(configure_parameters_iface), deferred :: configure_parameters
    procedure(execution_admitted_iface), deferred :: execution_admitted
  end type kernel_model_t

  ! One executor belongs to a worker/job. Its bound model may retain numerical
  ! warm-start data, but every physical trial still originates from the
  ! committed state passed to advance_interval.
  type, public :: kernel_executor_t
    private
    class(kernel_model_t), pointer :: model => null()
  contains
    procedure, public :: bind_model => kernel_bind_model
    procedure, public :: advance_interval => kernel_advance_interval
    procedure, public :: commit_candidate => kernel_commit_candidate
    procedure, public :: rollback_candidate => kernel_rollback_candidate
  end type kernel_executor_t

  abstract interface
    subroutine configure_parameters_iface(self, parameters)
      import :: kernel_model_t, kernel_parameters_t
      class(kernel_model_t), intent(inout) :: self
      class(kernel_parameters_t), intent(in) :: parameters
    end subroutine configure_parameters_iface

    logical function execution_admitted_iface(self, parameters, numerical_config)
      import :: kernel_model_t, kernel_parameters_t, canonical_numerical_config_t
      class(kernel_model_t), intent(in) :: self
      class(kernel_parameters_t), intent(in) :: parameters
      type(canonical_numerical_config_t), intent(in) :: numerical_config
    end function execution_admitted_iface
  end interface

contains

  subroutine kernel_bind_model(self, model)
    class(kernel_executor_t), intent(inout) :: self
    class(kernel_model_t), target, intent(inout) :: model
    self%model => model
  end subroutine kernel_bind_model

  subroutine kernel_advance_interval(self, parameters, committed_state, forcing, numerical_config, t0, t1, &
                                     result, candidate_state, diagnostics)
    class(kernel_executor_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    class(transaction_state_t), allocatable, intent(in) :: committed_state
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate_state
    type(kernel_diagnostics_t), intent(out) :: diagnostics

    class(transaction_state_t), allocatable :: working
    type(canonical_interval_t) :: interval
    type(canonical_result_t) :: runtime_result

    result = kernel_result_t()
    result%requested_t0 = t0
    result%requested_t1 = t1
    result%completed_t = t0
    candidate_state = kernel_candidate_state_t()
    diagnostics = kernel_diagnostics_t()

    if (.not. allocated(committed_state) .or. t1 <= t0 .or. &
        numerical_config%max_committed_substeps <= 0 .or. numerical_config%progress_tolerance < 0.0_real64) then
      result%status = CANONICAL_STATUS_INVALID_REQUEST
      return
    end if

    if (.not. associated(self%model)) then
      result%status = KERNEL_STATUS_NOT_BOUND
      return
    end if

    ! Admission is deliberately fail-closed. In particular, a production
    ! B1.10 reference adapter must return false until independent VQ evidence
    ! has qualified the required numerical/temporal capability profile.
    if (.not. self%model%execution_admitted(parameters, numerical_config)) then
      result%status = KERNEL_STATUS_NOT_ADMITTED
      diagnostics%admission_rejections = 1
      return
    end if

    call self%model%configure_parameters(parameters)

    ! The caller-owned committed state is input-only. The F-CI runtime receives
    ! a private clone and may commit only inside that private working lineage.
    call committed_state%clone(working)
    interval%t0 = t0
    interval%t1 = t1
    call run_canonical_interval(self%model, working, forcing, interval, numerical_config, runtime_result)

    call map_runtime_result(runtime_result, result)
    call map_transaction_diagnostics(runtime_result%diagnostics, diagnostics)

    if (runtime_result%completed) then
      call move_alloc(working, candidate_state%state)
      candidate_state%valid = .true.
      candidate_state%origin_t0 = t0
      candidate_state%origin_t1 = t1
      diagnostics%candidate_materializations = 1
    end if
  end subroutine kernel_advance_interval

  subroutine kernel_commit_candidate(self, committed_state, candidate_state, diagnostics, did_commit)
    class(kernel_executor_t), intent(inout) :: self
    class(transaction_state_t), allocatable, intent(inout) :: committed_state
    type(kernel_candidate_state_t), intent(inout) :: candidate_state
    type(kernel_diagnostics_t), intent(inout) :: diagnostics
    logical, intent(out) :: did_commit

    did_commit = .false.
    if (.not. associated(self%model)) return
    if (.not. candidate_state%valid .or. .not. allocated(candidate_state%state)) return

    call move_alloc(candidate_state%state, committed_state)
    candidate_state%valid = .false.
    diagnostics%committed_state_mutations = diagnostics%committed_state_mutations + 1
    did_commit = .true.
  end subroutine kernel_commit_candidate

  subroutine kernel_rollback_candidate(self, candidate_state, diagnostics)
    class(kernel_executor_t), intent(inout) :: self
    type(kernel_candidate_state_t), intent(inout) :: candidate_state
    type(kernel_diagnostics_t), intent(inout) :: diagnostics

    if (.not. associated(self%model)) return
    if (allocated(candidate_state%state)) deallocate(candidate_state%state)
    if (candidate_state%valid) diagnostics%candidate_rollbacks = diagnostics%candidate_rollbacks + 1
    candidate_state%valid = .false.
    candidate_state%origin_t0 = 0.0_real64
    candidate_state%origin_t1 = 0.0_real64
  end subroutine kernel_rollback_candidate

  subroutine map_runtime_result(runtime_result, result)
    type(canonical_result_t), intent(in) :: runtime_result
    type(kernel_result_t), intent(out) :: result

    result%status = runtime_result%status
    result%completed = runtime_result%completed
    result%requested_t0 = runtime_result%requested_t0
    result%requested_t1 = runtime_result%requested_t1
    result%completed_t = runtime_result%completed_t
    result%mass = runtime_result%mass
  end subroutine map_runtime_result

  subroutine map_transaction_diagnostics(runtime_diagnostics, diagnostics)
    type(canonical_run_diagnostics_t), intent(in) :: runtime_diagnostics
    type(kernel_diagnostics_t), intent(out) :: diagnostics

    diagnostics = kernel_diagnostics_t()
    diagnostics%transaction_calls = runtime_diagnostics%transaction_calls
    diagnostics%accepted_substeps = runtime_diagnostics%committed_substeps
    diagnostics%attempts = runtime_diagnostics%attempts
    diagnostics%retries = runtime_diagnostics%retries
    diagnostics%trial_rollbacks = runtime_diagnostics%rollbacks
    diagnostics%solver_rejections = runtime_diagnostics%solver_rejections
    diagnostics%temporal_rejections = runtime_diagnostics%temporal_rejections
    diagnostics%mass_rejections = runtime_diagnostics%mass_rejections
    diagnostics%max_abs_step_mass_residual = runtime_diagnostics%max_abs_step_mass_residual
  end subroutine map_transaction_diagnostics

end module mod_kernel_transactions

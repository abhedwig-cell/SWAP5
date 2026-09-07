module mod_kernel_transactions
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t, &
       canonical_mass_accounting_t, canonical_run_diagnostics_t, canonical_result_t, canonical_physical_model_t, &
       CANONICAL_STATUS_INVALID_REQUEST
  use mod_canonical_interval_runtime, only: run_canonical_interval
  implicit none
  private

  integer, parameter, public :: KERNEL_STATUS_NOT_BOUND = 100
  integer, parameter, public :: KERNEL_STATUS_NOT_ADMITTED = 101
  integer, parameter, public :: KERNEL_STATUS_UNGUARDED_STATE = 102
  integer, parameter, public :: KERNEL_STATUS_TIME_MISMATCH = 103

  integer, parameter, public :: KERNEL_COMMIT_STATUS_COMMITTED = 0
  integer, parameter, public :: KERNEL_COMMIT_STATUS_INVALID_CANDIDATE = 1
  integer, parameter, public :: KERNEL_COMMIT_STATUS_UNGUARDED_STATE = 2
  integer, parameter, public :: KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH = 3
  integer, parameter, public :: KERNEL_COMMIT_STATUS_STALE_REVISION = 4
  integer, parameter, public :: KERNEL_COMMIT_STATUS_TIME_MISMATCH = 5

  type, abstract, public :: kernel_parameters_t
  end type kernel_parameters_t

  ! Canonical F-KT-owned committed carrier. Physical continuation state is
  ! private. Runtime/coupler code supplies a stable positive lineage id; F-KT
  ! owns revision and committed-time changes and never generates global column
  ! identities. Initial time is optional for staged legacy admission; once the
  ! timeline is bound, every continuation must start at the committed time.
  type, extends(transaction_state_t), public :: kernel_committed_state_t
    private
    class(transaction_state_t), allocatable :: physical_state
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: revision = 0_int64
    real(real64) :: committed_time_value = 0.0_real64
    logical :: time_bound = .false.
    logical :: initialized = .false.
  contains
    procedure :: clone => kernel_committed_clone
    procedure, public :: initialize => kernel_initialize_committed
    procedure, public :: snapshot => kernel_snapshot_committed
    procedure, public :: ready => kernel_committed_ready
    procedure, public :: current_lineage_id => kernel_current_lineage_id
    procedure, public :: current_revision => kernel_current_revision
    procedure, public :: current_time => kernel_current_time
    procedure, public :: time_is_bound => kernel_time_is_bound
  end type kernel_committed_state_t

  ! Candidate provenance and physical state are opaque outside F-KT. Callers
  ! may inspect cloned snapshots and origin metadata but cannot forge the
  ! lineage/revision that authorizes publication.
  type, public :: kernel_candidate_state_t
    private
    class(transaction_state_t), allocatable :: state
    logical :: valid = .false.
    real(real64) :: origin_t0 = 0.0_real64
    real(real64) :: origin_t1 = 0.0_real64
    integer(int64) :: origin_lineage_id_value = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
  contains
    procedure, public :: ready => kernel_candidate_ready
    procedure, public :: snapshot => kernel_snapshot_candidate
    procedure, public :: current_lineage_id => kernel_candidate_lineage_id
    procedure, public :: origin_revision => kernel_candidate_origin_revision
    procedure, public :: origin_interval => kernel_candidate_origin_interval
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
    integer :: commit_rejections = 0
    integer :: invalid_candidate_rejections = 0
    integer :: unguarded_state_rejections = 0
    integer :: lineage_mismatch_rejections = 0
    integer :: stale_revision_rejections = 0
    integer :: time_origin_rejections = 0
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
  ! warm-start data, but every physical trial originates from the committed
  ! physical state carried by kernel_committed_state_t.
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

  subroutine kernel_committed_clone(self, copy)
    class(kernel_committed_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(kernel_committed_state_t :: copy)
    select type (typed_copy => copy)
    type is (kernel_committed_state_t)
      typed_copy%lineage_id = self%lineage_id
      typed_copy%revision = self%revision
      typed_copy%committed_time_value = self%committed_time_value
      typed_copy%time_bound = self%time_bound
      typed_copy%initialized = self%initialized
      if (allocated(self%physical_state)) call self%physical_state%clone(typed_copy%physical_state)
    end select
  end subroutine kernel_committed_clone

  subroutine kernel_initialize_committed(self, lineage_id, initial_state, did_initialize, initial_time)
    class(kernel_committed_state_t), intent(inout) :: self
    integer(int64), intent(in) :: lineage_id
    class(transaction_state_t), allocatable, intent(in) :: initial_state
    logical, intent(out) :: did_initialize
    real(real64), intent(in), optional :: initial_time
    class(transaction_state_t), allocatable :: copy

    did_initialize = .false.
    if (self%initialized .or. lineage_id <= 0_int64 .or. .not. allocated(initial_state)) return
    if (present(initial_time)) then
      if (.not. ieee_is_finite(initial_time)) return
    end if

    call initial_state%clone(copy)
    call move_alloc(copy, self%physical_state)
    self%lineage_id = lineage_id
    self%revision = 0_int64
    self%committed_time_value = 0.0_real64
    self%time_bound = .false.
    if (present(initial_time)) then
      self%committed_time_value = initial_time
      self%time_bound = .true.
    end if
    self%initialized = .true.
    did_initialize = .true.
  end subroutine kernel_initialize_committed

  subroutine kernel_snapshot_committed(self, copy, available)
    class(kernel_committed_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    logical, intent(out) :: available

    available = self%ready()
    if (.not. available) return
    call self%physical_state%clone(copy)
  end subroutine kernel_snapshot_committed

  logical function kernel_committed_ready(self) result(is_ready)
    class(kernel_committed_state_t), intent(in) :: self
    is_ready = self%initialized .and. self%lineage_id > 0_int64 .and. &
         self%revision >= 0_int64 .and. allocated(self%physical_state) .and. &
         (.not. self%time_bound .or. ieee_is_finite(self%committed_time_value))
  end function kernel_committed_ready

  integer(int64) function kernel_current_lineage_id(self) result(value)
    class(kernel_committed_state_t), intent(in) :: self
    value = self%lineage_id
  end function kernel_current_lineage_id

  integer(int64) function kernel_current_revision(self) result(value)
    class(kernel_committed_state_t), intent(in) :: self
    value = self%revision
  end function kernel_current_revision

  subroutine kernel_current_time(self, value, available)
    class(kernel_committed_state_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available

    available = self%ready() .and. self%time_bound
    if (available) then
      value = self%committed_time_value
    else
      value = 0.0_real64
    end if
  end subroutine kernel_current_time

  logical function kernel_time_is_bound(self) result(is_bound)
    class(kernel_committed_state_t), intent(in) :: self
    is_bound = self%ready() .and. self%time_bound
  end function kernel_time_is_bound

  logical function kernel_candidate_ready(self) result(is_ready)
    class(kernel_candidate_state_t), intent(in) :: self
    is_ready = self%valid .and. allocated(self%state) .and. &
         self%origin_lineage_id_value > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         ieee_is_finite(self%origin_t0) .and. ieee_is_finite(self%origin_t1) .and. &
         self%origin_t1 > self%origin_t0
  end function kernel_candidate_ready

  subroutine kernel_snapshot_candidate(self, copy, available)
    class(kernel_candidate_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    logical, intent(out) :: available

    available = self%ready()
    if (.not. available) return
    call self%state%clone(copy)
  end subroutine kernel_snapshot_candidate

  integer(int64) function kernel_candidate_lineage_id(self) result(value)
    class(kernel_candidate_state_t), intent(in) :: self
    value = self%origin_lineage_id_value
  end function kernel_candidate_lineage_id

  integer(int64) function kernel_candidate_origin_revision(self) result(value)
    class(kernel_candidate_state_t), intent(in) :: self
    value = self%origin_revision_value
  end function kernel_candidate_origin_revision

  subroutine kernel_candidate_origin_interval(self, t0, t1, available)
    class(kernel_candidate_state_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      t0 = self%origin_t0
      t1 = self%origin_t1
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine kernel_candidate_origin_interval

  subroutine kernel_bind_model(self, model)
    class(kernel_executor_t), intent(inout) :: self
    class(kernel_model_t), target, intent(inout) :: model
    self%model => model
  end subroutine kernel_bind_model

  subroutine kernel_advance_interval(self, parameters, committed_state, forcing, numerical_config, t0, t1, &
                                     result, candidate_state, diagnostics)
    class(kernel_executor_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed_state
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

    if (.not. committed_state%ready()) then
      result%status = KERNEL_STATUS_UNGUARDED_STATE
      diagnostics%unguarded_state_rejections = 1
      return
    end if

    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0 .or. &
        numerical_config%max_committed_substeps <= 0 .or. numerical_config%progress_tolerance < 0.0_real64) then
      result%status = CANONICAL_STATUS_INVALID_REQUEST
      return
    end if

    if (committed_state%time_bound .and. .not. same_time_value(t0, committed_state%committed_time_value)) then
      result%status = KERNEL_STATUS_TIME_MISMATCH
      diagnostics%time_origin_rejections = 1
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

    ! Clone only the physical continuation state. Lineage/revision/time are
    ! transaction control and never enter solver or persistent physical state.
    call committed_state%physical_state%clone(working)

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
      candidate_state%origin_lineage_id_value = committed_state%lineage_id
      candidate_state%origin_revision_value = committed_state%revision
      diagnostics%candidate_materializations = 1
    end if
  end subroutine kernel_advance_interval

  subroutine kernel_commit_candidate(self, committed_state, candidate_state, diagnostics, did_commit, commit_status)
    class(kernel_executor_t), intent(inout) :: self
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(kernel_candidate_state_t), intent(inout) :: candidate_state
    type(kernel_diagnostics_t), intent(inout) :: diagnostics
    logical, intent(out) :: did_commit
    integer, intent(out), optional :: commit_status

    did_commit = .false.
    if (present(commit_status)) commit_status = KERNEL_COMMIT_STATUS_INVALID_CANDIDATE
    if (.not. same_type_as(self, self)) error stop 'unreachable kernel executor type'

    if (.not. candidate_state%ready()) then
      diagnostics%commit_rejections = diagnostics%commit_rejections + 1
      diagnostics%invalid_candidate_rejections = diagnostics%invalid_candidate_rejections + 1
      return
    end if

    if (.not. committed_state%ready()) then
      diagnostics%commit_rejections = diagnostics%commit_rejections + 1
      diagnostics%unguarded_state_rejections = diagnostics%unguarded_state_rejections + 1
      if (present(commit_status)) commit_status = KERNEL_COMMIT_STATUS_UNGUARDED_STATE
      return
    end if

    if (candidate_state%origin_lineage_id_value /= committed_state%lineage_id) then
      diagnostics%commit_rejections = diagnostics%commit_rejections + 1
      diagnostics%lineage_mismatch_rejections = diagnostics%lineage_mismatch_rejections + 1
      if (present(commit_status)) commit_status = KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH
      return
    end if

    if (candidate_state%origin_revision_value /= committed_state%revision) then
      diagnostics%commit_rejections = diagnostics%commit_rejections + 1
      diagnostics%stale_revision_rejections = diagnostics%stale_revision_rejections + 1
      if (present(commit_status)) commit_status = KERNEL_COMMIT_STATUS_STALE_REVISION
      return
    end if

    if (committed_state%time_bound .and. &
        .not. same_time_value(candidate_state%origin_t0, committed_state%committed_time_value)) then
      diagnostics%commit_rejections = diagnostics%commit_rejections + 1
      diagnostics%time_origin_rejections = diagnostics%time_origin_rejections + 1
      if (present(commit_status)) commit_status = KERNEL_COMMIT_STATUS_TIME_MISMATCH
      return
    end if

    call move_alloc(candidate_state%state, committed_state%physical_state)
    committed_state%revision = committed_state%revision + 1_int64
    committed_state%committed_time_value = candidate_state%origin_t1
    committed_state%time_bound = .true.

    call clear_candidate(candidate_state)
    diagnostics%committed_state_mutations = diagnostics%committed_state_mutations + 1
    did_commit = .true.
    if (present(commit_status)) commit_status = KERNEL_COMMIT_STATUS_COMMITTED
  end subroutine kernel_commit_candidate

  subroutine kernel_rollback_candidate(self, candidate_state, diagnostics)
    class(kernel_executor_t), intent(inout) :: self
    type(kernel_candidate_state_t), intent(inout) :: candidate_state
    type(kernel_diagnostics_t), intent(inout) :: diagnostics

    if (.not. same_type_as(self, self)) error stop 'unreachable kernel executor type'
    if (candidate_state%ready()) diagnostics%candidate_rollbacks = diagnostics%candidate_rollbacks + 1
    call clear_candidate(candidate_state)
  end subroutine kernel_rollback_candidate

  subroutine clear_candidate(candidate_state)
    type(kernel_candidate_state_t), intent(inout) :: candidate_state

    if (allocated(candidate_state%state)) deallocate(candidate_state%state)
    candidate_state%valid = .false.
    candidate_state%origin_t0 = 0.0_real64
    candidate_state%origin_t1 = 0.0_real64
    candidate_state%origin_lineage_id_value = 0_int64
    candidate_state%origin_revision_value = -1_int64
  end subroutine clear_candidate

  logical function same_time_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*scale
  end function same_time_value

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

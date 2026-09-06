module mod_a23br_worker_execution_context
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  type, public :: a23br_headcalc_scratch_t
    real(real64), allocatable :: dfdhl(:), dfdhm(:), dfdhu(:)
    real(real64), allocatable :: difh(:), residual(:)
    real(real64), allocatable :: sink(:), source(:), dkdh(:), hold(:)
    real(real64), allocatable :: qv(:), hgrad(:)
    logical, allocatable :: flnonconv1(:), flnonconv2(:)
    logical :: flunsatok(3) = .false.
  end type a23br_headcalc_scratch_t

  type, public :: a23br_solver_history_t
    logical :: flwarn = .true.
    integer :: iwarn = 0
    integer :: nstep = 0
  end type a23br_solver_history_t

  type, public :: a23br_solver_diagnostics_t
    integer :: headcalc_calls = 0
    integer :: nonlinear_iterations = 0
    integer :: jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    integer :: internal_retries = 0
  end type a23br_solver_diagnostics_t

  type, public :: a23br_numerical_control_t
    integer :: last_numbit = 0
    logical :: request_dt_reduction = .false.
    logical :: at_min_dt = .false.
  end type a23br_numerical_control_t

  type, public :: a23br_worker_context_t
    integer :: worker_id = -1
    integer :: active_nodes = 0
    type(a23br_headcalc_scratch_t) :: headcalc
    type(a23br_solver_history_t) :: history
    type(a23br_solver_diagnostics_t) :: diagnostics
    type(a23br_numerical_control_t) :: control
  end type a23br_worker_context_t

  public :: a23br_initialize_worker, a23br_release_worker
  public :: a23br_reset_attempt_diagnostics, a23br_record_internal_retry
  public :: a23br_reset_attempt_control, a23br_reset_all_numerical_control
  public :: a23br_seed_timestep_control, a23br_request_dt_reduction
  public :: a23br_scratch_payload_bytes

contains

  subroutine a23br_initialize_worker(worker, active_nodes, worker_id)
    type(a23br_worker_context_t), intent(inout) :: worker
    integer, intent(in) :: active_nodes
    integer, intent(in), optional :: worker_id

    if (active_nodes <= 0) error stop 'A23BR worker: active_nodes must be positive'
    call a23br_release_worker(worker)
    worker%active_nodes = active_nodes
    if (present(worker_id)) worker%worker_id = worker_id
    allocate(worker%headcalc%dfdhl(active_nodes), worker%headcalc%dfdhm(active_nodes), &
             worker%headcalc%dfdhu(active_nodes), worker%headcalc%difh(active_nodes), &
             worker%headcalc%residual(active_nodes), worker%headcalc%sink(active_nodes), &
             worker%headcalc%source(active_nodes), worker%headcalc%dkdh(active_nodes), &
             worker%headcalc%hold(active_nodes), worker%headcalc%qv(active_nodes+1), &
             worker%headcalc%hgrad(active_nodes+1), worker%headcalc%flnonconv1(active_nodes), &
             worker%headcalc%flnonconv2(active_nodes))
    worker%headcalc%dfdhl = 0.0_real64
    worker%headcalc%dfdhm = 0.0_real64
    worker%headcalc%dfdhu = 0.0_real64
    worker%headcalc%difh = 0.0_real64
    worker%headcalc%residual = 0.0_real64
    worker%headcalc%sink = 0.0_real64
    worker%headcalc%source = 0.0_real64
    worker%headcalc%dkdh = 0.0_real64
    worker%headcalc%hold = 0.0_real64
    worker%headcalc%qv = 0.0_real64
    worker%headcalc%hgrad = 0.0_real64
    worker%headcalc%flnonconv1 = .false.
    worker%headcalc%flnonconv2 = .false.
    worker%headcalc%flunsatok = .false.
    worker%history = a23br_solver_history_t()
    worker%diagnostics = a23br_solver_diagnostics_t()
    worker%control = a23br_numerical_control_t()
  end subroutine a23br_initialize_worker

  subroutine a23br_release_worker(worker)
    type(a23br_worker_context_t), intent(inout) :: worker
    if (allocated(worker%headcalc%dfdhl)) deallocate(worker%headcalc%dfdhl)
    if (allocated(worker%headcalc%dfdhm)) deallocate(worker%headcalc%dfdhm)
    if (allocated(worker%headcalc%dfdhu)) deallocate(worker%headcalc%dfdhu)
    if (allocated(worker%headcalc%difh)) deallocate(worker%headcalc%difh)
    if (allocated(worker%headcalc%residual)) deallocate(worker%headcalc%residual)
    if (allocated(worker%headcalc%sink)) deallocate(worker%headcalc%sink)
    if (allocated(worker%headcalc%source)) deallocate(worker%headcalc%source)
    if (allocated(worker%headcalc%dkdh)) deallocate(worker%headcalc%dkdh)
    if (allocated(worker%headcalc%hold)) deallocate(worker%headcalc%hold)
    if (allocated(worker%headcalc%qv)) deallocate(worker%headcalc%qv)
    if (allocated(worker%headcalc%hgrad)) deallocate(worker%headcalc%hgrad)
    if (allocated(worker%headcalc%flnonconv1)) deallocate(worker%headcalc%flnonconv1)
    if (allocated(worker%headcalc%flnonconv2)) deallocate(worker%headcalc%flnonconv2)
    worker%active_nodes = 0
    worker%history = a23br_solver_history_t()
    worker%diagnostics = a23br_solver_diagnostics_t()
    worker%control = a23br_numerical_control_t()
  end subroutine a23br_release_worker

  subroutine a23br_reset_attempt_diagnostics(worker)
    type(a23br_worker_context_t), intent(inout) :: worker
    worker%diagnostics = a23br_solver_diagnostics_t()
  end subroutine a23br_reset_attempt_diagnostics

  subroutine a23br_reset_attempt_control(worker)
    type(a23br_worker_context_t), intent(inout) :: worker
    worker%control%last_numbit = 0
    worker%control%request_dt_reduction = .false.
  end subroutine a23br_reset_attempt_control

  subroutine a23br_reset_all_numerical_control(worker)
    type(a23br_worker_context_t), intent(inout) :: worker
    worker%control = a23br_numerical_control_t()
  end subroutine a23br_reset_all_numerical_control

  subroutine a23br_seed_timestep_control(worker, dt, dtmin)
    type(a23br_worker_context_t), intent(inout) :: worker
    real(real64), intent(in) :: dt, dtmin
    real(real64), parameter :: dtcrit = 1.0e-8_real64
    call a23br_reset_attempt_control(worker)
    worker%control%at_min_dt = dt <= (1.0_real64 + dtcrit) * dtmin
  end subroutine a23br_seed_timestep_control

  subroutine a23br_request_dt_reduction(worker)
    type(a23br_worker_context_t), intent(inout) :: worker
    worker%control%request_dt_reduction = .true.
  end subroutine a23br_request_dt_reduction

  subroutine a23br_record_internal_retry(worker)
    type(a23br_worker_context_t), intent(inout) :: worker
    worker%diagnostics%internal_retries = worker%diagnostics%internal_retries + 1
  end subroutine a23br_record_internal_retry

  integer function a23br_scratch_payload_bytes(worker) result(bytes)
    type(a23br_worker_context_t), intent(in) :: worker
    integer :: rb, lb
    rb = storage_size(0.0_real64)/8
    lb = storage_size(.false.)/8
    bytes = 0
    if (.not. allocated(worker%headcalc%dfdhl)) return
    bytes = rb * (size(worker%headcalc%dfdhl) + size(worker%headcalc%dfdhm) + &
                  size(worker%headcalc%dfdhu) + size(worker%headcalc%difh) + &
                  size(worker%headcalc%residual) + size(worker%headcalc%sink) + &
                  size(worker%headcalc%source) + size(worker%headcalc%dkdh) + &
                  size(worker%headcalc%hold) + size(worker%headcalc%qv) + &
                  size(worker%headcalc%hgrad))
    bytes = bytes + lb * (size(worker%headcalc%flnonconv1) + size(worker%headcalc%flnonconv2) + &
                          size(worker%headcalc%flunsatok))
  end function a23br_scratch_payload_bytes

end module mod_a23br_worker_execution_context

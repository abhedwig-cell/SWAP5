module mod_difficulty_trial_record
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t, soil_water_solve_result_t, &
       SW_SOLVE_CONVERGED
  implicit none
  private

  integer, parameter, public :: DIFF_METHOD_REFERENCE_NEWTON = 1
  integer, parameter, public :: DIFF_METHOD_ROSSFAST_D3R = 2
  integer, parameter, public :: DIFF_METHOD_CLASS_ITERATIVE_NONLINEAR = 1
  integer, parameter, public :: DIFF_METHOD_CLASS_ALTERNATIVE_FORMULATION = 2

  type, public :: difficulty_identity_t
    character(len=64) :: experiment_id = ''
    character(len=64) :: checkpoint_id = ''
    character(len=64) :: counterfactual_group_id = ''
    character(len=40) :: canonical_commit_sha = ''
    character(len=32) :: soil_id = ''
    character(len=8) :: regime_id = ''
    character(len=64) :: trial_id = ''
    integer :: method_id = 0
    integer :: method_class = 0
  end type difficulty_identity_t

  type, public :: difficulty_pretrial_t
    integer :: active_nodes = 0
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
    real(real64), allocatable :: z(:)
    real(real64), allocatable :: dz(:)
    real(real64) :: ponding_depth = 0.0_real64
    real(real64) :: groundwater_level = 0.0_real64
    integer :: top_mode = 0
    integer :: bottom_mode = 0
    real(real64) :: top_flux = 0.0_real64
    real(real64) :: top_head = 0.0_real64
    real(real64) :: bottom_flux = 0.0_real64
    real(real64) :: bottom_head = 0.0_real64
    real(real64) :: dt = 0.0_real64
    logical :: constitutive_available = .false.
    real(real64), allocatable :: conductivity(:)
    real(real64), allocatable :: capacity(:)
    real(real64), allocatable :: dkdh(:)
    logical :: previous_iterations_available = .false.
    integer :: previous_iterations = 0
    logical :: previous_rejection_available = .false.
    logical :: previous_rejection = .false.
    integer :: retry_index = 0
    logical :: previous_method_available = .false.
    integer :: previous_method_id = 0
  end type difficulty_pretrial_t

  type, public :: difficulty_outcome_t
    logical :: solve_completed = .false.
    logical :: converged = .false.
    logical :: retry_advised = .false.
    integer :: nonlinear_iterations = 0
    integer :: jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    integer :: internal_retries = 0
    character(len=32) :: route = 'not-run'
    logical :: integrated_mass_residual_available = .false.
    real(real64) :: integrated_mass_residual_cm = 0.0_real64
    logical :: native_balance_rate_available = .false.
    real(real64) :: native_balance_rate_cm_per_day = 0.0_real64
    logical :: residual_trajectory_available = .false.
    logical :: increment_trajectory_available = .false.
    logical :: conditioning_proxy_available = .false.
    logical :: transaction_admissibility_evaluated = .false.
    logical :: admissible_final_state = .false.
    logical :: mass_balance_pass = .false.
    logical :: hidden_fallback_used = .false.
    logical :: rejection = .false.
    logical :: retry_required = .false.
    logical :: reliably_solvable = .false.
    character(len=48) :: failure_class = 'not-classified'
  end type difficulty_outcome_t

  type, public :: difficulty_trial_record_t
    type(difficulty_identity_t) :: identity
    type(difficulty_pretrial_t) :: pre
    type(difficulty_outcome_t) :: outcome
  end type difficulty_trial_record_t

  public :: capture_difficulty_pretrial
  public :: capture_difficulty_solver_outcome
  public :: validate_difficulty_record

contains

  subroutine capture_difficulty_pretrial(record, request)
    type(difficulty_trial_record_t), intent(inout) :: record
    type(soil_water_solve_request_t), intent(in) :: request
    integer :: n

    n = request%base_state%active_nodes
    record%pre%active_nodes = n
    if (allocated(request%base_state%pressure_head)) then
      allocate(record%pre%pressure_head(size(request%base_state%pressure_head)))
      record%pre%pressure_head = request%base_state%pressure_head
    end if
    if (allocated(request%base_state%water_content)) then
      allocate(record%pre%water_content(size(request%base_state%water_content)))
      record%pre%water_content = request%base_state%water_content
    end if
    if (associated(request%parameters)) then
      if (allocated(request%parameters%z)) then
        allocate(record%pre%z(size(request%parameters%z))); record%pre%z = request%parameters%z
      end if
      if (allocated(request%parameters%dz)) then
        allocate(record%pre%dz(size(request%parameters%dz))); record%pre%dz = request%parameters%dz
      end if
    end if
    record%pre%ponding_depth = request%base_state%ponding_depth
    record%pre%groundwater_level = request%base_state%groundwater_level
    record%pre%top_mode = request%boundary%top_mode
    record%pre%bottom_mode = request%boundary%bottom_mode
    record%pre%top_flux = request%boundary%top_flux
    record%pre%top_head = request%boundary%top_head
    record%pre%bottom_flux = request%boundary%bottom_flux
    record%pre%bottom_head = request%boundary%bottom_head
    record%pre%dt = request%step_duration
  end subroutine capture_difficulty_pretrial

  subroutine capture_difficulty_solver_outcome(record, result)
    type(difficulty_trial_record_t), intent(inout) :: record
    type(soil_water_solve_result_t), intent(in) :: result

    record%outcome%solve_completed = .true.
    record%outcome%converged = result%status == SW_SOLVE_CONVERGED
    record%outcome%retry_advised = result%retry_advised
    record%outcome%nonlinear_iterations = result%diagnostics%nonlinear_iterations
    record%outcome%jacobian_builds = result%diagnostics%jacobian_builds
    record%outcome%linear_solves = result%diagnostics%linear_solves
    record%outcome%backtracking_attempts = result%diagnostics%backtracking_attempts
    record%outcome%alternative_solver_calls = result%diagnostics%alternative_solver_calls
    record%outcome%internal_retries = result%diagnostics%internal_retries
    record%outcome%route = result%diagnostics%route
    record%outcome%integrated_mass_residual_available = result%integrated_mass_balance_residual_available
    record%outcome%integrated_mass_residual_cm = result%integrated_mass_balance_residual_cm
    record%outcome%native_balance_rate_available = result%native_balance_rate_residual_available
    record%outcome%native_balance_rate_cm_per_day = result%native_balance_rate_residual_cm_per_day
    record%outcome%hidden_fallback_used = result%diagnostics%alternative_solver_calls > 0
    record%outcome%retry_required = result%retry_advised
    if (.not. record%outcome%converged) then
      record%outcome%failure_class = 'solver-not-converged'
    else
      record%outcome%failure_class = 'solver-converged-admissibility-pending'
    end if
    ! Reliable solvability is deliberately NOT inferred from solver convergence.
    record%outcome%reliably_solvable = .false.
  end subroutine capture_difficulty_solver_outcome

  subroutine validate_difficulty_record(record, ok)
    type(difficulty_trial_record_t), intent(in) :: record
    logical, intent(out) :: ok
    integer :: n
    ok = .false.
    n = record%pre%active_nodes
    if (n <= 0 .or. record%pre%dt <= 0.0_real64) return
    if (.not. allocated(record%pre%pressure_head) .or. .not. allocated(record%pre%water_content)) return
    if (size(record%pre%pressure_head) /= n .or. size(record%pre%water_content) /= n) return
    if (record%identity%method_id <= 0 .or. record%identity%method_class <= 0) return
    if (len_trim(record%identity%checkpoint_id) == 0 .or. len_trim(record%identity%counterfactual_group_id) == 0) return
    ok = .true.
  end subroutine validate_difficulty_record

end module mod_difficulty_trial_record

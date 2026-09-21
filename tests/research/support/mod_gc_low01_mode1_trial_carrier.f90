module mod_gc_low01_mode1_trial_carrier
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
  use mod_reference_richards_workspace, only: reference_richards_workspace_t
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
       soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
  implicit none
  private

  integer, parameter, public :: GC_LOW01_BRANCH_INVALID = 0
  integer, parameter, public :: GC_LOW01_BRANCH_ABOVE_OR_AT_TOP = 1
  integer, parameter, public :: GC_LOW01_BRANCH_INSIDE_PROFILE = 2
  integer, parameter, public :: GC_LOW01_BRANCH_BELOW_BOTTOM_NODE = 3
  character(len=*), parameter, public :: GC_LOW01_QBOT_ROUTE_HEADCALC_FLUX_CHAIN = &
       'headcalc-complete-flux-chain'

  type, public :: gc_low01_mode1_trial_result_t
    logical :: valid = .false.
    real(real64) :: requested_h_phreatic_cm = 0.0_real64
    real(real64) :: effective_h_phreatic_cm = 0.0_real64
    real(real64) :: raw_legacy_gwl_cm = 0.0_real64
    real(real64) :: raw_gwlinp_cm = 0.0_real64
    integer :: branch = GC_LOW01_BRANCH_INVALID
    integer :: branch_id = GC_LOW01_BRANCH_INVALID
    integer :: active_richards_nodes = 0
    integer :: active_nodes = 0
    logical :: fllowgwl = .false.
    logical :: retry_advised = .false.
    logical :: dt_reduction_requested = .false.
    logical :: derived_profile_gwl_available = .false.
    real(real64) :: derived_profile_gwl_cm = 0.0_real64
    real(real64) :: qbot_cm_per_day = 0.0_real64
    character(len=48) :: qbot_materialization_route = 'not-run'
    real(real64) :: qtop_cm_per_day = 0.0_real64
    real(real64) :: ponding_depth_cm = 0.0_real64
    real(real64) :: storage_change_cm = 0.0_real64
    real(real64) :: complete_profile_storage_change_cm = 0.0_real64
    real(real64) :: mass_residual_cm = 0.0_real64
    real(real64), allocatable :: pressure_head_cm(:)
    real(real64), allocatable :: water_content(:)
    integer :: nonlinear_iterations = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    integer :: internal_retries = 0
    type(reference_richards_state_binding_t) :: candidate
  end type gc_low01_mode1_trial_result_t

  public :: gc_low01_run_inside_profile_trial
  public :: gc_low01_classify_control

  interface
    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                        numerical_config, physical_config, explicit_step_duration, parameter_set)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, FSI_TOP_MODE_EXPLICIT_FLUX
      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
           soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
      type(soil_water_physical_config_t), intent(in), optional :: physical_config
      real(8), intent(in), optional :: explicit_step_duration
      type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set
    end subroutine headcalc
  end interface

contains

  subroutine gc_low01_classify_control(parameter_set, requested_h_phreatic_cm, branch, active_nodes, effective_h_phreatic_cm)
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    real(real64), intent(in) :: requested_h_phreatic_cm
    integer, intent(out) :: branch, active_nodes
    real(real64), intent(out) :: effective_h_phreatic_cm
    integer :: nn, n
    real(real64), parameter :: source_snap_tolerance_cm = 1.0e-4_real64

    branch = GC_LOW01_BRANCH_INVALID
    active_nodes = 0
    effective_h_phreatic_cm = requested_h_phreatic_cm

    n = parameter_set%active_nodes
    if (n <= 0 .or. .not. allocated(parameter_set%z) .or. .not. allocated(parameter_set%dz)) return
    if (size(parameter_set%z) /= n .or. size(parameter_set%dz) /= n) return

    if (requested_h_phreatic_cm >= parameter_set%z(1)-source_snap_tolerance_cm) then
      branch = GC_LOW01_BRANCH_ABOVE_OR_AT_TOP
      return
    end if

    nn = 0
    do while (nn < n)
      if (.not. (parameter_set%z(nn+1) > requested_h_phreatic_cm)) exit
      nn = nn + 1
    end do

    if (nn >= n) then
      branch = GC_LOW01_BRANCH_BELOW_BOTTOM_NODE
      active_nodes = n
      return
    end if

    effective_h_phreatic_cm = requested_h_phreatic_cm
    active_nodes = nn
    if (active_nodes > 0) then
      if ((parameter_set%z(active_nodes)-effective_h_phreatic_cm) < source_snap_tolerance_cm) then
        effective_h_phreatic_cm = parameter_set%z(active_nodes)
        active_nodes = active_nodes - 1
      end if
    end if

    if (active_nodes <= 0) then
      branch = GC_LOW01_BRANCH_INVALID
      return
    end if
    branch = GC_LOW01_BRANCH_INSIDE_PROFILE
  end subroutine gc_low01_classify_control

  subroutine gc_low01_run_inside_profile_trial(origin, requested_h_phreatic_cm, parameter_set, evaluation, &
                                               numerical, physical, step_duration_day, result)
    type(reference_richards_state_binding_t), intent(in) :: origin
    real(real64), intent(in) :: requested_h_phreatic_cm
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(hydraulic_evaluation_context_t), intent(in) :: evaluation
    type(soil_water_numerical_config_t), intent(in) :: numerical
    type(soil_water_physical_config_t), intent(in) :: physical
    real(real64), intent(in) :: step_duration_day
    type(gc_low01_mode1_trial_result_t), intent(out) :: result

    type(a23bu_worker_context_t) :: worker
    type(reference_richards_workspace_t), target :: workspace
    type(a23bu_solver_history_t), target :: history
    type(soil_water_boundary_conditions_t) :: boundary
    real(real64) :: classified_effective
    real(real64) :: storage0, storage1, mass_gate
    integer :: branch, active_nodes, n, k
    logical :: branch_boundary

    result = gc_low01_mode1_trial_result_t()
    result%requested_h_phreatic_cm = requested_h_phreatic_cm

    call gc_low01_classify_control(parameter_set, requested_h_phreatic_cm, branch, active_nodes, classified_effective)
    result%branch = branch
    result%branch_id = branch
    result%active_richards_nodes = active_nodes
    result%active_nodes = active_nodes
    result%effective_h_phreatic_cm = classified_effective
    if (branch /= GC_LOW01_BRANCH_INSIDE_PROFILE) return
    ! Explicit typed geometry does not own legacy grid_z(n+1).  The lower
    ! half-cell NN=n regime is classification-only until LOW01-G2 is resolved.
    if (active_nodes >= parameter_set%active_nodes) return
    if (step_duration_day <= 0.0_real64) return

    ! OUTPUT01 deliberately excludes node-snap and branch-boundary cases.
    branch_boundary = .false.
    do k = 1, parameter_set%active_nodes
      if (abs(requested_h_phreatic_cm-parameter_set%z(k)) <= 1.0e-4_real64) then
        branch_boundary = .true.
        exit
      end if
    end do
    if (branch_boundary) return
    if (classified_effective /= requested_h_phreatic_cm) return

    n = parameter_set%active_nodes
    if (origin%active_nodes /= n) return
    if (.not. allocated(origin%h) .or. .not. allocated(origin%theta)) return
    if (.not. allocated(origin%hm1) .or. .not. allocated(origin%thetm1)) return
    if (size(origin%h) /= n .or. size(origin%theta) /= n) return

    result%candidate = origin
    result%candidate%gwlinp = requested_h_phreatic_cm

    boundary = soil_water_boundary_conditions_t()
    boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    boundary%bottom_mode = 1
    boundary%top_flux = origin%qtop
    boundary%top_head = origin%hsurf
    boundary%bottom_flux = 0.0_real64
    ! H_phreatic is carried only by candidate%gwlinp for mode 1.  Keep the
    ! mode-5 lower-face head field semantically neutral in this research route.
    boundary%bottom_head = 0.0_real64

    storage0 = sum(origin%theta*parameter_set%dz) + origin%pond

    call headcalc(worker, workspace, history, result%candidate, evaluation, boundary, numerical, physical, &
                  step_duration_day, parameter_set)

    result%effective_h_phreatic_cm = result%candidate%gwlinp
    result%raw_legacy_gwl_cm = result%candidate%gwl
    result%raw_gwlinp_cm = result%candidate%gwlinp
    result%fllowgwl = result%candidate%fllowgwl
    result%retry_advised = result%candidate%fldecdt .or. worker%control%request_dt_reduction
    result%dt_reduction_requested = result%retry_advised
    result%qbot_cm_per_day = result%candidate%qbot
    result%qbot_materialization_route = GC_LOW01_QBOT_ROUTE_HEADCALC_FLUX_CHAIN
    result%qtop_cm_per_day = result%candidate%qtop
    result%ponding_depth_cm = result%candidate%pond
    result%derived_profile_gwl_available = .false.
    result%derived_profile_gwl_cm = 0.0_real64
    result%nonlinear_iterations = worker%diagnostics%nonlinear_iterations
    result%linear_solves = worker%diagnostics%linear_solves
    result%backtracking_attempts = worker%diagnostics%backtracking_attempts
    result%alternative_solver_calls = worker%diagnostics%alternative_solver_calls
    result%internal_retries = worker%diagnostics%internal_retries

    storage1 = sum(result%candidate%theta*parameter_set%dz) + result%candidate%pond
    result%storage_change_cm = storage1-storage0
    result%complete_profile_storage_change_cm = result%storage_change_cm
    result%mass_residual_cm = result%storage_change_cm - &
         step_duration_day*(-result%candidate%qtop + result%candidate%qbot)

    allocate(result%pressure_head_cm(n), result%water_content(n))
    result%pressure_head_cm = result%candidate%h
    result%water_content = result%candidate%theta

    mass_gate = max(0.0_real64, numerical%total_balance_tolerance)
    result%valid = .not. result%retry_advised .and. .not. result%fllowgwl .and. &
         result%alternative_solver_calls == 0 .and. &
         result%branch == GC_LOW01_BRANCH_INSIDE_PROFILE .and. &
         result%effective_h_phreatic_cm == result%requested_h_phreatic_cm .and. &
         ieee_is_finite(result%qbot_cm_per_day) .and. ieee_is_finite(result%qtop_cm_per_day) .and. &
         ieee_is_finite(result%ponding_depth_cm) .and. &
         all(ieee_is_finite(result%pressure_head_cm)) .and. all(ieee_is_finite(result%water_content)) .and. &
         ieee_is_finite(result%storage_change_cm) .and. ieee_is_finite(result%mass_residual_cm) .and. &
         abs(result%mass_residual_cm) <= mass_gate
  end subroutine gc_low01_run_inside_profile_trial

end module mod_gc_low01_mode1_trial_carrier

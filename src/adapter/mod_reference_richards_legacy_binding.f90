module mod_reference_richards_legacy_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, &
       soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED, SW_SOLVE_FAILED, &
       SW_TEMPORAL_INDICATOR_FAILED, validate_soil_water_request
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       reset_reference_workspace
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, &
       initialize_reference_state_binding, FSI_TOP_MODE_LEGACY_CONTEXT, FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_temporal_indicator, only: evaluate_reference_richards_temporal_indicator
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, &
       a23bu_initialize_worker, a23bu_reset_attempt_diagnostics, a23bu_reset_attempt_control
  use MOD_swap_base, only: swmacro
  use MOD_grid, only: numnod, z, dz, disnod
  use variables, only: h, theta, pond, gwl, dt, swbotb, maxit, maxbacktr, swkimpl, swkmean, &
       dtmin, CritDevBalCp, CritDevBalTot, critdevh2cp, critdevh1cp, critdevponddt, fldtmin, &
       qtop, qbot, hbot
  implicit none
  private

  integer, parameter, public :: FSI_LEGACY_TOP_CONTEXT = FSI_TOP_MODE_LEGACY_CONTEXT

  type, extends(soil_water_solver_workspace_base_t), public :: reference_richards_legacy_workspace_t
     type(reference_richards_workspace_t) :: richards
     type(a23bu_worker_context_t) :: legacy_worker
  end type reference_richards_legacy_workspace_t

  type, extends(soil_water_solver_t), public :: reference_richards_legacy_solver_t
     integer :: reserved = 0
   contains
     procedure :: solve => reference_richards_legacy_solve
     procedure :: evaluate_temporal_indicator => reference_richards_evaluate_temporal_indicator
  end type reference_richards_legacy_solver_t

  public :: build_legacy_reference_request

  interface
     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                         numerical_config, physical_config, explicit_step_duration, parameter_set)
       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
       use mod_reference_richards_workspace, only: reference_richards_workspace_t
       use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
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

  subroutine build_legacy_reference_request(request, parameters, constitutive, top_boundary, source_sink)
    use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, constitutive_hydraulics_provider_t, &
         top_boundary_provider_t, source_sink_provider_t
    type(soil_water_solve_request_t), intent(out) :: request
    type(soil_water_parameter_set_t), target, intent(in) :: parameters
    class(constitutive_hydraulics_provider_t), target, intent(in) :: constitutive
    class(top_boundary_provider_t), target, intent(in), optional :: top_boundary
    class(source_sink_provider_t), target, intent(in), optional :: source_sink

    request%parameters => parameters
    request%physical%macropore_active = (swmacro /= 0)
    request%evaluation%constitutive => constitutive
    if (present(source_sink)) request%evaluation%source_sink => source_sink
    if (present(top_boundary)) then
       request%evaluation%top_boundary => top_boundary
       request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    else
       request%boundary%top_mode = FSI_TOP_MODE_LEGACY_CONTEXT
    end if
    request%step_duration = dt
    request%boundary%bottom_mode = swbotb
    request%boundary%top_flux = qtop
    request%boundary%bottom_flux = qbot
    request%boundary%bottom_head = hbot
    request%numerical%max_iterations = maxit
    request%numerical%max_backtracking = maxbacktr
    request%numerical%conductivity_implicit_mode = swkimpl
    request%numerical%conductivity_mean_method = swkmean
    request%numerical%min_step_duration = dtmin
    request%numerical%compartment_balance_tolerance = CritDevBalCp
    request%numerical%total_balance_tolerance = CritDevBalTot
    request%numerical%head_abs_tolerance = critdevh2cp
    request%numerical%head_rel_tolerance = critdevh1cp
    request%numerical%ponding_tolerance = critdevponddt
    request%base_state%active_nodes = numnod
    allocate(request%base_state%pressure_head(numnod), request%base_state%water_content(numnod))
    request%base_state%pressure_head = h(1:numnod)
    request%base_state%water_content = theta(1:numnod)
    request%base_state%ponding_depth = pond
    request%base_state%groundwater_level = gwl
  end subroutine build_legacy_reference_request

  subroutine reference_richards_legacy_solve(self, request, workspace, result)
    class(reference_richards_legacy_solver_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_result_t), intent(out) :: result

    logical :: ok
    type(a23bu_solver_history_t) :: call_history
    type(reference_richards_state_binding_t) :: state_binding
    integer :: n

    if (self%reserved /= 0) error stop 'invalid legacy solver marker'
    result = soil_water_solve_result_t()
    result%unrounded_mass_balance_residual = ieee_value(0.0_real64, ieee_quiet_nan)
    call validate_legacy_request(request, ok, result%diagnostics%route)
    if (.not. ok) then
       result%status = SW_SOLVE_FAILED
       return
    end if
    n = request%parameters%active_nodes

    select type (ws => workspace)
    type is (reference_richards_legacy_workspace_t)
       if (ws%legacy_worker%active_nodes /= n) then
          call a23bu_initialize_worker(ws%legacy_worker, n)
       end if
       call a23bu_reset_attempt_diagnostics(ws%legacy_worker)
       call a23bu_reset_attempt_control(ws%legacy_worker)
       call initialize_reference_workspace(ws%richards, n)
       call reset_reference_workspace(ws%richards)

       ! F-KT owns the committed/base state. F-SI materializes only this solve's
       ! explicit candidate state and lets HeadCalc rebuild reconstructible
       ! hydraulic intermediates in worker-owned scratch/state.
       call initialize_reference_state_binding(state_binding, request)

       call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding, &
            request%evaluation, request%boundary, request%numerical, request%physical, &
            request%step_duration, request%parameters)

       ! B1.10 SWBOTB=5 prescribes head at the lower boundary face, so qbot is
       ! an output rather than an input boundary condition. HeadCalc already
       ! leaves the exact unrounded compartment residual vector in worker scratch.
       ! Materialize qbot with exact B1.10 watstor()+fluxes() arithmetic grouping
       ! from explicit request/state/provider data; do not call legacy fluxes(),
       ! which mutates integration globals outside the focused solver service.
       if (request%boundary%bottom_mode == 5 .and. .not. state_binding%fldecdt .and. &
           .not. ws%legacy_worker%control%request_dt_reduction) then
          call materialize_prescribed_head_bottom_flux(request, ws%richards, state_binding)
          result%unrounded_mass_balance_residual = sum(ws%richards%residual(1:n))
       end if

       ! SWBOTB=2 prescribes qbot directly. For an accepted solve the final
       ! unrounded compartment residual vector is already the exact vector used
       ! by HeadCalc's total-balance convergence criterion. Publish its sum as
       ! the solver mass diagnostic without changing state, fluxes, or physics.
       if (request%boundary%bottom_mode == 2 .and. .not. state_binding%fldecdt .and. &
           .not. ws%legacy_worker%control%request_dt_reduction) then
          result%unrounded_mass_balance_residual = sum(ws%richards%residual(1:n))
       end if

       result%candidate_state%active_nodes = n
       allocate(result%candidate_state%pressure_head(n), result%candidate_state%water_content(n))
       result%candidate_state%pressure_head = state_binding%h
       result%candidate_state%water_content = state_binding%theta
       result%candidate_state%ponding_depth = state_binding%pond
       result%candidate_state%groundwater_level = state_binding%gwl
       result%top_flux = state_binding%qtop
       result%bottom_flux = state_binding%qbot
       result%diagnostics%nonlinear_iterations = ws%legacy_worker%diagnostics%nonlinear_iterations
       result%diagnostics%jacobian_builds = ws%legacy_worker%diagnostics%jacobian_builds
       result%diagnostics%linear_solves = ws%legacy_worker%diagnostics%linear_solves
       result%diagnostics%backtracking_attempts = ws%legacy_worker%diagnostics%backtracking_attempts
       result%diagnostics%alternative_solver_calls = ws%legacy_worker%diagnostics%alternative_solver_calls
       result%diagnostics%internal_retries = ws%legacy_worker%diagnostics%internal_retries

       if (state_binding%fldecdt .or. ws%legacy_worker%control%request_dt_reduction) then
          result%status = SW_SOLVE_RETRY_ADVISED
          result%retry_advised = .true.
          result%diagnostics%route = 'legacy-reference-retry'
       else
          result%status = SW_SOLVE_CONVERGED
          result%diagnostics%route = 'legacy-reference-bound'
       end if

    class default
       result%status = SW_SOLVE_FAILED
       result%diagnostics%route = 'legacy-workspace-type-error'
    end select
  end subroutine reference_richards_legacy_solve

  subroutine reference_richards_evaluate_temporal_indicator(self, request, solve_result, indicator_request, &
                                                            workspace, indicator_result)
    class(reference_richards_legacy_solver_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(soil_water_temporal_indicator_request_t), intent(in) :: indicator_request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result

    if (self%reserved /= 0) then
       indicator_result = soil_water_temporal_indicator_result_t()
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'invalid-legacy-solver-marker'
       return
    end if

    select type (ws => workspace)
    type is (reference_richards_legacy_workspace_t)
       call evaluate_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)
    class default
       indicator_result = soil_water_temporal_indicator_result_t()
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'legacy-workspace-type-error'
    end select
  end subroutine reference_richards_evaluate_temporal_indicator

  subroutine materialize_prescribed_head_bottom_flux(request, richards, state)
    type(soil_water_solve_request_t), intent(in) :: request
    type(reference_richards_workspace_t), intent(in) :: richards
    type(reference_richards_state_binding_t), intent(inout) :: state
    integer :: n
    real(real64) :: volm1, volact, qrosum, qdrtot, qssdisum

    ! Exact B1.10 arithmetic grouping for inactive macropores:
    ! watstor(): volact = SUM(theta*dz), with volm1 holding the preceding
    ! storage; fluxes(): qbot = qtop + qrosum + qdrtot +
    ! (volact-volm1)/dt - qssdisum.  The explicit solver contract supplies
    ! the equivalent base state and source/sink/root-sink vectors directly.
    n = state%active_nodes
    volm1 = sum(state%thetm1(1:n) * request%parameters%dz(1:n))
    volact = sum(state%theta(1:n) * request%parameters%dz(1:n))
    qrosum = sum(richards%provider_root_sink(1:n))
    qdrtot = sum(richards%sink(1:n))
    qssdisum = sum(richards%source(1:n))
    state%qbot = state%qtop + qrosum + qdrtot + &
         (volact-volm1) / request%step_duration - qssdisum
  end subroutine materialize_prescribed_head_bottom_flux

  subroutine validate_legacy_request(request, ok, route)
    type(soil_water_solve_request_t), intent(in) :: request
    logical, intent(out) :: ok
    character(len=*), intent(out) :: route
    logical :: common_ok

    ok = .false.
    route = 'legacy-request-invalid'
    if (.not. associated(request%evaluation%constitutive)) then
       route = 'constitutive-provider-required'
       return
    end if
    call validate_soil_water_request(request, common_ok)
    if (.not. common_ok) return
    if (request%physical%macropore_active) then
       route = 'explicit-macropore-deferred'
       return
    end if
    if (request%numerical%conductivity_implicit_mode /= 0) then
       route = 'legacy-implicit-k-deferred'
       return
    end if
    if (fldtmin) then
       route = 'legacy-min-dt-deferred'
       return
    end if
    if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2 .and. &
        request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2) then
       route = 'legacy-bottom-mode-deferred'
       return
    end if
    if (request%boundary%top_mode /= FSI_TOP_MODE_EXPLICIT_FLUX) then
       route = 'explicit-top-mode-required'
       return
    end if
    if (.not. associated(request%evaluation%top_boundary)) then
       route = 'explicit-top-provider-required'
       return
    end if
    if (.not. associated(request%evaluation%source_sink)) then
       route = 'source-sink-provider-required'
       return
    end if
    ok = .true.
    route = 'legacy-request-bound'
  end subroutine validate_legacy_request

  logical function same_real(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    same_real = abs(a-b) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function same_real

end module mod_reference_richards_legacy_binding

module mod_reference_richards_legacy_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, &
       SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED, SW_SOLVE_FAILED, validate_soil_water_request
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       reset_reference_workspace
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, &
       initialize_reference_state_binding, FSI_TOP_MODE_LEGACY_CONTEXT, FSI_TOP_MODE_EXPLICIT_FLUX
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
  end type reference_richards_legacy_solver_t

  public :: build_legacy_reference_request

  interface
     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions)
       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
       use mod_reference_richards_workspace, only: reference_richards_workspace_t
       use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
       use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t
       type(a23bu_worker_context_t), intent(inout), optional :: worker
       type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
       type(a23bu_solver_history_t), target, intent(inout), optional :: history
       type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
       type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
       type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
     end subroutine headcalc
  end interface

contains

  subroutine build_legacy_reference_request(request, parameters, constitutive, top_boundary)
    use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, constitutive_hydraulics_provider_t, &
         top_boundary_provider_t
    type(soil_water_solve_request_t), intent(out) :: request
    type(soil_water_parameter_set_t), target, intent(in) :: parameters
    class(constitutive_hydraulics_provider_t), target, intent(in) :: constitutive
    class(top_boundary_provider_t), target, intent(in), optional :: top_boundary

    request%parameters => parameters
    request%evaluation%constitutive => constitutive
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

    if (self%reserved /= 0) error stop 'invalid legacy solver marker'
    result = soil_water_solve_result_t()
    result%unrounded_mass_balance_residual = ieee_value(0.0_real64, ieee_quiet_nan)
    call validate_legacy_request(request, ok, result%diagnostics%route)
    if (.not. ok) then
       result%status = SW_SOLVE_FAILED
       return
    end if

    select type (ws => workspace)
    type is (reference_richards_legacy_workspace_t)
       if (ws%legacy_worker%active_nodes /= numnod) then
          call a23bu_initialize_worker(ws%legacy_worker, numnod)
       end if
       call a23bu_reset_attempt_diagnostics(ws%legacy_worker)
       call a23bu_reset_attempt_control(ws%legacy_worker)
       call initialize_reference_workspace(ws%richards, numnod)
       call reset_reference_workspace(ws%richards)

       ! F-KT owns the committed/base state. F-SI materializes only this solve's
       ! explicit candidate state and lets HeadCalc rebuild reconstructible
       ! hydraulic intermediates in worker-owned scratch/state.
       call initialize_reference_state_binding(state_binding, request)

       call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding, &
            request%evaluation, request%boundary)

       result%candidate_state%active_nodes = numnod
       allocate(result%candidate_state%pressure_head(numnod), result%candidate_state%water_content(numnod))
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

  subroutine validate_legacy_request(request, ok, route)
    type(soil_water_solve_request_t), intent(in) :: request
    logical, intent(out) :: ok
    character(len=*), intent(out) :: route
    logical :: common_ok

    ok = .false.
    route = 'legacy-request-invalid'
    call validate_soil_water_request(request, common_ok)
    if (.not. common_ok) return
    if (swmacro /= 0) then
       route = 'legacy-macropore-deferred'
       return
    end if
    if (swkimpl /= 0) then
       route = 'legacy-implicit-k-deferred'
       return
    end if
    if (fldtmin) then
       route = 'legacy-min-dt-deferred'
       return
    end if
    if (swbotb /= 7 .and. swbotb /= -2) then
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
    if (request%boundary%bottom_mode /= swbotb) then
       route = 'legacy-bottom-mode-mismatch'
       return
    end if
    if (request%parameters%active_nodes /= numnod) return
    if (maxval(abs(request%parameters%z-z(1:numnod))) > 0.0_real64) return
    if (maxval(abs(request%parameters%dz-dz(1:numnod))) > 0.0_real64) return
    if (maxval(abs(request%parameters%node_distance-disnod(1:numnod))) > 0.0_real64) return
    if (.not. same_real(request%step_duration, dt)) return
    if (request%numerical%max_iterations /= maxit) return
    if (request%numerical%max_backtracking /= maxbacktr) return
    if (request%numerical%conductivity_implicit_mode /= swkimpl) return
    if (request%numerical%conductivity_mean_method /= swkmean) return
    if (.not. same_real(request%numerical%min_step_duration, dtmin)) return
    if (.not. same_real(request%numerical%compartment_balance_tolerance, CritDevBalCp)) return
    if (.not. same_real(request%numerical%total_balance_tolerance, CritDevBalTot)) return
    if (.not. same_real(request%numerical%head_abs_tolerance, critdevh2cp)) return
    if (.not. same_real(request%numerical%head_rel_tolerance, critdevh1cp)) return
    if (.not. same_real(request%numerical%ponding_tolerance, critdevponddt)) return
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

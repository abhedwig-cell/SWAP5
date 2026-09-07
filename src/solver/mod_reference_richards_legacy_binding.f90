module mod_reference_richards_legacy_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, &
       SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED, SW_SOLVE_FAILED, validate_soil_water_request
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       reset_reference_workspace
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker, &
       a23bu_reset_attempt_diagnostics, a23bu_reset_attempt_control
  use MOD_swap_base, only: swmacro
  use MOD_grid, only: numnod, z, dz, disnod
  use variables, only: h, theta, pond, gwl, hm1, thetm1, pondm1, gwlm1, dt, swbotb, &
       maxit, maxbacktr, swkimpl, swkmean, dtmin, CritDevBalCp, CritDevBalTot, &
       critdevh2cp, critdevh1cp, critdevponddt, fldtmin, qtop, qbot, fldecdt, numbit
  implicit none
  private

  integer, parameter, public :: FSI_LEGACY_TOP_CONTEXT = -9001

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
     subroutine headcalc(worker)
       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
       type(a23bu_worker_context_t), intent(inout), optional :: worker
     end subroutine headcalc
  end interface

contains

  subroutine build_legacy_reference_request(request, parameters, constitutive)
    use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, constitutive_hydraulics_provider_t
    type(soil_water_solve_request_t), intent(out) :: request
    type(soil_water_parameter_set_t), target, intent(in) :: parameters
    class(constitutive_hydraulics_provider_t), target, intent(in) :: constitutive

    request%parameters => parameters
    request%evaluation%constitutive => constitutive
    request%step_duration = dt
    request%boundary%top_mode = FSI_LEGACY_TOP_CONTEXT
    request%boundary%bottom_mode = swbotb
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
    real(real64), allocatable :: h_saved(:), theta_saved(:), hm1_saved(:), thetm1_saved(:)
    real(real64) :: pond_saved, gwl_saved, pondm1_saved, gwlm1_saved, qtop_saved, qbot_saved
    logical :: fldecdt_saved
    integer :: numbit_saved

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

       allocate(h_saved(numnod), theta_saved(numnod), hm1_saved(numnod), thetm1_saved(numnod))
       h_saved = h(1:numnod)
       theta_saved = theta(1:numnod)
       hm1_saved = hm1(1:numnod)
       thetm1_saved = thetm1(1:numnod)
       pond_saved = pond
       gwl_saved = gwl
       pondm1_saved = pondm1
       gwlm1_saved = gwlm1
       qtop_saved = qtop
       qbot_saved = qbot
       fldecdt_saved = fldecdt
       numbit_saved = numbit

       h(1:numnod) = request%base_state%pressure_head
       theta(1:numnod) = request%base_state%water_content
       hm1(1:numnod) = request%base_state%pressure_head
       thetm1(1:numnod) = request%base_state%water_content
       pond = request%base_state%ponding_depth
       gwl = request%base_state%groundwater_level
       pondm1 = request%base_state%ponding_depth
       gwlm1 = request%base_state%groundwater_level
       fldecdt = .false.

       call headcalc(ws%legacy_worker)

       result%candidate_state%active_nodes = numnod
       allocate(result%candidate_state%pressure_head(numnod), result%candidate_state%water_content(numnod))
       result%candidate_state%pressure_head = h(1:numnod)
       result%candidate_state%water_content = theta(1:numnod)
       result%candidate_state%ponding_depth = pond
       result%candidate_state%groundwater_level = gwl
       result%top_flux = qtop
       result%bottom_flux = qbot
       result%diagnostics%nonlinear_iterations = ws%legacy_worker%diagnostics%nonlinear_iterations
       result%diagnostics%jacobian_builds = ws%legacy_worker%diagnostics%jacobian_builds
       result%diagnostics%linear_solves = ws%legacy_worker%diagnostics%linear_solves
       result%diagnostics%backtracking_attempts = ws%legacy_worker%diagnostics%backtracking_attempts
       result%diagnostics%alternative_solver_calls = ws%legacy_worker%diagnostics%alternative_solver_calls
       result%diagnostics%internal_retries = ws%legacy_worker%diagnostics%internal_retries

       if (fldecdt .or. ws%legacy_worker%control%request_dt_reduction) then
          result%status = SW_SOLVE_RETRY_ADVISED
          result%retry_advised = .true.
          result%diagnostics%route = 'legacy-reference-retry'
       else
          result%status = SW_SOLVE_CONVERGED
          result%diagnostics%route = 'legacy-reference-bound'
       end if

       h(1:numnod) = h_saved
       theta(1:numnod) = theta_saved
       hm1(1:numnod) = hm1_saved
       thetm1(1:numnod) = thetm1_saved
       pond = pond_saved
       gwl = gwl_saved
       pondm1 = pondm1_saved
       gwlm1 = gwlm1_saved
       qtop = qtop_saved
       qbot = qbot_saved
       fldecdt = fldecdt_saved
       numbit = numbit_saved
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
    if (request%boundary%top_mode /= FSI_LEGACY_TOP_CONTEXT) then
       route = 'legacy-top-context-required'
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

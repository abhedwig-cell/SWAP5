module mod_b110_production_soil_water_task2
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_reset_soil_water_trial_result
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_top_boundary_result_t, soil_water_solver_t, &
       soil_water_solver_workspace_base_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED, SW_SOLVE_FAILED, &
       SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use MOD_swap_base, only: swmacro, swdra, swpondmx, swfrost, swrunon
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_MvG, only: cofgen
  use MOD_meteo, only: nraidt, epond, peva, empreva
  use MOD_irrigation, only: nird, qssdi
  use MOD_snow, only: melt
  use MOD_frost, only: rfcp
  use MOD_drain, only: qdra, nrlevs
  use MOD_top, only: q0, flrunoff, ftoph, hsurf
  use variables, only: h, theta, pond, pondm1, gwl, qtop, qbot, hbot, runon, epd, reva, runots, qrot, &
       dt, swbotb, swkimpl, swkmean, dtmin, maxit, maxbacktr, CritDevBalCp, CritDevBalTot, &
       critdevh2cp, critdevh1cp, critdevponddt, fldtmin, fldecdt, pondmx, rsro, rsroexp, swredu, &
       kmean, numbit, itnumb
  implicit none
  private

  ! F-SI35 keeps legacy B1.10 behavior available without leaving a second
  ! production entry point in MOD_SoilWater. The compatibility implementation
  ! is deliberately behind the same abstract soil_water_solver_t boundary.
  ! It is not promoted to the qualified explicit Full Richards production
  ! profile merely by existing; the F-SI33 profile remains authoritative.
  type, extends(soil_water_solver_workspace_base_t) :: b110_legacy_compat_workspace_t
    type(a23bu_worker_context_t), pointer :: worker => null()
  end type b110_legacy_compat_workspace_t

  type, extends(soil_water_solver_t) :: b110_legacy_compat_solver_t
    integer :: reserved = 0
  contains
    procedure :: solve => b110_legacy_compat_solve
  end type b110_legacy_compat_solver_t

  type(a23bu_worker_context_t), target, save :: standalone_worker

  public :: try_b110_production_task2
  public :: run_b110_production_task2

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

  subroutine run_b110_production_task2(worker)
    type(a23bu_worker_context_t), target, intent(inout), optional :: worker

    if (present(worker)) then
      call execute_b110_production_task2(worker)
    else
      call execute_b110_production_task2(standalone_worker)
    end if
  end subroutine run_b110_production_task2

  subroutine execute_b110_production_task2(worker)
    type(a23bu_worker_context_t), target, intent(inout) :: worker
    logical :: handled

    call try_b110_production_task2(worker, handled)
    if (.not. handled) call run_b110_legacy_compatibility_task2(worker)
  end subroutine execute_b110_production_task2

  subroutine try_b110_production_task2(worker, handled)
    type(a23bu_worker_context_t), intent(inout) :: worker
    logical, intent(out) :: handled
    type(soil_water_parameter_set_t), target :: parameters
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(b110_dynamic_top_boundary_solver_provider_t), target :: dynamic_top
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_top_boundary_result_t) :: initial_surface, accepted_surface
    real(real64), allocatable, target :: drainage_copy(:,:), subsurface_copy(:), root_copy(:)
    real(real64) :: potential_bare_evaporation
    logical :: sensitivity_route_admitted
    integer :: n, stat_index

    handled = .false.
    call a23bu_reset_soil_water_trial_result(worker)
    if (.not. production_route_admitted()) return

    ! From this point the explicit production route is the sole hydraulic
    ! authority for this trial. A started solve never falls through to the
    ! compatibility solver.
    handled = .true.
    worker%soil_water_trial%typed_attempted = .true.
    worker%soil_water_trial%route = 'typed-task2-started'

    n = numnod
    parameters%parameter_set_id = int(worker%worker_id, int64)
    parameters%active_nodes = n
    allocate(parameters%z(n), parameters%dz(n), parameters%node_distance(n))
    parameters%z = z(1:n)
    parameters%dz = dz(1:n)
    parameters%node_distance = disnod(1:n)

    call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen(:,1:n))
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)

    allocate(drainage_copy(nrlevs,n), subsurface_copy(n), root_copy(n))
    drainage_copy = qdra(1:nrlevs,1:n)
    subsurface_copy = qssdi(1:n)
    root_copy = qrot(1:n)
    call bind_b110_source_sink_provider(source_sink, drainage_copy, subsurface_copy, root_copy)

    if (swredu == 0) then
      potential_bare_evaporation = peva
    else
      potential_bare_evaporation = empreva
    end if
    call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top, parameters, hydraulic_parameters, &
         swkmean, pondm1, dt, nraidt, nird, melt, 0.0_real64, potential_bare_evaporation, epond, &
         pondmx, rsro, rsroexp)

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state%active_nodes = n
    allocate(request%base_state%pressure_head(n), request%base_state%water_content(n))
    request%base_state%pressure_head = h(1:n)
    request%base_state%water_content = theta(1:n)
    request%base_state%ponding_depth = pond
    request%base_state%groundwater_level = gwl
    request%step_duration = dt
    request%boundary%top_mode = FSI_TOP_MODE_DYNAMIC_PROVIDER
    request%boundary%bottom_mode = swbotb
    request%boundary%top_flux = qtop
    request%boundary%bottom_flux = qbot
    request%boundary%bottom_head = hbot
    request%physical%macropore_active = .false.
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
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%dynamic_top_boundary => dynamic_top

    ! F-SI28/F-SI30 qualify the local qbot tangent only on the smooth dynamic
    ! surface-flux route. Do not infer tangent validity for atmospheric-head,
    ! ponded-head or runoff regimes merely because SWBOTB=2 is active.
    call dynamic_top%evaluate(h(1), theta(1), pond, request%boundary, initial_surface)
    if (initial_surface%status /= SW_TOP_BOUNDARY_AVAILABLE) &
         error stop 'F-KT15: initial dynamic surface route unavailable'
    sensitivity_route_admitted = swbotb == 2 .and. &
         initial_surface%regime == SW_TOP_BOUNDARY_REGIME_FLUX .and. &
         trim(initial_surface%route) == 'surface-flux'
    request%request_interface_sensitivity = sensitivity_route_admitted

    call invoke_soil_water_solver(solver, request, workspace, result)
    call accumulate_solver_diagnostics(worker, result)
    worker%soil_water_trial%route = result%diagnostics%route
    worker%soil_water_trial%interface_sensitivity_backsolves = &
         result%diagnostics%interface_sensitivity_backsolves

    select case (result%status)
    case (SW_SOLVE_CONVERGED)
      call dynamic_top%evaluate(result%candidate_state%pressure_head(1), &
           result%candidate_state%water_content(1), result%candidate_state%ponding_depth, &
           request%boundary, accepted_surface)
      if (accepted_surface%status /= SW_TOP_BOUNDARY_AVAILABLE) &
           error stop 'F-KT15: accepted dynamic surface postimage unavailable'

      ! Materialize only accepted hydraulic outputs and the accepted surface-process
      ! result required by the unchanged legacy continuation. No solver scratch leaks.
      h(1:n) = result%candidate_state%pressure_head
      theta(1:n) = result%candidate_state%water_content
      pond = result%candidate_state%ponding_depth
      gwl = result%candidate_state%groundwater_level
      qtop = result%top_flux
      qbot = result%bottom_flux
      reva = accepted_surface%bare_soil_evaporation
      epd = accepted_surface%ponded_water_evaporation
      runots = accepted_surface%runoff_depth
      q0 = accepted_surface%net_potential_surface_flux
      hsurf = accepted_surface%surface_head
      ftoph = (accepted_surface%regime == SW_TOP_BOUNDARY_REGIME_HEAD)
      flrunoff = accepted_surface%runoff_potential .or. abs(accepted_surface%runoff_depth) > 0.0_real64
      if (ftoph) kmean(1) = accepted_surface%surface_face_conductivity
      runon = 0.0_real64
      fldecdt = .false.

      ! Preserve the legacy accepted-iteration statistics owned by HeadCalc.
      numbit = result%diagnostics%nonlinear_iterations
      if (numbit > 0) then
        stat_index = min(100,numbit)
        itnumb(stat_index,1) = itnumb(stat_index,1) + 1
        itnumb(stat_index,2) = itnumb(stat_index,2) + result%diagnostics%backtracking_attempts
        worker%control%last_numbit = numbit
      end if

      worker%soil_water_trial%typed_accepted = .true.
      if (sensitivity_route_admitted .and. &
          accepted_surface%regime == SW_TOP_BOUNDARY_REGIME_FLUX .and. &
          trim(accepted_surface%route) == 'surface-flux' .and. &
          result%interface_sensitivity%available) then
        worker%soil_water_trial%sensitivity_available = .true.
        worker%soil_water_trial%dh_bottom_dq_bottom = &
             result%interface_sensitivity%dh_bottom_dq_bottom
        worker%soil_water_trial%sensitivity_method = result%interface_sensitivity%method
      end if

    case (SW_SOLVE_RETRY_ADVISED)
      ! Existing SoilWaterStateVar(2) + TimeControl retry path owns restoration.
      ! Do not publish sensitivity or accepted result metadata from this rejected trial.
      worker%soil_water_trial%retry_advised = .true.
      worker%soil_water_trial%sensitivity_available = .false.
      fldecdt = .true.

    case (SW_SOLVE_FAILED)
      worker%soil_water_trial%sensitivity_available = .false.
      error stop 'F-KT15: admitted typed soil-water solve failed closed'

    case default
      worker%soil_water_trial%sensitivity_available = .false.
      error stop 'F-KT15: invalid typed soil-water solve status'
    end select
  end subroutine try_b110_production_task2

  logical function production_route_admitted() result(admitted)
    real(real64) :: potential_bare_evaporation

    admitted = .false.
    if (numnod <= 0 .or. nrlevs <= 0) return
    if (swmacro /= 0) return
    if (swfrost /= 0) return
    if (swdra == 2) return
    if (swpondmx /= 0) return
    if (swrunon /= 0) return
    if (swkimpl /= 0) return
    if (fldtmin) return
    if (swkmean < 1 .or. swkmean > 6) return
    if (swbotb /= 7 .and. swbotb /= -2 .and. swbotb /= 5 .and. swbotb /= 2) return
    if (dt <= 0.0_real64 .or. dtmin < 0.0_real64) return
    if (maxit <= 0 .or. maxbacktr <= 0) return
    if (rsro < 0.0_real64 .or. rsroexp /= 1.0_real64 .or. pondmx < 0.0_real64) return
    if (any(rfcp(1:numnod) /= 1.0_real64)) return
    if (any(abs(qrot(1:numnod)) > 0.0_real64)) return

    if (swredu == 0) then
      potential_bare_evaporation = peva
    else
      potential_bare_evaporation = empreva
    end if
    if (potential_bare_evaporation < 0.0_real64 .or. epond < 0.0_real64) return

    if (any(.not. ieee_is_finite(h(1:numnod)))) return
    if (any(.not. ieee_is_finite(theta(1:numnod)))) return
    if (.not. ieee_is_finite(pond) .or. .not. ieee_is_finite(gwl)) return
    if (.not. ieee_is_finite(qtop) .or. .not. ieee_is_finite(qbot) .or. .not. ieee_is_finite(hbot)) return
    if (.not. ieee_is_finite(nraidt) .or. .not. ieee_is_finite(nird) .or. .not. ieee_is_finite(melt)) return
    if (.not. ieee_is_finite(potential_bare_evaporation) .or. .not. ieee_is_finite(epond)) return
    if (.not. ieee_is_finite(pondmx) .or. .not. ieee_is_finite(rsro) .or. .not. ieee_is_finite(rsroexp)) return
    if (any(.not. ieee_is_finite(qdra(1:nrlevs,1:numnod)))) return
    if (any(.not. ieee_is_finite(qssdi(1:numnod)))) return
    if (any(.not. ieee_is_finite(qrot(1:numnod)))) return
    if (any(.not. ieee_is_finite(cofgen(:,1:numnod)))) return

    admitted = .true.
  end function production_route_admitted

  subroutine run_b110_legacy_compatibility_task2(worker)
    type(a23bu_worker_context_t), target, intent(inout) :: worker
    type(soil_water_parameter_set_t), target :: parameters
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(b110_legacy_compat_solver_t) :: solver
    type(b110_legacy_compat_workspace_t) :: workspace
    integer :: n

    n = numnod
    if (n <= 0) error stop 'F-SI35: legacy compatibility route requires active nodes'

    parameters%parameter_set_id = int(worker%worker_id, int64)
    parameters%active_nodes = n
    allocate(parameters%z(n), parameters%dz(n), parameters%node_distance(n))
    parameters%z = z(1:n)
    parameters%dz = dz(1:n)
    parameters%node_distance = disnod(1:n)

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state%active_nodes = n
    allocate(request%base_state%pressure_head(n), request%base_state%water_content(n))
    request%base_state%pressure_head = h(1:n)
    request%base_state%water_content = theta(1:n)
    request%base_state%ponding_depth = pond
    request%base_state%groundwater_level = gwl
    request%step_duration = dt
    request%boundary%bottom_mode = swbotb
    request%boundary%top_flux = qtop
    request%boundary%bottom_flux = qbot
    request%boundary%bottom_head = hbot
    request%physical%macropore_active = (swmacro /= 0)
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

    workspace%worker => worker
    worker%soil_water_trial%typed_attempted = .true.
    worker%soil_water_trial%route = 'legacy-compat-started'
    call invoke_soil_water_solver(solver, request, workspace, result)
    worker%soil_water_trial%route = result%diagnostics%route
    worker%soil_water_trial%sensitivity_available = .false.

    select case (result%status)
    case (SW_SOLVE_CONVERGED)
      h(1:n) = result%candidate_state%pressure_head
      theta(1:n) = result%candidate_state%water_content
      pond = result%candidate_state%ponding_depth
      gwl = result%candidate_state%groundwater_level
      qtop = result%top_flux
      qbot = result%bottom_flux
      worker%soil_water_trial%typed_accepted = .true.
    case (SW_SOLVE_RETRY_ADVISED)
      worker%soil_water_trial%retry_advised = .true.
      fldecdt = .true.
    case (SW_SOLVE_FAILED)
      error stop 'F-SI35: legacy compatibility solver failed closed'
    case default
      error stop 'F-SI35: invalid legacy compatibility solver status'
    end select
  end subroutine run_b110_legacy_compatibility_task2

  subroutine invoke_soil_water_solver(solver, request, workspace, result)
    class(soil_water_solver_t), intent(inout) :: solver
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_result_t), intent(out) :: result

    call solver%solve(request, workspace, result)
  end subroutine invoke_soil_water_solver

  subroutine b110_legacy_compat_solve(self, request, workspace, result)
    class(b110_legacy_compat_solver_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_result_t), intent(out) :: result
    integer :: n
    integer :: iter0, jac0, linear0, back0, alt0, retry0

    result = soil_water_solve_result_t()
    result%unrounded_mass_balance_residual = ieee_value(0.0_real64, ieee_quiet_nan)
    result%diagnostics%route = 'legacy-compat-invalid'

    if (self%reserved /= 0) then
      result%status = SW_SOLVE_FAILED
      return
    end if
    if (.not. associated(request%parameters)) then
      result%status = SW_SOLVE_FAILED
      return
    end if
    n = request%parameters%active_nodes
    if (n <= 0 .or. n /= numnod) then
      result%status = SW_SOLVE_FAILED
      return
    end if
    if (request%base_state%active_nodes /= n) then
      result%status = SW_SOLVE_FAILED
      return
    end if
    if (.not. allocated(request%base_state%pressure_head) .or. &
        .not. allocated(request%base_state%water_content)) then
      result%status = SW_SOLVE_FAILED
      return
    end if
    if (size(request%base_state%pressure_head) /= n .or. &
        size(request%base_state%water_content) /= n) then
      result%status = SW_SOLVE_FAILED
      return
    end if

    select type (ws => workspace)
    type is (b110_legacy_compat_workspace_t)
      if (.not. associated(ws%worker)) then
        result%status = SW_SOLVE_FAILED
        return
      end if

      iter0 = ws%worker%diagnostics%nonlinear_iterations
      jac0 = ws%worker%diagnostics%jacobian_builds
      linear0 = ws%worker%diagnostics%linear_solves
      back0 = ws%worker%diagnostics%backtracking_attempts
      alt0 = ws%worker%diagnostics%alternative_solver_calls
      retry0 = ws%worker%diagnostics%internal_retries

      ! This is the only legacy HeadCalc compatibility invocation left outside
      ! the Full Richards binding itself. It is an adapter-boundary call, never
      ! a process/runtime API. Physics and global continuation behavior are
      ! intentionally identical to the pre-F-SI35 fallback.
      call headcalc(ws%worker, history=ws%worker%history)

      result%candidate_state%active_nodes = n
      allocate(result%candidate_state%pressure_head(n), result%candidate_state%water_content(n))
      result%candidate_state%pressure_head = h(1:n)
      result%candidate_state%water_content = theta(1:n)
      result%candidate_state%ponding_depth = pond
      result%candidate_state%groundwater_level = gwl
      result%top_flux = qtop
      result%bottom_flux = qbot
      result%diagnostics%nonlinear_iterations = max(0, ws%worker%diagnostics%nonlinear_iterations - iter0)
      result%diagnostics%jacobian_builds = max(0, ws%worker%diagnostics%jacobian_builds - jac0)
      result%diagnostics%linear_solves = max(0, ws%worker%diagnostics%linear_solves - linear0)
      result%diagnostics%backtracking_attempts = max(0, ws%worker%diagnostics%backtracking_attempts - back0)
      result%diagnostics%alternative_solver_calls = max(0, ws%worker%diagnostics%alternative_solver_calls - alt0)
      result%diagnostics%internal_retries = max(0, ws%worker%diagnostics%internal_retries - retry0)
      result%diagnostics%route = 'legacy-compat-interface'

      if (fldecdt .or. ws%worker%control%request_dt_reduction) then
        result%status = SW_SOLVE_RETRY_ADVISED
        result%retry_advised = .true.
      else
        result%status = SW_SOLVE_CONVERGED
      end if

    class default
      result%status = SW_SOLVE_FAILED
      result%diagnostics%route = 'legacy-compat-workspace'
    end select
  end subroutine b110_legacy_compat_solve

  subroutine accumulate_solver_diagnostics(worker, result)
    type(a23bu_worker_context_t), intent(inout) :: worker
    type(soil_water_solve_result_t), intent(in) :: result
    worker%diagnostics%headcalc_calls = worker%diagnostics%headcalc_calls + 1
    worker%diagnostics%nonlinear_iterations = worker%diagnostics%nonlinear_iterations + &
         result%diagnostics%nonlinear_iterations
    worker%diagnostics%jacobian_builds = worker%diagnostics%jacobian_builds + &
         result%diagnostics%jacobian_builds
    worker%diagnostics%linear_solves = worker%diagnostics%linear_solves + &
         result%diagnostics%linear_solves
    worker%diagnostics%backtracking_attempts = worker%diagnostics%backtracking_attempts + &
         result%diagnostics%backtracking_attempts
    worker%diagnostics%alternative_solver_calls = worker%diagnostics%alternative_solver_calls + &
         result%diagnostics%alternative_solver_calls
    worker%diagnostics%internal_retries = worker%diagnostics%internal_retries + &
         result%diagnostics%internal_retries
  end subroutine accumulate_solver_diagnostics

end module mod_b110_production_soil_water_task2
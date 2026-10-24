module mod_reference_richards_legacy_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value, ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_top_boundary_result_t, &
       soil_water_numerical_config_t, &
       soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED, SW_SOLVE_FAILED, SW_TOP_BOUNDARY_AVAILABLE, &
       SW_TEMPORAL_INDICATOR_FAILED, validate_soil_water_request, evaluate_resistive_bottom_boundary
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, ensure_reference_workspace_shape, &
       prepare_reference_tridag_factorization_capture, &
       release_reference_tridag_factorization_capture
  use mod_reference_linear_solver, only: reference_tridag_backsolve
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, &
       initialize_reference_state_binding, FSI_TOP_MODE_LEGACY_CONTEXT, FSI_TOP_MODE_EXPLICIT_FLUX, &
       FSI_TOP_MODE_DYNAMIC_PROVIDER
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
     type(reference_richards_state_binding_t) :: state_binding
     type(soil_water_top_boundary_result_t) :: converged_surface_result
     logical :: gross_surface_sources_available = .false.
     real(real64) :: precipitation_rate_cm_day = 0.0_real64
     real(real64) :: irrigation_rate_cm_day = 0.0_real64
     real(real64) :: snowmelt_rate_cm_day = 0.0_real64
     real(real64) :: runon_rate_cm_day = 0.0_real64
     ! Worker-only numerical history, never a physical checkpoint/restart field.
     real(real64), allocatable :: trial_origin_key(:), trial_guess_head(:)
     real(real64), allocatable :: trial_endpoint_key(:)
     real(real64) :: trial_guess_duration = 0.0_real64
     integer(int64) :: trial_parameter_id = 0_int64
     logical :: trial_guess_available = .false.
     integer :: warm_start_attempts = 0, warm_start_fallbacks = 0, warm_start_invalidations = 0
     integer :: warm_start_continuations = 0
   end type reference_richards_legacy_workspace_t

  type, extends(soil_water_solver_t), public :: reference_richards_legacy_solver_t
     integer :: reserved = 0
   contains
     procedure :: solve => reference_richards_legacy_solve
     procedure :: evaluate_temporal_indicator => reference_richards_evaluate_temporal_indicator
  end type reference_richards_legacy_solver_t

  public :: build_legacy_reference_request
  public :: clear_reference_trial_guess

  interface
     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                         numerical_config, physical_config, explicit_step_duration, parameter_set, accepted_top_result)
       use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
       use mod_reference_richards_workspace, only: reference_richards_workspace_t
       use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
       use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
            soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t, &
            soil_water_top_boundary_result_t
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
       type(soil_water_top_boundary_result_t), intent(out), optional :: accepted_top_result
     end subroutine headcalc
  end interface

contains

  subroutine clear_reference_trial_guess(workspace)
    type(reference_richards_legacy_workspace_t), intent(inout) :: workspace
    workspace%trial_guess_available = .false.
  end subroutine clear_reference_trial_guess

  subroutine trial_guess_key(request, key, allowed, allow_line_search_retry)
    type(soil_water_solve_request_t), intent(in) :: request
    real(real64), allocatable, intent(out) :: key(:)
    logical, intent(out) :: allowed
    logical, intent(in), optional :: allow_line_search_retry
    logical :: selected
    real(real64) :: source(request%parameters%active_nodes), sink(request%parameters%active_nodes)
    real(real64) :: root(request%parameters%active_nodes)

    allowed=.false.
    selected=request%numerical%reuse_trial_head
    if(present(allow_line_search_retry))selected=selected.or.allow_line_search_retry
    if(.not.selected.or..not.request%numerical%consistent_provider_conductivity)return
    if(request%numerical%conductivity_mean_method/=1)return
    if(request%physical%macropore_active.or.request%request_interface_sensitivity)return
    if(request%boundary%bottom_mode/=7.or.request%boundary%top_mode/=FSI_TOP_MODE_DYNAMIC_PROVIDER)return
    if(allocated(request%physical%matrix_area_fraction))return
    if(.not.associated(request%evaluation%dynamic_top_boundary).or. &
       .not.associated(request%evaluation%constitutive))return
    select type(top=>request%evaluation%dynamic_top_boundary)
    type is(b110_dynamic_top_boundary_solver_provider_t)
      if(.not.top%implicit_conductivity.or.top%implicit_pond_evaporation.or. &
         top%macropore_pond_donor_active.or.top%matrix_source_area_partition)return
      if(top%conductivity_mean_method/=1)return
      if(.not.associated(top%hydraulics))return
      select type(hyd=>request%evaluation%constitutive)
      type is(b110_default_mvg_provider_t)
        if(.not.associated(hyd%parameters,top%hydraulics))return
        if(.not.hyd%parameters%continuous_saturation_conductivity.or.hyd%parameters%ksatexm_extension_enabled.or. &
           hyd%parameters%elastic_storage_active.or.hyd%parameters%conductivity_power_tail_enabled)return
      class default
        return
      end select
      source=0.0_real64;sink=0.0_real64;root=0.0_real64
      if(associated(request%evaluation%source_sink))then
        select type(provider=>request%evaluation%source_sink)
        type is(b110_source_sink_provider_t)
          call provider%evaluate(request%base_state%pressure_head,request%base_state%water_content,source,sink)
        class default
          return
        end select
      end if
      if(associated(request%evaluation%root_sink))then
        select type(provider=>request%evaluation%root_sink)
        type is(b110_root_sink_provider_t)
          call provider%evaluate(request%base_state%pressure_head,request%base_state%water_content,root)
        class default
          return
        end select
      end if
      key=[request%base_state%pressure_head,request%base_state%water_content, &
        request%base_state%ponding_depth,request%base_state%groundwater_level, &
        request%parameters%z,request%parameters%dz,request%parameters%node_distance, &
        reshape(top%hydraulics%cofgen,[size(top%hydraulics%cofgen)]),source,sink,root, &
        top%precipitation_rate,top%irrigation_rate,top%snowmelt_rate,top%runon_rate, &
        top%potential_bare_soil_evaporation,top%potential_pond_evaporation, &
        top%ponding_max,top%runoff_resistance,top%runoff_exponent,top%fixed_top_node_conductivity, &
        request%boundary%top_flux,request%boundary%top_head,request%boundary%bottom_flux,request%boundary%bottom_head]
      allowed=all(ieee_is_finite(key))
    class default
      return
    end select
  end subroutine trial_guess_key

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

    logical :: ok, sensitivity_capture, warm_allowed, warm_used, same_origin, same_forcing, continuation
    logical :: line_search_retry_allowed
    type(soil_water_numerical_config_t) :: warm_config, cold_config
    real(real64), allocatable :: origin_key(:), guess(:), line_search_route_key(:)
    real(real64) :: duration_ratio
    type(a23bu_solver_history_t) :: call_history
    type(soil_water_top_boundary_result_t) :: final_top
    integer :: n, tangent_ierror, interface_sensitivity_backsolves, reset_calls_before
    integer(int64) :: reset_bytes_before

    if (self%reserved /= 0) error stop 'invalid legacy solver marker'
    result = soil_water_solve_result_t()
    result%unrounded_mass_balance_residual = ieee_value(0.0_real64, ieee_quiet_nan)
    interface_sensitivity_backsolves = 0
    call validate_legacy_request(request, ok, result%diagnostics%route)
    if (.not. ok) then
       result%status = SW_SOLVE_FAILED
       return
    end if
    n = request%parameters%active_nodes

    select type (ws => workspace)
    type is (reference_richards_legacy_workspace_t)
       ws%converged_surface_result = soil_water_top_boundary_result_t()
       ws%gross_surface_sources_available = .false.
       ws%precipitation_rate_cm_day = 0.0_real64
       ws%irrigation_rate_cm_day = 0.0_real64
       ws%snowmelt_rate_cm_day = 0.0_real64
       ws%runon_rate_cm_day = 0.0_real64
       if (ws%legacy_worker%active_nodes /= n) then
          call a23bu_initialize_worker(ws%legacy_worker, n)
       end if
       call a23bu_reset_attempt_diagnostics(ws%legacy_worker)
       call a23bu_reset_attempt_control(ws%legacy_worker)
       reset_calls_before = ws%richards%profile_full_reset_calls
       reset_bytes_before = ws%richards%profile_zeroed_bytes
       call ensure_reference_workspace_shape(ws%richards, n)

       ! F-KT owns the committed/base state. F-SI materializes only this solve's
       ! explicit candidate state and lets HeadCalc rebuild reconstructible
       ! hydraulic intermediates in worker-owned scratch/state.
       call initialize_reference_state_binding(ws%state_binding, request)

       warm_allowed=.false.
       if(request%numerical%reuse_trial_head)call trial_guess_key(request,origin_key,warm_allowed)
       warm_used=.false.;same_origin=.false.;same_forcing=.false.;continuation=.false.
       if(warm_allowed.and.ws%trial_guess_available)then
          if(allocated(ws%trial_origin_key).and.allocated(ws%trial_guess_head))then
             if(size(ws%trial_origin_key)==size(origin_key).and.size(ws%trial_guess_head)==n) &
               same_forcing=ws%trial_parameter_id==request%parameters%parameter_set_id
             if(same_forcing)same_forcing=all(ws%trial_origin_key(2*n+3:)==origin_key(2*n+3:))
             if(same_forcing)then
                same_origin=all(ws%trial_origin_key(:2*n+2)==origin_key(:2*n+2))
                if(allocated(ws%trial_endpoint_key))then
                   if(size(ws%trial_endpoint_key)==2*n+2) &
                     continuation=all(ws%trial_endpoint_key==origin_key(:2*n+2))
                end if
             end if
          end if
          if(.not.same_origin.and..not.continuation)ws%warm_start_invalidations=ws%warm_start_invalidations+1
          if((same_origin.or.continuation).and.ws%trial_guess_duration>0.0_real64.and. &
             request%step_duration<=merge(2.0_real64,1.0_real64,continuation)*ws%trial_guess_duration)then
            if(all(ieee_is_finite(ws%trial_guess_head)))then
             if(maxval(abs(ws%trial_guess_head))<=1.0e6_real64)then
             duration_ratio=request%step_duration/ws%trial_guess_duration
             guess=request%base_state%pressure_head+duration_ratio*(ws%trial_guess_head-ws%trial_origin_key(:n))
             if(all(ieee_is_finite(guess)))then
                ws%state_binding%h=guess
                ws%legacy_worker%diagnostics%constitutive_evaluations= &
                  ws%legacy_worker%diagnostics%constitutive_evaluations+1
                ws%legacy_worker%diagnostics%constitutive_initial_full_evaluations= &
                  ws%legacy_worker%diagnostics%constitutive_initial_full_evaluations+1
                call request%evaluation%constitutive%evaluate(guess,ws%state_binding%theta, &
                  ws%richards%provider_k,ws%richards%provider_capacity,ws%richards%provider_dkdh)
                warm_used=.true.;ws%warm_start_attempts=ws%warm_start_attempts+1
                if(continuation)ws%warm_start_continuations=ws%warm_start_continuations+1
             end if
             end if
            end if
          end if
       end if
       if(.not.warm_allowed)call clear_reference_trial_guess(ws)

       ! Only the qualified prescribed-qbot route needs reusable-factor capture.
       ! Expanding the existing gamma scratch is temporary worker state; the
       ! normal no-sensitivity path keeps the exact compact allocation.
       sensitivity_capture = request%request_interface_sensitivity .and. request%boundary%bottom_mode == 2
       if (sensitivity_capture) call prepare_reference_tridag_factorization_capture(ws%richards)

       cold_config=request%numerical
       line_search_retry_allowed=.false.
       if(request%numerical%abort_failed_line_search) &
         call trial_guess_key(request,line_search_route_key,line_search_retry_allowed,allow_line_search_retry=.true.)
       cold_config%abort_failed_line_search=line_search_retry_allowed
       warm_config=cold_config
       if(warm_used)warm_config%max_iterations=min(3,request%numerical%max_iterations)
       call headcalc(ws%legacy_worker, ws%richards, call_history, ws%state_binding, &
            request%evaluation, request%boundary, warm_config, request%physical, &
            request%step_duration, request%parameters, final_top)

       if(warm_used.and.(ws%state_binding%fldecdt.or.ws%legacy_worker%control%request_dt_reduction))then
          ! Rebuild the physical origin; retain both phases in diagnostic totals.
          ws%warm_start_fallbacks=ws%warm_start_fallbacks+1
          call initialize_reference_state_binding(ws%state_binding,request)
          call a23bu_reset_attempt_control(ws%legacy_worker)
          call headcalc(ws%legacy_worker,ws%richards,call_history,ws%state_binding, &
            request%evaluation,request%boundary,cold_config,request%physical, &
            request%step_duration,request%parameters,final_top)
       end if
       if(warm_allowed)then
          ws%trial_guess_available=.false.
          if(allocated(ws%trial_endpoint_key))deallocate(ws%trial_endpoint_key)
          if(ws%legacy_worker%diagnostics%nonlinear_iterations>0)then
             if(ws%state_binding%fldecdt.or.ws%legacy_worker%control%request_dt_reduction)then
                guess=ws%richards%old_head
             else
                guess=ws%state_binding%h
                ws%trial_endpoint_key=[ws%state_binding%h,ws%state_binding%theta, &
                  ws%state_binding%pond,ws%state_binding%gwl]
             end if
             if(all(ieee_is_finite(guess)))then
                ws%trial_origin_key=origin_key;ws%trial_guess_head=guess
                ws%trial_guess_duration=request%step_duration
                ws%trial_parameter_id=request%parameters%parameter_set_id
                ws%trial_guess_available=.true.
             end if
          end if
       end if

       ! B1.10 SWBOTB=5 and active SWBOTB=8 prescribe head at the lower boundary face, so qbot is
       ! an output rather than an input boundary condition. HeadCalc already
       ! leaves the exact unrounded compartment residual vector in worker scratch.
       ! Materialize qbot with exact B1.10 watstor()+fluxes() arithmetic grouping
       ! from explicit request/state/provider data; do not call legacy fluxes(),
       ! which mutates integration globals outside the focused solver service.
       if ((request%boundary%bottom_mode == 5 .or. request%boundary%bottom_mode == 8) .and. .not. ws%state_binding%fldecdt .and. &
           .not. ws%legacy_worker%control%request_dt_reduction) then
          if (request%boundary%bottom_mode == 5 .or. ws%state_binding%qbot /= 0.0_real64) then
             call materialize_prescribed_head_bottom_flux(request, ws%richards, ws%state_binding)
          end if
          result%unrounded_mass_balance_residual = sum(ws%richards%residual(1:n))
          result%native_balance_rate_residual_available = .true.
          result%native_balance_rate_residual_cm_per_day = result%unrounded_mass_balance_residual
          result%integrated_mass_balance_residual_available = .true.
          result%integrated_mass_balance_residual_cm = &
               request%step_duration * result%unrounded_mass_balance_residual
       end if

       ! SWBOTB=2 prescribes qbot directly. For an accepted solve the final
       ! unrounded compartment residual vector is already the exact vector used
       ! by HeadCalc's total-balance convergence criterion. Preserve that exact
       ! value in the compatibility field, expose it explicitly as cm/day, and
       ! separately publish its time-integrated equation-balance residual in cm.
       if ((request%boundary%bottom_mode == 2 .or. request%boundary%bottom_mode == 3) .and. &
           .not. ws%state_binding%fldecdt .and. &
           .not. ws%legacy_worker%control%request_dt_reduction) then
          result%unrounded_mass_balance_residual = sum(ws%richards%residual(1:n))
          result%native_balance_rate_residual_available = .true.
          result%native_balance_rate_residual_cm_per_day = result%unrounded_mass_balance_residual
          result%integrated_mass_balance_residual_available = .true.
          result%integrated_mass_balance_residual_cm = &
               request%step_duration * result%unrounded_mass_balance_residual
       end if

       ! SWBOTB=7 free drainage owns qbot inside HeadCalc. For an accepted
       ! solve, the final unrounded compartment residual vector is already the
       ! exact vector used by HeadCalc's total-balance convergence criterion.
       ! Publish the same typed native-rate and integrated equation-balance
       ! residual contract used by the already-qualified bottom modes 2 and 5.
       if (request%boundary%bottom_mode == 7 .and. .not. ws%state_binding%fldecdt .and. &
           .not. ws%legacy_worker%control%request_dt_reduction) then
          result%unrounded_mass_balance_residual = sum(ws%richards%residual(1:n))
          result%native_balance_rate_residual_available = .true.
          result%native_balance_rate_residual_cm_per_day = result%unrounded_mass_balance_residual
          result%integrated_mass_balance_residual_available = .true.
          result%integrated_mass_balance_residual_cm = &
               request%step_duration * result%unrounded_mass_balance_residual
       end if

       ! Native SWAP prescribed-qbot enters the implemented bottom residual as
       ! F_N(...,qbot)=...-qbot. Therefore dF/dqbot=-e_N and implicit
       ! differentiation gives J * dh/dqbot = +e_N. Reuse the final normal
       ! TRIDAG factorization: one extra backsolve, no Jacobian rebuild and no
       ! second nonlinear trajectory. Any retry or alternative-solver use is
       ! fail-closed because the captured normal TRIDAG factorization is then
       ! not a qualified accepted-path authority.
       if (sensitivity_capture .and. .not. ws%state_binding%fldecdt .and. &
           .not. ws%legacy_worker%control%request_dt_reduction .and. &
           ws%legacy_worker%diagnostics%alternative_solver_calls == 0 .and. &
           size(ws%richards%tridag_gamma) >= 2*n) then
          ws%richards%band_rhs(1:n) = 0.0_real64
          ws%richards%band_rhs(n) = 1.0_real64
          interface_sensitivity_backsolves = interface_sensitivity_backsolves + 1
          call reference_tridag_backsolve(n, ws%richards%dfdh_upper, ws%richards%band_rhs, &
               ws%richards%tridag_gamma(1:n), ws%richards%tridag_gamma(n+1:2*n), &
               ws%richards%delta_head, tangent_ierror)
          if (tangent_ierror == 0) then
             result%interface_sensitivity%available = .true.
             result%interface_sensitivity%dh_bottom_dq_bottom = ws%richards%delta_head(n)
             result%interface_sensitivity%method = 'same-tridag-factor'
          end if
       end if

       result%candidate_state%active_nodes = n
       allocate(result%candidate_state%pressure_head(n), result%candidate_state%water_content(n))
       result%candidate_state%pressure_head = ws%state_binding%h
       result%candidate_state%water_content = ws%state_binding%theta
       result%candidate_state%ponding_depth = ws%state_binding%pond
       result%candidate_state%groundwater_level = ws%state_binding%gwl
       result%top_flux = ws%state_binding%qtop
       result%bottom_flux = ws%state_binding%qbot
       result%diagnostics%headcalc_calls = ws%legacy_worker%diagnostics%headcalc_calls
       result%diagnostics%nonlinear_iterations = ws%legacy_worker%diagnostics%nonlinear_iterations
       result%diagnostics%jacobian_builds = ws%legacy_worker%diagnostics%jacobian_builds
       result%diagnostics%linear_solves = ws%legacy_worker%diagnostics%linear_solves
       result%diagnostics%backtracking_attempts = ws%legacy_worker%diagnostics%backtracking_attempts
       result%diagnostics%alternative_solver_calls = ws%legacy_worker%diagnostics%alternative_solver_calls
       result%diagnostics%internal_retries = ws%legacy_worker%diagnostics%internal_retries
       result%diagnostics%interface_sensitivity_backsolves = interface_sensitivity_backsolves
       result%diagnostics%constitutive_evaluations = ws%legacy_worker%diagnostics%constitutive_evaluations
       result%diagnostics%constitutive_initial_full_evaluations = &
            ws%legacy_worker%diagnostics%constitutive_initial_full_evaluations
       result%diagnostics%constitutive_candidate_full_evaluations = &
            ws%legacy_worker%diagnostics%constitutive_candidate_full_evaluations
       result%diagnostics%constitutive_candidate_demand_evaluations = &
            ws%legacy_worker%diagnostics%constitutive_candidate_demand_evaluations
       result%diagnostics%constitutive_capacity_only_evaluations = &
            ws%legacy_worker%diagnostics%constitutive_capacity_only_evaluations
       result%diagnostics%constitutive_candidate_terminal_evaluations = &
            ws%legacy_worker%diagnostics%constitutive_candidate_terminal_evaluations
       result%diagnostics%constitutive_candidate_capacity_reuses = &
            ws%legacy_worker%diagnostics%constitutive_candidate_capacity_reuses
       result%diagnostics%workspace_full_resets = ws%richards%profile_full_reset_calls - reset_calls_before
       result%diagnostics%workspace_zeroed_bytes = ws%richards%profile_zeroed_bytes - reset_bytes_before

       if (sensitivity_capture) call release_reference_tridag_factorization_capture(ws%richards)

       if (ws%state_binding%fldecdt .or. ws%legacy_worker%control%request_dt_reduction) then
          result%status = SW_SOLVE_RETRY_ADVISED
          result%retry_advised = .true.
          result%diagnostics%route = 'legacy-reference-retry'
       else
          result%status = SW_SOLVE_CONVERGED
          ws%converged_surface_result = final_top
          if (final_top%status == SW_TOP_BOUNDARY_AVAILABLE .and. associated(request%evaluation%dynamic_top_boundary)) then
             select type (top => request%evaluation%dynamic_top_boundary)
             type is (b110_dynamic_top_boundary_solver_provider_t)
                ws%gross_surface_sources_available = .true.
                ws%precipitation_rate_cm_day = top%precipitation_rate
                ws%irrigation_rate_cm_day = top%irrigation_rate
                ws%snowmelt_rate_cm_day = top%snowmelt_rate
                ws%runon_rate_cm_day = top%runon_rate
             end select
          end if
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
    if (associated(request%evaluation%root_sink)) then
       qrosum = sum(richards%provider_root_sink(1:n))
    else
       qrosum = 0.0_real64
    end if
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
    logical :: boundary_ok
    integer :: n
    real(real64), allocatable :: theta_check(:), k_check(:), capacity_check(:), derivative_check(:)
    real(real64) :: boundary_flux, boundary_conductance

    ok = .false.
    route = 'legacy-request-invalid'
    if (.not. associated(request%evaluation%constitutive)) then
       route = 'constitutive-provider-required'
       return
    end if
    call validate_soil_water_request(request, common_ok)
    if (.not. common_ok) return
    if (request%physical%macropore_active .and. .not. associated(request%evaluation%macropore)) then
       route = 'explicit-macropore-provider-required'
       return
    end if
    if (request%physical%macropore_active .and. request%boundary%matrix_source_area_partition .and. &
        request%boundary%top_mode /= FSI_TOP_MODE_DYNAMIC_PROVIDER) then
       route = 'matrix-source-partition-requires-dynamic-top'
       return
    end if
    if (request%numerical%conductivity_implicit_mode /= 0) then
       route = 'legacy-implicit-k-deferred'
       return
    end if
    if (request%numerical%picard_conductivity_iteration .and. &
        ((request%boundary%bottom_mode /= 2.and.request%boundary%bottom_mode /= 3) .or. &
         request%numerical%conductivity_mean_method /= 1 .or. &
         request%numerical%max_iterations /= 64 .or. request%physical%macropore_active .or. &
         request%request_interface_sensitivity)) then
       route = 'picard-conductivity-composition-deferred'
       return
    end if
    if (fldtmin) then
       route = 'legacy-min-dt-deferred'
       return
    end if
    if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2 .and. &
        request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2 .and. &
        request%boundary%bottom_mode /= 3 .and. request%boundary%bottom_mode /= 8) then
       route = 'legacy-bottom-mode-deferred'
       return
    end if
    if (request%boundary%bottom_mode == 8) then
       route = 'lysimeter-plate-domain-deferred'
       if (request%physical%macropore_active .or. request%request_interface_sensitivity) return
       if (.not. ieee_is_finite(request%boundary%bottom_head)) return
       if (.not. ieee_is_finite(request%boundary%bottom_flux) .or. request%boundary%bottom_flux /= 0.0_real64) return
       if (request%boundary%bottom_external_resistance_days /= 0.0_real64) return
       if (.not. request%boundary%bottom_include_half_cell) return
       n=request%parameters%active_nodes
       if (n < 2) return
       if (.not. ieee_is_finite(request%parameters%node_distance(n))) return
       if (request%parameters%node_distance(n) <= 0.0_real64) return
       if (.not. ieee_is_finite(request%base_state%pressure_head(n))) return
    end if
    if (request%boundary%bottom_mode == 3) then
       route = 'resistive-bottom-domain-deferred'
       if (request%physical%macropore_active .or. request%request_interface_sensitivity) return
       n=request%parameters%active_nodes
       if (n < 2) return
       if (any(.not. ieee_is_finite(request%parameters%z))) return
       if (any(.not. ieee_is_finite(request%parameters%dz))) return
       if (any(.not. ieee_is_finite(request%parameters%node_distance))) return
       if (any(request%parameters%dz <= 0.0_real64)) return
       if (any(request%parameters%node_distance <= 0.0_real64)) return
       if (any(.not. ieee_is_finite(request%base_state%pressure_head))) return
       if (any(abs(request%base_state%pressure_head)>1.0e10_real64)) return
       allocate(theta_check(n),k_check(n),capacity_check(n),derivative_check(n))
       call request%evaluation%constitutive%evaluate(request%base_state%pressure_head, &
            theta_check,k_check,capacity_check,derivative_check)
       call evaluate_resistive_bottom_boundary(request%boundary,request%base_state%pressure_head(n), &
            request%parameters%z(n),0.5_real64*request%parameters%dz(n),k_check(n), &
            boundary_flux,boundary_conductance,boundary_ok)
       if (.not. boundary_ok) return
    end if
    select case (request%boundary%top_mode)
    case (FSI_TOP_MODE_EXPLICIT_FLUX)
       if (.not. associated(request%evaluation%top_boundary)) then
          route = 'explicit-top-provider-required'
          return
       end if
    case (FSI_TOP_MODE_DYNAMIC_PROVIDER)
       if (.not. associated(request%evaluation%dynamic_top_boundary)) then
          route = 'dynamic-top-provider-required'
          return
       end if
    case default
       route = 'explicit-top-mode-required'
       return
    end select
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

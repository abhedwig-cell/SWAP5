module mod_moving_interface_manager
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  implicit none
  private

  integer, parameter, public :: MI_MANAGER_ROUTE_NOT_RUN = 0
  integer, parameter, public :: MI_MANAGER_ROUTE_REDUCED = 1
  integer, parameter, public :: MI_MANAGER_ROUTE_FULL_FALLBACK = 2
  integer, parameter, public :: MI_MANAGER_ROUTE_FULL_BYPASS = 3

  type, public :: moving_interface_active_view_t
     integer :: full_nodes = 0
     integer :: active_nodes = 0
     integer :: tail_start_node = 0
     integer :: interface_face = 0
     logical :: eligible = .false.
  end type moving_interface_active_view_t

  type, public :: moving_interface_manager_diagnostics_t
     integer :: route = MI_MANAGER_ROUTE_NOT_RUN
     integer :: full_nodes = 0
     integer :: active_nodes = 0
     integer :: tail_start_node = 0
     integer :: interface_face = 0
     integer(int64) :: reduced_workspace_generation = 0_int64
     logical :: reduced_attempted = .false.
     logical :: reduced_accepted = .false.
     logical :: fallback_used = .false.
     character(len=64) :: fallback_reason = 'not-run'
  end type moving_interface_manager_diagnostics_t

  type, public :: moving_interface_manager_context_t
     type(soil_water_parameter_set_t), pointer :: reduced_parameters => null()
     type(soil_water_solve_request_t) :: reduced_request
     type(soil_water_solve_result_t) :: full_candidate
     integer :: prepared_full_nodes = 0
     integer :: prepared_active_nodes = 0
     integer(int64) :: source_parameter_set_id = -1_int64
     integer :: request_buffer_reallocations = 0
     integer :: full_candidate_buffer_reallocations = 0
  end type moving_interface_manager_context_t

  public :: evaluate_moving_interface_request_eligibility
  public :: derive_moving_interface_active_view
  public :: build_moving_interface_reduced_request
  public :: materialize_moving_interface_full_candidate
  public :: choose_moving_interface_result
  public :: prepare_moving_interface_reduced_request_persistent
  public :: materialize_moving_interface_full_candidate_persistent
  public :: finalize_moving_interface_result_persistent
  public :: release_moving_interface_manager_context
  public :: prepare_moving_interface_reduced_request_inplace
  public :: materialize_moving_interface_full_candidate_inplace
  public :: select_moving_interface_route

contains

  subroutine evaluate_moving_interface_request_eligibility(manager_enabled, full_request, tail_start_node, &
                                                           view, ok, reason)
    logical, intent(in) :: manager_enabled
    type(soil_water_solve_request_t), intent(in) :: full_request
    integer, intent(in) :: tail_start_node
    type(moving_interface_active_view_t), intent(out) :: view
    logical, intent(out) :: ok
    character(len=*), intent(out) :: reason

    integer :: n
    real(real64), allocatable :: source(:), sink(:)
    logical :: view_ok
    character(len=64) :: view_reason

    view = moving_interface_active_view_t()
    ok = .false.
    reason = 'manager-disabled'
    if (.not. manager_enabled) return

    reason = 'provider-binding-incomplete'
    if (.not. associated(full_request%parameters)) return
    if (.not. associated(full_request%evaluation%constitutive)) return
    if (.not. associated(full_request%evaluation%source_sink)) return
    if (.not. associated(full_request%evaluation%top_boundary)) return

    reason = 'macropore-active'
    if (full_request%physical%macropore_active) return
    if (associated(full_request%evaluation%macropore)) return

    reason = 'root-sink-scope-unsupported'
    if (associated(full_request%evaluation%root_sink)) return

    reason = 'interface-sensitivity-unsupported'
    if (full_request%request_interface_sensitivity) return

    reason = 'unsupported-bottom-boundary'
    if (full_request%boundary%bottom_mode /= 2) return

    reason = 'nonzero-bottom-flux'
    if (full_request%boundary%bottom_flux /= 0.0_real64) return

    reason = 'unsupported-top-boundary'
    if (full_request%boundary%top_mode /= FSI_TOP_MODE_EXPLICIT_FLUX) return
    if (associated(full_request%evaluation%dynamic_top_boundary)) return

    n = full_request%base_state%active_nodes
    reason = 'invalid-tail-geometry'
    if (n <= 0) return
    if (.not. allocated(full_request%base_state%pressure_head)) return
    if (.not. allocated(full_request%base_state%water_content)) return
    if (size(full_request%base_state%pressure_head) /= n) return
    if (size(full_request%base_state%water_content) /= n) return
    if (tail_start_node <= 1 .or. tail_start_node > n) return
    if (any(full_request%base_state%pressure_head(tail_start_node:n) < 0.0_real64)) return
    if (tail_start_node > 1) then
       if (full_request%base_state%pressure_head(tail_start_node-1) >= 0.0_real64) return
    end if

    allocate(source(n), sink(n))
    call full_request%evaluation%source_sink%evaluate(full_request%base_state%pressure_head, &
         full_request%base_state%water_content, source, sink)
    reason = 'source-sink-scope-unsupported'
    if (any(source /= 0.0_real64) .or. any(sink /= 0.0_real64)) return

    call derive_moving_interface_active_view(full_request%base_state, tail_start_node, view, view_ok, view_reason)
    if (.not. view_ok) then
       if (trim(view_reason) == 'no-reduced-dimension') then
          reason = 'no-reduced-dimension'
       else
          reason = 'invalid-tail-geometry'
       end if
       return
    end if

    ok = .true.
    reason = 'eligible'
  end subroutine evaluate_moving_interface_request_eligibility


  subroutine derive_moving_interface_active_view(full_state, tail_start_node, view, ok, reason)
    type(soil_water_physical_state_t), intent(in) :: full_state
    integer, intent(in) :: tail_start_node
    type(moving_interface_active_view_t), intent(out) :: view
    logical, intent(out) :: ok
    character(len=*), intent(out) :: reason
    integer :: n

    view = moving_interface_active_view_t()
    ok = .false.
    reason = 'invalid-full-state'

    n = full_state%active_nodes
    if (n <= 0) return
    if (.not. allocated(full_state%pressure_head) .or. .not. allocated(full_state%water_content)) return
    if (size(full_state%pressure_head) /= n .or. size(full_state%water_content) /= n) return

    view%full_nodes = n
    if (tail_start_node <= 1 .or. tail_start_node > n) then
       reason = 'tail-start-ineligible'
       return
    end if

    ! Keep the shallowest currently saturated node inside the nonlinear solve.
    ! Only nodes below it are reconstructible tail scratch.
    view%active_nodes = tail_start_node
    view%tail_start_node = tail_start_node
    view%interface_face = tail_start_node
    view%eligible = view%active_nodes < view%full_nodes

    if (.not. view%eligible) then
       reason = 'no-reduced-dimension'
       return
    end if

    ok = .true.
    reason = 'eligible'
  end subroutine derive_moving_interface_active_view


  subroutine build_moving_interface_reduced_request(full_request, view, reduced_parameters, reduced_request, ok, reason)
    type(soil_water_solve_request_t), intent(in) :: full_request
    type(moving_interface_active_view_t), intent(in) :: view
    type(soil_water_parameter_set_t), target, intent(inout) :: reduced_parameters
    type(soil_water_solve_request_t), intent(out) :: reduced_request
    logical, intent(out) :: ok
    character(len=*), intent(out) :: reason
    integer :: n, nf

    reduced_request = soil_water_solve_request_t()
    reduced_parameters = soil_water_parameter_set_t()
    ok = .false.
    reason = 'invalid-view'

    if (.not. view%eligible) return
    if (.not. associated(full_request%parameters)) then
       reason = 'full-parameters-unbound'
       return
    end if

    nf = full_request%parameters%active_nodes
    n = view%active_nodes
    if (nf /= view%full_nodes .or. n <= 0 .or. n >= nf) then
       reason = 'view-shape-mismatch'
       return
    end if
    if (full_request%base_state%active_nodes /= nf) then
       reason = 'full-state-shape-mismatch'
       return
    end if
    if (.not. allocated(full_request%parameters%z) .or. .not. allocated(full_request%parameters%dz) .or. &
        .not. allocated(full_request%parameters%node_distance)) then
       reason = 'full-parameter-shape-missing'
       return
    end if
    if (.not. allocated(full_request%base_state%pressure_head) .or. &
        .not. allocated(full_request%base_state%water_content)) then
       reason = 'full-state-shape-missing'
       return
    end if

    reduced_parameters%parameter_set_id = full_request%parameters%parameter_set_id
    reduced_parameters%active_nodes = n
    allocate(reduced_parameters%z(n), reduced_parameters%dz(n), reduced_parameters%node_distance(n))
    reduced_parameters%z = full_request%parameters%z(1:n)
    reduced_parameters%dz = full_request%parameters%dz(1:n)
    reduced_parameters%node_distance = full_request%parameters%node_distance(1:n)

    reduced_request%parameters => reduced_parameters
    reduced_request%boundary = full_request%boundary
    reduced_request%physical = full_request%physical
    reduced_request%numerical = full_request%numerical
    reduced_request%evaluation = full_request%evaluation
    reduced_request%step_duration = full_request%step_duration
    reduced_request%request_interface_sensitivity = .false.

    reduced_request%base_state%active_nodes = n
    allocate(reduced_request%base_state%pressure_head(n), reduced_request%base_state%water_content(n))
    reduced_request%base_state%pressure_head = full_request%base_state%pressure_head(1:n)
    reduced_request%base_state%water_content = full_request%base_state%water_content(1:n)
    reduced_request%base_state%ponding_depth = full_request%base_state%ponding_depth
    reduced_request%base_state%groundwater_level = full_request%base_state%groundwater_level

    ok = .true.
    reason = 'reduced-request-ready'
  end subroutine build_moving_interface_reduced_request


  subroutine materialize_moving_interface_full_candidate(full_origin, reduced_result, tail_pressure_head, tail_water_content, &
                                                         full_candidate, ok, reason)
    type(soil_water_physical_state_t), intent(in) :: full_origin
    type(soil_water_solve_result_t), intent(in) :: reduced_result
    real(real64), intent(in) :: tail_pressure_head(:), tail_water_content(:)
    type(soil_water_solve_result_t), intent(out) :: full_candidate
    logical, intent(out) :: ok
    character(len=*), intent(out) :: reason
    integer :: na, nf, nt

    full_candidate = soil_water_solve_result_t()
    ok = .false.
    reason = 'reduced-result-not-converged'

    if (reduced_result%status /= SW_SOLVE_CONVERGED) return

    nf = full_origin%active_nodes
    na = reduced_result%candidate_state%active_nodes
    if (nf <= 0 .or. na <= 0 .or. na >= nf) then
       reason = 'candidate-shape-invalid'
       return
    end if
    if (.not. allocated(full_origin%pressure_head) .or. .not. allocated(full_origin%water_content)) then
       reason = 'origin-shape-missing'
       return
    end if
    if (.not. allocated(reduced_result%candidate_state%pressure_head) .or. &
        .not. allocated(reduced_result%candidate_state%water_content)) then
       reason = 'reduced-candidate-shape-missing'
       return
    end if

    nt = nf - na
    if (size(tail_pressure_head) /= nt .or. size(tail_water_content) /= nt) then
       reason = 'tail-shape-mismatch'
       return
    end if

    full_candidate = reduced_result
    if (allocated(full_candidate%candidate_state%pressure_head)) deallocate(full_candidate%candidate_state%pressure_head)
    if (allocated(full_candidate%candidate_state%water_content)) deallocate(full_candidate%candidate_state%water_content)

    full_candidate%candidate_state%active_nodes = nf
    allocate(full_candidate%candidate_state%pressure_head(nf), full_candidate%candidate_state%water_content(nf))
    full_candidate%candidate_state%pressure_head(1:na) = reduced_result%candidate_state%pressure_head
    full_candidate%candidate_state%water_content(1:na) = reduced_result%candidate_state%water_content
    full_candidate%candidate_state%pressure_head(na+1:nf) = tail_pressure_head
    full_candidate%candidate_state%water_content(na+1:nf) = tail_water_content

    ok = .true.
    reason = 'full-candidate-materialized'
  end subroutine materialize_moving_interface_full_candidate



  subroutine prepare_moving_interface_reduced_request_persistent(full_request, view, context, ok, reason)
    type(soil_water_solve_request_t), intent(in) :: full_request
    type(moving_interface_active_view_t), intent(in) :: view
    type(moving_interface_manager_context_t), intent(inout) :: context
    logical, intent(out) :: ok
    character(len=*), intent(out) :: reason
    integer :: n, nf
    logical :: shape_changed, parameter_changed

    ok = .false.
    reason = 'invalid-view'
    if (.not. view%eligible) return
    if (.not. associated(full_request%parameters)) then
       reason = 'full-parameters-unbound'
       return
    end if

    nf = full_request%parameters%active_nodes
    n = view%active_nodes
    if (nf /= view%full_nodes .or. n <= 0 .or. n >= nf) then
       reason = 'view-shape-mismatch'
       return
    end if
    if (full_request%base_state%active_nodes /= nf) then
       reason = 'full-state-shape-mismatch'
       return
    end if
    if (.not. allocated(full_request%parameters%z) .or. .not. allocated(full_request%parameters%dz) .or. &
        .not. allocated(full_request%parameters%node_distance)) then
       reason = 'full-parameter-shape-missing'
       return
    end if
    if (.not. allocated(full_request%base_state%pressure_head) .or. &
        .not. allocated(full_request%base_state%water_content)) then
       reason = 'full-state-shape-missing'
       return
    end if

    if (.not. associated(context%reduced_parameters)) allocate(context%reduced_parameters)

    shape_changed = context%prepared_full_nodes /= nf .or. context%prepared_active_nodes /= n .or. &
         .not. allocated(context%reduced_parameters%z) .or. &
         .not. allocated(context%reduced_request%base_state%pressure_head)

    if (shape_changed) then
       if (allocated(context%reduced_parameters%z)) deallocate(context%reduced_parameters%z)
       if (allocated(context%reduced_parameters%dz)) deallocate(context%reduced_parameters%dz)
       if (allocated(context%reduced_parameters%node_distance)) deallocate(context%reduced_parameters%node_distance)
       if (allocated(context%reduced_request%base_state%pressure_head)) &
            deallocate(context%reduced_request%base_state%pressure_head)
       if (allocated(context%reduced_request%base_state%water_content)) &
            deallocate(context%reduced_request%base_state%water_content)
       allocate(context%reduced_parameters%z(n), context%reduced_parameters%dz(n), &
            context%reduced_parameters%node_distance(n))
       allocate(context%reduced_request%base_state%pressure_head(n), &
            context%reduced_request%base_state%water_content(n))
       context%prepared_full_nodes = nf
       context%prepared_active_nodes = n
       context%request_buffer_reallocations = context%request_buffer_reallocations + 1
    end if

    parameter_changed = shape_changed .or. &
         context%source_parameter_set_id /= full_request%parameters%parameter_set_id
    if (parameter_changed) then
       context%reduced_parameters%parameter_set_id = full_request%parameters%parameter_set_id
       context%reduced_parameters%active_nodes = n
       context%reduced_parameters%z = full_request%parameters%z(1:n)
       context%reduced_parameters%dz = full_request%parameters%dz(1:n)
       context%reduced_parameters%node_distance = full_request%parameters%node_distance(1:n)
       context%source_parameter_set_id = full_request%parameters%parameter_set_id
    end if

    context%reduced_request%parameters => context%reduced_parameters
    context%reduced_request%boundary = full_request%boundary
    context%reduced_request%physical = full_request%physical
    context%reduced_request%numerical = full_request%numerical
    context%reduced_request%evaluation = full_request%evaluation
    context%reduced_request%step_duration = full_request%step_duration
    context%reduced_request%request_interface_sensitivity = .false.
    context%reduced_request%base_state%active_nodes = n
    context%reduced_request%base_state%pressure_head = full_request%base_state%pressure_head(1:n)
    context%reduced_request%base_state%water_content = full_request%base_state%water_content(1:n)
    context%reduced_request%base_state%ponding_depth = full_request%base_state%ponding_depth
    context%reduced_request%base_state%groundwater_level = full_request%base_state%groundwater_level

    ok = .true.
    reason = 'persistent-reduced-request-ready'
  end subroutine prepare_moving_interface_reduced_request_persistent


  subroutine materialize_moving_interface_full_candidate_persistent(full_origin, reduced_result, tail_pressure_head, &
                                                                    tail_water_content, context, ok, reason)
    type(soil_water_physical_state_t), intent(in) :: full_origin
    type(soil_water_solve_result_t), intent(in) :: reduced_result
    real(real64), intent(in) :: tail_pressure_head(:), tail_water_content(:)
    type(moving_interface_manager_context_t), intent(inout) :: context
    logical, intent(out) :: ok
    character(len=*), intent(out) :: reason
    integer :: na, nf, nt
    logical :: need_allocate

    ok = .false.
    reason = 'reduced-result-not-converged'
    if (reduced_result%status /= SW_SOLVE_CONVERGED) return

    nf = full_origin%active_nodes
    na = reduced_result%candidate_state%active_nodes
    if (nf <= 0 .or. na <= 0 .or. na >= nf) then
       reason = 'candidate-shape-invalid'
       return
    end if
    if (.not. allocated(reduced_result%candidate_state%pressure_head) .or. &
        .not. allocated(reduced_result%candidate_state%water_content)) then
       reason = 'reduced-candidate-shape-missing'
       return
    end if
    nt = nf-na
    if (size(tail_pressure_head) /= nt .or. size(tail_water_content) /= nt) then
       reason = 'tail-shape-mismatch'
       return
    end if

    need_allocate = .not. allocated(context%full_candidate%candidate_state%pressure_head)
    if (.not. need_allocate) need_allocate = size(context%full_candidate%candidate_state%pressure_head) /= nf
    if (need_allocate) then
       if (allocated(context%full_candidate%candidate_state%pressure_head)) &
            deallocate(context%full_candidate%candidate_state%pressure_head)
       if (allocated(context%full_candidate%candidate_state%water_content)) &
            deallocate(context%full_candidate%candidate_state%water_content)
       allocate(context%full_candidate%candidate_state%pressure_head(nf), &
            context%full_candidate%candidate_state%water_content(nf))
       context%full_candidate_buffer_reallocations = context%full_candidate_buffer_reallocations + 1
    end if

    context%full_candidate%status = reduced_result%status
    context%full_candidate%retry_advised = reduced_result%retry_advised
    context%full_candidate%top_flux = reduced_result%top_flux
    context%full_candidate%bottom_flux = reduced_result%bottom_flux
    context%full_candidate%unrounded_mass_balance_residual = reduced_result%unrounded_mass_balance_residual
    context%full_candidate%integrated_mass_balance_residual_available = &
         reduced_result%integrated_mass_balance_residual_available
    context%full_candidate%integrated_mass_balance_residual_cm = reduced_result%integrated_mass_balance_residual_cm
    context%full_candidate%native_balance_rate_residual_available = &
         reduced_result%native_balance_rate_residual_available
    context%full_candidate%native_balance_rate_residual_cm_per_day = &
         reduced_result%native_balance_rate_residual_cm_per_day
    context%full_candidate%diagnostics = reduced_result%diagnostics
    context%full_candidate%interface_sensitivity = reduced_result%interface_sensitivity
    context%full_candidate%candidate_state%active_nodes = nf
    context%full_candidate%candidate_state%ponding_depth = reduced_result%candidate_state%ponding_depth
    context%full_candidate%candidate_state%groundwater_level = reduced_result%candidate_state%groundwater_level
    context%full_candidate%candidate_state%pressure_head(1:na) = reduced_result%candidate_state%pressure_head
    context%full_candidate%candidate_state%water_content(1:na) = reduced_result%candidate_state%water_content
    context%full_candidate%candidate_state%pressure_head(na+1:nf) = tail_pressure_head
    context%full_candidate%candidate_state%water_content(na+1:nf) = tail_water_content

    ok = .true.
    reason = 'persistent-full-candidate-materialized'
  end subroutine materialize_moving_interface_full_candidate_persistent


  subroutine finalize_moving_interface_result_persistent(full_result, reduced_valid, view, &
                                                         reduced_workspace_generation, fallback_reason, &
                                                         context, diagnostics)
    type(soil_water_solve_result_t), intent(in) :: full_result
    logical, intent(in) :: reduced_valid
    type(moving_interface_active_view_t), intent(in) :: view
    integer(int64), intent(in) :: reduced_workspace_generation
    character(len=*), intent(in) :: fallback_reason
    type(moving_interface_manager_context_t), intent(inout) :: context
    type(moving_interface_manager_diagnostics_t), intent(out) :: diagnostics

    diagnostics = moving_interface_manager_diagnostics_t()
    diagnostics%full_nodes = view%full_nodes
    diagnostics%active_nodes = view%active_nodes
    diagnostics%tail_start_node = view%tail_start_node
    diagnostics%interface_face = view%interface_face
    diagnostics%reduced_workspace_generation = reduced_workspace_generation
    diagnostics%reduced_attempted = view%eligible

    if (.not. view%eligible) then
       context%full_candidate = full_result
       diagnostics%route = MI_MANAGER_ROUTE_FULL_BYPASS
       diagnostics%fallback_reason = 'reduced-view-ineligible'
       return
    end if

    if (reduced_valid .and. context%full_candidate%status == SW_SOLVE_CONVERGED) then
       diagnostics%route = MI_MANAGER_ROUTE_REDUCED
       diagnostics%reduced_accepted = .true.
       diagnostics%fallback_reason = 'none'
    else
       context%full_candidate = full_result
       diagnostics%route = MI_MANAGER_ROUTE_FULL_FALLBACK
       diagnostics%fallback_used = .true.
       diagnostics%fallback_reason = fallback_reason
    end if
  end subroutine finalize_moving_interface_result_persistent


  subroutine release_moving_interface_manager_context(context)
    type(moving_interface_manager_context_t), intent(inout) :: context
    if (associated(context%reduced_parameters)) then
       deallocate(context%reduced_parameters)
       nullify(context%reduced_parameters)
    end if
    context%reduced_request = soil_water_solve_request_t()
    context%full_candidate = soil_water_solve_result_t()
    context%prepared_full_nodes = 0
    context%prepared_active_nodes = 0
    context%source_parameter_set_id = -1_int64
  end subroutine release_moving_interface_manager_context


  subroutine choose_moving_interface_result(full_result, reduced_full_candidate, reduced_valid, view, &
                                            reduced_workspace_generation, fallback_reason, selected, diagnostics)
    type(soil_water_solve_result_t), intent(in) :: full_result
    type(soil_water_solve_result_t), intent(in) :: reduced_full_candidate
    logical, intent(in) :: reduced_valid
    type(moving_interface_active_view_t), intent(in) :: view
    integer(int64), intent(in) :: reduced_workspace_generation
    character(len=*), intent(in) :: fallback_reason
    type(soil_water_solve_result_t), intent(out) :: selected
    type(moving_interface_manager_diagnostics_t), intent(out) :: diagnostics

    diagnostics = moving_interface_manager_diagnostics_t()
    diagnostics%full_nodes = view%full_nodes
    diagnostics%active_nodes = view%active_nodes
    diagnostics%tail_start_node = view%tail_start_node
    diagnostics%interface_face = view%interface_face
    diagnostics%reduced_workspace_generation = reduced_workspace_generation
    diagnostics%reduced_attempted = view%eligible

    if (.not. view%eligible) then
       selected = full_result
       diagnostics%route = MI_MANAGER_ROUTE_FULL_BYPASS
       diagnostics%fallback_reason = 'reduced-view-ineligible'
       return
    end if

    if (reduced_valid .and. reduced_full_candidate%status == SW_SOLVE_CONVERGED) then
       selected = reduced_full_candidate
       diagnostics%route = MI_MANAGER_ROUTE_REDUCED
       diagnostics%reduced_accepted = .true.
       diagnostics%fallback_reason = 'none'
    else
       selected = full_result
       diagnostics%route = MI_MANAGER_ROUTE_FULL_FALLBACK
       diagnostics%fallback_used = .true.
       diagnostics%fallback_reason = fallback_reason
    end if
  end subroutine choose_moving_interface_result


  subroutine prepare_moving_interface_reduced_request_inplace(full_request, view, reduced_parameters, reduced_request, &
                                                              ok, reason, reallocated)
    type(soil_water_solve_request_t), intent(in) :: full_request
    type(moving_interface_active_view_t), intent(in) :: view
    type(soil_water_parameter_set_t), target, intent(inout) :: reduced_parameters
    type(soil_water_solve_request_t), intent(inout) :: reduced_request
    logical, intent(out) :: ok
    character(len=*), intent(out) :: reason
    logical, intent(out), optional :: reallocated
    integer :: n, nf
    logical :: did_reallocate

    ok = .false.
    reason = 'invalid-view'
    did_reallocate = .false.
    if (present(reallocated)) reallocated = .false.

    if (.not. view%eligible) return
    if (.not. associated(full_request%parameters)) then
       reason = 'full-parameters-unbound'
       return
    end if
    nf = full_request%parameters%active_nodes
    n = view%active_nodes
    if (nf /= view%full_nodes .or. n <= 0 .or. n >= nf) then
       reason = 'view-shape-mismatch'
       return
    end if
    if (full_request%base_state%active_nodes /= nf) then
       reason = 'full-state-shape-mismatch'
       return
    end if
    if (.not. allocated(full_request%parameters%z) .or. .not. allocated(full_request%parameters%dz) .or. &
        .not. allocated(full_request%parameters%node_distance)) then
       reason = 'full-parameter-shape-missing'
       return
    end if
    if (.not. allocated(full_request%base_state%pressure_head) .or. &
        .not. allocated(full_request%base_state%water_content)) then
       reason = 'full-state-shape-missing'
       return
    end if

    if (.not. allocated(reduced_parameters%z) .or. reduced_parameters%active_nodes /= n) then
       if (allocated(reduced_parameters%z)) deallocate(reduced_parameters%z)
       if (allocated(reduced_parameters%dz)) deallocate(reduced_parameters%dz)
       if (allocated(reduced_parameters%node_distance)) deallocate(reduced_parameters%node_distance)
       allocate(reduced_parameters%z(n), reduced_parameters%dz(n), reduced_parameters%node_distance(n))
       did_reallocate = .true.
    end if
    reduced_parameters%parameter_set_id = full_request%parameters%parameter_set_id
    reduced_parameters%active_nodes = n
    reduced_parameters%z = full_request%parameters%z(1:n)
    reduced_parameters%dz = full_request%parameters%dz(1:n)
    reduced_parameters%node_distance = full_request%parameters%node_distance(1:n)

    if (.not. allocated(reduced_request%base_state%pressure_head) .or. &
        reduced_request%base_state%active_nodes /= n) then
       if (allocated(reduced_request%base_state%pressure_head)) deallocate(reduced_request%base_state%pressure_head)
       if (allocated(reduced_request%base_state%water_content)) deallocate(reduced_request%base_state%water_content)
       allocate(reduced_request%base_state%pressure_head(n), reduced_request%base_state%water_content(n))
       did_reallocate = .true.
    end if

    reduced_request%parameters => reduced_parameters
    reduced_request%boundary = full_request%boundary
    reduced_request%physical = full_request%physical
    reduced_request%numerical = full_request%numerical
    reduced_request%evaluation = full_request%evaluation
    reduced_request%step_duration = full_request%step_duration
    reduced_request%request_interface_sensitivity = .false.
    reduced_request%base_state%active_nodes = n
    reduced_request%base_state%pressure_head = full_request%base_state%pressure_head(1:n)
    reduced_request%base_state%water_content = full_request%base_state%water_content(1:n)
    reduced_request%base_state%ponding_depth = full_request%base_state%ponding_depth
    reduced_request%base_state%groundwater_level = full_request%base_state%groundwater_level

    if (present(reallocated)) reallocated = did_reallocate
    ok = .true.
    reason = 'reduced-request-ready-inplace'
  end subroutine prepare_moving_interface_reduced_request_inplace


  subroutine materialize_moving_interface_full_candidate_inplace(full_origin, reduced_result, tail_pressure_head, &
                                                                  tail_water_content, full_candidate, ok, reason, &
                                                                  reallocated)
    type(soil_water_physical_state_t), intent(in) :: full_origin
    type(soil_water_solve_result_t), intent(in) :: reduced_result
    real(real64), intent(in) :: tail_pressure_head(:), tail_water_content(:)
    type(soil_water_solve_result_t), intent(inout) :: full_candidate
    logical, intent(out) :: ok
    character(len=*), intent(out) :: reason
    logical, intent(out), optional :: reallocated
    integer :: na, nf, nt
    logical :: did_reallocate

    ok = .false.
    reason = 'reduced-result-not-converged'
    did_reallocate = .false.
    if (present(reallocated)) reallocated = .false.
    if (reduced_result%status /= SW_SOLVE_CONVERGED) return

    nf = full_origin%active_nodes
    na = reduced_result%candidate_state%active_nodes
    if (nf <= 0 .or. na <= 0 .or. na >= nf) then
       reason = 'candidate-shape-invalid'
       return
    end if
    if (.not. allocated(reduced_result%candidate_state%pressure_head) .or. &
        .not. allocated(reduced_result%candidate_state%water_content)) then
       reason = 'reduced-candidate-shape-missing'
       return
    end if
    nt = nf-na
    if (size(tail_pressure_head) /= nt .or. size(tail_water_content) /= nt) then
       reason = 'tail-shape-mismatch'
       return
    end if

    if (.not. allocated(full_candidate%candidate_state%pressure_head) .or. &
        full_candidate%candidate_state%active_nodes /= nf) then
       if (allocated(full_candidate%candidate_state%pressure_head)) deallocate(full_candidate%candidate_state%pressure_head)
       if (allocated(full_candidate%candidate_state%water_content)) deallocate(full_candidate%candidate_state%water_content)
       allocate(full_candidate%candidate_state%pressure_head(nf), full_candidate%candidate_state%water_content(nf))
       did_reallocate = .true.
    end if

    full_candidate%status = reduced_result%status
    full_candidate%retry_advised = reduced_result%retry_advised
    full_candidate%top_flux = reduced_result%top_flux
    full_candidate%bottom_flux = reduced_result%bottom_flux
    full_candidate%unrounded_mass_balance_residual = reduced_result%unrounded_mass_balance_residual
    full_candidate%integrated_mass_balance_residual_available = reduced_result%integrated_mass_balance_residual_available
    full_candidate%integrated_mass_balance_residual_cm = reduced_result%integrated_mass_balance_residual_cm
    full_candidate%native_balance_rate_residual_available = reduced_result%native_balance_rate_residual_available
    full_candidate%native_balance_rate_residual_cm_per_day = reduced_result%native_balance_rate_residual_cm_per_day
    full_candidate%diagnostics = reduced_result%diagnostics
    full_candidate%interface_sensitivity = reduced_result%interface_sensitivity
    full_candidate%candidate_state%active_nodes = nf
    full_candidate%candidate_state%pressure_head(1:na) = reduced_result%candidate_state%pressure_head
    full_candidate%candidate_state%water_content(1:na) = reduced_result%candidate_state%water_content
    full_candidate%candidate_state%pressure_head(na+1:nf) = tail_pressure_head
    full_candidate%candidate_state%water_content(na+1:nf) = tail_water_content
    full_candidate%candidate_state%ponding_depth = reduced_result%candidate_state%ponding_depth
    full_candidate%candidate_state%groundwater_level = reduced_result%candidate_state%groundwater_level

    if (present(reallocated)) reallocated = did_reallocate
    ok = .true.
    reason = 'full-candidate-materialized-inplace'
  end subroutine materialize_moving_interface_full_candidate_inplace


  subroutine select_moving_interface_route(reduced_status, reduced_valid, view, reduced_workspace_generation, &
                                           fallback_reason, use_reduced, diagnostics)
    integer, intent(in) :: reduced_status
    logical, intent(in) :: reduced_valid
    type(moving_interface_active_view_t), intent(in) :: view
    integer(int64), intent(in) :: reduced_workspace_generation
    character(len=*), intent(in) :: fallback_reason
    logical, intent(out) :: use_reduced
    type(moving_interface_manager_diagnostics_t), intent(out) :: diagnostics

    diagnostics = moving_interface_manager_diagnostics_t()
    diagnostics%full_nodes = view%full_nodes
    diagnostics%active_nodes = view%active_nodes
    diagnostics%tail_start_node = view%tail_start_node
    diagnostics%interface_face = view%interface_face
    diagnostics%reduced_workspace_generation = reduced_workspace_generation
    diagnostics%reduced_attempted = view%eligible
    use_reduced = .false.

    if (.not. view%eligible) then
       diagnostics%route = MI_MANAGER_ROUTE_FULL_BYPASS
       diagnostics%fallback_reason = 'reduced-view-ineligible'
       return
    end if

    if (reduced_valid .and. reduced_status == SW_SOLVE_CONVERGED) then
       use_reduced = .true.
       diagnostics%route = MI_MANAGER_ROUTE_REDUCED
       diagnostics%reduced_accepted = .true.
       diagnostics%fallback_reason = 'none'
    else
       diagnostics%route = MI_MANAGER_ROUTE_FULL_FALLBACK
       diagnostics%fallback_used = .true.
       diagnostics%fallback_reason = fallback_reason
    end if
  end subroutine select_moving_interface_route

end module mod_moving_interface_manager

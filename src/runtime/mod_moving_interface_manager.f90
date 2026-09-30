module mod_moving_interface_manager
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
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

  public :: derive_moving_interface_active_view
  public :: build_moving_interface_reduced_request
  public :: materialize_moving_interface_full_candidate
  public :: choose_moving_interface_result

contains

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

end module mod_moving_interface_manager

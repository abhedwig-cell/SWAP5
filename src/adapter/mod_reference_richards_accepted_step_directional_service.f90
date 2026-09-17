module mod_reference_richards_accepted_step_directional_service
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_NOT_RUN, SW_STEP_DIRECTION_AVAILABLE, SW_STEP_DIRECTION_UNAVAILABLE, &
       SW_STEP_DIRECTION_FAILED, SW_STEP_CONTROL_BOTTOM_FLUX, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_workspace, only: initialize_reference_workspace, &
       prepare_reference_tridag_factorization_capture, release_reference_tridag_factorization_capture
  use mod_reference_linear_solver, only: reference_tridag_backsolve
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX, FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t
  use mod_b110_dynamic_top_boundary_directional_adapter, only: evaluate_b110_dynamic_surface_flux_direction
  implicit none
  private

  public :: solve_with_accepted_step_direction

contains

  subroutine solve_with_accepted_step_direction(solver, request, workspace, direction_request, &
                                                solve_result, direction_result)
    class(soil_water_solver_t), intent(inout) :: solver
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_accepted_step_direction_request_t), intent(in) :: direction_request
    type(soil_water_solve_result_t), intent(out) :: solve_result
    type(soil_water_accepted_step_direction_result_t), intent(out) :: direction_result

    logical :: eligible
    character(len=64) :: eligibility_route
    integer :: n

    direction_result = soil_water_accepted_step_direction_result_t()
    if (.not. direction_request%requested) then
       call solver%solve(request, workspace, solve_result)
       direction_result%status = SW_STEP_DIRECTION_NOT_RUN
       direction_result%route = 'not-requested'
       return
    end if

    select type (ref_solver => solver)
    type is (reference_richards_legacy_solver_t)
       select type (ref_ws => workspace)
       type is (reference_richards_legacy_workspace_t)
          n = request_node_count(request)
          call direction_route_eligible(request, direction_request, n, eligible, eligibility_route)
          if (.not. eligible) then
             call ref_solver%solve(request, ref_ws, solve_result)
             direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
             direction_result%route = eligibility_route
             direction_result%control_coordinate = direction_request%control_coordinate
             return
          end if

          ! Expanded factorization storage is worker scratch only. The physical
          ! solve is still executed exactly once and remains the sole candidate.
          call initialize_reference_workspace(ref_ws%richards, n)
          call prepare_reference_tridag_factorization_capture(ref_ws%richards)
          call ref_solver%solve(request, ref_ws, solve_result)

          if (solve_result%status /= SW_SOLVE_CONVERGED) then
             direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
             direction_result%route = 'physical-step-not-accepted'
             direction_result%control_coordinate = direction_request%control_coordinate
             call release_reference_tridag_factorization_capture(ref_ws%richards)
             return
          end if
          if (solve_result%diagnostics%alternative_solver_calls /= 0) then
             direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
             direction_result%route = 'accepted-alternative-linear-solver'
             direction_result%control_coordinate = direction_request%control_coordinate
             call release_reference_tridag_factorization_capture(ref_ws%richards)
             return
          end if
          if (size(ref_ws%richards%tridag_gamma) < 2*n) then
             direction_result%status = SW_STEP_DIRECTION_FAILED
             direction_result%route = 'accepted-factorization-not-captured'
             direction_result%control_coordinate = direction_request%control_coordinate
             call release_reference_tridag_factorization_capture(ref_ws%richards)
             return
          end if

          call evaluate_reference_accepted_step_direction(request, solve_result, direction_request, &
               ref_ws, direction_result)
          call release_reference_tridag_factorization_capture(ref_ws%richards)
       class default
          call ref_solver%solve(request, workspace, solve_result)
          direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
          direction_result%route = 'reference-workspace-type-unavailable'
          direction_result%control_coordinate = direction_request%control_coordinate
       end select
    class default
       ! Alternative soil-water solvers keep a valid physical solve and fail the
       ! optional Reference-specific directional capability closed.
       call solver%solve(request, workspace, solve_result)
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = 'solver-step-direction-unavailable'
       direction_result%control_coordinate = direction_request%control_coordinate
    end select
  end subroutine solve_with_accepted_step_direction

  subroutine direction_route_eligible(request, direction_request, n, eligible, route)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_accepted_step_direction_request_t), intent(in) :: direction_request
    integer, intent(in) :: n
    logical, intent(out) :: eligible
    character(len=*), intent(out) :: route

    logical :: top_ok
    real(real64) :: top_direction, pond_direction
    character(len=64) :: top_route

    eligible = .false.
    route = 'step-direction-unqualified'
    if (n < 2) then
       route = 'step-direction-needs-two-nodes'
       return
    end if
    if (request%request_interface_sensitivity) then
       route = 'local-terminal-request-conflicts'
       return
    end if
    if (request%physical%macropore_active) then
       route = 'macropore-direction-unavailable'
       return
    end if
    if (request%numerical%conductivity_implicit_mode /= 0) then
       route = 'swkimpl-direction-unavailable'
       return
    end if
    if (request%numerical%conductivity_mean_method < 1 .or. &
        request%numerical%conductivity_mean_method > 6) then
       route = 'conductivity-mean-direction-unavailable'
       return
    end if
    if (.not. associated(request%evaluation%constitutive)) then
       route = 'constitutive-provider-missing'
       return
    end if
    select type (hyd => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       continue
    class default
       route = 'constitutive-direction-unavailable'
       return
    end select

    select case (request%boundary%top_mode)
    case (FSI_TOP_MODE_EXPLICIT_FLUX)
       if (.not. associated(request%evaluation%top_boundary)) then
          route = 'top-provider-missing'
          return
       end if
       select type (top => request%evaluation%top_boundary)
       type is (fixed_flux_top_boundary_provider_t)
          continue
       class default
          route = 'top-provider-direction-unavailable'
          return
       end select
       route = 'reference-swkimpl0-fixed-flux-b110'

    case (FSI_TOP_MODE_DYNAMIC_PROVIDER)
       if (.not. associated(request%evaluation%dynamic_top_boundary)) then
          route = 'dynamic-top-provider-missing'
          return
       end if
       select type (top => request%evaluation%dynamic_top_boundary)
       type is (b110_dynamic_top_boundary_solver_provider_t)
          call evaluate_b110_dynamic_surface_flux_direction(top, request%base_state%pressure_head(1), &
               request%base_state%water_content(1), request%base_state%ponding_depth, request%boundary, &
               direction_request%incoming_ponding_depth, top_ok, top_direction, pond_direction, top_route)
          if (.not. top_ok) then
             route = top_route
             return
          end if
       class default
          route = 'dynamic-top-direction-unavailable'
          return
       end select
       route = 'reference-swkimpl0-dynamic-surface-flux'

    case default
       route = 'top-mode-direction-unavailable'
       return
    end select

    if (.not. associated(request%evaluation%source_sink)) then
       route = 'source-sink-provider-missing'
       return
    end if
    select type (ss => request%evaluation%source_sink)
    type is (b110_source_sink_provider_t)
       continue
    class default
       route = 'source-sink-direction-unavailable'
       return
    end select
    if (associated(request%evaluation%root_sink)) then
       route = 'root-sink-direction-unavailable'
       return
    end if
    if (.not. allocated(direction_request%incoming_pressure_head) .or. &
        .not. allocated(direction_request%incoming_water_content)) then
       route = 'incoming-direction-missing'
       return
    end if
    if (size(direction_request%incoming_pressure_head) /= n .or. &
        size(direction_request%incoming_water_content) /= n) then
       route = 'incoming-direction-shape-invalid'
       return
    end if
    if (allocated(direction_request%incoming_source_direction)) then
       if (size(direction_request%incoming_source_direction) /= n) then
          route = 'source-direction-shape-invalid'
          return
       end if
       if (any(.not. ieee_is_finite(direction_request%incoming_source_direction))) then
          route = 'source-direction-nonfinite'
          return
       end if
    end if
    if (allocated(direction_request%incoming_sink_direction)) then
       if (size(direction_request%incoming_sink_direction) /= n) then
          route = 'sink-direction-shape-invalid'
          return
       end if
       if (any(.not. ieee_is_finite(direction_request%incoming_sink_direction))) then
          route = 'sink-direction-nonfinite'
          return
       end if
    end if
    if (any(.not. ieee_is_finite(direction_request%incoming_pressure_head)) .or. &
        any(.not. ieee_is_finite(direction_request%incoming_water_content)) .or. &
        .not. ieee_is_finite(direction_request%incoming_ponding_depth) .or. &
        .not. ieee_is_finite(direction_request%direct_control_derivative)) then
       route = 'incoming-direction-nonfinite'
       return
    end if

    select case (request%boundary%bottom_mode)
    case (SW_STEP_CONTROL_BOTTOM_FLUX)
       if (direction_request%control_coordinate /= SW_STEP_CONTROL_BOTTOM_FLUX) then
          route = 'bottom-flux-control-coordinate-mismatch'
          return
       end if
    case (SW_STEP_CONTROL_BOTTOM_HEAD)
       if (direction_request%control_coordinate /= SW_STEP_CONTROL_BOTTOM_HEAD) then
          route = 'bottom-head-control-coordinate-mismatch'
          return
       end if
    case default
       route = 'bottom-mode-direction-unavailable'
       return
    end select

    eligible = .true.
  end subroutine direction_route_eligible

  subroutine evaluate_reference_accepted_step_direction(request, solve_result, direction_request, ref_ws, direction_result)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(soil_water_accepted_step_direction_request_t), intent(in) :: direction_request
    type(reference_richards_legacy_workspace_t), intent(inout) :: ref_ws
    type(soil_water_accepted_step_direction_result_t), intent(inout) :: direction_result

    integer :: n, i, tangent_ierror
    logical :: mean_ok, constitutive_direction_ok, top_direction_ok
    character(len=64) :: constitutive_direction_route, top_direction_route, result_route
    real(real64) :: bottom_distance, bdir, grad_bottom
    real(real64) :: top_flux_direction, outgoing_ponding_direction
    real(real64), allocatable :: source_direction(:), sink_direction(:)

    n = request%parameters%active_nodes
    direction_result%control_coordinate = direction_request%control_coordinate
    allocate(source_direction(n), sink_direction(n))
    source_direction = 0.0_real64
    sink_direction = 0.0_real64
    if (allocated(direction_request%incoming_source_direction)) &
         source_direction = direction_request%incoming_source_direction
    if (allocated(direction_request%incoming_sink_direction)) &
         sink_direction = direction_request%incoming_sink_direction

    ! Re-evaluate the immutable constitutive value provider at the step base
    ! state for the exact frozen K values used by swkimpl=0. Its historical
    ! dconductivity_dhead output is deliberately reserved/zero, therefore the
    ! derivative comes only from the explicit B1.10 sibling capability.
    call request%evaluation%constitutive%evaluate(request%base_state%pressure_head, &
         ref_ws%richards%provider_theta, ref_ws%richards%provider_k, &
         ref_ws%richards%provider_capacity, ref_ws%richards%provider_dkdh)
    if (any(.not. ieee_is_finite(ref_ws%richards%provider_k(1:n)))) then
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = 'base-constitutive-value-nonfinite'
       return
    end if

    select type (hyd => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       call evaluate_b110_default_mvg_state_direction(hyd, request%base_state%pressure_head, &
            direction_request%incoming_pressure_head, ref_ws%richards%provider_theta, &
            ref_ws%richards%band_aux(:,1), constitutive_direction_ok, constitutive_direction_route)
    class default
       constitutive_direction_ok = .false.
       constitutive_direction_route = 'constitutive-direction-unavailable'
    end select
    if (.not. constitutive_direction_ok) then
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = constitutive_direction_route
       return
    end if

    ! Resolve the accepted top route before the tangent backsolve. If a dynamic
    ! trial crossed into capacity-limited evaporation or any regime boundary,
    ! the physical candidate stays valid but its optional derivative is withheld.
    select case (request%boundary%top_mode)
    case (FSI_TOP_MODE_EXPLICIT_FLUX)
       top_direction_ok = .true.
       top_flux_direction = 0.0_real64
       outgoing_ponding_direction = direction_request%incoming_ponding_depth
       top_direction_route = 'fixed-flux-direction'
       result_route = 'reference-swkimpl0-fixed-flux-b110'
    case (FSI_TOP_MODE_DYNAMIC_PROVIDER)
       top_direction_ok = .false.
       top_flux_direction = 0.0_real64
       outgoing_ponding_direction = 0.0_real64
       top_direction_route = 'dynamic-top-direction-unavailable'
       select type (top => request%evaluation%dynamic_top_boundary)
       type is (b110_dynamic_top_boundary_solver_provider_t)
          call evaluate_b110_dynamic_surface_flux_direction(top, &
               solve_result%candidate_state%pressure_head(1), solve_result%candidate_state%water_content(1), &
               solve_result%candidate_state%ponding_depth, request%boundary, &
               direction_request%incoming_ponding_depth, top_direction_ok, top_flux_direction, &
               outgoing_ponding_direction, top_direction_route)
       class default
          continue
       end select
       if (.not. top_direction_ok) then
          direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
          direction_result%route = top_direction_route
          return
       end if
       result_route = 'reference-swkimpl0-dynamic-surface-flux'
    case default
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = 'top-mode-direction-unavailable'
       return
    end select

    ! band_aux(:,1) contains exact base-state dK at nodes. vertical_flux is
    ! reused after the physical solve as worker scratch for dKmean at faces.
    ref_ws%richards%vertical_flux(1:n+1) = 0.0_real64
    do i = 2, n
       call hydraulic_mean_directional(request%numerical%conductivity_mean_method, &
            ref_ws%richards%provider_k(i-1), ref_ws%richards%provider_k(i), &
            request%parameters%dz(i-1), request%parameters%dz(i), &
            ref_ws%richards%band_aux(i-1,1), ref_ws%richards%band_aux(i,1), &
            ref_ws%richards%vertical_flux(i), mean_ok)
       if (.not. mean_ok) then
          direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
          direction_result%route = 'conductivity-mean-direction-nonsmooth'
          return
       end if
    end do
    ref_ws%richards%vertical_flux(n+1) = ref_ws%richards%band_aux(n,1)

    ref_ws%richards%head_gradient(1:n+1) = 0.0_real64
    do i = 2, n
       ref_ws%richards%head_gradient(i) = &
            (solve_result%candidate_state%pressure_head(i-1) - &
             solve_result%candidate_state%pressure_head(i)) / request%parameters%node_distance(i) + 1.0_real64
    end do

    ! Assemble B_k*s_k + r_p at fixed accepted h. HeadCalc's residual owns
    ! external source/sink signs as +sink-source, so their direct directions
    ! enter with exactly the same signs here. Absent optional direction arrays
    ! are materialized as exact zero above, preserving all earlier callers.
    ! For the admitted dynamic surface-flux subset dqtop is a direct
    ! previous-ponding contribution; the capacity-limited branch is rejected.
    ref_ws%richards%band_rhs(1:n) = 0.0_real64
    bdir = -direction_request%incoming_water_content(1) * request%parameters%dz(1) / request%step_duration + &
           sink_direction(1) - source_direction(1) + &
           ref_ws%richards%vertical_flux(2) * ref_ws%richards%head_gradient(2) + top_flux_direction
    ref_ws%richards%band_rhs(1) = -bdir
    do i = 2, n-1
       bdir = -direction_request%incoming_water_content(i) * request%parameters%dz(i) / request%step_duration + &
              sink_direction(i) - source_direction(i) - &
              ref_ws%richards%vertical_flux(i) * ref_ws%richards%head_gradient(i) + &
              ref_ws%richards%vertical_flux(i+1) * ref_ws%richards%head_gradient(i+1)
       ref_ws%richards%band_rhs(i) = -bdir
    end do
    bdir = -direction_request%incoming_water_content(n) * request%parameters%dz(n) / request%step_duration + &
           sink_direction(n) - source_direction(n) - &
           ref_ws%richards%vertical_flux(n) * ref_ws%richards%head_gradient(n)

    select case (request%boundary%bottom_mode)
    case (SW_STEP_CONTROL_BOTTOM_FLUX)
       bdir = bdir - direction_request%direct_control_derivative
    case (SW_STEP_CONTROL_BOTTOM_HEAD)
       bottom_distance = 0.5_real64 * request%parameters%dz(n)
       if (bottom_distance <= 0.0_real64) then
          direction_result%status = SW_STEP_DIRECTION_FAILED
          direction_result%route = 'bottom-distance-invalid'
          return
       end if
       grad_bottom = (solve_result%candidate_state%pressure_head(n) - request%boundary%bottom_head) / &
            bottom_distance + 1.0_real64
       bdir = bdir + ref_ws%richards%vertical_flux(n+1) * grad_bottom - &
            ref_ws%richards%provider_k(n) * direction_request%direct_control_derivative / bottom_distance
    end select
    ref_ws%richards%band_rhs(n) = -bdir

    if (any(.not. ieee_is_finite(ref_ws%richards%band_rhs(1:n)))) then
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = 'directional-rhs-nonfinite'
       return
    end if

    call reference_tridag_backsolve(n, ref_ws%richards%dfdh_upper, ref_ws%richards%band_rhs, &
         ref_ws%richards%tridag_gamma(1:n), ref_ws%richards%tridag_gamma(n+1:2*n), &
         ref_ws%richards%delta_head, tangent_ierror)
    direction_result%additional_tridiagonal_backsolves = 1
    if (tangent_ierror /= 0 .or. any(.not. ieee_is_finite(ref_ws%richards%delta_head(1:n)))) then
       direction_result%status = SW_STEP_DIRECTION_FAILED
       direction_result%route = 'accepted-factor-backsolve-failed'
       return
    end if

    allocate(direction_result%outgoing_pressure_head(n), direction_result%outgoing_water_content(n))
    direction_result%outgoing_pressure_head = ref_ws%richards%delta_head(1:n)

    select type (hyd => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       call evaluate_b110_default_mvg_state_direction(hyd, solve_result%candidate_state%pressure_head, &
            direction_result%outgoing_pressure_head, direction_result%outgoing_water_content, &
            ref_ws%richards%band_aux(:,1), constitutive_direction_ok, constitutive_direction_route)
    class default
       constitutive_direction_ok = .false.
       constitutive_direction_route = 'accepted-constitutive-direction-unavailable'
    end select
    if (.not. constitutive_direction_ok) then
       deallocate(direction_result%outgoing_pressure_head, direction_result%outgoing_water_content)
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = constitutive_direction_route
       return
    end if

    direction_result%outgoing_ponding_depth = outgoing_ponding_direction
    direction_result%top_flux_derivative = top_flux_direction

    select case (request%boundary%bottom_mode)
    case (SW_STEP_CONTROL_BOTTOM_FLUX)
       direction_result%bottom_flux_derivative = direction_request%direct_control_derivative
    case (SW_STEP_CONTROL_BOTTOM_HEAD)
       ! Exact derivative of materialize_prescribed_head_bottom_flux():
       ! qtop + accepted-minus-base storage + sink - source. Root terms remain
       ! excluded by direction_route_eligible().
       direction_result%bottom_flux_derivative = top_flux_direction + &
            (sum(direction_result%outgoing_water_content * request%parameters%dz) - &
             sum(direction_request%incoming_water_content * request%parameters%dz)) / request%step_duration + &
            sum(sink_direction) - sum(source_direction)
    end select

    if (.not. ieee_is_finite(direction_result%top_flux_derivative) .or. &
        .not. ieee_is_finite(direction_result%bottom_flux_derivative) .or. &
        .not. ieee_is_finite(direction_result%outgoing_ponding_depth) .or. &
        any(.not. ieee_is_finite(direction_result%outgoing_water_content))) then
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%available = .false.
       direction_result%route = 'accepted-output-direction-nonfinite'
       return
    end if

    direction_result%status = SW_STEP_DIRECTION_AVAILABLE
    direction_result%available = .true.
    direction_result%fixed_smooth_route = .true.
    direction_result%method = 'same-accepted-tridag-factor'
    direction_result%route = result_route
    direction_result%additional_jacobian_builds = 0
    direction_result%additional_full_nonlinear_solves = 0
  end subroutine evaluate_reference_accepted_step_direction

  subroutine hydraulic_mean_directional(method, kup, klow, dzup, dzlow, dkup, dklow, dmean, ok)
    integer, intent(in) :: method
    real(real64), intent(in) :: kup, klow, dzup, dzlow, dkup, dklow
    real(real64), intent(out) :: dmean
    logical, intent(out) :: ok
    real(real64) :: dup, dlow

    ok = .false.
    dmean = 0.0_real64
    if (.not. ieee_is_finite(kup) .or. .not. ieee_is_finite(klow) .or. &
        .not. ieee_is_finite(dkup) .or. .not. ieee_is_finite(dklow)) return
    if (dzup <= 0.0_real64 .or. dzlow <= 0.0_real64) return
    if (method >= 3 .and. method <= 6) then
       if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
    end if

    call hydraulic_mean_partial(method, kup, klow, dzup, dzlow, dup, ok)
    if (.not. ok) return
    call hydraulic_mean_partial(method, klow, kup, dzlow, dzup, dlow, ok)
    if (.not. ok) return
    dmean = dup*dkup + dlow*dklow
    ok = ieee_is_finite(dmean)
  end subroutine hydraulic_mean_directional

  subroutine hydraulic_mean_partial(method, kmain, ksub, dzmain, dzsub, derivative, ok)
    integer, intent(in) :: method
    real(real64), intent(in) :: kmain, ksub, dzmain, dzsub
    real(real64), intent(out) :: derivative
    logical, intent(out) :: ok
    real(real64) :: a

    derivative = 0.0_real64
    ok = .true.
    select case (method)
    case (1)
       derivative = 0.5_real64
    case (2)
       derivative = dzmain/(dzmain+dzsub)
    case (3)
       derivative = 0.5_real64*sqrt(ksub/kmain)
    case (4)
       a = dzmain/(dzmain+dzsub)
       derivative = a*(ksub/kmain)**(1.0_real64-a)
    case (5)
       derivative = 0.5_real64 / (((0.5_real64/kmain)+(0.5_real64/ksub))**2 * kmain**2)
    case (6)
       a = dzmain/(dzmain+dzsub)
       derivative = a / (((a/kmain)+((1.0_real64-a)/ksub))**2 * kmain**2)
    case default
       ok = .false.
       return
    end select
    ok = ieee_is_finite(derivative)
  end subroutine hydraulic_mean_partial

  integer function request_node_count(request) result(n)
    type(soil_water_solve_request_t), intent(in) :: request
    if (associated(request%parameters)) then
       n = request%parameters%active_nodes
    else
       n = 0
    end if
  end function request_node_count

end module mod_reference_richards_accepted_step_directional_service

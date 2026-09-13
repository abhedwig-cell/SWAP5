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
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t
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

          ! Expand only worker-owned TRIDAG scratch. reference_richards_legacy_solve
          ! reinitializes/reset the workspace but deliberately preserves this
          ! allocation shape, so its final accepted factorization remains available
          ! here. No physical state, parameter data or per-column persistence is added.
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
       ! Alternative solvers keep the same physical solve semantics and fail the
       ! optional derivative closed. They need not emulate Richards internals.
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
    if (request%boundary%top_mode /= FSI_TOP_MODE_EXPLICIT_FLUX) then
       route = 'dynamic-or-head-top-direction-unavailable'
       return
    end if
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
    route = 'reference-swkimpl0-fixed-flux-b110'
  end subroutine direction_route_eligible

  subroutine evaluate_reference_accepted_step_direction(request, solve_result, direction_request, ref_ws, direction_result)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(soil_water_accepted_step_direction_request_t), intent(in) :: direction_request
    type(reference_richards_legacy_workspace_t), intent(inout) :: ref_ws
    type(soil_water_accepted_step_direction_result_t), intent(inout) :: direction_result

    integer :: n, i, tangent_ierror
    logical :: mean_ok
    real(real64) :: bottom_distance, bdir, grad_bottom

    n = request%parameters%active_nodes
    direction_result%control_coordinate = direction_request%control_coordinate

    ! Re-evaluate the immutable constitutive provider at the step base state to
    ! obtain dK/dh for B_k*s_k. This is numerical scratch evaluation only; it
    ! does not change the accepted candidate or the physical mass ledger.
    call request%evaluation%constitutive%evaluate(request%base_state%pressure_head, &
         ref_ws%richards%provider_theta, ref_ws%richards%provider_k, &
         ref_ws%richards%provider_capacity, ref_ws%richards%provider_dkdh)
    if (any(.not. ieee_is_finite(ref_ws%richards%provider_k(1:n))) .or. &
        any(.not. ieee_is_finite(ref_ws%richards%provider_dkdh(1:n)))) then
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = 'base-constitutive-direction-nonfinite'
       return
    end if

    ! band_aux(:,1) is worker scratch for dK at nodes; vertical_flux is reused
    ! after the accepted physical solve as scratch for dKmean at faces.
    ref_ws%richards%band_aux(1:n,1) = ref_ws%richards%provider_dkdh(1:n) * &
         direction_request%incoming_pressure_head(1:n)
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
    ! B1.10 reset semantics for the lower face in modes 2/5: Kmean(N+1)=K(N).
    ref_ws%richards%vertical_flux(n+1) = ref_ws%richards%band_aux(n,1)

    ! Accepted-state hydraulic gradients. The top route is prescribed flux, so
    ! it contributes no state/control directional term to F_1.
    ref_ws%richards%head_gradient(1:n+1) = 0.0_real64
    do i = 2, n
       ref_ws%richards%head_gradient(i) = &
            (solve_result%candidate_state%pressure_head(i-1) - &
             solve_result%candidate_state%pressure_head(i)) / request%parameters%node_distance(i) + 1.0_real64
    end do

    ! Assemble B_k*s_k + r_p at fixed accepted h. Storage uses the incoming
    ! water-content direction explicitly; frozen swkimpl=0 conductivities use
    ! the incoming pressure-head direction through dK/dh and exact hcomean
    ! derivatives for methods 1..6.
    ref_ws%richards%band_rhs(1:n) = 0.0_real64
    bdir = -direction_request%incoming_water_content(1) * request%parameters%dz(1) / request%step_duration + &
           ref_ws%richards%vertical_flux(2) * ref_ws%richards%head_gradient(2)
    ref_ws%richards%band_rhs(1) = -bdir
    do i = 2, n-1
       bdir = -direction_request%incoming_water_content(i) * request%parameters%dz(i) / request%step_duration - &
              ref_ws%richards%vertical_flux(i) * ref_ws%richards%head_gradient(i) + &
              ref_ws%richards%vertical_flux(i+1) * ref_ws%richards%head_gradient(i+1)
       ref_ws%richards%band_rhs(i) = -bdir
    end do
    bdir = -direction_request%incoming_water_content(n) * request%parameters%dz(n) / request%step_duration - &
           ref_ws%richards%vertical_flux(n) * ref_ws%richards%head_gradient(n)

    select case (request%boundary%bottom_mode)
    case (SW_STEP_CONTROL_BOTTOM_FLUX)
       ! F_N contains -qbot.
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

    ! At the accepted state, provider capacity is dtheta/dh on the same smooth
    ! constitutive branch. This second provider evaluation is diagnostic scratch
    ! only and occurs after the physical candidate and exact qbot are fixed.
    call request%evaluation%constitutive%evaluate(solve_result%candidate_state%pressure_head, &
         ref_ws%richards%provider_theta, ref_ws%richards%provider_k, &
         ref_ws%richards%provider_capacity, ref_ws%richards%provider_dkdh)
    if (any(.not. ieee_is_finite(ref_ws%richards%provider_capacity(1:n)))) then
       deallocate(direction_result%outgoing_pressure_head, direction_result%outgoing_water_content)
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = 'accepted-capacity-direction-nonfinite'
       return
    end if
    direction_result%outgoing_water_content = ref_ws%richards%provider_capacity(1:n) * &
         direction_result%outgoing_pressure_head
    direction_result%outgoing_ponding_depth = direction_request%incoming_ponding_depth
    direction_result%top_flux_derivative = 0.0_real64

    select case (request%boundary%bottom_mode)
    case (SW_STEP_CONTROL_BOTTOM_FLUX)
       direction_result%bottom_flux_derivative = direction_request%direct_control_derivative
    case (SW_STEP_CONTROL_BOTTOM_HEAD)
       ! Exact derivative of materialize_prescribed_head_bottom_flux(): fixed
       ! top/source/sink terms have zero directional derivative on this qualified
       ! route, leaving only accepted-minus-base storage divided by dt.
       direction_result%bottom_flux_derivative = &
            (sum(direction_result%outgoing_water_content * request%parameters%dz) - &
             sum(direction_request%incoming_water_content * request%parameters%dz)) / request%step_duration
    end select

    if (.not. ieee_is_finite(direction_result%bottom_flux_derivative) .or. &
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
    direction_result%route = 'reference-swkimpl0-fixed-flux-b110'
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

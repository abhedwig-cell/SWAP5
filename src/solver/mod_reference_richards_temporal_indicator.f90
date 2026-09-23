module mod_reference_richards_temporal_indicator
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t, soil_water_solve_result_t, &
       soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       soil_water_top_boundary_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE, &
       SW_TEMPORAL_INDICATOR_FAILED, SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX, FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_reference_linear_solver, only: reference_tridag
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t
  implicit none
  private

  public :: evaluate_reference_richards_temporal_indicator

contains

  subroutine evaluate_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(soil_water_temporal_indicator_request_t), intent(in) :: indicator_request
    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result

    integer :: n, i, ierr
    logical :: dynamic_flux_equivalent
    real(real64) :: dt, face_conductance, bottom_distance, raw_norm, defect_norm, bounded_norm
    real(real64) :: scale, water_diff
    real(real64), allocatable :: water_base(:), conductivity_base(:), capacity_base(:), dkdh_base(:)
    real(real64), allocatable :: water_candidate(:), conductivity_candidate(:), capacity_candidate(:), dkdh_candidate(:)
    real(real64), allocatable :: mass_weight(:), lower(:), diagonal(:), upper(:), rhs(:), delta(:), gamma(:), e_raw(:)

    indicator_result = soil_water_temporal_indicator_result_t()
    if (solve_result%status /= SW_SOLVE_CONVERGED) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'candidate-not-converged'
       return
    end if
    if (.not. associated(request%parameters)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'parameters-not-bound'
       return
    end if

    n = request%parameters%active_nodes
    dt = request%step_duration
    if (n <= 0 .or. dt <= 0.0_real64) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'invalid-size-or-dt'
       return
    end if
    if (request%base_state%active_nodes /= n .or. solve_result%candidate_state%active_nodes /= n) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'state-size-mismatch'
       return
    end if
    if (.not. allocated(request%base_state%pressure_head) .or. &
        .not. allocated(solve_result%candidate_state%pressure_head) .or. &
        .not. allocated(solve_result%candidate_state%water_content) .or. &
        .not. allocated(request%parameters%dz) .or. .not. allocated(request%parameters%node_distance)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'required-array-missing'
       return
    end if
    if (size(request%base_state%pressure_head) /= n .or. &
        size(solve_result%candidate_state%pressure_head) /= n .or. &
        size(solve_result%candidate_state%water_content) /= n .or. &
        size(request%parameters%dz) /= n .or. size(request%parameters%node_distance) /= n) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'required-array-shape'
       return
    end if
    if (any(.not. ieee_is_finite(request%base_state%pressure_head)) .or. &
        any(.not. ieee_is_finite(solve_result%candidate_state%pressure_head)) .or. &
        any(.not. ieee_is_finite(solve_result%candidate_state%water_content))) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'nonfinite-state'
       return
    end if

    allocate(indicator_result%current_right_derivative(n))
    indicator_result%current_right_derivative = &
         (solve_result%candidate_state%pressure_head-request%base_state%pressure_head)/dt
    if (any(.not. ieee_is_finite(indicator_result%current_right_derivative))) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'nonfinite-current-derivative'
       return
    end if

    if (.not. indicator_request%previous_right_derivative_available) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'previous-derivative-unavailable'
       return
    end if
    if (.not. allocated(indicator_request%previous_right_derivative)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'previous-derivative-missing'
       return
    end if
    if (size(indicator_request%previous_right_derivative) /= n .or. &
        any(.not. ieee_is_finite(indicator_request%previous_right_derivative))) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'previous-derivative-invalid'
       return
    end if

    if (request%physical%macropore_active .or. associated(request%evaluation%macropore)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'macropore-envelope-deferred'
       return
    end if
    if (associated(request%evaluation%root_sink)) then
       select type (root_sink_provider => request%evaluation%root_sink)
       type is (b110_root_sink_provider_t)
          if (root_sink_provider%active_nodes /= n) then
             indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
             indicator_result%route = 'root-sink-size-mismatch'
             return
          end if
          if (.not. associated(root_sink_provider%root_extraction_sink)) then
             indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
             indicator_result%route = 'root-sink-not-bound'
             return
          end if
          if (size(root_sink_provider%root_extraction_sink) /= n .or. &
              any(.not. ieee_is_finite(root_sink_provider%root_extraction_sink))) then
             indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
             indicator_result%route = 'root-sink-invalid-prescribed-vector'
             return
          end if
       class default
          indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
          indicator_result%route = 'root-sink-policy-deferred'
          return
       end select
    end if
    if (request%numerical%conductivity_implicit_mode /= 0 .or. &
        request%numerical%conductivity_mean_method /= 1) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'conductivity-policy-deferred'
       return
    end if
    if (request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'boundary-envelope-deferred'
       return
    end if
    if (.not. associated(request%evaluation%constitutive) .or. &
        .not. associated(request%evaluation%source_sink)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'provider-envelope-incomplete'
       return
    end if

    dynamic_flux_equivalent = .false.
    select case (request%boundary%top_mode)
    case (FSI_TOP_MODE_EXPLICIT_FLUX)
       if (.not. associated(request%evaluation%top_boundary)) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
          indicator_result%route = 'provider-envelope-incomplete'
          return
       end if
       select type (top_provider => request%evaluation%top_boundary)
       type is (fixed_flux_top_boundary_provider_t)
          continue
       class default
          indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
          indicator_result%route = 'fixed-top-flux-required'
          return
       end select
    case (FSI_TOP_MODE_DYNAMIC_PROVIDER)
       call qualify_dynamic_flux_temporal_envelope(request, solve_result, dynamic_flux_equivalent)
       if (.not. dynamic_flux_equivalent) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
          indicator_result%route = 'dynamic-flux-envelope-deferred'
          return
       end if
    case default
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'boundary-envelope-deferred'
       return
    end select
    select type (source_sink_provider => request%evaluation%source_sink)
    type is (b110_source_sink_provider_t)
       if (source_sink_provider%active_nodes /= n) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'source-sink-size-mismatch'
          return
       end if
    class default
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'source-sink-policy-deferred'
       return
    end select

    allocate(water_base(n), conductivity_base(n), capacity_base(n), dkdh_base(n))
    allocate(water_candidate(n), conductivity_candidate(n), capacity_candidate(n), dkdh_candidate(n))
    select type (constitutive => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       scale = max(1.0_real64, abs(constitutive%step_duration), abs(dt))
       if (abs(constitutive%step_duration-dt) > 16.0_real64*epsilon(1.0_real64)*scale) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'constitutive-dt-mismatch'
          return
       end if
       call constitutive%evaluate(request%base_state%pressure_head, water_base, conductivity_base, capacity_base, dkdh_base)
       call constitutive%evaluate(solve_result%candidate_state%pressure_head, water_candidate, conductivity_candidate, &
            capacity_candidate, dkdh_candidate)
    class default
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'constitutive-policy-deferred'
       return
    end select

    if (any(.not. ieee_is_finite(conductivity_base)) .or. any(conductivity_base <= 0.0_real64) .or. &
        any(.not. ieee_is_finite(capacity_candidate)) .or. any(capacity_candidate <= 0.0_real64)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'invalid-operator-coefficients'
       return
    end if
    scale = max(1.0_real64, maxval(abs(water_candidate)), maxval(abs(solve_result%candidate_state%water_content)))
    water_diff = maxval(abs(water_candidate-solve_result%candidate_state%water_content))
    if (water_diff > 65536.0_real64*epsilon(1.0_real64)*scale) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'candidate-provider-mismatch'
       return
    end if
    if (any(.not. ieee_is_finite(request%parameters%dz)) .or. any(request%parameters%dz <= 0.0_real64)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'invalid-dz'
       return
    end if
    if (n > 1) then
       if (any(.not. ieee_is_finite(request%parameters%node_distance(2:n))) .or. &
           any(request%parameters%node_distance(2:n) <= 0.0_real64)) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'invalid-node-distance'
          return
       end if
    end if

    allocate(mass_weight(n), lower(n), diagonal(n), upper(n), rhs(n), delta(n), gamma(n), e_raw(n))
    mass_weight = capacity_candidate*request%parameters%dz
    if (any(.not. ieee_is_finite(mass_weight)) .or. any(mass_weight <= 0.0_real64)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'invalid-mass-weight'
       return
    end if

    e_raw = 0.5_real64*dt*(indicator_result%current_right_derivative-indicator_request%previous_right_derivative)
    if (any(.not. ieee_is_finite(e_raw))) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'nonfinite-raw-defect'
       return
    end if

    lower = 0.0_real64
    upper = 0.0_real64
    diagonal = mass_weight/dt
    do i = 2, n
       face_conductance = 0.5_real64*(conductivity_base(i-1)+conductivity_base(i))/request%parameters%node_distance(i)
       if (.not. ieee_is_finite(face_conductance) .or. face_conductance <= 0.0_real64) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'invalid-face-conductance'
          return
       end if
       lower(i) = -face_conductance
       upper(i-1) = -face_conductance
       diagonal(i-1) = diagonal(i-1)+face_conductance
       diagonal(i) = diagonal(i)+face_conductance
    end do

    ! Prescribed bottom head (mode 5) contributes a Dirichlet face stiffness
    ! d q_b / d h_N = K_b / distance. Prescribed qbot (mode 2) is a Neumann
    ! flux owned by the boundary request; its derivative with respect to state
    ! is zero and therefore contributes no bottom-head stiffness to the defect
    ! operator. The top boundary is likewise an explicit prescribed flux and
    ! already carries no top-face stiffness here.
    if (request%boundary%bottom_mode == 5) then
       bottom_distance = 0.5_real64*request%parameters%dz(n)
       face_conductance = conductivity_base(n)/bottom_distance
       if (.not. ieee_is_finite(face_conductance) .or. face_conductance <= 0.0_real64) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'invalid-bottom-conductance'
          return
       end if
       diagonal(n) = diagonal(n)+face_conductance
    end if

    rhs = (mass_weight/dt)*e_raw
    gamma = 0.0_real64
    call reference_tridag(n, lower, diagonal, upper, rhs, delta, gamma, ierr)
    indicator_result%additional_tridiagonal_solves = 1
    if (ierr /= 0 .or. any(.not. ieee_is_finite(delta))) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'defect-tridag-failed'
       return
    end if

    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
    defect_norm = sqrt(sum(mass_weight*delta*delta))
    bounded_norm = min(raw_norm, 2.0_real64*defect_norm)
    indicator_result%min_mass_weight = minval(mass_weight)
    indicator_result%raw_m_norm = raw_norm
    indicator_result%defect_m_norm = defect_norm
    indicator_result%bounded_m_norm = bounded_norm
    indicator_result%head_inf_bound = bounded_norm/sqrt(indicator_result%min_mass_weight)
    indicator_result%additional_full_nonlinear_solves = 0

    if (.not. ieee_is_finite(indicator_result%head_inf_bound) .or. indicator_result%head_inf_bound < 0.0_real64) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'nonfinite-indicator'
       return
    end if

    indicator_result%available = .true.
    indicator_result%status = SW_TEMPORAL_INDICATOR_AVAILABLE
    if (raw_norm <= 2.0_real64*defect_norm) then
       if (dynamic_flux_equivalent) then
          indicator_result%route = 'reference-dynamic-flux-raw-bound'
       else
          indicator_result%route = 'reference-richards-raw-bound'
       end if
    else
       if (dynamic_flux_equivalent) then
          indicator_result%route = 'reference-dynamic-flux-defect-bound'
       else
          indicator_result%route = 'reference-richards-defect-bound'
       end if
    end if
  end subroutine evaluate_reference_richards_temporal_indicator

  subroutine qualify_dynamic_flux_temporal_envelope(request, solve_result, qualified)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    logical, intent(out) :: qualified
    type(soil_water_top_boundary_result_t) :: base_result, mid_result, candidate_result
    real(real64) :: mid_head, mid_water, mid_ponding, flux_scale, state_scale, tol_flux, tol_state

    qualified = .false.
    if (.not. associated(request%evaluation%dynamic_top_boundary)) return
    if (.not. allocated(request%base_state%water_content)) return
    if (.not. allocated(solve_result%candidate_state%water_content)) return
    if (size(request%base_state%water_content) < 1 .or. size(solve_result%candidate_state%water_content) < 1) return

    select type (dynamic_provider => request%evaluation%dynamic_top_boundary)
    type is (b110_dynamic_top_boundary_solver_provider_t)
       call dynamic_provider%evaluate(request%base_state%pressure_head(1), request%base_state%water_content(1), &
            request%base_state%ponding_depth, request%boundary, base_result)
       mid_head = 0.5_real64*(request%base_state%pressure_head(1)+solve_result%candidate_state%pressure_head(1))
       mid_water = 0.5_real64*(request%base_state%water_content(1)+solve_result%candidate_state%water_content(1))
       mid_ponding = 0.5_real64*(request%base_state%ponding_depth+solve_result%candidate_state%ponding_depth)
       call dynamic_provider%evaluate(mid_head, mid_water, mid_ponding, request%boundary, mid_result)
       call dynamic_provider%evaluate(solve_result%candidate_state%pressure_head(1), &
            solve_result%candidate_state%water_content(1), solve_result%candidate_state%ponding_depth, &
            request%boundary, candidate_result)
    class default
       return
    end select

    if (base_result%status /= SW_TOP_BOUNDARY_AVAILABLE .or. &
        mid_result%status /= SW_TOP_BOUNDARY_AVAILABLE .or. &
        candidate_result%status /= SW_TOP_BOUNDARY_AVAILABLE) return
    if (base_result%regime /= SW_TOP_BOUNDARY_REGIME_FLUX .or. &
        mid_result%regime /= SW_TOP_BOUNDARY_REGIME_FLUX .or. &
        candidate_result%regime /= SW_TOP_BOUNDARY_REGIME_FLUX) return

    flux_scale = max(1.0_real64, abs(base_result%actual_top_flux), abs(mid_result%actual_top_flux), &
         abs(candidate_result%actual_top_flux), abs(solve_result%top_flux))
    tol_flux = 128.0_real64*epsilon(1.0_real64)*flux_scale
    if (abs(base_result%actual_top_flux-mid_result%actual_top_flux) > tol_flux) return
    if (abs(base_result%actual_top_flux-candidate_result%actual_top_flux) > tol_flux) return
    if (abs(base_result%actual_top_flux-solve_result%top_flux) > tol_flux) return

    state_scale = max(1.0_real64, abs(request%base_state%ponding_depth), &
         abs(solve_result%candidate_state%ponding_depth))
    tol_state = 128.0_real64*epsilon(1.0_real64)*state_scale
    if (abs(base_result%runoff_depth) > tol_state .or. abs(mid_result%runoff_depth) > tol_state .or. &
        abs(candidate_result%runoff_depth) > tol_state) return
    if (abs(base_result%candidate_ponding_depth) > tol_state .or. &
        abs(mid_result%candidate_ponding_depth) > tol_state .or. &
        abs(candidate_result%candidate_ponding_depth) > tol_state) return

    qualified = .true.
  end subroutine qualify_dynamic_flux_temporal_envelope

end module mod_reference_richards_temporal_indicator

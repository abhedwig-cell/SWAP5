module mod_reference_richards_phase_flux_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_workspace, only: reference_richards_workspace_t
  use mod_soil_water_phase_flux_view, only: soil_water_phase_flux_view_t, SW_FACE_FLUX_POSITIVE_UPWARD, &
       reset_soil_water_phase_flux_view, validate_soil_water_phase_flux_view
  implicit none
  private

  public :: build_reference_richards_phase_flux_view

contains

  subroutine build_reference_richards_phase_flux_view(request, solve_result, workspace, view, ok)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(reference_richards_workspace_t), intent(in) :: workspace
    type(soil_water_phase_flux_view_t), intent(out) :: view
    logical, intent(out) :: ok

    integer :: i, n
    real(real64) :: storage_rate

    call reset_soil_water_phase_flux_view(view)
    ok = .false.

    ! This binding is deliberately restricted to the explicit, single-domain
    ! reference Richards route.  Active macropores need their own phase/path
    ! accounting and must never be folded silently into a matrix-liquid flux.
    if (solve_result%status /= SW_SOLVE_CONVERGED) return
    if (.not. associated(request%parameters)) return
    if (.not. associated(request%evaluation%source_sink)) return
    if (request%physical%macropore_active) return
    if (request%step_duration <= 0.0_real64) return

    n = request%parameters%active_nodes
    if (n <= 0) return
    if (request%base_state%active_nodes /= n) return
    if (solve_result%candidate_state%active_nodes /= n) return
    if (workspace%active_nodes /= n) return

    if (.not. allocated(request%parameters%dz)) return
    if (.not. allocated(request%base_state%water_content)) return
    if (.not. allocated(solve_result%candidate_state%water_content)) return
    if (.not. allocated(workspace%sink)) return
    if (.not. allocated(workspace%source)) return
    if (.not. allocated(workspace%provider_root_sink)) return
    if (.not. allocated(workspace%residual)) return
    if (size(request%parameters%dz) /= n) return
    if (size(request%base_state%water_content) /= n) return
    if (size(solve_result%candidate_state%water_content) /= n) return
    if (size(workspace%sink) /= n) return
    if (size(workspace%source) /= n) return
    if (size(workspace%provider_root_sink) /= n) return
    if (size(workspace%residual) /= n) return

    if (.not. all(ieee_is_finite(request%parameters%dz))) return
    if (.not. all(ieee_is_finite(request%base_state%water_content))) return
    if (.not. all(ieee_is_finite(solve_result%candidate_state%water_content))) return
    if (.not. all(ieee_is_finite(workspace%sink))) return
    if (.not. all(ieee_is_finite(workspace%source))) return
    if (.not. all(ieee_is_finite(workspace%provider_root_sink))) return
    if (.not. all(ieee_is_finite(workspace%residual))) return
    if (.not. ieee_is_finite(solve_result%top_flux)) return
    if (.not. ieee_is_finite(solve_result%bottom_flux)) return

    allocate(view%liquid_face_flux_cm_day(n+1))
    allocate(view%liquid_face_transport_cm(n+1))
    allocate(view%continuity_residual_cm_day(n))

    ! Native SWAP/B1.10 face-flux sign is positive upward.  The final Newton
    ! residual for compartment i is
    !   r_i = storage_i + sink_i - source_i + root_i + q_i - q_(i+1).
    ! Replaying that exact algebra, including r_i rather than forcing it to
    ! zero, recovers the numerical face fluxes without hiding solver residuals.
    view%liquid_face_flux_cm_day(1) = solve_result%top_flux
    do i = 1, n
       storage_rate = request%parameters%dz(i) * &
            (solve_result%candidate_state%water_content(i) - request%base_state%water_content(i)) / &
            request%step_duration
       view%liquid_face_flux_cm_day(i+1) = view%liquid_face_flux_cm_day(i) + storage_rate + &
            workspace%sink(i) - workspace%source(i) + workspace%provider_root_sink(i) - workspace%residual(i)
    end do

    ! The reference Richards residual is a backward-Euler interval equation.
    ! q*dt is therefore the discrete interval-equivalent liquid transport used
    ! by that accepted candidate equation.  It is not advertised as a higher-
    ! order reconstruction of the continuous-time flux trajectory.
    view%liquid_face_transport_cm = view%liquid_face_flux_cm_day * request%step_duration
    view%continuity_residual_cm_day = workspace%residual
    view%active_nodes = n
    view%face_count = n + 1
    view%sign_convention = SW_FACE_FLUX_POSITIVE_UPWARD
    view%candidate_interval = .true.
    view%liquid_flux_available = .true.
    view%liquid_transport_available = .true.
    view%continuity_residual_available = .true.
    view%vapor_phase_modelled = .false.
    view%vapor_flux_available = .false.
    view%vapor_transport_available = .false.
    view%full_physical_phase_coverage = .false.
    view%step_duration_day = request%step_duration
    view%bottom_flux_consistency_residual_cm_day = view%liquid_face_flux_cm_day(n+1) - solve_result%bottom_flux
    view%mass_balance_residual_cm_day = sum(workspace%residual)
    view%route = 'reference-richards-residual-replay'

    if (.not. ieee_is_finite(view%bottom_flux_consistency_residual_cm_day)) then
       call reset_soil_water_phase_flux_view(view)
       return
    end if
    if (.not. ieee_is_finite(view%mass_balance_residual_cm_day)) then
       call reset_soil_water_phase_flux_view(view)
       return
    end if
    if (.not. all(ieee_is_finite(view%liquid_face_flux_cm_day))) then
       call reset_soil_water_phase_flux_view(view)
       return
    end if
    if (.not. all(ieee_is_finite(view%liquid_face_transport_cm))) then
       call reset_soil_water_phase_flux_view(view)
       return
    end if

    call validate_soil_water_phase_flux_view(view, ok)
  end subroutine build_reference_richards_phase_flux_view

end module mod_reference_richards_phase_flux_binding

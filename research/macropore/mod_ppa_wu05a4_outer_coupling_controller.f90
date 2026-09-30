module mod_ppa_wu05a4_outer_coupling_controller
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_physical_state_t, &
       SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a4_fixed_exchange_provider, only: ppa_wu05a4_fixed_exchange_provider_t
  use mod_ppa_wu05a4_r2_macropore_process, only: ppa_wu05a4_r2_process_t
  implicit none
  private

  integer, parameter, public :: PPA_COUPLED_NOT_RUN = 0
  integer, parameter, public :: PPA_COUPLED_CONVERGED = 1
  integer, parameter, public :: PPA_COUPLED_PRACTICAL_CAP = 2
  integer, parameter, public :: PPA_COUPLED_RETRY = 3
  integer, parameter, public :: PPA_COUPLED_FAILED = 4

  type, public :: ppa_wu05a4_coupling_policy_t
    integer :: max_correctors = 0
    real(real64) :: exchange_relative_tolerance = 0.0_real64
    real(real64) :: exchange_floor = 1.0e-12_real64
    real(real64) :: damping_previous_weight = 0.5_real64
    logical :: allow_practical_cap = .false.
    real(real64) :: combined_mass_tolerance_cm = 1.0e-10_real64
  contains
    procedure, public :: valid => coupling_policy_valid
  end type ppa_wu05a4_coupling_policy_t

  type, public :: ppa_wu05a4_coupled_result_t
    integer :: status = PPA_COUPLED_NOT_RUN
    logical :: retry_advised = .false.
    logical :: outer_converged = .false.
    logical :: practical_cap_used = .false.
    integer :: predictor_solves = 0
    integer :: corrector_solves = 0
    integer :: outer_iterations = 0
    real(real64) :: final_relative_exchange_change = huge(1.0_real64)
    real(real64) :: top_flux = 0.0_real64
    real(real64) :: bottom_flux = 0.0_real64
    real(real64) :: combined_mass_residual_cm = huge(1.0_real64)
    real(real64) :: macropore_external_outflow_cm = 0.0_real64
    real(real64), allocatable :: exchange_rate(:)
    type(soil_water_physical_state_t) :: matrix_candidate
    type(macropore_continuation_state_t) :: macropore_candidate
  end type ppa_wu05a4_coupled_result_t

  type, public :: ppa_wu05a4_outer_coupling_controller_t
  contains
    procedure, public :: execute => outer_coupling_execute
  end type ppa_wu05a4_outer_coupling_controller_t

contains

  pure logical function coupling_policy_valid(self) result(ok)
    class(ppa_wu05a4_coupling_policy_t), intent(in) :: self
    ok = self%max_correctors > 0 .and. self%exchange_relative_tolerance > 0.0_real64 .and. &
         self%exchange_floor > 0.0_real64 .and. self%damping_previous_weight >= 0.0_real64 .and. &
         self%damping_previous_weight < 1.0_real64 .and. self%combined_mass_tolerance_cm > 0.0_real64
  end function coupling_policy_valid

  subroutine outer_coupling_execute(self, solver, workspace, base_request, accepted_macro, process, policy, result)
    class(ppa_wu05a4_outer_coupling_controller_t), intent(inout) :: self
    class(soil_water_solver_t), intent(inout) :: solver
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_request_t), intent(in) :: base_request
    type(macropore_continuation_state_t), intent(in) :: accepted_macro
    type(ppa_wu05a4_r2_process_t), intent(in) :: process
    type(ppa_wu05a4_coupling_policy_t), intent(in) :: policy
    type(ppa_wu05a4_coupled_result_t), intent(out) :: result

    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: predictor, corrector
    type(ppa_wu05a4_fixed_exchange_provider_t), target :: exchange_provider
    real(real64), allocatable :: current_exchange(:), raw_next(:), next_exchange(:)
    real(real64) :: numerator, denominator, matrix_delta, macro_delta, boundary_amount, external_outflow
    logical :: ok
    integer :: n, iter

    result = ppa_wu05a4_coupled_result_t()
    if (.not. policy%valid()) then
      result%status = PPA_COUPLED_FAILED
      return
    end if
    if (.not. associated(base_request%parameters)) then
      result%status = PPA_COUPLED_FAILED
      return
    end if
    n = base_request%parameters%active_nodes
    if (n <= 0 .or. base_request%base_state%active_nodes /= n) then
      result%status = PPA_COUPLED_FAILED
      return
    end if
    if (.not. process%ready(base_request%base_state, accepted_macro)) then
      result%status = PPA_COUPLED_FAILED
      return
    end if

    allocate(current_exchange(n), raw_next(n), next_exchange(n))
    allocate(exchange_provider%source_rate(n), exchange_provider%sink_rate(n))
    exchange_provider%source_rate = 0.0_real64
    exchange_provider%sink_rate = 0.0_real64

    request = base_request
    request%evaluation%source_sink => exchange_provider

    ! Predictor from the accepted matrix state with no tentative macropore exchange.
    call solver%solve(request, workspace, predictor)
    result%predictor_solves = 1
    if (predictor%status /= SW_SOLVE_CONVERGED) then
      result%retry_advised = predictor%retry_advised .or. predictor%status == SW_SOLVE_RETRY_ADVISED
      result%status = merge(PPA_COUPLED_RETRY, PPA_COUPLED_FAILED, result%retry_advised)
      return
    end if

    call process%evaluate_exchange(predictor%candidate_state, accepted_macro, request%step_duration, current_exchange, ok)
    if (.not. ok) then
      result%status = PPA_COUPLED_FAILED
      return
    end if

    do iter = 1, policy%max_correctors
      exchange_provider%source_rate = max(current_exchange, 0.0_real64)
      exchange_provider%sink_rate = max(-current_exchange, 0.0_real64)

      ! Every corrector is solved from the same accepted matrix base state.
      request%base_state = base_request%base_state
      call solver%solve(request, workspace, corrector)
      result%corrector_solves = result%corrector_solves + 1
      result%outer_iterations = iter

      if (corrector%status /= SW_SOLVE_CONVERGED) then
        result%retry_advised = corrector%retry_advised .or. corrector%status == SW_SOLVE_RETRY_ADVISED
        result%status = merge(PPA_COUPLED_RETRY, PPA_COUPLED_FAILED, result%retry_advised)
        return
      end if

      call process%evaluate_exchange(corrector%candidate_state, accepted_macro, request%step_duration, raw_next, ok)
      if (.not. ok) then
        result%status = PPA_COUPLED_FAILED
        return
      end if

      next_exchange = policy%damping_previous_weight*current_exchange + &
           (1.0_real64-policy%damping_previous_weight)*raw_next

      numerator = maxval(abs(next_exchange-current_exchange))
      denominator = max(maxval(abs(current_exchange)), policy%exchange_floor)
      result%final_relative_exchange_change = numerator/denominator

      if (result%final_relative_exchange_change <= policy%exchange_relative_tolerance) then
        result%outer_converged = .true.
        exit
      end if

      if (iter < policy%max_correctors) current_exchange = next_exchange
    end do

    if (.not. result%outer_converged) then
      if (.not. policy%allow_practical_cap) then
        result%status = PPA_COUPLED_FAILED
        return
      end if
      result%practical_cap_used = .true.
    end if

    call process%build_candidate(base_request%base_state, corrector%candidate_state, accepted_macro, &
         request%step_duration, current_exchange, result%macropore_candidate, external_outflow, ok)
    if (.not. ok) then
      result%status = PPA_COUPLED_FAILED
      return
    end if

    result%matrix_candidate = corrector%candidate_state
    allocate(result%exchange_rate(n))
    result%exchange_rate = current_exchange
    result%top_flux = corrector%top_flux
    result%bottom_flux = corrector%bottom_flux
    result%macropore_external_outflow_cm = external_outflow

    matrix_delta = sum((result%matrix_candidate%water_content-base_request%base_state%water_content) * &
         base_request%parameters%dz)
    macro_delta = sum(result%macropore_candidate%water_domain_cp-accepted_macro%water_domain_cp)
    boundary_amount = (result%bottom_flux-result%top_flux)*request%step_duration
    result%combined_mass_residual_cm = matrix_delta + macro_delta + external_outflow - boundary_amount

    if (abs(result%combined_mass_residual_cm) > policy%combined_mass_tolerance_cm) then
      result%status = PPA_COUPLED_FAILED
      return
    end if

    if (result%outer_converged) then
      result%status = PPA_COUPLED_CONVERGED
    else
      result%status = PPA_COUPLED_PRACTICAL_CAP
    end if

    if (.not. same_type_as(self,self)) result%status = PPA_COUPLED_FAILED
  end subroutine outer_coupling_execute

end module mod_ppa_wu05a4_outer_coupling_controller

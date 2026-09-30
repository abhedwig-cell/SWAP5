program test_ppa_wu05a4_outer_controller
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, source_sink_provider_t, &
       SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a4_r2_macropore_process, only: ppa_wu05a4_r2_process_t
  use mod_ppa_wu05a4_outer_coupling_controller, only: ppa_wu05a4_outer_coupling_controller_t, &
       ppa_wu05a4_coupling_policy_t, ppa_wu05a4_coupled_result_t, &
       PPA_COUPLED_CONVERGED, PPA_COUPLED_PRACTICAL_CAP, PPA_COUPLED_RETRY
  implicit none

  type, extends(soil_water_solver_workspace_base_t) :: mock_workspace_t
  end type mock_workspace_t

  type, extends(soil_water_solver_t) :: mock_solver_t
    integer :: call_count = 0
    real(real64) :: retry_above_source = huge(1.0_real64)
  contains
    procedure :: solve => mock_solve
  end type mock_solver_t

  type(ppa_wu05a4_outer_coupling_controller_t) :: controller
  type(ppa_wu05a4_r2_process_t) :: process
  type(ppa_wu05a4_coupling_policy_t) :: strict_policy, practical_policy
  type(ppa_wu05a4_coupled_result_t) :: result
  type(mock_solver_t) :: solver
  type(mock_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(macropore_continuation_state_t) :: accepted_macro, accepted_snapshot
  logical :: ok
  integer :: n

  n = 3
  allocate(request%parameters)
  request%parameters%active_nodes = n
  allocate(request%parameters%z(n), request%parameters%dz(n), request%parameters%node_distance(n))
  request%parameters%z = [-5.0_real64,-15.0_real64,-25.0_real64]
  request%parameters%dz = 10.0_real64
  request%parameters%node_distance = 10.0_real64
  request%base_state%active_nodes = n
  allocate(request%base_state%pressure_head(n), request%base_state%water_content(n))
  request%base_state%pressure_head = -100.0_real64
  request%base_state%water_content = [0.16_real64,0.16_real64,0.16_real64]
  request%step_duration = 0.01_real64

  call accepted_macro%initialize(1,n,ok)
  call expect(ok,'macro initialize')
  accepted_macro%icp_bottom_domain = 3
  accepted_macro%volume_domain_cp = 1.0_real64
  accepted_macro%water_domain_cp = 0.0_real64
  accepted_macro%water_domain_cp(1,2) = 0.5_real64
  accepted_macro%dynamic_volume_cp = 0.0_real64
  accepted_snapshot = accepted_macro

  process%domain_index = 1
  process%node_index = 2
  process%sorptivity_max = 0.5_real64

  strict_policy%max_correctors = 40
  strict_policy%exchange_relative_tolerance = 1.0e-8_real64
  strict_policy%damping_previous_weight = 0.5_real64
  strict_policy%allow_practical_cap = .false.
  strict_policy%combined_mass_tolerance_cm = 1.0e-10_real64

  practical_policy = strict_policy
  practical_policy%max_correctors = 1
  practical_policy%exchange_relative_tolerance = 1.0e-14_real64
  practical_policy%allow_practical_cap = .true.

  ! Strict route must converge and must not mutate accepted macro state.
  solver%call_count = 0
  solver%retry_above_source = huge(1.0_real64)
  call controller%execute(solver,workspace,request,accepted_macro,process,strict_policy,result)
  call expect(result%status == PPA_COUPLED_CONVERGED,'strict converged')
  call expect(result%outer_converged,'strict convergence flag')
  call expect(abs(result%combined_mass_residual_cm) < 1.0e-10_real64,'strict combined mass')
  call expect(accepted_macro%same_values(accepted_snapshot),'accepted macro isolated')
  call expect(result%macropore_candidate%water_domain_cp(1,2) < accepted_macro%water_domain_cp(1,2), &
       'macro candidate loses exchange water')
  call expect(result%matrix_candidate%water_content(2) > request%base_state%water_content(2), &
       'matrix candidate gains exchange water')

  ! Practical cap is a distinct, explicit result rather than fake convergence.
  solver%call_count = 0
  call controller%execute(solver,workspace,request,accepted_macro,process,practical_policy,result)
  call expect(result%status == PPA_COUPLED_PRACTICAL_CAP,'practical cap status')
  call expect(result%practical_cap_used,'practical cap flag')
  call expect(.not. result%outer_converged,'practical not falsely converged')
  call expect(abs(result%combined_mass_residual_cm) < 1.0e-10_real64,'practical combined mass')

  ! Retry from the Richards corrector propagates outward and returns no accepted candidate.
  solver%call_count = 0
  solver%retry_above_source = 1.0e-6_real64
  call controller%execute(solver,workspace,request,accepted_macro,process,strict_policy,result)
  call expect(result%status == PPA_COUPLED_RETRY,'retry propagated')
  call expect(result%retry_advised,'retry flag')
  call expect(accepted_macro%same_values(accepted_snapshot),'retry accepted macro isolated')

  print '(a)', 'PPA_WU05A4_OUTER_CONTROLLER=PASS'

contains

  subroutine mock_solve(self, request, workspace, result)
    class(mock_solver_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_result_t), intent(out) :: result

    real(real64), allocatable :: source(:), sink(:)
    real(real64) :: max_source
    integer :: m

    m = request%base_state%active_nodes
    result = soil_water_solve_result_t()
    self%call_count = self%call_count + 1

    allocate(source(m), sink(m))
    source = 0.0_real64
    sink = 0.0_real64
    if (associated(request%evaluation%source_sink)) then
      call request%evaluation%source_sink%evaluate(request%base_state%pressure_head, &
           request%base_state%water_content, source, sink)
    end if

    max_source = maxval(source)
    if (self%call_count > 1 .and. max_source > self%retry_above_source) then
      result%status = SW_SOLVE_RETRY_ADVISED
      result%retry_advised = .true.
      return
    end if

    result%status = SW_SOLVE_CONVERGED
    result%candidate_state = request%base_state
    result%candidate_state%water_content = request%base_state%water_content + &
         (source-sink)*request%step_duration/request%parameters%dz
    result%top_flux = 0.0_real64
    result%bottom_flux = 0.0_real64
    result%integrated_mass_balance_residual_available = .true.
    result%integrated_mass_balance_residual_cm = 0.0_real64

    if (.not. same_type_as(workspace,workspace)) error stop 'unreachable workspace type'
  end subroutine mock_solve

  subroutine expect(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU05A4_CONTROLLER_ASSERT_FAIL',trim(label)
      error stop 74
    end if
  end subroutine expect

end program test_ppa_wu05a4_outer_controller

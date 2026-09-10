program test_fsi27_explicit_prescribed_qbot
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use variables, only: legacy_qbot => qbot, legacy_hbot => hbot, legacy_swbotb => swbotb, legacy_qtop => qtop
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_FAILED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: total_dt = 0.25_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: h0 = -75.0_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace_a, workspace_b, workspace_c, workspace_bad
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result_a, result_b, result_c, result_bad
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: k0, qeq, qpert, mass_a, mass_b, mass_c, response, solver_mass_max
  logical :: solver_mass_finite

  call configure_problem(parameters, hydraulic_parameters, constitutive, source_sink, initial_state, &
       drainage, subsurface, root_sink, cofgen, k0)

  qeq = -k0
  qpert = 0.99_real64*qeq
  call configure_request(request, parameters, constitutive, source_sink, top_provider, initial_state, qeq, qeq)

  ! A: exact homogeneous gravity-flow equilibrium. Poison every matching legacy
  ! global so the production result can only come from the explicit request.
  legacy_swbotb = 99
  legacy_qbot = 98765.4321_real64
  legacy_hbot = -87654.321_real64
  legacy_qtop = 76543.21_real64
  request%boundary%bottom_head = -999999.0_real64
  call solver%solve(request, workspace_a, result_a)
  call require(result_a%status == SW_SOLVE_CONVERGED, 'equilibrium solve converged')
  call require(same_bits(result_a%bottom_flux, qeq), 'equilibrium result qbot equals requested qbot bitwise')
  call require(same_bits(result_a%top_flux, qeq), 'equilibrium result qtop equals requested qtop bitwise')
  call require_state_unchanged(request%base_state, initial_state, 'request base state unchanged after A')
  call require(all(ieee_is_finite(result_a%candidate_state%pressure_head)), 'equilibrium finite heads')
  call require(all(ieee_is_finite(result_a%candidate_state%water_content)), 'equilibrium finite water')
  mass_a = external_mass_residual(initial_state, result_a, parameters)
  call require(abs(mass_a) <= hard_mass_gate, 'equilibrium hard external mass gate')

  ! B: same physical request, radically different inactive bottom-head field and
  ! different poisoned legacy globals. Mode 2 must be invariant to both.
  legacy_swbotb = -1234
  legacy_qbot = -24680.1357_real64
  legacy_hbot = 13579.2468_real64
  legacy_qtop = -97531.8642_real64
  request%boundary%bottom_head = 999999.0_real64
  call solver%solve(request, workspace_b, result_b)
  call require(result_b%status == SW_SOLVE_CONVERGED, 'metamorphic solve converged')
  call require(same_bits(result_b%bottom_flux, qeq), 'metamorphic result qbot equals requested qbot bitwise')
  call require_state_unchanged(request%base_state, initial_state, 'request base state unchanged after B')
  call require_states_bitwise_equal(result_a%candidate_state, result_b%candidate_state, &
       'bottom-head and legacy-global poison independence')
  call require(same_bits(result_a%top_flux, result_b%top_flux), 'metamorphic qtop identity')
  call require(same_bits(result_a%bottom_flux, result_b%bottom_flux), 'metamorphic qbot identity')
  mass_b = external_mass_residual(initial_state, result_b, parameters)
  call require(abs(mass_b) <= hard_mass_gate, 'metamorphic hard external mass gate')

  ! C: a small true qbot perturbation with the same top forcing. This must move
  ! the column, proving mode 2 is not merely admitted administratively.
  request%boundary%bottom_flux = qpert
  request%boundary%bottom_head = -123456.0_real64
  legacy_swbotb = 5
  legacy_qbot = 11111.0_real64
  legacy_hbot = 22222.0_real64
  call solver%solve(request, workspace_c, result_c)
  call require(result_c%status == SW_SOLVE_CONVERGED, 'perturbed qbot solve converged')
  call require(same_bits(result_c%bottom_flux, qpert), 'perturbed result qbot equals requested qbot bitwise')
  call require_state_unchanged(request%base_state, initial_state, 'request base state unchanged after C')
  response = maxval(abs(result_c%candidate_state%pressure_head-result_a%candidate_state%pressure_head))
  call require(ieee_is_finite(response) .and. response > 1024.0_real64*epsilon(1.0_real64), &
       'qbot perturbation changes physical column state')
  mass_c = external_mass_residual(initial_state, result_c, parameters)
  call require(abs(mass_c) <= hard_mass_gate, 'perturbed hard external mass gate')

  ! D: nearby unowned mode remains fail closed. F-SI27 must not widen the
  ! general bottom-boundary admission surface.
  request%boundary%bottom_mode = 6
  call solver%solve(request, workspace_bad, result_bad)
  call require(result_bad%status == SW_SOLVE_FAILED, 'unowned bottom mode fails closed')
  call require(trim(result_bad%diagnostics%route) == 'legacy-bottom-mode-deferred', 'fail-closed route identity')

  solver_mass_finite = ieee_is_finite(result_a%unrounded_mass_balance_residual) .and. &
       ieee_is_finite(result_b%unrounded_mass_balance_residual) .and. &
       ieee_is_finite(result_c%unrounded_mass_balance_residual)
  call require(solver_mass_finite, 'accepted mode 2 solver mass diagnostics finite')
  solver_mass_max = max(abs(result_a%unrounded_mass_balance_residual), &
       abs(result_b%unrounded_mass_balance_residual), abs(result_c%unrounded_mass_balance_residual))
  call require(solver_mass_max <= hard_mass_gate, 'accepted mode 2 solver mass diagnostics within hard gate')

  write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
       'FSI27_ROW:QEQ=',qeq,':QPERT=',qpert,':RESPONSE=',response,':MAX_EXTERNAL_MASS=', &
       max(abs(mass_a),abs(mass_b),abs(mass_c))
  write(*,'(A,L1,A,ES26.17E3)') 'FSI27_SOLVER_MASS_RESIDUAL_FINITE=',solver_mass_finite, &
       ':MAX_SOLVER_MASS=',solver_mass_max
  write(*,'(A)') 'FSI27_EXPLICIT_PRESCRIBED_QBOT_GATE PASS'

contains

  subroutine configure_problem(p, hp, cp, sp, state, qdra, qssdi, qrot, c, conductivity0)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: conductivity0
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 270027_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)

    allocate(c(24,numnod))
    c = 0.0_real64
    do k = 1, numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,total_dt)
    heads = h0
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(conductivity)) .and. all(conductivity>0.0_real64), 'initial K finite positive')
    do k = 2, numnod
      call require(same_bits(conductivity(k),conductivity(1)), 'uniform initial conductivity')
    end do
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    allocate(qdra(1,numnod), qssdi(numnod), qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem

  subroutine configure_request(r, p, cp, sp, tp, state, top_flux, bottom_flux)
    type(soil_water_solve_request_t), intent(out) :: r
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_provider_t), target, intent(in) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fixed_flux_top_boundary_provider_t), target, intent(in) :: tp
    type(soil_water_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: top_flux, bottom_flux

    r = soil_water_solve_request_t()
    r%parameters => p
    r%base_state = state
    r%step_duration = total_dt
    r%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    r%boundary%bottom_mode = 2
    r%boundary%top_flux = top_flux
    r%boundary%bottom_flux = bottom_flux
    r%boundary%top_head = h0
    r%boundary%bottom_head = 0.0_real64
    r%physical%macropore_active = .false.
    r%numerical%max_iterations = 8
    r%numerical%max_backtracking = 4
    r%numerical%conductivity_implicit_mode = 0
    r%numerical%conductivity_mean_method = 1
    r%numerical%min_step_duration = 1.0e-6_real64
    r%numerical%compartment_balance_tolerance = hard_mass_gate
    r%numerical%total_balance_tolerance = hard_mass_gate
    r%numerical%head_abs_tolerance = 1.0e-12_real64
    r%numerical%head_rel_tolerance = 1.0e-12_real64
    r%numerical%ponding_tolerance = 1.0e-12_real64
    r%evaluation%constitutive => cp
    r%evaluation%source_sink => sp
    r%evaluation%top_boundary => tp
  end subroutine configure_request

  real(real64) function external_mass_residual(state0, result, p) result(value)
    type(soil_water_physical_state_t), intent(in) :: state0
    type(soil_water_solve_result_t), intent(in) :: result
    type(soil_water_parameter_set_t), intent(in) :: p
    real(real64) :: storage0, storage1, total_in, total_out
    storage0 = sum(state0%water_content*p%dz) + state0%ponding_depth
    storage1 = sum(result%candidate_state%water_content*p%dz) + result%candidate_state%ponding_depth
    total_in = max(0.0_real64,-result%top_flux)*total_dt + max(0.0_real64,result%bottom_flux)*total_dt
    total_out = max(0.0_real64,result%top_flux)*total_dt + max(0.0_real64,-result%bottom_flux)*total_dt
    value = storage1-storage0-(total_in-total_out)
  end function external_mass_residual

  subroutine require_state_unchanged(actual, expected, label)
    type(soil_water_physical_state_t), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    call require(actual%active_nodes == expected%active_nodes, label//' active_nodes')
    call require(vector_same_bits(actual%pressure_head,expected%pressure_head), label//' heads')
    call require(vector_same_bits(actual%water_content,expected%water_content), label//' water')
    call require(same_bits(actual%ponding_depth,expected%ponding_depth), label//' pond')
    call require(same_bits(actual%groundwater_level,expected%groundwater_level), label//' gwl')
  end subroutine require_state_unchanged

  subroutine require_states_bitwise_equal(a, b, label)
    type(soil_water_physical_state_t), intent(in) :: a, b
    character(len=*), intent(in) :: label
    call require(a%active_nodes == b%active_nodes, label//' active_nodes')
    call require(vector_same_bits(a%pressure_head,b%pressure_head), label//' heads')
    call require(vector_same_bits(a%water_content,b%water_content), label//' water')
    call require(same_bits(a%ponding_depth,b%ponding_depth), label//' pond')
    call require(same_bits(a%groundwater_level,b%groundwater_level), label//' gwl')
  end subroutine require_states_bitwise_equal

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  pure logical function vector_same_bits(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    vector_same_bits = size(a)==size(b)
    if (.not.vector_same_bits) return
    do i=1,size(a)
      if (.not.same_bits(a(i),b(i))) then
        vector_same_bits=.false.
        return
      end if
    end do
  end function vector_same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FSI27_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi27_explicit_prescribed_qbot

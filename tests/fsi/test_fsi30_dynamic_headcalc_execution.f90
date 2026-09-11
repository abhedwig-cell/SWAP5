program test_fsi30_dynamic_headcalc_execution
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64, error_unit
  use MOD_grid, only: numnod, z, dz, disnod
  use variables, only: legacy_qtop => qtop, legacy_qbot => qbot, legacy_hbot => hbot, &
       legacy_swbotb => swbotb, legacy_runon => runon, legacy_epd => epd, legacy_reva => reva
  use MOD_meteo, only: legacy_nraidt => nraidt
  use MOD_irrigation, only: legacy_nird => nird
  use MOD_snow, only: legacy_melt => melt
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_FAILED, &
       SW_TOP_BOUNDARY_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX, FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_b110_dynamic_top_boundary_provider, only: B110_DYN_TOP_ATMOSPHERIC_HEAD_CM
  implicit none

  real(real64), parameter :: total_dt = 0.125_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: fixed_top
  type(reference_richards_legacy_solver_t) :: solver
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: raw(:,:)
  real(real64) :: k_flux, k_atm, k_sat, ponded_head, runoff_head

  call configure_shared_problem(parameters, hydraulic_parameters, constitutive, source_sink, &
       drainage, subsurface, root_sink, raw)
  k_flux = node_conductivity(-75.0_real64)
  k_atm = node_conductivity(B110_DYN_TOP_ATMOSPHERIC_HEAD_CM)
  k_sat = node_conductivity(1.0_real64)
  call require(k_flux > 0.0_real64 .and. k_atm > 0.0_real64 .and. k_sat > 0.0_real64, &
       'positive conductivities for frozen execution cases')

  ! Case A: exact dynamic FLUX gravity equilibrium. F-SI28 sensitivity is also
  ! exercised here because qtop is state-independent inside the smooth flux regime.
  call run_dynamic_case('flux', -75.0_real64, 0.0_real64, &
       k_flux, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 10.0_real64, 0.5_real64, 1.0_real64, &
       'surface-flux', .true.)

  ! Case B: atmospheric-head branch at its own fixed head. With no external
  ! demand/supply, q1=0 while Emax=-K_atm<0, so the strict atmospheric switch
  ! is active. The only surface-balance remainder is K_atm*dt and must remain
  ! below the pre-existing hard mass gate.
  call run_dynamic_case('atmospheric', B110_DYN_TOP_ATMOSPHERIC_HEAD_CM, 0.0_real64, &
       0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 10.0_real64, 0.5_real64, 1.0_real64, &
       'atmospheric-head', .false.)

  ! Case C: saturated ponded-head equilibrium. For zero surface forcing and
  ! unit top distance, H = P_previous - Ksat*dt makes the F-SI29 pond equation
  ! and the Richards gravity flux agree exactly.
  ponded_head = 2.0_real64 - k_sat*total_dt
  call require(ponded_head > 0.0_real64, 'ponded-head frozen start remains saturated')
  call run_dynamic_case('ponded', ponded_head, 2.0_real64, &
       0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 10.0_real64, 0.5_real64, 1.0_real64, &
       'ponded-head', .false.)

  ! Case D: exact linear-runoff ponded-head equilibrium. The closed form below
  ! is the F-SI29 restricted linear runoff equation after imposing steady soil
  ! gravity flow (qtop=qbot=-Ksat).
  runoff_head = (3.0_real64 - k_sat*total_dt + &
       (total_dt/0.5_real64)*0.1_real64)/(1.0_real64 + total_dt/0.5_real64)
  call require(runoff_head > 0.1_real64, 'linear-runoff frozen start exceeds ponding threshold')
  call run_dynamic_case('linear-runoff', runoff_head, 3.0_real64, &
       0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 0.1_real64, 0.5_real64, 1.0_real64, &
       'ponded-head-linear-runoff', .false.)

  call run_fixed_flux_regression(-75.0_real64, -k_flux)
  call run_dynamic_missing_provider_failclosed(-75.0_real64, -k_flux)

  write(*,'(A)') 'FSI30_REAL_SOLVER_DYNAMIC_FLUX=PASS'
  write(*,'(A)') 'FSI30_REAL_SOLVER_ATMOSPHERIC_HEAD=PASS'
  write(*,'(A)') 'FSI30_REAL_SOLVER_PONDED_HEAD=PASS'
  write(*,'(A)') 'FSI30_REAL_SOLVER_LINEAR_RUNOFF=PASS'
  write(*,'(A)') 'FSI30_REAL_SOLVER_HARD_MASS_CLOSURE=PASS'
  write(*,'(A)') 'FSI30_FSI28_TANGENT_PRESERVATION=PASS'
  write(*,'(A)') 'FSI30_FIXED_FLUX_REGRESSION=PASS'
  write(*,'(A)') 'FSI30_DYNAMIC_MISSING_PROVIDER_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FSI30_DYNAMIC_HEADCALC_EXECUTION_GATE=PASS'

contains

  subroutine configure_shared_problem(p, hp, cp, sp, qdra, qssdi, qrot, c)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    integer :: k

    p%parameter_set_id = 300030_int64
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
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k); c(9,k)=0.0_real64
      c(10,k)=c(3,k); c(11,k)=0.999_real64; c(12,k)=0.99_real64*c(3,k)
      c(13,k)=0.10_real64; c(14,k)=1.50_real64; c(15,k)=0.50_real64
      c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,total_dt)

    allocate(qdra(1,numnod), qssdi(numnod), qrot(numnod))
    qdra = 0.0_real64; qssdi = 0.0_real64; qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_shared_problem

  real(real64) function node_conductivity(head_value) result(kvalue)
    real(real64), intent(in) :: head_value
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    heads = head_value
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(conductivity)), 'finite conductivity probe')
    kvalue = conductivity(1)
  end function node_conductivity

  subroutine make_state(head_value, pond_value, state)
    real(real64), intent(in) :: head_value, pond_value
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    heads = head_value
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = pond_value
    state%groundwater_level = -2.0_real64
  end subroutine make_state

  subroutine bind_dynamic(provider, pond_previous, precip, irrigation, snowmelt, runon_rate, &
       bare_evap, pond_evap, pondmax, rsro, exponent)
    type(b110_dynamic_top_boundary_solver_provider_t), target, intent(out) :: provider
    real(real64), intent(in) :: pond_previous, precip, irrigation, snowmelt, runon_rate
    real(real64), intent(in) :: bare_evap, pond_evap, pondmax, rsro, exponent
    call bind_b110_dynamic_top_boundary_solver_provider(provider, parameters, hydraulic_parameters, &
         1, pond_previous, total_dt, precip, irrigation, snowmelt, runon_rate, bare_evap, pond_evap, &
         pondmax, rsro, exponent)
  end subroutine bind_dynamic

  subroutine configure_dynamic_request(r, state, provider, bottom_flux)
    type(soil_water_solve_request_t), intent(out) :: r
    type(soil_water_physical_state_t), intent(in) :: state
    type(b110_dynamic_top_boundary_solver_provider_t), target, intent(in) :: provider
    real(real64), intent(in) :: bottom_flux
    r = soil_water_solve_request_t()
    r%parameters => parameters
    r%base_state = state
    r%step_duration = total_dt
    r%boundary%top_mode = FSI_TOP_MODE_DYNAMIC_PROVIDER
    r%boundary%bottom_mode = 2
    r%boundary%top_flux = 98765.4321_real64
    r%boundary%top_head = -98765.4321_real64
    r%boundary%bottom_flux = bottom_flux
    r%boundary%bottom_head = 87654.321_real64
    r%physical%macropore_active = .false.
    r%numerical%max_iterations = 12
    r%numerical%max_backtracking = 6
    r%numerical%conductivity_implicit_mode = 0
    r%numerical%conductivity_mean_method = 1
    r%numerical%min_step_duration = 1.0e-6_real64
    r%numerical%compartment_balance_tolerance = hard_mass_gate
    r%numerical%total_balance_tolerance = hard_mass_gate
    r%numerical%head_abs_tolerance = 1.0e-12_real64
    r%numerical%head_rel_tolerance = 1.0e-12_real64
    r%numerical%ponding_tolerance = hard_mass_gate
    r%evaluation%constitutive => constitutive
    r%evaluation%source_sink => source_sink
    r%evaluation%dynamic_top_boundary => provider
  end subroutine configure_dynamic_request

  subroutine run_dynamic_case(label, head_value, pond_previous, precip, irrigation, snowmelt, runon_rate, &
       bare_evap, pond_evap, pondmax, rsro, exponent, expected_route, sensitivity_pair)
    character(len=*), intent(in) :: label, expected_route
    real(real64), intent(in) :: head_value, pond_previous, precip, irrigation, snowmelt, runon_rate
    real(real64), intent(in) :: bare_evap, pond_evap, pondmax, rsro, exponent
    logical, intent(in) :: sensitivity_pair
    type(soil_water_physical_state_t) :: state
    type(b110_dynamic_top_boundary_solver_provider_t), target :: provider
    type(soil_water_boundary_conditions_t) :: probe_boundary
    type(soil_water_top_boundary_result_t) :: probe, final_probe
    type(soil_water_solve_request_t) :: request, request_on
    type(soil_water_solve_result_t) :: result, result_on
    type(reference_richards_legacy_workspace_t) :: workspace, workspace_on
    real(real64) :: surface_before, surface_after, total_mass

    call make_state(head_value,pond_previous,state)
    call bind_dynamic(provider,pond_previous,precip,irrigation,snowmelt,runon_rate,bare_evap,pond_evap,pondmax,rsro,exponent)
    probe_boundary = soil_water_boundary_conditions_t()
    call provider%evaluate(state%pressure_head(1),state%water_content(1),state%ponding_depth,probe_boundary,probe)
    call require(probe%status == SW_TOP_BOUNDARY_AVAILABLE, label//' initial generic provider available')
    call require(trim(probe%route) == expected_route, label//' initial route')
    surface_before = surface_mass_residual(pond_previous,probe)
    call require(abs(surface_before) <= hard_mass_gate, label//' initial surface mass gate')

    call configure_dynamic_request(request,state,provider,probe%actual_top_flux)
    call poison_legacy_top_context()
    call solver%solve(request,workspace,result)
    call require(result%status == SW_SOLVE_CONVERGED, label//' real solver converged')
    call require(all(ieee_is_finite(result%candidate_state%pressure_head)), label//' finite heads')
    call require(all(ieee_is_finite(result%candidate_state%water_content)), label//' finite water')
    call require(ieee_is_finite(result%unrounded_mass_balance_residual), label//' finite solver mass residual')
    call require(abs(result%unrounded_mass_balance_residual) <= hard_mass_gate, label//' solver hard mass gate')
    call require_state_unchanged(request%base_state,state,label//' request base state immutable')

    call provider%evaluate(result%candidate_state%pressure_head(1),result%candidate_state%water_content(1), &
         result%candidate_state%ponding_depth,probe_boundary,final_probe)
    call require(final_probe%status == SW_TOP_BOUNDARY_AVAILABLE, label//' final generic provider available')
    call require(trim(final_probe%route) == expected_route, label//' final route preserved')
    call require_close(result%top_flux,final_probe%actual_top_flux,hard_mass_gate,label//' final qtop/provider identity')
    call require_close(result%candidate_state%ponding_depth,final_probe%candidate_ponding_depth, &
         hard_mass_gate,label//' final pond/provider identity')
    surface_after = surface_mass_residual(pond_previous,final_probe)
    call require(abs(surface_after) <= hard_mass_gate, label//' final surface hard mass gate')
    total_mass = total_system_mass_residual(state,result,final_probe)
    call require(abs(total_mass) <= hard_mass_gate, label//' combined soil+surface hard mass gate')

    if (sensitivity_pair) then
      request_on = request
      request_on%request_interface_sensitivity = .true.
      call poison_legacy_top_context()
      call solver%solve(request_on,workspace_on,result_on)
      call require(result_on%status == SW_SOLVE_CONVERGED, label//' sensitivity-on solve converged')
      call require(result_on%interface_sensitivity%available, label//' F-SI28 tangent available')
      call require(trim(result_on%interface_sensitivity%method) == 'same-tridag-factor', label//' F-SI28 method preserved')
      call require(result_on%diagnostics%interface_sensitivity_backsolves == 1, label//' exactly one tangent backsolve')
      call require(result_on%diagnostics%nonlinear_iterations == result%diagnostics%nonlinear_iterations, &
           label//' sensitivity adds no nonlinear trajectory')
      call require(result_on%diagnostics%jacobian_builds == result%diagnostics%jacobian_builds, &
           label//' sensitivity adds no Jacobian')
      call require(result_on%diagnostics%linear_solves == result%diagnostics%linear_solves, &
           label//' normal linear solve count unchanged')
      call require_states_bitwise_equal(result_on%candidate_state,result%candidate_state,label//' tangent state identity')
      call require(same_bits(result_on%top_flux,result%top_flux),label//' tangent qtop identity')
      call require(same_bits(result_on%bottom_flux,result%bottom_flux),label//' tangent qbot identity')
      call require(same_bits(result_on%unrounded_mass_balance_residual,result%unrounded_mass_balance_residual), &
           label//' tangent mass identity')
    else
      call require(.not.result%interface_sensitivity%available,label//' unrequested tangent unavailable')
      call require(result%diagnostics%interface_sensitivity_backsolves == 0,label//' unrequested tangent zero cost')
    end if

    write(*,'(A,A,A,A,A,ES24.16,A,ES24.16,A,ES24.16)') 'FSI30_CASE:',trim(label),':ROUTE=',trim(expected_route), &
         ':SURFACE=',surface_after,':SOLVER=',result%unrounded_mass_balance_residual,':TOTAL=',total_mass
  end subroutine run_dynamic_case

  subroutine run_fixed_flux_regression(head_value, qeq)
    real(real64), intent(in) :: head_value, qeq
    type(soil_water_physical_state_t) :: state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_workspace_t) :: workspace
    call make_state(head_value,0.0_real64,state)
    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state = state
    request%step_duration = total_dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 2
    request%boundary%top_flux = qeq
    request%boundary%bottom_flux = qeq
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 8
    request%numerical%max_backtracking = 4
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-6_real64
    request%numerical%compartment_balance_tolerance = hard_mass_gate
    request%numerical%total_balance_tolerance = hard_mass_gate
    request%numerical%head_abs_tolerance = 1.0e-12_real64
    request%numerical%head_rel_tolerance = 1.0e-12_real64
    request%numerical%ponding_tolerance = hard_mass_gate
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%top_boundary => fixed_top
    call poison_legacy_top_context()
    call solver%solve(request,workspace,result)
    call require(result%status == SW_SOLVE_CONVERGED,'fixed-flux regression converged')
    call require(same_bits(result%top_flux,qeq),'fixed-flux qtop bitwise')
    call require(same_bits(result%bottom_flux,qeq),'fixed-flux qbot bitwise')
    call require_states_bitwise_equal(result%candidate_state,state,'fixed-flux equilibrium state identity')
    call require(abs(result%unrounded_mass_balance_residual) <= hard_mass_gate,'fixed-flux hard mass gate')
  end subroutine run_fixed_flux_regression

  subroutine run_dynamic_missing_provider_failclosed(head_value, qbot_value)
    real(real64), intent(in) :: head_value, qbot_value
    type(soil_water_physical_state_t) :: state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_workspace_t) :: workspace
    call make_state(head_value,0.0_real64,state)
    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state = state
    request%step_duration = total_dt
    request%boundary%top_mode = FSI_TOP_MODE_DYNAMIC_PROVIDER
    request%boundary%bottom_mode = 2
    request%boundary%bottom_flux = qbot_value
    request%physical%macropore_active = .false.
    request%numerical%conductivity_implicit_mode = 0
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    call solver%solve(request,workspace,result)
    call require(result%status == SW_SOLVE_FAILED,'dynamic missing-provider fails closed')
    call require(trim(result%diagnostics%route) == 'dynamic-top-provider-required', &
         'dynamic missing-provider route identity')
  end subroutine run_dynamic_missing_provider_failclosed

  subroutine poison_legacy_top_context()
    legacy_swbotb = 99
    legacy_qtop = 87654.321_real64
    legacy_qbot = -76543.210_real64
    legacy_hbot = 65432.109_real64
    legacy_nraidt = 54321.0_real64
    legacy_nird = 43210.0_real64
    legacy_melt = 32109.0_real64
    legacy_runon = 21098.0_real64
    legacy_epd = 10987.0_real64
    legacy_reva = 99876.0_real64
  end subroutine poison_legacy_top_context

  real(real64) function surface_mass_residual(pond_previous, top_result) result(value)
    real(real64), intent(in) :: pond_previous
    type(soil_water_top_boundary_result_t), intent(in) :: top_result
    value = top_result%candidate_ponding_depth - pond_previous - &
         top_result%net_potential_surface_flux*total_dt + top_result%runoff_depth - &
         top_result%actual_top_flux*total_dt
  end function surface_mass_residual

  real(real64) function total_system_mass_residual(state0, result, top_result) result(value)
    type(soil_water_physical_state_t), intent(in) :: state0
    type(soil_water_solve_result_t), intent(in) :: result
    type(soil_water_top_boundary_result_t), intent(in) :: top_result
    real(real64) :: storage0, storage1
    storage0 = sum(state0%water_content*parameters%dz) + state0%ponding_depth
    storage1 = sum(result%candidate_state%water_content*parameters%dz) + result%candidate_state%ponding_depth
    value = storage1-storage0 - top_result%net_potential_surface_flux*total_dt + &
         top_result%runoff_depth - result%bottom_flux*total_dt
  end function total_system_mass_residual

  subroutine require_state_unchanged(actual,expected,label)
    type(soil_water_physical_state_t), intent(in) :: actual,expected
    character(len=*), intent(in) :: label
    call require_states_bitwise_equal(actual,expected,label)
  end subroutine require_state_unchanged

  subroutine require_states_bitwise_equal(a,b,label)
    type(soil_water_physical_state_t), intent(in) :: a,b
    character(len=*), intent(in) :: label
    integer :: i
    call require(a%active_nodes == b%active_nodes,label//' active_nodes')
    do i=1,a%active_nodes
      call require(same_bits(a%pressure_head(i),b%pressure_head(i)),label//' h')
      call require(same_bits(a%water_content(i),b%water_content(i)),label//' theta')
    end do
    call require(same_bits(a%ponding_depth,b%ponding_depth),label//' pond')
    call require(same_bits(a%groundwater_level,b%groundwater_level),label//' gwl')
  end subroutine require_states_bitwise_equal

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  subroutine require_close(actual,expected,tolerance,label)
    real(real64), intent(in) :: actual,expected,tolerance
    character(len=*), intent(in) :: label
    real(real64) :: scale
    scale = max(1.0_real64,abs(actual),abs(expected))
    call require(abs(actual-expected) <= tolerance*scale,label)
  end subroutine require_close

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(error_unit,'(A,A)') 'FSI30_EXECUTION_FAIL ',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fsi30_dynamic_headcalc_execution

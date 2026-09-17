program test_pub_p2e03_reference_failure_probe
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS

  call probe_case('B01', 0.65_real64, 'NOMINAL', 0.010_real64, -0.004_real64, 0.0004_real64)
  call probe_case('B01', 0.65_real64, 'DRYING', -0.005_real64, -0.019_real64, 0.0016_real64)
  call probe_case('O18', 0.85_real64, 'NOMINAL', 0.010_real64, -0.004_real64, 0.0016_real64)
  call probe_case('B12', 0.65_real64, 'WETTING', 0.025_real64, 0.011_real64, 0.0004_real64)
  write(*,'(A)') 'PUB_P2E03_FAILURE_PROBE_COMPLETE=PASS'

contains

  subroutine probe_case(material_id, se, forcing_id, top_factor, bottom_factor, coarse_dt)
    character(len=*), intent(in) :: material_id, forcing_id
    real(real64), intent(in) :: se, top_factor, bottom_factor, coarse_dt
    type(soil_water_parameter_set_t), target :: parameters
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(fixed_flux_top_boundary_provider_t), target :: top_boundary
    real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
    real(real64) :: cofgen(24,n), heads(n), theta0(n), conductivity(n), capacity(n), dkdh(n)
    real(real64) :: h0, k0, half_dt
    logical :: found

    call rossfast_d3r_material_from_id(material_id, material, found)
    if (.not. found) error stop 'probe material missing'
    h0 = head_from_effective_saturation(se, material)
    call initialize_parameter_contract(parameters, cofgen, material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, coarse_dt)
    heads = h0
    call constitutive%evaluate(heads, theta0, conductivity, capacity, dkdh)
    if (any(.not. ieee_is_finite(conductivity)) .or. any(conductivity <= 0.0_real64)) error stop 'probe conductivity invalid'
    k0 = conductivity(1)
    drainage = 0.0_real64
    irrigation = 0.0_real64
    root_sink = 0.0_real64
    call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

    write(*,'(A,A,A,ES26.17E3,A,A,A,ES26.17E3)') 'PUB_P2E03_PROBE_BEGIN|M=',trim(material_id),'|SE=',se, &
         '|F=',trim(forcing_id),'|DT=',coarse_dt

    call initialize_request(request, parameters, constitutive, source_sink, top_boundary, theta0, h0, &
         top_factor*k0, bottom_factor*k0, coarse_dt)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, coarse_dt)
    call solver%solve(request, workspace, result)
    call print_result('COARSE', result, workspace)

    half_dt = 0.5_real64 * coarse_dt
    call initialize_request(request, parameters, constitutive, source_sink, top_boundary, theta0, h0, &
         top_factor*k0, bottom_factor*k0, half_dt)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, half_dt)
    call solver%solve(request, workspace, result)
    call print_result('HALF1', result, workspace)
    if (result%status /= 1) then
      write(*,'(A)') 'PUB_P2E03_PROBE_HALF2_SKIPPED=HALF1_NOT_CONVERGED'
      return
    end if

    request%base_state = result%candidate_state
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, half_dt)
    call solver%solve(request, workspace, result)
    call print_result('HALF2', result, workspace)
  end subroutine probe_case

  subroutine print_result(stage, result, workspace)
    character(len=*), intent(in) :: stage
    type(soil_water_solve_result_t), intent(in) :: result
    type(reference_richards_legacy_workspace_t), intent(in) :: workspace
    real(real64) :: residual_sum, residual_max
    integer :: balance_flags, head_flags

    residual_sum = huge(0.0_real64)
    residual_max = huge(0.0_real64)
    balance_flags = -1
    head_flags = -1
    if (allocated(workspace%richards%residual)) then
      residual_sum = sum(workspace%richards%residual)
      residual_max = maxval(abs(workspace%richards%residual))
    end if
    if (allocated(workspace%richards%nonconverged_balance)) &
         balance_flags = count(workspace%richards%nonconverged_balance)
    if (allocated(workspace%richards%nonconverged_head)) &
         head_flags = count(workspace%richards%nonconverged_head)

    write(*,'(A,A,A,I0,A,L1,A,A)') 'PUB_P2E03_PROBE|STAGE=',trim(stage),'|STATUS=',result%status, &
         '|RETRY=',result%retry_advised,'|ROUTE=',trim(result%diagnostics%route)
    write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') 'PUB_P2E03_PROBE_RESIDUAL|PUBLISHED=', &
         result%unrounded_mass_balance_residual,'|SUM=',residual_sum,'|MAXABS=',residual_max
    write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0)') 'PUB_P2E03_PROBE_FLAGS|BAL=',balance_flags,'|HEAD=',head_flags, &
         '|ITER=',result%diagnostics%nonlinear_iterations,'|BACKTRACK=',result%diagnostics%backtracking_attempts, &
         '|INTERNAL_RETRIES=',result%diagnostics%internal_retries
  end subroutine print_result

  pure real(real64) function head_from_effective_saturation(se, material) result(head_cm)
    real(real64), intent(in) :: se
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m
    m = 1.0_real64 - 1.0_real64 / material%n
    head_cm = -(se**(-1.0_real64/m) - 1.0_real64)**(1.0_real64/material%n) / material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine initialize_parameter_contract(parameter_set, cofgen_out, mat)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t), intent(in) :: mat
    real(real64) :: m
    integer :: i
    m = 1.0_real64 - 1.0_real64 / mat%n
    parameter_set%parameter_set_id = 920302
    parameter_set%active_nodes = n
    allocate(parameter_set%z(n), parameter_set%dz(n), parameter_set%node_distance(n))
    do i=1,n
      parameter_set%z(i) = -ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
    parameter_set%dz = ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance = ROSSFAST_D3R_DZ_CM
    cofgen_out = 0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n; cofgen_out(7,i)=m
      cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm; cofgen_out(10,i)=mat%ksatfit_cm_per_day
      cofgen_out(11,i)=0.999_real64; cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64; cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req, parameter_set, hydraulic_provider, source_provider, top_provider, theta, &
       h0, qtop, qbot, dt)
    type(soil_water_solve_request_t), intent(out) :: req
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), target, intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t), target, intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t), target, intent(in) :: top_provider
    real(real64), intent(in) :: theta(n), h0, qtop, qbot, dt
    req%parameters => parameter_set
    req%base_state%active_nodes = n
    allocate(req%base_state%pressure_head(n), req%base_state%water_content(n))
    req%base_state%pressure_head=h0; req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64; req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop; req%boundary%top_head=h0; req%boundary%bottom_flux=qbot
    req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=ROSSFAST_D3R_HARD_MASS_TOL_CM
    req%numerical%total_balance_tolerance=ROSSFAST_D3R_HARD_MASS_TOL_CM
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64; req%step_duration=dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider; req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request
end program test_pub_p2e03_reference_failure_probe

program test_pub_p2e02_reference_uncertainty_pilot
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  real(real64), parameter :: h0 = -101.0_real64
  real(real64), parameter :: coarse_dt = ROSSFAST_D3R_OUTER_HORIZON_DAY
  real(real64), parameter :: half_dt = 0.5_real64 * coarse_dt

  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: coarse_request, half1_request, half2_request
  type(soil_water_solve_result_t) :: coarse_result, half1_result, half2_result
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: coarse_workspace, half1_workspace, half2_workspace
  type(rossfast_d3r_material_t) :: material
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: cofgen(24,n), heads(n), theta0(n), conductivity(n), capacity(n), dkdh(n)
  real(real64) :: coarse_storage, refined_storage
  real(real64) :: uh_inf, uh_rms, utheta_inf, utheta_rms, ustorage
  real(real64) :: top_flux, bottom_flux
  logical :: found

  call rossfast_d3r_material_from_id('B01', material, found)
  call require(found, 'B01 E0 material authority available')
  call initialize_parameter_contract(parameters, cofgen, material)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)

  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, coarse_dt)
  heads = h0
  call constitutive%evaluate(heads, theta0, conductivity, capacity, dkdh)
  call require(all(ieee_is_finite(theta0)) .and. all(ieee_is_finite(conductivity)), &
       'initial Reference constitutive state finite')
  call require(all(conductivity > 0.0_real64), 'initial Reference conductivity positive')
  top_flux = 0.01_real64 * conductivity(1)
  bottom_flux = -0.004_real64 * conductivity(1)

  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

  call initialize_request(coarse_request, parameters, constitutive, source_sink, top_boundary, theta0, &
       top_flux, bottom_flux, coarse_dt)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, coarse_dt)
  call solver%solve(coarse_request, coarse_workspace, coarse_result)
  call require_reference_success(coarse_result, 'coarse')

  call initialize_request(half1_request, parameters, constitutive, source_sink, top_boundary, theta0, &
       top_flux, bottom_flux, half_dt)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, half_dt)
  call solver%solve(half1_request, half1_workspace, half1_result)
  call require_reference_success(half1_result, 'half1')

  call initialize_request(half2_request, parameters, constitutive, source_sink, top_boundary, theta0, &
       top_flux, bottom_flux, half_dt)
  half2_request%base_state = half1_result%candidate_state
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, half_dt)
  call solver%solve(half2_request, half2_workspace, half2_result)
  call require_reference_success(half2_result, 'half2')

  call require(coarse_result%candidate_state%active_nodes == n .and. half2_result%candidate_state%active_nodes == n, &
       'coarse and refined endpoints share E0 shape')
  call require(all(ieee_is_finite(coarse_result%candidate_state%pressure_head)) .and. &
       all(ieee_is_finite(half2_result%candidate_state%pressure_head)) .and. &
       all(ieee_is_finite(coarse_result%candidate_state%water_content)) .and. &
       all(ieee_is_finite(half2_result%candidate_state%water_content)), 'coarse/refined endpoint states finite')

  coarse_storage = sum(parameters%dz * coarse_result%candidate_state%water_content) + &
       coarse_result%candidate_state%ponding_depth
  refined_storage = sum(parameters%dz * half2_result%candidate_state%water_content) + &
       half2_result%candidate_state%ponding_depth

  uh_inf = maxval(abs(coarse_result%candidate_state%pressure_head - half2_result%candidate_state%pressure_head))
  uh_rms = sqrt(sum((coarse_result%candidate_state%pressure_head - &
       half2_result%candidate_state%pressure_head)**2) / real(n, real64))
  utheta_inf = maxval(abs(coarse_result%candidate_state%water_content - half2_result%candidate_state%water_content))
  utheta_rms = sqrt(sum((coarse_result%candidate_state%water_content - &
       half2_result%candidate_state%water_content)**2) / real(n, real64))
  ustorage = abs(coarse_storage - refined_storage)

  call require(ieee_is_finite(uh_inf) .and. ieee_is_finite(uh_rms) .and. &
       ieee_is_finite(utheta_inf) .and. ieee_is_finite(utheta_rms) .and. ieee_is_finite(ustorage), &
       'Reference self-disagreement metrics finite')

  write(*,'(A,ES26.17E3)') 'PUB_P2E02_COARSE_MASS_RESIDUAL=', coarse_result%unrounded_mass_balance_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E02_HALF1_MASS_RESIDUAL=', half1_result%unrounded_mass_balance_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E02_HALF2_MASS_RESIDUAL=', half2_result%unrounded_mass_balance_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E02_U_H_INF_CM=', uh_inf
  write(*,'(A,ES26.17E3)') 'PUB_P2E02_U_H_RMS_CM=', uh_rms
  write(*,'(A,ES26.17E3)') 'PUB_P2E02_U_THETA_INF=', utheta_inf
  write(*,'(A,ES26.17E3)') 'PUB_P2E02_U_THETA_RMS=', utheta_rms
  write(*,'(A,ES26.17E3)') 'PUB_P2E02_U_STORAGE_CM=', ustorage
  write(*,'(A)') 'PUB_P2E02_ROSSFAST_NOT_EXECUTED=TRUE'
  write(*,'(A)') 'PUB_P2E02_THRESHOLD_NOT_CALIBRATED_FROM_PILOT=TRUE'
  write(*,'(A)') 'PUB_P2E02_REFERENCE_UNCERTAINTY_EXTRACTION=PASS'

contains

  subroutine require_reference_success(result, label)
    type(soil_water_solve_result_t), intent(in) :: result
    character(len=*), intent(in) :: label
    call require(result%status == SW_SOLVE_CONVERGED, trim(label)//' Reference solve converged')
    call require(trim(result%diagnostics%route) == 'legacy-reference-bound', trim(label)//' route identity')
    call require(ieee_is_finite(result%unrounded_mass_balance_residual), trim(label)//' mass residual finite')
    call require(abs(result%unrounded_mass_balance_residual) <= ROSSFAST_D3R_HARD_MASS_TOL_CM, &
         trim(label)//' hard mass gate')
  end subroutine require_reference_success

  subroutine initialize_parameter_contract(parameter_set, cofgen_out, mat)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t), intent(in) :: mat
    real(real64) :: m
    integer :: i
    m = 1.0_real64 - 1.0_real64 / mat%n
    parameter_set%parameter_set_id = 920201
    parameter_set%active_nodes = n
    allocate(parameter_set%z(n), parameter_set%dz(n), parameter_set%node_distance(n))
    do i = 1, n
      parameter_set%z(i) = -ROSSFAST_D3R_DZ_CM * (real(i,real64)-0.5_real64)
    end do
    parameter_set%dz = ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance = ROSSFAST_D3R_DZ_CM
    cofgen_out = 0.0_real64
    do i = 1, n
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n; cofgen_out(7,i)=m
      cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm; cofgen_out(10,i)=mat%ksatfit_cm_per_day
      cofgen_out(11,i)=0.999_real64; cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64; cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req, parameter_set, hydraulic_provider, source_provider, top_provider, theta, &
       qtop, qbot, dt)
    type(soil_water_solve_request_t), intent(out) :: req
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), target, intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t), target, intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t), target, intent(in) :: top_provider
    real(real64), intent(in) :: theta(n), qtop, qbot, dt
    req%parameters => parameter_set
    req%base_state%active_nodes = n
    allocate(req%base_state%pressure_head(n), req%base_state%water_content(n))
    req%base_state%pressure_head = h0
    req%base_state%water_content = theta
    req%base_state%ponding_depth = 0.0_real64
    req%base_state%groundwater_level = -999.0_real64
    req%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode = 2
    req%boundary%top_flux = qtop
    req%boundary%top_head = h0
    req%boundary%bottom_flux = qbot
    req%boundary%bottom_head = -999999.0_real64
    req%physical%macropore_active = .false.
    req%numerical%max_iterations = 16
    req%numerical%max_backtracking = 8
    req%numerical%conductivity_implicit_mode = 0
    req%numerical%conductivity_mean_method = 1
    req%numerical%min_step_duration = 1.0e-8_real64
    req%numerical%compartment_balance_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    req%numerical%total_balance_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    req%numerical%head_abs_tolerance = 1.0e-12_real64
    req%numerical%head_rel_tolerance = 1.0e-12_real64
    req%numerical%ponding_tolerance = 1.0e-12_real64
    req%step_duration = dt
    req%request_interface_sensitivity = .false.
    req%evaluation%constitutive => hydraulic_provider
    req%evaluation%source_sink => source_provider
    req%evaluation%top_boundary => top_provider
  end subroutine initialize_request

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'PUB_P2E02_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e02_reference_uncertainty_pilot

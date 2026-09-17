program test_pub_p2e01_solver_seam_paired_pilot
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_soil_water_solver, only: rossfast_d3r_soil_water_solver_t, &
       rossfast_d3r_soil_water_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: initial_head_cm = -101.0_real64
  integer, parameter :: n = ROSSFAST_D3R_N_CELLS

  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: reference_result, alternative_result
  type(reference_richards_legacy_solver_t) :: reference_solver
  type(reference_richards_legacy_workspace_t) :: reference_workspace
  type(rossfast_d3r_soil_water_solver_t) :: alternative_solver
  type(rossfast_d3r_soil_water_workspace_t) :: alternative_workspace
  type(rossfast_d3r_material_t) :: material
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: cofgen(24,n), heads(n), theta0(n), conductivity(n), capacity(n), dkdh(n)
  real(real64) :: storage_reference, storage_alternative
  real(real64) :: dh_inf, dh_rms, dtheta_inf, dtheta_rms, dstorage, dqtop, dqbot
  logical :: found, initialized
  integer :: provider_status

  call rossfast_d3r_material_from_id('B01', material, found)
  call require(found, 'B01 material authority available')

  call initialize_parameter_contract(parameters, cofgen, material)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, ROSSFAST_D3R_OUTER_HORIZON_DAY)

  heads = initial_head_cm
  call constitutive%evaluate(heads, theta0, conductivity, capacity, dkdh)
  call require(all(ieee_is_finite(theta0)) .and. all(ieee_is_finite(conductivity)), &
       'common constitutive initialization finite')
  call require(all(conductivity > 0.0_real64), 'common initial conductivity positive')

  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

  call initialize_common_request(request, parameters, constitutive, source_sink, top_boundary, theta0, conductivity(1))

  call reference_solver%solve(request, reference_workspace, reference_result)
  call require(reference_result%status == SW_SOLVE_CONVERGED, 'Reference solver converged on common request')
  call require(trim(reference_result%diagnostics%route) == 'legacy-reference-bound', &
       'Reference route identity explicit')

  call alternative_solver%initialize('assets/rossfast/d3r', 'B01', initialized, provider_status)
  call require(initialized, 'RossFast solver initialized from admitted B01 asset')
  call alternative_solver%solve(request, alternative_workspace, alternative_result)
  call require(alternative_result%status == SW_SOLVE_CONVERGED, 'RossFast solver converged on common request')
  call require(trim(alternative_result%diagnostics%route) == 'rossfast-d3r', 'RossFast route identity explicit')

  call require(reference_result%candidate_state%active_nodes == n .and. &
       alternative_result%candidate_state%active_nodes == n, 'paired candidates use identical node count')
  call require(allocated(reference_result%candidate_state%pressure_head) .and. &
       allocated(alternative_result%candidate_state%pressure_head) .and. &
       allocated(reference_result%candidate_state%water_content) .and. &
       allocated(alternative_result%candidate_state%water_content), 'paired endpoint state vectors allocated')
  call require(size(reference_result%candidate_state%pressure_head) == n .and. &
       size(alternative_result%candidate_state%pressure_head) == n .and. &
       size(reference_result%candidate_state%water_content) == n .and. &
       size(alternative_result%candidate_state%water_content) == n, 'paired endpoint state vectors share E0 shape')

  call require(all(ieee_is_finite(reference_result%candidate_state%pressure_head)) .and. &
       all(ieee_is_finite(alternative_result%candidate_state%pressure_head)) .and. &
       all(ieee_is_finite(reference_result%candidate_state%water_content)) .and. &
       all(ieee_is_finite(alternative_result%candidate_state%water_content)), 'paired endpoint state finite')
  call require(ieee_is_finite(reference_result%unrounded_mass_balance_residual) .and. &
       ieee_is_finite(alternative_result%unrounded_mass_balance_residual), 'paired mass residuals finite')
  call require(abs(reference_result%unrounded_mass_balance_residual) <= ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       'Reference one-step mass residual within declared pilot hard bound')
  call require(abs(alternative_result%unrounded_mass_balance_residual) <= ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       'RossFast one-step mass residual within admitted hard bound')

  storage_reference = sum(parameters%dz * reference_result%candidate_state%water_content) + &
       reference_result%candidate_state%ponding_depth
  storage_alternative = sum(parameters%dz * alternative_result%candidate_state%water_content) + &
       alternative_result%candidate_state%ponding_depth

  dh_inf = maxval(abs(alternative_result%candidate_state%pressure_head - &
       reference_result%candidate_state%pressure_head))
  dh_rms = sqrt(sum((alternative_result%candidate_state%pressure_head - &
       reference_result%candidate_state%pressure_head)**2) / real(n, real64))
  dtheta_inf = maxval(abs(alternative_result%candidate_state%water_content - &
       reference_result%candidate_state%water_content))
  dtheta_rms = sqrt(sum((alternative_result%candidate_state%water_content - &
       reference_result%candidate_state%water_content)**2) / real(n, real64))
  dstorage = abs(storage_alternative - storage_reference)
  dqtop = abs(alternative_result%top_flux - reference_result%top_flux)
  dqbot = abs(alternative_result%bottom_flux - reference_result%bottom_flux)

  call require(ieee_is_finite(dh_inf) .and. ieee_is_finite(dh_rms) .and. &
       ieee_is_finite(dtheta_inf) .and. ieee_is_finite(dtheta_rms) .and. &
       ieee_is_finite(dstorage) .and. ieee_is_finite(dqtop) .and. ieee_is_finite(dqbot), &
       'paired raw discrepancy metrics finite')

  write(*,'(A,A)') 'PUB_P2E01_REFERENCE_SOLVER_ROUTE=', trim(reference_result%diagnostics%route)
  write(*,'(A,A)') 'PUB_P2E01_ALTERNATIVE_SOLVER_ROUTE=', trim(alternative_result%diagnostics%route)
  write(*,'(A,I0)') 'PUB_P2E01_REFERENCE_NONLINEAR_ITERATIONS=', reference_result%diagnostics%nonlinear_iterations
  write(*,'(A,I0)') 'PUB_P2E01_REFERENCE_LINEAR_SOLVES=', reference_result%diagnostics%linear_solves
  write(*,'(A,I0)') 'PUB_P2E01_ALTERNATIVE_LINEAR_SOLVES=', alternative_result%diagnostics%linear_solves
  write(*,'(A,I0)') 'PUB_P2E01_ALTERNATIVE_SOLVER_CALLS=', alternative_result%diagnostics%alternative_solver_calls
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_REFERENCE_MASS_RESIDUAL=', reference_result%unrounded_mass_balance_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_ALTERNATIVE_MASS_RESIDUAL=', alternative_result%unrounded_mass_balance_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_H_INF_CM=', dh_inf
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_H_RMS_CM=', dh_rms
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_THETA_INF=', dtheta_inf
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_THETA_RMS=', dtheta_rms
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_STORAGE_CM=', dstorage
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_QTOP_PRESCRIBED_CM_PER_DAY=', dqtop
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_QBOT_PRESCRIBED_CM_PER_DAY=', dqbot
  write(*,'(A)') 'PUB_P2E01_PRESCRIBED_FLUX_DIFFERENCE_IS_NOT_INDEPENDENT_EVIDENCE=TRUE'
  write(*,'(A)') 'PUB_P2E01_SCIENTIFIC_ADMISSIBILITY_NOT_EVALUATED=TRUE'
  write(*,'(A)') 'PUB_P2E01_TRANSACTION_LEVEL_PAIR_BLOCKED_TEMPORAL_POLICY_ASYMMETRY=TRUE'
  write(*,'(A)') 'PUB_P2E01_SOLVER_SEAM_PAIRED_EXTRACTION_READY=PASS'

contains

  subroutine initialize_parameter_contract(parameter_set, cofgen_out, mat)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t), intent(in) :: mat
    real(real64) :: m
    integer :: i

    m = 1.0_real64 - 1.0_real64 / mat%n
    parameter_set%parameter_set_id = 220012
    parameter_set%active_nodes = n
    allocate(parameter_set%z(n), parameter_set%dz(n), parameter_set%node_distance(n))
    do i = 1, n
      parameter_set%z(i) = -ROSSFAST_D3R_DZ_CM * (real(i, real64) - 0.5_real64)
    end do
    parameter_set%dz = ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance = ROSSFAST_D3R_DZ_CM

    cofgen_out = 0.0_real64
    do i = 1, n
      cofgen_out(1,i) = mat%theta_r
      cofgen_out(2,i) = mat%theta_s
      cofgen_out(3,i) = mat%ksatfit_cm_per_day
      cofgen_out(4,i) = mat%alpha_per_cm
      cofgen_out(5,i) = mat%lambda
      cofgen_out(6,i) = mat%n
      cofgen_out(7,i) = m
      cofgen_out(8,i) = mat%alpha_per_cm
      cofgen_out(9,i) = mat%h_enpr_cm
      cofgen_out(10,i) = mat%ksatfit_cm_per_day
      cofgen_out(11,i) = 0.999_real64
      cofgen_out(12,i) = 0.99_real64 * mat%ksatfit_cm_per_day
      cofgen_out(22,i) = -1.0e6_real64
      cofgen_out(23,i) = 1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_common_request(req, parameter_set, hydraulic_provider, source_provider, top_provider, theta, k0)
    type(soil_water_solve_request_t), intent(out) :: req
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), target, intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t), target, intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t), target, intent(in) :: top_provider
    real(real64), intent(in) :: theta(n), k0

    req%parameters => parameter_set
    req%base_state%active_nodes = n
    allocate(req%base_state%pressure_head(n), req%base_state%water_content(n))
    req%base_state%pressure_head = initial_head_cm
    req%base_state%water_content = theta
    req%base_state%ponding_depth = 0.0_real64
    req%base_state%groundwater_level = -999.0_real64

    req%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode = 2
    req%boundary%top_flux = 0.01_real64 * k0
    req%boundary%top_head = initial_head_cm
    req%boundary%bottom_flux = -0.004_real64 * k0
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
    req%step_duration = ROSSFAST_D3R_OUTER_HORIZON_DAY
    req%request_interface_sensitivity = .false.

    req%evaluation%constitutive => hydraulic_provider
    req%evaluation%source_sink => source_provider
    req%evaluation%top_boundary => top_provider
  end subroutine initialize_common_request

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'PUB_P2E01_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_pub_p2e01_solver_seam_paired_pilot

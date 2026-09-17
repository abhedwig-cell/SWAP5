program test_pub_p2e01_e0_paired_pilot
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_soil_water_solver, only: rossfast_d3r_soil_water_solver_t, &
       rossfast_d3r_soil_water_workspace_t
  implicit none

  real(real64), parameter :: initial_head_cm = -101.0_real64
  integer(int64), parameter :: parameter_set_id = 220012_int64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  type(reference_richards_legacy_solver_t) :: reference_solver
  type(reference_richards_legacy_workspace_t) :: reference_workspace
  type(rossfast_d3r_soil_water_solver_t) :: alternative_solver
  type(rossfast_d3r_soil_water_workspace_t) :: alternative_workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: reference_result, alternative_result
  type(rossfast_d3r_material_t) :: material
  real(real64), allocatable, target :: drainage(:,:), irrigation(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: conductivity, theta0
  real(real64) :: dh_inf, dh_rms, dtheta_inf, dtheta_rms, dstorage
  real(real64) :: storage_reference, storage_alternative
  logical :: found, initialized
  integer :: provider_status

  call rossfast_d3r_material_from_id('B01', material, found)
  call require(found, 'B01 material authority available')

  call build_common_request(material, parameters, hydraulic_parameters, constitutive, source_sink, top_boundary, &
       drainage, irrigation, root_sink, cofgen, request, conductivity, theta0)

  call reference_solver%solve(request, reference_workspace, reference_result)
  call require(reference_result%status == SW_SOLVE_CONVERGED, &
       'Reference solver converges on exact common fixed-interval request')
  call require(trim(reference_result%diagnostics%route) == 'legacy-reference-bound', &
       'Reference route is explicit legacy-reference-bound')

  call alternative_solver%initialize('assets/rossfast/d3r', 'B01', initialized, provider_status)
  call require(initialized, 'RossFast initializes from admitted B01 assets')
  call alternative_solver%solve(request, alternative_workspace, alternative_result)
  call require(alternative_result%status == SW_SOLVE_CONVERGED, &
       'RossFast solver converges on exact common fixed-interval request')
  call require(trim(alternative_result%diagnostics%route) == 'rossfast-d3r', &
       'RossFast route is explicit rossfast-d3r')

  call require(reference_result%candidate_state%active_nodes == ROSSFAST_D3R_N_CELLS, &
       'Reference candidate has E0 node count')
  call require(alternative_result%candidate_state%active_nodes == ROSSFAST_D3R_N_CELLS, &
       'RossFast candidate has E0 node count')
  call require(allocated(reference_result%candidate_state%pressure_head) .and. &
       allocated(alternative_result%candidate_state%pressure_head), 'paired head profiles available')
  call require(allocated(reference_result%candidate_state%water_content) .and. &
       allocated(alternative_result%candidate_state%water_content), 'paired water-content profiles available')

  dh_inf = maxval(abs(alternative_result%candidate_state%pressure_head - &
       reference_result%candidate_state%pressure_head))
  dh_rms = sqrt(sum((alternative_result%candidate_state%pressure_head - &
       reference_result%candidate_state%pressure_head)**2) / real(ROSSFAST_D3R_N_CELLS, real64))
  dtheta_inf = maxval(abs(alternative_result%candidate_state%water_content - &
       reference_result%candidate_state%water_content))
  dtheta_rms = sqrt(sum((alternative_result%candidate_state%water_content - &
       reference_result%candidate_state%water_content)**2) / real(ROSSFAST_D3R_N_CELLS, real64))

  storage_reference = sum(reference_result%candidate_state%water_content * parameters%dz)
  storage_alternative = sum(alternative_result%candidate_state%water_content * parameters%dz)
  dstorage = abs(storage_alternative - storage_reference)

  call require(all(ieee_is_finite(reference_result%candidate_state%pressure_head)) .and. &
       all(ieee_is_finite(alternative_result%candidate_state%pressure_head)), 'paired head profiles finite')
  call require(all(ieee_is_finite(reference_result%candidate_state%water_content)) .and. &
       all(ieee_is_finite(alternative_result%candidate_state%water_content)), 'paired theta profiles finite')
  call require(ieee_is_finite(reference_result%unrounded_mass_balance_residual) .and. &
       abs(reference_result%unrounded_mass_balance_residual) <= ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       'Reference independent mass residual passes common hard pilot bound')
  call require(ieee_is_finite(alternative_result%unrounded_mass_balance_residual) .and. &
       abs(alternative_result%unrounded_mass_balance_residual) <= ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       'RossFast independent mass residual passes common hard pilot bound')

  call require(same_real(reference_result%top_flux, request%boundary%top_flux), &
       'Reference applied prescribed top flux')
  call require(same_real(alternative_result%top_flux, request%boundary%top_flux), &
       'RossFast applied prescribed top flux')
  call require(same_real(reference_result%bottom_flux, request%boundary%bottom_flux), &
       'Reference applied prescribed bottom flux')
  call require(same_real(alternative_result%bottom_flux, request%boundary%bottom_flux), &
       'RossFast applied prescribed bottom flux')

  call require(ieee_is_finite(dh_inf) .and. ieee_is_finite(dh_rms) .and. &
       ieee_is_finite(dtheta_inf) .and. ieee_is_finite(dtheta_rms) .and. ieee_is_finite(dstorage), &
       'paired raw metrics finite')

  write(*,'(A,A)') 'PUB_P2E01_LAYER=A_FIXED_INTERVAL_SOLVER_SEAM'
  write(*,'(A,A)') 'PUB_P2E01_REFERENCE_SOLVER_ROUTE=', trim(reference_result%diagnostics%route)
  write(*,'(A,A)') 'PUB_P2E01_ALTERNATIVE_SOLVER_ROUTE=', trim(alternative_result%diagnostics%route)
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_INITIAL_THETA=', theta0
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_PRESCRIBED_TOP_FLUX=', request%boundary%top_flux
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_PRESCRIBED_BOTTOM_FLUX=', request%boundary%bottom_flux
  write(*,'(A,I0)') 'PUB_P2E01_REFERENCE_NONLINEAR_ITERATIONS=', reference_result%diagnostics%nonlinear_iterations
  write(*,'(A,I0)') 'PUB_P2E01_REFERENCE_INTERNAL_RETRIES=', reference_result%diagnostics%internal_retries
  write(*,'(A,I0)') 'PUB_P2E01_REFERENCE_LINEAR_SOLVES=', reference_result%diagnostics%linear_solves
  write(*,'(A,I0)') 'PUB_P2E01_ALTERNATIVE_LINEAR_SOLVES=', alternative_result%diagnostics%linear_solves
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_REFERENCE_MASS_RESIDUAL=', reference_result%unrounded_mass_balance_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_ALTERNATIVE_MASS_RESIDUAL=', alternative_result%unrounded_mass_balance_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_H_INF_CM=', dh_inf
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_H_RMS_CM=', dh_rms
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_THETA_INF=', dtheta_inf
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_THETA_RMS=', dtheta_rms
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_STORAGE_CM=', dstorage
  write(*,'(A)') 'PUB_P2E01_LAYER_B_APPLICATION_POLICY_STATUS=ROUTE_EXECUTION_GAP'
  write(*,'(A)') 'PUB_P2E01_SCIENTIFIC_ADMISSIBILITY_NOT_EVALUATED=TRUE'
  write(*,'(A)') 'PUB_P2E01_PREDICTED_FLUX_EQUIVALENCE_NOT_EVALUATED=TRUE'
  write(*,'(A)') 'PUB_P2E01_PAIRED_EXTRACTION_READY=PASS'

contains

  subroutine build_common_request(material, parameters, hydraulic_parameters, constitutive, source_sink, top_boundary, &
       drainage, irrigation, root_sink, cofgen, request, conductivity, theta0)
    type(rossfast_d3r_material_t), intent(in) :: material
    type(soil_water_parameter_set_t), target, intent(out) :: parameters
    type(b110_default_mvg_parameters_t), target, intent(out) :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target, intent(out) :: constitutive
    type(b110_source_sink_provider_t), target, intent(out) :: source_sink
    type(fixed_flux_top_boundary_provider_t), target, intent(out) :: top_boundary
    real(real64), allocatable, target, intent(out) :: drainage(:,:), irrigation(:), root_sink(:)
    real(real64), allocatable, intent(out) :: cofgen(:,:)
    type(soil_water_solve_request_t), intent(out) :: request
    real(real64), intent(out) :: conductivity, theta0
    real(real64) :: m
    integer :: i

    m = 1.0_real64 - 1.0_real64 / material%n
    parameters%parameter_set_id = parameter_set_id
    parameters%active_nodes = ROSSFAST_D3R_N_CELLS
    allocate(parameters%z(ROSSFAST_D3R_N_CELLS), parameters%dz(ROSSFAST_D3R_N_CELLS), &
         parameters%node_distance(ROSSFAST_D3R_N_CELLS))
    do i = 1, ROSSFAST_D3R_N_CELLS
      parameters%z(i) = -ROSSFAST_D3R_DZ_CM * (real(i,real64) - 0.5_real64)
    end do
    parameters%dz = ROSSFAST_D3R_DZ_CM
    parameters%node_distance = ROSSFAST_D3R_DZ_CM

    allocate(cofgen(24,ROSSFAST_D3R_N_CELLS))
    cofgen = 0.0_real64
    do i = 1, ROSSFAST_D3R_N_CELLS
      cofgen(1,i) = material%theta_r
      cofgen(2,i) = material%theta_s
      cofgen(3,i) = material%ksatfit_cm_per_day
      cofgen(4,i) = material%alpha_per_cm
      cofgen(5,i) = material%lambda
      cofgen(6,i) = material%n
      cofgen(7,i) = m
      cofgen(8,i) = material%alpha_per_cm
      cofgen(9,i) = material%h_enpr_cm
      cofgen(10,i) = material%ksatfit_cm_per_day
      cofgen(11,i) = 0.999_real64
      cofgen(12,i) = 0.99_real64 * material%ksatfit_cm_per_day
      cofgen(22,i) = -1.0e6_real64
      cofgen(23,i) = 1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, ROSSFAST_D3R_OUTER_HORIZON_DAY)

    allocate(drainage(1,ROSSFAST_D3R_N_CELLS), irrigation(ROSSFAST_D3R_N_CELLS), &
         root_sink(ROSSFAST_D3R_N_CELLS))
    drainage = 0.0_real64
    irrigation = 0.0_real64
    root_sink = 0.0_real64
    call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

    theta0 = theta_from_head(initial_head_cm, material)
    conductivity = conductivity_from_head(initial_head_cm, material)

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state%active_nodes = ROSSFAST_D3R_N_CELLS
    allocate(request%base_state%pressure_head(ROSSFAST_D3R_N_CELLS), &
         request%base_state%water_content(ROSSFAST_D3R_N_CELLS))
    request%base_state%pressure_head = initial_head_cm
    request%base_state%water_content = theta0
    request%base_state%ponding_depth = 0.0_real64
    request%base_state%groundwater_level = -999.0_real64
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 2
    request%boundary%top_flux = 0.01_real64 * conductivity
    request%boundary%top_head = initial_head_cm
    request%boundary%bottom_flux = -0.004_real64 * conductivity
    request%boundary%bottom_head = -999999.0_real64
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 16
    request%numerical%max_backtracking = 8
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-8_real64
    request%numerical%compartment_balance_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    request%numerical%total_balance_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    request%numerical%head_abs_tolerance = 1.0e-12_real64
    request%numerical%head_rel_tolerance = 1.0e-12_real64
    request%numerical%ponding_tolerance = 1.0e-12_real64
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%top_boundary => top_boundary
    request%step_duration = ROSSFAST_D3R_OUTER_HORIZON_DAY
    request%request_interface_sensitivity = .false.
  end subroutine build_common_request

  pure real(real64) function theta_from_head(head_cm, material) result(theta)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m, saturation
    m = 1.0_real64 - 1.0_real64 / material%n
    saturation = (1.0_real64 + abs(material%alpha_per_cm * head_cm)**material%n)**(-m)
    theta = material%theta_r + (material%theta_s - material%theta_r) * saturation
  end function theta_from_head

  pure real(real64) function conductivity_from_head(head_cm, material) result(conductivity)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m, saturation, term
    m = 1.0_real64 - 1.0_real64 / material%n
    saturation = (1.0_real64 + abs(material%alpha_per_cm * head_cm)**material%n)**(-m)
    term = (1.0_real64 - saturation**(1.0_real64 / m))**m
    conductivity = material%ksatfit_cm_per_day * saturation**material%lambda * (1.0_real64 - term)**2
  end function conductivity_from_head

  pure logical function same_real(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    same_real = abs(a-b) <= 32.0_real64 * epsilon(1.0_real64) * scale
  end function same_real

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'PUB_P2E01_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_pub_p2e01_e0_paired_pilot

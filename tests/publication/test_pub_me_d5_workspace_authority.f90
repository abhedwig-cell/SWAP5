program test_pub_me_d5_workspace_authority
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  real(real64), parameter :: h0 = -101.0_real64
  real(real64), parameter :: full_dt = 0.0016_real64
  real(real64), parameter :: retry_dt = 0.0008_real64
  real(real64), parameter :: reference_balance_rate_tol = 1.0e-12_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: full_request, half1_request, half2_request
  type(soil_water_solve_request_t) :: clean_retry_request, mutant_retry_request
  type(soil_water_solve_result_t) :: full_result, half1_result, half2_result
  type(soil_water_solve_result_t) :: clean_retry_result, mutant_retry_result
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: full_workspace, half1_workspace, half2_workspace
  type(reference_richards_legacy_workspace_t) :: clean_retry_workspace, mutant_retry_workspace
  type(rossfast_d3r_material_t) :: material
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: cofgen(24,n), initial_head(n), theta0(n)
  real(real64) :: conductivity(n), capacity(n), dkdh(n)
  real(real64) :: mutant_theta(n), scratch_k(n), scratch_c(n), scratch_dkdh(n)
  real(real64) :: full_refined_h_inf, full_refined_theta_inf
  real(real64) :: workspace_origin_h_inf, workspace_origin_theta_inf
  real(real64) :: retry_h_inf, retry_theta_inf, clean_storage, mutant_storage, retry_storage_diff
  real(real64) :: top_flux, bottom_flux
  character(len=32) :: classification
  logical :: found, b2_detected, b1_detected

  call rossfast_d3r_material_from_id('B01', material, found)
  call require(found, 'B01 E0 material authority available')
  call initialize_parameter_contract(parameters, cofgen, material)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)

  initial_head = h0
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, full_dt)
  call constitutive%evaluate(initial_head, theta0, conductivity, capacity, dkdh)
  call require(all(ieee_is_finite(theta0)) .and. all(ieee_is_finite(conductivity)), &
       'initial constitutive state finite')
  call require(all(conductivity > 0.0_real64), 'initial conductivity positive')

  top_flux = 0.01_real64 * conductivity(1)
  bottom_flux = -0.004_real64 * conductivity(1)
  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

  ! Frozen P2E02 full trial.
  call initialize_request(full_request, parameters, constitutive, source_sink, top_boundary, &
       initial_head, theta0, top_flux, bottom_flux, full_dt)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, full_dt)
  call solver%solve(full_request, full_workspace, full_result)
  call require_reference_success(full_result, 'full')

  ! Independent two-half comparator establishing that the full trial is rejected
  ! under the preregistered zero temporal-discrepancy tolerance.
  call initialize_request(half1_request, parameters, constitutive, source_sink, top_boundary, &
       initial_head, theta0, top_flux, bottom_flux, retry_dt)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, retry_dt)
  call solver%solve(half1_request, half1_workspace, half1_result)
  call require_reference_success(half1_result, 'half1')

  call initialize_request(half2_request, parameters, constitutive, source_sink, top_boundary, &
       initial_head, theta0, top_flux, bottom_flux, retry_dt)
  half2_request%base_state = half1_result%candidate_state
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, retry_dt)
  call solver%solve(half2_request, half2_workspace, half2_result)
  call require_reference_success(half2_result, 'half2')

  full_refined_h_inf = maxval(abs(full_result%candidate_state%pressure_head - &
       half2_result%candidate_state%pressure_head))
  full_refined_theta_inf = maxval(abs(full_result%candidate_state%water_content - &
       half2_result%candidate_state%water_content))
  call require(full_refined_h_inf > 0.0_real64 .or. full_refined_theta_inf > 0.0_real64, &
       'BLOCKED_FIXTURE_NO_REJECTION: full and refined endpoints bit-identical')

  ! Frozen real workspace source. Do not switch to another field if uninformative.
  call require(allocated(full_workspace%richards%old_head), 'full Reference old_head workspace allocated')
  call require(size(full_workspace%richards%old_head) == n, 'full old_head workspace shape')
  call require(all(ieee_is_finite(full_workspace%richards%old_head)), 'full old_head workspace finite')
  workspace_origin_h_inf = maxval(abs(full_workspace%richards%old_head - initial_head))
  call require(workspace_origin_h_inf > 0.0_real64, &
       'BLOCKED_WORKSPACE_NOT_INFORMATIVE: old_head identical to committed initial head')

  ! Clean retry starts from the authoritative committed physical origin.
  call initialize_request(clean_retry_request, parameters, constitutive, source_sink, top_boundary, &
       initial_head, theta0, top_flux, bottom_flux, retry_dt)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, retry_dt)
  call solver%solve(clean_retry_request, clean_retry_workspace, clean_retry_result)
  call require_reference_success(clean_retry_result, 'clean retry')

  ! Qualification-only mutant: promote rejected-trial Newton scratch old_head into
  ! physical retry authority, then recompute dependent theta from the same
  ! constitutive relation to avoid an unrelated inconsistent-state fault.
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, retry_dt)
  call constitutive%evaluate(full_workspace%richards%old_head, mutant_theta, scratch_k, scratch_c, scratch_dkdh)
  call require(all(ieee_is_finite(mutant_theta)), 'mutant workspace-derived theta finite')

  workspace_origin_theta_inf = maxval(abs(mutant_theta - theta0))
  b2_detected = workspace_origin_h_inf > 0.0_real64 .or. workspace_origin_theta_inf > 0.0_real64
  call require(b2_detected, 'B2 retry-origin authority detects workspace-derived physical start')

  call initialize_request(mutant_retry_request, parameters, constitutive, source_sink, top_boundary, &
       full_workspace%richards%old_head, mutant_theta, top_flux, bottom_flux, retry_dt)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, retry_dt)
  call solver%solve(mutant_retry_request, mutant_retry_workspace, mutant_retry_result)

  ! B1 is deliberately strong. Solver failure itself is a conventional detection;
  ! otherwise compare endpoint state and storage after the solve.
  if (mutant_retry_result%status /= SW_SOLVE_CONVERGED) then
    b1_detected = .true.
    retry_h_inf = huge(0.0_real64)
    retry_theta_inf = huge(0.0_real64)
    retry_storage_diff = huge(0.0_real64)
  else
    call require(all(ieee_is_finite(mutant_retry_result%candidate_state%pressure_head)), &
         'mutant retry endpoint head finite')
    call require(all(ieee_is_finite(mutant_retry_result%candidate_state%water_content)), &
         'mutant retry endpoint theta finite')
    retry_h_inf = maxval(abs(clean_retry_result%candidate_state%pressure_head - &
         mutant_retry_result%candidate_state%pressure_head))
    retry_theta_inf = maxval(abs(clean_retry_result%candidate_state%water_content - &
         mutant_retry_result%candidate_state%water_content))
    clean_storage = sum(parameters%dz * clean_retry_result%candidate_state%water_content) + &
         clean_retry_result%candidate_state%ponding_depth
    mutant_storage = sum(parameters%dz * mutant_retry_result%candidate_state%water_content) + &
         mutant_retry_result%candidate_state%ponding_depth
    retry_storage_diff = abs(clean_storage - mutant_storage)
    b1_detected = retry_h_inf > 0.0_real64 .or. retry_theta_inf > 0.0_real64 .or. &
         retry_storage_diff > 0.0_real64
  end if

  if (.not. b2_detected) then
    classification = 'D5_AUTHORITY_FAILURE'
  else if (b1_detected) then
    classification = 'EARLIER_DETECTION'
  else
    classification = 'UNIQUE_DETECTION'
  end if

  write(*,'(A,ES26.17E3)') 'PUB_ME_D5_FULL_REFINED_U_H_INF_CM=', full_refined_h_inf
  write(*,'(A,ES26.17E3)') 'PUB_ME_D5_FULL_REFINED_U_THETA_INF=', full_refined_theta_inf
  write(*,'(A,ES26.17E3)') 'PUB_ME_D5_WORKSPACE_ORIGIN_H_INF_CM=', workspace_origin_h_inf
  write(*,'(A,ES26.17E3)') 'PUB_ME_D5_WORKSPACE_ORIGIN_THETA_INF=', workspace_origin_theta_inf
  write(*,'(A,L1)') 'PUB_ME_D5_B2_PRE_RETRY_AUTHORITY_DETECTED=', b2_detected
  write(*,'(A,I0)') 'PUB_ME_D5_CLEAN_RETRY_STATUS=', clean_retry_result%status
  write(*,'(A,I0)') 'PUB_ME_D5_MUTANT_RETRY_STATUS=', mutant_retry_result%status
  write(*,'(A,L1)') 'PUB_ME_D5_B1_POST_RETRY_DETECTED=', b1_detected
  write(*,'(A,ES26.17E3)') 'PUB_ME_D5_RETRY_ENDPOINT_H_INF_CM=', retry_h_inf
  write(*,'(A,ES26.17E3)') 'PUB_ME_D5_RETRY_ENDPOINT_THETA_INF=', retry_theta_inf
  write(*,'(A,ES26.17E3)') 'PUB_ME_D5_RETRY_STORAGE_DIFF_CM=', retry_storage_diff
  write(*,'(A,A)') 'PUB_ME_D5_CLASSIFICATION=', trim(classification)
  write(*,'(A)') 'PUB_ME_D5_REFERENCE_WORKSPACE_AUTHORITY_EXPERIMENT=PASS'

contains

  subroutine require_reference_success(result, label)
    type(soil_water_solve_result_t), intent(in) :: result
    character(len=*), intent(in) :: label
    call require(result%status == SW_SOLVE_CONVERGED, trim(label)//' Reference solve converged')
    call require(trim(result%diagnostics%route) == 'legacy-reference-bound', trim(label)//' route identity')
    call require(result%integrated_mass_balance_residual_available, trim(label)//' integrated residual available')
    call require(ieee_is_finite(result%integrated_mass_balance_residual_cm), &
         trim(label)//' integrated mass residual finite')
  end subroutine require_reference_success

  subroutine initialize_parameter_contract(parameter_set, cofgen_out, mat)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t), intent(in) :: mat
    real(real64) :: m
    integer :: i
    m = 1.0_real64 - 1.0_real64 / mat%n
    parameter_set%parameter_set_id = 950501
    parameter_set%active_nodes = n
    allocate(parameter_set%z(n), parameter_set%dz(n), parameter_set%node_distance(n))
    do i = 1, n
      parameter_set%z(i) = -ROSSFAST_D3R_DZ_CM * (real(i,real64)-0.5_real64)
    end do
    parameter_set%dz = ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance = ROSSFAST_D3R_DZ_CM
    cofgen_out = 0.0_real64
    do i = 1, n
      cofgen_out(1,i)=mat%theta_r
      cofgen_out(2,i)=mat%theta_s
      cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm
      cofgen_out(5,i)=mat%lambda
      cofgen_out(6,i)=mat%n
      cofgen_out(7,i)=m
      cofgen_out(8,i)=mat%alpha_per_cm
      cofgen_out(9,i)=mat%h_enpr_cm
      cofgen_out(10,i)=mat%ksatfit_cm_per_day
      cofgen_out(11,i)=0.999_real64
      cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64
      cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req, parameter_set, hydraulic_provider, source_provider, top_provider, &
       head, theta, qtop, qbot, dt)
    type(soil_water_solve_request_t), intent(out) :: req
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), target, intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t), target, intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t), target, intent(in) :: top_provider
    real(real64), intent(in) :: head(n), theta(n), qtop, qbot, dt

    req%parameters => parameter_set
    req%base_state%active_nodes = n
    allocate(req%base_state%pressure_head(n), req%base_state%water_content(n))
    req%base_state%pressure_head = head
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
    req%numerical%compartment_balance_tolerance = reference_balance_rate_tol
    req%numerical%total_balance_tolerance = reference_balance_rate_tol
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
      write(*,'(A,1X,A)') 'PUB_ME_D5_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_me_d5_workspace_authority

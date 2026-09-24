program test_ppa_free_drainage_indicator
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_SOLVE_CONVERGED, &
       SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_ppa_free_drainage_stiffness, only: evaluate_free_drainage_stiffness
  use mod_ppa_free_drainage_temporal_indicator, only: evaluate_free_drainage_temporal_indicator
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: compare_scale = 32768.0_real64*epsilon(1.0_real64)
  real(real64), parameter :: q_values(5) = [-1.0e-6_real64, -1.0e-10_real64, 0.0_real64, &
                                             1.0e-10_real64,  1.0e-6_real64]
  real(real64), parameter :: dt_values(3) = [1.0e-2_real64, 1.0e-4_real64, 1.0_real64]
  integer :: iq, idt, isource, mode2_cases, wrong_dirichlet_separations

  mode2_cases = 0
  wrong_dirichlet_separations = 0
  do isource = 0, 2
  do idt = 1, size(dt_values)
    do iq = 1, size(q_values)
      call run_mode2_case(q_values(iq), dt_values(idt), isource, mode2_cases, wrong_dirichlet_separations)
    end do
  end do
  end do

  call require(mode2_cases == 3*size(q_values)*size(dt_values), 'complete free drainage/source matrix')
  call require(wrong_dirichlet_separations > 0, 'oracle distinguishes Neumann from Dirichlet bottom stiffness')
  write(*,'(A,I0)') 'FREE_DRAINAGE_MODE2_CASES=', mode2_cases
  write(*,'(A,I0)') 'FREE_DRAINAGE_WRONG_DIRICHLET_SEPARATIONS=', wrong_dirichlet_separations
  write(*,'(A)') 'FREE_DRAINAGE_MASS_LEDGER_AND_RETRY=PASS'
  write(*,'(A)') 'FREE_DRAINAGE_EXPLICIT_TEMPORAL_ORACLE=PASS'

contains

  subroutine run_mode2_case(q, step_dt, source_case, completed_cases, separated_cases)
    real(real64), intent(in) :: q, step_dt
    integer, intent(in) :: source_case
    integer, intent(inout) :: completed_cases, separated_cases
    type(soil_water_parameter_set_t), target :: parameters
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(b110_root_sink_provider_t), target :: root_provider
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace, comparison_workspace
    type(soil_water_solve_request_t) :: request, unsupported_request
    type(soil_water_solve_result_t) :: result, comparison_result
    type(soil_water_temporal_indicator_request_t) :: indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator, unsupported
    real(real64), target :: drainage(1,numnod), irrigation(numnod), root_sink(numnod)
    real(real64), target :: no_root(numnod)
    real(real64) :: cofgen(24,numnod)
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: candidate_water(numnod), candidate_k(numnod), candidate_capacity(numnod), candidate_dkdh(numnod)
    real(real64) :: expected_raw, expected_defect, expected_bounded, expected_binf, wrong_binf
    real(real64) :: storage0, storage1, total_in, total_out, ledger_residual, solver_mass
    real(real64) :: head_snapshot(numnod), water_snapshot(numnod), top_snapshot, bottom_snapshot, mass_snapshot
    integer :: nonlinear_before, jacobian_before, linear_before, backtracking_before, retries_before, status_snapshot
    integer :: i

    call configure_parameters(parameters, cofgen)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, step_dt)

    heads = h0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(ieee_is_finite(water)) .and. all(ieee_is_finite(conductivity)) .and. &
         all(ieee_is_finite(capacity)), 'finite base constitutive state')
    call require(all(conductivity > 0.0_real64) .and. all(capacity > 0.0_real64), &
         'positive base conductivity and capacity')

    drainage = 0.0_real64
    irrigation = 0.0_real64
    root_sink = 0.0_real64
    if (source_case == 1) irrigation = 1.0e-8_real64
    if (source_case == 2) then
      drainage = 1.0e-8_real64
      root_sink = 2.0e-8_real64
    end if
    no_root = 0.0_real64
    call bind_b110_source_sink_provider(source_sink, drainage, irrigation, no_root)
    call bind_b110_root_sink_provider(root_provider, root_sink)

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state%active_nodes = numnod
    allocate(request%base_state%pressure_head(numnod), request%base_state%water_content(numnod))
    request%base_state%pressure_head = heads
    request%base_state%water_content = water
    request%base_state%ponding_depth = 0.0_real64
    request%base_state%groundwater_level = -2.0_real64
    request%step_duration = step_dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 2
    request%boundary%top_flux = -conductivity(numnod)+q
    request%boundary%top_head = heads(1)
    request%boundary%bottom_flux = -conductivity(numnod)
    request%boundary%bottom_head = 777777.0_real64
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 16
    request%numerical%max_backtracking = 8
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-12_real64
    request%numerical%compartment_balance_tolerance = hard_mass_gate
    request%numerical%total_balance_tolerance = hard_mass_gate
    request%numerical%head_abs_tolerance = hard_mass_gate
    request%numerical%head_rel_tolerance = hard_mass_gate
    request%numerical%ponding_tolerance = hard_mass_gate
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%root_sink => root_provider
    request%evaluation%top_boundary => top_provider

    storage0 = sum(request%base_state%water_content*parameters%dz) + request%base_state%ponding_depth
    unsupported_request = request
    unsupported_request%boundary%bottom_mode = 7
    call solver%solve(unsupported_request, comparison_workspace, comparison_result)
    call require(comparison_result%status == SW_SOLVE_CONVERGED, 'real free drainage solve converged')
    call solver%solve(request, workspace, result)
    call constitutive%evaluate(comparison_result%candidate_state%pressure_head, candidate_water, candidate_k, &
         candidate_capacity, candidate_dkdh)
    call require(abs(comparison_result%bottom_flux+candidate_k(numnod))<1.0e-12_real64, &
         'mode7 uses candidate conductivity, not frozen base conductivity')
    call check_bottom_stiffness(constitutive,comparison_result%candidate_state%pressure_head)
    if(abs(q)>=1.0e-6_real64.and.step_dt>=1.0e-2_real64) then
      call require(abs(comparison_result%bottom_flux+conductivity(numnod))>1.0e-14_real64, &
           'transient mode7 differs from lagged Neumann hypothesis')
    end if
    call require(ieee_is_finite(comparison_result%unrounded_mass_balance_residual), 'mode7 finite mass diagnostic')
    call require(abs(comparison_result%unrounded_mass_balance_residual)<=hard_mass_gate, 'mode7 mass gate')
    call require(comparison_result%native_balance_rate_residual_available, 'mode7 native residual available')
    call require(comparison_result%integrated_mass_balance_residual_available, 'mode7 integrated residual available')
    storage1 = sum(comparison_result%candidate_state%water_content*parameters%dz)
    ledger_residual = storage1-storage0-step_dt*(comparison_result%bottom_flux-comparison_result%top_flux &
         +sum(irrigation)-sum(drainage)-sum(root_sink))
    call require(abs(ledger_residual)<=hard_mass_gate, 'independent mode7 storage flux ledger')
    call require(abs(ledger_residual-comparison_result%integrated_mass_balance_residual_cm)<=hard_mass_gate, &
         'mode7 integrated equation agrees with independent ledger')
    call require(comparison_result%integrated_mass_balance_residual_cm == &
         step_dt*comparison_result%native_balance_rate_residual_cm_per_day, 'mode7 residual units')
    call require(result%status == SW_SOLVE_CONVERGED, 'prescribed-qbot principal solve converged')
    call require(transfer(result%bottom_flux,0_int64) == transfer(-conductivity(numnod),0_int64), 'prescribed qbot exact identity')
    storage1 = sum(result%candidate_state%water_content*parameters%dz) + result%candidate_state%ponding_depth
    total_in = max(0.0_real64,-result%top_flux)*step_dt + max(0.0_real64,result%bottom_flux)*step_dt
    total_out = max(0.0_real64,result%top_flux)*step_dt + max(0.0_real64,-result%bottom_flux)*step_dt
    ledger_residual = storage1-storage0-(total_in-total_out) &
         -step_dt*(sum(irrigation)-sum(drainage)-sum(root_sink))
    solver_mass = result%unrounded_mass_balance_residual
    call require(ieee_is_finite(solver_mass), 'finite solver mass residual')
    call require(max(abs(ledger_residual),abs(solver_mass)) <= hard_mass_gate, 'hard mass gate before certificate')

    head_snapshot = result%candidate_state%pressure_head
    water_snapshot = result%candidate_state%water_content
    top_snapshot = result%top_flux
    bottom_snapshot = result%bottom_flux
    mass_snapshot = result%unrounded_mass_balance_residual
    status_snapshot = result%status
    nonlinear_before = workspace%legacy_worker%diagnostics%nonlinear_iterations
    jacobian_before = workspace%legacy_worker%diagnostics%jacobian_builds
    linear_before = workspace%legacy_worker%diagnostics%linear_solves
    backtracking_before = workspace%legacy_worker%diagnostics%backtracking_attempts
    retries_before = workspace%legacy_worker%diagnostics%internal_retries

    indicator_request%previous_right_derivative_available = .true.
    allocate(indicator_request%previous_right_derivative(numnod))
    indicator_request%previous_right_derivative = 0.0_real64
    call solver%evaluate_temporal_indicator(request, result, indicator_request, workspace, indicator)

    call require(indicator%status == SW_TEMPORAL_INDICATOR_AVAILABLE .and. indicator%available, &
         'mode2 temporal indicator available')
    call require(indicator%additional_full_nonlinear_solves == 0, 'mode2 indicator no extra nonlinear trajectory')
    call require(indicator%additional_tridiagonal_solves == 1, 'mode2 indicator one defect tridiagonal solve')
    call require(allocated(indicator%current_right_derivative), 'mode2 current derivative available')
    call require(all(ieee_is_finite(indicator%current_right_derivative)), 'mode2 finite current derivative')
    call require(ieee_is_finite(indicator%head_inf_bound) .and. indicator%head_inf_bound >= 0.0_real64, &
         'mode2 finite nonnegative Binf')

    call constitutive%evaluate(result%candidate_state%pressure_head, candidate_water, candidate_k, &
         candidate_capacity, candidate_dkdh)
    call independent_mode2_oracle(parameters, conductivity, candidate_capacity, &
         indicator%current_right_derivative, step_dt, expected_raw, expected_defect, expected_bounded, expected_binf, wrong_binf)

    call require(close_value(indicator%raw_m_norm, expected_raw), 'independent raw norm oracle')
    call require(close_value(indicator%defect_m_norm, expected_defect), 'independent Neumann defect norm oracle')
    call require(close_value(indicator%bounded_m_norm, expected_bounded), 'independent bounded norm oracle')
    call require(close_value(indicator%head_inf_bound, expected_binf), 'independent Neumann Binf oracle')
    call require(close_value(indicator%min_mass_weight, minval(candidate_capacity*parameters%dz)), &
         'independent minimum mass weight oracle')

    if (abs(expected_binf-wrong_binf) > &
             1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(expected_binf),abs(wrong_binf))) then
      separated_cases = separated_cases + 1
    end if

    call require(maxval(abs(result%candidate_state%pressure_head-head_snapshot)) == 0.0_real64, &
         'indicator does not mutate candidate heads')
    call require(maxval(abs(result%candidate_state%water_content-water_snapshot)) == 0.0_real64, &
         'indicator does not mutate candidate water')
    call require(transfer(result%top_flux,0_int64) == transfer(top_snapshot,0_int64), &
         'indicator does not mutate top flux')
    call require(transfer(result%bottom_flux,0_int64) == transfer(bottom_snapshot,0_int64), &
         'indicator does not mutate bottom flux')
    call require(transfer(result%unrounded_mass_balance_residual,0_int64) == transfer(mass_snapshot,0_int64), &
         'indicator does not mutate mass diagnostic')
    call require(result%status == status_snapshot, 'indicator does not mutate solver status')
    call require(workspace%legacy_worker%diagnostics%nonlinear_iterations == nonlinear_before, &
         'indicator does not add nonlinear iterations')
    call require(workspace%legacy_worker%diagnostics%jacobian_builds == jacobian_before, &
         'indicator does not rebuild principal Jacobian')
    call require(workspace%legacy_worker%diagnostics%linear_solves == linear_before, &
         'indicator does not alter principal linear solve counter')
    call require(workspace%legacy_worker%diagnostics%backtracking_attempts == backtracking_before, &
         'indicator does not alter backtracking counter')
    call require(workspace%legacy_worker%diagnostics%internal_retries == retries_before, &
         'indicator does not alter solver retry counter')

    unsupported_request = request
    unsupported_request%boundary%bottom_mode = 7
    call solver%evaluate_temporal_indicator(unsupported_request, result, indicator_request, workspace, unsupported)
    call require(unsupported%status == SW_TEMPORAL_INDICATOR_UNAVAILABLE .and. .not. unsupported%available, &
         'unowned bottom mode remains unavailable')
    call require(trim(unsupported%route) == 'boundary-envelope-deferred', &
         'unowned bottom mode fails closed at boundary envelope')

    call check_mode7_indicator(unsupported_request,comparison_result,indicator_request,constitutive,conductivity)
    hydraulic_parameters%ksatexm_extension_enabled = .true.
    call evaluate_free_drainage_temporal_indicator(unsupported_request,comparison_result,indicator_request,unsupported)
    call require(.not.unsupported%available,'Ksatexm temporal extension unavailable')
    hydraulic_parameters%ksatexm_extension_enabled = .false.
    unsupported_request%numerical%max_iterations = 1
    unsupported_request%boundary%top_flux = -1.0_real64
    call solver%solve(unsupported_request, comparison_workspace, comparison_result)
    call require(comparison_result%status /= SW_SOLVE_CONVERGED, 'forced retry does not converge')
    call require(.not.comparison_result%native_balance_rate_residual_available, 'retry has no native diagnostic')
    call require(.not.comparison_result%integrated_mass_balance_residual_available, 'retry has no integrated diagnostic')
    call require(.not.ieee_is_finite(comparison_result%unrounded_mass_balance_residual), 'retry compatibility field unavailable')
    call require(all(request%base_state%pressure_head == heads), 'retry preserves committed base heads')
    call require(all(request%base_state%water_content == water), 'retry preserves committed base water')
    completed_cases = completed_cases + 1
    write(*,'(A,ES16.8E3,A,ES16.8E3,A,ES26.17E3,A,ES26.17E3,A,A)') &
         'FREE_DRAINAGE_MODE2_ROW q=',q,':dt=',step_dt,':BINF=',indicator%head_inf_bound, &
         ':WRONG_DIRICHLET_BINF=',wrong_binf,':ROUTE=',trim(indicator%route)
  end subroutine run_mode2_case

  subroutine check_mode7_indicator(request,result,history,provider,base_k)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: result
    type(soil_water_temporal_indicator_request_t), intent(in) :: history
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64), intent(in) :: base_k(:)
    type(soil_water_temporal_indicator_result_t) :: certificate
    type(soil_water_solve_result_t) :: invalid
    type(soil_water_temporal_indicator_request_t) :: no_history
    real(real64) :: heads(numnod), water(numnod), k(numnod), c(numnod), dk(numnod)
    real(real64) :: plus, minus, slope, raw, defect, bounded, binf, wrong
    heads = result%candidate_state%pressure_head
    heads(numnod) = heads(numnod)+0.0005_real64
    call provider%evaluate(heads,water,k,c,dk)
    plus = k(numnod)
    heads(numnod) = heads(numnod)-0.001_real64
    call provider%evaluate(heads,water,k,c,dk)
    minus = k(numnod)
    slope = (plus-minus)/0.001_real64
    call provider%evaluate(result%candidate_state%pressure_head,water,k,c,dk)
    call evaluate_free_drainage_temporal_indicator(request,result,history,certificate)
    call require(certificate%available,'mode7 explicit temporal service available')
    call require(certificate%additional_full_nonlinear_solves==0,'mode7 no extra nonlinear trajectory')
    call require(certificate%additional_tridiagonal_solves==1,'mode7 one defect solve')
    call independent_mode2_oracle(request%parameters,base_k,c,certificate%current_right_derivative, &
         request%step_duration,raw,defect,bounded,binf,wrong,slope)
    call require(abs(certificate%defect_m_norm-defect)<=1.0e-8_real64*max(abs(defect),1.0e-14_real64), &
         'mode7 independent finite difference stiffness defect oracle')
    call require(abs(certificate%head_inf_bound-binf)<=1.0e-8_real64*max(abs(binf),1.0e-14_real64), &
         'mode7 independent bound oracle')
    invalid = result
    invalid%bottom_flux = invalid%bottom_flux+1.0e-4_real64
    call evaluate_free_drainage_temporal_indicator(request,invalid,history,certificate)
    call require(.not.certificate%available,'mode7 inconsistent flux rejected')
    call evaluate_free_drainage_temporal_indicator(request,result,no_history,certificate)
    call require(.not.certificate%available,'mode7 missing history unavailable')
  end subroutine

  subroutine check_bottom_stiffness(provider, heads)
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64), intent(in) :: heads(:)
    real(real64) :: perturbed(size(heads)), water(size(heads)), k(size(heads)), c(size(heads)), reserved(size(heads))
    real(real64) :: stiffness, plus, minus, numerical, step
    logical :: available
    integer :: n, j
    n = size(heads)
    call evaluate_free_drainage_stiffness(provider,heads,stiffness,available)
    call require(available.and.stiffness>0.0_real64,'smooth free drainage stiffness available positive')
    do j=1,2
      step = 1.0e-3_real64/real(j,real64)
      perturbed = heads
      perturbed(n) = heads(n)+step
      call provider%evaluate(perturbed,water,k,c,reserved)
      plus = k(n)
      perturbed(n) = heads(n)-step
      call provider%evaluate(perturbed,water,k,c,reserved)
      minus = k(n)
      numerical = (plus-minus)/(2*step)
      call require(abs(stiffness-numerical)<1.0e-7_real64*abs(numerical), &
           'mode7 stiffness agrees with independent central difference of residual K')
    end do
    perturbed = heads
    perturbed(n) = 0.0_real64
    call evaluate_free_drainage_stiffness(provider,perturbed,stiffness,available)
    call require(.not.available,'constitutive switch stiffness unavailable')
  end subroutine

  subroutine independent_mode2_oracle(parameters, conductivity_base, capacity_candidate, current_derivative, step_dt, &
                                      raw_norm, defect_norm, bounded_norm, binf, wrong_dirichlet_binf, bottom_stiffness)
    type(soil_water_parameter_set_t), intent(in) :: parameters
    real(real64), intent(in) :: conductivity_base(:), capacity_candidate(:), current_derivative(:), step_dt
    real(real64), intent(out) :: raw_norm, defect_norm, bounded_norm, binf, wrong_dirichlet_binf
    real(real64), intent(in), optional :: bottom_stiffness
    real(real64) :: mass_weight(numnod), lower(numnod), diagonal(numnod), upper(numnod), rhs(numnod)
    real(real64) :: delta(numnod), wrong_delta(numnod), e_raw(numnod), wrong_diag(numnod)
    real(real64) :: face_conductance, wrong_defect, wrong_bounded
    logical :: ok
    integer :: i

    mass_weight = capacity_candidate*parameters%dz
    e_raw = 0.5_real64*step_dt*current_derivative
    lower = 0.0_real64
    diagonal = mass_weight/step_dt
    upper = 0.0_real64
    do i = 2, numnod
      face_conductance = 0.5_real64*(conductivity_base(i-1)+conductivity_base(i))/parameters%node_distance(i)
      lower(i) = -face_conductance
      upper(i-1) = -face_conductance
      diagonal(i-1) = diagonal(i-1)+face_conductance
      diagonal(i) = diagonal(i)+face_conductance
    end do
    if(present(bottom_stiffness)) diagonal(numnod) = diagonal(numnod)+bottom_stiffness
    rhs = (mass_weight/step_dt)*e_raw
    call local_thomas(lower, diagonal, upper, rhs, delta, ok)
    call require(ok, 'independent Neumann tridiagonal solve')

    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
    defect_norm = sqrt(sum(mass_weight*delta*delta))
    bounded_norm = min(raw_norm,2.0_real64*defect_norm)
    binf = bounded_norm/sqrt(minval(mass_weight))

    wrong_diag = diagonal
    face_conductance = conductivity_base(numnod)/(0.5_real64*parameters%dz(numnod))
    wrong_diag(numnod) = wrong_diag(numnod)+face_conductance
    call local_thomas(lower, wrong_diag, upper, rhs, wrong_delta, ok)
    call require(ok, 'independent wrong-Dirichlet comparison solve')
    wrong_defect = sqrt(sum(mass_weight*wrong_delta*wrong_delta))
    wrong_bounded = min(raw_norm,2.0_real64*wrong_defect)
    wrong_dirichlet_binf = wrong_bounded/sqrt(minval(mass_weight))
  end subroutine independent_mode2_oracle

  subroutine local_thomas(lower, diagonal, upper, rhs, solution, ok)
    real(real64), intent(in) :: lower(:), diagonal(:), upper(:), rhs(:)
    real(real64), intent(out) :: solution(:)
    logical, intent(out) :: ok
    real(real64) :: c(size(rhs)), d(size(rhs)), denom, scale
    integer :: i, n

    n = size(rhs)
    ok = .false.
    solution = 0.0_real64
    if (n <= 0 .or. size(lower) /= n .or. size(diagonal) /= n .or. size(upper) /= n .or. size(solution) /= n) return
    scale = max(1.0_real64,maxval(abs(diagonal)),maxval(abs(lower)),maxval(abs(upper)))
    if (abs(diagonal(1)) <= epsilon(1.0_real64)*scale) return
    c = 0.0_real64
    d = 0.0_real64
    if (n > 1) c(1) = upper(1)/diagonal(1)
    d(1) = rhs(1)/diagonal(1)
    do i = 2, n
      denom = diagonal(i)-lower(i)*c(i-1)
      if (abs(denom) <= epsilon(1.0_real64)*scale) return
      if (i < n) c(i) = upper(i)/denom
      d(i) = (rhs(i)-lower(i)*d(i-1))/denom
    end do
    solution(n) = d(n)
    do i = n-1, 1, -1
      solution(i) = d(i)-c(i)*solution(i+1)
    end do
    ok = all(ieee_is_finite(solution))
  end subroutine local_thomas

  subroutine configure_parameters(parameters, cofgen)
    type(soil_water_parameter_set_t), target, intent(out) :: parameters
    real(real64), intent(out) :: cofgen(24,numnod)
    integer :: i

    parameters%parameter_set_id = 380038_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    cofgen = 0.0_real64
    do i = 1, numnod
      cofgen(1,i)=0.032_real64; cofgen(2,i)=0.423_real64; cofgen(3,i)=4.75_real64
      cofgen(4,i)=0.0135_real64; cofgen(5,i)=0.365_real64; cofgen(6,i)=1.455_real64
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
      cofgen(9,i)=0.0_real64; cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64
      cofgen(12,i)=0.99_real64*cofgen(3,i); cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
    end do
  end subroutine configure_parameters

  pure logical function close_value(actual, expected)
    real(real64), intent(in) :: actual, expected
    real(real64) :: scale
    scale = max(1.0_real64,abs(actual),abs(expected))
    close_value = ieee_is_finite(actual) .and. ieee_is_finite(expected) .and. &
         abs(actual-expected) <= compare_scale*scale
  end function close_value

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FREE_DRAINAGE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_free_drainage_indicator

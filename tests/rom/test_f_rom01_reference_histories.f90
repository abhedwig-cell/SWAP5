program test_f_rom01_reference_histories
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = 16
  integer, parameter :: root_nodes = 4
  integer, parameter :: phase_steps = 48
  integer, parameter :: continuation_steps = 24
  real(real64), parameter :: dz_cm = 10.0_real64
  real(real64), parameter :: dt_day = 0.0016_real64
  real(real64), parameter :: mass_tol_cm = 1.0e-12_real64
  real(real64), parameter :: collision_storage_tol_cm = 1.0e-8_real64
  real(real64), parameter :: distinct_theta_rms_min = 1.0e-10_real64
  integer, parameter :: max_retry_depth = 8
  real(real64), parameter :: min_internal_duration_day = dt_day / real(2**max_retry_depth, real64)

  ! F-ROM01 research fixture B01. Provenance is frozen in
  ! integration/f-rom/F-ROM01_REFERENCE_HISTORY_PILOT_CONTRACT.json.
  real(real64), parameter :: theta_r = 0.02_real64
  real(real64), parameter :: theta_s = 0.427494_real64
  real(real64), parameter :: alpha_per_cm = 0.021659_real64
  real(real64), parameter :: vg_n = 1.734737_real64
  real(real64), parameter :: ksatfit_cm_per_day = 31.225016_real64
  real(real64), parameter :: lambda_mvg = 0.98087_real64
  real(real64), parameter :: h_enpr_cm = 0.0_real64
  real(real64), parameter :: initial_se = 0.85_real64

  real(real64), parameter :: wet_top_factor = 0.025_real64
  real(real64), parameter :: dry_top_factor = -0.005_real64
  real(real64), parameter :: history_bottom_factor = -0.004_real64
  real(real64), parameter :: continuation_top_factor = 0.010_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  type(reference_richards_legacy_solver_t) :: solver_a, solver_b
  type(reference_richards_legacy_workspace_t) :: workspace_a, workspace_b
  type(soil_water_solve_request_t) :: request_a, request_b
  type(soil_water_physical_state_t) :: initial_state, state_a, state_b
  type(soil_water_physical_state_t) :: collision_a, collision_b
  type(soil_water_solve_result_t) :: result_a, result_b

  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: cofgen(24,n), heads(n), theta0(n), conductivity(n), capacity(n), dkdh(n)
  real(real64) :: h0, k0, q_wet, q_dry, q_history_bottom, q_cont
  real(real64) :: s_total_a, s_total_b, s_root_a, s_root_b, moment_a, moment_b
  real(real64) :: collision_storage_diff, collision_root_diff, collision_theta_rms, collision_h_rms
  real(real64) :: max_mass_a, max_mass_b
  real(real64) :: cont_s_a, cont_s_b, cont_root_a, cont_root_b
  real(real64) :: cont_theta_rms, cont_h_rms, cont_qbot_diff
  real(real64) :: outer_qbot_a, outer_qbot_b
  integer :: i, accepted_substeps_a, accepted_substeps_b, retry_attempts_a, retry_attempts_b

  call initialize_parameter_contract(parameters, cofgen)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt_day)

  h0 = head_from_effective_saturation(initial_se)
  heads = h0
  call constitutive%evaluate(heads, theta0, conductivity, capacity, dkdh)
  call require(all(ieee_is_finite(theta0)), 'initial theta finite')
  call require(all(ieee_is_finite(conductivity)) .and. all(conductivity > 0.0_real64), &
       'initial conductivity finite and positive')
  k0 = conductivity(1)

  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

  call initialize_state(initial_state, theta0, h0)
  state_a = initial_state
  state_b = initial_state
  call initialize_request(request_a, parameters, constitutive, source_sink, top_boundary, initial_state)
  call initialize_request(request_b, parameters, constitutive, source_sink, top_boundary, initial_state)

  q_wet = wet_top_factor * k0
  q_dry = dry_top_factor * k0
  q_history_bottom = history_bottom_factor * k0
  q_cont = continuation_top_factor * k0
  max_mass_a = 0.0_real64
  max_mass_b = 0.0_real64
  accepted_substeps_a = 0
  accepted_substeps_b = 0
  retry_attempts_a = 0
  retry_attempts_b = 0

  ! Deliberate Z1 collision construction. Both histories receive the same
  ! integrated external fluxes; only the order differs.
  call run_phase('A_WET', phase_steps, q_wet, q_history_bottom, state_a, request_a, solver_a, workspace_a, &
       max_mass_a, accepted_substeps_a, retry_attempts_a)
  call run_phase('A_DRY', phase_steps, q_dry, q_history_bottom, state_a, request_a, solver_a, workspace_a, &
       max_mass_a, accepted_substeps_a, retry_attempts_a)
  call run_phase('B_DRY', phase_steps, q_dry, q_history_bottom, state_b, request_b, solver_b, workspace_b, &
       max_mass_b, accepted_substeps_b, retry_attempts_b)
  call run_phase('B_WET', phase_steps, q_wet, q_history_bottom, state_b, request_b, solver_b, workspace_b, &
       max_mass_b, accepted_substeps_b, retry_attempts_b)

  collision_a = state_a
  collision_b = state_b

  s_total_a = total_storage(collision_a, parameters)
  s_total_b = total_storage(collision_b, parameters)
  s_root_a = root_storage(collision_a, parameters)
  s_root_b = root_storage(collision_b, parameters)
  moment_a = first_depth_moment(collision_a, parameters)
  moment_b = first_depth_moment(collision_b, parameters)
  collision_storage_diff = abs(s_total_a - s_total_b)
  collision_root_diff = abs(s_root_a - s_root_b)
  collision_theta_rms = rms_difference(collision_a%water_content, collision_b%water_content)
  collision_h_rms = rms_difference(collision_a%pressure_head, collision_b%pressure_head)

  call require(collision_storage_diff <= collision_storage_tol_cm, 'deliberate Z1 total-storage collision')
  call require(collision_theta_rms > distinct_theta_rms_min, 'collision histories retain distinct full profiles')

  write(*,'(*(g0))') 'F_ROM01_AUTHORITY|BASELINE=0e68a716f655f9bba3a0962cf35ccb724b5184c3', &
       '|MATERIAL=B01|N=',n,'|DZ_CM=',dz_cm,'|DT_DAY=',dt_day,'|PHASE_STEPS=',phase_steps
  write(*,'(*(g0))') 'F_ROM01_INITIAL|SE=',initial_se,'|H0_CM=',h0,'|K0_CM_PER_DAY=',k0, &
       '|Q_WET=',q_wet,'|Q_DRY=',q_dry,'|Q_HISTORY_BOTTOM=',q_history_bottom,'|Q_CONT=',q_cont
  write(*,'(*(g0))') 'F_ROM01_COLLISION|S_TOTAL_A_CM=',s_total_a,'|S_TOTAL_B_CM=',s_total_b, &
       '|D_S_TOTAL_CM=',collision_storage_diff,'|S_ROOT_A_CM=',s_root_a,'|S_ROOT_B_CM=',s_root_b, &
       '|D_S_ROOT_CM=',collision_root_diff,'|M1_A_CM2=',moment_a,'|M1_B_CM2=',moment_b, &
       '|THETA_RMS=',collision_theta_rms,'|H_RMS_CM=',collision_h_rms
  write(*,'(*(g0))') 'F_ROM01_HISTORY_MASS|MAX_A_CM=',max_mass_a,'|MAX_B_CM=',max_mass_b
  write(*,'(*(g0))') 'F_ROM01_HISTORY_EXECUTION|ACCEPTED_SUBSTEPS_A=',accepted_substeps_a, &
       '|RETRY_ATTEMPTS_A=',retry_attempts_a,'|ACCEPTED_SUBSTEPS_B=',accepted_substeps_b, &
       '|RETRY_ATTEMPTS_B=',retry_attempts_b,'|MAX_RETRY_DEPTH=',max_retry_depth, &
       '|MIN_INTERNAL_DT_DAY=',min_internal_duration_day

  ! Identical continuation under a prescribed lower-boundary head. Unlike the
  ! history construction, qbot is now an output, so hidden-profile information
  ! is allowed to reveal itself in future hydraulic response.
  state_a = collision_a
  state_b = collision_b
  do i = 1, continuation_steps
     call run_outer_interval('CONT_A', q_cont, 5, 0.0_real64, h0, state_a, request_a, solver_a, workspace_a, &
          outer_qbot_a, max_mass_a, accepted_substeps_a, retry_attempts_a)
     call run_outer_interval('CONT_B', q_cont, 5, 0.0_real64, h0, state_b, request_b, solver_b, workspace_b, &
          outer_qbot_b, max_mass_b, accepted_substeps_b, retry_attempts_b)

     if (i == 1 .or. i == 8 .or. i == continuation_steps) then
        cont_s_a = total_storage(state_a, parameters)
        cont_s_b = total_storage(state_b, parameters)
        cont_root_a = root_storage(state_a, parameters)
        cont_root_b = root_storage(state_b, parameters)
        cont_theta_rms = rms_difference(state_a%water_content, state_b%water_content)
        cont_h_rms = rms_difference(state_a%pressure_head, state_b%pressure_head)
        cont_qbot_diff = abs(outer_qbot_a - outer_qbot_b)
        write(*,'(*(g0))') 'F_ROM01_CONTINUATION|STEP=',i,'|QBOT_A=',outer_qbot_a, &
             '|QBOT_B=',outer_qbot_b,'|D_QBOT=',cont_qbot_diff, &
             '|S_TOTAL_A_CM=',cont_s_a,'|S_TOTAL_B_CM=',cont_s_b,'|D_S_TOTAL_CM=',abs(cont_s_a-cont_s_b), &
             '|S_ROOT_A_CM=',cont_root_a,'|S_ROOT_B_CM=',cont_root_b,'|D_S_ROOT_CM=',abs(cont_root_a-cont_root_b), &
             '|THETA_RMS=',cont_theta_rms,'|H_RMS_CM=',cont_h_rms
     end if
  end do

  write(*,'(*(g0))') 'F_ROM01_ALL_MASS|MAX_A_CM=',max_mass_a,'|MAX_B_CM=',max_mass_b
  write(*,'(*(g0))') 'F_ROM01_ALL_EXECUTION|ACCEPTED_SUBSTEPS_A=',accepted_substeps_a, &
       '|RETRY_ATTEMPTS_A=',retry_attempts_a,'|ACCEPTED_SUBSTEPS_B=',accepted_substeps_b, &
       '|RETRY_ATTEMPTS_B=',retry_attempts_b
  write(*,'(A)') 'F_ROM01_PRODUCTION_SOURCE_MUTATION=NONE'
  write(*,'(A)') 'F_ROM01_REJECTED_RETRY_COMMIT=NONE'
  write(*,'(A)') 'F_ROM01_V2_EXECUTION_POLICY=BOUNDED_BISECTION'
  write(*,'(A)') 'F_ROM01_SCIENTIFIC_SUFFICIENCY_VERDICT=NOT_SET_IN_PILOT'
  write(*,'(A)') 'F_ROM01_REFERENCE_HISTORY_PILOT=PASS'

contains

  subroutine initialize_parameter_contract(parameter_set, cofgen_out)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_out(24,n)
    real(real64) :: m
    integer :: j

    m = 1.0_real64 - 1.0_real64 / vg_n
    parameter_set%parameter_set_id = 9401001
    parameter_set%active_nodes = n
    allocate(parameter_set%z(n), parameter_set%dz(n), parameter_set%node_distance(n))
    do j = 1, n
       parameter_set%z(j) = -dz_cm * (real(j,real64) - 0.5_real64)
    end do
    parameter_set%dz = dz_cm
    parameter_set%node_distance = dz_cm

    cofgen_out = 0.0_real64
    do j = 1, n
       cofgen_out(1,j) = theta_r
       cofgen_out(2,j) = theta_s
       cofgen_out(3,j) = ksatfit_cm_per_day
       cofgen_out(4,j) = alpha_per_cm
       cofgen_out(5,j) = lambda_mvg
       cofgen_out(6,j) = vg_n
       cofgen_out(7,j) = m
       cofgen_out(8,j) = alpha_per_cm
       cofgen_out(9,j) = h_enpr_cm
       cofgen_out(10,j) = ksatfit_cm_per_day
       cofgen_out(11,j) = 0.999_real64
       cofgen_out(12,j) = 0.99_real64 * ksatfit_cm_per_day
       cofgen_out(22,j) = -1.0e6_real64
       cofgen_out(23,j) = 1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_state(state, theta, h)
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), intent(in) :: theta(n), h

    state%active_nodes = n
    allocate(state%pressure_head(n), state%water_content(n))
    state%pressure_head = h
    state%water_content = theta
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -999.0_real64
  end subroutine initialize_state

  subroutine initialize_request(req, parameter_set, hydraulic_provider, source_provider, top_provider, base)
    type(soil_water_solve_request_t), intent(out) :: req
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), target, intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t), target, intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t), target, intent(in) :: top_provider
    type(soil_water_physical_state_t), intent(in) :: base

    req%parameters => parameter_set
    req%base_state = base
    req%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode = 2
    req%boundary%top_flux = 0.0_real64
    req%boundary%top_head = h0
    req%boundary%bottom_flux = 0.0_real64
    req%boundary%bottom_head = h0
    req%physical%macropore_active = .false.
    req%numerical%max_iterations = 16
    req%numerical%max_backtracking = 8
    req%numerical%conductivity_implicit_mode = 0
    req%numerical%conductivity_mean_method = 1
    req%numerical%min_step_duration = 1.0e-8_real64
    req%numerical%compartment_balance_tolerance = 1.0e-12_real64
    req%numerical%total_balance_tolerance = 1.0e-12_real64
    req%numerical%head_abs_tolerance = 1.0e-12_real64
    req%numerical%head_rel_tolerance = 1.0e-12_real64
    req%numerical%ponding_tolerance = 1.0e-12_real64
    req%step_duration = dt_day
    req%request_interface_sensitivity = .false.
    req%evaluation%constitutive => hydraulic_provider
    req%evaluation%source_sink => source_provider
    req%evaluation%top_boundary => top_provider
  end subroutine initialize_request

  subroutine run_phase(label, steps, qtop, qbot, state, req, solver, workspace, max_mass, accepted_substeps, retry_attempts)
    character(len=*), intent(in) :: label
    integer, intent(in) :: steps
    real(real64), intent(in) :: qtop, qbot
    type(soil_water_physical_state_t), intent(inout) :: state
    type(soil_water_solve_request_t), intent(inout) :: req
    type(reference_richards_legacy_solver_t), intent(inout) :: solver
    type(reference_richards_legacy_workspace_t), intent(inout) :: workspace
    real(real64), intent(inout) :: max_mass
    integer, intent(inout) :: accepted_substeps, retry_attempts
    real(real64) :: outer_qbot
    integer :: j

    do j = 1, steps
       call run_outer_interval(label, qtop, 2, qbot, h0, state, req, solver, workspace, outer_qbot, &
            max_mass, accepted_substeps, retry_attempts)
    end do
  end subroutine run_phase

  subroutine run_outer_interval(label, qtop, bottom_mode, qbot, hbot, state, req, solver, workspace, &
                                outer_qbot, max_mass, accepted_substeps, retry_attempts)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: qtop, qbot, hbot
    integer, intent(in) :: bottom_mode
    type(soil_water_physical_state_t), intent(inout) :: state
    type(soil_water_solve_request_t), intent(inout) :: req
    type(reference_richards_legacy_solver_t), intent(inout) :: solver
    type(reference_richards_legacy_workspace_t), intent(inout) :: workspace
    real(real64), intent(out) :: outer_qbot
    real(real64), intent(inout) :: max_mass
    integer, intent(inout) :: accepted_substeps, retry_attempts
    real(real64) :: integrated_qbot

    integrated_qbot = 0.0_real64
    call advance_segment(label, qtop, bottom_mode, qbot, hbot, dt_day, 0, state, req, solver, workspace, &
         integrated_qbot, max_mass, accepted_substeps, retry_attempts)
    outer_qbot = integrated_qbot / dt_day
  end subroutine run_outer_interval

  recursive subroutine advance_segment(label, qtop, bottom_mode, qbot, hbot, duration, depth, state, req, &
                                       solver, workspace, integrated_qbot, max_mass, accepted_substeps, retry_attempts)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: qtop, qbot, hbot, duration
    integer, intent(in) :: bottom_mode, depth
    type(soil_water_physical_state_t), intent(inout) :: state
    type(soil_water_solve_request_t), intent(inout) :: req
    type(reference_richards_legacy_solver_t), intent(inout) :: solver
    type(reference_richards_legacy_workspace_t), intent(inout) :: workspace
    real(real64), intent(inout) :: integrated_qbot, max_mass
    integer, intent(inout) :: accepted_substeps, retry_attempts

    type(soil_water_solve_result_t) :: result
    real(real64) :: half_duration

    req%base_state = state
    req%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux = qtop
    req%boundary%top_head = state%pressure_head(1)
    req%boundary%bottom_mode = bottom_mode
    req%boundary%bottom_flux = qbot
    req%boundary%bottom_head = hbot
    req%step_duration = duration

    call solver%solve(req, workspace, result)

    if (result%status == SW_SOLVE_RETRY_ADVISED) then
       retry_attempts = retry_attempts + 1
       write(*,'(*(g0))') 'F_ROM01_RETRY|LABEL=',trim(label),'|DEPTH=',depth,'|DT_DAY=',duration, &
            '|ROUTE=',trim(result%diagnostics%route),'|NONLINEAR_ITERS=',result%diagnostics%nonlinear_iterations, &
            '|LINEAR_SOLVES=',result%diagnostics%linear_solves,'|BACKTRACK=',result%diagnostics%backtracking_attempts
       call require(result%retry_advised, trim(label)//' retry status carries retry flag')
       call require(depth < max_retry_depth, trim(label)//' retry depth bounded')
       half_duration = 0.5_real64 * duration
       call require(half_duration >= min_internal_duration_day, trim(label)//' retry duration bounded')
       call advance_segment(label, qtop, bottom_mode, qbot, hbot, half_duration, depth+1, state, req, solver, &
            workspace, integrated_qbot, max_mass, accepted_substeps, retry_attempts)
       call advance_segment(label, qtop, bottom_mode, qbot, hbot, half_duration, depth+1, state, req, solver, &
            workspace, integrated_qbot, max_mass, accepted_substeps, retry_attempts)
       return
    end if

    if (result%status /= SW_SOLVE_CONVERGED) then
       write(*,'(*(g0))') 'F_ROM01_SOLVER_FAILURE|LABEL=',trim(label),'|STATUS=',result%status, &
            '|RETRY=',result%retry_advised,'|ROUTE=',trim(result%diagnostics%route), &
            '|NONLINEAR_ITERS=',result%diagnostics%nonlinear_iterations, &
            '|JACOBIAN_BUILDS=',result%diagnostics%jacobian_builds, &
            '|LINEAR_SOLVES=',result%diagnostics%linear_solves, &
            '|BACKTRACK=',result%diagnostics%backtracking_attempts, &
            '|INTERNAL_RETRIES=',result%diagnostics%internal_retries, &
            '|MASS_AVAILABLE=',result%integrated_mass_balance_residual_available
       call require(.false., trim(label)//' converged or retry-advised')
    end if

    call require(trim(result%diagnostics%route) == 'legacy-reference-bound', trim(label)//' reference route')
    call require(result%integrated_mass_balance_residual_available, trim(label)//' mass diagnostic available')
    call require(ieee_is_finite(result%integrated_mass_balance_residual_cm), trim(label)//' mass residual finite')
    call require(abs(result%integrated_mass_balance_residual_cm) <= mass_tol_cm, trim(label)//' mass residual bounded')
    call require(ieee_is_finite(result%top_flux) .and. ieee_is_finite(result%bottom_flux), trim(label)//' flux finite')
    call require(same_real(result%top_flux, qtop), trim(label)//' prescribed top flux preserved')
    if (bottom_mode == 2) call require(same_real(result%bottom_flux, qbot), trim(label)//' prescribed bottom flux preserved')
    call require(result%candidate_state%active_nodes == n, trim(label)//' candidate shape')
    call require(allocated(result%candidate_state%pressure_head) .and. &
         allocated(result%candidate_state%water_content), trim(label)//' candidate arrays')
    call require(all(ieee_is_finite(result%candidate_state%pressure_head)), trim(label)//' candidate head finite')
    call require(all(ieee_is_finite(result%candidate_state%water_content)), trim(label)//' candidate theta finite')

    max_mass = max(max_mass, abs(result%integrated_mass_balance_residual_cm))
    integrated_qbot = integrated_qbot + duration * result%bottom_flux
    accepted_substeps = accepted_substeps + 1
    state = result%candidate_state
  end subroutine advance_segment

  pure real(real64) function total_storage(state, parameter_set) result(storage)
    type(soil_water_physical_state_t), intent(in) :: state
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    storage = sum(parameter_set%dz * state%water_content) + state%ponding_depth
  end function total_storage

  pure real(real64) function root_storage(state, parameter_set) result(storage)
    type(soil_water_physical_state_t), intent(in) :: state
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    storage = sum(parameter_set%dz(1:root_nodes) * state%water_content(1:root_nodes))
  end function root_storage

  pure real(real64) function first_depth_moment(state, parameter_set) result(moment)
    type(soil_water_physical_state_t), intent(in) :: state
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    moment = sum((-parameter_set%z) * parameter_set%dz * state%water_content)
  end function first_depth_moment

  pure real(real64) function rms_difference(a, b) result(rms)
    real(real64), intent(in) :: a(:), b(:)
    rms = sqrt(sum((a-b)**2) / real(size(a), real64))
  end function rms_difference

  pure real(real64) function head_from_effective_saturation(se) result(head_cm)
    real(real64), intent(in) :: se
    real(real64) :: m
    m = 1.0_real64 - 1.0_real64 / vg_n
    head_cm = -(se**(-1.0_real64/m) - 1.0_real64)**(1.0_real64/vg_n) / alpha_per_cm
  end function head_from_effective_saturation

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
       write(*,'(A,1X,A)') 'F_ROM01_FAIL', trim(label)
       error stop 1
    end if
  end subroutine require

end program test_f_rom01_reference_histories
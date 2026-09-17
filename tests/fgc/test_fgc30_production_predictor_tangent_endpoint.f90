program test_fgc30_production_predictor_tangent_endpoint
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t, &
       groundwater_interface_state_t, swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, &
       pair_groundwater_flux_from_swap, GW_INTERFACE_OK
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_swap_predictor_response_t
  use mod_modflow6_swap_predictor_origin, only: modflow6_swap_predictor_origin_t, &
       capture_modflow6_swap_predictor_origin, MODFLOW6_PREDICTOR_ORIGIN_OK
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK, &
       MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE
  use mod_modflow6_swap_predictor_candidate_assembler, only: assemble_modflow6_swap_predictor_response, &
       MODFLOW6_PREDICTOR_ASSEMBLER_OK, MODFLOW6_PREDICTOR_ASSEMBLER_LINEAGE_MISMATCH, &
       MODFLOW6_PREDICTOR_ASSEMBLER_BOTTOM_EXCHANGE_UNAVAILABLE
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: duration = 1.0e-4_real64
  real(real64), parameter :: mass_tolerance = 1.0e-12_real64
  real(real64), parameter :: qualification_head_budget = 1.0e-5_real64
  real(real64), parameter :: predictor_qbot = 1.0e-6_real64
  real(real64), parameter :: fd_eps = 1.0e-4_real64
  integer(int64), parameter :: column_id = 530030_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(soil_water_parameter_set_t), target :: solver_parameters
  type(soil_water_physical_state_t) :: predictor_state
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_state_t) :: accepted_interface
  type(modflow6_swap_predictor_lineage_t) :: lineage
  type(modflow6_swap_predictor_origin_t) :: origin, blocked_origin
  type(modflow6_prescribed_qbot_bottom_face_t) :: start_face, plus_face, minus_face
  type(modflow6_swap_predictor_tangent_endpoint_t) :: endpoint, blocked_endpoint
  type(modflow6_swap_predictor_response_t) :: response, blocked_response
  type(kernel_result_t) :: predictor_result, blocked_result
  type(kernel_candidate_state_t) :: predictor_candidate
  type(kernel_diagnostics_t) :: predictor_diagnostics
  type(fixed_flux_top_boundary_provider_t), target :: top
  real(real64) :: qeq, fd_derivative, derivative_scale
  real(real64) :: q_swap_m_per_s, q_groundwater_m_per_s, comparison_scale
  integer :: status, flux_status

  call initialize_parameters(parameters)
  call initialize_column_and_template(column, template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, duration)
  qeq = predictor_qbot

  call run_production_candidate(qeq, .true., predictor_result, predictor_candidate, predictor_diagnostics)
  call require(predictor_result%status == CANONICAL_STATUS_COMPLETED .and. predictor_result%completed, &
       'predictor production interval completed')
  call require(predictor_candidate%ready(), 'predictor candidate materialized')
  call require(predictor_diagnostics%retries == 0, 'predictor accepted without retry')
  call require(predictor_result%accepted_trajectory_direction%requested .and. &
       predictor_result%accepted_trajectory_direction%available, 'accepted trajectory available')
  call require(predictor_result%accepted_trajectory_direction%control_coordinate == SW_STEP_CONTROL_BOTTOM_FLUX, &
       'accepted trajectory uses prescribed qbot control')
  call require(predictor_result%accepted_trajectory_direction%additional_full_nonlinear_solves == 0, &
       'trajectory tangent added no nonlinear solve')

  call materialize_solver_view(predictor_candidate, predictor_state, solver_parameters)
  datum%available = .true.
  datum%datum_id = 530030_int64
  datum%bottom_boundary_elevation_m = 0.0_real64

  call build_modflow6_swap_predictor_tangent_endpoint(predictor_state, solver_parameters, constitutive, &
       predictor_result%accepted_trajectory_direction, qeq, datum, .false., .false., .false., .false., &
       endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_OK .and. endpoint%available .and. endpoint%authoritative, &
       'drainage-free production endpoint is authoritative')
  call require(endpoint%worker_id == int(column_id), 'worker provenance retained')
  call require(endpoint%trajectory_generation == predictor_result%accepted_trajectory_direction%generation, &
       'trajectory generation retained')
  call require(endpoint%accepted_steps == predictor_result%accepted_trajectory_direction%accepted_steps, &
       'accepted-step provenance retained')
  call require(endpoint%coverage%tangent_complete(), 'production derivative coverage complete')
  call require(endpoint%bottom_face%valid .and. endpoint%bottom_face%derivative_available, &
       'terminal lower-face value and derivative available')
  call require(ieee_is_finite(endpoint%bottom_face%hydraulic_head_m) .and. &
       ieee_is_finite(endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day), &
       'terminal lower-face response finite')
  write(*,'(A)') 'FGC30_PRODUCTION_ACCEPTED_TRAJECTORY_BINDING=PASS'
  write(*,'(A)') 'FGC30_PRODUCTION_TANGENT_ENDPOINT_AUTHORITATIVE=PASS'

  ! Independent centered finite difference through the same admitted
  ! model-certificate production candidate route as the nominal predictor.
  ! Perturbed trials start from the same immutable origin, disable tangent
  ! publication, change only native prescribed qbot, and must accept without retry.
  call run_endpoint_value(qeq + fd_eps, plus_face)
  call run_endpoint_value(qeq - fd_eps, minus_face)
  fd_derivative = (plus_face%pressure_head_cm - minus_face%pressure_head_cm) / (2.0_real64 * fd_eps)
  derivative_scale = max(1.0_real64, abs(fd_derivative), &
       abs(endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day))
  call require(abs(fd_derivative - endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day) <= &
       5.0e-4_real64 * derivative_scale, 'production trajectory tangent disagrees with centered FD')
  write(*,'(A)') 'FGC30_PRODUCTION_CENTERED_FD_ORACLE=PASS'
  write(*,'(A)') 'FGC30_PRODUCTION_TANGENT_FD_AGREEMENT=PASS'

  call materialize_origin_face(qeq, start_face)
  window%t0 = 0.0_real64
  window%t1 = duration
  lineage%coupling_id = 530030_int64
  lineage%swap_lineage_id = column_id
  lineage%swap_origin_revision = 0_int64
  lineage%groundwater_service_id = 630031_int64
  lineage%groundwater_lineage_id = 630030_int64
  lineage%groundwater_origin_revision = 0_int64

  call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qeq, q_swap_m_per_s, flux_status)
  call require(flux_status == GW_INTERFACE_OK, 'origin SWAP flux conversion')
  call pair_groundwater_flux_from_swap(q_swap_m_per_s, q_groundwater_m_per_s, flux_status)
  call require(flux_status == GW_INTERFACE_OK, 'origin groundwater flux pairing')
  accepted_interface%h_swap_m = start_face%hydraulic_head_m
  accepted_interface%h_groundwater_m = start_face%hydraulic_head_m - 1.0e-6_real64
  accepted_interface%q_swap_m_per_s = q_swap_m_per_s
  accepted_interface%q_groundwater_m_per_s = q_groundwater_m_per_s
  call capture_modflow6_swap_predictor_origin(accepted_interface, window%t0, lineage, .true., origin, status)
  call require(status == MODFLOW6_PREDICTOR_ORIGIN_OK .and. origin%structurally_valid(), &
       'committed predictor origin captured')

  call assemble_modflow6_swap_predictor_response(origin, window, predictor_candidate, predictor_result, &
       endpoint, response, status)
  call require(status == MODFLOW6_PREDICTOR_ASSEMBLER_OK .and. response%valid, &
       'production candidate provenance did not assemble typed predictor response')
  comparison_scale = max(1.0_real64, abs(qeq))
  call require(abs(response%q_bot_predictor_cm_per_day - qeq) <= &
       128.0_real64*epsilon(1.0_real64)*comparison_scale, &
       'assembler did not recover native qbot from terminal outward flux')
  call require(abs(response%h_bot_start_m - accepted_interface%h_swap_m) <= &
       128.0_real64*epsilon(1.0_real64)*max(1.0_real64, abs(accepted_interface%h_swap_m)), &
       'assembler did not retain committed SWAP H_bot,start')
  call require(abs(response%h_bot_start_m - accepted_interface%h_groundwater_m) > 1.0e-8_real64, &
       'assembler silently substituted groundwater head for SWAP H_bot,start')
  call require(ieee_is_finite(response%coupling_storage_coefficient_u) .and. &
       ieee_is_finite(response%q_u_m_per_s), 'typed production predictor response finite')
  write(*,'(A)') 'FGC30_PRODUCTION_CANDIDATE_ASSEMBLER=PASS'
  write(*,'(A)') 'FGC30_PRODUCTION_TYPED_PREDICTOR_RESPONSE=PASS'

  blocked_origin = origin
  blocked_origin%lineage%swap_lineage_id = column_id + 1_int64
  call assemble_modflow6_swap_predictor_response(blocked_origin, window, predictor_candidate, predictor_result, &
       endpoint, blocked_response, status)
  call require(status == MODFLOW6_PREDICTOR_ASSEMBLER_LINEAGE_MISMATCH .and. .not. blocked_response%valid, &
       'candidate lineage mismatch did not fail closed')

  blocked_result = predictor_result
  blocked_result%bottom_interface_exchange_available = .false.
  call assemble_modflow6_swap_predictor_response(origin, window, predictor_candidate, blocked_result, &
       endpoint, blocked_response, status)
  call require(status == MODFLOW6_PREDICTOR_ASSEMBLER_BOTTOM_EXCHANGE_UNAVAILABLE .and. &
       .not. blocked_response%valid, 'missing terminal bottom exchange did not fail closed')
  write(*,'(A)') 'FGC30_PRODUCTION_PROVENANCE_FAIL_CLOSED=PASS'

  call build_modflow6_swap_predictor_tangent_endpoint(predictor_state, solver_parameters, constitutive, &
       predictor_result%accepted_trajectory_direction, qeq, datum, .false., .false., .true., .false., &
       blocked_endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE .and. &
       blocked_endpoint%available .and. .not. blocked_endpoint%authoritative, &
       'active unqualified drainage did not fail closed')
  write(*,'(A)') 'FGC30_PRODUCTION_DRAINAGE_TANGENT_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FGC30_PRODUCTION_PREDICTOR_TANGENT_ENDPOINT_GATE=PASS'

contains

  subroutine initialize_parameters(value)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    integer :: k

    value%parameter_set_id = 530030_int64
    value%active_nodes = numnod
    allocate(value%z(numnod), value%dz(numnod), value%node_distance(numnod), value%cofgen(24,numnod))
    value%z = z
    value%dz = dz
    value%node_distance = disnod(1:numnod)
    value%cofgen = 0.0_real64
    do k = 1, numnod
      value%cofgen(1,k) = 0.032_real64
      value%cofgen(2,k) = 0.423_real64
      value%cofgen(3,k) = 4.75_real64
      value%cofgen(4,k) = 0.0135_real64
      value%cofgen(5,k) = 0.365_real64
      value%cofgen(6,k) = 1.455_real64
      value%cofgen(7,k) = 1.0_real64 - 1.0_real64/value%cofgen(6,k)
      value%cofgen(8,k) = value%cofgen(4,k)
      value%cofgen(9,k) = 0.0_real64
      value%cofgen(10,k) = value%cofgen(3,k)
      value%cofgen(11,k) = 0.999_real64
      value%cofgen(12,k) = 0.99_real64*value%cofgen(3,k)
      value%cofgen(22,k) = -1.0e6_real64
      value%cofgen(23,k) = 1.0e-12_real64
    end do
    value%bottom_mode = SW_STEP_CONTROL_BOTTOM_FLUX
    value%swkimpl = 0
    value%swkmean = 1
    value%swsophy = 0
    value%max_iterations = 16
    value%max_backtracking = 8
    value%min_step_duration = 1.0e-8_real64
    value%compartment_balance_tolerance = mass_tolerance
    value%total_balance_tolerance = mass_tolerance
    value%head_abs_tolerance = mass_tolerance
    value%head_rel_tolerance = mass_tolerance
    value%ponding_tolerance = mass_tolerance
    value%root_extraction_active = .false.
    value%macropore_active = .false.
    value%snow_active = .false.
    value%hysteresis_active = .false.
    value%tabulated_hydraulics_active = .false.
    value%elasticity_active = .false.
    value%frost_active = .false.
    value%soil_temperature_active = .false.
    value%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_column_and_template(column_value, template_value)
    type(fmr_logical_column_t), intent(out) :: column_value
    type(fmr_template_t), intent(out) :: template_value

    template_value%template_id = 530001_int64
    template_value%physics_topology_id = 530002_int64
    template_value%vertical_layout_id = 530003_int64
    template_value%state_layout_id = 530004_int64
    template_value%solver_interface_id = 530005_int64
    template_value%optional_state_layout_id = 0_int64
    template_value%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    template_value%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    column_value%column_id = column_id
    column_value%template_id = template_value%template_id
    column_value%parameter_ref = 1_int64
    column_value%state_handle = 1_int64
    column_value%forcing_handle = 1_int64
    column_value%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_and_template


  subroutine initialize_forcing(value, bottom_flux)
    type(fmr_b110_physical_forcing_t), intent(out) :: value
    real(real64), intent(in) :: bottom_flux

    value%top_flux = qeq
    value%top_head = h0
    value%bottom_flux = bottom_flux
    value%bottom_head = -999999.0_real64
    allocate(value%drainage_flux_by_level(1,numnod), value%subsurface_irrigation_source(numnod), &
         value%root_extraction_sink(numnod))
    value%drainage_flux_by_level = 0.0_real64
    value%subsurface_irrigation_source = 0.0_real64
    value%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_config(config, request_trajectory)
    type(canonical_numerical_config_t), intent(out) :: config
    logical, intent(in) :: request_trajectory

    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = mass_tolerance
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 8
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = qualification_head_budget
    config%accepted_trajectory_direction%requested = request_trajectory
    config%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
  end subroutine initialize_config

  subroutine initialize_committed(committed, initialized)
    type(kernel_committed_state_t), intent(out) :: committed
    logical, intent(out) :: initialized
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: accepted_predecessor_right_derivative(numnod)
    integer :: i

    heads(1) = h0
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
    end do
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    accepted_predecessor_right_derivative = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, 0.0_real64, initialized, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_committed

  subroutine run_production_candidate(bottom_flux, request_trajectory, result, candidate, diagnostics)
    real(real64), intent(in) :: bottom_flux
    logical, intent(in) :: request_trajectory
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    logical :: initialized

    call initialize_committed(committed, initialized)
    call require(initialized, 'committed state initialized')
    call fmr_capture_checkpoint(committed, checkpoint, initialized)
    call require(initialized, 'checkpoint captured')
    call initialize_forcing(forcing, bottom_flux)
    call initialize_config(config, request_trajectory)
    call backend%initialize(top)
    call backend%run_trial(column, template, parameters, committed, forcing, config, 0.0_real64, duration, &
         checkpoint, result, candidate, diagnostics)
    if (.not. result%completed) then
      write(*,'(A,I0,A,F12.8,A,I0,A,I0,A,I0)') 'FGC30_PRODUCTION_CANDIDATE_DIAG status=', result%status, &
           ' completed_t=', result%completed_t, ' retries=', diagnostics%retries, &
           ' temporal_rejections=', diagnostics%temporal_rejections, ' solver_rejections=', diagnostics%solver_rejections
    end if
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, &
         'production candidate completed')
    call require(candidate%ready(), 'production candidate ready')
  end subroutine run_production_candidate

  subroutine materialize_solver_view(candidate, state, parameter_set)
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(soil_water_physical_state_t), intent(out) :: state
    type(soil_water_parameter_set_t), intent(out) :: parameter_set
    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    call candidate%snapshot(snapshot, available)
    call require(available .and. allocated(snapshot), 'candidate snapshot available')
    select type (typed => snapshot)
    class is (fmr_b110_physical_state_t)
      state%active_nodes = typed%active_nodes
      allocate(state%pressure_head(typed%active_nodes), state%water_content(typed%active_nodes))
      state%pressure_head = typed%pressure_head
      state%water_content = typed%water_content
      state%ponding_depth = typed%ponding_depth
      state%groundwater_level = typed%groundwater_level
    class default
      call require(.false., 'candidate snapshot has B1.10 physical state type')
    end select

    parameter_set%parameter_set_id = parameters%parameter_set_id
    parameter_set%active_nodes = parameters%active_nodes
    allocate(parameter_set%z(parameters%active_nodes), parameter_set%dz(parameters%active_nodes), &
         parameter_set%node_distance(parameters%active_nodes))
    parameter_set%z = parameters%z
    parameter_set%dz = parameters%dz
    parameter_set%node_distance = parameters%node_distance
  end subroutine materialize_solver_view

  subroutine run_endpoint_value(bottom_flux, face)
    real(real64), intent(in) :: bottom_flux
    type(modflow6_prescribed_qbot_bottom_face_t), intent(out) :: face
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(soil_water_physical_state_t) :: state
    type(soil_water_parameter_set_t) :: parameter_set
    real(real64) :: water(numnod), conductivity(numnod), capacity(numnod), reserved(numnod)
    integer :: face_status

    ! Independent centered-FD oracle through the same non-committing production
    ! candidate route as the nominal predictor. The model-certificate temporal
    ! route admits smooth nonstationary qbot perturbations without changing the
    ! scientific state or relaxing transaction semantics.
    call run_production_candidate(bottom_flux, .false., result, candidate, diagnostics)
    call require(diagnostics%retries == 0, 'FD perturbation changed production acceptance topology')
    call materialize_solver_view(candidate, state, parameter_set)
    call constitutive%evaluate(state%pressure_head, water, conductivity, capacity, reserved)
    call materialize_modflow6_prescribed_qbot_bottom_face(state%pressure_head(numnod), conductivity(numnod), &
         bottom_flux, 0.5_real64*parameter_set%dz(numnod), datum, face, face_status)
    call require(face_status == MODFLOW6_BOTTOM_FACE_OK .and. face%valid, 'FD endpoint face materialized')
  end subroutine run_endpoint_value

  subroutine materialize_origin_face(bottom_flux, face)
    real(real64), intent(in) :: bottom_flux
    type(modflow6_prescribed_qbot_bottom_face_t), intent(out) :: face
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), reserved(numnod)
    integer :: face_status, i

    heads(1) = h0
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
    end do
    call constitutive%evaluate(heads, water, conductivity, capacity, reserved)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod), conductivity(numnod), bottom_flux, &
         0.5_real64*parameters%dz(numnod), datum, face, face_status)
    call require(face_status == MODFLOW6_BOTTOM_FACE_OK .and. face%valid, 'origin face materialized')
  end subroutine materialize_origin_face

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FGC30_PRODUCTION_TANGENT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fgc30_production_predictor_tangent_endpoint

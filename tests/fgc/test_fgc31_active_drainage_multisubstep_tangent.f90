program test_fgc31_active_drainage_multisubstep_tangent
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
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_TABULATED
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK
  implicit none

  real(real64), parameter :: duration = 1.0e-2_real64
  real(real64), parameter :: temporal_budget = 1.0e-5_real64
  real(real64), parameter :: mass_tolerance = 1.0e-11_real64
  real(real64), parameter :: qbot_nominal = 2.0e-3_real64
  real(real64), parameter :: fd_eps = 2.0e-5_real64
  real(real64), parameter :: initial_projected_drainage = 1.8e-3_real64
  integer(int64), parameter :: column_id = 531131_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(groundwater_head_datum_t) :: datum
  type(kernel_result_t) :: nominal_result
  type(kernel_candidate_state_t) :: nominal_candidate
  type(kernel_diagnostics_t) :: nominal_diagnostics
  type(soil_water_physical_state_t) :: nominal_state
  type(soil_water_parameter_set_t) :: solver_parameters
  type(modflow6_swap_predictor_tangent_endpoint_t) :: endpoint
  type(modflow6_prescribed_qbot_bottom_face_t) :: plus_face, minus_face
  real(real64) :: fd_derivative, scale
  integer :: status

  call initialize_parameters(parameters)
  call initialize_column_template(column, template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, duration)

  datum%available = .true.
  datum%datum_id = 531131_int64
  datum%bottom_boundary_elevation_m = 0.0_real64

  call run_candidate(qbot_nominal, .true., nominal_result, nominal_candidate, nominal_diagnostics)
  call require(nominal_result%status == CANONICAL_STATUS_COMPLETED .and. nominal_result%completed, &
       'nominal production interval completed')
  call require(nominal_candidate%ready(), 'nominal candidate ready')
  call require(nominal_result%diagnostics%committed_substeps >= 2, 'nominal interval did not exercise multiple substeps')
  call require(nominal_result%accepted_trajectory_direction%requested .and. &
       nominal_result%accepted_trajectory_direction%available, 'whole-window tangent unavailable')
  call require(nominal_result%accepted_trajectory_direction%accepted_steps >= 2, &
       'whole-window tangent did not aggregate multiple accepted steps')
  call require(nominal_result%accepted_trajectory_direction%source_sink_direction_coverage_complete, &
       'active drainage coverage provenance incomplete')
  call require(nominal_result%accepted_trajectory_direction%additional_full_nonlinear_solves == 0, &
       'tangent introduced extra nonlinear solves')

  call materialize_solver_view(nominal_candidate, nominal_state, solver_parameters)
  call build_modflow6_swap_predictor_tangent_endpoint(nominal_state, solver_parameters, constitutive, &
       nominal_result%accepted_trajectory_direction, qbot_nominal, datum, .false., .false., .true., .false., &
       endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_OK .and. endpoint%available .and. endpoint%authoritative, &
       'active-drainage endpoint is not authoritative')
  call require(endpoint%coverage%drainage_active .and. endpoint%coverage%drainage_covered .and. &
       endpoint%coverage%tangent_complete(), 'endpoint did not carry complete drainage coverage')

  call run_endpoint_value(qbot_nominal + fd_eps, nominal_diagnostics%committed_substeps, &
       nominal_diagnostics%retries, plus_face)
  call run_endpoint_value(qbot_nominal - fd_eps, nominal_diagnostics%committed_substeps, &
       nominal_diagnostics%retries, minus_face)
  fd_derivative = (plus_face%pressure_head_cm - minus_face%pressure_head_cm) / (2.0_real64*fd_eps)
  scale = max(1.0_real64, abs(fd_derivative), &
       abs(endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day))
  call require(abs(fd_derivative-endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day) <= &
       8.0e-4_real64*scale, 'active-drainage whole-window tangent disagrees with centered FD')

  write(*,'(A,I0)') 'FGC31_ACTIVE_DRAINAGE_COMMITTED_SUBSTEPS=', nominal_result%diagnostics%committed_substeps
  write(*,'(A,I0)') 'FGC31_ACTIVE_DRAINAGE_ACCEPTED_STEPS=', nominal_result%accepted_trajectory_direction%accepted_steps
  write(*,'(A,I0)') 'FGC31_ACTIVE_DRAINAGE_RETRIES=', nominal_diagnostics%retries
  write(*,'(A,1X,ES18.10)') 'FGC31_ACTIVE_DRAINAGE_ANALYTIC=', &
       endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day
  write(*,'(A,1X,ES18.10)') 'FGC31_ACTIVE_DRAINAGE_FD=', fd_derivative
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_MULTI_SUBSTEP=PASS'
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_COVERAGE_PROVENANCE=PASS'
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_CENTERED_FD=PASS'
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_NO_EXTRA_NONLINEAR_SOLVES=PASS'
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_ENDPOINT_AUTHORITATIVE=PASS'

contains

  subroutine initialize_parameters(value)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    integer :: k

    value%parameter_set_id = 531131_int64
    value%active_nodes = numnod
    allocate(value%z(numnod), value%dz(numnod), value%node_distance(numnod), value%cofgen(24,numnod))
    value%z = z
    value%dz = dz
    value%node_distance = disnod(1:numnod)
    value%cofgen = 0.0_real64
    do k = 1, numnod
      value%cofgen(1,k)=0.032_real64
      value%cofgen(2,k)=0.423_real64
      value%cofgen(3,k)=4.75_real64
      value%cofgen(4,k)=0.0135_real64
      value%cofgen(5,k)=0.365_real64
      value%cofgen(6,k)=1.455_real64
      value%cofgen(7,k)=1.0_real64-1.0_real64/value%cofgen(6,k)
      value%cofgen(8,k)=value%cofgen(4,k)
      value%cofgen(9,k)=0.0_real64
      value%cofgen(10,k)=value%cofgen(3,k)
      value%cofgen(11,k)=0.999_real64
      value%cofgen(12,k)=0.99_real64*value%cofgen(3,k)
      value%cofgen(22,k)=-1.0e6_real64
      value%cofgen(23,k)=1.0e-12_real64
    end do
    value%bottom_mode = SW_STEP_CONTROL_BOTTOM_FLUX
    value%swkimpl = 0
    value%swkmean = 1
    value%swsophy = 0
    value%max_iterations = 16
    value%max_backtracking = 8
    value%min_step_duration = 1.0e-9_real64
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
    value%drainage_response_active = .true.
    value%drainage_qbot_smooth_freatic_projection = .true.
    allocate(value%drainage_response_levels(1))
    value%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_TABULATED
    allocate(value%drainage_response_levels(1)%tabulated%groundwater_depth(2), &
         value%drainage_response_levels(1)%tabulated%signed_exchange_rate(2))
    value%drainage_response_levels(1)%tabulated%groundwater_depth = [0.5_real64, 2.5_real64]
    value%drainage_response_levels(1)%tabulated%signed_exchange_rate = [3.0e-3_real64, 1.0e-3_real64]
  end subroutine initialize_parameters

  subroutine initialize_column_template(c, t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t

    t%template_id=531101_int64
    t%physics_topology_id=531102_int64
    t%vertical_layout_id=531103_int64
    t%state_layout_id=531104_int64
    t%solver_interface_id=531105_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    c%column_id=column_id
    c%template_id=t%template_id
    c%parameter_ref=1_int64
    c%state_handle=1_int64
    c%forcing_handle=1_int64
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_forcing(value, bottom_flux)
    type(fmr_b110_physical_forcing_t), intent(out) :: value
    real(real64), intent(in) :: bottom_flux

    value%top_flux = 0.0_real64
    value%top_head = -999.0_real64
    value%bottom_flux = bottom_flux
    value%bottom_head = -999.0_real64
    allocate(value%drainage_response_controls(1), value%subsurface_irrigation_source(numnod), &
         value%root_extraction_sink(numnod))
    value%subsurface_irrigation_source = 0.0_real64
    value%subsurface_irrigation_source(numnod) = initial_projected_drainage
    value%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_config(config, request_trajectory)
    type(canonical_numerical_config_t), intent(out) :: config
    logical, intent(in) :: request_trajectory

    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = mass_tolerance
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 12
    config%max_committed_substeps = 64
    config%progress_tolerance = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = temporal_budget
    config%accepted_trajectory_direction%requested = request_trajectory
    config%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
  end subroutine initialize_config

  subroutine initialize_committed(committed, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: previous_right(numnod)

    heads = [-2.2_real64, -1.2_real64, -0.2_real64, 0.8_real64]
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -1.7_real64
    previous_right = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, 0.0_real64, ok, previous_right)
  end subroutine initialize_committed

  subroutine run_candidate(bottom_flux, request_trajectory, result, candidate, diagnostics)
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
      write(*,'(A,I0,A,F12.8,A,I0,A,I0,A,I0)') 'FGC31_MULTI_DIAG status=', result%status, &
           ' completed_t=', result%completed_t, ' retries=', diagnostics%retries, &
           ' temporal_rejections=', diagnostics%temporal_rejections, ' solver_rejections=', diagnostics%solver_rejections
    end if
  end subroutine run_candidate

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
      call require(.false., 'candidate snapshot has B1.10 state type')
    end select

    parameter_set%parameter_set_id = parameters%parameter_set_id
    parameter_set%active_nodes = parameters%active_nodes
    allocate(parameter_set%z(parameters%active_nodes), parameter_set%dz(parameters%active_nodes), &
         parameter_set%node_distance(parameters%active_nodes))
    parameter_set%z = parameters%z
    parameter_set%dz = parameters%dz
    parameter_set%node_distance = parameters%node_distance
  end subroutine materialize_solver_view

  subroutine run_endpoint_value(bottom_flux, expected_substeps, expected_retries, face)
    real(real64), intent(in) :: bottom_flux
    integer, intent(in) :: expected_substeps, expected_retries
    type(modflow6_prescribed_qbot_bottom_face_t), intent(out) :: face
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(soil_water_physical_state_t) :: state
    type(soil_water_parameter_set_t) :: parameter_set
    real(real64) :: water(numnod), conductivity(numnod), capacity(numnod), reserved(numnod)
    integer :: face_status

    call run_candidate(bottom_flux, .false., result, candidate, diagnostics)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed .and. candidate%ready(), &
         'FD production candidate completed')
    call require(result%diagnostics%committed_substeps == expected_substeps, &
         'FD perturbation changed committed-substep topology')
    call require(diagnostics%retries == expected_retries, 'FD perturbation changed retry topology')
    call materialize_solver_view(candidate, state, parameter_set)
    call constitutive%evaluate(state%pressure_head, water, conductivity, capacity, reserved)
    call materialize_modflow6_prescribed_qbot_bottom_face(state%pressure_head(numnod), conductivity(numnod), &
         bottom_flux, 0.5_real64*parameter_set%dz(numnod), datum, face, face_status)
    call require(face_status == MODFLOW6_BOTTOM_FACE_OK .and. face%valid, 'FD endpoint face materialized')
  end subroutine run_endpoint_value

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FGC31_ACTIVE_DRAINAGE_MULTI_FAIL', trim(label)
      error stop 31
    end if
  end subroutine require

end program test_fgc31_active_drainage_multisubstep_tangent

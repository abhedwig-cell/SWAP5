program test_ross12_serialized_production_wiring
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_rossfast_solver_selection_binding, only: FMR_ROSSFAST_SOLVER_MODEL_KEY, FMR_ROSSFAST_BIND_OK
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY, &
       ROSSFAST_D3R_RETRY_SCALE, ROSSFAST_D3R_MAX_FULL_INDEX
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  implicit none

  integer(int64), parameter :: column_id = 120120_int64
  real(real64), parameter :: initial_head_cm = -101.0_real64

  call verify_real_b01_production_route()
  call verify_material_drift_fails_closed()
  call verify_unsupported_root_physics_fails_closed()
  write(*,'(A)') 'ROSS12_SERIALIZED_PRODUCTION_WIRING PASS'

contains

  subroutine verify_real_b01_production_route()
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(.false., .false., output, observation)
    call require(output%completed .and. output%committed, 'B01 production transaction commits')
    call require(output%mass%complete, 'B01 production mass accounting complete')
    call require(abs(output%mass%residual) <= ROSSFAST_D3R_HARD_MASS_TOL_CM, 'B01 production hard mass gate')
    call require(output%final_revision > 0_int64, 'B01 production revision advances')
    call require(output%accepted_substeps > 0, 'B01 production accepts at least one substep')
    call require(output%solver_headcalc_calls == 0, 'RossFast route executes no legacy HeadCalc trajectory')
    call require(observation%solver_executed, 'RossFast solver executed in serialized host')
    call require(observation%temporal_certificate_available, 'RossFast production certificate available')
    call require(ieee_is_finite(observation%temporal_normalized_indicator) .and. &
         observation%temporal_normalized_indicator >= 0.0_real64 .and. &
         observation%temporal_normalized_indicator <= 1.0_real64, 'RossFast production certificate accepted')
    call require(trim(observation%temporal_indicator_route) == 'rossfast-model-certificate', &
         'RossFast production certificate route explicit')
    write(*,'(A,I0)') 'ROSS12_PRODUCTION_ACCEPTED_SUBSTEPS=', output%accepted_substeps
    write(*,'(A,ES26.17E3)') 'ROSS12_PRODUCTION_MASS_RESIDUAL=', output%mass%residual
    write(*,'(A,ES26.17E3)') 'ROSS12_PRODUCTION_TEMPORAL_INDICATOR=', observation%temporal_normalized_indicator
    write(*,'(A)') 'ROSS12_REAL_B01_PRODUCTION_ROUTE=PASS'
  end subroutine verify_real_b01_production_route

  subroutine verify_material_drift_fails_closed()
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(.true., .false., output, observation)
    call require(.not. output%committed, 'material drift no commit')
    call require(output%final_revision == 0_int64, 'material drift revision unchanged')
    call require(.not. observation%solver_executed, 'material drift rejected before solver execution')
    call require(output%solver_headcalc_calls == 0, 'material drift does not fall back to HeadCalc')
    write(*,'(A)') 'ROSS12_MATERIAL_DRIFT_FAIL_CLOSED=PASS'
  end subroutine verify_material_drift_fails_closed

  subroutine verify_unsupported_root_physics_fails_closed()
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(.false., .true., output, observation)
    call require(.not. output%committed, 'unsupported root physics no commit')
    call require(output%final_revision == 0_int64, 'unsupported root physics revision unchanged')
    call require(.not. observation%solver_executed, 'unsupported root physics rejected before solver')
    call require(output%solver_headcalc_calls == 0, 'unsupported root physics does not fall back to HeadCalc')
    write(*,'(A)') 'ROSS12_UNSUPPORTED_ROOT_PHYSICS_FAIL_CLOSED=PASS'
  end subroutine verify_unsupported_root_physics_fails_closed

  subroutine execute_case(material_drift, root_active, output, observation)
    logical, intent(in) :: material_drift, root_active
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_serialized_physical_observation_t), intent(out) :: observation
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: transaction_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(rossfast_d3r_material_t) :: material
    integer :: active_physical_calls, selection_status
    logical :: ok, found

    call rossfast_d3r_material_from_id('B01', material, found)
    call require(found, 'B01 material authority available')
    call initialize_parameters(parameters, material, root_active)
    if (material_drift) parameters%cofgen(3,1) = 1.01_real64 * parameters%cofgen(3,1)
    call initialize_committed(committed, parameters, material, ok)
    call require(ok, 'typed committed state initialization')
    call initialize_forcing(forcing, material)
    call initialize_column_and_template(column, template)
    call initialize_config(config)

    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = 0.0_real64
    output%requested_t1 = ROSSFAST_D3R_OUTER_HORIZON_DAY
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_physical_calls = 0

    call backend%initialize(top)
    call backend%configure_soil_water_model(FMR_ROSSFAST_SOLVER_MODEL_KEY, ok, selection_status, &
         asset_root='assets/rossfast/d3r', material_id='B01')
    call require(ok .and. selection_status == FMR_ROSSFAST_BIND_OK, 'RossFast production selection configured')

    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, output, diagnostic, runtime, &
         active_physical_calls)
    observation = backend%observation()
  end subroutine execute_case

  subroutine initialize_column_and_template(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 120001_int64
    template%physics_topology_id = 120002_int64
    template%vertical_layout_id = 120003_int64
    template%state_layout_id = 120004_int64
    template%solver_interface_id = 120005_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_and_template

  subroutine initialize_config(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config = canonical_numerical_config_t()
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%retry_scale = ROSSFAST_D3R_RETRY_SCALE
    config%transaction%max_retries = ROSSFAST_D3R_MAX_FULL_INDEX
    config%transaction%mass_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
  end subroutine initialize_config

  subroutine initialize_parameters(parameters, material, root_active)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(rossfast_d3r_material_t), intent(in) :: material
    logical, intent(in) :: root_active
    real(real64) :: m
    integer :: i

    m = 1.0_real64 - 1.0_real64 / material%n
    parameters%parameter_set_id = 120012_int64
    parameters%active_nodes = ROSSFAST_D3R_N_CELLS
    allocate(parameters%z(ROSSFAST_D3R_N_CELLS), parameters%dz(ROSSFAST_D3R_N_CELLS), &
         parameters%node_distance(ROSSFAST_D3R_N_CELLS), parameters%cofgen(24,ROSSFAST_D3R_N_CELLS))
    do i = 1, ROSSFAST_D3R_N_CELLS
      parameters%z(i) = -ROSSFAST_D3R_DZ_CM * (real(i,real64) - 0.5_real64)
    end do
    parameters%dz = ROSSFAST_D3R_DZ_CM
    parameters%node_distance = ROSSFAST_D3R_DZ_CM
    parameters%cofgen = 0.0_real64
    do i = 1, ROSSFAST_D3R_N_CELLS
      parameters%cofgen(1,i) = material%theta_r
      parameters%cofgen(2,i) = material%theta_s
      parameters%cofgen(3,i) = material%ksatfit_cm_per_day
      parameters%cofgen(4,i) = material%alpha_per_cm
      parameters%cofgen(5,i) = material%lambda
      parameters%cofgen(6,i) = material%n
      parameters%cofgen(7,i) = m
      parameters%cofgen(8,i) = material%alpha_per_cm
      parameters%cofgen(9,i) = material%h_enpr_cm
      parameters%cofgen(10,i) = material%ksatfit_cm_per_day
      parameters%cofgen(11,i) = 0.999_real64
      parameters%cofgen(12,i) = 0.99_real64 * material%ksatfit_cm_per_day
      parameters%cofgen(22,i) = -1.0e6_real64
      parameters%cofgen(23,i) = 1.0e-12_real64
    end do
    parameters%bottom_mode = 2
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    parameters%total_balance_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%root_extraction_active = root_active
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
    parameters%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_committed(committed, parameters, material, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(rossfast_d3r_material_t), intent(in) :: material
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: theta

    theta = theta_from_head(initial_head_cm, material)
    state%active_nodes = ROSSFAST_D3R_N_CELLS
    allocate(state%pressure_head(ROSSFAST_D3R_N_CELLS), state%water_content(ROSSFAST_D3R_N_CELLS))
    state%pressure_head = initial_head_cm
    state%water_content = theta
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -999.0_real64
    call fmr_new_b110_committed_state(committed, column_id, state, 0.0_real64, ok)
  end subroutine initialize_committed

  subroutine initialize_forcing(forcing, material)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: conductivity

    conductivity = conductivity_from_head(initial_head_cm, material)
    forcing%top_flux = 0.01_real64 * conductivity
    forcing%top_head = initial_head_cm
    forcing%bottom_flux = -0.004_real64 * conductivity
    forcing%bottom_head = -999999.0_real64
    allocate(forcing%drainage_flux_by_level(1,ROSSFAST_D3R_N_CELLS), &
         forcing%subsurface_irrigation_source(ROSSFAST_D3R_N_CELLS), &
         forcing%root_extraction_sink(ROSSFAST_D3R_N_CELLS))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

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

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'ROSS12_PRODUCTION_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ross12_serialized_production_wiring

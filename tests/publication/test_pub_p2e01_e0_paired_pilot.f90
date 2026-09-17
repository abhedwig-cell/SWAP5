program test_pub_p2e01_e0_paired_pilot
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_soil_water_application_host, only: FMR_SOIL_WATER_MODEL_REFERENCE
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

  integer(int64), parameter :: reference_column_id = 220120_int64
  integer(int64), parameter :: alternative_column_id = 220121_int64
  real(real64), parameter :: initial_head_cm = -101.0_real64

  type :: endpoint_t
    real(real64), allocatable :: head(:)
    real(real64), allocatable :: theta(:)
    real(real64) :: storage_start = 0.0_real64
    real(real64) :: storage_end = 0.0_real64
    real(real64) :: mass_residual = 0.0_real64
    integer(int64) :: revision = -1_int64
    integer :: accepted_substeps = 0
    integer :: retries = 0
    integer :: headcalc_calls = 0
    integer :: alternative_solver_calls = 0
    character(len=64) :: solver_route = ''
  end type endpoint_t

  type(endpoint_t) :: reference_endpoint, alternative_endpoint
  real(real64) :: dh_inf, dh_rms, dtheta_inf, dtheta_rms, dstorage

  call run_route(FMR_SOIL_WATER_MODEL_REFERENCE, reference_column_id, reference_endpoint)
  call run_route(FMR_ROSSFAST_SOLVER_MODEL_KEY, alternative_column_id, alternative_endpoint)

  call require(allocated(reference_endpoint%head) .and. allocated(alternative_endpoint%head), &
       'paired head profiles available')
  call require(allocated(reference_endpoint%theta) .and. allocated(alternative_endpoint%theta), &
       'paired water-content profiles available')
  call require(size(reference_endpoint%head) == ROSSFAST_D3R_N_CELLS .and. &
       size(alternative_endpoint%head) == ROSSFAST_D3R_N_CELLS, 'paired head profiles have E0 shape')
  call require(size(reference_endpoint%theta) == ROSSFAST_D3R_N_CELLS .and. &
       size(alternative_endpoint%theta) == ROSSFAST_D3R_N_CELLS, 'paired theta profiles have E0 shape')

  dh_inf = maxval(abs(alternative_endpoint%head - reference_endpoint%head))
  dh_rms = sqrt(sum((alternative_endpoint%head - reference_endpoint%head)**2) / &
       real(ROSSFAST_D3R_N_CELLS, real64))
  dtheta_inf = maxval(abs(alternative_endpoint%theta - reference_endpoint%theta))
  dtheta_rms = sqrt(sum((alternative_endpoint%theta - reference_endpoint%theta)**2) / &
       real(ROSSFAST_D3R_N_CELLS, real64))
  dstorage = abs(alternative_endpoint%storage_end - reference_endpoint%storage_end)

  call require(all(ieee_is_finite(reference_endpoint%head)) .and. &
       all(ieee_is_finite(alternative_endpoint%head)), 'paired head profiles finite')
  call require(all(ieee_is_finite(reference_endpoint%theta)) .and. &
       all(ieee_is_finite(alternative_endpoint%theta)), 'paired theta profiles finite')
  call require(ieee_is_finite(dh_inf) .and. ieee_is_finite(dh_rms) .and. &
       ieee_is_finite(dtheta_inf) .and. ieee_is_finite(dtheta_rms) .and. ieee_is_finite(dstorage), &
       'paired raw metrics finite')

  write(*,'(A,A)') 'PUB_P2E01_REFERENCE_SOLVER_ROUTE=', trim(reference_endpoint%solver_route)
  write(*,'(A,A)') 'PUB_P2E01_ALTERNATIVE_SOLVER_ROUTE=', trim(alternative_endpoint%solver_route)
  write(*,'(A,I0)') 'PUB_P2E01_REFERENCE_ACCEPTED_SUBSTEPS=', reference_endpoint%accepted_substeps
  write(*,'(A,I0)') 'PUB_P2E01_ALTERNATIVE_ACCEPTED_SUBSTEPS=', alternative_endpoint%accepted_substeps
  write(*,'(A,I0)') 'PUB_P2E01_REFERENCE_RETRIES=', reference_endpoint%retries
  write(*,'(A,I0)') 'PUB_P2E01_ALTERNATIVE_RETRIES=', alternative_endpoint%retries
  write(*,'(A,I0)') 'PUB_P2E01_REFERENCE_HEADCALC_CALLS=', reference_endpoint%headcalc_calls
  write(*,'(A,I0)') 'PUB_P2E01_ALTERNATIVE_SOLVER_CALLS=', alternative_endpoint%alternative_solver_calls
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_REFERENCE_MASS_RESIDUAL=', reference_endpoint%mass_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_ALTERNATIVE_MASS_RESIDUAL=', alternative_endpoint%mass_residual
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_H_INF_CM=', dh_inf
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_H_RMS_CM=', dh_rms
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_THETA_INF=', dtheta_inf
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_THETA_RMS=', dtheta_rms
  write(*,'(A,ES26.17E3)') 'PUB_P2E01_D_STORAGE_CM=', dstorage
  write(*,'(A)') 'PUB_P2E01_SCIENTIFIC_ADMISSIBILITY_NOT_EVALUATED=TRUE'
  write(*,'(A)') 'PUB_P2E01_PREDICTED_FLUX_EQUIVALENCE_NOT_EVALUATED=TRUE'
  write(*,'(A)') 'PUB_P2E01_PAIRED_EXTRACTION_READY=PASS'

contains

  subroutine run_route(model_key, column_id, endpoint)
    character(len=*), intent(in) :: model_key
    integer(int64), intent(in) :: column_id
    type(endpoint_t), intent(out) :: endpoint
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
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
    class(transaction_state_t), allocatable :: snapshot
    integer :: active_physical_calls, selection_status
    logical :: ok, found, available

    call rossfast_d3r_material_from_id('B01', material, found)
    call require(found, 'B01 material authority available')
    call initialize_parameters(parameters, material)
    call initialize_committed(committed, column_id, material, ok)
    call require(ok, 'typed committed state initialization')
    call initialize_forcing(forcing, material)
    call initialize_column_and_template(column, template, column_id)
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
    if (trim(model_key) == FMR_ROSSFAST_SOLVER_MODEL_KEY) then
      call backend%configure_soil_water_model(model_key, ok, selection_status, &
           asset_root='assets/rossfast/d3r', material_id='B01')
    else
      call backend%configure_soil_water_model(model_key, ok, selection_status)
    end if
    call require(ok .and. selection_status == FMR_ROSSFAST_BIND_OK, 'explicit model selection configured')

    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, output, diagnostic, runtime, &
         active_physical_calls)
    observation = backend%observation()

    call require(output%admitted .and. output%completed .and. output%committed, 'paired production route committed')
    call require(output%mass%complete, 'paired production route mass ledger complete')
    call require(abs(output%mass%residual) <= config%transaction%mass_tolerance, 'paired production hard mass gate')
    call require(output%final_revision > 0_int64, 'paired production revision advanced')
    call require(output%accepted_substeps > 0, 'paired production accepted at least one substep')
    call require(observation%solver_executed, 'selected solver executed')

    if (trim(model_key) == FMR_ROSSFAST_SOLVER_MODEL_KEY) then
      call require(output%solver_headcalc_calls == 0, 'RossFast route has no HeadCalc execution')
      call require(output%solver_alternative_solver_calls > 0, 'RossFast route reports alternative solver execution')
    else
      call require(output%solver_headcalc_calls > 0, 'Reference route executes HeadCalc')
      call require(output%solver_alternative_solver_calls == 0, 'Reference route has no alternative solver execution')
    end if

    call committed%snapshot(snapshot, available)
    call require(available, 'accepted committed state snapshot available')
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      call require(physical%active_nodes == ROSSFAST_D3R_N_CELLS, 'accepted endpoint uses E0 node count')
      call require(allocated(physical%pressure_head) .and. allocated(physical%water_content), &
           'accepted endpoint state vectors allocated')
      allocate(endpoint%head(size(physical%pressure_head)), endpoint%theta(size(physical%water_content)))
      endpoint%head = physical%pressure_head
      endpoint%theta = physical%water_content
    class default
      call require(.false., 'accepted snapshot has B1.10 physical state type')
    end select

    endpoint%storage_start = output%mass%storage_start
    endpoint%storage_end = output%mass%storage_end
    endpoint%mass_residual = output%mass%residual
    endpoint%revision = output%final_revision
    endpoint%accepted_substeps = output%accepted_substeps
    endpoint%retries = output%solver_internal_retries
    endpoint%headcalc_calls = output%solver_headcalc_calls
    endpoint%alternative_solver_calls = output%solver_alternative_solver_calls
    endpoint%solver_route = trim(output%solver_route)
  end subroutine run_route

  subroutine initialize_column_and_template(column, template, column_id)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    integer(int64), intent(in) :: column_id

    template%template_id = 220001_int64
    template%physics_topology_id = 220002_int64
    template%vertical_layout_id = 220003_int64
    template%state_layout_id = 220004_int64
    template%solver_interface_id = 220005_int64
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

  subroutine initialize_parameters(parameters, material)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m
    integer :: i

    m = 1.0_real64 - 1.0_real64 / material%n
    parameters%parameter_set_id = 220012_int64
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
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
    parameters%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_committed(committed, column_id, material, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: column_id
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
      write(*,'(A,1X,A)') 'PUB_P2E01_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_pub_p2e01_e0_paired_pilot

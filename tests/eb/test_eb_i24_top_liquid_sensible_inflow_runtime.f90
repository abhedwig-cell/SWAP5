module mod_eb_i24_provider_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_request_t, &
       fmr_external_bottom_thermal_response_t
  implicit none
  private
  integer(int64), public :: expected_column_id = 0_int64
  integer, public :: provider_calls = 0
  public :: reset_provider, eb_i24_bottom_provider
contains
  subroutine reset_provider(column_id)
    integer(int64), intent(in) :: column_id
    expected_column_id = column_id
    provider_calls = 0
  end subroutine reset_provider

  subroutine eb_i24_bottom_provider(request, response)
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    type(fmr_external_bottom_thermal_response_t), intent(out) :: response
    logical :: ok
    if (.not. request%ready()) error stop 'EB-I24 provider invalid request'
    if (request%column_id() /= expected_column_id) error stop 'EB-I24 provider column mismatch'
    provider_calls = provider_calls + 1
    call response%set_complete(request, 12.5_real64, 824001_int64, ok)
    if (.not. ok) error stop 'EB-I24 provider response failed'
  end subroutine eb_i24_bottom_provider
end module mod_eb_i24_provider_fixture

program test_eb_i24_top_liquid_sensible_inflow_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
  use mod_external_liquid_water_temperature, only: external_liquid_water_temperature_t
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, initialize_soil_temperature_parameters, &
       initialize_soil_temperature_state
  use mod_whole_column_sensible_energy_accounting, only: whole_column_sensible_boundary_t
  use mod_eb_i24_top_liquid_sensible_inflow_runtime, only: eb_i24_sensible_boundary_publication_t, &
       fmr_execute_column_with_top_sensible_inflow, EB_I24_TOP_INFLOW_MATERIALIZED, &
       EB_I24_TOP_DONOR_UNAVAILABLE, EB_I24_TOP_OUTFLOW_UNQUALIFIED, EB_I24_TOP_MULTI_SUBSTEP_UNQUALIFIED
  use mod_eb_i24_provider_fixture, only: reset_provider, eb_i24_bottom_provider
  implicit none

  real(real64), parameter :: t0 = 9240.125_real64
  real(real64), parameter :: t1 = 9240.1251_real64
  real(real64), parameter :: initial_head = -75.0_real64
  real(real64), parameter :: reference_temperature_c = 5.0_real64
  real(real64), parameter :: top_donor_temperature_c = 15.0_real64
  real(real64), parameter :: rho = 1000.0_real64
  real(real64), parameter :: cp = 4180.0_real64
  integer(int64), parameter :: column_id = 924001_int64

  call verify_explicit_inflow_materializes_complete_i22_boundary()
  call verify_external_full_half_route_fails_closed()
  call verify_missing_top_donor_stays_unavailable()
  call verify_top_outflow_does_not_reuse_external_donor()
  call verify_rejected_transaction_has_no_i24_publication()
  write(*,'(A)') 'EB_I24_TOP_LIQUID_SENSIBLE_INFLOW_GATE=PASS'

contains

  subroutine verify_explicit_inflow_materializes_complete_i22_boundary()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i24_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    real(real64) :: inflow_cm, expected_energy
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, -1.0e-10_real64)
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c
    call reset_provider(column_id)
    call fmr_execute_column_with_top_sensible_inflow(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i24_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(output%completed .and. output%committed, 'inflow path committed')
    call require(output%accepted_substeps == 1, 'inflow fixture one accepted substep')
    call require(publication%ready(), 'I24 accepted publication ready')
    call require(publication%top_status() == EB_I24_TOP_INFLOW_MATERIALIZED, 'top inflow materialized status')
    call publication%top_liquid_inflow(inflow_cm, available)
    call require(available .and. inflow_cm > 0.0_real64, 'accepted top liquid inflow available')
    expected_energy = 0.01_real64 * rho * cp * inflow_cm * &
         (top_donor_temperature_c-reference_temperature_c)
    call publication%boundary_snapshot(boundary, available)
    call require(available, 'I24 boundary snapshot available')
    call require(boundary%top_conductive_available, 'inherited top conductive available')
    call require(boundary%bottom_conductive_available, 'inherited bottom conductive available')
    call require(boundary%bottom_advective_available, 'inherited bottom advective available')
    call require(boundary%top_advective_available, 'qualified top advective available')
    call require(close_value(boundary%top_advective_into_j_m2, expected_energy, 1.0e-12_real64), &
         'top sensible energy exact transport law')
    call require(boundary%complete(), 'I22 boundary complete on bounded I24 route')
    call require(publication%runtime_materialization_complete(), 'bounded runtime materialization complete')
    write(*,'(A)') 'EB_I24_ACCEPTED_INFLOW_COMPLETE_I22_BOUNDARY=PASS'
  end subroutine verify_explicit_inflow_materializes_complete_i22_boundary

  subroutine verify_external_full_half_route_fails_closed()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i24_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, -1.0e-10_real64)
    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = huge(1.0_real64)
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c
    call reset_provider(column_id)
    call fmr_execute_column_with_top_sensible_inflow(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i24_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(output%completed .and. output%committed, 'external full-half transaction committed')
    call require(output%accepted_substeps == 1, 'external full-half exposes one canonical commit')
    call require(publication%ready(), 'external full-half accepted publication ready')
    call require(publication%top_status() == EB_I24_TOP_MULTI_SUBSTEP_UNQUALIFIED, &
         'external full-half route explicitly fail-closed')
    call publication%boundary_snapshot(boundary, available)
    call require(available, 'external full-half boundary snapshot available')
    call require(.not. boundary%top_conductive_available, 'final-half observation not promoted as top conductive')
    call require(.not. boundary%bottom_conductive_available, 'final-half observation not promoted as bottom conductive')
    call require(.not. boundary%top_advective_available, 'final-half top flux not promoted as whole-interval advection')
    call require(.not. boundary%complete(), 'external full-half cannot close I22 without carrier')
    call require(.not. publication%runtime_materialization_complete(), &
         'external full-half cannot claim runtime complete without carrier')
    write(*,'(A)') 'EB_I23R_I24R_EXTERNAL_FULL_HALF_FAIL_CLOSED=PASS'
  end subroutine verify_external_full_half_route_fails_closed

  subroutine verify_missing_top_donor_stays_unavailable()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i24_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, -1.0e-10_real64)
    top_temperature%available = .false.
    call reset_provider(column_id)
    call fmr_execute_column_with_top_sensible_inflow(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i24_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(publication%ready(), 'missing donor accepted publication remains ready')
    call require(publication%top_status() == EB_I24_TOP_DONOR_UNAVAILABLE, 'missing donor explicit status')
    call publication%boundary_snapshot(boundary, available)
    call require(available .and. .not. boundary%top_advective_available, 'missing donor is unavailable not zero')
    call require(.not. boundary%complete(), 'missing donor cannot close I22 boundary')
    call require(.not. publication%runtime_materialization_complete(), 'missing donor cannot claim runtime complete')
    write(*,'(A)') 'EB_I24_MISSING_TOP_DONOR_FAIL_CLOSED=PASS'
  end subroutine verify_missing_top_donor_stays_unavailable

  subroutine verify_top_outflow_does_not_reuse_external_donor()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i24_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, 1.0e-10_real64)
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c
    call reset_provider(column_id)
    call fmr_execute_column_with_top_sensible_inflow(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i24_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(publication%ready(), 'outflow accepted publication ready')
    call require(publication%top_status() == EB_I24_TOP_OUTFLOW_UNQUALIFIED, 'outflow donor direction guarded')
    call publication%boundary_snapshot(boundary, available)
    call require(available .and. .not. boundary%top_advective_available, 'external donor not reused for top outflow')
    call require(.not. boundary%complete(), 'top outflow remains fail-closed')
    write(*,'(A)') 'EB_I24_TOP_OUTFLOW_DONOR_DIRECTION_FAIL_CLOSED=PASS'
  end subroutine verify_top_outflow_does_not_reuse_external_donor

  subroutine verify_rejected_transaction_has_no_i24_publication()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i24_sensible_boundary_publication_t) :: publication
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, -1.0e-10_real64)
    parameters%bottom_mode = 6
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c
    call reset_provider(column_id)
    call fmr_execute_column_with_top_sensible_inflow(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i24_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(.not. output%committed .and. committed%current_revision() == 0_int64, 'rejected path stayed precommit')
    call require(output%kernel_status == KERNEL_STATUS_NOT_ADMITTED, 'rejected path kernel status')
    call require(.not. publication%ready(), 'rejected path has no I24 publication')
    write(*,'(A)') 'EB_I24_REJECTED_TRIAL_NO_PUBLICATION=PASS'
  end subroutine verify_rejected_transaction_has_no_i24_publication

  subroutine initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
       runtime, active_calls, energy_parameters, q)
    type(fmr_serialized_reference_backend_t), intent(out) :: backend
    type(fixed_flux_top_boundary_provider_t), target, intent(out) :: top
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_column_diagnostics_t), intent(out) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer, intent(out) :: active_calls
    type(liquid_water_sensible_enthalpy_parameters_t), intent(out) :: energy_parameters
    real(real64), intent(in) :: q
    integer :: enthalpy_status

    call initialize_parameters(parameters)
    call initialize_committed_state(committed, parameters, t0)
    call initialize_forcing(parameters, forcing, q)
    template%template_id = 92401_int64
    template%physics_topology_id = 92402_int64
    template%vertical_layout_id = 92403_int64
    template%state_layout_id = 92404_int64
    template%solver_interface_id = 92405_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 8
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = 2.5e-11_real64
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = t0
    output%requested_t1 = t1
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_calls = 0
    call initialize_liquid_water_sensible_enthalpy_parameters(rho, cp, reference_temperature_c, energy_parameters, &
         enthalpy_status)
    call require(enthalpy_status == LWSE_OK .and. energy_parameters%ready(), 'energy parameters')
    call backend%initialize(top)
  end subroutine initialize_case

  subroutine initialize_parameters(parameters)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    real(real64) :: dz_cm(numnod), distance_above_cm(numnod), theta_sat(numnod)
    real(real64) :: f_quartz(numnod), f_clay(numnod), f_organic(numnod)
    integer :: k, soil_temperature_status
    parameters%parameter_set_id = 92401_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode = 2
    parameters%swkimpl = 0; parameters%swkmean = 1; parameters%swsophy = 0
    parameters%root_extraction_active = .false.; parameters%macropore_active = .false.
    parameters%snow_active = .false.; parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.; parameters%elasticity_active = .false.
    parameters%frost_active = .false.; parameters%max_iterations = 16; parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64; parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64; parameters%soil_temperature_active = .true.
    dz_cm = 100.0_real64 * abs(dz); distance_above_cm = 0.5_real64 * dz_cm
    theta_sat = 0.423_real64; f_quartz = 0.40_real64; f_clay = 0.40_real64; f_organic = 0.10_real64
    allocate(parameters%soil_temperature)
    call initialize_soil_temperature_parameters(dz_cm, distance_above_cm, theta_sat, f_quartz, f_clay, f_organic, &
         parameters%soil_temperature, soil_temperature_status)
    call require(soil_temperature_status == SOIL_TEMP_OK, 'soil temperature parameter initialization')
  end subroutine initialize_parameters

  subroutine initialize_committed_state(committed, parameters, initial_time)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: initial_time
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: initial_temperature(numnod), predecessor_right_derivative(numnod)
    integer :: soil_temperature_status, i
    logical :: ok
    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, t1-t0)
    heads(1) = initial_head
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
    end do
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod), state%soil_temperature)
    state%pressure_head = heads; state%water_content = water
    state%ponding_depth = 0.0_real64; state%groundwater_level = -2.0_real64
    initial_temperature = 9.0_real64
    call initialize_soil_temperature_state(initial_temperature, state%soil_temperature, soil_temperature_status)
    call require(soil_temperature_status == SOIL_TEMP_OK, 'soil temperature state initialization')
    predecessor_right_derivative = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, initial_time, ok, &
         predecessor_right_derivative)
    call require(ok, 'committed state initialization')
  end subroutine initialize_committed_state

  subroutine initialize_forcing(parameters, forcing, q)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: q
    forcing%top_flux = q
    forcing%top_head = initial_head
    forcing%bottom_flux = q
    forcing%bottom_head = -321.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod), forcing%soil_temperature)
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
    forcing%soil_temperature%prescribed_surface_temperature_c = 15.0_real64
    if (parameters%active_nodes /= numnod) error stop 'EB-I24 forcing parameter mismatch'
  end subroutine initialize_forcing

  logical function close_value(a, b, rel_tol) result(close)
    real(real64), intent(in) :: a, b, rel_tol
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    close = abs(a-b) <= rel_tol*scale
  end function close_value

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_I24_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_eb_i24_top_liquid_sensible_inflow_runtime

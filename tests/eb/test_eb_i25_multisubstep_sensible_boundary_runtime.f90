module mod_eb_i25_provider_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_request_t, &
       fmr_external_bottom_thermal_response_t
  implicit none
  private
  integer(int64), public :: expected_column_id = 0_int64
  integer, public :: provider_calls = 0
  public :: reset_provider, eb_i25_bottom_provider
contains
  subroutine reset_provider(column_id)
    integer(int64), intent(in) :: column_id
    expected_column_id = column_id
    provider_calls = 0
  end subroutine reset_provider

  subroutine eb_i25_bottom_provider(request, response)
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    type(fmr_external_bottom_thermal_response_t), intent(out) :: response
    logical :: ok
    if (.not. request%ready()) error stop 'EB-I25 provider invalid request'
    if (request%column_id() /= expected_column_id) error stop 'EB-I25 provider column mismatch'
    provider_calls = provider_calls + 1
    call response%set_complete(request, 12.5_real64, 825001_int64, ok)
    if (.not. ok) error stop 'EB-I25 provider response failed'
  end subroutine eb_i25_bottom_provider
end module mod_eb_i25_provider_fixture

program test_eb_i25_multisubstep_sensible_boundary_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state, &
       fmr_new_b110_temporal_indicator_committed_state
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
       fmr_execute_column_with_top_sensible_inflow
  use mod_eb_i25_multisubstep_sensible_boundary_runtime, only: eb_i25_sensible_boundary_publication_t, &
       fmr_execute_multisubstep_sensible_boundary, EB_I25_TOP_MULTISUBSTEP_INFLOW, &
       EB_I25_TOP_DONOR_UNAVAILABLE, EB_I25_TOP_SINGLE_SUBSTEP_INHERITED
  use mod_eb_i25_provider_fixture, only: reset_provider, eb_i25_bottom_provider
  implicit none

  real(real64), parameter :: t0 = 9250.125_real64
  real(real64), parameter :: t1 = 9250.1251_real64
  real(real64), parameter :: initial_head = -75.0_real64
  real(real64), parameter :: reference_temperature_c = 5.0_real64
  real(real64), parameter :: top_donor_temperature_c = 15.0_real64
  real(real64), parameter :: rho = 1000.0_real64
  real(real64), parameter :: cp = 4180.0_real64
  integer(int64), parameter :: column_id = 925001_int64

  call verify_two_half_inflow_materializes_complete_boundary()
  call verify_two_half_missing_donor_fails_closed()
  call verify_two_half_outflow_fixture_rejects_without_publication()
  call verify_single_substep_matches_i24()
  call verify_rejected_transaction_has_no_i25_publication()
  write(*,'(A)') 'EB_I25_MULTISUBSTEP_SENSIBLE_BOUNDARY_GATE=PASS'

contains

  subroutine verify_two_half_inflow_materializes_complete_boundary()
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
    type(eb_i25_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    real(real64) :: inflow_cm, expected_inflow, expected_energy
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, -1.0e-10_real64, .true.)
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(output%completed .and. output%committed, 'two-half inflow committed')
    call require(output%accepted_substeps == 1, 'external full-half accepted as one canonical commit')
    call require(publication%ready(), 'two-half publication ready')
    call require(publication%accepted_substeps() == 1, 'publication records one canonical commit')
    call require(publication%carrier_sample_count() == 2, 'carrier contains only accepted half steps')
    call require(publication%top_status() == EB_I25_TOP_MULTISUBSTEP_INFLOW, 'two-half inflow status')
    call publication%top_liquid_inflow(inflow_cm, available)
    expected_inflow = 1.0e-10_real64 * (t1-t0)
    call require(available .and. close_value(inflow_cm, expected_inflow, 1.0e-12_real64), &
         'accepted top inflow excludes rejected full trial')
    call publication%boundary_snapshot(boundary, available)
    call require(available, 'two-half boundary snapshot')
    call require(boundary%top_conductive_available, 'aggregated top conductive available')
    call require(boundary%bottom_conductive_available .and. boundary%bottom_conductive_outward_j_m2 == 0.0_real64, &
         'qualified explicit zero bottom conductive')
    call require(boundary%bottom_advective_available, 'receipt-owned bottom advective available')
    call require(boundary%top_advective_available, 'two-half top advective available')
    expected_energy = 0.01_real64 * rho * cp * expected_inflow * &
         (top_donor_temperature_c-reference_temperature_c)
    call require(close_value(boundary%top_advective_into_j_m2, expected_energy, 1.0e-12_real64), &
         'two-half top sensible transport exact law')
    call require(boundary%complete(), 'two-half I22 boundary complete')
    call require(publication%runtime_materialization_complete(), 'two-half runtime materialization complete')
    write(*,'(A)') 'EB_I25_TWO_HALF_ACCEPTED_AGGREGATION=PASS'
  end subroutine verify_two_half_inflow_materializes_complete_boundary

  subroutine verify_two_half_missing_donor_fails_closed()
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
    type(eb_i25_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, -1.0e-10_real64, .true.)
    top_temperature%available = .false.
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(output%accepted_substeps == 1 .and. publication%ready(), 'missing donor external full-half publication')
    call require(publication%carrier_sample_count() == 2, 'missing donor carrier accepted-only')
    call require(publication%top_status() == EB_I25_TOP_DONOR_UNAVAILABLE, 'missing donor explicit status')
    call publication%boundary_snapshot(boundary, available)
    call require(available .and. boundary%top_conductive_available .and. boundary%bottom_conductive_available, &
         'missing donor preserves conductive evidence')
    call require(.not. boundary%top_advective_available, 'missing top donor unavailable not zero')
    call require(.not. boundary%complete() .and. .not. publication%runtime_materialization_complete(), &
         'missing donor remains fail closed')
    write(*,'(A)') 'EB_I25_MISSING_TOP_DONOR_FAIL_CLOSED=PASS'
  end subroutine verify_two_half_missing_donor_fails_closed

  subroutine verify_two_half_outflow_fixture_rejects_without_publication()
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
    type(eb_i25_sensible_boundary_publication_t) :: publication
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, 1.0e-10_real64, .true.)
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(.not. output%completed .and. .not. output%committed .and. output%accepted_substeps == 0, &
         'external full-half outflow fixture rejected before commit')
    call require(committed%current_revision() == 0_int64, 'outflow rejection leaves committed revision unchanged')
    call require(.not. publication%ready(), 'rejected outflow fixture has no I25 publication')
    write(*,'(A)') 'EB_I25_OUTFLOW_FIXTURE_REJECTED_NO_PUBLICATION=PASS'
  end subroutine verify_two_half_outflow_fixture_rejects_without_publication

  subroutine verify_single_substep_matches_i24()
    type(fmr_serialized_reference_backend_t) :: backend24, backend25
    type(kernel_executor_t) :: tx24, tx25
    type(kernel_committed_state_t) :: committed24, committed25
    type(fmr_logical_column_t) :: column24, column25
    type(fmr_template_t) :: template24, template25
    type(fmr_b110_physical_parameters_t) :: parameters24, parameters25
    type(fmr_b110_physical_forcing_t) :: forcing24, forcing25
    type(canonical_numerical_config_t) :: config24, config25
    type(fmr_serialized_column_result_t) :: output24, output25
    type(fmr_column_diagnostics_t) :: diagnostic24, diagnostic25
    type(fmr_serialized_batch_diagnostics_t) :: runtime24, runtime25
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy24, energy25
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i24_sensible_boundary_publication_t) :: publication24
    type(eb_i25_sensible_boundary_publication_t) :: publication25
    type(whole_column_sensible_boundary_t) :: boundary24, boundary25
    type(fixed_flux_top_boundary_provider_t), target :: top24, top25
    integer :: calls24, calls25
    logical :: available24, available25

    call initialize_case(backend24, top24, committed24, column24, template24, parameters24, forcing24, config24, output24, &
         diagnostic24, runtime24, calls24, energy24, -1.0e-10_real64, .false.)
    call initialize_case(backend25, top25, committed25, column25, template25, parameters25, forcing25, config25, output25, &
         diagnostic25, runtime25, calls25, energy25, -1.0e-10_real64, .false.)
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c

    call reset_provider(column_id)
    call fmr_execute_column_with_top_sensible_inflow(backend24, tx24, column24, template24, parameters24, forcing24, &
         committed24, config24, t0, t1, energy24, eb_i25_bottom_provider, top_temperature, output24, diagnostic24, &
         runtime24, calls24, publication24)
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend25, tx25, column25, template25, parameters25, forcing25, &
         committed25, config25, t0, t1, energy25, eb_i25_bottom_provider, top_temperature, output25, diagnostic25, &
         runtime25, calls25, publication25)

    call require(output24%accepted_substeps == 1 .and. output25%accepted_substeps == 1, 'single substep fixtures')
    call require(publication24%ready() .and. publication25%ready(), 'single substep publications')
    call require(publication25%top_status() == EB_I25_TOP_SINGLE_SUBSTEP_INHERITED, 'single substep inheritance status')
    call publication24%boundary_snapshot(boundary24, available24)
    call publication25%boundary_snapshot(boundary25, available25)
    call require(available24 .and. available25, 'single substep boundaries available')
    call require(boundary_equal(boundary24, boundary25), 'I25 single substep exactly matches I24 boundary')
    call require(publication24%runtime_materialization_complete() .eqv. publication25%runtime_materialization_complete(), &
         'I25 single substep completion matches I24')
    write(*,'(A)') 'EB_I25_SINGLE_SUBSTEP_I24_EQUIVALENCE=PASS'
  end subroutine verify_single_substep_matches_i24

  subroutine verify_rejected_transaction_has_no_i25_publication()
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
    type(eb_i25_sensible_boundary_publication_t) :: publication
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, -1.0e-10_real64, .true.)
    parameters%bottom_mode = 6
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &
         config, t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, publication)

    call require(.not. output%committed .and. committed%current_revision() == 0_int64, 'rejected path stayed precommit')
    call require(output%kernel_status == KERNEL_STATUS_NOT_ADMITTED, 'rejected path kernel status')
    call require(.not. publication%ready(), 'rejected path has no I25 publication')
    write(*,'(A)') 'EB_I25_REJECTED_TRIAL_NO_PUBLICATION=PASS'
  end subroutine verify_rejected_transaction_has_no_i25_publication

  subroutine initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
       runtime, active_calls, energy_parameters, q, two_half)
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
    logical, intent(in) :: two_half
    integer :: enthalpy_status

    call initialize_parameters(parameters)
    call initialize_committed_state(committed, parameters, t0, .true.)
    call initialize_forcing(parameters, forcing, q)
    template%template_id = 92501_int64
    template%physics_topology_id = 92502_int64
    template%vertical_layout_id = 92503_int64
    template%state_layout_id = 92504_int64
    template%solver_interface_id = 92505_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    if (two_half) then
      config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
      config%transaction%temporal_tolerance = huge(1.0_real64)
      config%model_temporal_indicator_budget_available = .false.
      config%model_temporal_indicator_budget = 0.0_real64
    else
      config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
      config%transaction%temporal_tolerance = 0.0_real64
      config%model_temporal_indicator_budget_available = .true.
      config%model_temporal_indicator_budget = 2.5e-11_real64
    end if
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 8
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
    parameters%parameter_set_id = 92501_int64
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

  subroutine initialize_committed_state(committed, parameters, initial_time, temporal_history)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: initial_time
    logical, intent(in) :: temporal_history
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
    if (temporal_history) then
      predecessor_right_derivative = 0.0_real64
      call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, initial_time, ok, &
           predecessor_right_derivative)
    else
      call fmr_new_b110_committed_state(committed, column_id, state, initial_time, ok)
    end if
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
    if (parameters%active_nodes /= numnod) error stop 'EB-I25 forcing parameter mismatch'
  end subroutine initialize_forcing

  logical function boundary_equal(a, b) result(equal)
    type(whole_column_sensible_boundary_t), intent(in) :: a, b
    equal = a%top_conductive_available .eqv. b%top_conductive_available
    equal = equal .and. (a%top_advective_available .eqv. b%top_advective_available)
    equal = equal .and. (a%bottom_conductive_available .eqv. b%bottom_conductive_available)
    equal = equal .and. (a%bottom_advective_available .eqv. b%bottom_advective_available)
    equal = equal .and. (a%mass_carried_reference_available .eqv. b%mass_carried_reference_available)
    if (a%top_conductive_available .and. b%top_conductive_available) &
         equal = equal .and. close_value(a%top_conductive_into_j_m2, b%top_conductive_into_j_m2, 1.0e-13_real64)
    if (a%top_advective_available .and. b%top_advective_available) &
         equal = equal .and. close_value(a%top_advective_into_j_m2, b%top_advective_into_j_m2, 1.0e-13_real64)
    if (a%bottom_conductive_available .and. b%bottom_conductive_available) &
         equal = equal .and. close_value(a%bottom_conductive_outward_j_m2, b%bottom_conductive_outward_j_m2, 1.0e-13_real64)
    if (a%bottom_advective_available .and. b%bottom_advective_available) &
         equal = equal .and. close_value(a%bottom_advective_outward_j_m2, b%bottom_advective_outward_j_m2, 1.0e-13_real64)
    if (a%mass_carried_reference_available .and. b%mass_carried_reference_available) &
         equal = equal .and. close_value(a%mass_carried_reference_temperature_c, b%mass_carried_reference_temperature_c, &
              1.0e-13_real64)
  end function boundary_equal

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
      write(*,'(A,1X,A)') 'EB_I25_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_eb_i25_multisubstep_sensible_boundary_runtime

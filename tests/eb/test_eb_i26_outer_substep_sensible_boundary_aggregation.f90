module mod_eb_i26_provider_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_request_t, &
       fmr_external_bottom_thermal_response_t
  implicit none
  private
  integer(int64), public :: expected_column_id = 0_int64
  public :: reset_provider, eb_i26_bottom_provider
contains
  subroutine reset_provider(column_id)
    integer(int64), intent(in) :: column_id
    expected_column_id = column_id
  end subroutine reset_provider

  subroutine eb_i26_bottom_provider(request, response)
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    type(fmr_external_bottom_thermal_response_t), intent(out) :: response
    logical :: ok
    if (.not. request%ready()) error stop 'EB-I26 provider invalid request'
    if (request%column_id() /= expected_column_id) error stop 'EB-I26 provider column mismatch'
    call response%set_complete(request, 12.5_real64, 826001_int64, ok)
    if (.not. ok) error stop 'EB-I26 provider response failed'
  end subroutine eb_i26_bottom_provider
end module mod_eb_i26_provider_fixture

program test_eb_i26_outer_substep_sensible_boundary_aggregation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
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
  use mod_eb_i25_multisubstep_sensible_boundary_runtime, only: eb_i25_sensible_boundary_publication_t, &
       fmr_execute_multisubstep_sensible_boundary
  use mod_eb_i26_outer_substep_sensible_boundary_aggregation, only: &
       eb_i26_outer_substep_sensible_boundary_publication_t, &
       aggregate_accepted_outer_substep_sensible_boundaries, EB_I26_ACCEPTED_COMPLETE, &
       EB_I26_INSUFFICIENT_OUTER_SUBSTEPS, EB_I26_INVALID_SEQUENCE, EB_I26_INCOMPLETE_INPUT
  use mod_eb_i26_provider_fixture, only: reset_provider, eb_i26_bottom_provider
  implicit none

  real(real64), parameter :: t_start = 9250.125_real64
  real(real64), parameter :: dt_outer = 1.0e-4_real64
  real(real64), parameter :: t_mid = t_start + dt_outer
  real(real64), parameter :: t_end = t_start + 2.0_real64*dt_outer
  real(real64), parameter :: initial_head = -75.0_real64
  real(real64), parameter :: reference_temperature_c = 5.0_real64
  real(real64), parameter :: top_donor_temperature_c = 15.0_real64
  real(real64), parameter :: rho = 1000.0_real64
  real(real64), parameter :: cp = 4180.0_real64
  integer(int64), parameter :: column_id = 926001_int64

  call verify_two_outer_commits_aggregate()
  call verify_incomplete_input_fails_closed()
  write(*,'(A)') 'EB_I26_OUTER_SUBSTEP_SENSIBLE_BOUNDARY_GATE=PASS'

contains

  subroutine verify_two_outer_commits_aggregate()
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
    type(eb_i25_sensible_boundary_publication_t) :: p1, p2
    type(eb_i25_sensible_boundary_publication_t) :: sequence(2), one(1), reversed(2), duplicate(2)
    type(eb_i26_outer_substep_sensible_boundary_publication_t) :: aggregate, rejected
    type(whole_column_sensible_boundary_t) :: b1, b2, ba
    type(fixed_flux_top_boundary_provider_t), target :: top
    real(real64) :: q, inflow1, inflow2, inflow_total, agg_t0, agg_t1
    integer :: active_calls
    logical :: available1, available2, availablea, interval_available

    q = -1.0e-10_real64
    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, energy_parameters, q)
    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c

    call initialize_step_outputs(output, diagnostic, runtime, active_calls, t_start, t_mid)
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &
         config, t_start, t_mid, energy_parameters, eb_i26_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, p1)
    call require(output%completed .and. output%committed, 'first outer transaction committed')
    call require(committed%current_revision() == 1_int64, 'first outer revision')
    call require(p1%ready() .and. p1%accepted_substeps() == 1 .and. p1%carrier_sample_count() == 2, &
         'first outer accepted I25 publication')

    call initialize_step_outputs(output, diagnostic, runtime, active_calls, t_mid, t_end)
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &
         config, t_mid, t_end, energy_parameters, eb_i26_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, p2)
    if (.not. output%completed .or. .not. output%committed) then
      write(*,'(A,1X,L1,1X,L1,1X,I0,1X,I0,1X,A,1X,A,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0,1X,L1,1X,ES24.16E3)') &
           'EB_I26_SECOND_OUTER_DIAG', output%completed, output%committed, output%kernel_status, output%commit_status, &
           trim(output%admission_status), trim(diagnostic%failure_classification), output%accepted_substeps, &
           diagnostic%attempts, diagnostic%retries, int(output%initial_revision), int(output%final_revision), &
           output%mass%complete, output%mass%residual
    end if
    call require(output%completed .and. output%committed, 'second outer transaction committed')
    call require(committed%current_revision() == 2_int64, 'second outer revision')
    call require(p2%ready() .and. p2%accepted_substeps() == 1 .and. p2%carrier_sample_count() == 2, &
         'second outer accepted I25 publication')
    call require(p2%origin_revision() == p1%committed_revision(), 'I25 revision chain')

    sequence(1) = p1
    sequence(2) = p2
    call aggregate_accepted_outer_substep_sensible_boundaries(sequence, aggregate)
    call require(aggregate%ready(), 'I26 aggregate ready')
    call require(aggregate%status() == EB_I26_ACCEPTED_COMPLETE, 'I26 complete status')
    call require(aggregate%accepted_outer_substeps() == 2, 'two accepted outer commits')
    call require(aggregate%accepted_internal_half_samples() == 4, 'four accepted internal half samples')
    call require(aggregate%origin_revision() == 0_int64 .and. aggregate%committed_revision() == 2_int64, &
         'aggregate revision span')
    call aggregate%origin_interval(agg_t0, agg_t1, interval_available)
    call require(interval_available .and. close_value(agg_t0, t_start, 1.0e-13_real64) .and. &
         close_value(agg_t1, t_end, 1.0e-13_real64), 'aggregate interval span')

    call p1%boundary_snapshot(b1, available1)
    call p2%boundary_snapshot(b2, available2)
    call aggregate%boundary_snapshot(ba, availablea)
    call require(available1 .and. available2 .and. availablea, 'boundary snapshots available')
    call require(ba%complete(), 'aggregate sensible boundary complete')
    call require(close_value(ba%top_conductive_into_j_m2, b1%top_conductive_into_j_m2 + b2%top_conductive_into_j_m2, &
         1.0e-12_real64), 'top conductive sum')
    call require(close_value(ba%top_advective_into_j_m2, b1%top_advective_into_j_m2 + b2%top_advective_into_j_m2, &
         1.0e-12_real64), 'top advective sum')
    call require(close_value(ba%bottom_conductive_outward_j_m2, &
         b1%bottom_conductive_outward_j_m2 + b2%bottom_conductive_outward_j_m2, 1.0e-12_real64), &
         'bottom conductive sum')
    call require(close_value(ba%bottom_advective_outward_j_m2, &
         b1%bottom_advective_outward_j_m2 + b2%bottom_advective_outward_j_m2, 1.0e-12_real64), &
         'bottom advective sum')
    call require(close_value(ba%mass_carried_reference_temperature_c, reference_temperature_c, 1.0e-13_real64), &
         'reference temperature preserved')

    call p1%top_liquid_inflow(inflow1, available1)
    call p2%top_liquid_inflow(inflow2, available2)
    call aggregate%top_liquid_inflow(inflow_total, availablea)
    call require(available1 .and. available2 .and. availablea, 'top inflow values available')
    call require(close_value(inflow_total, inflow1 + inflow2, 1.0e-12_real64), 'top inflow sum')
    call require(aggregate%runtime_materialization_complete(), 'I26 runtime materialization complete')
    write(*,'(A)') 'EB_I26_TWO_OUTER_FOUR_HALF_AGGREGATION=PASS'

    one(1) = p1
    call aggregate_accepted_outer_substep_sensible_boundaries(one, rejected)
    call require(.not. rejected%ready() .and. rejected%status() == EB_I26_INSUFFICIENT_OUTER_SUBSTEPS, &
         'single outer input rejected')
    write(*,'(A)') 'EB_I26_SINGLE_OUTER_REJECTED=PASS'

    reversed(1) = p2
    reversed(2) = p1
    call aggregate_accepted_outer_substep_sensible_boundaries(reversed, rejected)
    call require(.not. rejected%ready() .and. rejected%status() == EB_I26_INVALID_SEQUENCE, &
         'reversed revision/time sequence rejected')
    write(*,'(A)') 'EB_I26_REVERSED_SEQUENCE_REJECTED=PASS'

    duplicate(1) = p1
    duplicate(2) = p1
    call aggregate_accepted_outer_substep_sensible_boundaries(duplicate, rejected)
    call require(.not. rejected%ready() .and. rejected%status() == EB_I26_INVALID_SEQUENCE, &
         'duplicate accepted publication rejected')
    write(*,'(A)') 'EB_I26_DUPLICATE_SEQUENCE_REJECTED=PASS'
  end subroutine verify_two_outer_commits_aggregate

  subroutine verify_incomplete_input_fails_closed()
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
    type(eb_i25_sensible_boundary_publication_t) :: p1, p2, sequence(2)
    type(eb_i26_outer_substep_sensible_boundary_publication_t) :: aggregate
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, energy_parameters, &
         -1.0e-10_real64)

    top_temperature%available = .true.
    top_temperature%temperature_c = top_donor_temperature_c
    call initialize_step_outputs(output, diagnostic, runtime, active_calls, t_start, t_mid)
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &
         config, t_start, t_mid, energy_parameters, eb_i26_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, p1)
    call require(p1%ready() .and. p1%runtime_materialization_complete(), 'complete first input fixture')

    top_temperature%available = .false.
    call initialize_step_outputs(output, diagnostic, runtime, active_calls, t_mid, t_end)
    call reset_provider(column_id)
    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &
         config, t_mid, t_end, energy_parameters, eb_i26_bottom_provider, top_temperature, output, diagnostic, runtime, &
         active_calls, p2)
    call require(p2%ready() .and. .not. p2%runtime_materialization_complete(), 'incomplete second I25 publication')

    sequence(1) = p1
    sequence(2) = p2
    call aggregate_accepted_outer_substep_sensible_boundaries(sequence, aggregate)
    call require(.not. aggregate%ready() .and. aggregate%status() == EB_I26_INCOMPLETE_INPUT, &
         'incomplete accepted input fails closed')
    write(*,'(A)') 'EB_I26_INCOMPLETE_INPUT_FAIL_CLOSED=PASS'
  end subroutine verify_incomplete_input_fails_closed

  subroutine initialize_case(backend, top, committed, column, template, parameters, forcing, config, energy_parameters, q)
    type(fmr_serialized_reference_backend_t), intent(out) :: backend
    type(fixed_flux_top_boundary_provider_t), target, intent(out) :: top
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    type(liquid_water_sensible_enthalpy_parameters_t), intent(out) :: energy_parameters
    real(real64), intent(in) :: q
    integer :: enthalpy_status

    call initialize_parameters(parameters)
    call initialize_committed_state(committed, parameters, t_start, dt_outer)
    call initialize_forcing(parameters, forcing, q)
    template%template_id = 92601_int64
    template%physics_topology_id = 92602_int64
    template%vertical_layout_id = 92603_int64
    template%state_layout_id = 92604_int64
    template%solver_interface_id = 92605_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = huge(1.0_real64)
    config%model_temporal_indicator_budget_available = .false.
    config%model_temporal_indicator_budget = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 8
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
    call initialize_liquid_water_sensible_enthalpy_parameters(rho, cp, reference_temperature_c, energy_parameters, &
         enthalpy_status)
    call require(enthalpy_status == LWSE_OK .and. energy_parameters%ready(), 'energy parameters')
    call backend%initialize(top)
  end subroutine initialize_case

  subroutine initialize_step_outputs(output, diagnostic, runtime, active_calls, step_t0, step_t1)
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_column_diagnostics_t), intent(out) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer, intent(out) :: active_calls
    real(real64), intent(in) :: step_t0, step_t1
    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = step_t0
    output%requested_t1 = step_t1
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_calls = 0
  end subroutine initialize_step_outputs

  subroutine initialize_parameters(parameters)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    real(real64) :: dz_cm(numnod), distance_above_cm(numnod), theta_sat(numnod)
    real(real64) :: f_quartz(numnod), f_clay(numnod), f_organic(numnod)
    integer :: k, soil_temperature_status

    parameters%parameter_set_id = 92601_int64
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
    dz_cm = 100.0_real64 * abs(dz)
    distance_above_cm = 0.5_real64 * dz_cm
    theta_sat = 0.423_real64
    f_quartz = 0.40_real64
    f_clay = 0.40_real64
    f_organic = 0.10_real64
    allocate(parameters%soil_temperature)
    call initialize_soil_temperature_parameters(dz_cm, distance_above_cm, theta_sat, f_quartz, f_clay, f_organic, &
         parameters%soil_temperature, soil_temperature_status)
    call require(soil_temperature_status == SOIL_TEMP_OK, 'soil temperature parameter initialization')
  end subroutine initialize_parameters

  subroutine initialize_committed_state(committed, parameters, initial_time, provider_step)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: initial_time, provider_step
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: initial_temperature(numnod), predecessor_right_derivative(numnod)
    integer :: soil_temperature_status, i
    logical :: ok

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, provider_step)
    heads(1) = initial_head
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
    end do
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod), state%soil_temperature)
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
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
    if (parameters%active_nodes /= numnod) error stop 'EB-I26 forcing parameter mismatch'
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
      write(*,'(A,1X,A)') 'EB_I26_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_eb_i26_outer_substep_sensible_boundary_aggregation

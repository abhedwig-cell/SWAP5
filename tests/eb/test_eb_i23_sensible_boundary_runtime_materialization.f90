module mod_eb_i23_provider_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_request_t, &
       fmr_external_bottom_thermal_response_t
  implicit none
  private

  integer, parameter, public :: PROVIDER_COMPLETE = 1
  integer, parameter, public :: PROVIDER_UNAVAILABLE = 2
  integer, public :: provider_mode = PROVIDER_COMPLETE
  integer, public :: provider_calls = 0
  integer(int64), public :: expected_column_id = 0_int64
  real(real64), public :: donor_temperature_c = 12.5_real64

  public :: reset_provider, eb_i23_external_provider

contains

  subroutine reset_provider(mode, column_id)
    integer, intent(in) :: mode
    integer(int64), intent(in) :: column_id
    provider_mode = mode
    provider_calls = 0
    expected_column_id = column_id
  end subroutine reset_provider

  subroutine eb_i23_external_provider(request, response)
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    type(fmr_external_bottom_thermal_response_t), intent(out) :: response
    logical :: ok

    if (.not. request%ready()) error stop 'EB-I23 provider received invalid request'
    if (request%column_id() /= expected_column_id) error stop 'EB-I23 provider column mismatch'
    provider_calls = provider_calls + 1

    select case (provider_mode)
    case (PROVIDER_COMPLETE)
      call response%set_complete(request, donor_temperature_c, 823001_int64, ok)
      if (.not. ok) error stop 'EB-I23 complete provider response failed'
    case (PROVIDER_UNAVAILABLE)
      call response%set_unavailable(request, 823002_int64, ok)
      if (.not. ok) error stop 'EB-I23 unavailable provider response failed'
    case default
      error stop 'EB-I23 unknown provider mode'
    end select
  end subroutine eb_i23_external_provider

end module mod_eb_i23_provider_fixture

program test_eb_i23_sensible_boundary_runtime_materialization
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, initialize_soil_temperature_parameters, &
       initialize_soil_temperature_state
  use mod_whole_column_sensible_energy_accounting, only: whole_column_sensible_boundary_t
  use mod_eb_i23_sensible_boundary_runtime, only: EB_I23_ACCEPTED_PARTIAL, &
       eb_i23_sensible_boundary_publication_t, fmr_execute_column_with_sensible_boundary
  use mod_eb_i23_provider_fixture, only: PROVIDER_COMPLETE, PROVIDER_UNAVAILABLE, provider_calls, &
       reset_provider, eb_i23_external_provider
  implicit none

  real(real64), parameter :: t0 = 9230.125_real64
  real(real64), parameter :: t1 = 9230.1251_real64
  real(real64), parameter :: initial_head = -75.0_real64
  real(real64), parameter :: reference_temperature_c = 5.0_real64
  real(real64), parameter :: rho = 1000.0_real64
  real(real64), parameter :: cp = 4180.0_real64
  integer(int64), parameter :: column_id = 923001_int64

  call verify_single_substep_partial_materialization()
  call verify_bottom_external_unavailable_stays_unavailable()
  call verify_rejected_transaction_has_no_publication()

  write(*,'(A)') 'EB_I23_SENSIBLE_BOUNDARY_RUNTIME_MATERIALIZATION_GATE=PASS'

contains

  subroutine verify_single_substep_partial_materialization()
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
    type(eb_i23_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fmr_serialized_physical_observation_t) :: observation
    type(fixed_flux_top_boundary_provider_t), target :: top
    real(real64) :: pt0, pt1, expected_top
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters)
    call reset_provider(PROVIDER_COMPLETE, column_id)
    call fmr_execute_column_with_sensible_boundary(backend, tx, column, template, parameters, &
         forcing, committed, config, t0, t1, energy_parameters, eb_i23_external_provider, output, diagnostic, runtime, &
         active_calls, publication)

    call require(output%completed .and. output%committed, 'complete path committed')
    call require(output%accepted_substeps == 1, 'fixture remains one accepted substep')
    call require(committed%current_revision() == 1_int64, 'single commit revision')
    call require(publication%ready(), 'accepted partial publication ready')
    call require(publication%status() == EB_I23_ACCEPTED_PARTIAL, 'accepted partial status')
    call require(publication%column_id() == column_id, 'publication column identity')
    call require(publication%origin_revision() == 0_int64 .and. publication%committed_revision() == 1_int64, &
         'publication revision identity')
    call publication%origin_interval(pt0, pt1, available)
    call require(available .and. same_value(pt0,t0) .and. same_value(pt1,t1), 'publication interval identity')

    call publication%boundary_snapshot(boundary, available)
    call require(available, 'boundary snapshot available')
    call require(boundary%top_conductive_available, 'top conductive accepted materialization')
    call require(boundary%bottom_conductive_available, 'bottom conductive restricted-BC materialization')
    call require(boundary%bottom_conductive_outward_j_m2 == 0.0_real64, 'bottom conductive explicit zero')
    call require(boundary%bottom_advective_available, 'accepted bottom advective materialization')
    call require(.not. boundary%top_advective_available, 'top advective authority stays unavailable')
    call require(boundary%mass_carried_reference_available, 'mass reference provenance available')
    call require(boundary%mass_carried_reference_temperature_c == reference_temperature_c, 'reference temperature preserved')
    call require(.not. boundary%complete(), 'I22 boundary remains fail-closed without top advective')
    call require(.not. publication%runtime_materialization_complete(), 'I23 must not claim complete runtime materialization')

    observation = backend%observation()
    call require(observation%soil_temperature_energy_accounting_complete, 'thermal accounting authority complete')
    expected_top = 1.0e4_real64 * observation%soil_temperature_boundary_energy_j_cm2
    call require(ieee_is_finite(expected_top), 'converted top conductive finite')
    call require(close_value(boundary%top_conductive_into_j_m2, expected_top, 1.0e-12_real64), &
         'J/cm2 to J/m2 conversion identity')
    call require(provider_calls > 0, 'external bottom provider exercised')
    write(*,'(A)') 'EB_I23_ACCEPTED_SINGLE_SUBSTEP_PARTIAL_MATERIALIZATION=PASS'
  end subroutine verify_single_substep_partial_materialization

  subroutine verify_bottom_external_unavailable_stays_unavailable()
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
    type(eb_i23_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters)
    call reset_provider(PROVIDER_UNAVAILABLE, column_id)
    call fmr_execute_column_with_sensible_boundary(backend, tx, column, template, parameters, &
         forcing, committed, config, t0, t1, energy_parameters, eb_i23_external_provider, output, diagnostic, runtime, &
         active_calls, publication)

    call require(output%committed .and. publication%ready(), 'unavailable donor still accepted publication')
    call publication%boundary_snapshot(boundary, available)
    call require(available, 'unavailable donor boundary snapshot exists')
    call require(boundary%top_conductive_available .and. boundary%bottom_conductive_available, &
         'conductive evidence preserved when bottom donor unavailable')
    call require(.not. boundary%bottom_advective_available, 'missing bottom donor is not zero energy')
    call require(.not. boundary%top_advective_available, 'top advective remains unavailable')
    call require(.not. boundary%complete(), 'unavailable donor cannot close I22 boundary')
    call require(provider_calls > 0, 'unavailable external provider exercised')
    write(*,'(A)') 'EB_I23_BOTTOM_ADVECTIVE_UNAVAILABLE_FAIL_CLOSED=PASS'
  end subroutine verify_bottom_external_unavailable_stays_unavailable

  subroutine verify_rejected_transaction_has_no_publication()
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
    type(eb_i23_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters)
    parameters%bottom_mode = 6
    call reset_provider(PROVIDER_COMPLETE, column_id)
    call fmr_execute_column_with_sensible_boundary(backend, tx, column, template, parameters, &
         forcing, committed, config, t0, t1, energy_parameters, eb_i23_external_provider, output, diagnostic, runtime, &
         active_calls, publication)

    call require(.not. output%committed .and. committed%current_revision() == 0_int64, 'rejected path stayed precommit')
    call require(output%kernel_status == KERNEL_STATUS_NOT_ADMITTED, 'rejected path kernel status')
    call require(.not. publication%ready(), 'rejected trial has no accepted I23 publication')
    call publication%boundary_snapshot(boundary, available)
    call require(.not. available, 'rejected trial has no boundary snapshot')
    call require(provider_calls == 0, 'rejected path did not query external donor provider')
    write(*,'(A)') 'EB_I23_REJECTED_TRIAL_NO_PUBLICATION=PASS'
  end subroutine verify_rejected_transaction_has_no_publication

  subroutine initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
       runtime, active_calls, energy_parameters)
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
    integer :: enthalpy_status

    call initialize_parameters(parameters)
    call initialize_committed_state(committed, parameters, t0)
    call initialize_forcing(parameters, forcing)

    template%template_id = 92301_int64
    template%physics_topology_id = 92302_int64
    template%vertical_layout_id = 92303_int64
    template%state_layout_id = 92304_int64
    template%solver_interface_id = 92305_int64
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

    parameters%parameter_set_id = 92301_int64
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
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%soil_temperature_active = .true.
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

  subroutine initialize_forcing(parameters, forcing)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64) :: q

    q = 1.0e-10_real64
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
    if (parameters%active_nodes /= numnod) error stop 'EB-I23 forcing parameter mismatch'
  end subroutine initialize_forcing

  logical function same_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    matches = abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
  end function same_value

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
      write(*,'(A,1X,A)') 'EB_I23_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i23_sensible_boundary_runtime_materialization
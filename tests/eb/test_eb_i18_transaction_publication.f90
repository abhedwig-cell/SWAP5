module mod_eb_i18_provider_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_request_t, &
       fmr_external_bottom_thermal_response_t, initialize_fmr_external_bottom_thermal_request
  implicit none
  private

  integer, parameter, public :: PROVIDER_COMPLETE = 1
  integer, parameter, public :: PROVIDER_UNAVAILABLE = 2
  integer, parameter, public :: PROVIDER_STALE = 3
  integer, parameter, public :: PROVIDER_MISMATCH = 4
  integer, parameter, public :: PROVIDER_INVALID = 5

  integer, public :: provider_mode = PROVIDER_COMPLETE
  integer, public :: provider_calls = 0
  real(real64), public :: requested_exchange_sum = 0.0_real64
  integer(int64), public :: expected_column_id = 0_int64
  real(real64), public :: donor_temperature_c = 12.5_real64

  public :: reset_provider
  public :: eb_i18_external_provider

contains

  subroutine reset_provider(mode, column_id)
    integer, intent(in) :: mode
    integer(int64), intent(in) :: column_id
    provider_mode = mode
    provider_calls = 0
    requested_exchange_sum = 0.0_real64
    expected_column_id = column_id
  end subroutine reset_provider

  subroutine eb_i18_external_provider(request, response)
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    type(fmr_external_bottom_thermal_response_t), intent(out) :: response
    type(fmr_external_bottom_thermal_request_t) :: wrong_request
    real(real64) :: q, rt0, rt1
    logical :: available, ok

    if (.not. request%ready()) error stop 'EB-I18 provider received invalid request'
    if (request%column_id() /= expected_column_id) error stop 'EB-I18 provider column mismatch'
    if (request%sample_ordinal() <= 0) error stop 'EB-I18 provider ordinal invalid'
    call request%interval(rt0, rt1, available)
    if (.not. available .or. rt1 <= rt0) error stop 'EB-I18 provider interval invalid'
    call request%bottom_outward_exchange_native(q, available)
    if (.not. available .or. q >= 0.0_real64) error stop 'EB-I18 provider non-external request'

    provider_calls = provider_calls + 1
    requested_exchange_sum = requested_exchange_sum + q

    select case (provider_mode)
    case (PROVIDER_COMPLETE)
      call response%set_complete(request, donor_temperature_c, 81001_int64, ok)
      if (.not. ok) error stop 'EB-I18 provider complete response failed'
    case (PROVIDER_UNAVAILABLE)
      call response%set_unavailable(request, 81002_int64, ok)
      if (.not. ok) error stop 'EB-I18 provider unavailable response failed'
    case (PROVIDER_STALE)
      call response%set_stale(request, 81003_int64, ok)
      if (.not. ok) error stop 'EB-I18 provider stale response failed'
    case (PROVIDER_MISMATCH)
      call initialize_fmr_external_bottom_thermal_request(request%column_id(), request%sample_ordinal(), rt0, rt1, &
           2.0_real64*q, wrong_request, ok)
      if (.not. ok) error stop 'EB-I18 wrong request construction failed'
      call response%set_complete(wrong_request, donor_temperature_c, 81004_int64, ok)
      if (.not. ok) error stop 'EB-I18 mismatched response construction failed'
    case (PROVIDER_INVALID)
      call response%set_complete(request, donor_temperature_c, -1_int64, ok)
      if (ok) error stop 'EB-I18R invalid response unexpectedly ready'
    case default
      error stop 'EB-I18 unknown provider mode'
    end select
  end subroutine eb_i18_external_provider

end module mod_eb_i18_provider_fixture

program test_eb_i18_transaction_publication
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_serialized_bottom_energy_publication_t, fmr_execute_serialized_column_with_bottom_energy
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, initialize_soil_temperature_parameters, &
       initialize_soil_temperature_state
  use mod_fmr_bottom_sensible_energy, only: FMR_BOTTOM_ENERGY_COMPLETE, FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR
  use mod_eb_i18_provider_fixture, only: PROVIDER_COMPLETE, PROVIDER_UNAVAILABLE, PROVIDER_STALE, &
       PROVIDER_MISMATCH, PROVIDER_INVALID, provider_calls, requested_exchange_sum, donor_temperature_c, &
       reset_provider, eb_i18_external_provider
  implicit none

  real(real64), parameter :: t0 = 9100.125_real64
  real(real64), parameter :: t1 = 9100.1251_real64
  real(real64), parameter :: initial_head = -75.0_real64
  real(real64), parameter :: reference_temperature_c = 5.0_real64
  real(real64), parameter :: rho = 1000.0_real64
  real(real64), parameter :: cp = 4180.0_real64
  integer(int64), parameter :: column_id = 918001_int64

  call verify_external_complete()
  call verify_external_unavailable()
  call verify_external_stale()
  call verify_external_identity_mismatch()
  call verify_external_invalid_response()
  call verify_rejected_trial_has_no_publication()
  call verify_backend_reuse_has_no_stale_publication()

  write(*,'(A)') 'EB_I18_TRANSACTION_PUBLICATION_GATE PASS'

contains

  subroutine verify_external_complete()
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
    type(fmr_serialized_bottom_energy_publication_t) :: publication
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls, status, requested, complete, unavailable, stale, invalid
    real(real64) :: total, expected
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters)
    call reset_provider(PROVIDER_COMPLETE, column_id)
    call fmr_execute_serialized_column_with_bottom_energy(backend, tx, column, template, parameters, &
         forcing, committed, config, t0, t1, energy_parameters, eb_i18_external_provider, output, diagnostic, &
         runtime, active_calls, publication)

    call require(output%completed .and. output%committed, 'complete provider hydrology committed')
    call require(output%mass%complete, 'complete provider water mass accounting complete')
    call require(abs(output%mass%residual) <= 1.0e-12_real64, 'complete provider hard water mass gate')
    call require(output%accepted_substeps == 1, 'complete provider exactly one accepted substep')
    call require(output%solver_headcalc_calls == 1, 'complete provider bounded one-trajectory HeadCalc cost')
    call require(committed%current_revision() == 1_int64, 'complete provider single commit')
    call require(publication%ready() .and. publication%complete(), 'complete provider publication complete')
    call require(publication%energy_status() == FMR_BOTTOM_ENERGY_COMPLETE, 'complete provider energy status')
    call publication%provider_counts(requested, complete, unavailable, stale, invalid)
    call require(requested > 0 .and. requested == provider_calls, 'complete provider request count')
    call require(complete == requested .and. unavailable == 0 .and. stale == 0 .and. invalid == 0, &
         'complete provider disposition counts')
    call publication%total_energy(total, available)
    call require(available, 'complete provider total available')
    expected = 0.01_real64*rho*cp*requested_exchange_sum*(donor_temperature_c-reference_temperature_c)
    call require(close_value(total, expected, 1.0e-10_real64), 'complete provider I04 energy identity')
    call require(publication%column_id() == column_id, 'complete provider column identity')
    call require(publication%origin_revision() == 0_int64 .and. publication%committed_revision() == 1_int64, &
         'complete provider accepted revision identity')
    write(*,'(A)') 'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS'
  end subroutine verify_external_complete

  subroutine verify_external_unavailable()
    call verify_noncomplete_provider(PROVIDER_UNAVAILABLE, 1, 0, 'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS')
  end subroutine verify_external_unavailable

  subroutine verify_external_stale()
    call verify_noncomplete_provider(PROVIDER_STALE, 0, 1, 'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS')
  end subroutine verify_external_stale

  subroutine verify_external_identity_mismatch()
    call verify_invalid_provider(PROVIDER_MISMATCH, 'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS')
  end subroutine verify_external_identity_mismatch

  subroutine verify_external_invalid_response()
    call verify_invalid_provider(PROVIDER_INVALID, 'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS')
  end subroutine verify_external_invalid_response

  subroutine verify_noncomplete_provider(mode, expect_unavailable, expect_stale, marker)
    integer, intent(in) :: mode, expect_unavailable, expect_stale
    character(len=*), intent(in) :: marker
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
    type(fmr_serialized_bottom_energy_publication_t) :: publication
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls, requested, complete, unavailable, stale, invalid
    real(real64) :: total
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters)
    call reset_provider(mode, column_id)
    call fmr_execute_serialized_column_with_bottom_energy(backend, tx, column, template, parameters, &
         forcing, committed, config, t0, t1, energy_parameters, eb_i18_external_provider, output, diagnostic, &
         runtime, active_calls, publication)

    call require(output%completed .and. output%committed .and. committed%current_revision() == 1_int64, &
         'noncomplete provider hydrology committed')
    call require(publication%ready() .and. .not. publication%complete(), 'noncomplete publication explicit unavailable')
    call require(publication%energy_status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR, &
         'noncomplete provider energy status')
    call publication%provider_counts(requested, complete, unavailable, stale, invalid)
    call require(requested > 0 .and. requested == provider_calls, 'noncomplete provider request count')
    call require(complete == 0 .and. unavailable == expect_unavailable*requested .and. &
         stale == expect_stale*requested .and. invalid == 0, 'noncomplete provider disposition counts')
    call publication%total_energy(total, available)
    call require(.not. available .and. total == 0.0_real64, 'noncomplete provider no zero-energy fallback availability')
    write(*,'(A)') trim(marker)
  end subroutine verify_noncomplete_provider

  subroutine verify_invalid_provider(mode, marker)
    integer, intent(in) :: mode
    character(len=*), intent(in) :: marker
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
    type(fmr_serialized_bottom_energy_publication_t) :: publication
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls, requested, complete, unavailable, stale, invalid
    real(real64) :: total
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters)
    call reset_provider(mode, column_id)
    call fmr_execute_serialized_column_with_bottom_energy(backend, tx, column, template, parameters, &
         forcing, committed, config, t0, t1, energy_parameters, eb_i18_external_provider, output, diagnostic, &
         runtime, active_calls, publication)

    call require(output%completed .and. output%committed .and. committed%current_revision() == 1_int64, &
         'invalid provider hydrology committed')
    call require(publication%ready() .and. .not. publication%complete(), 'invalid provider publication unavailable')
    call publication%provider_counts(requested, complete, unavailable, stale, invalid)
    call require(requested > 0 .and. requested == provider_calls .and. invalid == requested, &
         'invalid provider diagnostics')
    call require(complete == 0 .and. unavailable == 0 .and. stale == 0, 'invalid provider no false disposition')
    call publication%total_energy(total, available)
    call require(.not. available, 'invalid provider total unavailable')
    write(*,'(A)') trim(marker)
  end subroutine verify_invalid_provider

  subroutine verify_rejected_trial_has_no_publication()
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
    type(fmr_serialized_bottom_energy_publication_t) :: publication
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters)
    parameters%bottom_mode = 6
    call reset_provider(PROVIDER_COMPLETE, column_id)
    call fmr_execute_serialized_column_with_bottom_energy(backend, tx, column, template, parameters, &
         forcing, committed, config, t0, t1, energy_parameters, eb_i18_external_provider, output, diagnostic, &
         runtime, active_calls, publication)

    call require(.not. output%committed .and. committed%current_revision() == 0_int64, 'rejected route stayed precommit')
    call require(output%kernel_status == KERNEL_STATUS_NOT_ADMITTED, 'rejected route kernel status')
    call require(.not. publication%ready(), 'rejected route no accepted energy publication')
    call require(provider_calls == 0, 'rejected route did not query external provider')
    write(*,'(A)') 'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS'
  end subroutine verify_rejected_trial_has_no_publication

  subroutine verify_backend_reuse_has_no_stale_publication()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed_a, committed_b
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output_a, output_b
    type(fmr_column_diagnostics_t) :: diagnostic_a, diagnostic_b
    type(fmr_serialized_batch_diagnostics_t) :: runtime_a, runtime_b
    type(fmr_serialized_bottom_energy_publication_t) :: publication_a, publication_b
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls, requested, complete, unavailable, stale, invalid

    call initialize_case(backend, top, committed_a, column, template, parameters, forcing, config, output_a, diagnostic_a, &
         runtime_a, active_calls, energy_parameters)
    call reset_provider(PROVIDER_COMPLETE, column_id)
    call fmr_execute_serialized_column_with_bottom_energy(backend, tx, column, template, parameters, &
         forcing, committed_a, config, t0, t1, energy_parameters, eb_i18_external_provider, output_a, diagnostic_a, &
         runtime_a, active_calls, publication_a)
    call require(publication_a%ready() .and. publication_a%complete(), 'reuse first publication complete')

    call initialize_committed_state(committed_b, parameters, t0)
    output_b = fmr_serialized_column_result_t(); output_b%column_id = column_id; output_b%requested_t0=t0; output_b%requested_t1=t1
    diagnostic_b = fmr_column_diagnostics_t(); diagnostic_b%column_id = column_id
    runtime_b = fmr_serialized_batch_diagnostics_t(); active_calls = 0
    call reset_provider(PROVIDER_UNAVAILABLE, column_id)
    call fmr_execute_serialized_column_with_bottom_energy(backend, tx, column, template, parameters, &
         forcing, committed_b, config, t0, t1, energy_parameters, eb_i18_external_provider, output_b, diagnostic_b, &
         runtime_b, active_calls, publication_b)

    call require(output_b%committed .and. committed_b%current_revision() == 1_int64, 'reuse second hydrology committed')
    call require(publication_b%ready() .and. .not. publication_b%complete(), 'reuse second publication not stale complete')
    call publication_b%provider_counts(requested, complete, unavailable, stale, invalid)
    call require(requested > 0 .and. complete == 0 .and. unavailable == requested .and. stale == 0 .and. invalid == 0, &
         'reuse second diagnostics belong to second transaction')
    write(*,'(A)') 'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS'
  end subroutine verify_backend_reuse_has_no_stale_publication

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

    template%template_id = 91801_int64
    template%physics_topology_id = 91802_int64
    template%vertical_layout_id = 91803_int64
    template%state_layout_id = 91804_int64
    template%solver_interface_id = 91805_int64
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

    parameters%parameter_set_id = 91801_int64
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
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod), k0, q

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, t1-t0)
    heads = initial_head
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    k0 = conductivity(1)
    q = 1.0e-10_real64

    ! Positive bottom flux is inflow to SWAP. Use the already-qualified
    ! F-MR44R bounded throughflow fixture so temporal acceptance, mass closure
    ! and thermal publication are tested on the same committed candidate.
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
      write(*,'(A,1X,A)') 'EB_I18_TRANSACTION_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i18_transaction_publication

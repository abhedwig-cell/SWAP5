program test_ppa_wu03_common_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK, FMR_APP_BOOT_INVALID_CONFIG
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, &
       B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_REGIME_FLUX, B110_DYN_TOP_REGIME_HEAD
  use mod_reference_et_demand_process, only: reference_et_demand_result_t, &
       reference_et_demand_diagnostics_t, REF_ET_DEMAND_OK
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, &
       fmr_evaluate_reference_et_demand, FMR_REFERENCE_ET_BINDING_OK
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_config_t, &
       ppa_wu03_common_forcing_input_t, ppa_wu03_common_forcing_result_t, &
       ppa_wu03_common_forcing_diagnostics_t, materialize_ppa_wu03_common_forcing, &
       bind_ppa_wu03_flux_result_to_effective_forcing, PPA_WU03_OK, &
       PPA_WU03_UNSUPPORTED_ET, PPA_WU03_UNSUPPORTED_INTERCEPTION, &
       PPA_WU03_UNSUPPORTED_IRRIGATION, PPA_WU03_TOP_RESULT_REJECTED, &
       PPA_WU03_ET_REFERENCE, PPA_WU03_INTERCEPTION_NONE, &
       PPA_WU03_IRRIGATION_NONE, PPA_WU03_IRRIGATION_RESOLVED_SURFACE
  implicit none

  real(real64), parameter :: T0 = 4100.1875_real64
  real(real64), parameter :: T1 = 4100.4375_real64
  real(real64), parameter :: T2 = 4100.5625_real64
  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: HARD_MASS_GATE = 1.0e-12_real64
  real(real64), parameter :: TOL = 1.0e-12_real64

  type(fmr_production_application_config_t) :: app_config
  type(fmr_production_application_bootstrap_t) :: direct_app, adapter_app
  type(ppa_wu03_common_forcing_config_t) :: forcing_config, bad_forcing_config
  type(ppa_wu03_common_forcing_input_t) :: normal_input, input_a, input_b, bad_input
  type(ppa_wu03_common_forcing_result_t) :: adapter_result, result_a1, result_a2, result_b
  type(ppa_wu03_common_forcing_diagnostics_t) :: adapter_diag, diag_a1, diag_a2, diag_b
  type(b110_dynamic_top_boundary_request_t) :: base_request, direct_request
  type(b110_dynamic_top_boundary_result_t) :: preliminary_top, adapter_top, direct_top, bad_top
  type(reference_et_demand_result_t) :: direct_et
  type(reference_et_demand_diagnostics_t) :: direct_et_process_diag
  type(fmr_reference_et_binding_diagnostics_t) :: direct_et_binding_diag
  type(fmr_b110_physical_forcing_t), allocatable :: adapter_forcing(:), empty_forcing(:)
  type(fmr_serialized_column_result_t), allocatable :: direct_results(:), adapter_results(:)
  integer(int64), allocatable :: direct_revisions(:), adapter_revisions(:)
  real(real64) :: conductivity0, irrigation_rate, preliminary_evap, qtarget
  real(real64) :: nan_value
  integer :: status, direct_status, adapter_status

  call initialize_application_config(app_config, conductivity0)
  call initialize_base_top_request(app_config, T0, T1, base_request)

  forcing_config%et_mode = PPA_WU03_ET_REFERENCE
  forcing_config%interception_mode = PPA_WU03_INTERCEPTION_NONE
  forcing_config%irrigation_mode = PPA_WU03_IRRIGATION_RESOLVED_SURFACE
  forcing_config%reference_et_parameters%pond_evaporation_factor = 1.0_real64

  normal_input%interval%t0 = T0
  normal_input%interval%t1 = T1
  normal_input%forcing_t0 = T0 - 0.125_real64
  normal_input%forcing_t1 = T1 + 0.125_real64
  normal_input%reference_et%t0 = normal_input%forcing_t0
  normal_input%reference_et%t1 = normal_input%forcing_t1
  normal_input%reference_et%reference_et_mm_per_day = 0.05_real64
  normal_input%canopy%crop_emerged = .true.
  normal_input%canopy%vegetation_cover_fraction = 0.30_real64
  normal_input%canopy%crop_factor = 1.0_real64
  normal_input%canopy%co2_transpiration_factor = 1.0_real64
  irrigation_rate = 0.10_real64 * conductivity0
  normal_input%surface_irrigation_rate_cm_per_day = irrigation_rate
  normal_input%precipitation_rate_cm_per_day = 0.0_real64

  ! Resolve only the already-admitted surface-demand operator first.  The
  ! resulting actual dry-surface evaporation is then used to build a steady
  ! pure-flux qualification point whose effective top flux equals WU01's
  ! direct typed forcing.
  call materialize_ppa_wu03_common_forcing(forcing_config, normal_input, base_request, &
       adapter_result, adapter_diag)
  call require(adapter_diag%status == PPA_WU03_OK .and. adapter_result%valid, &
       'preliminary common forcing materialization')
  call evaluate_dynamic_top(app_config, adapter_result%top_request, preliminary_top)
  call require(preliminary_top%status == B110_DYN_TOP_AVAILABLE, 'preliminary dynamic top available')
  preliminary_evap = preliminary_top%bare_soil_evaporation_cm_per_day + &
       preliminary_top%ponded_water_evaporation_cm_per_day
  qtarget = conductivity0
  normal_input%precipitation_rate_cm_per_day = qtarget + preliminary_evap - irrigation_rate
  call require(normal_input%precipitation_rate_cm_per_day >= 0.0_real64, 'derived precipitation nonnegative')

  call materialize_ppa_wu03_common_forcing(forcing_config, normal_input, base_request, &
       adapter_result, adapter_diag)
  call require(adapter_diag%status == PPA_WU03_OK .and. adapter_result%valid, &
       'final common forcing materialization')
  call require(adapter_diag%interval_valid .and. adapter_diag%forcing_span_valid .and. &
       adapter_diag%forcing_covers_interval, 'generic forcing span accepted')

  ! Direct typed authority path.  This is independently assembled from the
  ! already-admitted reference-ET binding rather than from the WU03 result.
  call fmr_evaluate_reference_et_demand(normal_input%interval, normal_input%reference_et, &
       forcing_config%reference_et_parameters, normal_input%canopy, direct_et, &
       direct_et_process_diag, direct_et_binding_diag)
  call require(direct_et_binding_diag%status == FMR_REFERENCE_ET_BINDING_OK .and. &
       direct_et_process_diag%status == REF_ET_DEMAND_OK, 'direct reference ET authority')
  direct_request = base_request
  direct_request%step_duration_day = T1 - T0
  direct_request%precipitation_rate_cm_per_day = normal_input%precipitation_rate_cm_per_day
  direct_request%irrigation_rate_cm_per_day = normal_input%surface_irrigation_rate_cm_per_day
  direct_request%snowmelt_rate_cm_per_day = 0.0_real64
  direct_request%runon_rate_cm_per_day = 0.0_real64
  direct_request%potential_bare_soil_evaporation_cm_per_day = direct_et%potential_soil_evaporation_cm_per_day
  direct_request%potential_pond_evaporation_cm_per_day = direct_et%potential_pond_evaporation_cm_per_day

  call require(abs(adapter_result%reference_et_demand%potential_transpiration_cm_per_day - &
       direct_et%potential_transpiration_cm_per_day) <= TOL, 'typed reference ET transpiration identity')
  call require(abs(adapter_result%top_request%precipitation_rate_cm_per_day - &
       direct_request%precipitation_rate_cm_per_day) <= TOL, 'typed precipitation identity')
  call require(abs(adapter_result%top_request%irrigation_rate_cm_per_day - &
       direct_request%irrigation_rate_cm_per_day) <= TOL, 'typed irrigation identity')
  call require(abs(adapter_result%top_request%potential_bare_soil_evaporation_cm_per_day - &
       direct_request%potential_bare_soil_evaporation_cm_per_day) <= TOL, 'typed soil evaporation identity')
  call require(abs(adapter_result%top_request%potential_pond_evaporation_cm_per_day - &
       direct_request%potential_pond_evaporation_cm_per_day) <= TOL, 'typed pond evaporation identity')

  call evaluate_dynamic_top(app_config, adapter_result%top_request, adapter_top)
  call evaluate_dynamic_top(app_config, direct_request, direct_top)
  call require(adapter_top%status == B110_DYN_TOP_AVAILABLE .and. &
       adapter_top%regime == B110_DYN_TOP_REGIME_FLUX, 'adapter dynamic top pure flux')
  call require(direct_top%status == B110_DYN_TOP_AVAILABLE .and. &
       direct_top%regime == B110_DYN_TOP_REGIME_FLUX, 'direct dynamic top pure flux')
  call require(abs(adapter_top%actual_top_flux_cm_per_day - direct_top%actual_top_flux_cm_per_day) <= TOL, &
       'dynamic top direct-adapter identity')
  call require(abs(adapter_top%actual_top_flux_cm_per_day - app_config%tiles(1)%base_forcing%top_flux) <= TOL, &
       'adapter reproduces WU01 direct effective top flux')

  allocate(adapter_forcing(1))
  call bind_ppa_wu03_flux_result_to_effective_forcing(app_config%tiles(1)%base_forcing, adapter_top, &
       adapter_forcing(1), status)
  call require(status == PPA_WU03_OK, 'pure-flux effective forcing handoff')
  call require(abs(adapter_forcing(1)%top_flux - app_config%tiles(1)%base_forcing%top_flux) <= TOL, &
       'effective forcing top flux identity')

  ! Direct typed forcing and WU03 forcing both drive the same PPA-WU01 owner
  ! implementation from identical initial states.
  call direct_app%initialize(app_config, direct_status)
  call adapter_app%initialize(app_config, adapter_status)
  call require(direct_status == FMR_APP_BOOT_OK .and. adapter_status == FMR_APP_BOOT_OK, &
       'paired PPA-WU01 owners initialize')
  call direct_app%run_standalone(T0, T1, direct_results, direct_status)
  call adapter_app%run_standalone_with_forcing(T0, T1, adapter_forcing, adapter_results, adapter_status)
  call require(direct_status == FMR_APP_BOOT_OK .and. adapter_status == FMR_APP_BOOT_OK, &
       'direct and adapter owner runs complete')
  call require(size(direct_results) == 1 .and. size(adapter_results) == 1, 'paired result count')
  call require(direct_results(1)%completed .and. direct_results(1)%committed .and. &
       adapter_results(1)%completed .and. adapter_results(1)%committed, 'paired commits')
  call require(abs(direct_results(1)%mass%storage_end - adapter_results(1)%mass%storage_end) <= TOL, &
       'physics storage identity')
  call require(abs(direct_results(1)%mass%total_in - adapter_results(1)%mass%total_in) <= TOL, &
       'physics inflow identity')
  call require(abs(direct_results(1)%mass%total_out - adapter_results(1)%mass%total_out) <= TOL, &
       'physics outflow identity')
  call require(abs(direct_results(1)%mass%residual - adapter_results(1)%mass%residual) <= TOL, &
       'physics mass identity')
  call require(abs(adapter_results(1)%mass%residual) <= HARD_MASS_GATE, 'adapter hard mass gate')

  call direct_app%copy_committed_revisions(direct_revisions, direct_status)
  call adapter_app%copy_committed_revisions(adapter_revisions, adapter_status)
  call require(all(direct_revisions == 1_int64) .and. all(adapter_revisions == 1_int64), &
       'first interval owner revision')

  ! A second subdaily interval uses the same live owner.  No application
  ! bootstrap or committed-state replacement occurs between intervals.
  call direct_app%run_standalone(T1, T2, direct_results, direct_status)
  call adapter_app%run_standalone_with_forcing(T1, T2, adapter_forcing, adapter_results, adapter_status)
  call require(direct_status == FMR_APP_BOOT_OK .and. adapter_status == FMR_APP_BOOT_OK, &
       'second generic-time owner interval')
  call require(abs(direct_results(1)%mass%storage_end - adapter_results(1)%mass%storage_end) <= TOL, &
       'second interval storage identity')
  call direct_app%copy_committed_revisions(direct_revisions, direct_status)
  call adapter_app%copy_committed_revisions(adapter_revisions, adapter_status)
  call require(all(direct_revisions == 2_int64) .and. all(adapter_revisions == 2_int64), &
       'PPA-WU01 retains committed-state ownership')

  ! Stateless A-B-A materialization proves that retries or repeated requests
  ! cannot consume or advance hidden adapter input.
  input_a = normal_input
  input_b = normal_input
  input_b%reference_et%reference_et_mm_per_day = 0.075_real64
  input_b%precipitation_rate_cm_per_day = input_b%precipitation_rate_cm_per_day + 0.003_real64
  call materialize_ppa_wu03_common_forcing(forcing_config, input_a, base_request, result_a1, diag_a1)
  call materialize_ppa_wu03_common_forcing(forcing_config, input_b, base_request, result_b, diag_b)
  call materialize_ppa_wu03_common_forcing(forcing_config, input_a, base_request, result_a2, diag_a2)
  call require(diag_a1%status == PPA_WU03_OK .and. diag_b%status == PPA_WU03_OK .and. &
       diag_a2%status == PPA_WU03_OK, 'A-B-A materialization accepted')
  call require(result_a1%top_request%precipitation_rate_cm_per_day == &
       result_a2%top_request%precipitation_rate_cm_per_day, 'A-B-A precipitation bit identity')
  call require(result_a1%reference_et_demand%potential_soil_evaporation_cm_per_day == &
       result_a2%reference_et_demand%potential_soil_evaporation_cm_per_day, 'A-B-A ET bit identity')
  call require(result_a1%top_request%potential_pond_evaporation_cm_per_day == &
       result_a2%top_request%potential_pond_evaporation_cm_per_day, 'A-B-A pond demand bit identity')

  ! Fail-closed selectors and malformed forcing.
  bad_forcing_config = forcing_config
  bad_forcing_config%et_mode = 99
  call materialize_ppa_wu03_common_forcing(bad_forcing_config, normal_input, base_request, result_b, diag_b)
  call require(diag_b%status == PPA_WU03_UNSUPPORTED_ET .and. .not. result_b%valid, 'unsupported ET fails closed')

  bad_forcing_config = forcing_config
  bad_forcing_config%interception_mode = 3
  call materialize_ppa_wu03_common_forcing(bad_forcing_config, normal_input, base_request, result_b, diag_b)
  call require(diag_b%status == PPA_WU03_UNSUPPORTED_INTERCEPTION .and. .not. result_b%valid, &
       'unsupported interception fails closed')

  bad_forcing_config = forcing_config
  bad_forcing_config%irrigation_mode = 7
  call materialize_ppa_wu03_common_forcing(bad_forcing_config, normal_input, base_request, result_b, diag_b)
  call require(diag_b%status == PPA_WU03_UNSUPPORTED_IRRIGATION .and. .not. result_b%valid, &
       'unsupported irrigation fails closed')

  bad_forcing_config = forcing_config
  bad_forcing_config%irrigation_mode = PPA_WU03_IRRIGATION_NONE
  call materialize_ppa_wu03_common_forcing(bad_forcing_config, normal_input, base_request, result_b, diag_b)
  call require(diag_b%status == PPA_WU03_UNSUPPORTED_IRRIGATION .and. .not. result_b%valid, &
       'nonzero irrigation under NONE fails closed')

  bad_input = normal_input
  bad_input%forcing_t0 = T0 + 0.01_real64
  call materialize_ppa_wu03_common_forcing(forcing_config, bad_input, base_request, result_b, diag_b)
  call require(.not. result_b%valid, 'noncovering forcing span fails closed')

  bad_input = normal_input
  bad_input%precipitation_rate_cm_per_day = -1.0_real64
  call materialize_ppa_wu03_common_forcing(forcing_config, bad_input, base_request, result_b, diag_b)
  call require(.not. result_b%valid, 'negative precipitation fails closed')

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  bad_input = normal_input
  bad_input%surface_irrigation_rate_cm_per_day = nan_value
  call materialize_ppa_wu03_common_forcing(forcing_config, bad_input, base_request, result_b, diag_b)
  call require(.not. result_b%valid, 'nonfinite irrigation fails closed')

  bad_top = adapter_top
  bad_top%regime = B110_DYN_TOP_REGIME_HEAD
  call bind_ppa_wu03_flux_result_to_effective_forcing(app_config%tiles(1)%base_forcing, bad_top, &
       adapter_forcing(1), status)
  call require(status == PPA_WU03_TOP_RESULT_REJECTED, 'non-flux top result fails closed')

  allocate(empty_forcing(0))
  call adapter_app%run_standalone_with_forcing(T1, T2, empty_forcing, adapter_results, status)
  call require(status == FMR_APP_BOOT_INVALID_CONFIG, 'owner forcing cardinality fails closed')

  call direct_app%close(direct_status)
  call adapter_app%close(adapter_status)
  call require(direct_status == FMR_APP_BOOT_OK .and. adapter_status == FMR_APP_BOOT_OK, 'owners close cleanly')

  print '(a)', 'PPA_WU03_COMMON_NORMAL_INPUT_TO_TYPED_FORCING=PASS'
  print '(a)', 'PPA_WU03_GENERIC_SUBDAILY_TIME=PASS'
  print '(a)', 'PPA_WU03_DIRECT_TYPED_PHYSICS_IDENTITY=PASS'
  print '(a)', 'PPA_WU03_PPA_WU01_OWNER_PRESERVED=PASS'
  print '(a)', 'PPA_WU03_RETRY_INPUT_STATELESS_ABA=PASS'
  print '(a)', 'PPA_WU03_UNSUPPORTED_OPTIONS_FAIL_CLOSED=PASS'
  print '(a)', 'PPA_WU03_HARD_MASS=PASS'
  print '(a)', 'PPA-WU03 COMMON FORCING OWNER GATE PASS'

contains

  subroutine initialize_application_config(value, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(out) :: conductivity0

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 630101_int64
    value%tiles(1)%ledger_id = 730101_int64
    value%tiles(1)%template%template_id = 630201_int64
    value%tiles(1)%template%physics_topology_id = 630210_int64
    value%tiles(1)%template%vertical_layout_id = 630220_int64
    value%tiles(1)%template%state_layout_id = 630230_int64
    value%tiles(1)%template%solver_interface_id = 630240_int64
    value%tiles(1)%template%optional_state_layout_id = 0_int64
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_parameters(value%tiles(1)%parameters)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 640001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 7
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_state_and_forcing(p, state, forcing, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    heads = H0_CM
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity0
    forcing%top_head = H0_CM
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = 1.0e-5_real64 * real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -2.0e-6_real64 * real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
           forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine initialize_state_and_forcing

  subroutine initialize_base_top_request(value, ta, tb, request)
    type(fmr_production_application_config_t), intent(in) :: value
    real(real64), intent(in) :: ta, tb
    type(b110_dynamic_top_boundary_request_t), intent(out) :: request

    request = b110_dynamic_top_boundary_request_t()
    request%conductivity_mean_method = value%tiles(1)%parameters%swkmean
    request%pressure_head_top_cm = value%tiles(1)%initial_state%pressure_head(1)
    request%water_content_top = value%tiles(1)%initial_state%water_content(1)
    request%candidate_ponding_depth_cm = 0.0_real64
    request%previous_ponding_depth_cm = 0.0_real64
    request%step_duration_day = tb - ta
    request%ponding_max_cm = 2.0_real64
    request%runoff_resistance_day = 1.0_real64
    request%runoff_exponent = 1.0_real64
  end subroutine initialize_base_top_request

  subroutine evaluate_dynamic_top(value, request, result)
    type(fmr_production_application_config_t), intent(in) :: value
    type(b110_dynamic_top_boundary_request_t), intent(in) :: request
    type(b110_dynamic_top_boundary_result_t), intent(out) :: result

    type(soil_water_parameter_set_t) :: geometry
    type(b110_default_mvg_parameters_t) :: hydraulics

    geometry%parameter_set_id = value%tiles(1)%parameters%parameter_set_id
    geometry%active_nodes = value%tiles(1)%parameters%active_nodes
    allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), &
         geometry%node_distance(geometry%active_nodes))
    geometry%z = value%tiles(1)%parameters%z
    geometry%dz = value%tiles(1)%parameters%dz
    geometry%node_distance = value%tiles(1)%parameters%node_distance
    call initialize_b110_default_mvg_parameters(hydraulics, value%tiles(1)%parameters%cofgen)
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, request, result)
  end subroutine evaluate_dynamic_top

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU03_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu03_common_forcing_adapter

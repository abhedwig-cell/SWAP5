program test_ppa_wu04a_black_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_restricted_surface_evaporation, only: black_evaporation_parameters_t, black_evaporation_state_t, &
       black_evaporation_forcing_t, black_evaporation_result_t, evaluate_black_evaporation_reduction, &
       BLACK_EVAP_AVAILABLE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_black_evaporation_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_black_evaporation_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_reference_et_demand_process, only: reference_et_demand_parameters_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_forcing_span_t
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_config_t, &
       ppa_wu03_common_forcing_input_t, ppa_wu03_common_forcing_result_t, &
       ppa_wu03_common_forcing_diagnostics_t, materialize_ppa_wu03_common_forcing, &
       PPA_WU03_OK, PPA_WU03_ET_REFERENCE, PPA_WU03_INTERCEPTION_NONE, &
       PPA_WU03_IRRIGATION_RESOLVED_SURFACE
  use mod_ppa_wu04a_black_forcing_adapter, only: bind_ppa_wu04a_black_runtime_forcing, PPA_WU04A_BIND_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_TEMPLATE_MISMATCH
  implicit none

  real(real64), parameter :: T0 = 5100.125_real64
  real(real64), parameter :: TM = 5100.250_real64
  real(real64), parameter :: T1 = 5100.375_real64
  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: HARD_MASS_GATE = 1.0e-12_real64
  real(real64), parameter :: COFRED = 0.35_real64
  real(real64), parameter :: INITIAL_LDWET = 2.0_real64
  integer(int64), parameter :: PARAMETER_SET_IDENTITY = 404001_int64

  type(fmr_production_application_config_t) :: app_config
  type(fmr_production_application_bootstrap_t) :: app
  type(ppa_wu03_common_forcing_config_t) :: common_config
  type(ppa_wu03_common_forcing_input_t) :: common_input
  type(ppa_wu03_common_forcing_result_t) :: common_result
  type(ppa_wu03_common_forcing_diagnostics_t) :: common_diag
  type(b110_dynamic_top_boundary_request_t) :: base_request, oracle_request
  type(b110_dynamic_top_boundary_result_t) :: oracle_top
  type(black_evaporation_parameters_t) :: black_p
  type(black_evaporation_state_t) :: black_s
  type(black_evaporation_forcing_t) :: black_f
  type(black_evaporation_result_t) :: black_r
  type(fmr_b110_physical_forcing_t), allocatable :: bound_forcing(:)
  type(fmr_serialized_column_result_t), allocatable :: app_results(:)
  integer(int64), allocatable :: revisions(:)
  real(real64) :: conductivity0, preliminary_evaporation, qtarget
  integer :: status

  call initialize_application_config(app_config, conductivity0)
  call initialize_base_top_request(app_config, base_request)

  common_config%et_mode = PPA_WU03_ET_REFERENCE
  common_config%interception_mode = PPA_WU03_INTERCEPTION_NONE
  common_config%irrigation_mode = PPA_WU03_IRRIGATION_RESOLVED_SURFACE
  common_config%reference_et_parameters%pond_evaporation_factor = 1.0_real64

  common_input%interval%t0 = T0
  common_input%interval%t1 = T1
  common_input%forcing_t0 = T0
  common_input%forcing_t1 = T1
  common_input%reference_et%t0 = T0
  common_input%reference_et%t1 = T1
  common_input%reference_et%reference_et_mm_per_day = 0.5_real64
  common_input%canopy%crop_emerged = .true.
  common_input%canopy%vegetation_cover_fraction = 0.30_real64
  common_input%canopy%crop_factor = 1.0_real64
  common_input%canopy%co2_transpiration_factor = 1.0_real64
  common_input%surface_irrigation_rate_cm_per_day = 0.10_real64 * conductivity0
  common_input%precipitation_rate_cm_per_day = 0.0_real64

  call materialize_ppa_wu03_common_forcing(common_config, common_input, base_request, common_result, common_diag)
  call require(common_diag%status == PPA_WU03_OK .and. common_result%valid, 'initial WU03 common forcing')

  black_p%cofred = COFRED
  black_s%ldwet = INITIAL_LDWET
  black_f%potential_bare_soil_evaporation = common_result%top_request%potential_bare_soil_evaporation_cm_per_day
  call evaluate_black_evaporation_reduction(black_p, black_s, black_f, T1-T0, black_r)
  call require(black_r%status == BLACK_EVAP_AVAILABLE, 'independent Black source oracle')

  oracle_request = common_result%top_request
  oracle_request%potential_bare_soil_evaporation_cm_per_day = black_r%empirical_bare_soil_evaporation_demand
  call evaluate_dynamic_top(app_config, oracle_request, oracle_top)
  call require(oracle_top%status == B110_DYN_TOP_AVAILABLE, 'independent dynamic top oracle')
  preliminary_evaporation = oracle_top%bare_soil_evaporation_cm_per_day + oracle_top%ponded_water_evaporation_cm_per_day
  qtarget = conductivity0
  common_input%precipitation_rate_cm_per_day = qtarget + preliminary_evaporation - &
       common_input%surface_irrigation_rate_cm_per_day
  call require(common_input%precipitation_rate_cm_per_day >= 0.0_real64, 'derived precipitation nonnegative')

  call materialize_ppa_wu03_common_forcing(common_config, common_input, base_request, common_result, common_diag)
  call require(common_diag%status == PPA_WU03_OK .and. common_result%valid, 'final WU03 common forcing')

  allocate(bound_forcing(1))
  call bind_ppa_wu04a_black_runtime_forcing(app_config%tiles(1)%base_forcing, common_result, .false., T0, &
       bound_forcing(1), status)
  call require(status == PPA_WU04A_BIND_OK, 'WU04A Black runtime forcing binding')
  call require(allocated(bound_forcing(1)%black_evaporation), 'Black forcing component allocated')
  call require(bound_forcing(1)%top_flux == 0.0_real64, 'legacy fixed top flux neutralized')

  call app%initialize(app_config, status)
  call require(status == FMR_APP_BOOT_OK .and. app%ready(), 'Black production bootstrap')
  call app%run_standalone_with_forcing(T0, T1, bound_forcing, app_results, status)
  call require(status == FMR_APP_BOOT_OK, 'Black production application run')
  call require(allocated(app_results) .and. size(app_results) == 1, 'Black application result count')
  call require(app_results(1)%completed .and. app_results(1)%committed, 'Black application committed')
  call require(app_results(1)%mass%complete, 'Black application mass complete')
  call require(abs(app_results(1)%mass%residual) <= HARD_MASS_GATE, 'Black application hard mass')
  call app%copy_committed_revisions(revisions, status)
  call require(status == FMR_APP_BOOT_OK .and. revisions(1) == 1_int64, 'Black single committed revision')
  call app%close(status)
  call require(status == FMR_APP_BOOT_OK, 'Black application close')
  print '(a)', 'PPA_WU04A_PRODUCTION_APPLICATION_REACHABLE=PASS'
  print '(a)', 'PPA_WU04A_ACTUAL_EVAPORATION_HYDRAULIC_MASS_OWNER=PASS'
  print '(a)', 'PPA_WU04A_HARD_MASS=PASS'

  call verify_transaction_retry_and_restart(app_config, bound_forcing(1))
  call verify_wetting_event_boundary(app_config, common_result)

  print '(a)', 'PPA-WU04-A BLACK RUNTIME TEST PASS'

contains

  subroutine verify_transaction_retry_and_restart(config_source, forcing)
    type(fmr_production_application_config_t), intent(in) :: config_source
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(fmr_serialized_reference_backend_t) :: backend, direct_backend
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template, bad_template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(kernel_committed_state_t) :: committed, direct_committed
    type(kernel_committed_state_t), allocatable :: states(:), restored_states(:)
    type(kernel_checkpoint_t) :: checkpoint, direct_checkpoint
    type(kernel_candidate_state_t) :: full_candidate, retry_candidate, direct_candidate
    type(kernel_result_t) :: full_result, retry_result, direct_result
    type(kernel_diagnostics_t) :: full_diag, retry_diag, direct_diag
    type(canonical_numerical_config_t) :: numerical
    type(black_evaporation_state_t) :: initial_black
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:), bad_templates(:)
    type(fmr_committed_restart_bundle_t) :: bundle
    logical :: ok, did_commit, exported, restored
    integer :: commit_status, restart_status
    real(real64) :: ldwet0, ldwet_full, ldwet_retry, ldwet_direct, ldwet_committed, ldwet_restored

    column%column_id = 404101_int64
    column%template_id = config_source%tiles(1)%template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    template = config_source%tiles(1)%template
    parameters = config_source%tiles(1)%parameters
    numerical = config_source%numerical
    initial_black%ldwet = INITIAL_LDWET

    call fmr_new_b110_black_evaporation_committed_state(committed, column%column_id, &
         config_source%tiles(1)%initial_state, initial_black, T0, ok)
    call require(ok, 'low-level Black committed state')
    call committed%capture_checkpoint(checkpoint, ok)
    call require(ok .and. checkpoint%ready(), 'Black checkpoint capture')
    call snapshot_ldwet_committed(committed, ldwet0)
    call require(same_bits(ldwet0, INITIAL_LDWET), 'initial LDWET exact')

    call backend%initialize(top)
    call backend%run_trial(column, template, parameters, committed, forcing, numerical, T0, T1, checkpoint, &
         full_result, full_candidate, full_diag)
    call require(full_result%completed .and. full_candidate%ready(), 'full Black trial candidate')
    call snapshot_ldwet_candidate(full_candidate, ldwet_full)
    call require(ldwet_full > ldwet0, 'full candidate advanced LDWET')

    call backend%discard_trial_candidate(full_candidate, full_diag)
    call snapshot_ldwet_committed(committed, ldwet_committed)
    call require(same_bits(ldwet_committed, ldwet0), 'discarded full trial did not mutate committed LDWET')
    call require(committed%current_revision() == 0_int64, 'discarded full trial did not mutate revision')

    call backend%run_trial(column, template, parameters, committed, forcing, numerical, T0, TM, checkpoint, &
         retry_result, retry_candidate, retry_diag)
    call require(retry_result%completed .and. retry_candidate%ready(), 'changed-dt retry candidate')
    call snapshot_ldwet_candidate(retry_candidate, ldwet_retry)

    call fmr_new_b110_black_evaporation_committed_state(direct_committed, column%column_id + 1_int64, &
         config_source%tiles(1)%initial_state, initial_black, T0, ok)
    call require(ok, 'direct retry committed state')
    call direct_committed%capture_checkpoint(direct_checkpoint, ok)
    call require(ok, 'direct retry checkpoint')
    column%column_id = column%column_id + 1_int64
    call direct_backend%initialize(top)
    call direct_backend%run_trial(column, template, parameters, direct_committed, forcing, numerical, T0, TM, &
         direct_checkpoint, direct_result, direct_candidate, direct_diag)
    call require(direct_result%completed .and. direct_candidate%ready(), 'direct retry candidate')
    call snapshot_ldwet_candidate(direct_candidate, ldwet_direct)
    call require(same_bits(ldwet_retry, ldwet_direct), 'retry candidate equals direct same-dt candidate')
    print '(a)', 'PPA_WU04A_REJECTED_TRIAL_LDWET_IMMUTABLE=PASS'
    print '(a)', 'PPA_WU04A_CHANGED_DT_RETRY_FROM_CHECKPOINT=PASS'

    column%column_id = 404101_int64
    call backend%commit_trial_candidate(committed, retry_candidate, retry_diag, did_commit, commit_status)
    call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'retry candidate commit')
    call snapshot_ldwet_committed(committed, ldwet_committed)
    call require(same_bits(ldwet_committed, ldwet_retry), 'accepted candidate LDWET committed')

    allocate(columns(1), templates(1), states(1), restored_states(1), bad_templates(1))
    columns(1) = column
    templates(1) = template
    states(1) = committed
    call fmr_export_committed_restart(columns, templates, states, PARAMETER_SET_IDENTITY, bundle, exported, restart_status)
    call require(exported .and. restart_status == FMR_RESTART_OK, 'Black restart export')
    call require(allocated(bundle%records) .and. size(bundle%records) == 1, 'Black restart record count')

    call fmr_restore_committed_restart(bundle, PARAMETER_SET_IDENTITY, columns, templates, restored_states, restored, &
         restart_status)
    call require(restored .and. restart_status == FMR_RESTART_OK, 'Black restart restore')
    call snapshot_ldwet_committed(restored_states(1), ldwet_restored)
    call require(same_bits(ldwet_restored, ldwet_committed), 'Black restart exact LDWET roundtrip')

    bad_templates = templates
    bad_templates(1)%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    restored_states = kernel_committed_state_t()
    call fmr_restore_committed_restart(bundle, PARAMETER_SET_IDENTITY, columns, bad_templates, restored_states, restored, &
         restart_status)
    call require(.not. restored .and. restart_status == FMR_RESTART_TEMPLATE_MISMATCH, &
         'Black to BASE restart layout mismatch rejected')
    print '(a)', 'PPA_WU04A_RESTART_EXACT_LDWET_ROUNDTRIP=PASS'
    print '(a)', 'PPA_WU04A_RESTART_OPTION_LAYOUT_FAIL_CLOSED=PASS'
  end subroutine verify_transaction_retry_and_restart

  subroutine verify_wetting_event_boundary(config_source, common)
    type(fmr_production_application_config_t), intent(in) :: config_source
    type(ppa_wu03_common_forcing_result_t), intent(in) :: common
    type(fmr_b110_physical_forcing_t) :: forcing
    integer :: local_status

    call bind_ppa_wu04a_black_runtime_forcing(config_source%tiles(1)%base_forcing, common, .true., T0, &
         forcing, local_status)
    call require(local_status == PPA_WU04A_BIND_OK, 'explicit wetting event binding')
    call require(forcing%black_evaporation%wetting_reset_event, 'explicit wetting event retained')
    call require(same_bits(forcing%black_evaporation%wetting_event_time, T0), 'explicit wetting event time exact')
    print '(a)', 'PPA_WU04A_EXPLICIT_EVENT_FORCING_HANDOFF=PASS'
  end subroutine verify_wetting_event_boundary

  subroutine initialize_application_config(value, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(out) :: conductivity0
    integer :: k

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 404101_int64
    value%tiles(1)%ledger_id = 0_int64
    value%tiles(1)%template%template_id = 404201_int64
    value%tiles(1)%template%physics_topology_id = 404210_int64
    value%tiles(1)%template%vertical_layout_id = 404220_int64
    value%tiles(1)%template%state_layout_id = 404230_int64
    value%tiles(1)%template%solver_interface_id = 404240_int64
    value%tiles(1)%template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    value%tiles(1)%initial_black_ldwet = INITIAL_LDWET

    call initialize_parameters(value%tiles(1)%parameters)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 404301_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
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
    p%black_evaporation_active = .true.
    allocate(p%black_evaporation)
    p%black_evaporation%cofred = COFRED
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
    call bind_b110_default_mvg_provider(provider, hp, T1-T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = 0.0_real64
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

  subroutine initialize_base_top_request(value, request)
    type(fmr_production_application_config_t), intent(in) :: value
    type(b110_dynamic_top_boundary_request_t), intent(out) :: request

    request = b110_dynamic_top_boundary_request_t()
    request%conductivity_mean_method = value%tiles(1)%parameters%swkmean
    request%pressure_head_top_cm = value%tiles(1)%initial_state%pressure_head(1)
    request%water_content_top = value%tiles(1)%initial_state%water_content(1)
    request%candidate_ponding_depth_cm = 0.0_real64
    request%previous_ponding_depth_cm = 0.0_real64
    request%step_duration_day = T1-T0
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

  subroutine snapshot_ldwet_committed(committed, value)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), intent(out) :: value
    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    value = -huge(0.0_real64)
    call committed%snapshot(snapshot, available)
    call require(available, 'committed snapshot available')
    select type (state => snapshot)
    type is (fmr_b110_black_evaporation_state_t)
      value = state%black_evaporation%ldwet
    class default
      call require(.false., 'committed snapshot Black family')
    end select
  end subroutine snapshot_ldwet_committed

  subroutine snapshot_ldwet_candidate(candidate, value)
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64), intent(out) :: value
    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    value = -huge(0.0_real64)
    call candidate%snapshot(snapshot, available)
    call require(available, 'candidate snapshot available')
    select type (state => snapshot)
    type is (fmr_b110_black_evaporation_state_t)
      value = state%black_evaporation%ldwet
    class default
      call require(.false., 'candidate snapshot Black family')
    end select
  end subroutine snapshot_ldwet_candidate

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    equal = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU04A_RUNTIME_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu04a_black_runtime

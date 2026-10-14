module mod_fmr_production_application_bootstrap
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_micro_mvg_table_binding, only: fmr_micro_horizon_map_valid
  use mod_fmr_serialized_reference_backend, only: fmr_frost_response_drainage_configuration_valid, &
       fmr_frost_divdra_configuration_valid, fmr_frost_divdra_forcing_valid
  use mod_root_uptake_compensation, only: ROOT_COMP_OFF, ROOT_COMP_JARVIS, ROOT_COMP_WALSUM
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_executor_t, kernel_candidate_state_t, kernel_diagnostics_t, kernel_result_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, &
       export_kernel_committed_state, restore_kernel_committed_state, KERNEL_PERSISTENCE_OK
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_trial_contribution_t, fmr_wofost_accepted_interval_certificate_t, &
       open_wofost_accepted_window, begin_wofost_trial_contribution, &
       accumulate_wofost_trial_process_rate, prevalidate_wofost_trial_admission, &
       certify_fkt_accepted_interval, admit_wofost_accepted_trial, FMR_WOFOST_LINEAGE_OK
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t, &
       fmr_wofost_crop_transaction_parameters_t, fmr_wofost_crop_event_forcing_t, &
       initialize_fmr_wofost_crop_transaction_state, prepare_fmr_wofost_crop_event_forcing, FMR_WOF38_OK
  use mod_fmr_crop_weather_physical_event_composition, only: &
       propose_weather_crop_physical_event, CROP_EVENT_COMPOSE_OK
  use mod_fmr_wofost_crop_event_lifecycle, only: reconcile_committed_crop_event_receipt, FMR_WOF39_OK
  use mod_crop_lifecycle_continuation, only: crop_lifecycle_continuation_t, &
       initialize_b111_crop_lifecycle,CROP_PROFILE_BOUNDED,CROP_PROFILE_B111_TASK2,CROP_CONT_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_emergence_initialization, only: initialize_wofost_emergence_owner, WOFOST_EMERGENCE_INIT_OK
  use mod_wofost_rate_table, only: wofost_rate_table_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t,root_water_uptake_request_t,evaluate_macro_feddes_drought_uptake,ROOT_UPTAKE_OK
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_evaluate_shared_crop_root_uptake, &
       fmr_crop_root_uptake_adapter_diagnostics_t, FMR_CROP_ROOT_ADAPTER_OK
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_binding_diagnostics_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_crop_et_canopy_view_provider, only: crop_et_canopy_parameters_t, crop_et_canopy_state_view_t, &
       crop_et_canopy_forcing_t,crop_et_canopy_view_t,crop_et_canopy_diagnostics_t,evaluate_crop_et_canopy_view,CROP_ET_CANOPY_OK
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t
  use mod_crop_lifecycle_daily_composition, only: crop_daily_lifecycle_candidate_t, &
       compose_crop_lifecycle_daily_candidate, CROP_DAILY_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, fmr_serialized_execution_plan_t, fmr_build_serialized_execution_plan, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_EXECUTION_EASY, &
       FMR_SOLUTE_STATE_LAYOUT_NONE, FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE, &
       FMR_OPTIONAL_STATE_LAYOUT_RUTTER, &
       FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION, FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state, &
       fmr_new_b110_temporal_indicator_committed_state, fmr_new_b110_black_evaporation_committed_state, &
       fmr_new_b110_boesten_evaporation_committed_state, prepare_fmr_b110_default_mvg, &
       fmr_c_drain_salt_matches_trial, fmr_soil_salt_boundary_matches_trial, fmr_mobile_dispersion_matches_hydraulic_owner
  use mod_fmr_base_salt_temporal_policy, only: fmr_base_salt_temporal_policy_t
  use mod_restricted_surface_evaporation, only: black_evaporation_state_t, boesten_evaporation_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_direct_retention_core, only: begin_b110_direct_retention_application, end_b110_direct_retention_application, &
       freeze_b110_direct_retention_pool
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, &
       FMR_GW_REGISTRY_OK
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_temporal_budget_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, GW_MASS_LEDGER_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_groundwater_topology_composition, only: groundwater_topology_t, groundwater_topology_cell_t, &
       GW_TOPOLOGY_OK, GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_NONE
  use mod_groundwater_application_plan, only: groundwater_application_plan_t, groundwater_tile_predictor_input_t, &
       groundwater_cell_area_input_t, materialize_groundwater_application_plan, GW_APP_PLAN_OK
  use mod_swap_daily_weather_file_adapter, only: swap_daily_weather_record_t, swap_raintb_t, SWAP_WEATHER_FILE_OK
  use mod_crop_weather_day_owner, only: weather_day_owner_t, initialize_weather_day_owner, &
       ingest_weather_day, WEATHER_DAY_OK
  use mod_fmr_crop_weather_day_preflight, only: propose_weather_day_crop_preflight, CROP_WEATHER_PREFLIGHT_OK
  use mod_fmr_crop_certified_hydrothermal_forcing, only: &
       sample_certified_committed_crop_hydrothermal_forcing,CROP_CERT_FORCE_OK
  use mod_fmr_crop_certified_daily_preflight, only: crop_certified_daily_preflight_t
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_config_t, &
       ppa_wu03_common_forcing_input_t, ppa_wu03_common_forcing_result_t, &
       ppa_wu03_common_forcing_diagnostics_t, materialize_ppa_wu03_common_forcing, &
       bind_ppa_wu03_flux_result_to_effective_forcing, PPA_WU03_OK
  use mod_reference_et_demand_process, only: reference_et_demand_canopy_view_t, &
       daily_atmospheric_demand_parameters_t, traditional_pm_weather_t, evaluate_daily_atmospheric_demand, REF_ET_DEMAND_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_groundwater_application_context, only: fmr_groundwater_application_context_t, &
       FMR_GW_APP_CONTEXT_OK
  use mod_fmr_groundwater_application_c_api, only: register_fmr_groundwater_application_context, &
       release_fmr_groundwater_application_context, FMR_GW_APP_C_API_OK, FMR_GW_APP_C_API_INVALID_CONTEXT, &
       FMR_GW_APP_C_API_CONTEXT_BUSY
  implicit none
  private

  integer, parameter, public :: FMR_APP_BOOT_OK = 0
  integer, parameter, public :: FMR_APP_BOOT_INVALID_CONFIG = 1
  integer, parameter, public :: FMR_APP_BOOT_PROFILE_NOT_ADMITTED = 2
  integer, parameter, public :: FMR_APP_BOOT_STATE_INIT_FAILED = 3
  integer, parameter, public :: FMR_APP_BOOT_REGISTRY_FAILED = 4
  integer, parameter, public :: FMR_APP_BOOT_LEDGER_FAILED = 5
  integer, parameter, public :: FMR_APP_BOOT_NOT_READY = 6
  integer, parameter, public :: FMR_APP_BOOT_CONTEXT_BUSY = 7
  integer, parameter, public :: FMR_APP_BOOT_PLAN_FAILED = 8
  integer, parameter, public :: FMR_APP_BOOT_CONTEXT_FAILED = 9
  integer, parameter, public :: FMR_APP_BOOT_RUNTIME_FAILED = 10
  integer, parameter, public :: FMR_APP_BOOT_WEATHER_REJECTED = 11
  integer, parameter, public :: FMR_APP_BOOT_CROP_PREFLIGHT_FAILED = 12
  integer, parameter, public :: FMR_APP_BOOT_CROP_WINDOW_UNAVAILABLE = 13
  integer, parameter, public :: FMR_APP_BOOT_CROP_TRANSACTION_FAILED = 14
  integer, parameter, public :: FMR_APP_BOOT_CROP_EVENT_DELIVERED = 15

  ! Physical controls only. Live continuation is read exclusively from the
  ! existing committed crop owner; creation starts with zero continuation.
  type, public :: fmr_application_crop_daystart_controls_t
    integer :: initialization_profile=CROP_PROFILE_BOUNDED
    real(real64) :: zprep=-5.0_real64,zsow=-5.0_real64,ztempsow=-5.0_real64,zgerm=-5.0_real64
    integer :: swprep=0,swsow=0,germ_mode=1
    real(real64) :: hprep_threshold=-100.0_real64,hsow_threshold=-100.0_real64,sow_temperature=0.0_real64
    integer :: prep_delay=0,sow_delay=0,max_prep_delay=100,max_sow_delay=100
    real(real64) :: temperature_sum=0.0_real64,optimal_sum=100.0_real64,base_temperature=0.0_real64
    real(real64) :: max_effective_temperature=30.0_real64,dry_head=-1000.0_real64,wet_head=-10.0_real64
    real(real64) :: water_response_a=1.0_real64
  end type

  ! F-PE-TEMPORAL08 bounded fixed-interface groundwater temporal policy.
  ! This remains participant-local; generic canonical numerical configuration
  ! and non-groundwater application profiles retain their existing semantics.
  real(real64), parameter :: FMR_GW_HISTORY_TEMPORAL_COEFFICIENT = 0.65_real64
  real(real64), parameter :: FMR_GW_HISTORY_TEMPORAL_FLOOR_CM = 1.0e-5_real64

  ! WU01 established serialized Reference mode 7 standalone and mode 5 groundwater profiles.
  ! PPA-WU02-A additionally admits homogeneous typed bottom_mode=2 prescribed-qbot applications.
  ! WU03 may supply already-resolved effective forcing without changing lower-boundary ownership.
  type, public :: fmr_production_application_tile_config_t
    logical :: ordinary_prescribed_head = .false.
    logical :: ordinary_implicit_cauchy = .false.
    logical :: ordinary_explicit_cauchy = .false.
    logical :: ordinary_lysimeter_plate = .false.
    integer(int64) :: tile_id = 0_int64
    integer(int64) :: ledger_id = 0_int64
    integer :: execution_class = FMR_EXECUTION_EASY
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base_forcing
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: initial_black_ldwet = 0.0_real64
    real(real64) :: initial_boesten_spev = 0.0_real64
    real(real64) :: initial_boesten_saev = 0.0_real64
    real(real64) :: initial_rutter_canopy_storage_cm = 0.0_real64
    type(groundwater_head_datum_t) :: groundwater_datum
    real(real64), allocatable :: initial_right_derivative(:)
  end type fmr_production_application_tile_config_t

  type, public :: fmr_production_application_config_t
    logical :: file_weather_daily_demand=.false.
    type(daily_atmospheric_demand_parameters_t) :: file_weather_demand_parameters
    integer :: file_weather_swrain = 0
    type(swap_raintb_t) :: file_weather_raintb
    logical :: file_weather_daystart = .false.
    logical :: file_weather_rooted = .false.
    logical :: file_weather_dayend = .false.
    real(real64) :: file_weather_latitude = -999.0_real64
    real(real64) :: file_weather_emergence_dry_weight = -1.0_real64
    real(real64) :: file_weather_maximum_root_depth_cm = 0.0_real64
    real(real64) :: file_weather_stem_area_coefficient=0.0_real64,file_weather_storage_area_coefficient=0.0_real64
    type(wofost_rate_table_t) :: file_weather_root_depth, file_weather_root_density
    type(root_water_uptake_parameters_t) :: file_weather_root_parameters
    type(crop_et_canopy_parameters_t) :: file_weather_canopy_parameters
    ! Gregorian ordinal corresponding to model time zero; explicit, immutable.
    integer :: file_weather_epoch_day = 0
    real(real64) :: initial_time = 0.0_real64
    type(fmr_base_salt_temporal_policy_t) :: base_salt_temporal_policy
    type(canonical_numerical_config_t) :: numerical
    integer :: groundwater_parallel_workers = 1
    type(fmr_production_application_tile_config_t), allocatable :: tiles(:)
  end type fmr_production_application_config_t

  ! A serialization-neutral composition of existing owner snapshots and
  ! immutable input/configuration. It has no physical mutation authority,
  ! public setters or disk codec. F-KT provenance/certification stays opaque.
  type, public :: fmr_weather_crop_application_continuation_t
    private
    logical :: valid=.false., initial_crop_daystart_committed=.false.
    type(fmr_production_application_config_t) :: configuration
    type(kernel_persistence_snapshot_t) :: soil,crop
    type(weather_day_owner_t) :: weather
    type(swap_daily_weather_record_t) :: record,previous_record
    integer(int64) :: weather_revision=0_int64
    type(fmr_wofost_accepted_window_t) :: current_window,previous_window
    integer(int64) :: crop_lineage=0_int64,crop_revision=-1_int64
  end type

  type, public :: fmr_production_application_bootstrap_t
    private
    logical :: initialized = .false.
    logical :: ordinary_head_application = .false.
    logical :: ordinary_cauchy_application = .false.
    logical :: ordinary_lysimeter_application = .false.
    logical :: direct_retention_owner_active = .false.
    type(fmr_base_salt_temporal_policy_t) :: base_salt_temporal_policy
    type(canonical_numerical_config_t) :: numerical
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_serialized_execution_plan_t) :: execution_plan
    type(fmr_b110_physical_parameters_t), pointer :: parameters(:) => null()
    type(fmr_b110_physical_forcing_t), pointer :: base_forcing(:) => null()
    type(kernel_committed_state_t), pointer :: committed(:) => null()
    type(fmr_groundwater_head_forcing_materializer_t), pointer :: materializers(:) => null()
    type(groundwater_interface_mass_ledger_t), pointer :: ledgers(:) => null()
    type(fmr_groundwater_participant_registry_t), pointer :: registry => null()
    type(fmr_serialized_reference_backend_t), pointer :: backend => null()
    type(fmr_serialized_reference_backend_t), pointer :: groundwater_worker_backends(:) => null()
    type(fixed_flux_top_boundary_provider_t), pointer :: top_boundary => null()
    integer :: groundwater_parallel_workers = 1
    integer(int64), allocatable :: participant_handles(:)
    type(groundwater_application_plan_t), pointer :: active_plan => null()
    type(fmr_groundwater_application_context_t), pointer :: active_context => null()
    integer(int64) :: active_context_handle = 0_int64
    ! The existing weather owner is reused; the record is immutable forcing,
    ! not a second owner of meteorological state or of crop physical state.
    type(weather_day_o…27097 tokens truncated…acy_swbotb5_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb2_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb4_qgwl_control)) return
      if (tile%ledger_id /= 0_int64 .or. tile%groundwater_datum%available) return
      if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE) return
      if (tile%parameters%direct_retention_active .or. tile%parameters%ksatexm_extension_active .or. &
          tile%parameters%elasticity_active .or. tile%parameters%black_evaporation_active .or. &
          tile%parameters%boesten_evaporation_active) return
    else if (tile%ordinary_implicit_cauchy) then
      if (tile%parameters%bottom_mode /= 3 .or. tile%parameters%swkimpl /= 0 .or. tile%parameters%swsophy /= 0) return
      if (tile%parameters%swbotb3_explicit_active .or. tile%parameters%profile_groundwater_projection) return
      if (.not. allocated(tile%base_forcing%legacy_swbotb3_implicit_control)) return
      if (.not. tile%base_forcing%legacy_swbotb3_implicit_control%ready()) return
      if (allocated(tile%base_forcing%legacy_swbotb5_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb2_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb4_qgwl_control)) return
      if (tile%ledger_id /= 0_int64 .or. tile%groundwater_datum%available) return
      if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE) return
      if (tile%parameters%direct_retention_active .or. tile%parameters%ksatexm_extension_active .or. &
          tile%parameters%elasticity_active .or. tile%parameters%black_evaporation_active .or. &
          tile%parameters%boesten_evaporation_active) return
      if (tile%parameters%active_nodes > 1) then
        if (any(tile%parameters%cofgen(:,2:tile%parameters%active_nodes) /= &
             spread(tile%parameters%cofgen(:,1), 2, tile%parameters%active_nodes-1))) return
      end if
    else
      if (allocated(tile%base_forcing%legacy_swbotb5_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb3_implicit_control)) return
      if (tile%parameters%swbotb3_explicit_active .or. tile%parameters%profile_groundwater_projection) return
    end if
    if (tile%parameters%bottom_mode == 5 .and. .not. tile%ordinary_prescribed_head) then
      if (tile%ledger_id <= 0_int64 .or. .not. tile%groundwater_datum%valid()) return
    end if
    if (allocated(tile%initial_right_derivative)) then
      if (size(tile%initial_right_derivative) /= tile%parameters%active_nodes) return
    end if
    valid = .true.
  end function tile_config_valid

  subroutine discard_owner_storage(self)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self

    if (associated(self%active_context)) deallocate(self%active_context)
    if (associated(self%active_plan)) deallocate(self%active_plan)
    nullify(self%active_context)
    nullify(self%active_plan)
    self%active_context_handle = 0_int64

    if (associated(self%registry)) deallocate(self%registry)
    if (associated(self%ledgers)) deallocate(self%ledgers)
    if (associated(self%materializers)) deallocate(self%materializers)
    if (associated(self%committed)) deallocate(self%committed)
    if (associated(self%base_forcing)) deallocate(self%base_forcing)
    if (associated(self%parameters)) deallocate(self%parameters)
    if (associated(self%groundwater_worker_backends)) deallocate(self%groundwater_worker_backends)
    if (associated(self%backend)) deallocate(self%backend)
    if (associated(self%top_boundary)) deallocate(self%top_boundary)
    nullify(self%registry)
    nullify(self%ledgers)
    nullify(self%materializers)
    nullify(self%committed)
    nullify(self%base_forcing)
    nullify(self%parameters)
    nullify(self%groundwater_worker_backends)
    nullify(self%backend)
    nullify(self%top_boundary)
    self%groundwater_parallel_workers = 1

    call self%execution_plan%clear()
    if (allocated(self%participant_handles)) deallocate(self%participant_handles)
    if (allocated(self%columns)) deallocate(self%columns)
    if (allocated(self%templates)) deallocate(self%templates)
    if (self%direct_retention_owner_active) then
      call end_b110_direct_retention_application()
      self%direct_retention_owner_active = .false.
    end if
    self%initialized = .false.
    self%ordinary_head_application = .false.
    self%ordinary_cauchy_application = .false.
    self%ordinary_lysimeter_application = .false.
    self%weather=weather_day_owner_t()
    self%weather_record=swap_daily_weather_record_t()
    self%previous_weather_record=swap_daily_weather_record_t()
    self%initial_crop_daystart_committed=.false.
    self%weather_revision=0_int64;self%weather_epoch_day=0;self%weather_interval_active=.false.;self%crop_daystart_active=.false.
    self%accepted_crop_lineage=0_int64;self%accepted_crop_revision=-1_int64
    self%weather_configuration=fmr_production_application_config_t()
    self%weather_window=fmr_wofost_accepted_window_t()
    self%previous_weather_window=fmr_wofost_accepted_window_t()
  end subroutine discard_owner_storage

end module mod_fmr_production_application_bootstrap

module mod_fmr_production_application_bootstrap
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_micro_mvg_table_binding, only: fmr_micro_horizon_map_valid
  use mod_fmr_serialized_reference_backend, only: fmr_frost_response_drainage_configuration_valid, &
       fmr_frost_divdra_configuration_valid, fmr_frost_divdra_forcing_valid, fmr_frost_divdra_pair_valid
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
  use mod_crop_co2_response_resolver, only: crop_co2_response_parameters_t, crop_co2_response_t, &
       evaluate_crop_co2_response, CROP_CO2_RESPONSE_OK
  use mod_crop_atmospheric_co2_forcing, only: crop_atmospheric_co2_forcing_t, CROP_ATMOSPHERIC_CO2_OK
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
  use mod_fmr_biomass_root_uptake_input, only: bind_committed_biomass_root_uptake_input
  use mod_crop_root_depth_rate_owner, only: crop_root_depth_rate_parameters_t, crop_root_depth_rate_state_t, &
    CROP_ROOT_RATE_OK,CROP_ROOT_RATE_DROUGHT_SUPPLY
  use mod_crop_adaptive_root_profile_owner
  use mod_fmr_interception_source_window_binding, only: fmr_interception_source_window_t, &
       fmr_interception_source_window_restart_t, export_fmr_interception_source_window_restart, &
       prepare_fmr_interception_source_window_trial, accept_fmr_interception_source_window_result, FMR_INTWIN_OK
  ! INT12-C direct application imports.
  use mod_pmdirect_swetr0_process
  use mod_fmr_pmdirect_dynamic_top_boundary_binding
  use mod_fmr_pmdirect_ptra_root_input_binding
  use mod_fmr_pmdirect_surface_evaporation_binding
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t
  ! End INT12-C direct application imports.
  use mod_fmr_irrigation_allocation_binding, only: fmr_irrigation_allocation_t, &
       fmr_allocated_irrigation_state_t,fmr_allocated_irrigation_restart_t, &
       fmr_prepare_allocated_sensor_irrigation,fmr_prepare_allocated_root_irrigation,fmr_export_allocated_irrigation_restart, &
       fmr_restore_allocated_irrigation_restart,FMR_IRR_ALLOCATION_OK
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t,scheduled_irrigation_request_t
  use mod_fmr_irrigation_material_root_binding, only: fmr_build_irrigation_material_root_zone, &
       fmr_resolve_irrigation_management_activation
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_parameters_t
  use mod_crop_rotation_calendar, only: crop_calendar_t
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_parameters_t, &
       irrigation_management_policy_result_t
  use mod_fmr_scheduled_irrigation_forcing_binding, only: fmr_irrigation_forcing_binding_diagnostics_t
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_window_persistence_t, &
    export_wofost_window_persistence,reconstruct_wofost_window_persistence
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
  integer, parameter, public :: FMR_APP_BOOT_INTERCEPTION_REJECTED = 16
  integer, parameter, public :: FMR_APP_BOOT_IRRIGATION_REJECTED = 17
  integer, parameter :: FMR_APP_BOOT_IRRIGATION_SPLIT = 18

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

  ! INT12-C explicit immutable application inputs and accepted receipts.
  type, public :: fmr_pmdirect_interception_input_t
    type(pmdirect_swetr0_weather_t) :: weather
    type(pmdirect_swetr0_site_t) :: site
    type(pmdirect_swetr0_canopy_t) :: canopy
    type(crop_root_uptake_input_t) :: roots
    type(root_water_uptake_parameters_t) :: root_parameters
  end type
  type, public :: fmr_pmdirect_interception_receipt_t
    logical :: accepted=.false.
    type(pmdirect_swetr0_daily_result_t) :: daily
    type(pmdirect_swetr0_interval_result_t) :: interval
    type(b110_dynamic_top_boundary_result_t) :: top
    type(root_water_uptake_flux_result_t) :: roots
  end type
  ! End INT12-C explicit application types.

  type, public :: fmr_production_application_config_t
    logical :: explicit_pmdirect_interception=.false.
    ! One annual atmospheric forcing and one response for both assimilation
    ! and transpiration. No second canopy CO2 table is selected by this profile.
    logical :: file_weather_irrigation=.false.
    logical :: file_weather_irrigation_historical_activation=.false.
    logical :: file_weather_irrigation_schedule_enabled=.true.
    integer :: file_weather_irrigation_startirr(2)=[1,1],file_weather_irrigation_endirr(2)=[31,12]
    type(crop_calendar_t) :: file_weather_irrigation_crop_calendar
    type(scheduled_irrigation_parameters_t) :: file_weather_irrigation_sensor
    type(irrigation_management_policy_parameters_t) :: file_weather_irrigation_depth
    real(real64) :: file_weather_irrigation_field_capacity_head_cm=-100._real64
    logical :: file_weather_co2_response=.false.
    type(crop_atmospheric_co2_forcing_t) :: file_weather_atmospheric_co2
    type(crop_co2_response_parameters_t) :: file_weather_co2_parameters
    logical :: file_weather_daily_demand=.false.
    type(daily_atmospheric_demand_parameters_t) :: file_weather_demand_parameters
    integer :: file_weather_swrain = 0
    type(swap_raintb_t) :: file_weather_raintb
    logical :: file_weather_daystart = .false.
    logical :: file_weather_rooted = .false.
    integer :: file_weather_root_depth_mode = 1
    type(crop_root_depth_rate_parameters_t) :: file_weather_swrd2_parameters
    logical :: file_weather_adaptive_root_profile=.false.
    type(adaptive_root_profile_configuration_t)::file_weather_root_profile
    real(real64) :: file_weather_maximum_root_biomass = 0.0_real64
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
    integer :: irrigation_schema=0,irrigation_selection_day=-1
    real(real64) :: irrigation_time=0.0_real64,irrigation_delivered_cm=0.0_real64
    type(fmr_allocated_irrigation_restart_t) :: irrigation
    type(fmr_production_application_config_t) :: configuration
    type(kernel_persistence_snapshot_t) :: soil,crop
    type(weather_day_owner_t) :: weather
    type(swap_daily_weather_record_t) :: record,previous_record
    integer(int64) :: weather_revision=0_int64
    type(fmr_wofost_accepted_window_t) :: current_window,previous_window
    integer(int64) :: crop_lineage=0_int64,crop_revision=-1_int64
  end type

  ! Serialization-neutral view for the existing joint native adapter. This
  ! carrier grants no setter or commit authority to a live application.
  type, public :: fmr_weather_crop_native_view_t
    logical :: valid=.false., initial_crop_daystart_committed=.false.
    integer :: irrigation_schema=0,irrigation_selection_day=-1
    real(real64) :: irrigation_time=0.0_real64,irrigation_delivered_cm=0.0_real64
    type(fmr_allocated_irrigation_restart_t) :: irrigation
    type(fmr_production_application_config_t) :: configuration
    type(kernel_persistence_snapshot_t) :: soil,crop
    type(weather_day_owner_t) :: weather
    type(swap_daily_weather_record_t) :: record,previous_record
    integer(int64) :: weather_revision=0_int64
    type(fmr_wofost_accepted_window_t) :: current_window,previous_window
    integer(int64) :: crop_lineage=0_int64,crop_revision=-1_int64
  end type
  public :: export_weather_crop_native_view,reconstruct_weather_crop_native_view

  type, public :: fmr_production_application_bootstrap_t
    private
    logical :: initialized = .false.
    logical :: explicit_pmdirect_interception=.false.
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
    type(weather_day_owner_t) :: weather
    type(swap_daily_weather_record_t) :: weather_record,previous_weather_record
    integer(int64) :: weather_revision=0_int64
    integer :: weather_epoch_day=0
    logical :: weather_interval_active=.false.,crop_daystart_active=.false.
    logical :: initial_crop_daystart_committed=.false.
    type(fmr_production_application_config_t) :: weather_configuration
    type(fmr_wofost_accepted_window_t) :: weather_window, previous_weather_window
    integer(int64) :: accepted_crop_lineage=0_int64,accepted_crop_revision=-1_int64
    type(fmr_allocated_irrigation_state_t) :: irrigation
    integer :: irrigation_selection_day=-1
    real(real64) :: irrigation_time=0.0_real64,irrigation_delivered_cm=0.0_real64
  contains
    procedure, public :: initialize => production_application_initialize
    procedure, public :: ready => production_application_ready
    procedure, public :: tile_count => production_application_tile_count
    procedure, public :: groundwater_worker_count => production_application_groundwater_worker_count
    procedure, public :: run_pmdirect_interception_interval => production_application_run_pmdirect_interception_interval
    procedure, public :: run_interception_window_interval => production_application_run_interception_window_interval
    procedure, public :: run_standalone => production_application_run_standalone
    procedure, public :: run_standalone_with_forcing => production_application_run_standalone_with_forcing
    procedure, public :: snapshot_weather_irrigation => production_application_snapshot_weather_irrigation
    procedure, public :: begin_weather_day => production_application_begin_weather_day
    procedure, public :: run_weather_interval => production_application_run_weather_interval
    procedure, public :: initialize_weather_crop_daystart => production_application_initialize_weather_crop_daystart
    procedure, public :: run_weather_crop_daystart => production_application_run_weather_crop_daystart
    procedure, public :: run_weather_crop_dayend => production_application_run_weather_crop_dayend
    procedure, public :: capture_weather_crop_continuation => production_application_capture_weather_crop_continuation
    procedure, public :: restore_weather_crop_continuation => production_application_restore_weather_crop_continuation
    procedure, public :: copy_committed_for_crop => production_application_copy_committed_for_crop
    procedure, public :: materialize_groundwater_context => production_application_materialize_groundwater_context
    procedure, public :: release_groundwater_context => production_application_release_groundwater_context
    procedure, public :: copy_committed_revisions => production_application_copy_committed_revisions
    procedure, public :: groundwater_parallel_schedule_diagnostics => production_application_parallel_schedule_diagnostics
    procedure, public :: close => production_application_close
  end type fmr_production_application_bootstrap_t

contains
  subroutine export_weather_crop_native_view(bundle,view,status)
    type(fmr_weather_crop_application_continuation_t),intent(in)::bundle
    type(fmr_weather_crop_native_view_t),intent(out)::view
    integer,intent(out)::status
    view=fmr_weather_crop_native_view_t();status=FMR_APP_BOOT_INVALID_CONFIG
    if(.not.bundle%valid)return
    view%valid=bundle%valid
    view%initial_crop_daystart_committed=bundle%initial_crop_daystart_committed
    view%irrigation_schema=bundle%irrigation_schema
    view%irrigation_selection_day=bundle%irrigation_selection_day
    view%irrigation_time=bundle%irrigation_time
    view%irrigation_delivered_cm=bundle%irrigation_delivered_cm
    view%irrigation=bundle%irrigation
    view%configuration=bundle%configuration
    view%soil=bundle%soil
    view%crop=bundle%crop
    view%weather=bundle%weather
    view%record=bundle%record
    view%previous_record=bundle%previous_record
    view%weather_revision=bundle%weather_revision
    view%current_window=bundle%current_window
    view%previous_window=bundle%previous_window
    view%crop_lineage=bundle%crop_lineage
    view%crop_revision=bundle%crop_revision
    status=FMR_APP_BOOT_OK
  end subroutine
  subroutine reconstruct_weather_crop_native_view(view,bundle,status)
    type(fmr_weather_crop_native_view_t),intent(in)::view
    type(fmr_weather_crop_application_continuation_t),intent(out)::bundle
    integer,intent(out)::status
    type(fmr_wofost_window_persistence_t)::current,previous
    type(fmr_allocated_irrigation_state_t)::irrigation
    integer(int64)::source,epoch,revision
    real(real64)::day,tmin,tmax,rain,et,weather_day,soil_time,crop_time
    logical::ok
    integer::st
    bundle=fmr_weather_crop_application_continuation_t();status=FMR_APP_BOOT_INVALID_CONFIG
    if(.not.view%valid.or..not.view%record%ready().or..not.view%soil%ready().or..not.view%crop%ready())return
    if(.not.view%configuration%file_weather_irrigation)return
    select case(view%configuration%file_weather_irrigation_sensor%timing_criterion)
    case(2:4,6:8)
    case default
      return
    end select
    if(view%configuration%file_weather_irrigation_sensor%timing_criterion<7.or. &
       view%configuration%file_weather_irrigation_depth%depth_criterion==1)then
      if(.not.view%configuration%file_weather_rooted)return
    end if
    if(.not.allocated(view%configuration%tiles))return
    if(size(view%configuration%tiles)/=1)return
    if(view%soil%layout_id()/=view%configuration%tiles(1)%template%template_id.or.view%crop%layout_id()/=904001_int64)return
    if(view%crop%current_lineage_id()/=view%crop_lineage.or.view%crop%current_revision()/=view%crop_revision)return
    call view%record%values(day,tmin,tmax,rain,et,ok);if(.not.ok)return
    day=day-real(view%configuration%file_weather_epoch_day,real64)
    call view%weather%snapshot(source,epoch,revision,weather_day,tmin,tmax,ok)
    if(.not.ok.or.source/=1_int64.or.epoch/=1_int64.or.revision/=view%weather_revision.or.weather_day/=day)return
    call view%soil%current_time(soil_time,ok);if(.not.ok)return
    call view%crop%current_time(crop_time,ok);if(.not.ok)return
    call export_wofost_window_persistence(view%current_window,current,st);if(st/=0)return
    call export_wofost_window_persistence(view%previous_window,previous,st);if(st/=0)return
    if(.not.current%initialized.or.current%lineage_id/=view%soil%current_lineage_id())return
    if(current%t0/=day.or.current%t1/=day+1._real64.or.current%covered_t/=soil_time)return
    if(current%next_revision/=view%soil%current_revision())return
    if(current%event_delivered)then
      if(.not.view%configuration%file_weather_dayend.or.crop_time/=day+1._real64)return
    else if(previous%initialized.and..not.previous%event_delivered)then
      if(previous%t0/=day-1._real64.or.previous%t1/=day.or.crop_time/=day-1._real64)return
    else
      if(crop_time/=day)return
    end if
    if(previous%initialized)then
      if(.not.view%previous_record%ready().or..not.view%previous_record%same_source(view%record))return
      call view%previous_record%values(weather_day,tmin,tmax,rain,et,ok);if(.not.ok)return
      if(weather_day/=day-1._real64+real(view%configuration%file_weather_epoch_day,real64))return
    else
      if(view%previous_record%ready())return
    end if
    if(.not.ieee_is_finite(view%irrigation_time))return
    if(view%irrigation_schema/=1.or.view%irrigation_time/=soil_time)return
    if(.not.ieee_is_finite(view%irrigation_delivered_cm))return
    if(view%irrigation_delivered_cm<0._real64)return
    if(view%irrigation_selection_day< -1.or.view%irrigation_selection_day>int(day)+view%configuration%file_weather_epoch_day)return
    if(soil_time>day.and.view%irrigation_selection_day/=int(day)+view%configuration%file_weather_epoch_day)return
    call fmr_restore_allocated_irrigation_restart(view%irrigation,irrigation,st);if(st/=0)return
    if(.not.view%configuration%file_weather_irrigation_depth%fixed_interval_enabled)then
      if(irrigation%management%policy%weekly_day_counter>6.and. &
         irrigation%management%policy%weekly_day_counter/=366)return
    else
      if(irrigation%management%policy%weekly_day_counter> &
         view%configuration%file_weather_irrigation_depth%fixed_interval_days.and. &
         irrigation%management%policy%weekly_day_counter/=366)return
    end if
    bundle%valid=view%valid
    bundle%initial_crop_daystart_committed=view%initial_crop_daystart_committed
    bundle%irrigation_schema=view%irrigation_schema
    bundle%irrigation_selection_day=view%irrigation_selection_day
    bundle%irrigation_time=view%irrigation_time
    bundle%irrigation_delivered_cm=view%irrigation_delivered_cm
    bundle%irrigation=view%irrigation
    bundle%configuration=view%configuration
    bundle%soil=view%soil
    bundle%crop=view%crop
    bundle%weather=view%weather
    bundle%record=view%record
    bundle%previous_record=view%previous_record
    bundle%weather_revision=view%weather_revision
    bundle%current_window=view%current_window
    bundle%previous_window=view%previous_window
    bundle%crop_lineage=view%crop_lineage
    bundle%crop_revision=view%crop_revision
    status=FMR_APP_BOOT_OK
  end subroutine

  subroutine production_application_initialize(self, config, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(fmr_production_application_config_t), intent(in) :: config
    integer, intent(out) :: status

    integer :: i, local_status, n
    class(transaction_state_t), allocatable :: initial_physical
    logical :: ok, hydraulic_prepared, groundwater_profile, standalone_profile, prescribed_qbot_profile, ordinary_head_profile
    logical :: irrigation_window
    logical :: ordinary_cauchy_profile, ordinary_explicit_cauchy_profile, ordinary_lysimeter_profile, direct_retention_requested
    type(root_water_uptake_request_t) :: zero_root_request
    type(root_water_uptake_flux_result_t) :: zero_root_fluxes
    type(root_water_uptake_diagnostics_t) :: root_parameter_diagnostics
    type(process_hydraulic_view_t) :: unused_hydraulic_view
    type(black_evaporation_state_t) :: initial_black_state
    type(boesten_evaporation_state_t) :: initial_boesten_state
    type(fmr_groundwater_temporal_budget_policy_t) :: temporal_budget_policy

    status = FMR_APP_BOOT_INVALID_CONFIG
    if (self%initialized) return
    if (.not. allocated(config%tiles)) return
    n = size(config%tiles)
    if (n <= 0) return
    if (.not. ieee_is_finite(config%initial_time)) return
    if (config%groundwater_parallel_workers /= 1 .and. config%groundwater_parallel_workers /= 2 .and. &
        config%groundwater_parallel_workers /= 4) return

    ! INT12-C explicit initialization gate; false preserves incumbent routing.
    if (config%explicit_pmdirect_interception) then
      status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      if (config%file_weather_daystart.or.config%file_weather_rooted.or.config%file_weather_epoch_day/=0.or. &
          config%groundwater_parallel_workers/=1) return
      if (config%numerical%transaction%temporal_mode/=TX_TEMPORAL_MODEL_CERTIFICATE) return
      do i=1,n
        if (.not.explicit_pmdirect_tile_valid(config%tiles(i))) return
      end do
    end if
    ! End INT12-C explicit initialization gate.
    ordinary_head_profile = .true.
    ordinary_cauchy_profile = .true.
    ordinary_explicit_cauchy_profile = .true.
    ordinary_lysimeter_profile = .true.
    groundwater_profile = .true.
    standalone_profile = .true.
    prescribed_qbot_profile = .true.
    direct_retention_requested = .false.
    do i = 1, n
      if (.not. tile_config_valid(config%tiles(i), n, i, config%file_weather_daystart,config%file_weather_rooted,config%explicit_pmdirect_interception)) then
        status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
        return
      end if
      if (allocated(config%tiles(i)%parameters%micro_de_willigen)) then
        if (config%numerical%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE .or. &
            config%tiles(i)%template%numerical_continuation_layout_id /= &
            FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
      end if
      if(allocated(config%tiles(i)%parameters%mobile_dispersion))then
        if(.not.config%base_salt_temporal_policy%transport%valid())then
          status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
      end if
      if (config%tiles(i)%template%solute_state_layout_id /= FMR_SOLUTE_STATE_LAYOUT_NONE) then
        if (.not. config%base_salt_temporal_policy%valid() .or. &
            config%numerical%transaction%temporal_mode /= TX_TEMPORAL_EXTERNAL_FULL_HALF .or. &
            .not. ieee_is_finite(config%numerical%transaction%temporal_tolerance)) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
        if (config%numerical%transaction%temporal_tolerance /= 1.0_real64) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
        if (.not. fmr_c_drain_salt_matches_trial(config%tiles(i)%base_forcing%c_drain_salt, &
            int(i,int64),config%initial_time,config%tiles(i)%base_forcing%c_drain_salt%valid_t1) .or. &
            .not. fmr_soil_salt_boundary_matches_trial(config%tiles(i)%base_forcing%soil_salt_boundary, &
            int(i,int64),config%initial_time,config%tiles(i)%base_forcing%soil_salt_boundary%valid_t1)) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
      end if
      groundwater_profile = groundwater_profile .and. config%tiles(i)%parameters%bottom_mode == 5 .and. &
           .not. config%tiles(i)%ordinary_prescribed_head .and. .not. config%tiles(i)%ordinary_implicit_cauchy .and. &
           .not. config%tiles(i)%ordinary_explicit_cauchy .and. .not. config%tiles(i)%ordinary_lysimeter_plate
      ordinary_head_profile = ordinary_head_profile .and. config%tiles(i)%ordinary_prescribed_head
      ordinary_cauchy_profile = ordinary_cauchy_profile .and. config%tiles(i)%ordinary_implicit_cauchy
      ordinary_explicit_cauchy_profile = ordinary_explicit_cauchy_profile .and. config%tiles(i)%ordinary_explicit_cauchy
      ordinary_lysimeter_profile = ordinary_lysimeter_profile .and. config%tiles(i)%ordinary_lysimeter_plate
      standalone_profile = standalone_profile .and. (config%tiles(i)%parameters%bottom_mode == 7.or. &
         (config%tiles(i)%parameters%bottom_mode==1.and.config%tiles(i)%parameters%prescribed_groundwater_active))
      prescribed_qbot_profile = prescribed_qbot_profile .and. config%tiles(i)%parameters%bottom_mode == 2
      direct_retention_requested = direct_retention_requested .or. config%tiles(i)%parameters%direct_retention_active
    end do
    if (.not. int64_values_unique(config%tiles%tile_id)) return
    if (.not. groundwater_profile .and. .not. standalone_profile .and. .not. prescribed_qbot_profile .and. &
         .not. ordinary_head_profile .and. .not. ordinary_cauchy_profile .and. .not. ordinary_explicit_cauchy_profile .and. &
         .not. ordinary_lysimeter_profile) then
      status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      return
    end if
    if (.not. groundwater_profile .and. config%groundwater_parallel_workers /= 1) then
      status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      return
    end if
    if(config%file_weather_irrigation)then
      if(.not.config%file_weather_daystart.or.n/=1) return
      if(config%file_weather_irrigation_historical_activation)then
        call fmr_resolve_irrigation_management_activation(config%file_weather_irrigation_crop_calendar, &
          config%initial_time+real(config%file_weather_epoch_day,real64),config%file_weather_irrigation_startirr, &
          config%file_weather_irrigation_endirr,config%file_weather_irrigation_schedule_enabled,irrigation_window,ok)
        if(.not.ok)return
      end if
      ! New hydraulic selectors are independently admitted, not implicitly
      ! composed with this default-MvG managed weather profile.
      if(allocated(config%tiles(1)%parameters%hydraulic_model_kind).or. &
         config%tiles(1)%parameters%conductivity_power_tail_active)return
      if(config%explicit_pmdirect_interception.or.config%base_salt_temporal_policy%enabled) return
      if(config%tiles(1)%template%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_NONE)return
      if(config%file_weather_irrigation_sensor%salinity_excess_enabled)return
      if(.not.config%file_weather_irrigation_sensor%scheduled_irrigation_enabled)return
      if(config%file_weather_irrigation_sensor%active_nodes/=config%tiles(1)%parameters%active_nodes)return
      if(config%file_weather_irrigation_depth%fixed_interval_enabled)then
        ! All scheduled selectors share the existing accepted DAYFIX owner.
        if(config%file_weather_irrigation_sensor%timing_criterion==6)return
        if(config%file_weather_irrigation_depth%fixed_interval_days<1.or. &
           config%file_weather_irrigation_depth%fixed_interval_days>366)return
      end if
      select case(config%file_weather_irrigation_sensor%timing_criterion)
      case(2:4,6:8)
      case default
        return
      end select
      if(config%file_weather_irrigation_depth%depth_criterion/=1.and. &
         config%file_weather_irrigation_depth%depth_criterion/=2)return
      if(config%file_weather_irrigation_depth%depth_criterion==1.or. &
         config%file_weather_irrigation_sensor%timing_criterion<7)then
        if(.not.config%file_weather_rooted.or.config%file_weather_root_depth_mode/=2)return
        if(.not.ieee_is_finite(config%file_weather_irrigation_field_capacity_head_cm))return
        if(config%file_weather_irrigation_field_capacity_head_cm< -500._real64.or. &
           config%file_weather_irrigation_field_capacity_head_cm>0._real64)return
      end if
    end if
    if(config%file_weather_co2_response) then
      if(.not.config%file_weather_rooted) return
      if(.not.config%file_weather_atmospheric_co2%ready().or..not.config%file_weather_co2_parameters%ready()) return
    end if
    if(config%file_weather_dayend.and..not.config%file_weather_rooted) return
    if(config%file_weather_root_depth_mode<1.or.config%file_weather_root_depth_mode>3) return
    if(config%file_weather_root_depth_mode==2)then
      if(.not.config%file_weather_rooted.or..not.config%file_weather_swrd2_parameters%ready()) return
      if(config%file_weather_swrd2_parameters%negligible_transpiration<=0.0_real64) return
      if(config%file_weather_swrd2_parameters%maximum_root_depth_cm/=config%file_weather_maximum_root_depth_cm) return
    end if
    if(config%file_weather_adaptive_root_profile)then
      if(config%file_weather_root_depth_mode/=2)return
      if(.not.config%file_weather_root_profile%ready())return
      if(config%file_weather_swrd2_parameters%initial_root_depth_cm<=0.0_real64)return
      if(config%file_weather_root_profile%maximum_root_depth_cm/=config%file_weather_maximum_root_depth_cm)return
      if(size(config%file_weather_root_profile%dz_cm)/=config%tiles(1)%parameters%active_nodes)return
      if(any(config%file_weather_root_profile%dz_cm/=config%tiles(1)%parameters%dz))return
      if(any(config%file_weather_root_profile%ztop_cm/=config%tiles(1)%parameters%z+0.5_real64*config%tiles(1)%parameters%dz))return
      if(any(config%file_weather_root_profile%zbot_cm/=config%tiles(1)%parameters%z-0.5_real64*config%tiles(1)%parameters%dz))return
    else if(config%file_weather_root_depth_mode==2)then
      if(config%file_weather_swrd2_parameters%actual_extension_mode==CROP_ROOT_RATE_DROUGHT_SUPPLY)return
    end if
    if(config%file_weather_root_depth_mode==3)then
      if(.not.config%file_weather_rooted) return
      if(.not.ieee_is_finite(config%file_weather_maximum_root_biomass)) return
      if(config%file_weather_maximum_root_biomass<=0.0_real64) return
    end if
    if(config%file_weather_rooted) then
      if(.not.config%file_weather_daystart.or.n/=1) return
      if(.not.ieee_is_finite(config%file_weather_latitude).or. &
           .not.ieee_is_finite(config%file_weather_emergence_dry_weight).or. &
           .not.ieee_is_finite(config%file_weather_maximum_root_depth_cm)) return
      if(abs(config%file_weather_latitude)>66.5_real64.or.config%file_weather_emergence_dry_weight<=0.0_real64.or. &
           config%file_weather_emergence_dry_weight>10000.0_real64.or.config%file_weather_maximum_root_depth_cm<=0.0_real64) return
      if(.not.config%file_weather_root_depth%ready().or..not.config%file_weather_root_density%ready().or. &
           .not.config%file_weather_canopy_parameters%ready()) return
      if(config%file_weather_canopy_parameters%co2_enabled()) return
      if(config%file_weather_root_parameters%active_nodes/=config%tiles(1)%parameters%active_nodes) return
      if(.not.file_weather_rooted_tile_valid(config%tiles(1))) return
      call evaluate_macro_feddes_drought_uptake(config%file_weather_root_parameters,unused_hydraulic_view, &
           zero_root_request,zero_root_fluxes,root_parameter_diagnostics)
      if(root_parameter_diagnostics%status/=ROOT_UPTAKE_OK) return
      ! Empirical wet stress uses the existing committed-head Feddes binding.
      ! ROOT_COMP_OFF retains one prescribed sink and accepted uptake receipt.
      ! Parameter validation above also covers the wet thresholds/layer split.
      if(.not.all(ieee_is_finite([config%file_weather_stem_area_coefficient, &
           config%file_weather_storage_area_coefficient]))) return
      if(min(config%file_weather_stem_area_coefficient,config%file_weather_storage_area_coefficient)<0.0_real64) return
    end if
    if(config%file_weather_daily_demand) then
      if(.not.config%file_weather_daystart.or.config%file_weather_rooted.or.config%file_weather_swrain/=0) return
      if(.not.config%file_weather_demand_parameters%ready()) return
      if(config%file_weather_demand_parameters%mode==0) then
        if(config%file_weather_demand_parameters%canopy%crop_emerged.or. &
           config%file_weather_demand_parameters%canopy%vegetation_cover_fraction/=0.0_real64) return
      end if
    end if
    if(config%file_weather_swrain/=0.and.config%file_weather_swrain/=1) return
    if(config%file_weather_swrain==1) then
      if(.not.config%file_weather_daystart.or.config%file_weather_rooted) return
      if(.not.config%file_weather_raintb%ready()) return
    end if
    if(config%file_weather_daystart) then
      if(config%file_weather_epoch_day<1.or.config%file_weather_epoch_day>3652059) then
        status=FMR_APP_BOOT_INVALID_CONFIG
        return
      end if
      self%weather_epoch_day=config%file_weather_epoch_day
      if(n/=1.or..not.standalone_profile.or. &
           (config%tiles(1)%template%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BASE.and. &
            .not.file_weather_thermal_tile_valid(config%tiles(1),config%file_weather_rooted)).or. &
           (config%tiles(1)%template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_NONE.and. &
            config%tiles(1)%template%numerical_continuation_layout_id/= &
            FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)) then
        status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
        return
      end if
    end if
    if (groundwater_profile) then
      do i = 1, n
        if (config%tiles(i)%ledger_id <= 0_int64) then
          status = FMR_APP_BOOT_INVALID_CONFIG
          return
        end if
        if (.not. config%tiles(i)%groundwater_datum%valid()) then
          status = FMR_APP_BOOT_INVALID_CONFIG
          return
        end if
        if (config%tiles(i)%template%numerical_continuation_layout_id == &
            FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY .and. &
            config%numerical%transaction%temporal_mode == TX_TEMPORAL_MODEL_CERTIFICATE) then
          if (.not. allocated(config%tiles(i)%initial_right_derivative)) then
            status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
            return
          end if
          if (any(.not. ieee_is_finite(config%tiles(i)%initial_right_derivative))) then
            status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
            return
          end if
        end if
      end do
      if (.not. int64_values_unique(config%tiles%ledger_id)) return
    end if

    if (direct_retention_requested .and. .not. groundwater_profile) then
      status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      return
    end if
    if (direct_retention_requested) then
      call begin_b110_direct_retention_application(ok)
      if (.not. ok) then
        status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
        return
      end if

      self%direct_retention_owner_active = .true.
    end if

    allocate(self%columns(n), self%templates(n))
    allocate(self%parameters(n), self%base_forcing(n), self%committed(n))
    allocate(self%backend, self%top_boundary)
    self%ordinary_head_application = ordinary_head_profile
    self%ordinary_cauchy_application = ordinary_cauchy_profile .or. ordinary_explicit_cauchy_profile
    self%ordinary_lysimeter_application = ordinary_lysimeter_profile
    self%numerical = config%numerical
    self%base_salt_temporal_policy = config%base_salt_temporal_policy

    call self%backend%initialize(self%top_boundary)
    if (config%base_salt_temporal_policy%enabled) then
      call self%backend%configure_base_salt_temporal_policy(config%base_salt_temporal_policy,ok)
      if (.not. ok) then
        status = FMR_APP_BOOT_INVALID_CONFIG
        call discard_owner_storage(self)
        return
      end if
    end if
    self%groundwater_parallel_workers = config%groundwater_parallel_workers

    if (groundwater_profile .and. self%groundwater_parallel_workers > 1) then
      allocate(self%groundwater_worker_backends(self%groundwater_parallel_workers))
      do i = 1, self%groundwater_parallel_workers
        call self%groundwater_worker_backends(i)%initialize(self%top_boundary)
      end do
    end if

    if (groundwater_profile) then
      allocate(self%participant_handles(n), self%materializers(n), self%ledgers(n), self%registry)
      self%participant_handles = 0_int64
      call self%registry%initialize(n, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK) then
        status = FMR_APP_BOOT_REGISTRY_FAILED
        call discard_owner_storage(self)
        return
      end if
    end if

    do i = 1, n
      self%templates(i) = config%tiles(i)%template
      self%columns(i)%column_id = config%tiles(i)%tile_id
      self%columns(i)%template_id = self%templates(i)%template_id
      self%columns(i)%parameter_ref = int(i, int64)
      self%columns(i)%state_handle = int(i, int64)
      self%columns(i)%forcing_handle = int(i, int64)
      self%columns(i)%execution_class = config%tiles(i)%execution_class
      self%columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      self%parameters(i) = config%tiles(i)%parameters
      call prepare_fmr_b110_default_mvg(self%parameters(i), hydraulic_prepared)
      if (self%parameters(i)%direct_retention_active .and. .not. hydraulic_prepared) then
        status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
        call discard_owner_storage(self)
        return
      end if
      self%base_forcing(i) = config%tiles(i)%base_forcing
      if (groundwater_profile) call self%materializers(i)%initialize(self%base_forcing(i))

      select case (self%templates(i)%numerical_continuation_layout_id)
      case (FMR_NUMERICAL_CONTINUATION_NONE)
        if (self%templates(i)%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION) then
          initial_black_state%ldwet = config%tiles(i)%initial_black_ldwet
          call fmr_new_b110_black_evaporation_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, initial_black_state, config%initial_time, ok)
        else if (self%templates(i)%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION) then
          initial_boesten_state%spev = config%tiles(i)%initial_boesten_spev
          initial_boesten_state%saev = config%tiles(i)%initial_boesten_saev
          call fmr_new_b110_boesten_evaporation_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, initial_boesten_state, config%initial_time, ok)
        else if (self%templates(i)%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RUTTER) then
          call fmr_new_b110_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, config%initial_time, ok, &
               initial_rutter_storage_cm=config%tiles(i)%initial_rutter_canopy_storage_cm)
        else
          if(config%file_weather_daystart) then
            call fmr_new_b110_committed_state(self%committed(i), config%tiles(i)%tile_id, &
                 config%tiles(i)%initial_state, config%initial_time, ok,parameters=self%parameters(i))
          else
            call fmr_new_b110_committed_state(self%committed(i), config%tiles(i)%tile_id, &
                 config%tiles(i)%initial_state, config%initial_time, ok)
          end if
        end if
      case (FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
        if (allocated(config%tiles(i)%initial_right_derivative)) then
          call fmr_new_b110_temporal_indicator_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, config%initial_time, ok, config%tiles(i)%initial_right_derivative)
        else
          call fmr_new_b110_temporal_indicator_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, config%initial_time, ok)
        end if
      case default
        ok = .false.
      end select
      if (.not. ok) then
        status = FMR_APP_BOOT_STATE_INIT_FAILED
        call discard_owner_storage(self)
        return
      end if

      if(config%file_weather_daystart.and. &
           self%templates(i)%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY) then
        ! Initialization only: preserve the existing backend-created temporal
        ! carrier and certify its parameters through the existing F-KT entry.
        ! No accepted revision is ever rewrapped or reset during execution.
        call self%committed(i)%snapshot(initial_physical,ok)
        if(ok) then
          self%committed(i)=kernel_committed_state_t()
          call self%committed(i)%initialize(config%tiles(i)%tile_id,initial_physical,ok, &
               config%initial_time,self%parameters(i))
        end if
        if(.not.ok) then
          status=FMR_APP_BOOT_STATE_INIT_FAILED
          call discard_owner_storage(self)
          return
        end if
      end if

      if (groundwater_profile) then
        temporal_budget_policy = fmr_groundwater_temporal_budget_policy_t()
        if (self%templates(i)%numerical_continuation_layout_id == FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY .and. &
            self%numerical%transaction%temporal_mode == TX_TEMPORAL_MODEL_CERTIFICATE) then
          temporal_budget_policy%enabled = .true.
          temporal_budget_policy%coefficient = FMR_GW_HISTORY_TEMPORAL_COEFFICIENT
          temporal_budget_policy%floor_cm = FMR_GW_HISTORY_TEMPORAL_FLOOR_CM
        end if
        call self%registry%bind_prevalidated_fresh(config%tiles(i)%tile_id, self%backend, self%columns(i), &
             self%templates(i), self%parameters(i), self%committed(i), self%materializers(i), self%numerical, &
             config%tiles(i)%groundwater_datum, self%participant_handles(i), local_status, immutable_parameters=.true., &
             temporal_budget_policy=temporal_budget_policy)
        if (local_status /= FMR_GW_REGISTRY_OK .or. self%participant_handles(i) <= 0_int64) then
          status = FMR_APP_BOOT_REGISTRY_FAILED
          call discard_owner_storage(self)
          return
        end if

        call self%ledgers(i)%bind_identity(config%tiles(i)%ledger_id, local_status)
        if (local_status /= GW_MASS_LEDGER_OK) then
          status = FMR_APP_BOOT_LEDGER_FAILED
          call discard_owner_storage(self)
          return
        end if
      end if
    end do

    if (direct_retention_requested) call freeze_b110_direct_retention_pool()

    call fmr_build_serialized_execution_plan(self%columns, self%templates, size(self%committed), &
         self%execution_plan, ok)

    if(config%file_weather_daystart) self%weather_configuration=config
    if(config%file_weather_irrigation)self%irrigation_time=config%initial_time
    self%explicit_pmdirect_interception=config%explicit_pmdirect_interception
    self%initialized = .true.
    status = FMR_APP_BOOT_OK
  end subroutine production_application_initialize

  logical function production_application_ready(self) result(ready)
    class(fmr_production_application_bootstrap_t), intent(in) :: self

    ready = self%initialized
    if (.not. ready) return
    ready = allocated(self%columns) .and. allocated(self%templates)
    if (.not. ready) return
    ready = associated(self%parameters) .and. associated(self%base_forcing) .and. associated(self%committed) .and. &
         associated(self%backend) .and. associated(self%top_boundary)
    if (.not. ready) return
    ready = size(self%columns) > 0 .and. size(self%templates) == size(self%columns) .and. &
         size(self%parameters) == size(self%columns) .and. size(self%base_forcing) == size(self%columns) .and. &
         size(self%committed) == size(self%columns)
  end function production_application_ready

  logical function production_application_groundwater_ready(self) result(ready)
    class(fmr_production_application_bootstrap_t), intent(in) :: self

    ready = self%ready()
    if (.not. ready) return
    ready = associated(self%materializers) .and. associated(self%ledgers) .and. associated(self%registry) .and. &
         allocated(self%participant_handles)
    if (.not. ready) return
    ready = size(self%materializers) == size(self%columns) .and. size(self%ledgers) == size(self%columns) .and. &
         size(self%participant_handles) == size(self%columns)
    if (.not. ready) return
    ready = self%registry%active_count() == size(self%columns) .and. all(self%participant_handles > 0_int64) .and. &
         all(self%parameters%bottom_mode == 5)
    if (.not. ready) return
    if (self%groundwater_parallel_workers > 1) then
      ready = associated(self%groundwater_worker_backends)
      if (.not. ready) return
      ready = size(self%groundwater_worker_backends) == self%groundwater_parallel_workers
    else
      ready = .not. associated(self%groundwater_worker_backends)
    end if
  end function production_application_groundwater_ready

  integer function production_application_tile_count(self) result(count)
    class(fmr_production_application_bootstrap_t), intent(in) :: self
    count = 0
    if (self%ready()) count = size(self%columns)
  end function production_application_tile_count

  integer function production_application_groundwater_worker_count(self) result(count)
    class(fmr_production_application_bootstrap_t), intent(in) :: self
    count = 0
    if (.not. self%ready()) return
    count = self%groundwater_parallel_workers
  end function production_application_groundwater_worker_count

  subroutine production_application_copy_committed_for_crop(self, tile, snapshot, status)
    class(fmr_production_application_bootstrap_t), intent(in) :: self
    integer, intent(in) :: tile
    type(kernel_committed_state_t), intent(out) :: snapshot
    integer, intent(out) :: status
    snapshot=kernel_committed_state_t();status=FMR_APP_BOOT_NOT_READY
    if(.not.self%ready()) return
    status=FMR_APP_BOOT_INVALID_CONFIG
    if(tile<1.or.tile>size(self%committed)) return
    ! Intrinsic derived-type assignment deep-copies the private allocatable
    ! physical carrier. It cannot write back into the application authority.
    snapshot=self%committed(tile)
    status=FMR_APP_BOOT_OK
  end subroutine

  subroutine production_application_begin_weather_day(self,record,controls,candidate,status,task2_only)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(swap_daily_weather_record_t), intent(in) :: record
    type(fmr_application_crop_daystart_controls_t), intent(in) :: controls
    type(crop_certified_daily_preflight_t), intent(out) :: candidate
    integer, intent(out) :: status
    logical, intent(in), optional :: task2_only
    type(weather_day_owner_t) :: pending_weather
    type(fmr_wofost_accepted_window_t) :: pending_window
    type(kernel_checkpoint_t) :: day_checkpoint
    logical :: new_day,initialize_only
    real(real64) :: day,tmin,tmax,rain,etref,time
    logical :: available
    integer :: s
    integer(int64) :: pending_revision
    candidate=crop_certified_daily_preflight_t();status=FMR_APP_BOOT_NOT_READY
    if(.not.self%ready()) return
    initialize_only=.false.
    if(present(task2_only)) initialize_only=task2_only
    if(initialize_only) then
      if(self%crop_daystart_active.or.self%previous_weather_window%ready()) return
      if(self%committed(1)%current_revision()/=0_int64) return
    end if
    status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if(size(self%committed)/=1.or.associated(self%active_context)) return
    if(self%parameters(1)%bottom_mode/=7.or.self%weather_epoch_day==0) return
    status=FMR_APP_BOOT_WEATHER_REJECTED
    call record%values(day,tmin,tmax,rain,etref,available)
    if(.not.available) return
    day=day-real(self%weather_epoch_day,real64)
    call self%committed(1)%current_time(time,available)
    if(.not.available) return
    if(time/=day) return
    pending_weather=self%weather;pending_revision=self%weather_revision
    new_day=.not.self%weather_record%same_input(record)
    if(pending_revision==0_int64) then
      ! Private local namespace only. Authentication is the opaque file
      ! record, never these compatibility source/epoch numbers.
      call initialize_weather_day_owner(pending_weather,1_int64,1_int64,s)
      if(s/=WEATHER_DAY_OK) return
    end if
    if(self%weather_record%ready()) then
      if(.not.self%weather_record%same_source(record)) return
      if(self%weather_record%same_input(record)) then
        ! Exact repeated daystart reuses the same weather revision.
      else
        call ingest_weather_day(pending_weather,1_int64,1_int64,day,tmin,tmax,s)
        if(s/=WEATHER_DAY_OK) return
        pending_revision=pending_revision+1_int64
      end if
    else
      call ingest_weather_day(pending_weather,1_int64,1_int64,day,tmin,tmax,s)
      if(s/=WEATHER_DAY_OK) return
      pending_revision=1_int64
    end if
    status=FMR_APP_BOOT_CROP_PREFLIGHT_FAILED
    if(.not.initialize_only) then
    call propose_weather_day_crop_preflight(self%committed(1), &
         self%committed(1)%current_lineage_id(),self%committed(1)%current_revision(),time, &
         pending_weather,1_int64,1_int64,pending_revision,day, &
         controls%zprep,controls%zsow,controls%ztempsow,controls%zgerm,controls%swprep,controls%swsow, &
         controls%hprep_threshold,controls%hsow_threshold,controls%sow_temperature, &
         controls%prep_delay,controls%sow_delay,controls%max_prep_delay,controls%max_sow_delay, &
         controls%germ_mode,controls%temperature_sum,controls%optimal_sum,controls%base_temperature, &
         controls%max_effective_temperature,controls%dry_head,controls%wet_head,controls%water_response_a,candidate,s)
    if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.candidate%valid) return
    end if
    ! Weather acquisition is independent of acceptance of today's future
    ! trajectory. This publishes no crop event or lifecycle transition.
    if(new_day) then
      if(self%crop_daystart_active.and.self%previous_weather_window%ready()) then
        if(.not.self%previous_weather_window%delivery_committed()) then
          status=FMR_APP_BOOT_CROP_WINDOW_UNAVAILABLE
          return
        end if
      end if
      ! An opaque F-KT checkpoint at the real accepted daystart opens the
      ! existing window owner. No receipt is invented for the initial day.
      if(self%weather_window%ready().and..not.self%weather_window%complete()) return
      call self%committed(1)%capture_checkpoint(day_checkpoint,available)
      if(.not.available) return
      call open_wofost_accepted_window(day_checkpoint,day+1.0_real64,pending_window,s)
      if(s/=FMR_WOFOST_LINEAGE_OK) return
      self%previous_weather_record=self%weather_record
      self%previous_weather_window=self%weather_window
      self%weather_window=pending_window
    end if
    self%weather=pending_weather;self%weather_record=record;self%weather_revision=pending_revision
    status=FMR_APP_BOOT_OK
  end subroutine

  subroutine production_application_run_managed_weather(self,record,t0,t1,forcing_config,canopy,results,status, &
       crop_committed,irrigation_allocation)
    class(fmr_production_application_bootstrap_t),intent(inout)::self
    type(swap_daily_weather_record_t),intent(in)::record
    real(real64),intent(in)::t0,t1
    type(ppa_wu03_common_forcing_config_t),intent(in)::forcing_config
    type(reference_et_demand_canopy_view_t),intent(in)::canopy
    type(fmr_serialized_column_result_t),allocatable,intent(out)::results(:)
    integer,intent(out)::status
    type(kernel_committed_state_t),intent(in),optional::crop_committed
    type(fmr_irrigation_allocation_t),intent(in),optional::irrigation_allocation
    type(fmr_serialized_column_result_t),allocatable::segment(:)
    real(real64)::cursor,endpoint,rate,split,day,tmin,tmax,rain,etref
    logical::ok
    integer::st
    status=FMR_APP_BOOT_WEATHER_REJECTED
    if(.not.self%ready())return
    if(.not.all(ieee_is_finite([t0,t1])))return
    if(t1<=t0)return
    if(.not.record%same_input(self%weather_record))return
    call record%values(day,tmin,tmax,rain,etref,ok)
    if(.not.ok)return
    day=day-real(self%weather_epoch_day,real64)
    if(t0<day.or.t1>day+1.0_real64)return
    cursor=t0
    do while(cursor<t1)
      endpoint=t1;rate=rain*0.1_real64
      if(self%weather_configuration%file_weather_swrain==1)then
        call record%rain_segment(self%weather_configuration%file_weather_raintb,self%weather_epoch_day, &
          cursor,t1,rate,endpoint,st)
        if(st/=SWAP_WEATHER_FILE_OK)return
      end if
      call production_application_run_weather_segment(self,record,cursor,endpoint,forcing_config,canopy,segment,status, &
        crop_committed,rate,irrigation_allocation,split)
      if(status==FMR_APP_BOOT_IRRIGATION_SPLIT)then
        status=FMR_APP_BOOT_IRRIGATION_REJECTED
        if(.not.ieee_is_finite(split))return
        if(split<=cursor.or.split>=endpoint)return
        endpoint=split
        call production_application_run_weather_segment(self,record,cursor,endpoint,forcing_config,canopy,segment,status, &
          crop_committed,rate,irrigation_allocation,split)
      end if
      if(allocated(segment))then
        if(allocated(results))then
          results=[results,segment]
        else
          results=segment
        end if
      end if
      if(status/=FMR_APP_BOOT_OK)return
      cursor=endpoint
    end do
  end subroutine

  subroutine production_application_snapshot_weather_irrigation(self,state,selection_day,delivered_cm,status)
    class(fmr_production_application_bootstrap_t),intent(in)::self
    type(fmr_allocated_irrigation_state_t),intent(out)::state
    integer,intent(out)::selection_day,status
    real(real64),intent(out)::delivered_cm
    state=fmr_allocated_irrigation_state_t();selection_day=-1;delivered_cm=0.0_real64
    status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if(.not.self%ready())return
    if(.not.self%weather_configuration%file_weather_irrigation)return
    state=self%irrigation;selection_day=self%irrigation_selection_day;delivered_cm=self%irrigation_delivered_cm
    status=FMR_APP_BOOT_OK
  end subroutine

  subroutine production_application_run_weather_interval(self,record,t0,t1,forcing_config,canopy,results,status,crop_committed, &
       irrigation_allocation)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(swap_daily_weather_record_t), intent(in) :: record
    real(real64), intent(in) :: t0,t1
    type(ppa_wu03_common_forcing_config_t), intent(in) :: forcing_config
    type(reference_et_demand_canopy_view_t), intent(in) :: canopy
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    integer, intent(out) :: status
    type(kernel_committed_state_t),intent(in),optional :: crop_committed
    type(fmr_irrigation_allocation_t),intent(in),optional :: irrigation_allocation
    type(fmr_serialized_column_result_t),allocatable :: segment_results(:)
    real(real64)::cursor,endpoint,rate
    integer::s,attempt
    if(self%weather_configuration%file_weather_irrigation)then
      call production_application_run_managed_weather(self,record,t0,t1,forcing_config,canopy,results,status, &
        crop_committed,irrigation_allocation)
      return
    end if
    if(self%weather_configuration%file_weather_swrain==0) then
      call production_application_run_weather_segment(self,record,t0,t1,forcing_config,canopy,results,status,crop_committed)
      return
    end if
    status=FMR_APP_BOOT_WEATHER_REJECTED
    if(.not.self%weather_record%same_input(record)) return
    cursor=t0
    ! Within one authentic day there is at most one rain on/off boundary.
    do attempt=1,2
      call record%rain_segment(self%weather_configuration%file_weather_raintb,self%weather_epoch_day, &
           cursor,t1,rate,endpoint,s)
      if(s/=SWAP_WEATHER_FILE_OK) return
      call production_application_run_weather_segment(self,record,cursor,endpoint,forcing_config,canopy, &
           segment_results,status,crop_committed,rate)
      if(allocated(segment_results)) then
        if(allocated(results)) then
          results=[results,segment_results]
        else
          results=segment_results
        end if
      end if
      if(status/=FMR_APP_BOOT_OK) return
      if(endpoint==t1) return
      cursor=endpoint
    end do
    error stop 'MC-MET01 one-day rainfall segmentation exceeded one boundary'
  end subroutine

  subroutine production_application_run_weather_segment(self,record,t0,t1,forcing_config,canopy,results,status,crop_committed,rain_rate, &
       irrigation_allocation,irrigation_split)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(swap_daily_weather_record_t), intent(in) :: record
    real(real64), intent(in) :: t0,t1
    type(ppa_wu03_common_forcing_config_t), intent(in) :: forcing_config
    type(reference_et_demand_canopy_view_t), intent(in) :: canopy
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    integer, intent(out) :: status
    type(kernel_committed_state_t),intent(in),optional :: crop_committed
    real(real64),intent(in),optional :: rain_rate
    type(fmr_irrigation_allocation_t),intent(in),optional :: irrigation_allocation
    real(real64),intent(out),optional :: irrigation_split
    type(fmr_allocated_irrigation_state_t) :: irrigation_candidate
    type(fmr_irrigation_forcing_binding_diagnostics_t) :: irrigation_binding
    type(irrigation_management_policy_result_t) :: irrigation_depth
    type(irrigation_root_zone_parameters_t) :: unused_root
    type(crop_root_depth_rate_state_t) :: irrigation_root_depth
    type(scheduled_irrigation_request_t) :: irrigation_request
    type(fmr_b110_physical_forcing_t) :: irrigation_forcing
    type(fmr_irrigation_allocation_t) :: allocation
    type(wofost_crop_owner_state_t) :: crop_owner
    type(crop_lifecycle_continuation_t) :: crop_lifecycle
    type(crop_root_uptake_input_t) :: root_input
    type(root_water_uptake_flux_result_t) :: root_fluxes
    type(root_water_uptake_diagnostics_t) :: root_diagnostics
    type(fmr_root_uptake_binding_diagnostics_t) :: root_binding
    type(fmr_crop_root_uptake_adapter_diagnostics_t) :: root_adapter
    type(crop_et_canopy_state_view_t) :: canopy_state
    type(crop_et_canopy_forcing_t) :: canopy_forcing
    type(crop_et_canopy_view_t) :: crop_canopy
    type(crop_et_canopy_diagnostics_t) :: canopy_diagnostics
    type(ppa_wu03_common_forcing_input_t) :: input
    type(ppa_wu03_common_forcing_result_t) :: common
    type(ppa_wu03_common_forcing_diagnostics_t) :: diagnostics
    type(b110_dynamic_top_boundary_request_t) :: request
    type(kernel_checkpoint_t) :: interval_checkpoint
    type(fmr_wofost_trial_contribution_t) :: trial
    type(fmr_wofost_accepted_interval_certificate_t) :: certificate
    type(b110_dynamic_top_boundary_result_t) :: top
    type(soil_water_parameter_set_t) :: geometry
    type(b110_default_mvg_parameters_t) :: hydraulics
    type(fmr_b110_physical_forcing_t) :: effective(1)
    class(transaction_state_t), allocatable :: physical
    type(traditional_pm_weather_t) :: pm_weather
    type(crop_co2_response_t) :: co2_response
    real(real64) :: day,tmin,tmax,rain,etref,time,crop_time,qrot,ptra,deepest_oxygen
    logical :: available,rooted
    integer :: s
    status=FMR_APP_BOOT_NOT_READY
    if(.not.self%ready()) return
    status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if(size(self%committed)/=1.or.associated(self%active_context)) return
    if(self%parameters(1)%bottom_mode/=7.or.self%weather_epoch_day==0) return
    rooted=self%weather_configuration%file_weather_rooted
    ! This first application profile is the existing base, root-free,
    ! snow-free default-MVG pure-flux WU03 profile. Do not accidentally enable
    ! a stateful evaporation or root-uptake route through an outer adapter.
    if((self%templates(1)%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BASE.and. &
        .not.file_weather_thermal_tile_valid(self%weather_configuration%tiles(1),rooted)).or. &
         (self%parameters(1)%root_extraction_active.and..not.rooted).or.self%parameters(1)%snow_active.or. &
         self%parameters(1)%tabulated_hydraulics_active.or.self%parameters(1)%direct_retention_active.or. &
         self%parameters(1)%frost_active.or.self%parameters(1)%hysteresis_active.or. &
         self%parameters(1)%macropore_active) return
    status=FMR_APP_BOOT_WEATHER_REJECTED
    if(.not.self%weather_record%same_input(record)) return
    call record%values(day,tmin,tmax,rain,etref,available)
    if(.not.available) return
    day=day-real(self%weather_epoch_day,real64)
    if(.not.ieee_is_finite(t0).or..not.ieee_is_finite(t1)) return
    call self%committed(1)%current_time(time,available)
    if(.not.available) return
    if(t0/=time) return
    if(self%crop_daystart_active.and.self%previous_weather_window%ready()) then
      if(.not.self%previous_weather_window%delivery_committed()) then
        status=FMR_APP_BOOT_CROP_TRANSACTION_FAILED
        return
      end if
    end if
    input%interval%t0=t0;input%interval%t1=t1
    input%forcing_t0=day;input%forcing_t1=day+1.0_real64
    input%precipitation_rate_cm_per_day=rain*0.1_real64
    if(present(rain_rate)) input%precipitation_rate_cm_per_day=rain_rate
    input%reference_et%t0=day;input%reference_et%t1=day+1.0_real64
    input%reference_et%reference_et_mm_per_day=etref;input%canopy=canopy
    if(rooted) then
      if(.not.present(crop_committed)) return
      if(crop_committed%current_lineage_id()/=self%accepted_crop_lineage.or. &
           crop_committed%current_revision()/=self%accepted_crop_revision) return
      call crop_committed%current_time(crop_time,available)
      if(.not.available.or.crop_time/=day) return
      call crop_committed%snapshot(physical,available)
      if(.not.available) return
      select type(physical)
      type is(fmr_wofost_crop_transaction_state_t)
        call physical%snapshot_owner(crop_owner,available)
        if(.not.available) return
        call physical%snapshot_lifecycle(crop_lifecycle,available)
        if(.not.available.or..not.crop_lifecycle%ready()) return
        if(crop_lifecycle%harvested.or.crop_lifecycle%initialization_profile/=CROP_PROFILE_B111_TASK2) return
        if(crop_lifecycle%emerged.neqv.crop_owner%crop_emerged) return
      class default
        return
      end select
      canopy_state%crop_emerged=crop_owner%crop_emerged
      canopy_state%development_stage=crop_owner%development_stage
      call crop_owner%derive_actual_leaf_area_index(self%weather_configuration%file_weather_stem_area_coefficient, &
           self%weather_configuration%file_weather_storage_area_coefficient,canopy_state%leaf_area_index,s)
      if(s/=WOFOST_CROP_OWNER_OK) return
      if(self%weather_configuration%file_weather_co2_response.and.crop_owner%crop_emerged) then
        call resolve_weather_crop_co2(self,record,co2_response,s)
        if(s/=CROP_CO2_RESPONSE_OK) return
        call evaluate_crop_et_canopy_view(self%weather_configuration%file_weather_canopy_parameters, &
             canopy_state,canopy_forcing,crop_canopy,canopy_diagnostics,co2_response%transpiration_factor)
      else
        call evaluate_crop_et_canopy_view(self%weather_configuration%file_weather_canopy_parameters, &
             canopy_state,canopy_forcing,crop_canopy,canopy_diagnostics)
      end if
      if(canopy_diagnostics%status/=CROP_ET_CANOPY_OK.or..not.canopy_diagnostics%result_produced) return
      input%canopy%crop_emerged=crop_canopy%crop_emerged
      input%canopy%vegetation_cover_fraction=crop_canopy%vegetation_cover_fraction
      input%canopy%crop_factor=crop_canopy%crop_factor
      input%canopy%co2_transpiration_factor=crop_canopy%co2_transpiration_factor
    end if
    call self%committed(1)%snapshot(physical,available)
    if(.not.available) return
    select type(physical)
    class is(fmr_b110_physical_state_t)
      if(.not.allocated(physical%pressure_head).or..not.allocated(physical%water_content)) return
      if(physical%active_nodes<1) return
      request%pressure_head_top_cm=physical%pressure_head(1)
      request%water_content_top=physical%water_content(1)
      request%previous_ponding_depth_cm=physical%ponding_depth
      request%candidate_ponding_depth_cm=physical%ponding_depth
    class default
      return
    end select
    request%conductivity_mean_method=self%parameters(1)%swkmean
    request%ponding_max_cm=0.0_real64
    request%runoff_resistance_day=1.0_real64;request%runoff_exponent=1.0_real64
    call materialize_ppa_wu03_common_forcing(forcing_config,input,request,common,diagnostics, &
         self%weather,1_int64,1_int64,self%weather_revision,day)
    if(diagnostics%status/=PPA_WU03_OK.or..not.common%valid) return
    if(self%weather_configuration%file_weather_daily_demand) then
      if(rooted.or.canopy%crop_emerged.or.canopy%vegetation_cover_fraction/=0.0_real64) return
      if(forcing_config%reference_et_parameters%pond_evaporation_factor/= &
         self%weather_configuration%file_weather_demand_parameters%pond_factor) return
      call record%pm_values(pm_weather%day_of_year,pm_weather%radiation_j_m2_d, &
           pm_weather%vapour_pressure_kpa,pm_weather%wind_speed_m_s,available)
      if(.not.available) return
      pm_weather%minimum_air_temperature_c=tmin;pm_weather%maximum_air_temperature_c=tmax
      pm_weather%gross_rain_cm_d=rain*0.1_real64
      call evaluate_daily_atmospheric_demand(self%weather_configuration%file_weather_demand_parameters, &
           pm_weather,etref,input%canopy,common%reference_et_demand,s)
      if(s/=REF_ET_DEMAND_OK) return
      common%top_request%potential_bare_soil_evaporation_cm_per_day= &
           common%reference_et_demand%potential_soil_evaporation_cm_per_day
      common%top_request%potential_pond_evaporation_cm_per_day= &
           common%reference_et_demand%potential_pond_evaporation_cm_per_day
    end if
    ! This profile has no roots or transpiration. Do not manufacture a zero
    ! root integral if the common forcing carries a positive crop demand.
    if(.not.rooted.and.common%reference_et_demand%potential_transpiration_cm_per_day/=0.0_real64) return
    geometry%parameter_set_id=self%parameters(1)%parameter_set_id
    geometry%active_nodes=self%parameters(1)%active_nodes
    geometry%z=self%parameters(1)%z;geometry%dz=self%parameters(1)%dz
    geometry%node_distance=self%parameters(1)%node_distance
    call initialize_b110_default_mvg_parameters(hydraulics,self%parameters(1)%cofgen)
    call evaluate_b110_dynamic_top_boundary(geometry,hydraulics,common%top_request,top)
    if (.not.self%weather_configuration%file_weather_irrigation) then
      ! Keep gross atmospheric rates until the solver resolves its actual
      ! trial surface. A start-of-window flux must not suppress later ponding.
      effective(1)=self%base_forcing(1)
      if(allocated(effective(1)%pond_input).or.allocated(effective(1)%weather_surface))return
      allocate(effective(1)%weather_surface)
      effective(1)%top_flux=0.0_real64
      effective(1)%weather_surface%rain_rate_cm_day=common%top_request%precipitation_rate_cm_per_day
      effective(1)%weather_surface%potential_bare_soil_evaporation_cm_day= &
        common%top_request%potential_bare_soil_evaporation_cm_per_day
      effective(1)%weather_surface%potential_pond_evaporation_cm_day= &
        common%top_request%potential_pond_evaporation_cm_per_day
      effective(1)%weather_surface%ponding_max_cm=request%ponding_max_cm
      effective(1)%weather_surface%runoff_resistance_day=request%runoff_resistance_day
    else
      call bind_ppa_wu03_flux_result_to_effective_forcing(self%base_forcing(1),top,effective(1),s)
      if(s/=PPA_WU03_OK) return
    end if
    qrot=0.0_real64;ptra=0.0_real64
    if(rooted) then
      if(self%weather_configuration%file_weather_root_depth_mode==2)then
        call crop_committed%snapshot(physical,available)
        if(.not.available) return
        select type(physical)
        type is(fmr_wofost_crop_transaction_state_t)
          block
            type(crop_root_depth_rate_state_t)::depth
            call physical%snapshot_root_depth(depth,available)
            if(.not.available) return
            if(self%weather_configuration%file_weather_adaptive_root_profile.and.crop_owner%crop_emerged)then
              block
                type(adaptive_root_profile_state_t)::profile
                integer::rooted_nodes,i
                call physical%snapshot_root_profile(profile,available)
                if(.not.available)return
                rooted_nodes=0
                do i=1,self%parameters(1)%active_nodes
                  if(self%weather_configuration%file_weather_root_profile%zbot_cm(i)+ &
                    depth%actual_root_depth_cm<1e-8_real64)then
                    rooted_nodes=i;exit
                  end if
                end do
                call profile%derive_root_uptake_input(rooted_nodes,self%parameters(1)%active_nodes,root_input,s)
                if(s/=ADAPTIVE_ROOT_PROFILE_OK)return
              end block
            else
            call depth%derive_root_uptake_input(self%weather_configuration%file_weather_root_density, &
              self%weather_configuration%file_weather_maximum_root_depth_cm, &
              self%parameters(1)%z-self%parameters(1)%dz*0.5_real64,root_input,available,s)
            if(s/=CROP_ROOT_RATE_OK.or..not.available) return
            end if
            root_input%crop_emerged=crop_owner%crop_emerged
          end block
        class default
          return
        end select
      else if(self%weather_configuration%file_weather_root_depth_mode==3)then
        call crop_committed%snapshot(physical,available)
        if(.not.available) return
        select type(physical)
        type is(fmr_wofost_crop_transaction_state_t)
          call bind_committed_biomass_root_uptake_input(physical,self%weather_configuration%file_weather_root_depth, &
               self%weather_configuration%file_weather_root_density,self%weather_configuration%file_weather_maximum_root_depth_cm, &
               self%weather_configuration%file_weather_maximum_root_biomass, &
               self%parameters(1)%z-self%parameters(1)%dz*0.5_real64,root_input,s)
          if(s/=0) return
        class default
          return
        end select
      else
      call crop_owner%derive_dvs_root_uptake_input(self%weather_configuration%file_weather_root_depth, &
           self%weather_configuration%file_weather_root_density,self%weather_configuration%file_weather_maximum_root_depth_cm, &
           self%parameters(1)%z-self%parameters(1)%dz*0.5_real64,root_input,available,s)
      if(s/=WOFOST_CROP_OWNER_OK) return
      if(crop_owner%crop_emerged.and..not.available) return
      end if
      root_input%potential_transpiration=common%reference_et_demand%potential_transpiration_cm_per_day
      call fmr_evaluate_shared_crop_root_uptake(self%committed(1),self%weather_configuration%file_weather_root_parameters, &
           root_input,root_fluxes,root_diagnostics,root_binding,root_adapter)
      if(root_adapter%status/=FMR_CROP_ROOT_ADAPTER_OK) return
      effective(1)%root_extraction_sink=root_fluxes%root_extraction_sink
      qrot=sum(effective(1)%root_extraction_sink);ptra=root_input%potential_transpiration
    end if
    if(self%parameters(1)%soil_temperature_active) then
      ! Same immutable source record as rain/ET and crop TAV. The admitted
      ! numerical AIR/no-snow owner implements historical TeTop=tav.
      if(.not.file_weather_thermal_tile_valid(self%weather_configuration%tiles(1),rooted)) return
      effective(1)%soil_temperature%air_temperature_c=(tmax+tmin)*0.5_real64
    end if
    if(self%weather_configuration%file_weather_irrigation)then
      status=FMR_APP_BOOT_IRRIGATION_REJECTED
      if(.not.present(crop_committed))return
      if(crop_committed%current_lineage_id()/=self%accepted_crop_lineage.or. &
         crop_committed%current_revision()/=self%accepted_crop_revision)return
      call crop_committed%current_time(crop_time,available)
      if(.not.available)return
      if(crop_time/=day.or.self%irrigation_time/=t0)return
      call crop_committed%snapshot(physical,available)
      if(.not.available)return
      select type(physical)
      type is(fmr_wofost_crop_transaction_state_t)
        call physical%snapshot_owner(crop_owner,available)
        if(.not.available)return
      class default
        return
      end select
      irrigation_request%t0=t0;irrigation_request%t1=t1
      irrigation_request%dvs=crop_owner%development_stage
      irrigation_request%crop_emerged=crop_owner%crop_emerged
      irrigation_request%selection_opportunity=self%irrigation_selection_day/=int(day)+self%weather_epoch_day
      irrigation_request%irrigation_enabled=.true.;irrigation_request%schedule_enabled=.true.
      irrigation_request%irrigation_window_open=.true.
      if(self%weather_configuration%file_weather_irrigation_historical_activation)then
        irrigation_request%schedule_enabled=self%weather_configuration%file_weather_irrigation_schedule_enabled
        call fmr_resolve_irrigation_management_activation( &
          self%weather_configuration%file_weather_irrigation_crop_calendar,t0+real(self%weather_epoch_day,real64), &
          self%weather_configuration%file_weather_irrigation_startirr,self%weather_configuration%file_weather_irrigation_endirr, &
          irrigation_request%schedule_enabled,irrigation_request%irrigation_window_open,available)
        if(.not.available)return
      end if
      allocation=fmr_irrigation_allocation_t()
      if(present(irrigation_allocation))allocation=irrigation_allocation
      unused_root%active_nodes=self%parameters(1)%active_nodes
      if((self%weather_configuration%file_weather_irrigation_depth%depth_criterion==1.or. &
          self%weather_configuration%file_weather_irrigation_sensor%timing_criterion<7).and. &
          crop_owner%crop_emerged.and.irrigation_request%selection_opportunity.and. &
          irrigation_request%schedule_enabled.and.irrigation_request%irrigation_window_open.and. &
          .not.self%irrigation%management%event%active_event)then
        select type(physical)
        type is(fmr_wofost_crop_transaction_state_t)
          call physical%snapshot_root_depth(irrigation_root_depth,available)
          if(.not.available)return
        class default
          return
        end select
        call fmr_build_irrigation_material_root_zone(hydraulics,self%parameters(1)%dz, &
          irrigation_root_depth%actual_root_depth_cm,self%weather_configuration%file_weather_irrigation_field_capacity_head_cm, &
          self%weather_configuration%file_weather_root_parameters%hlim3l, &
          self%weather_configuration%file_weather_root_parameters%hlim3h, &
          self%weather_configuration%file_weather_root_parameters%hlim4,unused_root,available)
        if(.not.available)return
      end if
      if(self%weather_configuration%file_weather_irrigation_sensor%timing_criterion<7)then
        call fmr_prepare_allocated_root_irrigation(self%weather_configuration%file_weather_irrigation_sensor, &
          unused_root,self%weather_configuration%file_weather_irrigation_depth,rain*0.1_real64, &
          self%committed(1),effective(1),self%irrigation,irrigation_request,allocation,irrigation_candidate, &
          irrigation_forcing,irrigation_binding)
      else
      call fmr_prepare_allocated_sensor_irrigation(self%weather_configuration%file_weather_irrigation_sensor, &
        unused_root,self%weather_configuration%file_weather_irrigation_depth,rain*0.1_real64, &
        self%committed(1),effective(1),self%irrigation,irrigation_request,allocation,irrigation_candidate, &
        irrigation_forcing,irrigation_binding,irrigation_depth)
      end if
      if(irrigation_binding%split_required)then
        if(.not.present(irrigation_split))return
        irrigation_split=irrigation_binding%split_time;status=FMR_APP_BOOT_IRRIGATION_SPLIT
        return
      end if
      if(irrigation_binding%status/=0)return
      if(.not.ieee_is_finite(irrigation_binding%external_inflow_amount_cm))return
      if(irrigation_binding%external_inflow_amount_cm>huge(0.0_real64)-self%irrigation_delivered_cm)return
      effective(1)=irrigation_forcing
    end if
    call self%committed(1)%capture_checkpoint(interval_checkpoint,available)
    if(.not.available) return
    call begin_wofost_trial_contribution(interval_checkpoint,t1,trial,s)
    if(s/=FMR_WOFOST_LINEAGE_OK) return
    if(rooted.and.self%weather_configuration%file_weather_root_depth_mode/=1)then
      deepest_oxygen=1.0_real64
      if(root_input%rooted_nodes>0)then
        if(.not.allocated(root_diagnostics%oxygen_reduction_factor)) return
        if(size(root_diagnostics%oxygen_reduction_factor)<root_input%rooted_nodes) return
        deepest_oxygen=root_diagnostics%oxygen_reduction_factor(root_input%rooted_nodes)
      end if
      if(self%weather_configuration%file_weather_adaptive_root_profile)then
        block
          real(real64)::drought
          drought=0.0_real64
          if(ptra>1e-12_real64)drought=1.0_real64-root_diagnostics%drought_reduction_total/ptra
          call accumulate_wofost_trial_process_rate(trial,t0,t1,qrot,ptra,s,deepest_root_oxygen_factor=deepest_oxygen, &
            rootzone_drought_uptake_factor=drought,potential_root_sink=root_diagnostics%potential_root_sink, &
            root_sink_reduction=root_diagnostics%potential_root_sink-root_fluxes%root_extraction_sink)
        end block
      else
      call accumulate_wofost_trial_process_rate(trial,t0,t1,qrot,ptra,s,deepest_root_oxygen_factor=deepest_oxygen)
      end if
    else
      call accumulate_wofost_trial_process_rate(trial,t0,t1,qrot,ptra,s)
    end if
    if(s/=FMR_WOFOST_LINEAGE_OK) return
    call prevalidate_wofost_trial_admission(self%weather_window,trial,s)
    if(s/=FMR_WOFOST_LINEAGE_OK) return
    self%weather_interval_active=.true.
    call self%run_standalone_with_forcing(t0,t1,effective,results,status)
    self%weather_interval_active=.false.
    if(status/=FMR_APP_BOOT_OK) return
    ! Only the actually committed physical revision can certify and admit
    ! this interval. A rejected trial leaves the accepted window untouched.
    call certify_fkt_accepted_interval(interval_checkpoint,self%committed(1),certificate,s)
    if(s/=FMR_WOFOST_LINEAGE_OK) error stop 'MC-CROP01 accepted hydro interval lost FKT provenance'
    call admit_wofost_accepted_trial(self%weather_window,certificate,trial,s)
    if(s/=FMR_WOFOST_LINEAGE_OK) error stop 'MC-CROP01 prevalidated accepted window admission failed'
    if(self%weather_configuration%file_weather_irrigation)then
      self%irrigation=irrigation_candidate
      self%irrigation_selection_day=int(day)+self%weather_epoch_day
      self%irrigation_time=t1
      self%irrigation_delivered_cm=self%irrigation_delivered_cm+irrigation_binding%external_inflow_amount_cm
    end if
  end subroutine

  subroutine production_application_initialize_weather_crop_daystart(self,record,controls,owner, &
       crop_identity,crop_lineage,crop_committed,status,initial_dry_weight,initial_rate_parameters)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(swap_daily_weather_record_t), intent(in) :: record
    type(fmr_application_crop_daystart_controls_t), intent(in) :: controls
    type(wofost_crop_owner_state_t), intent(in) :: owner
    integer(int64), intent(in) :: crop_identity,crop_lineage
    type(kernel_committed_state_t), intent(inout) :: crop_committed
    integer, intent(out) :: status
    real(real64), intent(in), optional :: initial_dry_weight
    type(wofost_rate_parameter_bundle_t), intent(in), optional :: initial_rate_parameters
    type(wofost_crop_owner_state_t) :: initial_owner
    type(fmr_application_crop_daystart_controls_t) :: initial_controls
    type(crop_certified_daily_preflight_t) :: daily
    type(crop_daily_lifecycle_candidate_t) :: plan
    type(crop_lifecycle_continuation_t) :: lifecycle
    type(fmr_wofost_crop_transaction_state_t) :: state
    type(kernel_committed_state_t) :: pending_crop
    class(transaction_state_t), allocatable :: physical
    real(real64) :: day,tmin,tmax,rain,etref,time,initial_hprep,initial_hsow,initial_tsoil
    integer :: s,initial_sowing_node
    logical :: available
    status=FMR_APP_BOOT_NOT_READY
    if(.not.self%ready()) return
    status=FMR_APP_BOOT_CROP_TRANSACTION_FAILED
    ! Existing initialization authority creates a new owner exactly once.
    ! This is not an accepted hydro event or a zero-duration F-KT commit.
    if(crop_committed%ready().or.self%crop_daystart_active) return
    if(crop_identity<=0_int64.or.crop_lineage<=0_int64) return
    if(owner%validate()/=WOFOST_CROP_OWNER_OK.or.owner%crop_emerged) return
    initial_owner=owner
    if(present(initial_dry_weight).neqv.present(initial_rate_parameters)) return
    if(present(initial_dry_weight).and.present(initial_rate_parameters)) then
      ! Historical immediate startup is independent of the unresolved
      ! blocked-preparation flags: all three task2 flags are already true.
      if(controls%swprep/=0.or.controls%swsow/=0.or.controls%germ_mode/=0) return
      call initialize_wofost_emergence_owner(initial_dry_weight,initial_rate_parameters,initial_owner,s)
      if(s/=WOFOST_EMERGENCE_INIT_OK) return
    end if
    if(size(self%committed)/=1.or.self%weather_epoch_day==0) return
    if(self%committed(1)%current_revision()/=0_int64) return
    if(self%previous_weather_window%ready()) return
    call record%values(day,tmin,tmax,rain,etref,available)
    if(.not.available) return
    day=day-real(self%weather_epoch_day,real64)
    call self%committed(1)%current_time(time,available)
    if(.not.available.or.time/=day.or.day/=self%weather_configuration%initial_time) return
    initial_controls=controls
    initial_controls%prep_delay=0;initial_controls%sow_delay=0
    initial_controls%temperature_sum=0.0_real64
    select case(controls%initialization_profile)
    case(CROP_PROFILE_B111_TASK2)
      call initialize_b111_crop_lifecycle(crop_identity,controls%swprep,controls%swsow,controls%germ_mode,lifecycle,s)
      if(s/=CROP_CONT_OK) return
      if(lifecycle%prepared.and.lifecycle%sown.and.lifecycle%germinated.and..not.initial_owner%crop_emerged) return
      if(controls%swsow==1) then
        ! Task2 locates the sowing compartment; read the same certified
        ! immutable geometry used by subsequent simulated-sowing daystarts.
        call sample_certified_committed_crop_hydrothermal_forcing(self%committed(1), &
             self%committed(1)%current_lineage_id(),self%committed(1)%current_revision(),time, &
             controls%zprep,controls%zsow,controls%ztempsow,initial_hprep,initial_hsow, &
             initial_tsoil,initial_sowing_node,s)
        if(s/=CROP_CERT_FORCE_OK.or.initial_sowing_node<1) return
      end if
      ! Source cropemergence executes task2 and, for delayed emergence,
      ! task3 in this same first daystart. These are distinct operations;
      ! neither waits for today's future hydrological acceptance.
      if(initial_owner%crop_emerged) then
        call self%begin_weather_day(record,initial_controls,daily,status,task2_only=.true.)
      else
        call self%begin_weather_day(record,initial_controls,daily,status)
      end if
    case(CROP_PROFILE_BOUNDED)
      call self%begin_weather_day(record,initial_controls,daily,status)
    case default
      return
    end select
    if(status/=FMR_APP_BOOT_OK) return
    status=FMR_APP_BOOT_CROP_TRANSACTION_FAILED
    if(controls%initialization_profile==CROP_PROFILE_BOUNDED) then
    call compose_crop_lifecycle_daily_candidate(daily%preparation,daily%germination,plan,s)
    if(s/=CROP_DAILY_OK.or..not.plan%valid) return
    lifecycle%valid=.true.;lifecycle%crop_identity=crop_identity
    lifecycle%prepared=plan%prepared;lifecycle%sown=plan%sown;lifecycle%germinated=plan%germinated
    lifecycle%preparation_delay=plan%preparation_delay;lifecycle%sowing_delay=plan%sowing_delay
    if(plan%germination_evaluated) lifecycle%germination_temperature_sum=daily%germination%next_temperature_sum
    else if(.not.initial_owner%crop_emerged) then
      call compose_crop_lifecycle_daily_candidate(daily%preparation,daily%germination,plan,s, &
           previous_sown=lifecycle%sown,previous_germinated=lifecycle%germinated)
      if(s/=CROP_DAILY_OK.or..not.plan%valid) return
      lifecycle%prepared=plan%prepared;lifecycle%sown=plan%sown;lifecycle%germinated=plan%germinated
      lifecycle%preparation_delay=plan%preparation_delay;lifecycle%sowing_delay=plan%sowing_delay
      if(plan%germination_evaluated) lifecycle%germination_temperature_sum=daily%germination%next_temperature_sum
    end if
    lifecycle%emerged=initial_owner%crop_emerged
    if(self%weather_configuration%file_weather_root_depth_mode==2)then
      if(self%weather_configuration%file_weather_adaptive_root_profile)then
      call initialize_fmr_wofost_crop_transaction_state(initial_owner,state,s,lifecycle_initial=lifecycle, &
        enable_potential_shadow=.true.,root_depth_parameters=self%weather_configuration%file_weather_swrd2_parameters, &
        root_profile_configuration=self%weather_configuration%file_weather_root_profile)
      else
      call initialize_fmr_wofost_crop_transaction_state(initial_owner,state,s,lifecycle_initial=lifecycle, &
        enable_potential_shadow=.true.,root_depth_parameters=self%weather_configuration%file_weather_swrd2_parameters)
      end if
    else
      call initialize_fmr_wofost_crop_transaction_state(initial_owner,state,s,lifecycle_initial=lifecycle, &
        enable_potential_shadow=self%weather_configuration%file_weather_root_depth_mode==3)
    end if
    if(s/=FMR_WOF38_OK) return
    allocate(fmr_wofost_crop_transaction_state_t::physical)
    select type(physical)
    type is(fmr_wofost_crop_transaction_state_t)
      physical=state
    end select
    call pending_crop%initialize(crop_lineage,physical,available,time)
    if(.not.available) return
    crop_committed=pending_crop
    self%crop_daystart_active=.true.;self%initial_crop_daystart_committed=.true.
    self%accepted_crop_lineage=crop_lineage;self%accepted_crop_revision=0_int64
    status=FMR_APP_BOOT_OK
  end subroutine

  subroutine production_application_run_weather_crop_daystart(self,record,controls,crop_kernel, &
       crop_parameters,crop_config,crop_committed,result,status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(swap_daily_weather_record_t), intent(in) :: record
    type(fmr_application_crop_daystart_controls_t), intent(in) :: controls
    type(kernel_executor_t), intent(inout) :: crop_kernel
    type(fmr_wofost_crop_transaction_parameters_t), intent(in) :: crop_parameters
    type(canonical_numerical_config_t), intent(in) :: crop_config
    type(kernel_committed_state_t), intent(inout) :: crop_committed
    type(kernel_result_t), intent(out) :: result
    integer, intent(out) :: status
    type(fmr_application_crop_daystart_controls_t) :: effective_controls
    type(crop_certified_daily_preflight_t) :: daily
    type(crop_lifecycle_continuation_t) :: lifecycle
    type(crop_lifecycle_continuation_t), allocatable :: historical_current
    type(wofost_crop_owner_state_t) :: owner
    type(wofost_one_day_forcing_t) :: crop_forcing
    type(crop_co2_response_t) :: co2_response
    type(fmr_wofost_crop_event_forcing_t) :: event
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    class(transaction_state_t), allocatable :: physical
    real(real64) :: day,tmin,tmax,rain,etref,crop_time,solar(6),radiation
    integer :: iday
    integer :: s,commit_status
    logical :: available,did_commit,retired,active_event,emergence,new_weather_day
    active_event=.false.;emergence=.false.
    result=kernel_result_t();status=FMR_APP_BOOT_NOT_READY
    if(.not.self%ready()) return
    status=FMR_APP_BOOT_CROP_TRANSACTION_FAILED
    call crop_committed%snapshot(physical,available)
    if(.not.available) return
    select type(physical)
    type is(fmr_wofost_crop_transaction_state_t)
      call physical%snapshot_lifecycle(lifecycle,available)
      if(.not.available.or..not.lifecycle%ready()) return
      call physical%snapshot_owner(owner,available)
      if(.not.available.or.lifecycle%harvested) return
      if(owner%crop_emerged.neqv.lifecycle%emerged) return
      if(owner%crop_emerged.and..not.self%weather_configuration%file_weather_rooted) return
    class default
      return
    end select
    if(controls%initialization_profile/=lifecycle%initialization_profile) return
    new_weather_day=.not.self%weather_record%same_input(record)
    if(self%weather_configuration%file_weather_dayend.and.owner%crop_emerged) then
      ! Do not discard the still-undelivered current record by acquiring
      ! tomorrow's meteorology. Complete its real accepted window first.
      if(new_weather_day.and.self%weather_window%ready()) then
        if(.not.self%weather_window%delivery_committed()) then
          status=FMR_APP_BOOT_CROP_WINDOW_UNAVAILABLE;return
        end if
      end if
    end if
    if(lifecycle%initialization_profile==CROP_PROFILE_B111_TASK2) then
      ! Source emergence is checked from the previous accepted flags before
      ! task3. Only the explicit rooted profile may initialize biomass and
      ! complete active growth; the original pre-emergence profile stays bounded.
      if(lifecycle%prepared.and.lifecycle%sown.and.lifecycle%germinated) then
        if(.not.self%weather_configuration%file_weather_rooted) then
          status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED;return
        end if
        active_event=.true.;emergence=.not.owner%crop_emerged
      end if
      allocate(historical_current,source=lifecycle)
    end if
    self%crop_daystart_active=.true.
    if(self%accepted_crop_lineage/=0_int64) then
      if(crop_committed%current_lineage_id()/=self%accepted_crop_lineage.or. &
           crop_committed%current_revision()/=self%accepted_crop_revision) return
    end if
    effective_controls=controls
    ! Continuation comes exclusively from the existing committed crop owner.
    effective_controls%prep_delay=lifecycle%preparation_delay
    effective_controls%sow_delay=lifecycle%sowing_delay
    effective_controls%temperature_sum=lifecycle%germination_temperature_sum
    if(lifecycle%prepared) effective_controls%swprep=0
    if(lifecycle%sown) effective_controls%swsow=0
    if(lifecycle%germinated) effective_controls%germ_mode=0
    call self%begin_weather_day(record,effective_controls,daily,status)
    if(status/=FMR_APP_BOOT_OK) return
    if(self%weather_configuration%file_weather_dayend.and.owner%crop_emerged) then
      call record%values(day,tmin,tmax,rain,etref,available)
      if(.not.available) return
      day=day-real(self%weather_epoch_day,real64)
      call crop_committed%current_time(crop_time,available)
      if(.not.available.or.crop_time/=day.or..not.self%previous_weather_window%delivery_committed()) then
        status=FMR_APP_BOOT_CROP_WINDOW_UNAVAILABLE;return
      end if
      ! Previous growth is already accepted. Authentic morning weather and
      ! the new physical window were acquired, but no crop event is repeated.
      status=FMR_APP_BOOT_CROP_EVENT_DELIVERED
      if(new_weather_day) status=FMR_APP_BOOT_OK
      return
    end if
    status=FMR_APP_BOOT_CROP_WINDOW_UNAVAILABLE
    if(.not.self%previous_weather_window%complete()) return
    if(self%previous_weather_window%delivery_committed()) then
      status=FMR_APP_BOOT_CROP_EVENT_DELIVERED
      return
    end if
    call record%values(day,tmin,tmax,rain,etref,available)
    if(.not.available) return
    day=day-real(self%weather_epoch_day,real64)
    call crop_committed%current_time(crop_time,available)
    if(.not.available.or.crop_time/=day-1.0_real64) return
    crop_forcing%minimum_temperature=tmin
    crop_forcing%average_temperature=(tmax+tmin)*0.5_real64
    crop_forcing%daytime_average_temperature=(tmax+crop_forcing%average_temperature)*0.5_real64
    status=FMR_APP_BOOT_CROP_TRANSACTION_FAILED
    if(active_event) then
      if(.not.crop_parameters%matches_root_depth(self%weather_configuration%file_weather_root_depth_mode, &
        self%weather_configuration%file_weather_swrd2_parameters)) return
      if(.not.crop_parameters%matches_root_profile(self%weather_configuration%file_weather_adaptive_root_profile, &
        self%weather_configuration%file_weather_root_profile))return
      if(.not.crop_parameters%matches_canopy(self%weather_configuration%file_weather_stem_area_coefficient, &
           self%weather_configuration%file_weather_storage_area_coefficient)) return
      ! Completed growth belongs to its own previous immutable record;
      ! current morning weather still feeds the independent daily preflight.
      if(.not.self%previous_weather_record%same_source(record)) return
      call self%previous_weather_record%values(day,tmin,tmax,rain,etref,available)
      if(.not.available) return
      day=day-real(self%weather_epoch_day,real64)
      if(day/=crop_time) return
      call self%previous_weather_record%growth_values(self%weather_configuration%file_weather_latitude, &
           iday,radiation,solar,available)
      if(.not.available) return
      crop_forcing%minimum_temperature=tmin
      crop_forcing%average_temperature=(tmax+tmin)*0.5_real64
      crop_forcing%daytime_average_temperature=(tmax+crop_forcing%average_temperature)*0.5_real64
      crop_forcing%global_radiation=radiation
      crop_forcing%daylength_hours=solar(1);crop_forcing%photoperiodic_daylength_hours=solar(2)
      crop_forcing%sinld=solar(3);crop_forcing%cosld=solar(4)
      crop_forcing%diffuse_perpendicular_radiation=solar(5)
      crop_forcing%daily_sine_solar_elevation_integral=solar(6)
      if(self%weather_configuration%file_weather_co2_response.and.owner%crop_emerged) then
        call resolve_weather_crop_co2(self,self%previous_weather_record,co2_response,s)
        if(s/=CROP_CO2_RESPONSE_OK) return
        crop_forcing%co2_efficiency_factor=co2_response%efficiency_factor
        crop_forcing%co2_amax_factor=co2_response%amax_factor
      end if
      day=day+1.0_real64
      if(emergence) then
        call prepare_fmr_wofost_crop_event_forcing(self%previous_weather_window,crop_forcing,event,s, &
             active_expected_revision=lifecycle%revision, &
             emergence_dry_weight=self%weather_configuration%file_weather_emergence_dry_weight)
      else
        call prepare_fmr_wofost_crop_event_forcing(self%previous_weather_window,crop_forcing,event,s, &
             active_expected_revision=lifecycle%revision)
      end if
    else
    ! This profile is pre-emergence only. It neither invents solar forcing
    ! nor claims active WOFOST growth from a root-free source trajectory.
    call propose_weather_crop_physical_event(self%committed(1), &
         self%committed(1)%current_lineage_id(),self%committed(1)%current_revision(),day, &
         self%weather,1_int64,1_int64,self%weather_revision,day,self%previous_weather_window,crop_forcing, &
         lifecycle%revision,effective_controls%zprep,effective_controls%zsow,effective_controls%ztempsow, &
         effective_controls%zgerm,effective_controls%swprep,effective_controls%swsow, &
         effective_controls%hprep_threshold,effective_controls%hsow_threshold,effective_controls%sow_temperature, &
         effective_controls%prep_delay,effective_controls%sow_delay,effective_controls%max_prep_delay, &
         effective_controls%max_sow_delay,effective_controls%germ_mode,effective_controls%temperature_sum, &
         effective_controls%optimal_sum,effective_controls%base_temperature,effective_controls%max_effective_temperature, &
         effective_controls%dry_head,effective_controls%wet_head,effective_controls%water_response_a,event,s, &
         historical_current=historical_current)
    end if
    status=FMR_APP_BOOT_CROP_TRANSACTION_FAILED
    if(s/=CROP_EVENT_COMPOSE_OK.or..not.event%ready()) return
    call crop_committed%capture_checkpoint(checkpoint,available)
    if(.not.available) return
    call crop_kernel%advance_interval(crop_parameters,crop_committed,event,crop_config, &
         day-1.0_real64,day,result,candidate,diagnostics,checkpoint)
    if(.not.result%completed.or..not.candidate%ready()) return
    call crop_kernel%commit_candidate(crop_committed,candidate,diagnostics,did_commit,commit_status)
    if(.not.did_commit) return
    call reconcile_committed_crop_event_receipt(self%previous_weather_window,crop_committed,retired,s)
    if(s/=FMR_WOF39_OK.or..not.retired) error stop 'MC-CROP01 accepted crop receipt retirement failed'
    self%accepted_crop_lineage=crop_committed%current_lineage_id()
    self%accepted_crop_revision=crop_committed%current_revision()
    status=FMR_APP_BOOT_OK
  end subroutine

  ! The record selects the physical year's forcing, including lagged growth
  ! at a year boundary. Recompute from immutable inputs after opaque restart.
  subroutine resolve_weather_crop_co2(self,record,response,status)
    class(fmr_production_application_bootstrap_t),intent(in)::self
    type(swap_daily_weather_record_t),intent(in)::record
    type(crop_co2_response_t),intent(out)::response
    integer,intent(out)::status
    real(real64)::day,tmin,tmax,rain,etref,ppm
    logical::available
    response=crop_co2_response_t();status=1
    call record%values(day,tmin,tmax,rain,etref,available)
    if(.not.available)return
    call self%weather_configuration%file_weather_atmospheric_co2%resolve(int(day),ppm,status)
    if(status/=CROP_ATMOSPHERIC_CO2_OK)return
    call evaluate_crop_co2_response(self%weather_configuration%file_weather_co2_parameters,ppm,response,status)
  end subroutine

  subroutine production_application_run_weather_crop_dayend(self,crop_kernel,crop_parameters,crop_config, &
       crop_committed,result,status)
    class(fmr_production_application_bootstrap_t),intent(inout)::self
    type(kernel_executor_t),intent(inout)::crop_kernel
    type(fmr_wofost_crop_transaction_parameters_t),intent(in)::crop_parameters
    type(canonical_numerical_config_t),intent(in)::crop_config
    type(kernel_committed_state_t),intent(inout)::crop_committed
    type(kernel_result_t),intent(out)::result
    integer,intent(out)::status
    class(transaction_state_t),allocatable::physical
    type(crop_lifecycle_continuation_t)::lifecycle
    type(wofost_crop_owner_state_t)::owner
    type(wofost_one_day_forcing_t)::forcing
    type(crop_co2_response_t)::co2_response
    type(fmr_wofost_crop_event_forcing_t)::event
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::diagnostics
    real(real64)::day,tmin,tmax,rain,etref,soil_time,crop_time,radiation,solar(6)
    integer::s,iday,commit_status
    logical::available,did_commit,retired
    result=kernel_result_t();status=FMR_APP_BOOT_NOT_READY
    if(.not.self%ready()) return
    status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if(.not.self%weather_configuration%file_weather_dayend.or..not.self%weather_configuration%file_weather_rooted) return
    if(size(self%committed)/=1.or.associated(self%active_context).or.self%weather_interval_active) return
    if(.not.self%crop_daystart_active) return
    status=FMR_APP_BOOT_CROP_TRANSACTION_FAILED
    if(crop_committed%current_lineage_id()/=self%accepted_crop_lineage.or. &
         crop_committed%current_revision()/=self%accepted_crop_revision) return
    call crop_committed%snapshot(physical,available)
    if(.not.available) return
    select type(physical)
    type is(fmr_wofost_crop_transaction_state_t)
      call physical%snapshot_lifecycle(lifecycle,available)
      if(.not.available.or..not.lifecycle%ready()) return
      call physical%snapshot_owner(owner,available)
      if(.not.available.or..not.owner%crop_emerged.or..not.lifecycle%emerged.or.lifecycle%harvested) return
    class default
      return
    end select
    status=FMR_APP_BOOT_CROP_WINDOW_UNAVAILABLE
    if(.not.self%weather_window%complete()) return
    if(self%weather_window%delivery_committed()) then
      status=FMR_APP_BOOT_CROP_EVENT_DELIVERED;return
    end if
    call self%weather_record%values(day,tmin,tmax,rain,etref,available)
    if(.not.available) return
    day=day-real(self%weather_epoch_day,real64)
    call self%committed(1)%current_time(soil_time,available)
    if(.not.available.or.soil_time/=day+1.0_real64) return
    call crop_committed%current_time(crop_time,available)
    if(.not.available.or.crop_time/=day) return
    status=FMR_APP_BOOT_CROP_TRANSACTION_FAILED
    if(.not.crop_parameters%matches_canopy(self%weather_configuration%file_weather_stem_area_coefficient, &
         self%weather_configuration%file_weather_storage_area_coefficient)) return
    if(.not.crop_parameters%matches_root_depth(self%weather_configuration%file_weather_root_depth_mode, &
      self%weather_configuration%file_weather_swrd2_parameters)) return
    if(.not.crop_parameters%matches_root_profile(self%weather_configuration%file_weather_adaptive_root_profile, &
      self%weather_configuration%file_weather_root_profile))return
    call self%weather_record%growth_values(self%weather_configuration%file_weather_latitude, &
         iday,radiation,solar,available)
    if(.not.available) return
    forcing%minimum_temperature=tmin
    forcing%average_temperature=(tmax+tmin)*0.5_real64
    forcing%daytime_average_temperature=(tmax+forcing%average_temperature)*0.5_real64
    forcing%global_radiation=radiation
    forcing%daylength_hours=solar(1);forcing%photoperiodic_daylength_hours=solar(2)
    forcing%sinld=solar(3);forcing%cosld=solar(4)
    forcing%diffuse_perpendicular_radiation=solar(5)
    forcing%daily_sine_solar_elevation_integral=solar(6)
    if(self%weather_configuration%file_weather_co2_response) then
      call resolve_weather_crop_co2(self,self%weather_record,co2_response,s)
      if(s/=CROP_CO2_RESPONSE_OK) return
      forcing%co2_efficiency_factor=co2_response%efficiency_factor
      forcing%co2_amax_factor=co2_response%amax_factor
    end if
    call prepare_fmr_wofost_crop_event_forcing(self%weather_window,forcing,event,s, &
         active_expected_revision=lifecycle%revision)
    if(s/=CROP_EVENT_COMPOSE_OK.or..not.event%ready()) return
    call crop_committed%capture_checkpoint(checkpoint,available)
    if(.not.available) return
    call crop_kernel%advance_interval(crop_parameters,crop_committed,event,crop_config, &
         day,day+1.0_real64,result,candidate,diagnostics,checkpoint)
    if(.not.result%completed.or..not.candidate%ready()) return
    call crop_kernel%commit_candidate(crop_committed,candidate,diagnostics,did_commit,commit_status)
    if(.not.did_commit) return
    call reconcile_committed_crop_event_receipt(self%weather_window,crop_committed,retired,s)
    if(s/=FMR_WOF39_OK.or..not.retired) error stop 'MC-CROP01 accepted day-end receipt retirement failed'
    self%accepted_crop_lineage=crop_committed%current_lineage_id()
    self%accepted_crop_revision=crop_committed%current_revision()
    status=FMR_APP_BOOT_OK
  end subroutine

  subroutine production_application_capture_weather_crop_continuation(self,crop_committed,bundle,status)
    class(fmr_production_application_bootstrap_t), intent(in) :: self
    type(kernel_committed_state_t), intent(in) :: crop_committed
    type(fmr_weather_crop_application_continuation_t), intent(out) :: bundle
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: physical
    real(real64) :: soil_time,crop_time,day,tmin,tmax,rain,etref
    logical :: available
    integer :: s
    bundle=fmr_weather_crop_application_continuation_t()
    status=FMR_APP_BOOT_NOT_READY
    if(.not.self%ready()) return
    status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if(self%weather_epoch_day==0.or.size(self%committed)/=1.or.associated(self%active_context)) return
    if(.not.self%crop_daystart_active.or.self%weather_interval_active) return
    if(crop_committed%current_lineage_id()/=self%accepted_crop_lineage.or. &
         crop_committed%current_revision()/=self%accepted_crop_revision) return
    call crop_committed%snapshot(physical,available)
    if(.not.available) return
    select type(physical)
    type is(fmr_wofost_crop_transaction_state_t)
      if(.not.physical%receipt_ready()) then
        if(.not.self%initial_crop_daystart_committed.or.self%accepted_crop_revision/=0_int64) return
      end if
    class default
      return
    end select
    call self%committed(1)%current_time(soil_time,available)
    if(.not.available) return
    call crop_committed%current_time(crop_time,available)
    if(.not.available) return
    call self%weather_record%values(day,tmin,tmax,rain,etref,available)
    if(.not.available) return
    day=day-real(self%weather_epoch_day,real64)
    if(self%weather_configuration%file_weather_dayend.and.self%weather_window%delivery_committed()) then
      if(.not.self%weather_window%complete().or.crop_time/=day+1.0_real64.or.soil_time/=crop_time) return
    else if(self%previous_weather_window%ready().and..not.self%previous_weather_window%delivery_committed()) then
      ! Pending daystart/retry is a real previous accepted window; preserve
      ! its undelivered state without advancing today's soil or crop.
      if(.not.self%previous_weather_window%complete()) return
      if(crop_time/=day-1.0_real64.or.soil_time/=day) return
    else
      if(crop_time/=day.or.soil_time<day.or.soil_time>day+1.0_real64) return
      if(.not.self%previous_weather_window%ready().and..not.self%initial_crop_daystart_committed) return
    end if
    call export_kernel_committed_state(self%committed(1),self%templates(1)%template_id,bundle%soil,available,s)
    if(.not.available.or.s/=KERNEL_PERSISTENCE_OK) return
    call export_kernel_committed_state(crop_committed,904001_int64,bundle%crop,available,s)
    if(.not.available.or.s/=KERNEL_PERSISTENCE_OK) return
    if(self%weather_configuration%file_weather_irrigation)then
      if(self%irrigation_time/=soil_time)return
      call fmr_export_allocated_irrigation_restart(self%irrigation,bundle%irrigation,s)
      if(s/=FMR_IRR_ALLOCATION_OK)return
      bundle%irrigation_schema=1;bundle%irrigation_selection_day=self%irrigation_selection_day
      bundle%irrigation_time=self%irrigation_time;bundle%irrigation_delivered_cm=self%irrigation_delivered_cm
    end if
    bundle%configuration=self%weather_configuration
    bundle%weather=self%weather;bundle%record=self%weather_record
    bundle%previous_record=self%previous_weather_record
    bundle%weather_revision=self%weather_revision
    bundle%current_window=self%weather_window;bundle%previous_window=self%previous_weather_window
    bundle%crop_lineage=self%accepted_crop_lineage;bundle%crop_revision=self%accepted_crop_revision
    bundle%initial_crop_daystart_committed=self%initial_crop_daystart_committed
    bundle%valid=.true.;status=FMR_APP_BOOT_OK
  end subroutine

  subroutine production_application_restore_weather_crop_continuation(self,bundle,crop_committed,status,expected_raintb,expected_demand)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(fmr_weather_crop_application_continuation_t), intent(in) :: bundle
    type(swap_raintb_t),intent(in),optional :: expected_raintb
    type(daily_atmospheric_demand_parameters_t),intent(in),optional :: expected_demand
    type(kernel_committed_state_t), intent(inout) :: crop_committed
    integer, intent(out) :: status
    type(kernel_committed_state_t) :: pending_soil,pending_crop
    type(fmr_allocated_irrigation_state_t) :: pending_irrigation
    real(real64) :: pending_time
    logical :: restored
    integer :: s
    status=FMR_APP_BOOT_INVALID_CONFIG
    ! Restart creates owners. It never overwrites an active application or
    ! a live committed crop object, and no failure partially publishes crop.
    if(self%ready().or.crop_committed%ready()) return
    if(.not.bundle%valid.or..not.bundle%record%ready()) return
    if(bundle%configuration%file_weather_daily_demand) then
      if(.not.present(expected_demand)) return
      if(.not.bundle%configuration%file_weather_demand_parameters%same_input(expected_demand)) return
    end if
    if(bundle%configuration%file_weather_swrain==1) then
      if(.not.present(expected_raintb)) return
      if(.not.bundle%configuration%file_weather_raintb%same_input(expected_raintb)) return
    end if
    if(.not.allocated(bundle%configuration%tiles)) return
    if(size(bundle%configuration%tiles)/=1) return
    call restore_kernel_committed_state(bundle%soil,bundle%configuration%tiles(1)%template%template_id, &
         pending_soil,restored,s)
    if(.not.restored.or.s/=KERNEL_PERSISTENCE_OK) return
    call restore_kernel_committed_state(bundle%crop,904001_int64,pending_crop,restored,s)
    if(.not.restored.or.s/=KERNEL_PERSISTENCE_OK) return
    if(pending_crop%current_lineage_id()/=bundle%crop_lineage.or. &
         pending_crop%current_revision()/=bundle%crop_revision) return
    if(bundle%configuration%file_weather_irrigation)then
      if(bundle%irrigation_schema/=1)return
      call fmr_restore_allocated_irrigation_restart(bundle%irrigation,pending_irrigation,s)
      if(s/=FMR_IRR_ALLOCATION_OK)return
      if(.not.bundle%configuration%file_weather_irrigation_depth%fixed_interval_enabled)then
        if(pending_irrigation%management%policy%weekly_day_counter>6.and. &
           pending_irrigation%management%policy%weekly_day_counter/=366)return
      else
        if(pending_irrigation%management%policy%weekly_day_counter> &
           bundle%configuration%file_weather_irrigation_depth%fixed_interval_days.and. &
           pending_irrigation%management%policy%weekly_day_counter/=366)return
      end if
      call pending_soil%current_time(pending_time,restored)
      if(.not.restored)return
      if(.not.all(ieee_is_finite([bundle%irrigation_time,bundle%irrigation_delivered_cm])))return
      if(bundle%irrigation_time/=pending_time.or.bundle%irrigation_delivered_cm<0.0_real64)return
    else
      if(bundle%irrigation_schema/=0)return
    end if
    call self%initialize(bundle%configuration,status)
    if(status/=FMR_APP_BOOT_OK) return
    ! The fresh startup objects have not been exposed. Publish the validated
    ! existing owner snapshots together, retaining the soil certificate and
    ! numerical physical continuation, exact source bytes and delivered event.
    self%committed(1)=pending_soil
    self%weather=bundle%weather;self%weather_record=bundle%record
    self%previous_weather_record=bundle%previous_record
    self%weather_revision=bundle%weather_revision
    self%weather_window=bundle%current_window;self%previous_weather_window=bundle%previous_window
    self%crop_daystart_active=.true.
    self%initial_crop_daystart_committed=bundle%initial_crop_daystart_committed
    self%accepted_crop_lineage=bundle%crop_lineage;self%accepted_crop_revision=bundle%crop_revision
    if(bundle%configuration%file_weather_irrigation)then
      self%irrigation=pending_irrigation;self%irrigation_selection_day=bundle%irrigation_selection_day
      self%irrigation_time=bundle%irrigation_time;self%irrigation_delivered_cm=bundle%irrigation_delivered_cm
    end if
    crop_committed=pending_crop
    status=FMR_APP_BOOT_OK
  end subroutine

  ! INT12-C direct PMdirect application and its explicit tile contract.
  logical function explicit_pmdirect_tile_valid(tile) result(valid)
    type(fmr_production_application_tile_config_t), intent(in) :: tile
    valid=.false.
    if (tile%parameters%bottom_mode/=2.or.tile%parameters%root_compensation%method/=ROOT_COMP_OFF) return
    if (tile%template%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BASE.or. &
        tile%template%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_NONE.or. &
        tile%template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY) return
    if (tile%parameters%soil_temperature_active.or.tile%parameters%frost_active.or.tile%parameters%snow_active.or. &
        tile%parameters%macropore_active.or.tile%parameters%drainage_response_active.or. &
        tile%parameters%root_salinity_active.or.tile%parameters%root_frost%active.or. &
        tile%parameters%black_evaporation_active.or.tile%parameters%boesten_evaporation_active.or. &
        tile%parameters%elasticity_active.or.tile%parameters%direct_retention_active.or. &
        tile%parameters%hysteresis_active.or.tile%parameters%tabulated_hydraulics_active) return
    if (allocated(tile%parameters%bartholomeus).or.allocated(tile%parameters%micro_de_willigen)) return
    valid=.true.
  end function explicit_pmdirect_tile_valid

  subroutine production_application_run_pmdirect_interception_interval(self,owners,t0,t1,inputs, &
       results,accepted_interception,receipts,status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(fmr_interception_source_window_t), intent(inout) :: owners(:)
    real(real64), intent(in) :: t0,t1
    type(fmr_pmdirect_interception_input_t), intent(in) :: inputs(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    real(real64), allocatable, intent(out) :: accepted_interception(:)
    type(fmr_pmdirect_interception_receipt_t), allocatable, intent(out) :: receipts(:)
    integer, intent(out) :: status
    type(fmr_pmdirect_interception_receipt_t), allocatable :: trial(:)
    type(fmr_b110_physical_forcing_t), allocatable :: effective(:)
    type(pmdirect_swetr0_diagnostics_t) :: daily_diag,interval_diag
    type(fmr_pmdirect_surface_demand_binding_diagnostics_t) :: demand_diag
    type(fmr_pmdirect_top_precip_binding_diagnostics_t) :: top_diag
    type(fmr_pmdirect_ptra_root_binding_diagnostics_t) :: ptra_diag
    type(fmr_crop_root_uptake_adapter_diagnostics_t) :: root_adapter
    type(fmr_root_uptake_binding_diagnostics_t) :: root_binding
    type(root_water_uptake_diagnostics_t) :: root_diag
    type(crop_root_uptake_input_t) :: roots
    type(surface_evaporation_demand_t) :: demand
    type(b110_dynamic_top_boundary_request_t) :: base,request
    type(soil_water_parameter_set_t) :: geometry
    type(b110_default_mvg_parameters_t) :: hydraulics
    type(fmr_interception_source_window_restart_t) :: record
    class(transaction_state_t), allocatable :: physical
    real(real64) :: aggregate
    logical :: ok
    integer :: i,st
    allocate(accepted_interception(size(owners)));accepted_interception=0.0_real64
    status=FMR_APP_BOOT_NOT_READY
    if (.not.self%ready()) return
    status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if (.not.self%explicit_pmdirect_interception) return
    status=FMR_APP_BOOT_INTERCEPTION_REJECTED
    if (.not.all(ieee_is_finite([t0,t1]))) return
    if (t1<=t0) return
    if (size(inputs)/=size(self%columns).or.size(owners)/=size(self%columns)) return
    allocate(trial(size(inputs)),effective(size(inputs)))
    do i=1,size(inputs)
      if (inputs(i)%canopy%crop_emerged.neqv.inputs(i)%roots%crop_emerged) return
      if (inputs(i)%roots%crop_emerged.and..not.self%parameters(i)%root_extraction_active) return
      if (inputs(i)%root_parameters%active_nodes/=self%parameters(i)%active_nodes) return
      call evaluate_pmdirect_swetr0_daily(inputs(i)%weather,inputs(i)%site,inputs(i)%canopy,trial(i)%daily,daily_diag)
      if (.not.daily_diag%daily_result_produced) return
      interval_diag=daily_diag
      call apply_swinter1_daily_interval(inputs(i)%weather,inputs(i)%canopy,trial(i)%daily,trial(i)%interval,interval_diag)
      if (.not.interval_diag%interval_result_produced) return
      call export_fmr_interception_source_window_restart(owners(i),t0,record,st)
      if (st/=FMR_INTWIN_OK) return
      if (record%column_id/=self%columns(i)%column_id) return
      if (record%source_window%t1-record%source_window%t0>1.0_real64) return
      aggregate=trial(i)%interval%interception_rate_cm_per_day*(record%source_window%t1-record%source_window%t0)
      if (abs(aggregate-record%source_window%aggregate)> &
          64.0_real64*epsilon(aggregate)*max(tiny(aggregate),abs(aggregate))) return
      call fmr_bind_pmdirect_surface_evaporation_demand(trial(i)%daily,daily_diag,demand,demand_diag)
      if (.not.demand_diag%result_produced) return
      base=b110_dynamic_top_boundary_request_t()
      base%step_duration_day=t1-t0;base%conductivity_mean_method=self%parameters(i)%swkmean
      base%runoff_resistance_day=1.0_real64
      base%potential_bare_soil_evaporation_cm_per_day=demand%bare_soil_demand
      base%potential_pond_evaporation_cm_per_day=demand%ponded_water_demand
      call self%committed(i)%snapshot(physical,ok)
      if (.not.ok) return
      select type(physical)
      class is(fmr_b110_physical_state_t)
        base%pressure_head_top_cm=physical%pressure_head(1)
        base%water_content_top=physical%water_content(1)
        base%previous_ponding_depth_cm=physical%ponding_depth
        base%candidate_ponding_depth_cm=physical%ponding_depth
      class default
        return
      end select
      call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(base,trial(i)%interval,interval_diag,request,top_diag)
      if (.not.top_diag%result_produced) return
      geometry%parameter_set_id=self%parameters(i)%parameter_set_id
      geometry%active_nodes=self%parameters(i)%active_nodes
      geometry%z=self%parameters(i)%z;geometry%dz=self%parameters(i)%dz
      geometry%node_distance=self%parameters(i)%node_distance
      call initialize_b110_default_mvg_parameters(hydraulics,self%parameters(i)%cofgen)
      call evaluate_b110_dynamic_top_boundary(geometry,hydraulics,request,trial(i)%top)
      call bind_ppa_wu03_flux_result_to_effective_forcing(self%base_forcing(i),trial(i)%top,effective(i),st)
      if (st/=PPA_WU03_OK) return
      call fmr_bind_pmdirect_ptra_to_root_input(inputs(i)%roots,self%parameters(i)%active_nodes, &
           trial(i)%interval,interval_diag,roots,ptra_diag)
      if (.not.ptra_diag%result_produced) return
      call fmr_evaluate_shared_crop_root_uptake(self%committed(i),inputs(i)%root_parameters,roots, &
           trial(i)%roots,root_diag,root_binding,root_adapter)
      if (root_adapter%status/=FMR_CROP_ROOT_ADAPTER_OK) return
      effective(i)%root_extraction_sink=trial(i)%roots%root_extraction_sink
    end do
    call self%run_interception_window_interval(owners,t0,t1,effective,results,accepted_interception,status)
    if (status/=FMR_APP_BOOT_OK) return
    trial%accepted=.true.
    call move_alloc(trial,receipts)
  end subroutine production_application_run_pmdirect_interception_interval
  ! End INT12-C direct PMdirect application.

  ! Explicit source-window application: both physical and companion changes
  ! remain private until this call succeeds. Existing standalone calls retain
  ! their own partial-progress semantics.
  subroutine production_application_run_interception_window_interval(self, owners, t0, t1, &
       effective_forcing, results, accepted_interception, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(fmr_interception_source_window_t), intent(inout) :: owners(:)
    real(real64), intent(in) :: t0, t1
    type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    real(real64), allocatable, intent(out) :: accepted_interception(:)
    integer, intent(out) :: status
    type(fmr_interception_source_window_t), allocatable :: trial_owners(:)
    type(kernel_committed_state_t), allocatable :: before(:)
    type(fmr_interception_source_window_restart_t) :: record
    real(real64) :: proposed_amount
    integer :: i, local_status

    allocate(accepted_interception(size(owners)))
    accepted_interception=0.0_real64
    status=FMR_APP_BOOT_NOT_READY
    if (.not.self%ready()) return
    status=FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if (associated(self%active_context).or.self%weather_epoch_day/=0) return
    ! This is the qualified explicit root-inactive fixed-flux receiver. Do not
    ! silently acquire optional-process or automatic crop/weather semantics.
    if (any(self%parameters%bottom_mode/=2).or.(any(self%parameters%root_extraction_active).and..not.self%explicit_pmdirect_interception).or. &
        any(self%parameters%black_evaporation_active).or.any(self%parameters%boesten_evaporation_active).or. &
        any(self%parameters%macropore_active).or. &
        any(self%parameters%snow_active).or.any(self%parameters%frost_active).or. &
        any(self%parameters%soil_temperature_active)) return
    if (any(self%templates%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BASE).or. &
        any(self%templates%solute_state_layout_id/=0_int64).or. &
        self%numerical%transaction%temporal_mode/=TX_TEMPORAL_MODEL_CERTIFICATE) return
    status=FMR_APP_BOOT_INTERCEPTION_REJECTED
    if (size(owners)/=size(self%columns).or.size(effective_forcing)/=size(self%columns)) return
    trial_owners=owners
    do i=1,size(owners)
      call export_fmr_interception_source_window_restart(owners(i),t0,record,local_status)
      if (local_status/=FMR_INTWIN_OK) return
      if (record%column_id/=self%columns(i)%column_id) return
      call prepare_fmr_interception_source_window_trial(trial_owners(i),t1,proposed_amount,local_status)
      if (local_status/=FMR_INTWIN_OK) return
    end do
    before=self%committed
    call self%run_standalone_with_forcing(t0,t1,effective_forcing,results,status)
    if (status/=FMR_APP_BOOT_OK) then
      self%committed=before
      if (allocated(results)) deallocate(results)
      return
    end if
    status=FMR_APP_BOOT_INTERCEPTION_REJECTED
    do i=1,size(owners)
      if (.not.results(i)%mass%complete) exit
      call accept_fmr_interception_source_window_result(trial_owners(i),results(i)%column_id, &
           results(i)%requested_t0,results(i)%requested_t1,results(i)%committed,results(i)%accepted_substeps, &
           results(i)%initial_revision,results(i)%final_revision,results(i)%final_committed_time, &
           results(i)%final_committed_time_bound,accepted_interception(i),local_status)
      if (local_status/=FMR_INTWIN_OK) exit
    end do
    if (i<=size(owners)) then
      self%committed=before
      accepted_interception=0.0_real64
      if (allocated(results)) deallocate(results)
      return
    end if
    owners=trial_owners
    status=FMR_APP_BOOT_OK
  end subroutine production_application_run_interception_window_interval

  subroutine production_application_run_standalone(self, t0, t1, results, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    integer, intent(out) :: status

    if (allocated(results)) deallocate(results)
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return

    call self%run_standalone_with_forcing(t0, t1, self%base_forcing, results, status)
  end subroutine production_application_run_standalone

  subroutine production_application_run_standalone_with_forcing(self, t0, t1, effective_forcing, results, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1
    type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    integer, intent(out) :: status

    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    integer :: dispatch_status, i

    if (allocated(results)) deallocate(results)
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return
    if(self%weather_epoch_day/=0.and..not.self%weather_interval_active) then
      status=FMR_APP_BOOT_WEATHER_REJECTED
      return
    end if
    if (associated(self%active_context)) then
      status = FMR_APP_BOOT_CONTEXT_BUSY
      return
    end if
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) then
      status = FMR_APP_BOOT_INVALID_CONFIG
      return
    end if
    if (size(effective_forcing) /= size(self%columns)) then
      status = FMR_APP_BOOT_INVALID_CONFIG
      return
    end if

    do i = 1, size(effective_forcing)
      if (self%ordinary_head_application) then
        if (.not. allocated(effective_forcing(i)%legacy_swbotb5_control)) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
        if (.not. effective_forcing(i)%legacy_swbotb5_control%ready()) then
          status = FMR_APP_BOOT_INVALID_CONFIG
          return
        end if
        if (allocated(effective_forcing(i)%legacy_swbotb3_implicit_control)) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
      else if (self%ordinary_cauchy_application) then
        if (.not. allocated(effective_forcing(i)%legacy_swbotb3_implicit_control)) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
        if (.not. effective_forcing(i)%legacy_swbotb3_implicit_control%ready()) then
          status = FMR_APP_BOOT_INVALID_CONFIG
          return
        end if
        if (allocated(effective_forcing(i)%legacy_swbotb5_control)) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
      else if (self%ordinary_lysimeter_application) then
        if (.not. ieee_is_finite(effective_forcing(i)%bottom_head) .or. effective_forcing(i)%bottom_flux /= 0.0_real64) then
          status = FMR_APP_BOOT_INVALID_CONFIG
          return
        end if
        if (allocated(effective_forcing(i)%legacy_swbotb5_control) .or. &
            allocated(effective_forcing(i)%legacy_swbotb3_implicit_control)) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
      else if (allocated(effective_forcing(i)%legacy_swbotb5_control) .or. &
               allocated(effective_forcing(i)%legacy_swbotb3_implicit_control)) then
        status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
        return
      end if
    end do

    if (self%execution_plan%ready()) then
      call fmr_run_serialized_physical_multiswap(self%columns, self%templates, self%parameters, effective_forcing, &
           self%committed, self%numerical, self%top_boundary, t0, t1, size(self%columns), results, diagnostics, &
           aggregate, dispatch_status, execution_plan=self%execution_plan, materialize_worker_assignments=.false., &
           materialize_summary_diagnostics=.false., materialize_diagnostic_metadata=.false., &
           materialize_column_diagnostics=.false., trusted_prepared_parameters=.true., &
           base_salt_temporal_policy=self%base_salt_temporal_policy)
    else
      call fmr_run_serialized_physical_multiswap(self%columns, self%templates, self%parameters, effective_forcing, &
           self%committed, self%numerical, self%top_boundary, t0, t1, size(self%columns), results, diagnostics, &
           aggregate, dispatch_status, materialize_worker_assignments=.false., &
           materialize_summary_diagnostics=.false., materialize_diagnostic_metadata=.false., &
           materialize_column_diagnostics=.false., trusted_prepared_parameters=.true., &
           base_salt_temporal_policy=self%base_salt_temporal_policy)
    end if

    status = FMR_APP_BOOT_RUNTIME_FAILED
    if (dispatch_status /= FMR_SERIAL_DISPATCH_OK) return
    if (.not. allocated(results)) return
    if (size(results) /= size(self%columns)) return
    if (.not. all(results%completed)) return
    if (.not. all(results%committed)) return
    status = FMR_APP_BOOT_OK
  end subroutine production_application_run_standalone_with_forcing

  subroutine production_application_materialize_groundwater_context(self, topology, predictors, cell_areas, &
       context_handle, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(groundwater_topology_t), intent(in) :: topology
    type(groundwater_tile_predictor_input_t), intent(in) :: predictors(:)
    type(groundwater_cell_area_input_t), intent(in) :: cell_areas(:)
    integer(int64), intent(out) :: context_handle
    integer, intent(out) :: status

    type(groundwater_topology_cell_t), allocatable :: authority_cells(:)
    integer :: local_status

    context_handle = 0_int64
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return

    status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if (.not. production_application_groundwater_ready(self)) return

    ! Fixed-interface closeout application authority:
    ! * native MODFLOW STO is head-state capacitance, not an independently
    !   additive physical storage reservoir in the accepted water balance;
    ! * active physical drainage is outside this admitted application profile.
    ! Research topologies may carry other or unresolved labels, but production
    ! materialization fails closed on them.
    call topology%copy_cells(authority_cells, local_status)
    if (local_status /= GW_TOPOLOGY_OK .or. .not. allocated(authority_cells)) return
    if (size(authority_cells) <= 0) return
    if (any(authority_cells%storage_state_role /= GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE)) return
    if (any(authority_cells%drainage_owner /= GW_DRAINAGE_OWNER_NONE)) return

    if (associated(self%active_context)) then
      call retire_active_context(self, local_status)
      if (local_status /= FMR_APP_BOOT_OK) then
        status = local_status
        return
      end if
    end if

    allocate(self%active_plan)
    call materialize_groundwater_application_plan(topology, predictors, cell_areas, self%active_plan, local_status)
    if (local_status /= GW_APP_PLAN_OK .or. .not. self%active_plan%ready()) then
      status = FMR_APP_BOOT_PLAN_FAILED
      deallocate(self%active_plan)
      nullify(self%active_plan)
      return
    end if

    allocate(self%active_context)
    if (self%groundwater_parallel_workers > 1) then
      if (.not. associated(self%groundwater_worker_backends)) then
        status = FMR_APP_BOOT_CONTEXT_FAILED
        deallocate(self%active_context)
        deallocate(self%active_plan)
        nullify(self%active_context)
        nullify(self%active_plan)
        return
      end if
      call self%active_context%bind(self%active_plan, self%registry, self%participant_handles, self%ledgers, local_status, &
           worker_backends=self%groundwater_worker_backends, worker_count=self%groundwater_parallel_workers)
    else
      call self%active_context%bind(self%active_plan, self%registry, self%participant_handles, self%ledgers, local_status)
    end if
    if (local_status /= FMR_GW_APP_CONTEXT_OK .or. .not. self%active_context%ready()) then
      status = FMR_APP_BOOT_CONTEXT_FAILED
      deallocate(self%active_context)
      deallocate(self%active_plan)
      nullify(self%active_context)
      nullify(self%active_plan)
      return
    end if

    call register_fmr_groundwater_application_context(self%active_context, self%active_context_handle, local_status)
    if (local_status /= FMR_GW_APP_C_API_OK .or. self%active_context_handle <= 0_int64) then
      status = FMR_APP_BOOT_CONTEXT_FAILED
      deallocate(self%active_context)
      deallocate(self%active_plan)
      nullify(self%active_context)
      nullify(self%active_plan)
      self%active_context_handle = 0_int64
      return
    end if

    context_handle = self%active_context_handle
    status = FMR_APP_BOOT_OK
  end subroutine production_application_materialize_groundwater_context

  subroutine production_application_release_groundwater_context(self, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    integer, intent(out) :: status

    if (.not. self%ready()) then
      status = FMR_APP_BOOT_NOT_READY
      return
    end if
    if (.not. production_application_groundwater_ready(self)) then
      status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      return
    end if
    call retire_active_context(self, status)
  end subroutine production_application_release_groundwater_context

  subroutine production_application_copy_committed_revisions(self, revisions, status)
    class(fmr_production_application_bootstrap_t), intent(in) :: self
    integer(int64), allocatable, intent(out) :: revisions(:)
    integer, intent(out) :: status
    integer :: i

    if (allocated(revisions)) deallocate(revisions)
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return
    allocate(revisions(size(self%committed)))
    do i = 1, size(self%committed)
      revisions(i) = self%committed(i)%current_revision()
    end do
    status = FMR_APP_BOOT_OK
  end subroutine production_application_copy_committed_revisions

  subroutine production_application_parallel_schedule_diagnostics(self, schedule_code, &
       static_ratio, selected_ratio, available, status)
    class(fmr_production_application_bootstrap_t), intent(in) :: self
    integer, intent(out) :: schedule_code
    real(real64), intent(out) :: static_ratio, selected_ratio
    logical, intent(out) :: available
    integer, intent(out) :: status

    schedule_code = 0
    static_ratio = 1.0_real64
    selected_ratio = 1.0_real64
    available = .false.
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return
    if (.not. associated(self%active_context)) then
      status = FMR_APP_BOOT_CONTEXT_FAILED
      return
    end if
    call self%active_context%parallel_schedule_diagnostics(schedule_code, static_ratio, selected_ratio, available)
    if (.not. available) then
      status = FMR_APP_BOOT_CONTEXT_FAILED
      return
    end if
    status = FMR_APP_BOOT_OK
  end subroutine production_application_parallel_schedule_diagnostics

  subroutine production_application_close(self, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    integer, intent(out) :: status

    integer :: i, local_status

    status = FMR_APP_BOOT_OK
    if (.not. self%initialized) then
      call discard_owner_storage(self)
      return
    end if

    if (associated(self%active_context)) then
      call retire_active_context(self, local_status)
      if (local_status /= FMR_APP_BOOT_OK) then
        status = local_status
        return
      end if
    end if

    if (associated(self%registry)) then
      if (.not. self%registry%quiescent()) then
        status = FMR_APP_BOOT_CONTEXT_BUSY
        return
      end if
      if (allocated(self%participant_handles)) then
        do i = 1, size(self%participant_handles)
          if (self%participant_handles(i) <= 0_int64) cycle
          call self%registry%release(self%participant_handles(i), local_status)
          if (local_status /= FMR_GW_REGISTRY_OK) then
            status = FMR_APP_BOOT_CONTEXT_BUSY
            return
          end if
        end do
      end if
    end if

    call discard_owner_storage(self)
    status = FMR_APP_BOOT_OK
  end subroutine production_application_close

  subroutine retire_active_context(self, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    integer, intent(out) :: status
    integer :: local_status

    status = FMR_APP_BOOT_OK
    if (.not. associated(self%active_context)) then
      self%active_context_handle = 0_int64
      if (associated(self%active_plan)) then
        deallocate(self%active_plan)
        nullify(self%active_plan)
      end if
      return
    end if

    if (self%active_context_handle > 0_int64) then
      call release_fmr_groundwater_application_context(self%active_context_handle, local_status)
      if (local_status == FMR_GW_APP_C_API_CONTEXT_BUSY) then
        status = FMR_APP_BOOT_CONTEXT_BUSY
        return
      end if
      if (local_status /= FMR_GW_APP_C_API_OK .and. local_status /= FMR_GW_APP_C_API_INVALID_CONTEXT) then
        status = FMR_APP_BOOT_CONTEXT_FAILED
        return
      end if
    end if

    deallocate(self%active_context)
    nullify(self%active_context)
    if (associated(self%active_plan)) then
      deallocate(self%active_plan)
      nullify(self%active_plan)
    end if
    self%active_context_handle = 0_int64
  end subroutine retire_active_context


  logical function int64_values_unique(values) result(unique)
    integer(int64), intent(in) :: values(:)
    integer(int64), allocatable :: sorted(:), workspace(:)
    integer :: n, width, left, middle, right, i, j, k

    unique = .true.
    n = size(values)
    if (n <= 1) return

    allocate(sorted(n), workspace(n))
    sorted = values
    width = 1
    do while (width < n)
      left = 1
      do while (left <= n)
        middle = min(left + width - 1, n)
        right = min(left + 2*width - 1, n)
        i = left
        j = middle + 1
        k = left
        do while (i <= middle .and. j <= right)
          if (sorted(i) <= sorted(j)) then
            workspace(k) = sorted(i)
            i = i + 1
          else
            workspace(k) = sorted(j)
            j = j + 1
          end if
          k = k + 1
        end do
        do while (i <= middle)
          workspace(k) = sorted(i)
          i = i + 1
          k = k + 1
        end do
        do while (j <= right)
          workspace(k) = sorted(j)
          j = j + 1
          k = k + 1
        end do
        left = left + 2*width
      end do
      sorted = workspace
      width = 2*width
    end do

    do i = 2, n
      if (sorted(i) == sorted(i-1)) then
        unique = .false.
        return
      end if
    end do
  end function int64_values_unique

  logical function file_weather_thermal_tile_valid(tile,rooted) result(valid)
    use mod_soil_temperature_contract, only: SOIL_TEMP_SOLUTION_NUMERIC, &
         SOIL_TEMP_TOP_AIR_TEMPERATURE, SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
    type(fmr_production_application_tile_config_t), intent(in) :: tile
    logical,intent(in),optional :: rooted
    logical :: allow_roots
    allow_roots=.false.
    if(present(rooted)) allow_roots=rooted
    valid=.false.
    if(tile%template%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE) return
    if(.not.tile%parameters%soil_temperature_active.or.tile%parameters%bottom_mode/=7) return
    if((tile%parameters%root_extraction_active.and..not.allow_roots).or. &
         tile%parameters%frost_active.or.tile%parameters%snow_active) return
    if(allocated(tile%parameters%bartholomeus)) return
    if(.not.allocated(tile%parameters%soil_temperature).or..not.allocated(tile%initial_state%soil_temperature).or. &
       .not.allocated(tile%base_forcing%soil_temperature)) return
    if(.not.tile%parameters%soil_temperature%ready().or..not.tile%initial_state%soil_temperature%ready()) return
    if(tile%parameters%soil_temperature%solution_mode/=SOIL_TEMP_SOLUTION_NUMERIC) return
    if(tile%base_forcing%soil_temperature%top_boundary_mode/=SOIL_TEMP_TOP_AIR_TEMPERATURE.or. &
       tile%base_forcing%soil_temperature%bottom_boundary_mode/=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX.or. &
       tile%base_forcing%soil_temperature%snow_water_storage_cm/=0.0_real64) return
    valid=.true.
  end function

  logical function file_weather_rooted_tile_valid(tile) result(valid)
    type(fmr_production_application_tile_config_t),intent(in)::tile
    valid=.false.
    if(.not.file_weather_thermal_tile_valid(tile,.true.)) return
    if(.not.tile%parameters%root_extraction_active.or.tile%parameters%root_compensation%method/=ROOT_COMP_OFF) return
    if(tile%parameters%root_salinity_active.or.tile%parameters%root_frost%active) return
    if(allocated(tile%parameters%bartholomeus).or.allocated(tile%parameters%micro_de_willigen)) return
    if(tile%parameters%macropore_active.or.tile%parameters%tabulated_hydraulics_active.or. &
         tile%parameters%direct_retention_active.or.tile%parameters%hysteresis_active.or.tile%parameters%elasticity_active) return
    valid=.true.
  end function

  logical function tile_config_valid(tile, ntiles, slot, file_weather,rooted_weather,explicit_interception) result(valid)
    type(fmr_production_application_tile_config_t), intent(in) :: tile
    integer, intent(in) :: ntiles, slot
    logical, intent(in) :: file_weather,rooted_weather,explicit_interception

    valid = .false.
    if (tile%tile_id <= 0_int64) return
    if (slot <= 0 .or. slot > ntiles) return
    if (tile%template%template_id <= 0_int64) return
    if (tile%template%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE) return
    if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE .and. &
        tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE .and. &
        tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION .and. &
        tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION .and. &
        tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_RUTTER) return
    if (tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE .and. &
        tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY) return
    if (tile%parameters%parameter_set_id <= 0_int64) return
    if (tile%parameters%active_nodes <= 0) return
    if (tile%parameters%bottom_mode /= 5 .and. tile%parameters%bottom_mode /= 7 .and. &
        tile%parameters%bottom_mode /= 2 .and. tile%parameters%bottom_mode /= 3 .and. tile%parameters%bottom_mode /= 8.and. &
        .not.(tile%parameters%bottom_mode==1.and.tile%parameters%prescribed_groundwater_active)) return
    if (allocated(tile%parameters%micro_de_willigen)) then
      if (allocated(tile%parameters%micro_horizon_first_node)) then
        if (.not. fmr_micro_horizon_map_valid(tile%parameters%micro_horizon_first_node, &
            tile%parameters%active_nodes)) return
      end if
      if (.not. tile%parameters%root_extraction_active) return
      if (tile%parameters%bottom_mode /= 2 .and. tile%parameters%bottom_mode /= 7) return
      if (tile%parameters%root_compensation%method /= ROOT_COMP_OFF .or. tile%parameters%root_salinity_active .or. &
          tile%parameters%root_frost%active .or. allocated(tile%parameters%bartholomeus)) return
      if (tile%parameters%micro_de_willigen%oxygen_mode /= 0) return
      if (tile%parameters%elasticity_active .or. tile%parameters%direct_retention_active .or. &
          tile%parameters%ksatexm_extension_active .or. tile%parameters%frost_active .or. &
          tile%parameters%soil_temperature_active .or. tile%parameters%snow_active .or. &
          tile%parameters%black_evaporation_active .or. tile%parameters%boesten_evaporation_active) return
      if (.not. allocated(tile%base_forcing%micro_root_length_density)) return
      if (tile%base_forcing%micro_rooted_nodes < 0 .or. &
          tile%base_forcing%micro_rooted_nodes > tile%parameters%active_nodes) return
      if (size(tile%base_forcing%micro_root_length_density) /= tile%parameters%active_nodes) return
      if (any(.not. ieee_is_finite(tile%base_forcing%micro_root_length_density))) return
      if (any(tile%base_forcing%micro_root_length_density < 0.0_real64)) return
      if (.not. allocated(tile%base_forcing%root_extraction_sink)) return
      if (any(tile%base_forcing%root_extraction_sink /= 0.0_real64)) return
    else
      if (allocated(tile%parameters%micro_horizon_first_node)) return
      if (allocated(tile%base_forcing%micro_root_length_density) .or. &
          tile%base_forcing%micro_rooted_nodes /= 0) return
    end if

    select case (tile%template%solute_state_layout_id)
    case (FMR_SOLUTE_STATE_LAYOUT_NONE)
      if (allocated(tile%initial_state%salt) .or. tile%parameters%root_salinity_active.or. &
          allocated(tile%parameters%mobile_dispersion)) return
    case (FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED)
      if (tile%template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RUTTER) return
      if (tile%parameters%bottom_mode /= 2 .and. tile%parameters%bottom_mode /= 7) return
      if (tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
      if (tile%parameters%black_evaporation_active .or. tile%parameters%boesten_evaporation_active .or. &
          tile%parameters%elasticity_active .or. tile%parameters%direct_retention_active) return
      if(allocated(tile%parameters%mobile_dispersion))then
        if(.not.fmr_mobile_dispersion_matches_hydraulic_owner(tile%parameters))return
      end if
      if (.not. allocated(tile%initial_state%salt)) return
      if (.not. tile%initial_state%salt%ready(tile%parameters%active_nodes)) return
      if (.not. allocated(tile%base_forcing%c_drain_salt) .or. &
          .not. allocated(tile%base_forcing%soil_salt_boundary)) return
    case default
      return
    end select

    ! WU01 established the no-new-physics production owner. PPA-WU02-A only
    ! widens normal application reachability to the already admitted typed
    ! prescribed-qbot mode 2; process composition remains fail-closed here.
    if (tile%parameters%macropore_active .or. tile%parameters%snow_active .or. &
        tile%parameters%hysteresis_active .or. &
        (tile%parameters%frost_active.and..not.tile%parameters%root_frost%active.and..not.tile%parameters%frost_bottom%active.and..not.tile%parameters%frost_drainage%active) .or. &
        (tile%parameters%drainage_response_active.and..not.tile%parameters%frost_response_drainage_active) .or. &
        tile%parameters%tabulated_hydraulics_active) return
    ! The original bare-soil admission remains exact when the new carrier is
    ! absent. Only the source-bound standalone root/thermal slice is widened.
    if(allocated(tile%parameters%bartholomeus)) then
      if(tile%parameters%bottom_mode/=2 .and. tile%parameters%bottom_mode/=7) return
      if(.not.tile%parameters%root_extraction_active) return
      if(tile%parameters%elasticity_active .or. tile%parameters%direct_retention_active) return
      if(tile%parameters%black_evaporation_active .or. tile%parameters%boesten_evaporation_active) return
    else
      if(tile%parameters%soil_temperature_active.and..not.tile%parameters%root_frost%active.and. &
           .not.tile%parameters%frost_bottom%active.and..not.tile%parameters%frost_drainage%active) then
        if(.not.file_weather.or..not.file_weather_thermal_tile_valid(tile,rooted_weather)) return
      end if
      if(tile%parameters%root_extraction_active) then
        if (allocated(tile%parameters%micro_de_willigen)) then
          if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE) return
        else if (tile%template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RUTTER) then
          if (tile%parameters%root_compensation%method /= ROOT_COMP_OFF) return
        else if (explicit_interception.and.explicit_pmdirect_tile_valid(tile)) then
          ! Explicit frozen Feddes input; incumbent profiles below are unchanged.
        else
          if(tile%parameters%root_compensation%method/=ROOT_COMP_JARVIS.and. &
             tile%parameters%root_compensation%method/=ROOT_COMP_WALSUM.and. &
             .not.tile%parameters%root_frost%active.and. &
             .not.(rooted_weather.and.file_weather.and.file_weather_rooted_tile_valid(tile))) return
        end if
        if(tile%parameters%bottom_mode/=2.and.tile%parameters%bottom_mode/=7) return
        if(tile%parameters%elasticity_active.or.tile%parameters%direct_retention_active) return
        if(tile%parameters%black_evaporation_active.or.tile%parameters%boesten_evaporation_active) return
      end if
      if(allocated(tile%base_forcing%crop_oxygen)) return
    end if

    if(.not.fmr_frost_response_drainage_configuration_valid(tile%parameters))return
    if(.not.fmr_frost_divdra_configuration_valid(tile%parameters))return
    if(.not.fmr_frost_divdra_forcing_valid(tile%parameters%frost_divdra_active,tile%base_forcing))return
    if(.not.fmr_frost_divdra_pair_valid(tile%parameters,tile%base_forcing))return
    if(tile%parameters%frost_low_air_drainage%active)then
      if(.not.tile%parameters%frost_low_air_drainage%valid().or..not.tile%parameters%frost_drainage%active)return
      if(tile%parameters%frost_low_air_response_drainage_active)then
        if(.not.allocated(tile%parameters%drainage_response_levels))return
        if(size(tile%parameters%frost_low_air_drainage%drain_depth_cm)/= &
             size(tile%parameters%drainage_response_levels))return
      else
        if(.not.allocated(tile%base_forcing%drainage_flux_by_level))return
        if(size(tile%parameters%frost_low_air_drainage%drain_depth_cm)/= &
             size(tile%base_forcing%drainage_flux_by_level,1))return
      end if
    end if
    if(tile%parameters%frost_drainage%active)then
      if(.not.tile%parameters%frost_drainage%valid())return
      if(.not.tile%parameters%frost_active.or..not.tile%parameters%soil_temperature_active)return
      if(tile%parameters%frost_bottom%active.or.tile%parameters%root_extraction_active.or. &
           tile%parameters%root_frost%active.or. &
           (tile%parameters%drainage_response_active.and..not.tile%parameters%frost_response_drainage_active))return
      if(tile%parameters%root_salinity_active.or.allocated(tile%initial_state%salt))return
      if(allocated(tile%parameters%bartholomeus).or.allocated(tile%base_forcing%crop_oxygen))return
      if(tile%parameters%elasticity_active.or.tile%parameters%direct_retention_active)return
      if(tile%parameters%bottom_mode/=2)return
      if(tile%template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_NONE)return
    end if
    if(tile%parameters%frost_bottom%active)then
      if(.not.tile%parameters%frost_bottom%valid())return
      if(.not.tile%parameters%frost_active.or..not.tile%parameters%soil_temperature_active)return
      if(tile%parameters%root_extraction_active.neqv.tile%parameters%root_frost%active)return
      if(tile%parameters%root_salinity_active.or.allocated(tile%initial_state%salt))return
      if(allocated(tile%parameters%bartholomeus).or.allocated(tile%base_forcing%crop_oxygen))return
      if(tile%parameters%elasticity_active.or.tile%parameters%direct_retention_active)return
      if(tile%parameters%bottom_mode/=2)return
      if(tile%template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_NONE)return
    end if

    if(tile%parameters%root_frost%active) then
      if(tile%parameters%root_salinity_active.or.allocated(tile%initial_state%salt)) then
        if(.not.tile%parameters%root_salinity_active.or..not.allocated(tile%initial_state%salt)) return
        if(tile%template%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED) return
        if(tile%parameters%frost_bottom%active.or.tile%parameters%frost_drainage%active) return
        if(tile%parameters%root_compensation%method/=ROOT_COMP_JARVIS.and. &
             tile%parameters%root_compensation%method/=ROOT_COMP_WALSUM) return
      end if
      if(.not.tile%parameters%frost_active.or..not.tile%parameters%root_extraction_active.or. &
           .not.tile%parameters%soil_temperature_active) return
      if(tile%parameters%bottom_mode/=2) return
      if(.not.tile%parameters%frost_bottom%active.and.tile%base_forcing%bottom_flux/=0.0_real64) return
      if(allocated(tile%parameters%bartholomeus).or.allocated(tile%base_forcing%crop_oxygen)) return
      if(tile%template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_NONE) return
      if(tile%parameters%root_frost%rooted_nodes<0.or. &
           tile%parameters%root_frost%rooted_nodes>tile%parameters%active_nodes) return
      if(.not.ieee_is_finite(tile%parameters%root_frost_head_budget_cm).or. &
           .not.ieee_is_finite(tile%parameters%root_frost_temperature_budget_c)) return
      if(tile%parameters%root_frost_head_budget_cm<=0.0_real64.or. &
           tile%parameters%root_frost_temperature_budget_c<=0.0_real64) return
      if(tile%parameters%root_compensation%method/=ROOT_COMP_OFF.and. &
           tile%parameters%root_compensation%method/=ROOT_COMP_JARVIS.and. &
           tile%parameters%root_compensation%method/=ROOT_COMP_WALSUM) return
    end if

    if (tile%parameters%black_evaporation_active) then
      if (tile%parameters%boesten_evaporation_active) return
      if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION) return
      if (tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
      if (.not. allocated(tile%parameters%black_evaporation) .or. allocated(tile%parameters%boesten_evaporation)) return
      if (.not. ieee_is_finite(tile%parameters%black_evaporation%cofred) .or. &
          tile%parameters%black_evaporation%cofred < 0.0_real64) return
      if (.not. ieee_is_finite(tile%initial_black_ldwet) .or. tile%initial_black_ldwet < 0.0_real64) return
      if (tile%initial_boesten_spev /= 0.0_real64 .or. tile%initial_boesten_saev /= 0.0_real64) return
      if (tile%parameters%bottom_mode == 5) return
    else if (tile%parameters%boesten_evaporation_active) then
      if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION) return
      if (tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
      if (allocated(tile%parameters%black_evaporation) .or. .not. allocated(tile%parameters%boesten_evaporation)) return
      if (.not. ieee_is_finite(tile%parameters%boesten_evaporation%cofred) .or. &
          tile%parameters%boesten_evaporation%cofred <= 0.0_real64 .or. &
          tile%parameters%boesten_evaporation%cofred > 1.0_real64) return
      if (.not. ieee_is_finite(tile%initial_boesten_spev) .or. tile%initial_boesten_spev < 0.0_real64) return
      if (.not. ieee_is_finite(tile%initial_boesten_saev) .or. tile%initial_boesten_saev < 0.0_real64) return
      if (tile%initial_black_ldwet /= 0.0_real64) return
      if (tile%parameters%bottom_mode == 5) return
    else
      if(tile%parameters%soil_temperature_active) then
        if(tile%template%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE) return
      else if(tile%template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RUTTER) then
        if (allocated(tile%parameters%bartholomeus) .or. &
            tile%parameters%root_compensation%method /= ROOT_COMP_OFF .or. &
            tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
      else
        if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE) return
      end if
      if (allocated(tile%parameters%black_evaporation) .or. allocated(tile%parameters%boesten_evaporation)) return
      if (tile%initial_black_ldwet /= 0.0_real64 .or. tile%initial_boesten_spev /= 0.0_real64 .or. &
          tile%initial_boesten_saev /= 0.0_real64) return
    end if
    if (tile%template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RUTTER) then
      if (.not. ieee_is_finite(tile%initial_rutter_canopy_storage_cm) .or. &
          tile%initial_rutter_canopy_storage_cm < 0.0_real64) return
    else if (tile%initial_rutter_canopy_storage_cm /= 0.0_real64) then
      return
    end if

    if (.not. allocated(tile%parameters%z) .or. .not. allocated(tile%parameters%dz) .or. &
        .not. allocated(tile%parameters%node_distance) .or. .not. allocated(tile%parameters%cofgen)) return
    if (size(tile%parameters%z) /= tile%parameters%active_nodes .or. &
        size(tile%parameters%dz) /= tile%parameters%active_nodes .or. &
        size(tile%parameters%node_distance) /= tile%parameters%active_nodes .or. &
        size(tile%parameters%cofgen, 2) /= tile%parameters%active_nodes) return

    if (tile%parameters%elasticity_active) then
      if (size(tile%parameters%cofgen, 1) < 24) return
      if (tile%parameters%ksatexm_extension_active .or. tile%parameters%direct_retention_active .or. &
          tile%parameters%tabulated_hydraulics_active .or. tile%parameters%hysteresis_active) return
      if (any(.not. ieee_is_finite(tile%parameters%cofgen(24,:)))) return
      if (any(tile%parameters%cofgen(24,:) < 0.0_real64)) return
    end if

    if (tile%initial_state%active_nodes /= tile%parameters%active_nodes) return
    if (.not. allocated(tile%initial_state%pressure_head) .or. .not. allocated(tile%initial_state%water_content)) return
    if (size(tile%initial_state%pressure_head) /= tile%parameters%active_nodes .or. &
        size(tile%initial_state%water_content) /= tile%parameters%active_nodes) return
    if (tile%ordinary_prescribed_head .and. (tile%ordinary_implicit_cauchy .or. tile%ordinary_explicit_cauchy)) return
    if (tile%ordinary_implicit_cauchy .and. tile%ordinary_explicit_cauchy) return
    if (tile%ordinary_lysimeter_plate .and. (tile%ordinary_prescribed_head .or. tile%ordinary_implicit_cauchy .or. &
        tile%ordinary_explicit_cauchy)) return
    if (tile%ordinary_lysimeter_plate) then
      if (tile%parameters%bottom_mode /= 8 .or. tile%parameters%swkimpl /= 0 .or. tile%parameters%swsophy /= 0) return
      if (.not. ieee_is_finite(tile%base_forcing%bottom_head)) return
      if (tile%base_forcing%bottom_flux /= 0.0_real64) return
      if (allocated(tile%base_forcing%legacy_swbotb5_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb3_implicit_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb2_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb4_qgwl_control)) return
      if (tile%ledger_id /= 0_int64 .or. tile%groundwater_datum%available) return
      if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE) return
      if (tile%parameters%direct_retention_active .or. tile%parameters%ksatexm_extension_active .or. &
          tile%parameters%elasticity_active .or. tile%parameters%black_evaporation_active .or. &
          tile%parameters%boesten_evaporation_active) return
      if (tile%parameters%active_nodes > 1) then
        if (any(tile%parameters%cofgen(:,2:tile%parameters%active_nodes) /= &
             spread(tile%parameters%cofgen(:,1),2,tile%parameters%active_nodes-1))) return
      end if
    end if
    if (tile%ordinary_prescribed_head) then
      if (tile%parameters%bottom_mode /= 5) return
      if (.not. allocated(tile%base_forcing%legacy_swbotb5_control)) return
      if (.not. tile%base_forcing%legacy_swbotb5_control%ready()) return
      if (allocated(tile%base_forcing%legacy_swbotb3_implicit_control)) return
      if (tile%ledger_id /= 0_int64 .or. tile%groundwater_datum%available) return
      if (tile%parameters%direct_retention_active) return
      if (allocated(tile%base_forcing%legacy_swbotb2_control) .or. &
          allocated(tile%base_forcing%legacy_swbotb4_qgwl_control)) return
    else if (tile%ordinary_explicit_cauchy) then
      if (tile%parameters%bottom_mode /= 3 .or. tile%parameters%swkimpl /= 0 .or. tile%parameters%swsophy /= 0) return
      if (.not. tile%parameters%swbotb3_explicit_active .or. .not. tile%parameters%profile_groundwater_projection) return
      if (.not. ieee_is_finite(tile%parameters%swbotb3_explicit_hdrain_cm) .or. &
          .not. ieee_is_finite(tile%parameters%swbotb3_explicit_shape_3)) return
      if (tile%parameters%swbotb3_explicit_shape_3 < 0.0_real64 .or. tile%parameters%swbotb3_explicit_shape_3 > 1.0_real64) return
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
    self%explicit_pmdirect_interception=.false.
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
    self%irrigation=fmr_allocated_irrigation_state_t();self%irrigation_selection_day=-1
    self%irrigation_time=0.0_real64;self%irrigation_delivered_cm=0.0_real64
    self%weather_window=fmr_wofost_accepted_window_t()
    self%previous_weather_window=fmr_wofost_accepted_window_t()
  end subroutine discard_owner_storage

end module mod_fmr_production_application_bootstrap

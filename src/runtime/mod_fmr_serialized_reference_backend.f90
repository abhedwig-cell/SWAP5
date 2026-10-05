module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_EXTERNAL_FULL_HALF, &
       TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fkt_temporal_indicator_history, only: fkt_temporal_indicator_history_t
  use mod_ppa_wu05_perch19_reduction_controller, only: macropore_reduction_continuation_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
       kernel_checkpoint_t, kernel_executor_t, kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t, &
       kernel_reference_floor_result_t, kernel_reference_floor_candidate_t, &
       KERNEL_STATUS_NOT_ADMITTED, KERNEL_REFERENCE_FLOOR_STATUS_NOT_ADMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_trial_from_checkpoint, fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_mode7_temporal_head_envelope, only: fmr_mode7_head_envelope_assessment_t, &
       assess_fmr_mode7_temporal_head_envelope, FMR_MODE7_HEAD_ENVELOPE_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION, &
       FMR_OPTIONAL_STATE_LAYOUT_SNOW, FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE, &
       fmr_optional_state_layout_known
  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER, &
       FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION, &
       FMR_OPTIONAL_STATE_LAYOUT_MACROPORE, FMR_OPTIONAL_STATE_LAYOUT_RFM, &
       FMR_SOLUTE_STATE_LAYOUT_NONE, fmr_solute_state_layout_known
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t
  use mod_fmr_top_sensible_boundary_carrier, only: fmr_top_sensible_boundary_carrier_t, &
       fmr_top_sensible_boundary_candidate_t
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_solver_diagnostics_t, soil_water_top_boundary_result_t, top_boundary_provider_t, SW_SOLVE_CONVERGED, &
       soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_TEMPORAL_INDICATOR_NOT_RUN
  use mod_soil_water_accepted_step_direction_contract, only: soil_water_accepted_step_direction_request_t, &
       soil_water_accepted_step_direction_result_t, SW_STEP_DIRECTION_UNAVAILABLE
  use mod_accepted_trajectory_directional_sensitivity, only: accepted_trajectory_direction_t, trajectory_step_token_t, &
       configure_trajectory_direction, begin_or_continue_trajectory, build_trajectory_step_request, &
       stage_trajectory_step_result, accept_trajectory_step, finalize_trajectory_direction
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t, &
       publish_accepted_trajectory_direction
  use mod_reference_richards_accepted_step_directional_service, only: solve_with_accepted_step_direction
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX, FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_rossfast_solver_selection_binding, only: fmr_rossfast_solver_selection_binding_t, &
       FMR_ROSSFAST_BIND_INTERNAL_ERROR
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_RETRY_SCALE, ROSSFAST_D3R_MAX_FULL_INDEX, &
       rossfast_d3r_full_duration_for_index
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_direct_retention_core, only: acquire_b110_direct_retention_slot
  use mod_b110_direct_retention_provider, only: b110_direct_retention_provider_t, bind_b110_direct_retention_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_restricted_surface_evaporation, only: black_evaporation_parameters_t, black_evaporation_state_t, &
       black_evaporation_forcing_t, black_evaporation_result_t, evaluate_black_evaporation_reduction, &
       BLACK_EVAP_AVAILABLE, BLACK_EVAP_PONDING_CLASSIFICATION_CM, &
       boesten_evaporation_parameters_t, boesten_evaporation_state_t, boesten_evaporation_forcing_t, &
       boesten_evaporation_result_t, evaluate_boesten_evaporation_reduction, BOESTEN_EVAP_AVAILABLE, &
       BOESTEN_EVAP_PONDING_CLASSIFICATION_CM
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context
  use mod_snow_process, only: snow_parameters_t, snow_state_t, snow_forcing_t, snow_flux_result_t, &
       snow_mass_contribution_t, snow_diagnostics_t, evaluate_snow_reference_call, SNOW_OK
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
  use mod_b110_smooth_freatic_projection, only: b110_smooth_freatic_projection_diagnostics_t, &
       evaluate_b110_smooth_freatic_projection, B110_GWL_PROJECTION_OK
  use mod_soil_temperature_contract, only: soil_temperature_at_node, soil_temperature_field_view_t, &
       build_soil_temperature_field_view
  use mod_crop_bartholomeus_input, only: crop_bartholomeus_input_t, valid_crop_bartholomeus_input
  use mod_fmr_bartholomeus_contract, only: fmr_bartholomeus_parameters_t, valid_fmr_bartholomeus_parameters, &
       matches_bartholomeus_hydraulic_owner
  use mod_fmr_bartholomeus_activation, only: select_fmr_bartholomeus_route, FMR_BARTHOLOMEUS_ACTIVE, &
       FMR_BARTHOLOMEUS_DISABLED
  use mod_fmr_bartholomeus_execution, only: fmr_apply_bartholomeus_to_root_sink, FMR_BARTHOLOMEUS_EXEC_OK
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t
  use mod_root_uptake_compensation, only: root_compensation_config_t, root_compensation_diagnostics_t, &
       ROOT_COMP_OFF, ROOT_COMP_JARVIS, ROOT_COMP_WALSUM, root_walsum_geometry_t, ROOT_COMP_OK, attribute_root_stress_losses
  use mod_root_uptake_compensation_execution, only: apply_root_uptake_compensation, ROOT_COMP_EXEC_OK
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, fmr_drainage_response_diagnostics_t, &
       evaluate_fmr_drainage_response_bottom_lumped, fmr_drainage_response_configuration_status, &
       FMR_DRAIN_BIND_OK
  use mod_fmr_legacy_qgwl_bottom_boundary_provider, only: fmr_qgwl_bottom_boundary_config_t, &
       fmr_qgwl_bottom_boundary_result_t, fmr_evaluate_legacy_qgwl_bottom_boundary, FMR_QGWL_OK
  use mod_fmr_drainage_qbot_directional_binding, only: project_fmr_qbot_smooth_groundwater_level, &
       compose_fmr_qbot_drainage_sink_direction, FMR_QBOT_DRAIN_DIRECTION_OK
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, soil_temperature_parameters_t, &
       soil_temperature_numerical_config_t, soil_temperature_forcing_t, soil_temperature_state_t, &
       soil_temperature_workspace_t, soil_temperature_result_t, soil_temperature_diagnostics_t, &
       trial_restricted_soil_temperature, commit_soil_temperature_state
  use mod_restricted_fixed_weir_surface_water, only: fixed_weir_surface_water_parameters_t, &
       fixed_weir_surface_water_state_t, fixed_weir_surface_water_forcing_t, &
       fixed_weir_surface_water_numerical_config_t, fixed_weir_surface_water_result_t, &
       evaluate_restricted_fixed_weir_surface_water, validate_fixed_weir_surface_water_parameters, &
       FIXED_WEIR_AVAILABLE
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_rfm_physical_state, only: rfm_physical_state_t, copy_rfm_physical_state
  use mod_rfm_runtime_configuration, only: rfm_runtime_configuration_t
  use mod_rfm_surface_forcing, only: rfm_surface_forcing_t
  use mod_rfm_matrix_source_provider, only: rfm_matrix_source_provider_t, bind_rfm_matrix_source_provider
  use mod_rfm_live_trial_preparer, only: rfm_live_trial_prepare_result_t, prepare_rfm_live_trial

  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t
  use mod_fmr_macropore_top_input, only: fmr_macropore_top_input_forcing_t
  use mod_macropore_single_column_runtime, only: macropore_single_column_runtime_t, macropore_runtime_policy_t, &
       macropore_runtime_result_t, MACRO_RUNTIME_CONVERGED, MACRO_RUNTIME_RETRY
  use mod_fmr_legacy_head_bottom_boundary_provider, only: fmr_hbot5_control_t, fmr_hbot5_proposal_t, FMR_HBOT5_OK
  use mod_fmr_legacy_cauchy_bottom_boundary_provider, only: fmr_cauchy3_control_t, fmr_cauchy3_proposal_t, &
       FMR_CAUCHY3_OK
  implicit none
  private

  integer, parameter, public :: B110_SWBOTB2_OK = 0
  real(real64), parameter :: FMR_PRACTICAL_RICHARDS_A2C_TOL = 1.0e-8_real64
  real(real64), parameter :: FMR_REFERENCE_BALANCE_FLOOR_DEPTH_CM = 2.8e-16_real64
  integer, parameter, public :: B110_SWBOTB2_INVALID_CONTROL = 1
  integer, parameter, public :: B110_SWBOTB2_TIME_NOT_COVERED = 2

  integer, parameter, public :: B110_SWBOTB2_SINE = 1
  integer, parameter, public :: B110_SWBOTB2_TABLE = 2
  real(real64), parameter, public :: B110_SWBOTB2_DRY_HEAD_CM = -1.0e7_real64

  type, public :: b110_legacy_swbotb2_application_control_t
    private
    logical :: initialized = .false.
    integer :: sw2 = 0
    real(real64) :: canonical_origin_time = 0.0_real64
    real(real64) :: legacy_t1900_origin = 0.0_real64
    real(real64) :: sinave = 0.0_real64
    real(real64) :: sinamp = 0.0_real64
    real(real64) :: sinmax = 0.0_real64
    real(real64), allocatable :: calendar_year_start_t1900(:)
    real(real64), allocatable :: table_t1900(:)
    real(real64), allocatable :: table_qbot(:)
  contains
    procedure, public :: initialize_sine => b110_swbotb2_initialize_sine
    procedure, public :: initialize_table => b110_swbotb2_initialize_table
    procedure, public :: ready => b110_swbotb2_ready
    procedure, public :: evaluate => b110_swbotb2_evaluate
  end type b110_legacy_swbotb2_application_control_t


  type, public :: fmr_snow_runtime_state_t
    type(snow_state_t) :: process
    logical :: event_applied = .false.
    real(real64) :: event_t0 = 0.0_real64
  end type fmr_snow_runtime_state_t

  type, public :: fmr_mobile_salt_component_t
    real(real64), allocatable :: mass_mg_cm2(:)
    real(real64), allocatable :: macro_mass_mg_cm2(:,:)
    integer(int64) :: cdrain_source_id = 0_int64
    integer(int64) :: cdrain_revision = -1_int64
  contains
    procedure, public :: ready => fmr_mobile_salt_ready
  end type fmr_mobile_salt_component_t

  type, extends(canonical_state_t), public :: fmr_b110_physical_state_t
    integer :: active_nodes = 0
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
    real(real64) :: ponding_depth = 0.0_real64
    real(real64) :: groundwater_level = 0.0_real64
    type(fmr_snow_runtime_state_t), allocatable :: snow
    type(soil_temperature_state_t), allocatable :: soil_temperature
    type(macropore_continuation_state_t), allocatable :: macropore
    type(fmr_mobile_salt_component_t), allocatable :: salt
  contains
    procedure :: clone => fmr_b110_state_clone
  end type fmr_b110_physical_state_t

  type, extends(fmr_b110_physical_state_t), public :: fmr_b110_macropore_reduction_state_t
    type(macropore_reduction_continuation_t) :: reduction_continuation
  contains
    procedure :: clone => fmr_b110_macropore_reduction_state_clone
  end type fmr_b110_macropore_reduction_state_t

  type, extends(fmr_b110_physical_state_t), public :: fmr_b110_temporal_indicator_state_t
    private
    type(fkt_temporal_indicator_history_t) :: temporal_history
  contains
    procedure :: clone => fmr_b110_temporal_indicator_state_clone
    procedure, public :: temporal_history_available => fmr_b110_temporal_history_available
    procedure, public :: temporal_history_snapshot => fmr_b110_temporal_history_snapshot
  end type fmr_b110_temporal_indicator_state_t

  ! D7 physical optional-state family.  SWST exists only on feature-active
  ! columns; inactive B1.10 states retain their previous layout and footprint.
  type, extends(fmr_b110_physical_state_t), public :: fmr_b110_fixed_weir_surface_water_state_t
    type(fixed_weir_surface_water_state_t) :: surface_water
  contains
    procedure :: clone => fmr_b110_fixed_weir_surface_water_state_clone
  end type fmr_b110_fixed_weir_surface_water_state_t

  ! PPA-WU04-A option-discriminated process continuation family. LDWET is
  ! physical process continuation state, not a hydraulic field or worker scratch.
  type, extends(fmr_b110_physical_state_t), public :: fmr_b110_black_evaporation_state_t
    type(black_evaporation_state_t) :: black_evaporation
  contains
    procedure :: clone => fmr_b110_black_evaporation_state_clone
  end type fmr_b110_black_evaporation_state_t

  ! PPA-WU04-B keeps the Boesten-Stroosnijder continuation pair atomic and
  ! option-discriminated from both BASE and SWREDU=1 Black.
  type, extends(fmr_b110_physical_state_t), public :: fmr_b110_boesten_evaporation_state_t
    type(boesten_evaporation_state_t) :: boesten_evaporation
  contains
    procedure :: clone => fmr_b110_boesten_evaporation_state_clone
  end type fmr_b110_boesten_evaporation_state_t

  ! PPA-WU05-A20 dedicated RFM optional physical-state carrier.
  ! Carrier/checkpoint semantics are admitted separately from live execution.
  type, extends(fmr_b110_physical_state_t), public :: fmr_b110_rfm_state_t
    type(rfm_physical_state_t) :: rfm
  contains
    procedure :: clone => fmr_b110_rfm_state_clone
  end type fmr_b110_rfm_state_t

  type, extends(kernel_parameters_t), public :: fmr_b110_physical_parameters_t
    integer(int64) :: parameter_set_id = 0_int64
    integer :: active_nodes = 0
    real(real64), allocatable :: z(:)
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: node_distance(:)
    real(real64), allocatable :: cofgen(:,:)
    logical :: prepared_default_mvg_available = .false.
    type(b110_default_mvg_parameters_t) :: prepared_default_mvg
    integer :: bottom_mode = 7
    integer :: swkimpl = 0
    integer :: swkmean = 1
    integer :: swsophy = 0
    integer :: max_iterations = 8
    integer :: max_backtracking = 4
    real(real64) :: min_step_duration = 1.0e-6_real64
    real(real64) :: compartment_balance_tolerance = 1.0e-12_real64
    real(real64) :: total_balance_tolerance = 1.0e-12_real64
    real(real64) :: head_abs_tolerance = 1.0e-12_real64
    real(real64) :: head_rel_tolerance = 1.0e-12_real64
    real(real64) :: ponding_tolerance = 1.0e-12_real64
    logical :: practical_richards_a2c_active = .false.
    logical :: root_extraction_active = .false.
    type(root_compensation_config_t) :: root_compensation
    type(fmr_bartholomeus_parameters_t), allocatable :: bartholomeus
    logical :: macropore_active = .false.
    type(fmr_macropore_physical_config_t), allocatable :: macropore
    logical :: snow_active = .false.
    logical :: hysteresis_active = .false.
    logical :: tabulated_hydraulics_active = .false.
    logical :: direct_retention_active = .false.
    integer :: prepared_direct_retention_slot = 0
    ! F-SI39: explicit opt-in to the exact B1.11 near-saturated KSATEXM
    ! conductivity extension. Default false preserves all pre-F-SI39 routes.
    logical :: ksatexm_extension_active = .false.
    logical :: elasticity_active = .false.
    logical :: frost_active = .false.
    logical :: soil_temperature_active = .false.
    logical :: black_evaporation_active = .false.
    type(black_evaporation_parameters_t), allocatable :: black_evaporation
    logical :: boesten_evaporation_active = .false.
    type(boesten_evaporation_parameters_t), allocatable :: boesten_evaporation
    ! F-PM14 drainage response runtime composition. Immutable response and
    ! prepared geometry data belong to parameters, never to persistent state.
    logical :: drainage_response_active = .false.
    ! F-GC31 opt-in: for prescribed-qbot coupling only, derive the lagged
    ! drainage hydraulic-view GWL from the current substep-start pressure
    ! profile. Default false preserves every previously admitted PM14 route.
    logical :: drainage_qbot_smooth_freatic_projection = .false.
    type(fmr_drainage_response_level_parameters_t), allocatable :: drainage_response_levels(:)
    type(snow_parameters_t), allocatable :: snow
    type(soil_temperature_parameters_t), allocatable :: soil_temperature
  end type fmr_b110_physical_parameters_t

  type, public :: fmr_black_evaporation_runtime_forcing_t
    real(real64) :: precipitation_rate_cm_per_day = 0.0_real64
    real(real64) :: irrigation_rate_cm_per_day = 0.0_real64
    real(real64) :: snowmelt_rate_cm_per_day = 0.0_real64
    real(real64) :: runon_rate_cm_per_day = 0.0_real64
    real(real64) :: potential_bare_soil_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_pond_evaporation_cm_per_day = 0.0_real64
    real(real64) :: ponding_max_cm = 0.0_real64
    real(real64) :: runoff_resistance_day = 0.0_real64
    real(real64) :: runoff_exponent = 1.0_real64
    logical :: wetting_reset_event = .false.
    real(real64) :: wetting_event_time = 0.0_real64
  end type fmr_black_evaporation_runtime_forcing_t

  type, public :: fmr_boesten_evaporation_runtime_forcing_t
    real(real64) :: precipitation_rate_cm_per_day = 0.0_real64
    real(real64) :: irrigation_rate_cm_per_day = 0.0_real64
    real(real64) :: snowmelt_rate_cm_per_day = 0.0_real64
    real(real64) :: runon_rate_cm_per_day = 0.0_real64
    real(real64) :: potential_bare_soil_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_pond_evaporation_cm_per_day = 0.0_real64
    real(real64) :: ponding_max_cm = 0.0_real64
    real(real64) :: runoff_resistance_day = 0.0_real64
    real(real64) :: runoff_exponent = 1.0_real64
  end type fmr_boesten_evaporation_runtime_forcing_t

  integer, parameter, public :: FMR_C_DRAIN_UNIT_MG_CM3 = 1
  type, public :: fmr_c_drain_salt_forcing_t
    logical :: available = .false.
    real(real64) :: concentration_mg_cm3 = 0.0_real64
    real(real64) :: valid_t0 = 0.0_real64, valid_t1 = 0.0_real64
    integer(int64) :: source_id = 0_int64, revision = -1_int64
    integer :: unit_id = 0
  end type fmr_c_drain_salt_forcing_t

  type, extends(canonical_forcing_t), public :: fmr_b110_physical_forcing_t
    real(real64) :: top_flux = 0.0_real64
    real(real64) :: top_head = 0.0_real64
    real(real64) :: bottom_flux = 0.0_real64
    real(real64) :: bottom_head = 0.0_real64
    type(fmr_hbot5_control_t), allocatable :: legacy_swbotb5_control
    type(fmr_cauchy3_control_t), allocatable :: legacy_swbotb3_implicit_control
    type(b110_legacy_swbotb2_application_control_t), allocatable :: legacy_swbotb2_control
    type(fmr_qgwl_bottom_boundary_config_t), allocatable :: legacy_swbotb4_qgwl_control
    type(fmr_c_drain_salt_forcing_t), allocatable :: c_drain_salt
    real(real64), allocatable :: drainage_flux_by_level(:,:)
    type(fmr_drainage_response_level_control_t), allocatable :: drainage_response_controls(:)
    real(real64), allocatable :: subsurface_irrigation_source(:)
    real(real64), allocatable :: root_extraction_sink(:)
    real(real64) :: root_potential_transpiration = 0.0_real64
    real(real64) :: root_drought_reduction_total = 0.0_real64
    real(real64), allocatable :: root_potential_sink(:)
    type(root_walsum_geometry_t), allocatable :: root_walsum_geometry
    type(crop_bartholomeus_input_t), allocatable :: crop_oxygen
    type(snow_forcing_t), allocatable :: snow
    type(soil_temperature_forcing_t), allocatable :: soil_temperature
    type(fmr_black_evaporation_runtime_forcing_t), allocatable :: black_evaporation
    type(fmr_boesten_evaporation_runtime_forcing_t), allocatable :: boesten_evaporation
    type(fmr_macropore_top_input_forcing_t), allocatable :: macropore_top_input
    type(rfm_surface_forcing_t), allocatable :: rfm_surface
  end type fmr_b110_physical_forcing_t

  ! Read-only trial trace of one accepted Richards physical substep. It is
  ! worker observation data, never committed or restart state.
  type, public :: fmr_water_flux_substep_trace_t
    real(real64) :: t0 = 0.0_real64, t1 = 0.0_real64
    real(real64) :: top_flux = 0.0_real64, bottom_flux = 0.0_real64
    real(real64), allocatable :: water_start(:), water_end(:), subsurface_source(:), drainage_sink(:), drainage_sink_by_level(:,:), &
         root_sink(:), macropore_matrix_exchange(:), macropore_matrix_exchange_domain(:,:), &
         macropore_water_start(:,:), macropore_water_end(:,:), macropore_vertical_face_rate(:,:), net_node_source(:)
  end type fmr_water_flux_substep_trace_t

  type, public :: fmr_serialized_physical_observation_t
    logical :: bartholomeus_executed = .false.
    integer :: bartholomeus_status = 0
    real(real64) :: root_oxygen_base_uptake = 0.0_real64
    real(real64) :: root_oxygen_final_uptake = 0.0_real64
    real(real64), allocatable :: root_oxygen_final_sink(:)
    logical :: root_compensation_executed = .false.
    integer :: root_compensation_status = 0
    real(real64) :: root_compensation_base_uptake = 0.0_real64
    real(real64) :: root_compensation_final_uptake = 0.0_real64
    real(real64) :: root_compensation_drought_loss = 0.0_real64
    real(real64) :: root_compensation_oxygen_loss = 0.0_real64
    real(real64), allocatable :: root_compensation_final_sink(:)
    logical :: solver_executed = .false.
    logical :: accepted_water_flux_trace_available = .false.
    type(fmr_water_flux_substep_trace_t), allocatable :: accepted_water_flux_substeps(:)
    logical :: hbot5_proposal_available = .false.
    real(real64) :: hbot5_proposed_t0 = 0.0_real64, hbot5_proposed_t1 = 0.0_real64
    real(real64) :: hbot5_sample_t1900 = 0.0_real64, hbot5_pressure_head_cm = 0.0_real64
    logical :: cauchy3_proposal_available = .false.
    real(real64) :: cauchy3_proposed_t0 = 0.0_real64, cauchy3_proposed_t1 = 0.0_real64
    real(real64) :: cauchy3_head_sample_t1900 = 0.0_real64, cauchy3_sine_phase_day = 0.0_real64
    real(real64) :: cauchy3_aquifer_head_cm = 0.0_real64
    real(real64) :: cauchy3_q4_sample_t1900 = 0.0_real64, cauchy3_q4_cm_per_day = 0.0_real64
    integer :: solver_status = 0
    real(real64) :: top_flux = 0.0_real64
    real(real64) :: bottom_flux = 0.0_real64
    logical :: macropore_top_input_active = .false.
    real(real64) :: macropore_requested_top_cm = 0.0_real64
    real(real64) :: macropore_accepted_top_cm = 0.0_real64
    real(real64) :: macropore_returned_surface_cm = 0.0_real64
    logical :: macropore_rapid_drain_active = .false.
    real(real64) :: macropore_rapid_outflow_cm = 0.0_real64
    logical :: macropore_inner_richards_exchange_used = .false.
    real(real64) :: macropore_inner_initial_exchange_rate_cm_per_day = 0.0_real64
    real(real64) :: macropore_inner_final_exchange_rate_cm_per_day = 0.0_real64
    real(real64) :: solver_equation_residual = 0.0_real64
    logical :: solver_equation_residual_available = .false.
    type(soil_water_solver_diagnostics_t) :: solver_diagnostics
    logical :: practical_richards_a2c_active = .false.
    real(real64) :: practical_richards_head_abs_tolerance = 0.0_real64
    real(real64) :: practical_richards_head_rel_tolerance = 0.0_real64
    real(real64) :: practical_richards_compartment_balance_tolerance = 0.0_real64
    real(real64) :: practical_richards_total_balance_tolerance = 0.0_real64
    real(real64) :: effective_reference_compartment_balance_tolerance = 0.0_real64
    real(real64) :: effective_reference_total_balance_tolerance = 0.0_real64
    logical :: temporal_indicator_enabled = .false.
    logical :: temporal_previous_derivative_available = .false.
    logical :: temporal_current_derivative_available = .false.
    integer :: temporal_indicator_status = SW_TEMPORAL_INDICATOR_NOT_RUN
    logical :: temporal_indicator_available = .false.
    character(len=40) :: temporal_indicator_route = 'not-run'
    real(real64) :: temporal_head_inf_bound = 0.0_real64
    logical :: temporal_head_budget_supplied = .false.
    logical :: temporal_head_budget_valid = .false.
    real(real64) :: temporal_head_budget = 0.0_real64
    logical :: temporal_certificate_available = .false.
    real(real64) :: temporal_normalized_indicator = 0.0_real64
    character(len=48) :: temporal_certificate_unavailable_reason = 'not-evaluated'
    integer :: temporal_additional_tridiagonal_solves = 0
    integer :: temporal_additional_full_nonlinear_solves = 0
    logical :: snow_active = .false.
    logical :: snow_event_prepared = .false.
    integer :: snow_status = 0
    real(real64) :: snow_melt_rate = 0.0_real64
    type(snow_flux_result_t) :: snow_fluxes
    type(snow_mass_contribution_t) :: snow_mass
    logical :: soil_temperature_active = .false.
    logical :: soil_temperature_executed = .false.
    integer :: soil_temperature_status = 0
    logical :: soil_temperature_energy_accounting_complete = .false.
    real(real64) :: soil_temperature_energy_residual_j_cm2 = 0.0_real64
    real(real64) :: soil_temperature_top_heat_flux_j_cm2_day = 0.0_real64
    real(real64) :: soil_temperature_storage_change_j_cm2 = 0.0_real64
    real(real64) :: soil_temperature_boundary_energy_j_cm2 = 0.0_real64
    logical :: fixed_weir_surface_water_active = .false.
    integer :: fixed_weir_surface_water_status = 0
    real(real64) :: fixed_weir_surface_water_storage = 0.0_real64
    real(real64) :: fixed_weir_surface_water_level = 0.0_real64
    real(real64) :: fixed_weir_surface_water_supply_rate = 0.0_real64
    real(real64) :: fixed_weir_surface_water_discharge_rate = 0.0_real64
    real(real64) :: fixed_weir_surface_water_mass_residual = 0.0_real64
    real(real64) :: fixed_weir_surface_water_rating_residual = 0.0_real64
    integer :: fixed_weir_surface_water_iterations = 0
    character(len=32) :: fixed_weir_surface_water_route = 'not-run'
    logical :: drainage_response_active = .false.
    logical :: drainage_qbot_projection_active = .false.
    logical :: drainage_qbot_projection_available = .false.
    real(real64) :: drainage_projected_groundwater_level = 0.0_real64
    integer :: drainage_response_evaluations = 0
    logical :: drainage_response_mass_accounted_in_trial = .false.
    real(real64) :: drainage_response_signed_exchange_native = 0.0_real64
    logical :: drainage_response_window_exchange_available = .false.
    real(real64) :: drainage_response_window_signed_exchange_native = 0.0_real64
    type(fmr_drainage_response_diagnostics_t) :: drainage_response
    logical :: black_evaporation_active = .false.
    logical :: black_evaporation_evaluated = .false.
    logical :: black_wetting_reset_applied = .false.
    logical :: black_ponding_reset_applied = .false.
    real(real64) :: black_empirical_demand = 0.0_real64
    real(real64) :: black_candidate_ldwet = 0.0_real64
    logical :: boesten_evaporation_active = .false.
    logical :: boesten_evaporation_evaluated = .false.
    logical :: boesten_ponding_reset_applied = .false.
    real(real64) :: boesten_empirical_demand = 0.0_real64
    real(real64) :: boesten_candidate_spev = 0.0_real64
    real(real64) :: boesten_candidate_saev = 0.0_real64
  end type fmr_serialized_physical_observation_t

  ! Worker-local transactional scratch for thermal transfer provenance. This is
  ! attempt context, never compact committed column state.
  type, extends(transaction_attempt_context_t) :: fmr_serialized_attempt_context_t
    type(fmr_hbot5_proposal_t) :: hbot5_proposal
    type(fmr_cauchy3_proposal_t) :: cauchy3_proposal
    logical :: bottom_thermal_active = .false.
    logical :: bottom_thermal_valid = .true.
    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier
    logical :: top_sensible_boundary_active = .false.
    logical :: top_sensible_boundary_valid = .true.
    type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier
    logical :: drainage_response_window_exchange_available = .false.
    real(real64) :: drainage_response_window_signed_exchange_native = 0.0_real64
    type(accepted_trajectory_direction_t) :: trajectory_direction
    type(fmr_water_flux_substep_trace_t), allocatable :: accepted_water_flux_substeps(:)
    logical :: accepted_water_flux_trace_failed = .false.
  end type fmr_serialized_attempt_context_t

  type, extends(kernel_model_t) :: fmr_serialized_reference_model_t
    type(fmr_hbot5_control_t), allocatable :: legacy_swbotb5_control
    type(fmr_hbot5_proposal_t) :: hbot5_proposal
    type(fmr_cauchy3_control_t), allocatable :: legacy_swbotb3_implicit_control
    type(fmr_cauchy3_proposal_t) :: cauchy3_proposal
    type(soil_water_parameter_set_t), pointer :: soil_parameters => null()
    type(b110_default_mvg_parameters_t), pointer :: owned_hydraulic_parameters => null()
    type(b110_default_mvg_parameters_t), pointer :: hydraulic_parameters => null()
    type(fmr_b110_physical_parameters_t), pointer :: trusted_parameter_source => null()
    type(b110_default_mvg_provider_t), pointer :: constitutive => null()
    type(b110_direct_retention_provider_t), pointer :: direct_retention_constitutive => null()
    logical :: direct_retention_active = .false.
    integer :: direct_retention_slot = 0
    type(b110_source_sink_provider_t), pointer :: source_sink => null()
    type(b110_root_sink_provider_t), pointer :: root_sink => null()
    class(top_boundary_provider_t), pointer :: top_boundary => null()
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(fmr_rossfast_solver_selection_binding_t) :: soil_water_selection
    real(real64), pointer :: qdra(:,:) => null()
    logical :: drainage_response_active = .false.
    logical :: drainage_qbot_smooth_freatic_projection = .false.
    type(fmr_drainage_response_level_parameters_t), allocatable :: drainage_response_levels(:)
    type(fmr_drainage_response_level_control_t), allocatable :: drainage_response_controls(:)
    type(fmr_drainage_response_diagnostics_t) :: drainage_response_diagnostics
    integer :: drainage_response_evaluations = 0
    logical :: drainage_response_window_exchange_available = .false.
    real(real64) :: drainage_response_window_signed_exchange_native = 0.0_real64
    real(real64), pointer :: qssdi(:) => null()
    real(real64), pointer :: qrot(:) => null()
    real(real64), pointer :: qrot_zero(:) => null()
    ! Disposable worker inputs/scratch, not accepted oxygen continuation state.
    real(real64), allocatable :: qrot_unmodified(:)
    type(root_compensation_config_t) :: root_compensation
    real(real64) :: root_potential_transpiration = 0.0_real64
    real(real64) :: root_drought_reduction_total = 0.0_real64
    real(real64), allocatable :: root_potential_sink(:)
    type(root_walsum_geometry_t), allocatable :: root_walsum_geometry
    type(fmr_bartholomeus_parameters_t), allocatable :: bartholomeus
    type(crop_bartholomeus_input_t), allocatable :: crop_oxygen
    real(real64), allocatable :: projection_zero_direction(:)
    integer :: bottom_mode = 7
    integer :: swkimpl = 0
    integer :: swkmean = 1
    integer :: max_iterations = 8
    integer :: max_backtracking = 4
    real(real64) :: min_step_duration = 1.0e-6_real64
    real(real64) :: compartment_balance_tolerance = 1.0e-12_real64
    real(real64) :: total_balance_tolerance = 1.0e-12_real64
    real(real64) :: head_abs_tolerance = 1.0e-12_real64
    real(real64) :: head_rel_tolerance = 1.0e-12_real64
    real(real64) :: ponding_tolerance = 1.0e-12_real64
    logical :: practical_richards_a2c_active = .false.
    real(real64) :: top_flux = 0.0_real64
    real(real64) :: base_top_flux = 0.0_real64
    real(real64) :: top_head = 0.0_real64
    real(real64) :: bottom_flux = 0.0_real64
    real(real64) :: bottom_head = 0.0_real64
    type(b110_legacy_swbotb2_application_control_t), allocatable :: legacy_swbotb2_control
    type(fmr_qgwl_bottom_boundary_config_t), allocatable :: legacy_swbotb4_qgwl_control
    logical :: forcing_admitted = .false.
    logical :: state_profile_admitted = .false.
    logical :: root_extraction_active = .false.
    logical :: macropore_active = .false.
    type(fmr_macropore_physical_config_t), allocatable :: macropore_config
    type(fmr_macropore_top_input_forcing_t) :: macropore_top_input_forcing
    type(macropore_runtime_policy_t) :: macropore_policy
    logical :: macropore_policy_configured = .false.
    type(macropore_single_column_runtime_t) :: macropore_runtime
    type(rfm_runtime_configuration_t) :: rfm_configuration
    type(rfm_surface_forcing_t) :: rfm_surface_forcing
    logical :: trusted_prepared_default_mvg = .false.
    logical :: temporal_indicator_history_enabled = .false.
    logical :: macropore_reduction_continuation_enabled = .false.
    logical :: temporal_indicator_budget_supplied = .false.
    logical :: temporal_indicator_budget_valid = .false.
    real(real64) :: temporal_indicator_budget = 0.0_real64
    logical :: trajectory_direction_requested = .false.
    logical :: trajectory_provenance_valid = .false.
    integer :: trajectory_worker_id = -1
    integer :: trajectory_control_coordinate = 0
    integer(int64) :: trajectory_generation_counter = 0_int64
    real(real64) :: trajectory_requested_t0 = 0.0_real64
    real(real64) :: trajectory_requested_t1 = 0.0_real64
    type(accepted_trajectory_direction_t) :: trajectory_direction
    type(soil_water_accepted_step_direction_request_t) :: trajectory_request_workspace
    logical :: snow_active = .false.
    logical :: snow_event_prepared = .false.
    real(real64) :: snow_outer_t0 = 0.0_real64
    real(real64) :: snow_outer_t1 = 0.0_real64
    real(real64) :: snow_melt_rate = 0.0_real64
    type(snow_state_t) :: snow_candidate
    type(snow_flux_result_t) :: snow_fluxes
    type(snow_diagnostics_t) :: snow_diagnostics
    logical :: soil_temperature_active = .false.
    logical :: black_evaporation_active = .false.
    type(black_evaporation_parameters_t) :: black_evaporation_parameters
    type(fmr_black_evaporation_runtime_forcing_t) :: black_evaporation_forcing
    logical :: boesten_evaporation_active = .false.
    type(boesten_evaporation_parameters_t) :: boesten_evaporation_parameters
    type(fmr_boesten_evaporation_runtime_forcing_t) :: boesten_evaporation_forcing
    type(soil_temperature_parameters_t), allocatable :: soil_temperature_parameters
    type(soil_temperature_forcing_t), allocatable :: soil_temperature_forcing
    type(soil_temperature_numerical_config_t) :: soil_temperature_numerical
    type(soil_temperature_workspace_t) :: soil_temperature_workspace
    logical :: fixed_weir_surface_water_active = .false.
    logical :: fixed_weir_surface_water_configured = .false.
    type(fixed_weir_surface_water_parameters_t) :: fixed_weir_surface_water_parameters
    type(fixed_weir_surface_water_forcing_t) :: fixed_weir_surface_water_forcing
    type(fixed_weir_surface_water_numerical_config_t) :: fixed_weir_surface_water_numerical
    type(fixed_weir_surface_water_result_t) :: fixed_weir_surface_water_result
    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier
    logical :: bottom_thermal_carrier_active = .false.
    logical :: bottom_thermal_carrier_valid = .true.
    type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier
    logical :: top_sensible_boundary_carrier_active = .false.
    logical :: top_sensible_boundary_carrier_valid = .true.
    type(fmr_serialized_physical_observation_t) :: last_observation
    logical :: accepted_water_flux_trace_enabled = .false.
    logical :: accepted_water_flux_trace_failed = .false.
    type(fmr_water_flux_substep_trace_t), allocatable :: accepted_water_flux_substeps(:)
  contains
    procedure :: configure_parameters => fmr_serialized_configure_parameters
    procedure :: execution_admitted => fmr_serialized_execution_admitted
    procedure :: prepare_interval => fmr_serialized_prepare_interval
    procedure :: advance => fmr_serialized_advance
    procedure :: storage => fmr_serialized_storage
    procedure :: storage_accounting_status => fmr_serialized_storage_accounting_status
    procedure :: temporal_error => fmr_serialized_temporal_identity
    procedure :: attempt_context_required => fmr_serialized_attempt_context_required
    procedure :: capture_attempt_context => fmr_serialized_capture_attempt_context
    procedure :: restore_attempt_context => fmr_serialized_restore_attempt_context
    procedure :: accepted_trajectory_direction_snapshot => fmr_serialized_accepted_trajectory_direction_snapshot
  end type fmr_serialized_reference_model_t

  type, public :: fmr_serialized_reference_backend_t
    private
    type(fmr_serialized_reference_model_t) :: model
    type(kernel_executor_t) :: kernel
    logical :: initialized = .false.
    logical :: bottom_thermal_requested = .false.
    type(fmr_bottom_thermal_candidate_t) :: bottom_thermal_candidate
    logical :: top_sensible_boundary_requested = .false.
    type(fmr_top_sensible_boundary_candidate_t) :: top_sensible_boundary_candidate
  contains
    procedure, public :: initialize => fmr_serialized_backend_initialize
    procedure, public :: configure_soil_water_model => fmr_serialized_backend_configure_soil_water_model
    procedure, public :: configure_macropore_policy => fmr_serialized_backend_configure_macropore_policy
    procedure, public :: configure_rfm_runtime => fmr_serialized_backend_configure_rfm_runtime
    procedure, public :: run_trial => fmr_serialized_backend_run_trial
    procedure, public :: run_reference_floor_sample => fmr_serialized_backend_run_reference_floor_sample
    procedure, public :: commit_reference_floor_candidate => fmr_serialized_backend_commit_reference_floor_candidate
    procedure, public :: discard_reference_floor_candidate => fmr_serialized_backend_discard_reference_floor_candidate
    procedure, public :: observation => fmr_serialized_backend_observation
    procedure, public :: set_bottom_thermal_carrier_enabled => fmr_serialized_backend_set_bottom_thermal_carrier_enabled
    procedure, public :: bottom_thermal_snapshot => fmr_serialized_backend_bottom_thermal_snapshot
    procedure, public :: set_top_sensible_boundary_enabled => fmr_serialized_backend_set_top_sensible_boundary_enabled
    procedure, public :: top_sensible_boundary_snapshot => fmr_serialized_backend_top_sensible_boundary_snapshot
    procedure, public :: configure_fixed_weir_surface_water => fmr_serialized_backend_configure_fixed_weir_surface_water
    procedure, public :: clear_fixed_weir_surface_water => fmr_serialized_backend_clear_fixed_weir_surface_water
    procedure, public :: commit_trial_candidate => fmr_serialized_backend_commit_trial_candidate
    procedure, public :: discard_trial_candidate => fmr_serialized_backend_discard_trial_candidate
  end type fmr_serialized_reference_backend_t

  public :: prepare_fmr_b110_default_mvg
  public :: fmr_c_drain_salt_covers_interval
  public :: fmr_c_drain_salt_matches_trial
  public :: fmr_new_b110_committed_state
  public :: fmr_new_b110_macropore_reduction_committed_state
  public :: fmr_new_b110_temporal_indicator_committed_state
  public :: fmr_new_b110_fixed_weir_surface_water_committed_state
  public :: fmr_new_b110_black_evaporation_committed_state
  public :: fmr_new_b110_boesten_evaporation_committed_state
  public :: fmr_new_b110_rfm_committed_state

contains

  pure logical function fmr_c_drain_salt_covers_interval(forcing, t0, t1) result(valid)
    type(fmr_c_drain_salt_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    valid = .false.
    if (.not. forcing%available) return
    if (forcing%unit_id /= FMR_C_DRAIN_UNIT_MG_CM3) return
    if (forcing%source_id <= 0_int64 .or. forcing%revision < 0_int64) return
    if (.not. ieee_is_finite(forcing%concentration_mg_cm3) .or. forcing%concentration_mg_cm3 < 0.0_real64) return
    if (.not. ieee_is_finite(forcing%valid_t0) .or. .not. ieee_is_finite(forcing%valid_t1)) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    valid = forcing%valid_t0 <= t0 .and. forcing%valid_t1 >= t1 .and. forcing%valid_t1 > forcing%valid_t0
  end function fmr_c_drain_salt_covers_interval

  pure logical function fmr_c_drain_salt_matches_trial(forcing, forcing_handle, t0, t1) result(valid)
    type(fmr_c_drain_salt_forcing_t), intent(in) :: forcing
    integer(int64), intent(in) :: forcing_handle
    real(real64), intent(in) :: t0, t1
    valid = .false.
    if (forcing_handle <= 0_int64 .or. forcing%source_id /= forcing_handle) return
    valid = fmr_c_drain_salt_covers_interval(forcing, t0, t1)
  end function fmr_c_drain_salt_matches_trial

  subroutine prepare_fmr_b110_default_mvg(parameters, prepared)
    type(fmr_b110_physical_parameters_t), intent(inout) :: parameters
    logical, intent(out) :: prepared
    integer :: i
    logical :: direct_hit

    prepared = .false.
    parameters%prepared_default_mvg_available = .false.
    parameters%prepared_default_mvg = b110_default_mvg_parameters_t()
    parameters%prepared_direct_retention_slot = 0

    if (parameters%active_nodes <= 0) return
    if (.not. allocated(parameters%cofgen)) return
    if (size(parameters%cofgen,1) < 24 .or. size(parameters%cofgen,2) /= parameters%active_nodes) return

    if (parameters%elasticity_active) then
      if (parameters%ksatexm_extension_active .or. parameters%direct_retention_active .or. &
          parameters%tabulated_hydraulics_active .or. parameters%hysteresis_active) return
      if (any(.not. ieee_is_finite(parameters%cofgen(24,:)))) return
      if (any(parameters%cofgen(24,:) < 0.0_real64)) return
    end if

    if (parameters%ksatexm_extension_active) then
      do i = 1, parameters%active_nodes
        if (parameters%cofgen(10,i) > parameters%cofgen(3,i)) then
          if (.not. ieee_is_finite(parameters%cofgen(10,i)) .or. parameters%cofgen(10,i) <= 0.0_real64) return
          if (.not. ieee_is_finite(parameters%cofgen(11,i)) .or. parameters%cofgen(11,i) < 0.0_real64 .or. &
              parameters%cofgen(11,i) >= 1.0_real64) return
          if (.not. ieee_is_finite(parameters%cofgen(12,i)) .or. parameters%cofgen(12,i) < 0.0_real64) return
        end if
      end do
    end if

    if (parameters%elasticity_active) then
      call initialize_b110_default_mvg_parameters(parameters%prepared_default_mvg, parameters%cofgen, &
           enable_ksatexm_extension=parameters%ksatexm_extension_active, &
           enable_elastic_storage=.true., specific_elastic_storage_input=parameters%cofgen(24,:))
    else
      call initialize_b110_default_mvg_parameters(parameters%prepared_default_mvg, parameters%cofgen, &
           enable_ksatexm_extension=parameters%ksatexm_extension_active)
    end if
    parameters%prepared_default_mvg_available = .true.

    if (parameters%direct_retention_active) then
      if (parameters%bottom_mode /= 5 .or. parameters%swkimpl /= 0 .or. &
          parameters%tabulated_hydraulics_active .or. parameters%hysteresis_active .or. &
          parameters%ksatexm_extension_active .or. parameters%elasticity_active) return
      if (parameters%active_nodes > 1) then
        if (any(parameters%prepared_default_mvg%cofgen(:,2:parameters%active_nodes) /= &
             spread(parameters%prepared_default_mvg%cofgen(:,1),2,parameters%active_nodes-1))) return
      end if
      call acquire_b110_direct_retention_slot(parameters%prepared_default_mvg, &
           parameters%prepared_direct_retention_slot, prepared, direct_hit)
      if (.not. prepared) return
    end if
    prepared = .true.
  end subroutine prepare_fmr_b110_default_mvg

  logical function prepared_default_mvg_structurally_compatible(parameters) result(compatible)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    compatible = .false.
    if (.not. parameters%prepared_default_mvg_available) return
    if (.not. allocated(parameters%cofgen)) return
    if (.not. allocated(parameters%prepared_default_mvg%cofgen)) return
    if (parameters%active_nodes <= 0) return
    if (size(parameters%cofgen,1) < 24 .or. size(parameters%cofgen,2) /= parameters%active_nodes) return
    if (parameters%prepared_default_mvg%active_nodes /= parameters%active_nodes) return
    if (parameters%prepared_default_mvg%ksatexm_extension_enabled .neqv. parameters%ksatexm_extension_active) return
    if (parameters%prepared_default_mvg%elastic_storage_active .neqv. parameters%elasticity_active) return
    if (parameters%elasticity_active) then
      if (.not. allocated(parameters%prepared_default_mvg%specific_elastic_storage)) return
      if (size(parameters%prepared_default_mvg%specific_elastic_storage) /= parameters%active_nodes) return
    else
      if (allocated(parameters%prepared_default_mvg%specific_elastic_storage)) return
    end if
    if (size(parameters%prepared_default_mvg%cofgen,1) /= 42) return
    if (size(parameters%prepared_default_mvg%cofgen,2) /= parameters%active_nodes) return
    compatible = .true.
  end function prepared_default_mvg_structurally_compatible

  logical function prepared_default_mvg_compatible(parameters) result(compatible)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    compatible = prepared_default_mvg_structurally_compatible(parameters)
    if (.not. compatible) return
    if (.not. all(parameters%prepared_default_mvg%cofgen(1:24,:) == parameters%cofgen(1:24,:))) compatible = .false.
    if (compatible .and. parameters%elasticity_active) then
      if (.not. all(parameters%prepared_default_mvg%specific_elastic_storage == parameters%cofgen(24,:))) &
           compatible = .false.
    end if
  end function prepared_default_mvg_compatible

  subroutine copy_b110_physical_state(source, target)
    class(fmr_b110_physical_state_t), intent(in) :: source
    class(fmr_b110_physical_state_t), intent(inout) :: target
    target%active_nodes = source%active_nodes
    if (allocated(target%pressure_head)) deallocate(target%pressure_head)
    if (allocated(source%pressure_head)) then
      allocate(target%pressure_head(size(source%pressure_head)))
      target%pressure_head = source%pressure_head
    end if
    if (allocated(target%water_content)) deallocate(target%water_content)
    if (allocated(source%water_content)) then
      allocate(target%water_content(size(source%water_content)))
      target%water_content = source%water_content
    end if
    target%ponding_depth = source%ponding_depth
    target%groundwater_level = source%groundwater_level
    if (allocated(target%snow)) deallocate(target%snow)
    if (allocated(source%snow)) then
      allocate(target%snow)
      target%snow = source%snow
    end if
    if (allocated(target%soil_temperature)) deallocate(target%soil_temperature)
    if (allocated(source%soil_temperature)) then
      allocate(target%soil_temperature)
      target%soil_temperature = source%soil_temperature
    end if
    if (allocated(target%macropore)) deallocate(target%macropore)
    if (allocated(source%macropore)) then
      allocate(target%macropore)
      target%macropore = source%macropore
    end if
    if (allocated(target%salt)) deallocate(target%salt)
    if (allocated(source%salt)) then
      allocate(target%salt)
      target%salt = source%salt
    end if
  end subroutine copy_b110_physical_state

  logical function fmr_mobile_salt_ready(self,active_nodes,active_domains) result(ready)
    class(fmr_mobile_salt_component_t), intent(in) :: self
    integer, intent(in) :: active_nodes
    integer, intent(in), optional :: active_domains
    ready = .false.
    if ((self%cdrain_source_id == 0_int64 .and. self%cdrain_revision /= -1_int64) .or. &
        (self%cdrain_source_id /= 0_int64 .and. &
        (self%cdrain_source_id < 0_int64 .or. self%cdrain_revision < 0_int64))) return
    if (active_nodes <= 0) return
    if (.not. allocated(self%mass_mg_cm2)) return
    if (size(self%mass_mg_cm2) /= active_nodes) return
    if (.not. all(ieee_is_finite(self%mass_mg_cm2)) .or. any(self%mass_mg_cm2 < 0.0_real64)) return
    if (present(active_domains)) then
      if (active_domains <= 0 .or. .not. allocated(self%macro_mass_mg_cm2)) return
      if (any(shape(self%macro_mass_mg_cm2) /= [active_domains,active_nodes])) return
      if (.not. all(ieee_is_finite(self%macro_mass_mg_cm2))) return
      if (any(self%macro_mass_mg_cm2 < 0.0_real64)) return
    else if (allocated(self%macro_mass_mg_cm2)) then
      ! A domain-resolved payload cannot be validated without its declared layout.
      return
    end if
    ready = .true.
  end function fmr_mobile_salt_ready

  subroutine fmr_b110_state_clone(self, copy)
    class(fmr_b110_physical_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b110_physical_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_physical_state_t)
      call copy_b110_physical_state(self, typed_copy)
    end select
  end subroutine fmr_b110_state_clone

  subroutine fmr_b110_macropore_reduction_state_clone(self, copy)
    class(fmr_b110_macropore_reduction_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b110_macropore_reduction_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_macropore_reduction_state_t)
      call copy_b110_physical_state(self, typed_copy)
      typed_copy%reduction_continuation = self%reduction_continuation
    end select
  end subroutine fmr_b110_macropore_reduction_state_clone

  subroutine fmr_b110_rfm_state_clone(self, copy)
    class(fmr_b110_rfm_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    logical :: ok

    allocate(fmr_b110_rfm_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_rfm_state_t)
      call copy_b110_physical_state(self, typed_copy)
      call copy_rfm_physical_state(self%rfm, typed_copy%rfm, ok)
      if (.not. ok) error stop 'PPA-WU05-A20 RFM clone rejected valid source'
    end select
  end subroutine fmr_b110_rfm_state_clone

  subroutine fmr_b110_temporal_indicator_state_clone(self, copy)
    class(fmr_b110_temporal_indicator_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    real(real64), allocatable :: derivative(:)
    logical :: available, ok
    allocate(fmr_b110_temporal_indicator_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_temporal_indicator_state_t)
      call copy_b110_physical_state(self, typed_copy)
      call self%temporal_history%snapshot(derivative, available)
      if (available) then
        call typed_copy%temporal_history%replace(derivative, ok)
        if (.not. ok) error stop 'F-KT10 temporal history clone rejected valid source'
      end if
    end select
  end subroutine fmr_b110_temporal_indicator_state_clone

  subroutine fmr_b110_fixed_weir_surface_water_state_clone(self, copy)
    class(fmr_b110_fixed_weir_surface_water_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b110_fixed_weir_surface_water_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      call copy_b110_physical_state(self, typed_copy)
      typed_copy%surface_water = self%surface_water
    end select
  end subroutine fmr_b110_fixed_weir_surface_water_state_clone

  subroutine fmr_b110_black_evaporation_state_clone(self, copy)
    class(fmr_b110_black_evaporation_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b110_black_evaporation_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_black_evaporation_state_t)
      call copy_b110_physical_state(self, typed_copy)
      typed_copy%black_evaporation = self%black_evaporation
    end select
  end subroutine fmr_b110_black_evaporation_state_clone

  subroutine fmr_b110_boesten_evaporation_state_clone(self, copy)
    class(fmr_b110_boesten_evaporation_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b110_boesten_evaporation_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_boesten_evaporation_state_t)
      call copy_b110_physical_state(self, typed_copy)
      typed_copy%boesten_evaporation = self%boesten_evaporation
    end select
  end subroutine fmr_b110_boesten_evaporation_state_clone

  logical function fmr_b110_temporal_history_available(self) result(available)
    class(fmr_b110_temporal_indicator_state_t), intent(in) :: self
    available = self%temporal_history%available(self%active_nodes)
  end function fmr_b110_temporal_history_available

  subroutine fmr_b110_temporal_history_snapshot(self, derivative, available)
    class(fmr_b110_temporal_indicator_state_t), intent(in) :: self
    real(real64), allocatable, intent(out) :: derivative(:)
    logical, intent(out) :: available
    available = self%temporal_history%available(self%active_nodes)
    if (.not. available) return
    call self%temporal_history%snapshot(derivative, available)
  end subroutine fmr_b110_temporal_history_snapshot

  subroutine fmr_new_b110_committed_state(committed, lineage_id, state, initial_time, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: carrier
    allocate(fmr_b110_physical_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_physical_state_t)
      call copy_b110_physical_state(state, typed_carrier)
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_committed_state

  subroutine fmr_new_b110_macropore_reduction_committed_state(committed,lineage_id,state,reduction,initial_time,ok)
    type(kernel_committed_state_t),intent(out)::committed
    integer(int64),intent(in)::lineage_id
    type(fmr_b110_physical_state_t),intent(in)::state
    type(macropore_reduction_continuation_t),intent(in)::reduction
    real(real64),intent(in)::initial_time
    logical,intent(out)::ok
    class(transaction_state_t),allocatable::carrier

    ok=.false.
    if(.not.reduction%valid())return
    allocate(fmr_b110_macropore_reduction_state_t :: carrier)
    select type(typed_carrier=>carrier)
    type is(fmr_b110_macropore_reduction_state_t)
      call copy_b110_physical_state(state,typed_carrier)
      typed_carrier%reduction_continuation=reduction
    end select
    call committed%initialize(lineage_id,carrier,ok,initial_time)
  end subroutine fmr_new_b110_macropore_reduction_committed_state

  subroutine fmr_new_b110_rfm_committed_state(committed, lineage_id, state, rfm_state, initial_time, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(rfm_physical_state_t), intent(in) :: rfm_state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: carrier
    logical :: copied

    ok = .false.
    if (.not. rfm_state%ready()) return
    if (allocated(state%macropore) .or. allocated(state%snow) .or. allocated(state%soil_temperature)) return

    allocate(fmr_b110_rfm_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_rfm_state_t)
      call copy_b110_physical_state(state, typed_carrier)
      call copy_rfm_physical_state(rfm_state, typed_carrier%rfm, copied)
      if (.not. copied) return
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_rfm_committed_state

  subroutine fmr_new_b110_temporal_indicator_committed_state(committed, lineage_id, state, initial_time, ok, &
                                                              initial_right_derivative)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    real(real64), intent(in), optional :: initial_right_derivative(:)
    class(transaction_state_t), allocatable :: carrier
    logical :: seeded

    ok = .false.
    allocate(fmr_b110_temporal_indicator_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_temporal_indicator_state_t)
      call copy_b110_physical_state(state, typed_carrier)
      call typed_carrier%temporal_history%clear()
      if (present(initial_right_derivative)) then
        if (state%active_nodes <= 0 .or. size(initial_right_derivative) /= state%active_nodes) return
        call typed_carrier%temporal_history%replace(initial_right_derivative, seeded)
        if (.not. seeded) return
      end if
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_temporal_indicator_committed_state

  subroutine fmr_new_b110_fixed_weir_surface_water_committed_state(committed, lineage_id, state, initial_time, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_fixed_weir_surface_water_state_t), intent(in) :: state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: carrier

    ok = .false.
    if (.not. ieee_is_finite(state%surface_water%storage)) return
    allocate(fmr_b110_fixed_weir_surface_water_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      call copy_b110_physical_state(state, typed_carrier)
      typed_carrier%surface_water = state%surface_water
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_fixed_weir_surface_water_committed_state

  subroutine fmr_new_b110_black_evaporation_committed_state(committed, lineage_id, state, black_state, initial_time, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(black_evaporation_state_t), intent(in) :: black_state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: carrier

    ok = .false.
    if (.not. ieee_is_finite(black_state%ldwet) .or. black_state%ldwet < 0.0_real64) return
    allocate(fmr_b110_black_evaporation_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_black_evaporation_state_t)
      call copy_b110_physical_state(state, typed_carrier)
      typed_carrier%black_evaporation = black_state
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_black_evaporation_committed_state

  subroutine fmr_new_b110_boesten_evaporation_committed_state(committed, lineage_id, state, boesten_state, initial_time, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(boesten_evaporation_state_t), intent(in) :: boesten_state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: carrier

    ok = .false.
    if (.not. ieee_is_finite(boesten_state%spev) .or. boesten_state%spev < 0.0_real64 .or. &
        .not. ieee_is_finite(boesten_state%saev) .or. boesten_state%saev < 0.0_real64) return
    allocate(fmr_b110_boesten_evaporation_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_boesten_evaporation_state_t)
      call copy_b110_physical_state(state, typed_carrier)
      typed_carrier%boesten_evaporation = boesten_state
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_boesten_evaporation_committed_state

  logical function state_matches_numerical_continuation_layout(state, temporal_history_enabled, &
                                                               macropore_reduction_enabled, &
                                                               fixed_weir_surface_water_active, &
                                                               black_evaporation_active, &
                                                               boesten_evaporation_active) result(matches)
    class(transaction_state_t), intent(in) :: state
    logical, intent(in) :: temporal_history_enabled, macropore_reduction_enabled, fixed_weir_surface_water_active
    logical, intent(in) :: black_evaporation_active, boesten_evaporation_active
    if (black_evaporation_active .and. boesten_evaporation_active) then
      matches = .false.
      return
    end if
    select type (state)
    type is (fmr_b110_macropore_reduction_state_t)
      matches = macropore_reduction_enabled .and. .not. temporal_history_enabled .and. &
           .not. fixed_weir_surface_water_active .and. .not. black_evaporation_active .and. &
           .not. boesten_evaporation_active .and. state%reduction_continuation%valid()
    type is (fmr_b110_temporal_indicator_state_t)
      matches = temporal_history_enabled .and. .not. macropore_reduction_enabled .and. &
           .not. fixed_weir_surface_water_active .and. &
           .not. black_evaporation_active .and. .not. boesten_evaporation_active
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      matches = .not. temporal_history_enabled .and. .not. macropore_reduction_enabled .and. &
           fixed_weir_surface_water_active .and. &
           .not. black_evaporation_active .and. .not. boesten_evaporation_active
    type is (fmr_b110_black_evaporation_state_t)
      matches = .not. temporal_history_enabled .and. .not. macropore_reduction_enabled .and. &
           .not. fixed_weir_surface_water_active .and. black_evaporation_active .and. .not. boesten_evaporation_active
    type is (fmr_b110_boesten_evaporation_state_t)
      matches = .not. temporal_history_enabled .and. .not. macropore_reduction_enabled .and. &
           .not. fixed_weir_surface_water_active .and. .not. black_evaporation_active .and. boesten_evaporation_active
    type is (fmr_b110_physical_state_t)
      matches = .not. temporal_history_enabled .and. .not. macropore_reduction_enabled .and. &
           .not. fixed_weir_surface_water_active .and. &
           .not. black_evaporation_active .and. .not. boesten_evaporation_active
    class default
      matches = .false.
    end select
  end function state_matches_numerical_continuation_layout

  subroutine clear_snow_preparation(model)
    type(fmr_serialized_reference_model_t), intent(inout) :: model
    model%snow_active = .false.
    model%soil_temperature_active = .false.
    model%black_evaporation_active = .false.
    model%boesten_evaporation_active = .false.
    model%snow_event_prepared = .false.
    model%state_profile_admitted = .false.
    model%snow_outer_t0 = 0.0_real64
    model%snow_outer_t1 = 0.0_real64
    model%snow_melt_rate = 0.0_real64
    model%snow_candidate = snow_state_t()
    model%snow_fluxes = snow_flux_result_t()
    model%snow_diagnostics = snow_diagnostics_t()
  end subroutine clear_snow_preparation

  subroutine prepare_snow_outer_event(model, parameters, committed, forcing, t0, t1)
    type(fmr_serialized_reference_model_t), intent(inout) :: model
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call clear_snow_preparation(model)
    if(allocated(parameters%bartholomeus)) then
      if(.not.valid_fmr_bartholomeus_parameters(parameters%bartholomeus,parameters%active_nodes)) return
    else
      if(allocated(forcing%crop_oxygen)) return
    end if
    model%snow_active = parameters%snow_active
    model%soil_temperature_active = parameters%soil_temperature_active
    model%black_evaporation_active = parameters%black_evaporation_active
    model%boesten_evaporation_active = parameters%boesten_evaporation_active
    model%snow_outer_t0 = t0
    model%snow_outer_t1 = t1
    if (model%fixed_weir_surface_water_active .and. parameters%snow_active) return
    call committed%snapshot(snapshot, available)
    if (.not. available) return
    if (.not. state_matches_numerical_continuation_layout(snapshot, model%temporal_indicator_history_enabled, &
                                                           model%macropore_reduction_continuation_enabled, &
                                                           model%fixed_weir_surface_water_active, &
                                                           model%black_evaporation_active, &
                                                           model%boesten_evaporation_active)) return
    select type (physical => snapshot)
    class is (fmr_b110_physical_state_t)
      if (parameters%snow_active) then
        if (.not. allocated(parameters%snow) .or. .not. allocated(forcing%snow) .or. &
            .not. allocated(physical%snow)) return
        call evaluate_snow_reference_call(parameters%snow, physical%snow%process, forcing%snow, t0, t1, &
             model%snow_candidate, model%snow_fluxes, model%snow_diagnostics)
        if (model%snow_diagnostics%status /= SNOW_OK .or. .not. model%snow_diagnostics%mass%available) return
        model%snow_event_prepared = .true.
        model%snow_melt_rate = model%snow_fluxes%melt / (t1 - t0)
      else
        if (allocated(parameters%snow) .or. allocated(forcing%snow) .or. allocated(physical%snow)) return
      end if
      if (parameters%soil_temperature_active) then
        if (parameters%snow_active) return
        if (.not. allocated(parameters%soil_temperature) .or. .not. allocated(forcing%soil_temperature) .or. &
            .not. allocated(physical%soil_temperature)) return
        if (.not. parameters%soil_temperature%ready() .or. .not. physical%soil_temperature%ready()) return
        if (parameters%soil_temperature%node_count() /= parameters%active_nodes .or. &
            physical%soil_temperature%node_count() /= parameters%active_nodes) return
      else
        if (allocated(parameters%soil_temperature) .or. allocated(forcing%soil_temperature) .or. &
            allocated(physical%soil_temperature)) return
      end if
      model%state_profile_admitted = .true.
    class default
      return
    end select
  end subroutine prepare_snow_outer_event

  subroutine fmr_serialized_backend_initialize(self, top_boundary)
    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    logical :: selection_ok
    integer :: selection_status
    self%initialized = .false.
    call self%model%soil_water_selection%configure('', selection_ok, selection_status)
    if (.not. selection_ok) return
    self%model%top_boundary => top_boundary
    self%model%temporal_indicator_history_enabled = .false.
    self%model%macropore_reduction_continuation_enabled = .false.
    self%model%temporal_indicator_budget_supplied = .false.
    self%model%temporal_indicator_budget_valid = .false.
    self%model%temporal_indicator_budget = 0.0_real64
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
    self%bottom_thermal_requested = .false.
    call configure_trajectory_direction(self%model%trajectory_direction, .false.)
    call self%model%bottom_thermal_carrier%clear()
    self%model%trusted_prepared_default_mvg = .false.
    nullify(self%model%trusted_parameter_source)
    nullify(self%model%hydraulic_parameters)
    call self%bottom_thermal_candidate%clear()
    self%model%top_sensible_boundary_carrier_active = .false.
    self%model%top_sensible_boundary_carrier_valid = .true.
    self%top_sensible_boundary_requested = .false.
    call self%model%top_sensible_boundary_carrier%clear()
    call self%top_sensible_boundary_candidate%clear()
    call self%clear_fixed_weir_surface_water()
    self%model%macropore_active = .false.
    if (allocated(self%model%macropore_config)) deallocate(self%model%macropore_config)
    self%model%macropore_policy = macropore_runtime_policy_t()
    self%model%macropore_policy_configured = .false.
    call self%model%rfm_configuration%clear()
    call self%kernel%bind_model(self%model)
    self%initialized = .true.
  end subroutine fmr_serialized_backend_initialize

  subroutine fmr_serialized_backend_configure_soil_water_model(self, requested_model_key, ok, status, &
                                                                asset_root, material_id)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    character(len=*), intent(in) :: requested_model_key
    logical, intent(out) :: ok
    integer, intent(out) :: status
    character(len=*), intent(in), optional :: asset_root, material_id

    ok = .false.
    status = FMR_ROSSFAST_BIND_INTERNAL_ERROR
    if (.not. self%initialized) return
    self%initialized = .false.
    if (present(asset_root)) then
      if (present(material_id)) then
        call self%model%soil_water_selection%configure(requested_model_key, ok, status, &
             asset_root=asset_root, material_id=material_id)
      else
        call self%model%soil_water_selection%configure(requested_model_key, ok, status, asset_root=asset_root)
      end if
    else if (present(material_id)) then
      call self%model%soil_water_selection%configure(requested_model_key, ok, status, material_id=material_id)
    else
      call self%model%soil_water_selection%configure(requested_model_key, ok, status)
    end if
    self%initialized = ok
  end subroutine fmr_serialized_backend_configure_soil_water_model

  subroutine fmr_serialized_backend_configure_macropore_policy(self, policy, ok)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(macropore_runtime_policy_t), intent(in) :: policy
    logical, intent(out) :: ok

    ok = .false.
    if (.not. self%initialized) return
    if (.not. policy%valid()) return
    if (.not. policy%enabled) return
    self%model%macropore_policy = policy
    self%model%macropore_policy_configured = .true.
    ok = .true.
  end subroutine fmr_serialized_backend_configure_macropore_policy

  subroutine fmr_serialized_backend_configure_rfm_runtime(self, config, ok)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(rfm_runtime_configuration_t), intent(in) :: config
    logical, intent(out) :: ok

    ok = .false.
    if (.not. self%initialized) return
    if (.not. config%valid()) return
    self%model%rfm_configuration = config
    ok = self%model%rfm_configuration%valid()
  end subroutine fmr_serialized_backend_configure_rfm_runtime

  subroutine fmr_serialized_backend_set_bottom_thermal_carrier_enabled(self, enabled)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    logical, intent(in) :: enabled
    self%bottom_thermal_requested = enabled
    call self%bottom_thermal_candidate%clear()
    call self%model%bottom_thermal_carrier%clear()
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
  end subroutine fmr_serialized_backend_set_bottom_thermal_carrier_enabled

  function fmr_serialized_backend_bottom_thermal_snapshot(self) result(candidate)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_bottom_thermal_candidate_t) :: candidate
    call self%bottom_thermal_candidate%copy_to(candidate)
  end function fmr_serialized_backend_bottom_thermal_snapshot

  subroutine fmr_serialized_backend_set_top_sensible_boundary_enabled(self, enabled)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    logical, intent(in) :: enabled
    self%top_sensible_boundary_requested = enabled
    call self%top_sensible_boundary_candidate%clear()
    call self%model%top_sensible_boundary_carrier%clear()
    self%model%top_sensible_boundary_carrier_active = .false.
    self%model%top_sensible_boundary_carrier_valid = .true.
  end subroutine fmr_serialized_backend_set_top_sensible_boundary_enabled

  function fmr_serialized_backend_top_sensible_boundary_snapshot(self) result(candidate)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_top_sensible_boundary_candidate_t) :: candidate
    call self%top_sensible_boundary_candidate%copy_to(candidate)
  end function fmr_serialized_backend_top_sensible_boundary_snapshot

  subroutine fmr_serialized_backend_configure_fixed_weir_surface_water(self, parameters, forcing, numerical, ok)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(fixed_weir_surface_water_parameters_t), intent(in) :: parameters
    type(fixed_weir_surface_water_forcing_t), intent(in) :: forcing
    type(fixed_weir_surface_water_numerical_config_t), intent(in) :: numerical
    logical, intent(out) :: ok
    logical :: parameters_ok

    call self%clear_fixed_weir_surface_water()
    ok = .false.
    if (.not. self%initialized) return
    call validate_fixed_weir_surface_water_parameters(parameters, parameters_ok)
    if (.not. parameters_ok) return
    if (.not. ieee_is_finite(forcing%secondary_drainage_rate) .or. &
        .not. ieee_is_finite(forcing%supply_capacity_rate)) return
    if (forcing%secondary_drainage_rate < 0.0_real64 .or. forcing%supply_capacity_rate < 0.0_real64) return
    if (numerical%max_bisection_iterations <= 0 .or. &
        .not. ieee_is_finite(numerical%rating_storage_abs_tolerance) .or. &
        .not. ieee_is_finite(numerical%rating_storage_rel_tolerance)) return
    if (numerical%rating_storage_abs_tolerance <= 0.0_real64 .or. &
        numerical%rating_storage_rel_tolerance < 0.0_real64) return

    self%model%fixed_weir_surface_water_parameters = parameters
    self%model%fixed_weir_surface_water_forcing = forcing
    self%model%fixed_weir_surface_water_numerical = numerical
    self%model%fixed_weir_surface_water_result = fixed_weir_surface_water_result_t()
    self%model%fixed_weir_surface_water_configured = .true.
    self%model%fixed_weir_surface_water_active = .true.
    ok = .true.
  end subroutine fmr_serialized_backend_configure_fixed_weir_surface_water

  subroutine fmr_serialized_backend_clear_fixed_weir_surface_water(self)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    self%model%fixed_weir_surface_water_active = .false.
    self%model%fixed_weir_surface_water_configured = .false.
    self%model%fixed_weir_surface_water_parameters = fixed_weir_surface_water_parameters_t()
    self%model%fixed_weir_surface_water_forcing = fixed_weir_surface_water_forcing_t()
    self%model%fixed_weir_surface_water_numerical = fixed_weir_surface_water_numerical_config_t()
    self%model%fixed_weir_surface_water_result = fixed_weir_surface_water_result_t()
  end subroutine fmr_serialized_backend_clear_fixed_weir_surface_water

  logical function fmr_serialized_rossfast_parameter_matches(actual, expected) result(matches)
    real(real64), intent(in) :: actual, expected
    real(real64) :: tolerance
    tolerance = 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(expected))
    matches = ieee_is_finite(actual) .and. abs(actual - expected) <= tolerance
  end function fmr_serialized_rossfast_parameter_matches

  logical function fmr_serialized_rossfast_preflight(self, template, parameters, forcing, config, t0, t1) result(ok)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: config
    real(real64), intent(in) :: t0, t1
    type(rossfast_d3r_material_t) :: material
    character(len=3) :: material_id
    real(real64) :: duration, tolerance, expected_m
    logical :: found, duration_admitted
    integer :: i, index

    ok = .false.
    if (.not. self%model%soil_water_selection%execution_ready()) return
    if (.not. self%model%soil_water_selection%uses_rossfast()) then
      ok = self%model%soil_water_selection%uses_reference()
      return
    end if
    if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE .or. &
        template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
    if (config%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE) return
    if (config%transaction%retry_scale /= ROSSFAST_D3R_RETRY_SCALE .or. &
        config%transaction%max_retries /= ROSSFAST_D3R_MAX_FULL_INDEX) return
    if (.not. ieee_is_finite(config%transaction%mass_tolerance) .or. &
        config%transaction%mass_tolerance <= 0.0_real64 .or. &
        config%transaction%mass_tolerance > ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (config%accepted_trajectory_direction%requested) return
    if (self%bottom_thermal_requested .or. self%top_sensible_boundary_requested .or. &
        self%model%fixed_weir_surface_water_active) return
    if (parameters%active_nodes /= ROSSFAST_D3R_N_CELLS .or. parameters%bottom_mode /= 2) return
    if (.not. allocated(parameters%dz) .or. size(parameters%dz) /= ROSSFAST_D3R_N_CELLS) return
    if (any(.not. ieee_is_finite(parameters%dz)) .or. any(parameters%dz /= ROSSFAST_D3R_DZ_CM)) return
    if (.not. allocated(parameters%cofgen) .or. size(parameters%cofgen,1) < 9 .or. &
        size(parameters%cofgen,2) /= ROSSFAST_D3R_N_CELLS) return
    if (parameters%root_extraction_active .or. parameters%macropore_active .or. parameters%snow_active .or. &
        parameters%hysteresis_active .or. parameters%tabulated_hydraulics_active .or. &
        parameters%elasticity_active .or. parameters%frost_active .or. parameters%soil_temperature_active .or. &
        parameters%drainage_response_active) return
    if (parameters%swkimpl /= 0 .or. parameters%swsophy /= 0) return
    if (.not. allocated(forcing%drainage_flux_by_level) .or. &
        .not. allocated(forcing%subsurface_irrigation_source) .or. .not. allocated(forcing%root_extraction_sink)) return
    if (any(.not. ieee_is_finite(forcing%drainage_flux_by_level)) .or. &
        any(.not. ieee_is_finite(forcing%subsurface_irrigation_source)) .or. &
        any(.not. ieee_is_finite(forcing%root_extraction_sink))) return
    if (any(forcing%drainage_flux_by_level /= 0.0_real64) .or. &
        any(forcing%subsurface_irrigation_source /= 0.0_real64) .or. &
        any(forcing%root_extraction_sink /= 0.0_real64)) return
    if (allocated(forcing%drainage_response_controls) .or. allocated(forcing%snow) .or. &
        allocated(forcing%soil_temperature)) return
    select type (top_boundary => self%model%top_boundary)
    type is (fixed_flux_top_boundary_provider_t)
      continue
    class default
      return
    end select

    material_id = self%model%soil_water_selection%selected_material_id()
    call rossfast_d3r_material_from_id(material_id, material, found)
    if (.not. found) return
    expected_m = 1.0_real64 - 1.0_real64 / material%n
    do i = 1, ROSSFAST_D3R_N_CELLS
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(1,i), material%theta_r)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(2,i), material%theta_s)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(3,i), material%ksatfit_cm_per_day)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(4,i), material%alpha_per_cm)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(5,i), material%lambda)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(6,i), material%n)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(7,i), expected_m)) return
      if (.not. fmr_serialized_rossfast_parameter_matches(parameters%cofgen(9,i), material%h_enpr_cm)) return
    end do

    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    duration_admitted = .false.
    do index = 0, ROSSFAST_D3R_MAX_FULL_INDEX
      duration = rossfast_d3r_full_duration_for_index(index)
      tolerance = 2.0_real64 * max(spacing(t0), spacing(t1), spacing(duration))
      if (abs((t1 - t0) - duration) <= tolerance) then
        duration_admitted = .true.
        exit
      end if
    end do
    if (.not. duration_admitted) return
    ok = .true.
  end function fmr_serialized_rossfast_preflight

  subroutine fmr_serialized_backend_commit_reference_floor_candidate(self, committed, candidate, diagnostics, &
                                                                       did_commit, status)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(kernel_committed_state_t), intent(inout) :: committed
    type(kernel_reference_floor_candidate_t), intent(inout) :: candidate
    type(kernel_diagnostics_t), intent(inout) :: diagnostics
    logical, intent(out) :: did_commit
    integer, intent(out) :: status

    did_commit = .false.
    status = KERNEL_STATUS_NOT_ADMITTED
    if (.not. self%initialized) return
    call self%kernel%commit_reference_floor_candidate(committed, candidate, diagnostics, did_commit, status)
  end subroutine fmr_serialized_backend_commit_reference_floor_candidate

  subroutine fmr_serialized_backend_discard_reference_floor_candidate(self, candidate, diagnostics)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(kernel_reference_floor_candidate_t), intent(inout) :: candidate
    type(kernel_diagnostics_t), intent(inout) :: diagnostics

    if (.not. self%initialized) return
    call self%kernel%discard_reference_floor_candidate(candidate, diagnostics)
  end subroutine fmr_serialized_backend_discard_reference_floor_candidate

  subroutine fmr_serialized_backend_commit_trial_candidate(self, committed, candidate, diagnostics, did_commit, status)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(kernel_committed_state_t), intent(inout) :: committed
    type(kernel_candidate_state_t), intent(inout) :: candidate
    type(kernel_diagnostics_t), intent(inout) :: diagnostics
    logical, intent(out) :: did_commit
    integer, intent(out) :: status

    did_commit = .false.
    status = KERNEL_STATUS_NOT_ADMITTED
    if (.not. self%initialized) return
    call fmr_commit_candidate(self%kernel, committed, candidate, diagnostics, did_commit, status)
  end subroutine fmr_serialized_backend_commit_trial_candidate

  subroutine fmr_serialized_backend_discard_trial_candidate(self, candidate, diagnostics)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(kernel_candidate_state_t), intent(inout) :: candidate
    type(kernel_diagnostics_t), intent(inout) :: diagnostics

    if (.not. self%initialized) return
    call fmr_discard_candidate(self%kernel, candidate, diagnostics)
  end subroutine fmr_serialized_backend_discard_trial_candidate

  subroutine fmr_serialized_backend_run_reference_floor_sample(self, column, template, parameters, committed, &
                                                                 forcing, t0, t1, mass_tolerance, result, candidate, &
                                                                 diagnostics)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1, mass_tolerance
    type(kernel_reference_floor_result_t), intent(out) :: result
    type(kernel_reference_floor_candidate_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics

    result = kernel_reference_floor_result_t()
    result%requested_t0 = t0
    result%requested_t1 = t1
    diagnostics = kernel_diagnostics_t()

    call self%bottom_thermal_candidate%clear()
    call self%model%bottom_thermal_carrier%clear()
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
    call self%top_sensible_boundary_candidate%clear()
    call self%model%top_sensible_boundary_carrier%clear()
    self%model%top_sensible_boundary_carrier_active = .false.
    self%model%top_sensible_boundary_carrier_valid = .true.
    self%model%temporal_indicator_history_enabled = .false.
    self%model%temporal_indicator_budget_supplied = .false.
    self%model%temporal_indicator_budget_valid = .false.
    self%model%temporal_indicator_budget = 0.0_real64
    call configure_trajectory_direction(self%model%trajectory_direction, .false.)
    self%model%trajectory_direction_requested = .false.
    self%model%trajectory_provenance_valid = .false.
    self%model%trajectory_worker_id = -1

    if (.not. self%initialized .or. column%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        template%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        column%template_id /= template%template_id .or. column%column_id <= 0_int64) then
      result%status = KERNEL_REFERENCE_FLOOR_STATUS_NOT_ADMITTED
      diagnostics%admission_rejections = 1
      return
    end if

    if (.not. self%model%soil_water_selection%uses_reference()) then
      result%status = KERNEL_REFERENCE_FLOOR_STATUS_NOT_ADMITTED
      diagnostics%admission_rejections = 1
      return
    end if

    if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE .or. &
        template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE .or. &
        self%model%fixed_weir_surface_water_active .or. self%bottom_thermal_requested .or. &
        self%top_sensible_boundary_requested .or. parameters%snow_active .or. &
        parameters%soil_temperature_active .or. parameters%root_extraction_active .or. &
        parameters%macropore_active .or. parameters%drainage_response_active .or. &
        parameters%drainage_qbot_smooth_freatic_projection .or. &
        (parameters%bottom_mode /= 2 .and. parameters%bottom_mode /= 5)) then
      result%status = KERNEL_REFERENCE_FLOOR_STATUS_NOT_ADMITTED
      diagnostics%admission_rejections = 1
      return
    end if

    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)
    if (.not. self%model%state_profile_admitted) then
      result%status = KERNEL_REFERENCE_FLOOR_STATUS_NOT_ADMITTED
      diagnostics%admission_rejections = 1
      return
    end if

    call self%kernel%sample_reference_floor_interval(parameters, committed, forcing, t0, t1, mass_tolerance, &
         result, candidate, diagnostics)
  end subroutine fmr_serialized_backend_run_reference_floor_sample

  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics, &
                                               trusted_prepared_parameters, trace_accepted_water_flux_substeps)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), target, intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: config
    real(real64), intent(in) :: t0, t1
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    logical, intent(in), optional :: trusted_prepared_parameters
    logical, intent(in), optional :: trace_accepted_water_flux_substeps
    logical :: bottom_thermal_ok, top_sensible_ok

    call self%bottom_thermal_candidate%clear()
    call self%model%bottom_thermal_carrier%clear()
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
    call self%top_sensible_boundary_candidate%clear()
    call self%model%top_sensible_boundary_carrier%clear()
    self%model%top_sensible_boundary_carrier_active = .false.
    self%model%top_sensible_boundary_carrier_valid = .true.
    self%model%temporal_indicator_history_enabled = .false.
    self%model%temporal_indicator_budget_supplied = .false.
    self%model%temporal_indicator_budget_valid = .false.
    self%model%temporal_indicator_budget = 0.0_real64
    self%model%trajectory_worker_id = -1
    self%model%trajectory_provenance_valid = .false.
    self%model%accepted_water_flux_trace_enabled = .false.
    if (present(trace_accepted_water_flux_substeps)) &
         self%model%accepted_water_flux_trace_enabled = trace_accepted_water_flux_substeps
    if (allocated(self%model%accepted_water_flux_substeps)) deallocate(self%model%accepted_water_flux_substeps)
    if (self%model%accepted_water_flux_trace_enabled) then
      if (parameters%snow_active .or. parameters%drainage_response_active .or. &
          parameters%soil_temperature_active .or. parameters%black_evaporation_active .or. &
          parameters%boesten_evaporation_active .or. parameters%frost_active .or. &
          self%model%rfm_configuration%enabled .or. &
          self%model%fixed_weir_surface_water_active) then
        call reject_backend_trial(result, candidate, diagnostics)
        return
      end if
    end if
    self%model%accepted_water_flux_trace_failed = .false.
    if (column%column_id > 0_int64 .and. column%column_id <= int(huge(0), int64)) then
      self%model%trajectory_worker_id = int(column%column_id)
      self%model%trajectory_provenance_valid = self%model%trajectory_worker_id > 0
    end if
    if (.not. self%initialized .or. column%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        template%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        column%template_id /= template%template_id .or. column%column_id <= 0_int64) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
    if (template%solute_state_layout_id /= FMR_SOLUTE_STATE_LAYOUT_NONE) then
      if (.not. allocated(forcing%c_drain_salt)) then
        call reject_backend_trial(result, candidate, diagnostics)
        return
      end if
      if (.not. fmr_c_drain_salt_matches_trial(forcing%c_drain_salt, column%forcing_handle, t0, t1)) then
        call reject_backend_trial(result, candidate, diagnostics)
        return
      end if
      ! Active salt layouts remain fail-closed until an FMR-owned candidate and
      ! its complete boundary receipts can be staged and discarded atomically.
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
    if (.not. fmr_solute_state_layout_known(template%solute_state_layout_id)) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
    if (.not. fmr_serialized_rossfast_preflight(self, template, parameters, forcing, config, t0, t1)) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
    if (self%model%fixed_weir_surface_water_active) then
      if (parameters%drainage_response_active) then
        call reject_backend_trial(result, candidate, diagnostics)
        return
      end if
      if (.not. self%model%fixed_weir_surface_water_configured .or. &
          template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER .or. &
          template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE .or. &
          config%transaction%temporal_mode /= TX_TEMPORAL_EXTERNAL_FULL_HALF .or. parameters%snow_active) then
        call reject_backend_trial(result, candidate, diagnostics)
        return
      end if
    else if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
    self%model%macropore_reduction_continuation_enabled = .false.
    select case (template%numerical_continuation_layout_id)
    case (FMR_NUMERICAL_CONTINUATION_NONE)
      self%model%temporal_indicator_history_enabled = .false.
    case (FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
      self%model%temporal_indicator_history_enabled = .true.
    case (FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION)
      self%model%temporal_indicator_history_enabled = .false.
      self%model%macropore_reduction_continuation_enabled = .true.
    case default
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end select
    if (.not. fmr_optional_state_layout_known(template%optional_state_layout_id)) then
      result = kernel_result_t()
      result%status = KERNEL_STATUS_NOT_ADMITTED
      candidate = kernel_candidate_state_t()
      diagnostics = kernel_diagnostics_t()
      diagnostics%admission_rejections = 1
      return
    end if
    if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RFM) then
      if (.not. self%model%rfm_configuration%valid() .or. parameters%macropore_active .or. &
          template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE .or. &
          .not. self%model%soil_water_selection%uses_reference()) then
        call reject_backend_trial(result,candidate,diagnostics)
        return
      end if
    end if
    if (parameters%macropore_active) then
      if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_MACROPORE .or. &
          (template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE .and. &
           template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION) .or. &
          (template%numerical_continuation_layout_id == FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION .and. &
           .not. self%model%macropore_policy%source_reduction_retry_enabled) .or. &
          config%transaction%temporal_mode /= TX_TEMPORAL_EXTERNAL_FULL_HALF) then
        result = kernel_result_t()
        result%status = KERNEL_STATUS_NOT_ADMITTED
        candidate = kernel_candidate_state_t()
        diagnostics = kernel_diagnostics_t()
        diagnostics%admission_rejections = 1
        return
      end if
    else if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_MACROPORE) then
      result = kernel_result_t()
      result%status = KERNEL_STATUS_NOT_ADMITTED
      candidate = kernel_candidate_state_t()
      diagnostics = kernel_diagnostics_t()
      diagnostics%admission_rejections = 1
      return
    end if
    if (parameters%black_evaporation_active) then
      if (parameters%boesten_evaporation_active .or. &
          template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION .or. &
          parameters%snow_active .or. parameters%soil_temperature_active .or. &
          template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) then
        result = kernel_result_t()
        result%status = KERNEL_STATUS_NOT_ADMITTED
        candidate = kernel_candidate_state_t()
        diagnostics = kernel_diagnostics_t()
        diagnostics%admission_rejections = 1
        return
      end if
    else if (parameters%boesten_evaporation_active) then
      if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION .or. &
          parameters%snow_active .or. parameters%soil_temperature_active .or. &
          template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) then
        result = kernel_result_t()
        result%status = KERNEL_STATUS_NOT_ADMITTED
        candidate = kernel_candidate_state_t()
        diagnostics = kernel_diagnostics_t()
        diagnostics%admission_rejections = 1
        return
      end if
    else if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION .or. &
             template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION) then
      result = kernel_result_t()
      result%status = KERNEL_STATUS_NOT_ADMITTED
      candidate = kernel_candidate_state_t()
      diagnostics = kernel_diagnostics_t()
      diagnostics%admission_rejections = 1
      return
    else if (parameters%soil_temperature_active) then
      if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE .or. &
          parameters%snow_active) then
        result = kernel_result_t()
        result%status = KERNEL_STATUS_NOT_ADMITTED
        candidate = kernel_candidate_state_t()
        diagnostics = kernel_diagnostics_t()
        diagnostics%admission_rejections = 1
        return
      end if
    else if (parameters%snow_active) then
      if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_SNOW) then
        result = kernel_result_t()
        result%status = KERNEL_STATUS_NOT_ADMITTED
        candidate = kernel_candidate_state_t()
        diagnostics = kernel_diagnostics_t()
        diagnostics%admission_rejections = 1
        return
      end if
    end if
    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)
    if (self%bottom_thermal_requested .and. parameters%soil_temperature_active .and. &
        self%model%state_profile_admitted .and. config%max_committed_substeps <= ishft(huge(0), -1)) then
      call self%model%bottom_thermal_carrier%initialize(2 * config%max_committed_substeps, bottom_thermal_ok)
      self%model%bottom_thermal_carrier_active = bottom_thermal_ok
      self%model%bottom_thermal_carrier_valid = bottom_thermal_ok
    end if
    if (self%top_sensible_boundary_requested .and. parameters%soil_temperature_active .and. &
        self%model%state_profile_admitted .and. config%max_committed_substeps <= ishft(huge(0), -1)) then
      call self%model%top_sensible_boundary_carrier%initialize(2 * config%max_committed_substeps, top_sensible_ok)
      self%model%top_sensible_boundary_carrier_active = top_sensible_ok
      self%model%top_sensible_boundary_carrier_valid = top_sensible_ok
    end if
    self%model%trusted_prepared_default_mvg = .false.
    nullify(self%model%trusted_parameter_source)
    if (present(trusted_prepared_parameters)) then
      if (trusted_prepared_parameters .and. prepared_default_mvg_structurally_compatible(parameters)) then
        self%model%trusted_prepared_default_mvg = .true.
        self%model%trusted_parameter_source => parameters
      end if
    end if
    if (allocated(forcing%legacy_swbotb5_control)) then
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics, target_selector=select_hbot5_proposal)
    else if (allocated(forcing%legacy_swbotb3_implicit_control)) then
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics, target_selector=select_cauchy3_proposal)
    else
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics)
    end if
    if (associated(self%model%constitutive)) nullify(self%model%constitutive%parameters)
    nullify(self%model%hydraulic_parameters)
    nullify(self%model%trusted_parameter_source)
    self%model%trusted_prepared_default_mvg = .false.
    if (self%model%accepted_water_flux_trace_enabled .and. result%completed) then
      if (self%model%accepted_water_flux_trace_failed .or. &
          .not. allocated(self%model%accepted_water_flux_substeps)) then
        call reject_backend_trial(result, candidate, diagnostics)
      else if (.not. accepted_water_flux_trace_covers(self%model%accepted_water_flux_substeps,t0,t1)) then
        call reject_backend_trial(result, candidate, diagnostics)
      else
        self%model%last_observation%accepted_water_flux_substeps = self%model%accepted_water_flux_substeps
        self%model%last_observation%accepted_water_flux_trace_available = .true.
      end if
    end if
    if (self%model%bottom_thermal_carrier_active .and. self%model%bottom_thermal_carrier_valid .and. &
        result%completed) then
      if (candidate%ready()) then
        call self%model%bottom_thermal_carrier%materialize_candidate(t0, t1, self%bottom_thermal_candidate, &
             bottom_thermal_ok)
        if (.not. bottom_thermal_ok) call self%bottom_thermal_candidate%clear()
      end if
    end if
    if (self%model%top_sensible_boundary_carrier_active .and. self%model%top_sensible_boundary_carrier_valid .and. &
        result%completed) then
      if (candidate%ready()) then
        call self%model%top_sensible_boundary_carrier%materialize_candidate(t0, t1, &
             self%top_sensible_boundary_candidate, top_sensible_ok)
        if (.not. top_sensible_ok) call self%top_sensible_boundary_candidate%clear()
      end if
    end if
    call self%model%bottom_thermal_carrier%clear()
    self%model%bottom_thermal_carrier_active = .false.
    self%model%bottom_thermal_carrier_valid = .true.
    call self%model%top_sensible_boundary_carrier%clear()
    self%model%top_sensible_boundary_carrier_active = .false.
    self%model%top_sensible_boundary_carrier_valid = .true.
  contains
    subroutine select_hbot5_proposal(cursor, requested_t1, target_t1, max_retries_cap, valid)
      real(real64), intent(in) :: cursor, requested_t1
      real(real64), intent(out) :: target_t1
      integer, intent(out) :: max_retries_cap
      logical, intent(out) :: valid
      integer :: provider_status
      target_t1 = requested_t1
      max_retries_cap = config%transaction%max_retries
      valid = .false.
      self%model%hbot5_proposal = fmr_hbot5_proposal_t()
      if (.not. allocated(self%model%legacy_swbotb5_control)) return
      call self%model%legacy_swbotb5_control%resolve(cursor,target_t1,self%model%hbot5_proposal,provider_status)
      valid = provider_status == FMR_HBOT5_OK .and. self%model%hbot5_proposal%available
    end subroutine

    subroutine select_cauchy3_proposal(cursor, requested_t1, target_t1, max_retries_cap, valid)
      real(real64), intent(in) :: cursor, requested_t1
      real(real64), intent(out) :: target_t1
      integer, intent(out) :: max_retries_cap
      logical, intent(out) :: valid
      integer :: provider_status
      target_t1 = requested_t1
      max_retries_cap = config%transaction%max_retries
      valid = .false.
      self%model%cauchy3_proposal = fmr_cauchy3_proposal_t()
      if (.not. allocated(self%model%legacy_swbotb3_implicit_control)) return
      call self%model%legacy_swbotb3_implicit_control%resolve_proposal(cursor, target_t1, &
           self%model%cauchy3_proposal, provider_status)
      valid = provider_status == FMR_CAUCHY3_OK .and. self%model%cauchy3_proposal%available
    end subroutine
  end subroutine fmr_serialized_backend_run_trial

  subroutine reject_backend_trial(result, candidate, diagnostics)
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    result = kernel_result_t()
    result%status = KERNEL_STATUS_NOT_ADMITTED
    candidate = kernel_candidate_state_t()
    diagnostics = kernel_diagnostics_t()
    diagnostics%admission_rejections = 1
  end subroutine reject_backend_trial

  function fmr_serialized_backend_observation(self) result(obs)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_serialized_physical_observation_t) :: obs
    obs = self%model%last_observation
  end function fmr_serialized_backend_observation

  logical function fmr_serialized_attempt_context_required(self) result(required)
    class(fmr_serialized_reference_model_t), intent(in) :: self

    required = allocated(self%legacy_swbotb5_control) .or. allocated(self%legacy_swbotb3_implicit_control) .or. &
         self%trajectory_direction_requested .or. self%drainage_response_active .or. &
         self%accepted_water_flux_trace_enabled .or. &
         self%bottom_thermal_carrier_active .or. .not. self%bottom_thermal_carrier_valid .or. &
         self%top_sensible_boundary_carrier_active .or. .not. self%top_sensible_boundary_carrier_valid
  end function fmr_serialized_attempt_context_required

  subroutine fmr_serialized_capture_attempt_context(self, context)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context

    allocate(fmr_serialized_attempt_context_t :: context)
    select type (typed => context)
    type is (fmr_serialized_attempt_context_t)
      typed%hbot5_proposal = self%hbot5_proposal
      typed%cauchy3_proposal = self%cauchy3_proposal
      typed%bottom_thermal_active = self%bottom_thermal_carrier_active
      typed%bottom_thermal_valid = self%bottom_thermal_carrier_valid
      call self%bottom_thermal_carrier%copy_to(typed%bottom_thermal_carrier)
      typed%top_sensible_boundary_active = self%top_sensible_boundary_carrier_active
      typed%top_sensible_boundary_valid = self%top_sensible_boundary_carrier_valid
      call self%top_sensible_boundary_carrier%copy_to(typed%top_sensible_boundary_carrier)
      typed%drainage_response_window_exchange_available = self%drainage_response_window_exchange_available
      typed%drainage_response_window_signed_exchange_native = self%drainage_response_window_signed_exchange_native
      typed%trajectory_direction = self%trajectory_direction
      typed%accepted_water_flux_trace_failed = self%accepted_water_flux_trace_failed
      if (allocated(self%accepted_water_flux_substeps)) &
           typed%accepted_water_flux_substeps = self%accepted_water_flux_substeps
    end select
  end subroutine fmr_serialized_capture_attempt_context

  subroutine fmr_serialized_restore_attempt_context(self, context)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context

    select type (typed => context)
    type is (fmr_serialized_attempt_context_t)
      self%hbot5_proposal = typed%hbot5_proposal
      self%cauchy3_proposal = typed%cauchy3_proposal
      self%bottom_thermal_carrier_active = typed%bottom_thermal_active
      self%bottom_thermal_carrier_valid = typed%bottom_thermal_valid
      call self%bottom_thermal_carrier%restore_from(typed%bottom_thermal_carrier)
      self%top_sensible_boundary_carrier_active = typed%top_sensible_boundary_active
      self%top_sensible_boundary_carrier_valid = typed%top_sensible_boundary_valid
      call self%top_sensible_boundary_carrier%restore_from(typed%top_sensible_boundary_carrier)
      self%drainage_response_window_exchange_available = typed%drainage_response_window_exchange_available
      self%drainage_response_window_signed_exchange_native = typed%drainage_response_window_signed_exchange_native
      self%trajectory_direction = typed%trajectory_direction
      self%accepted_water_flux_trace_failed = typed%accepted_water_flux_trace_failed
      if (allocated(typed%accepted_water_flux_substeps)) then
        self%accepted_water_flux_substeps = typed%accepted_water_flux_substeps
      else if (allocated(self%accepted_water_flux_substeps)) then
        deallocate(self%accepted_water_flux_substeps)
      end if
    class default
      self%hbot5_proposal = fmr_hbot5_proposal_t()
      self%cauchy3_proposal = fmr_cauchy3_proposal_t()
      self%bottom_thermal_carrier_active = .false.
      self%bottom_thermal_carrier_valid = .false.
      call self%bottom_thermal_carrier%clear()
      self%top_sensible_boundary_carrier_active = .false.
      self%top_sensible_boundary_carrier_valid = .false.
      call self%top_sensible_boundary_carrier%clear()
      self%drainage_response_window_exchange_available = .false.
      self%drainage_response_window_signed_exchange_native = 0.0_real64
      self%accepted_water_flux_trace_failed = .true.
      if (allocated(self%accepted_water_flux_substeps)) deallocate(self%accepted_water_flux_substeps)
      call configure_trajectory_direction(self%trajectory_direction, .false.)
    end select
  end subroutine fmr_serialized_restore_attempt_context

  logical function fmr_serialized_execution_admitted(self, parameters, numerical_config)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: ok
    integer :: oxygen_route,waterfilm_mode
    ok = associated(self%top_boundary) .and. numerical_config%max_committed_substeps > 0 .and. &
         self%state_profile_admitted
    if (self%fixed_weir_surface_water_active) then
      ok = ok .and. self%fixed_weir_surface_water_configured .and. .not. self%temporal_indicator_history_enabled .and. &
           numerical_config%transaction%temporal_mode == TX_TEMPORAL_EXTERNAL_FULL_HALF
    end if
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      ok = ok .and. parameters%parameter_set_id > 0_int64 .and. parameters%active_nodes > 0 .and. &
           allocated(parameters%z) .and. allocated(parameters%dz) .and. allocated(parameters%node_distance) .and. &
           allocated(parameters%cofgen)
      if (ok) ok = size(parameters%z) == parameters%active_nodes .and. &
           size(parameters%dz) == parameters%active_nodes .and. &
           size(parameters%node_distance) == parameters%active_nodes .and. &
           size(parameters%cofgen,1) >= 24 .and. size(parameters%cofgen,2) == parameters%active_nodes
      if (parameters%macropore_active) then
        ! Admission precedes configure_parameters(). Validate the immutable
        ! production config from the parameter carrier here; configure_parameters
        ! materializes the model-owned copy only after this gate succeeds.
        ok = ok .and. allocated(parameters%macropore) .and. self%macropore_policy_configured .and. &
             self%macropore_policy%valid() .and. self%macropore_policy%enabled .and. &
             self%soil_water_selection%uses_reference() .and. &
             .not. parameters%snow_active .and. &
             .not. parameters%soil_temperature_active .and. .not. parameters%black_evaporation_active .and. &
             .not. parameters%boesten_evaporation_active .and. .not. parameters%drainage_response_active .and. &
             .not. self%fixed_weir_surface_water_active .and. &
             parameters%macropore%valid_for_nodes(parameters%active_nodes)
      else
        ok = ok .and. .not. allocated(parameters%macropore)
      end if
      ok = ok .and. (parameters%bottom_mode == 7 .or. parameters%bottom_mode == -2 .or. parameters%bottom_mode == 5 .or. &
           parameters%bottom_mode == 2 .or. parameters%bottom_mode == 3 .or. parameters%bottom_mode == 8) .and. &
           parameters%swkimpl == 0 .and. parameters%swsophy == 0 .and. &
           .not. parameters%hysteresis_active .and. .not. parameters%tabulated_hydraulics_active .and. &
            .not. parameters%frost_active
       if (parameters%bottom_mode == 3) then
         ! Admission precedes configure_parameters()/prepare_interval(). The
         ! immutable forcing-owned Cauchy control is therefore validated in
         ! prepare_interval, not through stale model-local state here.
         ok = ok .and. self%soil_water_selection%uses_reference()
       end if
       if (parameters%elasticity_active) then
         ok = ok .and. self%soil_water_selection%uses_reference() .and. &
              .not. parameters%ksatexm_extension_active .and. .not. parameters%direct_retention_active .and. &
              parameters%prepared_default_mvg_available .and. &
              parameters%prepared_default_mvg%elastic_storage_active .and. &
              allocated(parameters%prepared_default_mvg%specific_elastic_storage)
         if (ok) ok = size(parameters%prepared_default_mvg%specific_elastic_storage) == parameters%active_nodes
         if (ok) ok = all(ieee_is_finite(parameters%prepared_default_mvg%specific_elastic_storage))
         if (ok) ok = all(parameters%prepared_default_mvg%specific_elastic_storage >= 0.0_real64)
       end if
      if (parameters%direct_retention_active) then
        ok = ok .and. self%soil_water_selection%uses_reference() .and. &
             parameters%bottom_mode == 5 .and. parameters%swkimpl == 0 .and. &
             .not. parameters%ksatexm_extension_active .and. parameters%prepared_default_mvg_available .and. &
             parameters%prepared_direct_retention_slot > 0
      end if
      if (parameters%snow_active) then
        ok = ok .and. allocated(parameters%snow) .and. self%snow_event_prepared .and. &
             .not. self%fixed_weir_surface_water_active
      else
        ok = ok .and. .not. allocated(parameters%snow) .and. .not. self%snow_event_prepared
      end if
      if (parameters%soil_temperature_active) then
        ok = ok .and. .not. parameters%snow_active .and. self%soil_temperature_active .and. &
             allocated(parameters%soil_temperature)
        if (ok) ok = parameters%soil_temperature%ready() .and. &
             parameters%soil_temperature%node_count() == parameters%active_nodes
      else
        ok = ok .and. .not. allocated(parameters%soil_temperature) .and. .not. self%soil_temperature_active
      end if
      if (parameters%black_evaporation_active) then
        ok = ok .and. .not. parameters%boesten_evaporation_active .and. self%black_evaporation_active .and. &
             .not. self%boesten_evaporation_active .and. allocated(parameters%black_evaporation) .and. &
             .not. allocated(parameters%boesten_evaporation) .and. self%soil_water_selection%uses_reference() .and. &
             .not. parameters%snow_active .and. .not. parameters%soil_temperature_active .and. &
             .not. self%fixed_weir_surface_water_active .and. .not. parameters%drainage_response_active .and. &
             .not. parameters%root_extraction_active .and. parameters%bottom_mode /= 5
        if (ok) ok = ieee_is_finite(parameters%black_evaporation%cofred) .and. &
             parameters%black_evaporation%cofred >= 0.0_real64
      else if (parameters%boesten_evaporation_active) then
        ok = ok .and. .not. self%black_evaporation_active .and. self%boesten_evaporation_active .and. &
             .not. allocated(parameters%black_evaporation) .and. allocated(parameters%boesten_evaporation) .and. &
             self%soil_water_selection%uses_reference() .and. .not. parameters%snow_active .and. &
             .not. parameters%soil_temperature_active .and. .not. self%fixed_weir_surface_water_active .and. &
             .not. parameters%drainage_response_active .and. .not. parameters%root_extraction_active .and. &
             parameters%bottom_mode /= 5
        if (ok) ok = ieee_is_finite(parameters%boesten_evaporation%cofred) .and. &
             parameters%boesten_evaporation%cofred > 0.0_real64 .and. parameters%boesten_evaporation%cofred <= 1.0_real64
      else
        ok = ok .and. .not. allocated(parameters%black_evaporation) .and. .not. self%black_evaporation_active .and. &
             .not. allocated(parameters%boesten_evaporation) .and. .not. self%boesten_evaporation_active
      end if
      if (parameters%drainage_response_active) then
        ok = ok .and. allocated(parameters%drainage_response_levels) .and. &
             .not. self%fixed_weir_surface_water_active
        if (ok) ok = size(parameters%drainage_response_levels) > 0
      else
        ok = ok .and. .not. allocated(parameters%drainage_response_levels) .and. &
             .not. parameters%drainage_qbot_smooth_freatic_projection
      end if
      if (parameters%drainage_qbot_smooth_freatic_projection) then
        ok = ok .and. parameters%drainage_response_active .and. parameters%bottom_mode == 2 .and. &
             .not. parameters%root_extraction_active .and. .not. parameters%macropore_active
      end if
      if(allocated(parameters%bartholomeus)) then
        ok=ok .and. valid_fmr_bartholomeus_parameters(parameters%bartholomeus,parameters%active_nodes)
        call select_fmr_bartholomeus_route(parameters%bartholomeus%selection,oxygen_route,waterfilm_mode)
        if(oxygen_route==FMR_BARTHOLOMEUS_ACTIVE) then
          ok=ok .and. parameters%root_extraction_active .and. parameters%soil_temperature_active .and. &
               self%soil_water_selection%uses_reference() .and. &
               (parameters%bottom_mode==2 .or. parameters%bottom_mode==7) .and. &
               .not.parameters%direct_retention_active .and. .not.parameters%elasticity_active .and. &
               .not.parameters%macropore_active .and. .not.parameters%snow_active .and. &
               .not.parameters%drainage_response_active .and. .not.self%fixed_weir_surface_water_active
          ok=ok .and. parameters%bartholomeus%soil%initial_hysteresis_branch==0
          ok=ok .and. matches_bartholomeus_hydraulic_owner(parameters%bartholomeus,parameters%cofgen,parameters%dz)
        end if
      end if
    class default
      ok = .false.
    end select
    fmr_serialized_execution_admitted = ok
  end function fmr_serialized_execution_admitted

  subroutine fmr_serialized_configure_parameters(self, parameters)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    integer :: n
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      n = parameters%active_nodes
      if (.not. associated(self%soil_parameters)) allocate(self%soil_parameters)
      if (.not. associated(self%owned_hydraulic_parameters)) allocate(self%owned_hydraulic_parameters)
      nullify(self%hydraulic_parameters)
      if (.not. associated(self%constitutive)) allocate(self%constitutive)
      if (.not. associated(self%direct_retention_constitutive)) allocate(self%direct_retention_constitutive)
      if (.not. associated(self%source_sink)) allocate(self%source_sink)
      if (.not. associated(self%root_sink)) allocate(self%root_sink)

      self%soil_parameters%parameter_set_id = parameters%parameter_set_id
      self%soil_parameters%active_nodes = n
      if (allocated(self%soil_parameters%z)) then
        if (size(self%soil_parameters%z) /= n) deallocate(self%soil_parameters%z)
      end if
      if (allocated(self%soil_parameters%dz)) then
        if (size(self%soil_parameters%dz) /= n) deallocate(self%soil_parameters%dz)
      end if
      if (allocated(self%soil_parameters%node_distance)) then
        if (size(self%soil_parameters%node_distance) /= n) deallocate(self%soil_parameters%node_distance)
      end if
      if (.not. allocated(self%soil_parameters%z)) allocate(self%soil_parameters%z(n))
      if (.not. allocated(self%soil_parameters%dz)) allocate(self%soil_parameters%dz(n))
      if (.not. allocated(self%soil_parameters%node_distance)) allocate(self%soil_parameters%node_distance(n))
      self%soil_parameters%z = parameters%z
      self%soil_parameters%dz = parameters%dz
      self%soil_parameters%node_distance = parameters%node_distance
      if (self%trusted_prepared_default_mvg .and. associated(self%trusted_parameter_source) .and. &
          prepared_default_mvg_structurally_compatible(parameters)) then
        self%hydraulic_parameters => self%trusted_parameter_source%prepared_default_mvg
      else
        if (prepared_default_mvg_compatible(parameters)) then
          self%owned_hydraulic_parameters = parameters%prepared_default_mvg
        else
          if (parameters%elasticity_active) then
            call initialize_b110_default_mvg_parameters(self%owned_hydraulic_parameters, parameters%cofgen, &
                 enable_ksatexm_extension=parameters%ksatexm_extension_active, &
                 enable_elastic_storage=.true., specific_elastic_storage_input=parameters%cofgen(24,:))
          else
            call initialize_b110_default_mvg_parameters(self%owned_hydraulic_parameters, parameters%cofgen, &
                 enable_ksatexm_extension=parameters%ksatexm_extension_active)
          end if
        end if
        self%hydraulic_parameters => self%owned_hydraulic_parameters
      end if
      self%direct_retention_active = parameters%direct_retention_active
      self%direct_retention_slot = parameters%prepared_direct_retention_slot
      self%bottom_mode = parameters%bottom_mode
      self%swkimpl = parameters%swkimpl
      self%swkmean = parameters%swkmean
      self%max_iterations = parameters%max_iterations
      self%max_backtracking = parameters%max_backtracking
      self%min_step_duration = parameters%min_step_duration
      self%practical_richards_a2c_active = parameters%practical_richards_a2c_active
      self%compartment_balance_tolerance = parameters%compartment_balance_tolerance
      self%total_balance_tolerance = parameters%total_balance_tolerance
      self%head_abs_tolerance = parameters%head_abs_tolerance
      self%head_rel_tolerance = parameters%head_rel_tolerance
      if (self%practical_richards_a2c_active) then
        self%compartment_balance_tolerance = FMR_PRACTICAL_RICHARDS_A2C_TOL
        self%total_balance_tolerance = FMR_PRACTICAL_RICHARDS_A2C_TOL
        self%head_abs_tolerance = FMR_PRACTICAL_RICHARDS_A2C_TOL
        self%head_rel_tolerance = FMR_PRACTICAL_RICHARDS_A2C_TOL
      end if
      self%ponding_tolerance = parameters%ponding_tolerance
      self%root_extraction_active = parameters%root_extraction_active
      self%root_compensation = parameters%root_compensation
      if (self%root_compensation%method < ROOT_COMP_OFF .or. self%root_compensation%method > ROOT_COMP_WALSUM) return
      if (self%root_compensation%method /= ROOT_COMP_OFF .and. .not. self%root_extraction_active) return
      if(allocated(self%bartholomeus)) deallocate(self%bartholomeus)
      if(allocated(parameters%bartholomeus)) self%bartholomeus=parameters%bartholomeus
      self%macropore_active = parameters%macropore_active
      if (allocated(self%macropore_config)) deallocate(self%macropore_config)
      if (parameters%macropore_active .and. allocated(parameters%macropore)) then
        allocate(self%macropore_config)
        self%macropore_config = parameters%macropore
      end if
      self%snow_active = parameters%snow_active
      self%soil_temperature_active = parameters%soil_temperature_active
      self%black_evaporation_active = parameters%black_evaporation_active
      self%black_evaporation_parameters = black_evaporation_parameters_t()
      if (parameters%black_evaporation_active .and. allocated(parameters%black_evaporation)) then
        self%black_evaporation_parameters = parameters%black_evaporation
      end if
      self%boesten_evaporation_active = parameters%boesten_evaporation_active
      self%boesten_evaporation_parameters = boesten_evaporation_parameters_t()
      if (parameters%boesten_evaporation_active .and. allocated(parameters%boesten_evaporation)) then
        self%boesten_evaporation_parameters = parameters%boesten_evaporation
      end if
      self%drainage_response_active = parameters%drainage_response_active
      self%drainage_qbot_smooth_freatic_projection = parameters%drainage_qbot_smooth_freatic_projection
      if (allocated(self%drainage_response_levels)) deallocate(self%drainage_response_levels)
      if (parameters%drainage_response_active .and. allocated(parameters%drainage_response_levels)) then
        allocate(self%drainage_response_levels(size(parameters%drainage_response_levels)))
        self%drainage_response_levels = parameters%drainage_response_levels
      end if
      if (allocated(self%soil_temperature_parameters)) deallocate(self%soil_temperature_parameters)
      if (parameters%soil_temperature_active) then
        allocate(self%soil_temperature_parameters)
        self%soil_temperature_parameters = parameters%soil_temperature
      end if
    class default
      error stop 'F-MR06 serialized backend: unexpected parameter type'
    end select
  end subroutine fmr_serialized_configure_parameters

  subroutine fmr_serialized_prepare_interval(self, forcing, interval, config)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    integer :: n, drainage_preflight_status
    real(real64) :: black_values(9), boesten_values(9)
    self%forcing_admitted = .false.
    if(allocated(self%crop_oxygen)) deallocate(self%crop_oxygen)
    self%hbot5_proposal = fmr_hbot5_proposal_t()
    self%cauchy3_proposal = fmr_cauchy3_proposal_t()
    if (allocated(self%legacy_swbotb5_control)) deallocate(self%legacy_swbotb5_control)
    if (allocated(self%legacy_swbotb3_implicit_control)) deallocate(self%legacy_swbotb3_implicit_control)
    self%macropore_top_input_forcing = fmr_macropore_top_input_forcing_t()
    self%rfm_surface_forcing = rfm_surface_forcing_t()
    self%drainage_response_evaluations = 0
    self%drainage_response_diagnostics = fmr_drainage_response_diagnostics_t()
    self%drainage_response_window_exchange_available = self%drainage_response_active
    self%drainage_response_window_signed_exchange_native = 0.0_real64
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%drainage_response_active = self%drainage_response_active
    self%last_observation%practical_richards_a2c_active = self%practical_richards_a2c_active
    self%last_observation%practical_richards_head_abs_tolerance = self%head_abs_tolerance
    self%last_observation%practical_richards_head_rel_tolerance = self%head_rel_tolerance
    self%last_observation%practical_richards_compartment_balance_tolerance = self%compartment_balance_tolerance
    self%last_observation%practical_richards_total_balance_tolerance = self%total_balance_tolerance
    self%last_observation%temporal_indicator_enabled = self%temporal_indicator_history_enabled
    self%last_observation%fixed_weir_surface_water_active = self%fixed_weir_surface_water_active
    self%last_observation%black_evaporation_active = self%black_evaporation_active
    self%last_observation%boesten_evaporation_active = self%boesten_evaporation_active
    self%trajectory_direction_requested = config%accepted_trajectory_direction%requested
    self%trajectory_control_coordinate = config%accepted_trajectory_direction%control_coordinate
    self%trajectory_requested_t0 = interval%t0
    self%trajectory_requested_t1 = interval%t1
    call configure_trajectory_direction(self%trajectory_direction, &
         self%trajectory_direction_requested .and. self%trajectory_provenance_valid)
    self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available
    self%temporal_indicator_budget_valid = .false.
    if (self%temporal_indicator_budget_supplied) then
      self%temporal_indicator_budget = config%model_temporal_indicator_budget
      if (ieee_is_finite(self%temporal_indicator_budget)) then
        self%temporal_indicator_budget_valid = self%temporal_indicator_budget > 0.0_real64
      end if
    else
      self%temporal_indicator_budget = 0.0_real64
    end if
    self%last_observation%temporal_head_budget_supplied = self%temporal_indicator_budget_supplied
    self%last_observation%temporal_head_budget_valid = self%temporal_indicator_budget_valid
    self%last_observation%temporal_head_budget = self%temporal_indicator_budget
    if (.not. self%temporal_indicator_history_enabled) then
      self%last_observation%temporal_certificate_unavailable_reason = 'history-service-disabled'
    else if (.not. self%temporal_indicator_budget_supplied) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-not-supplied'
    else if (.not. self%temporal_indicator_budget_valid) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-invalid'
    else
      self%last_observation%temporal_certificate_unavailable_reason = 'indicator-not-evaluated'
    end if
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) return
    if (.not. associated(self%soil_parameters)) return
    n = self%soil_parameters%active_nodes
    select type (forcing)
    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%subsurface_irrigation_source) .or. .not. allocated(forcing%root_extraction_sink)) return
      if (size(forcing%subsurface_irrigation_source) /= n .or. size(forcing%root_extraction_sink) /= n) return
      if (self%drainage_response_active) then
        if (allocated(forcing%drainage_flux_by_level) .or. .not. allocated(self%drainage_response_levels) .or. &
            .not. allocated(forcing%drainage_response_controls)) return
        drainage_preflight_status = fmr_drainage_response_configuration_status(self%drainage_response_levels, &
             forcing%drainage_response_controls, n)
        self%drainage_response_diagnostics%status = drainage_preflight_status
        self%last_observation%drainage_response = self%drainage_response_diagnostics
        if (drainage_preflight_status /= FMR_DRAIN_BIND_OK) return
      else
        if (.not. allocated(forcing%drainage_flux_by_level) .or. allocated(forcing%drainage_response_controls)) return
        if (size(forcing%drainage_flux_by_level,1) <= 0 .or. size(forcing%drainage_flux_by_level,2) /= n) return
      end if
      if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return
      if (self%root_compensation%method /= ROOT_COMP_OFF) then
        if (.not. ieee_is_finite(forcing%root_potential_transpiration) .or. forcing%root_potential_transpiration < 0.0_real64) return
        if (.not. ieee_is_finite(forcing%root_drought_reduction_total) .or. forcing%root_drought_reduction_total < 0.0_real64) return
      end if
      if(allocated(self%bartholomeus)) then
        block
          integer :: oxygen_route,waterfilm_mode
          call select_fmr_bartholomeus_route(self%bartholomeus%selection,oxygen_route,waterfilm_mode)
          if(oxygen_route==FMR_BARTHOLOMEUS_ACTIVE) then
            if(.not.allocated(forcing%crop_oxygen)) return
            if(.not.valid_crop_bartholomeus_input(forcing%crop_oxygen,n)) return
            self%crop_oxygen=forcing%crop_oxygen
          else if(oxygen_route/=FMR_BARTHOLOMEUS_DISABLED) then
            return
          end if
        end block
      else
        if(allocated(forcing%crop_oxygen)) return
      end if
      if (self%root_extraction_active) then
        if (any(forcing%root_extraction_sink < 0.0_real64)) return
      else
        if (any(abs(forcing%root_extraction_sink) > 0.0_real64)) return
      end if
      if (allocated(forcing%legacy_swbotb5_control)) then
        if (self%bottom_mode /= 5 .or. .not. self%soil_water_selection%uses_reference()) return
        if (allocated(forcing%legacy_swbotb3_implicit_control) .or. allocated(forcing%legacy_swbotb2_control) .or. &
            allocated(forcing%legacy_swbotb4_qgwl_control)) return
        if (.not. forcing%legacy_swbotb5_control%ready()) return
        allocate(self%legacy_swbotb5_control)
        self%legacy_swbotb5_control = forcing%legacy_swbotb5_control
      end if
      if (allocated(forcing%legacy_swbotb3_implicit_control)) then
        if (self%bottom_mode /= 3 .or. .not. self%soil_water_selection%uses_reference()) return
        if (allocated(forcing%legacy_swbotb5_control) .or. allocated(forcing%legacy_swbotb2_control) .or. &
            allocated(forcing%legacy_swbotb4_qgwl_control)) return
        if (.not. forcing%legacy_swbotb3_implicit_control%ready()) return
        allocate(self%legacy_swbotb3_implicit_control)
        self%legacy_swbotb3_implicit_control = forcing%legacy_swbotb3_implicit_control
      end if
      if (self%bottom_mode == 3 .and. .not. allocated(self%legacy_swbotb3_implicit_control)) return
      if (allocated(forcing%legacy_swbotb4_qgwl_control)) then
        if (allocated(forcing%legacy_swbotb2_control)) return
        if (self%bottom_mode /= 2 .or. .not. self%soil_water_selection%uses_reference()) return
        if (.not. allocated(self%legacy_swbotb4_qgwl_control)) allocate(self%legacy_swbotb4_qgwl_control)
        self%legacy_swbotb4_qgwl_control = forcing%legacy_swbotb4_qgwl_control
      else if (allocated(self%legacy_swbotb4_qgwl_control)) then
        deallocate(self%legacy_swbotb4_qgwl_control)
      end if
      if (allocated(forcing%legacy_swbotb2_control)) then
        if (self%bottom_mode /= 2 .or. .not. self%soil_water_selection%uses_reference()) return
        if (.not. forcing%legacy_swbotb2_control%ready()) return
        if (.not. allocated(self%legacy_swbotb2_control)) allocate(self%legacy_swbotb2_control)
        self%legacy_swbotb2_control = forcing%legacy_swbotb2_control
      else if (allocated(self%legacy_swbotb2_control)) then
        deallocate(self%legacy_swbotb2_control)
      end if
      if (self%snow_active) then
        if (.not. self%snow_event_prepared .or. .not. allocated(forcing%snow)) return
        if (.not. same_real_bits(interval%t0, self%snow_outer_t0) .or. .not. same_real_bits(interval%t1, self%snow_outer_t1)) return
      else
        if (allocated(forcing%snow)) return
      end if
      if (self%soil_temperature_active) then
        if (.not. allocated(forcing%soil_temperature)) return
        if (.not. allocated(self%soil_temperature_forcing)) allocate(self%soil_temperature_forcing)
        self%soil_temperature_forcing = forcing%soil_temperature
      else
        if (allocated(forcing%soil_temperature)) return
        if (allocated(self%soil_temperature_forcing)) deallocate(self%soil_temperature_forcing)
      end if

      self%black_evaporation_forcing = fmr_black_evaporation_runtime_forcing_t()
      if (self%black_evaporation_active) then
        if (.not. allocated(forcing%black_evaporation)) return
        if (forcing%top_flux /= 0.0_real64) return
        black_values = [forcing%black_evaporation%precipitation_rate_cm_per_day, &
             forcing%black_evaporation%irrigation_rate_cm_per_day, &
             forcing%black_evaporation%snowmelt_rate_cm_per_day, &
             forcing%black_evaporation%runon_rate_cm_per_day, &
             forcing%black_evaporation%potential_bare_soil_evaporation_cm_per_day, &
             forcing%black_evaporation%potential_pond_evaporation_cm_per_day, &
             forcing%black_evaporation%ponding_max_cm, forcing%black_evaporation%runoff_resistance_day, &
             forcing%black_evaporation%runoff_exponent]
        if (.not. all(ieee_is_finite(black_values))) return
        if (any(black_values(1:8) < 0.0_real64)) return
        if (forcing%black_evaporation%runoff_exponent /= 1.0_real64) return
        if (forcing%black_evaporation%snowmelt_rate_cm_per_day /= 0.0_real64 .or. &
            forcing%black_evaporation%runon_rate_cm_per_day /= 0.0_real64) return
        if (forcing%black_evaporation%wetting_reset_event) then
          if (.not. ieee_is_finite(forcing%black_evaporation%wetting_event_time)) return
          if (.not. same_real_bits(forcing%black_evaporation%wetting_event_time, interval%t0)) return
        end if
        self%black_evaporation_forcing = forcing%black_evaporation
      else
        if (allocated(forcing%black_evaporation)) return
      end if

      self%boesten_evaporation_forcing = fmr_boesten_evaporation_runtime_forcing_t()
      if (self%boesten_evaporation_active) then
        if (.not. allocated(forcing%boesten_evaporation)) return
        if (allocated(forcing%black_evaporation)) return
        if (forcing%top_flux /= 0.0_real64) return
        boesten_values = [forcing%boesten_evaporation%precipitation_rate_cm_per_day, &
             forcing%boesten_evaporation%irrigation_rate_cm_per_day, &
             forcing%boesten_evaporation%snowmelt_rate_cm_per_day, &
             forcing%boesten_evaporation%runon_rate_cm_per_day, &
             forcing%boesten_evaporation%potential_bare_soil_evaporation_cm_per_day, &
             forcing%boesten_evaporation%potential_pond_evaporation_cm_per_day, &
             forcing%boesten_evaporation%ponding_max_cm, forcing%boesten_evaporation%runoff_resistance_day, &
             forcing%boesten_evaporation%runoff_exponent]
        if (.not. all(ieee_is_finite(boesten_values))) return
        if (any(boesten_values(1:8) < 0.0_real64)) return
        if (forcing%boesten_evaporation%runoff_exponent /= 1.0_real64) return
        if (forcing%boesten_evaporation%snowmelt_rate_cm_per_day /= 0.0_real64 .or. &
            forcing%boesten_evaporation%runon_rate_cm_per_day /= 0.0_real64) return
        self%boesten_evaporation_forcing = forcing%boesten_evaporation
      else
        if (allocated(forcing%boesten_evaporation)) return
      end if

      if (self%drainage_response_active) then
        if (associated(self%qdra)) then
          if (size(self%qdra,1) /= size(self%drainage_response_levels) .or. size(self%qdra,2) /= n) then
            deallocate(self%qdra)
          end if
        end if
        if (.not. associated(self%qdra)) allocate(self%qdra(size(self%drainage_response_levels),n))
        self%qdra = 0.0_real64
        if (allocated(self%drainage_response_controls)) then
          if (size(self%drainage_response_controls) /= size(forcing%drainage_response_controls)) &
               deallocate(self%drainage_response_controls)
        end if
        if (.not. allocated(self%drainage_response_controls)) &
             allocate(self%drainage_response_controls(size(forcing%drainage_response_controls)))
        self%drainage_response_controls = forcing%drainage_response_controls
      else
        if (allocated(self%drainage_response_controls)) deallocate(self%drainage_response_controls)
        if (associated(self%qdra)) then
          if (size(self%qdra,1) /= size(forcing%drainage_flux_by_level,1) .or. size(self%qdra,2) /= n) then
            deallocate(self%qdra)
          end if
        end if
        if (.not. associated(self%qdra)) allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n))
        self%qdra = forcing%drainage_flux_by_level
      end if

      if (associated(self%qssdi)) then
        if (size(self%qssdi) /= n) deallocate(self%qssdi)
      end if
      if (.not. associated(self%qssdi)) allocate(self%qssdi(n))

      if (associated(self%qrot)) then
        if (size(self%qrot) /= n) deallocate(self%qrot)
      end if
      if (.not. associated(self%qrot)) allocate(self%qrot(n))

      if (associated(self%qrot_zero)) then
        if (size(self%qrot_zero) /= n) deallocate(self%qrot_zero)
      end if
      if (.not. associated(self%qrot_zero)) allocate(self%qrot_zero(n))

      self%qssdi = forcing%subsurface_irrigation_source
      self%qrot = forcing%root_extraction_sink
      self%root_potential_transpiration = forcing%root_potential_transpiration
      self%root_drought_reduction_total = forcing%root_drought_reduction_total
      if(allocated(self%root_walsum_geometry)) deallocate(self%root_walsum_geometry)
      if(allocated(forcing%root_walsum_geometry)) self%root_walsum_geometry=forcing%root_walsum_geometry
      if(allocated(self%root_potential_sink)) deallocate(self%root_potential_sink)
      if(allocated(forcing%root_potential_sink)) self%root_potential_sink=forcing%root_potential_sink
      if(allocated(self%crop_oxygen) .or. self%root_compensation%method /= ROOT_COMP_OFF) then
        self%qrot_unmodified=forcing%root_extraction_sink
      else
        if(allocated(self%qrot_unmodified)) deallocate(self%qrot_unmodified)
      end if
      self%qrot_zero = 0.0_real64

      if (self%drainage_qbot_smooth_freatic_projection) then
        if (allocated(self%projection_zero_direction)) then
          if (size(self%projection_zero_direction) /= n) deallocate(self%projection_zero_direction)
        end if
        if (.not. allocated(self%projection_zero_direction)) allocate(self%projection_zero_direction(n))
        self%projection_zero_direction = 0.0_real64
      else if (allocated(self%projection_zero_direction)) then
        deallocate(self%projection_zero_direction)
      end if
      if (self%rfm_configuration%enabled) then
        if (.not. self%rfm_configuration%valid()) return
        if (.not. allocated(forcing%rfm_surface)) return
        if (.not. forcing%rfm_surface%valid()) return
        if (self%macropore_active .or. self%snow_active .or. self%black_evaporation_active .or. &
            self%boesten_evaporation_active .or. self%fixed_weir_surface_water_active) return
        if (allocated(forcing%macropore_top_input)) return
        self%rfm_surface_forcing = forcing%rfm_surface
      else
        if (allocated(forcing%rfm_surface)) return
      end if

      if (allocated(forcing%macropore_top_input)) then
        if (.not. self%macropore_active) return
        if (.not. forcing%macropore_top_input%valid()) return
        if (forcing%macropore_top_input%supplied) then
          if (self%snow_active .or. self%black_evaporation_active .or. self%boesten_evaporation_active .or. &
              self%fixed_weir_surface_water_active) return
        end if
        self%macropore_top_input_forcing = forcing%macropore_top_input
      end if
      self%base_top_flux = forcing%top_flux
      self%top_flux = forcing%top_flux
      if (self%snow_active) self%top_flux = self%base_top_flux - self%snow_melt_rate
      self%top_head = forcing%top_head
      self%bottom_flux = forcing%bottom_flux
      self%bottom_head = forcing%bottom_head
      self%forcing_admitted = .true.
    class default
      return
    end select
  end subroutine fmr_serialized_prepare_interval

  subroutine fmr_serialized_accepted_trajectory_direction_snapshot(self, interval, result)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    type(canonical_interval_t), intent(in) :: interval
    type(accepted_trajectory_direction_result_t), intent(out) :: result
    logical :: finalized

    result = accepted_trajectory_direction_result_t()
    if (.not. self%trajectory_direction_requested) return
    if (.not. self%trajectory_provenance_valid) then
      result%requested = .true.
      result%worker_id = self%trajectory_worker_id
      result%control_coordinate = self%trajectory_control_coordinate
      result%origin_t0 = self%trajectory_requested_t0
      result%accepted_t1 = self%trajectory_requested_t0
      result%route = 'worker-provenance-unavailable'
      return
    end if
    if (.not. same_real_bits(interval%t0, self%trajectory_requested_t0) .or. &
        .not. same_real_bits(interval%t1, self%trajectory_requested_t1)) then
      result%requested = .true.
      result%worker_id = self%trajectory_worker_id
      result%control_coordinate = self%trajectory_control_coordinate
      result%origin_t0 = self%trajectory_requested_t0
      result%accepted_t1 = self%trajectory_direction%current_t1
      result%route = 'canonical-window-mismatch'
      return
    end if
    call finalize_trajectory_direction(self%trajectory_direction, interval%t0, interval%t1, finalized)
    call publish_accepted_trajectory_direction(self%trajectory_direction, result)
  end subroutine fmr_serialized_accepted_trajectory_direction_snapshot

  subroutine populate_snow_observation(self)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    self%last_observation%snow_active = self%snow_active
    self%last_observation%snow_event_prepared = self%snow_event_prepared
    self%last_observation%snow_melt_rate = self%snow_melt_rate
    if (self%snow_active) then
      self%last_observation%snow_status = self%snow_diagnostics%status
      self%last_observation%snow_fluxes = self%snow_fluxes
      self%last_observation%snow_mass = self%snow_diagnostics%mass
    end if
  end subroutine populate_snow_observation

  subroutine populate_fixed_weir_surface_water_observation(self)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    self%last_observation%fixed_weir_surface_water_active = self%fixed_weir_surface_water_active
    if (.not. self%fixed_weir_surface_water_active) return
    self%last_observation%fixed_weir_surface_water_status = self%fixed_weir_surface_water_result%status
    self%last_observation%fixed_weir_surface_water_storage = self%fixed_weir_surface_water_result%candidate_state%storage
    self%last_observation%fixed_weir_surface_water_level = self%fixed_weir_surface_water_result%water_level
    self%last_observation%fixed_weir_surface_water_supply_rate = self%fixed_weir_surface_water_result%supply_rate
    self%last_observation%fixed_weir_surface_water_discharge_rate = self%fixed_weir_surface_water_result%discharge_rate
    self%last_observation%fixed_weir_surface_water_mass_residual = self%fixed_weir_surface_water_result%mass_residual
    self%last_observation%fixed_weir_surface_water_rating_residual = &
         self%fixed_weir_surface_water_result%rating_storage_residual
    self%last_observation%fixed_weir_surface_water_iterations = self%fixed_weir_surface_water_result%bisection_iterations
    self%last_observation%fixed_weir_surface_water_route = self%fixed_weir_surface_water_result%route
  end subroutine populate_fixed_weir_surface_water_observation

  subroutine evaluate_temporal_history_service(self, state, request, solve_result, outcome, ok)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(trial_outcome_t), intent(inout) :: outcome
    logical, intent(out) :: ok
    type(soil_water_temporal_indicator_request_t) :: indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator_result
    real(real64), allocatable :: previous_derivative(:)
    real(real64) :: normalized_indicator
    type(fmr_mode7_head_envelope_assessment_t) :: head_envelope
    logical :: previous_available, replaced
    integer :: n
    ok = .false.
    n = request%parameters%active_nodes
    previous_available = .false.
    select type (physical => state)
    type is (fmr_b110_temporal_indicator_state_t)
      call physical%temporal_history%snapshot(previous_derivative, previous_available)
      if (previous_available) previous_available = size(previous_derivative) == n .and. all(ieee_is_finite(previous_derivative))
    class default
      return
    end select
    indicator_request%previous_right_derivative_available = previous_available
    if (previous_available) then
      allocate(indicator_request%previous_right_derivative(n))
      indicator_request%previous_right_derivative = previous_derivative
    end if
    call self%solver%evaluate_temporal_indicator(request, solve_result, indicator_request, self%workspace, indicator_result)
    self%last_observation%temporal_indicator_enabled = .true.
    self%last_observation%temporal_previous_derivative_available = previous_available
    self%last_observation%temporal_indicator_status = indicator_result%status
    self%last_observation%temporal_indicator_available = indicator_result%available
    self%last_observation%temporal_indicator_route = indicator_result%route
    self%last_observation%temporal_head_inf_bound = indicator_result%head_inf_bound
    self%last_observation%temporal_head_budget_supplied = self%temporal_indicator_budget_supplied
    self%last_observation%temporal_head_budget_valid = self%temporal_indicator_budget_valid
    self%last_observation%temporal_head_budget = self%temporal_indicator_budget
    self%last_observation%temporal_certificate_available = .false.
    self%last_observation%temporal_normalized_indicator = 0.0_real64
    self%last_observation%temporal_additional_tridiagonal_solves = indicator_result%additional_tridiagonal_solves
    self%last_observation%temporal_additional_full_nonlinear_solves = indicator_result%additional_full_nonlinear_solves
    outcome%linear_solves = outcome%linear_solves + indicator_result%additional_tridiagonal_solves
    if (indicator_result%additional_full_nonlinear_solves /= 0) return
    if (.not. allocated(indicator_result%current_right_derivative)) return
    if (size(indicator_result%current_right_derivative) /= n) return
    if (any(.not. ieee_is_finite(indicator_result%current_right_derivative))) return
    select type (physical => state)
    type is (fmr_b110_temporal_indicator_state_t)
      call physical%temporal_history%replace(indicator_result%current_right_derivative, replaced)
      if (.not. replaced) return
    class default
      return
    end select
    self%last_observation%temporal_current_derivative_available = .true.

    if (.not. previous_available) then
      self%last_observation%temporal_certificate_unavailable_reason = 'history-unavailable'
    else if (.not. self%temporal_indicator_budget_supplied) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-not-supplied'
    else if (.not. self%temporal_indicator_budget_valid) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-invalid'
    else if (.not. indicator_result%available) then
      self%last_observation%temporal_certificate_unavailable_reason = 'indicator-unavailable'
    else if (.not. ieee_is_finite(indicator_result%head_inf_bound) .or. indicator_result%head_inf_bound < 0.0_real64) then
      self%last_observation%temporal_certificate_unavailable_reason = 'indicator-invalid'
    else
      if (request%boundary%bottom_mode == 7) then
        call assess_fmr_mode7_temporal_head_envelope(indicator_result%head_inf_bound, &
             self%temporal_indicator_budget, head_envelope)
        if (head_envelope%status == FMR_MODE7_HEAD_ENVELOPE_OK .and. head_envelope%complete) then
          normalized_indicator = head_envelope%normalized_error
        else
          normalized_indicator = huge(0.0_real64)
        end if
      else
        normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget
      end if
      if (ieee_is_finite(normalized_indicator) .and. normalized_indicator >= 0.0_real64) then
        outcome%temporal_certificate_available = .true.
        outcome%temporal_indicator = normalized_indicator
        self%last_observation%temporal_certificate_available = .true.
        self%last_observation%temporal_normalized_indicator = normalized_indicator
        self%last_observation%temporal_certificate_unavailable_reason = 'available'
      else
        self%last_observation%temporal_certificate_unavailable_reason = 'normalized-indicator-invalid'
      end if
    end if
    ok = .true.
  end subroutine evaluate_temporal_history_service

  subroutine fmr_serialized_advance(self, state, t0, t1, outcome)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: solve_result
    type(macropore_runtime_result_t) :: macropore_result
    type(soil_water_accepted_step_direction_result_t) :: direction_result
    type(trajectory_step_token_t) :: direction_token
    type(process_hydraulic_view_t) :: hydraulic_start, hydraulic_end
    type(soil_temperature_state_t) :: soil_temperature_trial
    type(soil_temperature_result_t) :: soil_temperature_result
    type(soil_temperature_diagnostics_t) :: soil_temperature_diagnostics
    type(soil_temperature_field_view_t) :: oxygen_thermal
    type(root_water_uptake_flux_result_t) :: oxygen_base,oxygen_final
    real(real64),allocatable :: oxygen_w_root(:),oxygen_factors(:)
    real(real64),allocatable :: trace_macro_water_start(:,:)
    real(real64) :: atmospheric_ctop
    integer :: oxygen_route,waterfilm_mode,oxygen_status,oxygen_nodes
    logical :: publish_root_result
    type(black_evaporation_forcing_t) :: black_process_forcing
    type(black_evaporation_result_t) :: black_result
    type(boesten_evaporation_forcing_t) :: boesten_process_forcing
    type(boesten_evaporation_result_t) :: boesten_result
    type(rfm_matrix_source_provider_t), target :: rfm_source_provider
    type(rfm_live_trial_prepare_result_t) :: rfm_live
    type(soil_water_top_boundary_result_t) :: rfm_preflight
    real(real64), allocatable, target :: rfm_source_rate(:)
    real(real64), allocatable :: rfm_node_depth_cm(:)
    type(b110_dynamic_top_boundary_solver_provider_t), target :: black_top_provider, boesten_top_provider, rfm_top_provider
    real(real64), allocatable :: drainage_sink_direction(:)
    type(b110_smooth_freatic_projection_diagnostics_t) :: projection_diagnostics
    real(real64) :: step_duration, bottom_temperature_start_c
    real(real64) :: macropore_accepted_top_cm, macropore_rapid_outflow_cm
    real(real64) :: rfm_preferential_input_cm, rfm_deep_receipt_cm
    real(real64) :: step_drainage_exchange
    real(real64) :: fixed_top_conductivity
    real(real64) :: projected_groundwater_level, ignored_groundwater_direction
    real(real64) :: candidate_projected_groundwater_level, drainage_groundwater_direction
    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok, hydraulic_view_ok, rfm_source_ok
    logical :: direct_retention_ok
    logical :: bottom_temperature_start_available, fixed_top_conductivity_ok
    logical :: trajectory_begin_ok, trajectory_request_ok, trajectory_stage_ok, trajectory_accept_ok
    logical :: trajectory_solver_used, rossfast_certificate_available, drainage_direction_available
    real(real64) :: rossfast_temporal_indicator, effective_bottom_flux
    real(real64) :: cauchy3_q4, cauchy3_q4_sample_t1900
    integer :: effective_bottom_mode, swbotb2_status, swbotb4_status, cauchy3_status
    type(fmr_qgwl_bottom_boundary_result_t) :: swbotb4_result
    integer :: soil_temperature_status, bottom_temperature_status, drainage_direction_status, candidate_projection_status
    character(len=64) :: drainage_direction_route
    outcome = trial_outcome_t()
    macropore_accepted_top_cm = 0.0_real64
    macropore_rapid_outflow_cm = 0.0_real64
    rfm_preferential_input_cm = 0.0_real64
    rfm_deep_receipt_cm = 0.0_real64
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%practical_richards_a2c_active = self%practical_richards_a2c_active
    self%last_observation%practical_richards_head_abs_tolerance = self%head_abs_tolerance
    self%last_observation%practical_richards_head_rel_tolerance = self%head_rel_tolerance
    self%last_observation%practical_richards_compartment_balance_tolerance = self%compartment_balance_tolerance
    self%last_observation%practical_richards_total_balance_tolerance = self%total_balance_tolerance
    self%last_observation%soil_temperature_active = self%soil_temperature_active
    self%last_observation%black_evaporation_active = self%black_evaporation_active
    self%last_observation%boesten_evaporation_active = self%boesten_evaporation_active
    self%fixed_weir_surface_water_result = fixed_weir_surface_water_result_t()
    black_result = black_evaporation_result_t()
    boesten_result = boesten_evaporation_result_t()
    self%last_observation%temporal_indicator_enabled = self%temporal_indicator_history_enabled
    self%last_observation%temporal_head_budget_supplied = self%temporal_indicator_budget_supplied
    self%last_observation%temporal_head_budget_valid = self%temporal_indicator_budget_valid
    self%last_observation%temporal_head_budget = self%temporal_indicator_budget
    bottom_temperature_start_c = 0.0_real64
    bottom_temperature_start_available = .false.
    trajectory_begin_ok = .false.
    trajectory_request_ok = .false.
    trajectory_stage_ok = .false.
    trajectory_accept_ok = .false.
    trajectory_solver_used = .false.
    drainage_direction_available = .true.
    drainage_direction_status = FMR_QBOT_DRAIN_DIRECTION_OK
    candidate_projection_status = FMR_QBOT_DRAIN_DIRECTION_OK
    drainage_direction_route = 'not-required'
    if (.not. self%temporal_indicator_history_enabled) then
      self%last_observation%temporal_certificate_unavailable_reason = 'history-service-disabled'
    else if (.not. self%temporal_indicator_budget_supplied) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-not-supplied'
    else if (.not. self%temporal_indicator_budget_valid) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-invalid'
    else
      self%last_observation%temporal_certificate_unavailable_reason = 'indicator-not-evaluated'
    end if
    call populate_snow_observation(self)
    ! Re-enter from the ORIGINAL base root sink for every sibling/retry/step.
    ! qrot is worker scratch. Reducing its previous value would create history.
    if(allocated(self%crop_oxygen)) then
      if(.not.allocated(self%qrot_unmodified) .or. .not.associated(self%qrot)) return
      if(size(self%qrot_unmodified)/=size(self%qrot)) return
      self%qrot=self%qrot_unmodified
    end if
    call populate_fixed_weir_surface_water_observation(self)
    self%last_observation%drainage_response_active = self%drainage_response_active
    self%last_observation%drainage_qbot_projection_active = self%drainage_qbot_smooth_freatic_projection
    snow_event_applied_this_call = .false.
    if (.not. self%forcing_admitted .or. .not. associated(self%soil_parameters) .or. &
        .not. associated(self%hydraulic_parameters) .or. .not. associated(self%constitutive) .or. &
        .not. associated(self%source_sink) .or. .not. associated(self%top_boundary)) return
    if (self%root_extraction_active .and. .not. associated(self%root_sink)) return
    if (.not. state_matches_numerical_continuation_layout(state, self%temporal_indicator_history_enabled, &
                                                           self%macropore_reduction_continuation_enabled, &
                                                           self%fixed_weir_surface_water_active, &
                                                           self%black_evaporation_active, &
                                                           self%boesten_evaporation_active)) return
    step_duration = t1 - t0
    if (step_duration <= 0.0_real64) return
    effective_bottom_mode = self%bottom_mode
    effective_bottom_flux = self%bottom_flux
    if (allocated(self%legacy_swbotb4_qgwl_control)) then
      select type (physical_control => state)
      class is (fmr_b110_physical_state_t)
        call fmr_evaluate_legacy_qgwl_bottom_boundary(self%legacy_swbotb4_qgwl_control, &
             physical_control%groundwater_level, swbotb4_result, swbotb4_status)
        if (swbotb4_status /= FMR_QGWL_OK .or. .not. swbotb4_result%available) return
        effective_bottom_mode = 2
        effective_bottom_flux = swbotb4_result%qbot_cm_per_day
      class default
        return
      end select
    end if
    if (allocated(self%legacy_swbotb2_control)) then
      select type (physical_control => state)
      class is (fmr_b110_physical_state_t)
        if (physical_control%active_nodes <= 0 .or. .not. allocated(physical_control%pressure_head)) return
        if (size(physical_control%pressure_head) < physical_control%active_nodes) return
        call self%legacy_swbotb2_control%evaluate(t0, t1, &
             physical_control%pressure_head(physical_control%active_nodes), effective_bottom_mode, &
             effective_bottom_flux, swbotb2_status)
        if (swbotb2_status /= B110_SWBOTB2_OK) return
      class default
        return
      end select
    end if
    if (self%direct_retention_active) then
      call bind_b110_direct_retention_provider(self%direct_retention_constitutive, self%hydraulic_parameters, &
           step_duration, self%direct_retention_slot, direct_retention_ok)
      if (.not. direct_retention_ok) return
    else
      call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)
    end if
    request%parameters => self%soil_parameters
    request%step_duration = step_duration
    if (self%black_evaporation_active .or. self%boesten_evaporation_active .or. self%rfm_configuration%enabled) then
      request%boundary%top_mode = FSI_TOP_MODE_DYNAMIC_PROVIDER
    else
      request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
      request%boundary%top_flux = self%top_flux
    end if
    request%boundary%bottom_mode = effective_bottom_mode
    request%boundary%top_head = self%top_head
    request%boundary%bottom_flux = effective_bottom_flux
    request%boundary%bottom_head = self%bottom_head
    if (allocated(self%legacy_swbotb3_implicit_control)) then
      if (.not. self%cauchy3_proposal%covers(t0,t1)) return
      call self%legacy_swbotb3_implicit_control%resolve_q4(t0, t1, cauchy3_q4, cauchy3_q4_sample_t1900, cauchy3_status)
      if (cauchy3_status /= FMR_CAUCHY3_OK) return
      request%boundary%bottom_mode = 3
      request%boundary%bottom_head = self%cauchy3_proposal%aquifer_total_head_cm
      request%boundary%bottom_flux = cauchy3_q4
      request%boundary%bottom_external_resistance_days = &
           self%legacy_swbotb3_implicit_control%external_resistance_days()
      request%boundary%bottom_include_half_cell = self%legacy_swbotb3_implicit_control%half_cell_enabled()
      self%last_observation%cauchy3_proposal_available = .true.
      self%last_observation%cauchy3_proposed_t0 = self%cauchy3_proposal%t0
      self%last_observation%cauchy3_proposed_t1 = self%cauchy3_proposal%original_t1
      self%last_observation%cauchy3_head_sample_t1900 = self%cauchy3_proposal%legacy_head_sample_t1900
      self%last_observation%cauchy3_sine_phase_day = self%cauchy3_proposal%sine_phase_day
      self%last_observation%cauchy3_aquifer_head_cm = self%cauchy3_proposal%aquifer_total_head_cm
      self%last_observation%cauchy3_q4_sample_t1900 = cauchy3_q4_sample_t1900
      self%last_observation%cauchy3_q4_cm_per_day = cauchy3_q4
    end if
    if (allocated(self%legacy_swbotb5_control)) then
      if (.not. self%hbot5_proposal%covers(t0,t1)) return
      request%boundary%bottom_head = self%hbot5_proposal%pressure_head_cm
      self%last_observation%hbot5_proposal_available = .true.
      self%last_observation%hbot5_proposed_t0 = self%hbot5_proposal%t0
      self%last_observation%hbot5_proposed_t1 = self%hbot5_proposal%original_t1
      self%last_observation%hbot5_sample_t1900 = self%hbot5_proposal%legacy_sample_t1900
      self%last_observation%hbot5_pressure_head_cm = self%hbot5_proposal%pressure_head_cm
    end if
    request%numerical%max_iterations = self%max_iterations
    request%numerical%max_backtracking = self%max_backtracking
    request%numerical%conductivity_implicit_mode = self%swkimpl
    request%numerical%conductivity_mean_method = self%swkmean
    request%numerical%min_step_duration = self%min_step_duration
    request%numerical%compartment_balance_tolerance = max(self%compartment_balance_tolerance, &
         FMR_REFERENCE_BALANCE_FLOOR_DEPTH_CM / step_duration)
    request%numerical%total_balance_tolerance = max(self%total_balance_tolerance, &
         FMR_REFERENCE_BALANCE_FLOOR_DEPTH_CM / step_duration)
    self%last_observation%effective_reference_compartment_balance_tolerance = &
         request%numerical%compartment_balance_tolerance
    self%last_observation%effective_reference_total_balance_tolerance = &
         request%numerical%total_balance_tolerance
    request%numerical%head_abs_tolerance = self%head_abs_tolerance
    request%numerical%head_rel_tolerance = self%head_rel_tolerance
    request%numerical%ponding_tolerance = self%ponding_tolerance
    if (self%macropore_active .and. allocated(self%macropore_config)) then
      if (allocated(self%macropore_config%matrix_area_fraction)) &
           request%physical%matrix_area_fraction = self%macropore_config%matrix_area_fraction
    end if
    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      if (physical%active_nodes /= self%soil_parameters%active_nodes .or. .not. allocated(physical%pressure_head) .or. &
          .not. allocated(physical%water_content)) return
      if (self%snow_active) then
        if (.not. allocated(physical%snow) .or. .not. self%snow_event_prepared) return
        if (.not. physical%snow%event_applied .or. .not. same_real_bits(physical%snow%event_t0, self%snow_outer_t0)) then
          physical%snow%process = self%snow_candidate
          physical%snow%event_applied = .true.
          physical%snow%event_t0 = self%snow_outer_t0
          snow_event_applied_this_call = .true.
        end if
      else
        if (allocated(physical%snow)) return
      end if
      request%base_state%active_nodes = physical%active_nodes
      allocate(request%base_state%pressure_head(physical%active_nodes), request%base_state%water_content(physical%active_nodes))
      request%base_state%pressure_head = physical%pressure_head
      request%base_state%water_content = physical%water_content
      request%base_state%ponding_depth = physical%ponding_depth
      request%base_state%groundwater_level = physical%groundwater_level
      if (self%macropore_active) then
        if (.not. allocated(physical%macropore) .or. .not. allocated(self%macropore_config)) return
        if (.not. physical%macropore%ready()) return
      else
        if (allocated(physical%macropore)) return
      end if

      if (self%black_evaporation_active) then
        select type (black_physical => state)
        type is (fmr_b110_black_evaporation_state_t)
          black_process_forcing = black_evaporation_forcing_t()
          black_process_forcing%potential_bare_soil_evaporation = &
               self%black_evaporation_forcing%potential_bare_soil_evaporation_cm_per_day
          black_process_forcing%surface_is_ponded = &
               black_physical%ponding_depth > BLACK_EVAP_PONDING_CLASSIFICATION_CM
          black_process_forcing%wetting_reset_event = self%black_evaporation_forcing%wetting_reset_event .and. &
               same_real_bits(t0, self%black_evaporation_forcing%wetting_event_time)
          call evaluate_black_evaporation_reduction(self%black_evaporation_parameters, &
               black_physical%black_evaporation, black_process_forcing, step_duration, black_result)
          self%last_observation%black_evaporation_evaluated = black_result%status == BLACK_EVAP_AVAILABLE
          self%last_observation%black_wetting_reset_applied = black_result%wetting_reset_applied
          self%last_observation%black_ponding_reset_applied = black_result%ponding_reset_applied
          self%last_observation%black_empirical_demand = black_result%empirical_bare_soil_evaporation_demand
          self%last_observation%black_candidate_ldwet = black_result%candidate_state%ldwet
          if (black_result%status /= BLACK_EVAP_AVAILABLE) return
          call evaluate_b110_default_mvg_conductivity(self%hydraulic_parameters, 1, &
               black_physical%pressure_head(1), fixed_top_conductivity, fixed_top_conductivity_ok)
          if (.not. fixed_top_conductivity_ok) return
          call bind_b110_dynamic_top_boundary_solver_provider(black_top_provider, self%soil_parameters, &
               self%hydraulic_parameters, self%swkmean, black_physical%ponding_depth, step_duration, &
               self%black_evaporation_forcing%precipitation_rate_cm_per_day, &
               self%black_evaporation_forcing%irrigation_rate_cm_per_day, &
               self%black_evaporation_forcing%snowmelt_rate_cm_per_day, &
               self%black_evaporation_forcing%runon_rate_cm_per_day, &
               black_result%empirical_bare_soil_evaporation_demand, &
               self%black_evaporation_forcing%potential_pond_evaporation_cm_per_day, &
               self%black_evaporation_forcing%ponding_max_cm, &
               self%black_evaporation_forcing%runoff_resistance_day, &
               self%black_evaporation_forcing%runoff_exponent, fixed_top_conductivity)
          request%evaluation%dynamic_top_boundary => black_top_provider
        class default
          return
        end select
      end if

      if (self%boesten_evaporation_active) then
        select type (boesten_physical => state)
        type is (fmr_b110_boesten_evaporation_state_t)
          boesten_process_forcing = boesten_evaporation_forcing_t()
          boesten_process_forcing%potential_bare_soil_evaporation = &
               self%boesten_evaporation_forcing%potential_bare_soil_evaporation_cm_per_day
          boesten_process_forcing%wetting_rate = self%boesten_evaporation_forcing%precipitation_rate_cm_per_day + &
               self%boesten_evaporation_forcing%irrigation_rate_cm_per_day
          boesten_process_forcing%surface_is_ponded = &
               boesten_physical%ponding_depth > BOESTEN_EVAP_PONDING_CLASSIFICATION_CM
          call evaluate_boesten_evaporation_reduction(self%boesten_evaporation_parameters, &
               boesten_physical%boesten_evaporation, boesten_process_forcing, step_duration, boesten_result)
          self%last_observation%boesten_evaporation_evaluated = boesten_result%status == BOESTEN_EVAP_AVAILABLE
          self%last_observation%boesten_ponding_reset_applied = boesten_result%ponding_reset_applied
          self%last_observation%boesten_empirical_demand = boesten_result%empirical_bare_soil_evaporation_demand
          self%last_observation%boesten_candidate_spev = boesten_result%candidate_state%spev
          self%last_observation%boesten_candidate_saev = boesten_result%candidate_state%saev
          if (boesten_result%status /= BOESTEN_EVAP_AVAILABLE) return
          call evaluate_b110_default_mvg_conductivity(self%hydraulic_parameters, 1, &
               boesten_physical%pressure_head(1), fixed_top_conductivity, fixed_top_conductivity_ok)
          if (.not. fixed_top_conductivity_ok) return
          call bind_b110_dynamic_top_boundary_solver_provider(boesten_top_provider, self%soil_parameters, &
               self%hydraulic_parameters, self%swkmean, boesten_physical%ponding_depth, step_duration, &
               self%boesten_evaporation_forcing%precipitation_rate_cm_per_day, &
               self%boesten_evaporation_forcing%irrigation_rate_cm_per_day, &
               self%boesten_evaporation_forcing%snowmelt_rate_cm_per_day, &
               self%boesten_evaporation_forcing%runon_rate_cm_per_day, &
               boesten_result%empirical_bare_soil_evaporation_demand, &
               self%boesten_evaporation_forcing%potential_pond_evaporation_cm_per_day, &
               self%boesten_evaporation_forcing%ponding_max_cm, &
               self%boesten_evaporation_forcing%runoff_resistance_day, &
               self%boesten_evaporation_forcing%runoff_exponent, fixed_top_conductivity)
          request%evaluation%dynamic_top_boundary => boesten_top_provider
        class default
          return
        end select
      end if

      if (self%soil_temperature_active) then
        if (.not. allocated(physical%soil_temperature) .or. .not. allocated(self%soil_temperature_parameters) .or. &
            .not. allocated(self%soil_temperature_forcing)) return
        if (self%bottom_thermal_carrier_active) then
          call soil_temperature_at_node(physical%soil_temperature, physical%active_nodes, bottom_temperature_start_c, &
               bottom_temperature_status)
          bottom_temperature_start_available = bottom_temperature_status == SOIL_TEMP_OK
        end if
      else
        if (allocated(physical%soil_temperature)) return
      end if
      if (self%soil_temperature_active .or. self%drainage_response_active .or. self%rfm_configuration%enabled) then
        call build_process_hydraulic_view(request%base_state, hydraulic_start, hydraulic_view_ok)
        if (.not. hydraulic_view_ok) return
      end if
      if (self%root_compensation%method /= ROOT_COMP_OFF) then
        if (.not. allocated(self%qrot_unmodified)) return
        self%qrot = self%qrot_unmodified
      end if
      if(allocated(self%bartholomeus)) then
        call select_fmr_bartholomeus_route(self%bartholomeus%selection,oxygen_route,waterfilm_mode)
        if(oxygen_route==FMR_BARTHOLOMEUS_ACTIVE) then
          if(.not.allocated(self%crop_oxygen) .or. .not.allocated(physical%soil_temperature)) return
          call build_soil_temperature_field_view(physical%soil_temperature,oxygen_thermal,oxygen_status)
          if(oxygen_status/=SOIL_TEMP_OK) return
          oxygen_nodes=size(self%crop_oxygen%root_density_kg_m3)
          allocate(oxygen_w_root(oxygen_nodes))
          oxygen_w_root=1.0_real64/self%bartholomeus%specific_root_length_m_kg
          atmospheric_ctop=672.0_real64/(8.314472_real64*(self%crop_oxygen%air_temperature_c+273.0_real64))
          oxygen_base%root_extraction_sink=self%qrot_unmodified
          oxygen_base%actual_uptake_total=sum(self%qrot_unmodified)
          call fmr_apply_bartholomeus_to_root_sink(self%bartholomeus%selection,hydraulic_start,oxygen_thermal, &
               self%bartholomeus%soil,self%bartholomeus%crop,oxygen_w_root, &
               self%crop_oxygen%root_density_kg_m3,atmospheric_ctop,oxygen_base,oxygen_final,oxygen_status,oxygen_factors)
          self%last_observation%bartholomeus_executed=.true.
          self%last_observation%bartholomeus_status=oxygen_status
          self%last_observation%root_oxygen_base_uptake=oxygen_base%actual_uptake_total
          if(oxygen_status/=FMR_BARTHOLOMEUS_EXEC_OK) return
          self%qrot=oxygen_final%root_extraction_sink
          self%last_observation%root_oxygen_final_uptake=oxygen_final%actual_uptake_total
          self%last_observation%root_oxygen_final_sink=oxygen_final%root_extraction_sink
        else if(oxygen_route/=FMR_BARTHOLOMEUS_DISABLED) then
          return
        end if
      end if
      if (self%root_compensation%method /= ROOT_COMP_OFF) then
        block
          type(root_water_uptake_flux_result_t) :: compensation_base, compensation_final
          type(root_water_uptake_diagnostics_t) :: compensation_base_diagnostics
          type(root_compensation_diagnostics_t) :: compensation_diagnostics
          real(real64) :: oxygen_reduction_total
          integer :: compensation_status,attribution_status
          compensation_base%root_extraction_sink = self%qrot
          compensation_base%actual_uptake_total = sum(self%qrot)
          compensation_base_diagnostics%drought_reduction_total = self%root_drought_reduction_total
          oxygen_reduction_total = sum(self%qrot_unmodified)-compensation_base%actual_uptake_total
          if(allocated(oxygen_factors).and.self%root_drought_reduction_total>0.0_real64) then
            ! Mixed stress requires the existing drought owner's potential nodes.
            ! Scalar sequential losses do not reproduce B1.11 apportionment.
            if(.not.allocated(self%root_potential_sink)) return
            if(abs(sum(self%root_potential_sink)-self%root_potential_transpiration)> &
                 256.0_real64*epsilon(1.0_real64)*max(1.0_real64,self%root_potential_transpiration)) return
            call attribute_root_stress_losses(self%root_potential_sink,self%qrot_unmodified,oxygen_factors, &
                 compensation_base_diagnostics%drought_reduction_total,oxygen_reduction_total,attribution_status)
            if(attribution_status/=ROOT_COMP_OK) return
          end if
          call apply_root_uptake_compensation(self%root_compensation,self%root_potential_transpiration, &
               compensation_base,compensation_base_diagnostics,oxygen_reduction_total,compensation_final, &
               compensation_diagnostics,compensation_status,self%root_walsum_geometry,self%soil_parameters%dz)
          self%last_observation%root_compensation_executed=.true.
          self%last_observation%root_compensation_status=compensation_status
          self%last_observation%root_compensation_base_uptake=compensation_base%actual_uptake_total
          if(compensation_status/=ROOT_COMP_EXEC_OK) return
          self%last_observation%root_compensation_drought_loss=compensation_diagnostics%drought_reduction_total
          self%last_observation%root_compensation_oxygen_loss=compensation_diagnostics%oxygen_reduction_total
          self%qrot=compensation_final%root_extraction_sink
          self%last_observation%root_compensation_final_uptake=compensation_final%actual_uptake_total
          self%last_observation%root_compensation_final_sink=compensation_final%root_extraction_sink
        end block
      end if
    class default
      return
    end select

    if (self%drainage_response_active) then
      if (self%drainage_qbot_smooth_freatic_projection) then
        if (.not. allocated(self%projection_zero_direction) .or. &
            size(self%projection_zero_direction) /= hydraulic_start%active_nodes) return
        call evaluate_b110_smooth_freatic_projection(self%bottom_mode, .false., self%soil_parameters%z, &
             self%soil_parameters%node_distance, hydraulic_start%pressure_head, self%projection_zero_direction, &
             projected_groundwater_level, ignored_groundwater_direction, projection_diagnostics)
        if (projection_diagnostics%status /= B110_GWL_PROJECTION_OK .or. &
            .not. projection_diagnostics%value_defined) return
        hydraulic_start%groundwater_level = projected_groundwater_level
        request%base_state%groundwater_level = projected_groundwater_level
        self%last_observation%drainage_qbot_projection_available = .true.
        self%last_observation%drainage_projected_groundwater_level = projected_groundwater_level
      end if
      call evaluate_fmr_drainage_response_bottom_lumped(self%drainage_response_levels, self%drainage_response_controls, &
           hydraulic_start, self%qdra, self%drainage_response_diagnostics)
      self%drainage_response_evaluations = self%drainage_response_evaluations + 1
      self%last_observation%drainage_response_evaluations = self%drainage_response_evaluations
      self%last_observation%drainage_response = self%drainage_response_diagnostics
      if (self%drainage_response_diagnostics%status /= FMR_DRAIN_BIND_OK) return
    end if

    if (self%root_extraction_active) then
      if (.not. associated(self%qrot_zero) .or. size(self%qrot_zero) /= size(self%qrot)) return
      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, self%qrot_zero)
      call bind_b110_root_sink_provider(self%root_sink, self%qrot)
    else
      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, self%qrot)
    end if
    if (self%direct_retention_active) then
      request%evaluation%constitutive => self%direct_retention_constitutive
    else
      request%evaluation%constitutive => self%constitutive
    end if

    if (self%rfm_configuration%enabled) then
      if (self%direct_retention_active) return
      if (.not. self%soil_water_selection%uses_reference()) return
      select type (rfm_physical => state)
      type is (fmr_b110_rfm_state_t)
        if (.not. rfm_physical%rfm%ready()) return
        call bind_b110_dynamic_top_boundary_solver_provider(rfm_top_provider, self%soil_parameters, &
             self%hydraulic_parameters, self%swkmean, rfm_physical%ponding_depth, step_duration, &
             self%rfm_surface_forcing%precipitation_rate_cm_per_day, self%rfm_surface_forcing%irrigation_rate_cm_per_day, &
             self%rfm_surface_forcing%snowmelt_rate_cm_per_day, self%rfm_surface_forcing%runon_rate_cm_per_day, &
             self%rfm_surface_forcing%potential_bare_soil_evaporation_cm_per_day, &
             self%rfm_surface_forcing%potential_pond_evaporation_cm_per_day, self%rfm_surface_forcing%ponding_max_cm, &
             self%rfm_surface_forcing%runoff_resistance_day, self%rfm_surface_forcing%runoff_exponent)
        call rfm_top_provider%evaluate(rfm_physical%pressure_head(1), rfm_physical%water_content(1), &
             rfm_physical%ponding_depth, request%boundary, rfm_preflight)
        allocate(rfm_node_depth_cm(rfm_physical%active_nodes)); rfm_node_depth_cm=abs(self%soil_parameters%z)
        call prepare_rfm_live_trial(rfm_physical%rfm,self%rfm_configuration,self%rfm_surface_forcing,hydraulic_start, &
             self%constitutive,rfm_preflight,rfm_node_depth_cm,self%soil_parameters%dz,step_duration, &
             max(self%compartment_balance_tolerance,FMR_REFERENCE_BALANCE_FLOOR_DEPTH_CM),rfm_live)
        if(.not.rfm_live%valid)return
        rfm_source_rate=rfm_live%candidate%matrix_source_rate_per_day
        call bind_rfm_matrix_source_provider(rfm_source_provider,self%source_sink,rfm_source_rate,rfm_source_ok)
        if(.not.rfm_source_ok)return
        request%evaluation%source_sink=>rfm_source_provider
        rfm_preferential_input_cm=rfm_live%surface%preferential_supply_cm_per_day*step_duration
        rfm_deep_receipt_cm=rfm_live%candidate%deep_receipt_cm
        call bind_b110_dynamic_top_boundary_solver_provider(rfm_top_provider,self%soil_parameters,self%hydraulic_parameters, &
             self%swkmean,rfm_physical%ponding_depth,step_duration,rfm_live%surface%matrix_supply_cm_per_day, &
             0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,self%rfm_surface_forcing%ponding_max_cm, &
             self%rfm_surface_forcing%runoff_resistance_day,self%rfm_surface_forcing%runoff_exponent)
        request%evaluation%dynamic_top_boundary=>rfm_top_provider
      class default
        return
      end select
    else
      request%evaluation%source_sink=>self%source_sink
    end if
    if (self%root_extraction_active) request%evaluation%root_sink => self%root_sink
    if (.not. self%black_evaporation_active .and. .not. self%boesten_evaporation_active) &
         request%evaluation%top_boundary => self%top_boundary

    if (self%soil_water_selection%uses_rossfast()) then
      context_ok = .true.
    else
      call bind_b110_serialized_legacy_context(request, context_ok)
    end if
    if (.not. context_ok) return

    if (self%trajectory_direction_requested .and. self%trajectory_provenance_valid) then
      if (.not. allocated(self%trajectory_direction%pressure_head_direction)) then
        if (self%trajectory_generation_counter >= huge(self%trajectory_generation_counter)) then
          self%trajectory_provenance_valid = .false.
        else
          self%trajectory_generation_counter = self%trajectory_generation_counter + 1_int64
          call begin_or_continue_trajectory(self%trajectory_direction, self%trajectory_worker_id, t0, t1, &
               self%trajectory_control_coordinate, self%soil_parameters%active_nodes, trajectory_begin_ok, &
               generation_seed=self%trajectory_generation_counter)
        end if
      else
        call begin_or_continue_trajectory(self%trajectory_direction, self%trajectory_worker_id, t0, t1, &
             self%trajectory_control_coordinate, self%soil_parameters%active_nodes, trajectory_begin_ok)
      end if
      if (trajectory_begin_ok) then
        call build_trajectory_step_request(self%trajectory_direction, t0, t1, self%trajectory_request_workspace, direction_token, &
             trajectory_request_ok)
      end if
    end if

    if (trajectory_request_ok .and. self%trajectory_request_workspace%requested .and. &
        self%drainage_qbot_smooth_freatic_projection) then
      call compose_fmr_qbot_drainage_sink_direction(self%soil_parameters, request%base_state, &
           self%trajectory_request_workspace%incoming_pressure_head, self%drainage_response_diagnostics, drainage_sink_direction, &
           drainage_groundwater_direction, drainage_direction_status, drainage_direction_route)
      drainage_direction_available = drainage_direction_status == FMR_QBOT_DRAIN_DIRECTION_OK
      if (drainage_direction_available) then
        call move_alloc(drainage_sink_direction, self%trajectory_request_workspace%incoming_sink_direction)
      end if
    end if

    if (self%macropore_active) then
      if (self%soil_water_selection%uses_rossfast() .or. trajectory_request_ok) return
      select type (physical_macro => state)
      type is (fmr_b110_macropore_reduction_state_t)
        if(self%accepted_water_flux_trace_enabled)then
          if(allocated(physical_macro%macropore%water_domain_cp))then
            trace_macro_water_start=physical_macro%macropore%water_domain_cp
          else
            self%accepted_water_flux_trace_failed=.true.
          end if
        end if
        if (self%macropore_config%covering_parameters_available) then
          call self%macropore_runtime%execute(self%solver, self%workspace, request, physical_macro%macropore, &
               self%macropore_config%geometry, self%macropore_config%rate_template, &
               self%macropore_config%history_template, self%macropore_policy, macropore_result, &
               top_input=self%macropore_top_input_forcing, reduction_accepted=physical_macro%reduction_continuation, &
               covering_minimum_polygon_diameter_cm=self%macropore_config%covering_minimum_polygon_diameter_cm, &
               covering_ksat_cm_per_day=self%macropore_config%covering_ksat_cm_per_day)
        else
          call self%macropore_runtime%execute(self%solver, self%workspace, request, physical_macro%macropore, &
               self%macropore_config%geometry, self%macropore_config%rate_template, &
               self%macropore_config%history_template, self%macropore_policy, macropore_result, &
               top_input=self%macropore_top_input_forcing, reduction_accepted=physical_macro%reduction_continuation)
        end if
        if(macropore_result%status==MACRO_RUNTIME_CONVERGED) &
             physical_macro%reduction_continuation=macropore_result%reduction_candidate
      class is (fmr_b110_physical_state_t)
        if(self%accepted_water_flux_trace_enabled)then
          if(allocated(physical_macro%macropore%water_domain_cp))then
            trace_macro_water_start=physical_macro%macropore%water_domain_cp
          else
            self%accepted_water_flux_trace_failed=.true.
          end if
        end if
        if (self%macropore_config%covering_parameters_available) then
          call self%macropore_runtime%execute(self%solver, self%workspace, request, physical_macro%macropore, &
               self%macropore_config%geometry, self%macropore_config%rate_template, &
               self%macropore_config%history_template, self%macropore_policy, macropore_result, &
               top_input=self%macropore_top_input_forcing, &
               covering_minimum_polygon_diameter_cm=self%macropore_config%covering_minimum_polygon_diameter_cm, &
               covering_ksat_cm_per_day=self%macropore_config%covering_ksat_cm_per_day)
        else
          call self%macropore_runtime%execute(self%solver, self%workspace, request, physical_macro%macropore, &
               self%macropore_config%geometry, self%macropore_config%rate_template, &
               self%macropore_config%history_template, self%macropore_policy, macropore_result, &
               top_input=self%macropore_top_input_forcing)
        end if
      class default
        return
      end select
      solve_result = macropore_result%matrix_result
      self%last_observation%macropore_top_input_active = self%macropore_top_input_forcing%supplied
      self%last_observation%macropore_requested_top_cm = macropore_result%requested_top_input_cm
      self%last_observation%macropore_accepted_top_cm = macropore_result%accepted_top_input_cm
      self%last_observation%macropore_returned_surface_cm = macropore_result%returned_surface_cm
      self%last_observation%macropore_rapid_drain_active = self%macropore_config%rate_template%rapid%enabled
      self%last_observation%macropore_rapid_outflow_cm = macropore_result%rapid_external_outflow_cm
      self%last_observation%macropore_inner_richards_exchange_used = macropore_result%inner_richards_exchange_used
      self%last_observation%macropore_inner_initial_exchange_rate_cm_per_day = &
           macropore_result%inner_initial_exchange_rate_cm_per_day
      self%last_observation%macropore_inner_final_exchange_rate_cm_per_day = &
           macropore_result%inner_final_exchange_rate_cm_per_day
      macropore_accepted_top_cm = macropore_result%accepted_top_input_cm
      macropore_rapid_outflow_cm = macropore_result%rapid_external_outflow_cm
      if (.not. ieee_is_finite(macropore_accepted_top_cm) .or. macropore_accepted_top_cm < 0.0_real64) return
      if (.not. ieee_is_finite(macropore_rapid_outflow_cm) .or. macropore_rapid_outflow_cm < 0.0_real64) return
      if (macropore_result%status /= MACRO_RUNTIME_CONVERGED) then
        if (macropore_result%status == MACRO_RUNTIME_RETRY) solve_result%retry_advised = .true.
        return
      end if
    else if (self%soil_water_selection%uses_rossfast()) then
      call self%soil_water_selection%solve(request, solve_result)
    else if (trajectory_request_ok) then
      if (self%drainage_qbot_smooth_freatic_projection .and. .not. drainage_direction_available) then
        call self%solver%solve(request, self%workspace, solve_result)
        direction_result = soil_water_accepted_step_direction_result_t()
        direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
        direction_result%control_coordinate = self%trajectory_request_workspace%control_coordinate
        direction_result%route = drainage_direction_route
      else
        call solve_with_accepted_step_direction(self%solver, request, self%workspace, self%trajectory_request_workspace, &
             solve_result, direction_result)
        trajectory_solver_used = .true.
      end if
      call stage_trajectory_step_result(self%trajectory_direction, direction_token, direction_result, trajectory_stage_ok)
    else
      call self%solver%solve(request, self%workspace, solve_result)
    end if

    self%last_observation%solver_executed = .true.
    self%last_observation%solver_status = solve_result%status
    self%last_observation%top_flux = solve_result%top_flux
    self%last_observation%bottom_flux = solve_result%bottom_flux
    self%last_observation%solver_diagnostics = solve_result%diagnostics
    self%last_observation%solver_equation_residual_available = .false.
    call populate_snow_observation(self)
    outcome%nonlinear_iterations = solve_result%diagnostics%nonlinear_iterations
    outcome%internal_retries = solve_result%diagnostics%internal_retries
    if (self%soil_water_selection%uses_rossfast()) then
      outcome%headcalc_calls = 0
    else
      outcome%headcalc_calls = 1
    end if
    outcome%jacobian_builds = solve_result%diagnostics%jacobian_builds
    outcome%linear_solves = solve_result%diagnostics%linear_solves
    outcome%backtracking_attempts = solve_result%diagnostics%backtracking_attempts
    outcome%alternative_solver_calls = solve_result%diagnostics%alternative_solver_calls
    outcome%workspace_full_resets = solve_result%diagnostics%workspace_full_resets
    outcome%workspace_zeroed_bytes = solve_result%diagnostics%workspace_zeroed_bytes
    if (trajectory_solver_used) then
      outcome%linear_solves = outcome%linear_solves + direction_result%additional_tridiagonal_backsolves
      outcome%jacobian_builds = outcome%jacobian_builds + direction_result%additional_jacobian_builds
      outcome%headcalc_calls = outcome%headcalc_calls + direction_result%additional_full_nonlinear_solves
    end if
    if (solve_result%status /= SW_SOLVE_CONVERGED) return
    if (self%drainage_qbot_smooth_freatic_projection) then
      call project_fmr_qbot_smooth_groundwater_level(self%soil_parameters, solve_result%candidate_state, &
           candidate_projected_groundwater_level, candidate_projection_status, projection_diagnostics)
      if (candidate_projection_status /= FMR_QBOT_DRAIN_DIRECTION_OK) return
      solve_result%candidate_state%groundwater_level = candidate_projected_groundwater_level
    end if
    if (self%soil_water_selection%uses_rossfast()) then
      call self%soil_water_selection%temporal_certificate_snapshot(rossfast_certificate_available, &
           rossfast_temporal_indicator)
      if (.not. rossfast_certificate_available .or. .not. ieee_is_finite(rossfast_temporal_indicator) .or. &
          rossfast_temporal_indicator < 0.0_real64) return
      outcome%temporal_certificate_available = .true.
      outcome%temporal_indicator = rossfast_temporal_indicator
      self%last_observation%temporal_certificate_available = .true.
      self%last_observation%temporal_normalized_indicator = rossfast_temporal_indicator
      self%last_observation%temporal_indicator_route = 'rossfast-model-certificate'
      self%last_observation%temporal_certificate_unavailable_reason = 'available'
    else if (self%temporal_indicator_history_enabled) then
      call evaluate_temporal_history_service(self, state, request, solve_result, outcome, temporal_history_ok)
      if (.not. temporal_history_ok) return
    end if

    if (self%black_evaporation_active) then
      select type (black_physical => state)
      type is (fmr_b110_black_evaporation_state_t)
        if (black_result%status /= BLACK_EVAP_AVAILABLE) return
        black_physical%black_evaporation = black_result%candidate_state
      class default
        return
      end select
    end if

    if (self%boesten_evaporation_active) then
      select type (boesten_physical => state)
      type is (fmr_b110_boesten_evaporation_state_t)
        if (boesten_result%status /= BOESTEN_EVAP_AVAILABLE) return
        boesten_physical%boesten_evaporation = boesten_result%candidate_state
      class default
        return
      end select
    end if

    if (self%fixed_weir_surface_water_active) then
      select type (physical => state)
      type is (fmr_b110_fixed_weir_surface_water_state_t)
        call evaluate_restricted_fixed_weir_surface_water(self%fixed_weir_surface_water_parameters, &
             self%fixed_weir_surface_water_numerical, physical%surface_water, &
             self%fixed_weir_surface_water_forcing, step_duration, self%fixed_weir_surface_water_result)
        call populate_fixed_weir_surface_water_observation(self)
        if (self%fixed_weir_surface_water_result%status /= FIXED_WEIR_AVAILABLE) return
      class default
        return
      end select
    end if
    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      if (self%soil_temperature_active) then
        call build_process_hydraulic_view(solve_result%candidate_state, hydraulic_end, hydraulic_view_ok)
        if (.not. hydraulic_view_ok) return
        call trial_restricted_soil_temperature(self%soil_temperature_parameters, self%soil_temperature_numerical, &
             self%soil_temperature_forcing, hydraulic_start, hydraulic_end, physical%soil_temperature, t0, t1, &
             self%soil_temperature_workspace, soil_temperature_trial, soil_temperature_result, soil_temperature_diagnostics)
        self%last_observation%soil_temperature_executed = .true.
        self%last_observation%soil_temperature_status = soil_temperature_result%status
        self%last_observation%soil_temperature_energy_accounting_complete = soil_temperature_diagnostics%energy_accounting_complete
        self%last_observation%soil_temperature_energy_residual_j_cm2 = soil_temperature_result%energy_residual_j_cm2
        self%last_observation%soil_temperature_top_heat_flux_j_cm2_day = &
             soil_temperature_result%top_heat_flux_into_soil_j_cm2_day
        self%last_observation%soil_temperature_storage_change_j_cm2 = soil_temperature_result%sensible_storage_change_j_cm2
        self%last_observation%soil_temperature_boundary_energy_j_cm2 = soil_temperature_result%boundary_energy_into_soil_j_cm2
        if (soil_temperature_result%status /= SOIL_TEMP_OK .or. .not. soil_temperature_result%produced) return
        call commit_soil_temperature_state(physical%soil_temperature, soil_temperature_trial, soil_temperature_status)
        if (soil_temperature_status /= SOIL_TEMP_OK) then
          self%last_observation%soil_temperature_status = soil_temperature_status
          return
        end if
      else
        if (allocated(physical%soil_temperature)) return
      end if
      if (self%macropore_active) then
        if (.not. allocated(physical%macropore)) return
        physical%macropore = macropore_result%macropore_candidate
      end if
      physical%active_nodes = solve_result%candidate_state%active_nodes
      physical%pressure_head = solve_result%candidate_state%pressure_head
      physical%water_content = solve_result%candidate_state%water_content
      physical%ponding_depth = solve_result%candidate_state%ponding_depth
      physical%groundwater_level = solve_result%candidate_state%groundwater_level
      if(self%rfm_configuration%enabled)then
        select type(rfm_physical=>state)
        type is(fmr_b110_rfm_state_t)
          call copy_rfm_physical_state(rfm_live%candidate%candidate_rfm,rfm_physical%rfm,rfm_source_ok)
          if(.not.rfm_source_ok)return
        class default
          return
        end select
      end if
    class default
      return
    end select
    if (self%fixed_weir_surface_water_active) then
      select type (physical => state)
      type is (fmr_b110_fixed_weir_surface_water_state_t)
        physical%surface_water = self%fixed_weir_surface_water_result%candidate_state
      class default
        return
      end select
    end if
    call account_external_fluxes(self, step_duration, solve_result%top_flux, solve_result%bottom_flux, &
         snow_event_applied_this_call, macropore_accepted_top_cm, macropore_rapid_outflow_cm, &
         outcome%mass_in, outcome%mass_out)
    if(self%rfm_configuration%enabled)then
      outcome%mass_in=outcome%mass_in+rfm_preferential_input_cm
      outcome%mass_out=outcome%mass_out+rfm_deep_receipt_cm
    end if
    if (self%drainage_response_active) then
      self%last_observation%drainage_response_mass_accounted_in_trial = .true.
      step_drainage_exchange = self%drainage_response_diagnostics%aggregate%signed_soil_to_drain_rate * step_duration
      self%last_observation%drainage_response_signed_exchange_native = step_drainage_exchange
      if (self%drainage_response_window_exchange_available .and. ieee_is_finite(step_drainage_exchange)) then
        self%drainage_response_window_signed_exchange_native = &
             self%drainage_response_window_signed_exchange_native + step_drainage_exchange
        if (.not. ieee_is_finite(self%drainage_response_window_signed_exchange_native)) then
          self%drainage_response_window_exchange_available = .false.
          self%drainage_response_window_signed_exchange_native = 0.0_real64
        end if
      else
        self%drainage_response_window_exchange_available = .false.
      end if
      self%last_observation%drainage_response_window_exchange_available = &
           self%drainage_response_window_exchange_available
      self%last_observation%drainage_response_window_signed_exchange_native = &
           self%drainage_response_window_signed_exchange_native
    end if
    outcome%bottom_outward_exchange_native = -solve_result%bottom_flux * step_duration
    outcome%terminal_bottom_outward_flux_native = -solve_result%bottom_flux
    if (.not. ieee_is_finite(outcome%bottom_outward_exchange_native) .or. &
        .not. ieee_is_finite(outcome%terminal_bottom_outward_flux_native)) then
      outcome%bottom_outward_exchange_native = 0.0_real64
      outcome%terminal_bottom_outward_flux_native = 0.0_real64
      return
    end if
    publish_root_result=self%root_compensation%method/=ROOT_COMP_OFF
    if(allocated(self%bartholomeus)) then
      call select_fmr_bartholomeus_route(self%bartholomeus%selection,oxygen_route,waterfilm_mode)
      publish_root_result=publish_root_result.or.oxygen_route==FMR_BARTHOLOMEUS_ACTIVE
    end if
    if(self%root_extraction_active.and.publish_root_result) then
      outcome%actual_transpiration_amount=sum(self%qrot)*step_duration
      if(.not.ieee_is_finite(outcome%actual_transpiration_amount).or.outcome%actual_transpiration_amount<0.0_real64) return
      outcome%actual_transpiration_available=.true.
    end if
    outcome%bottom_interface_exchange_available = .true.
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    if (self%bottom_thermal_carrier_active .and. self%bottom_thermal_carrier_valid) then
      call record_bottom_thermal_sample(self, state, t0, t1, outcome%bottom_outward_exchange_native, &
           bottom_temperature_start_c, bottom_temperature_start_available)
    end if
    if (self%top_sensible_boundary_carrier_active .and. self%top_sensible_boundary_carrier_valid) then
      call record_top_sensible_boundary_sample(self, t0, t1, solve_result%top_flux * step_duration)
    end if
    if (trajectory_stage_ok) then
      call accept_trajectory_step(self%trajectory_direction, trajectory_accept_ok)
    end if
    if (self%accepted_water_flux_trace_enabled) then
      if (self%macropore_active) then
        if (.not. allocated(macropore_result%exchange_rate_node) .or. &
            .not. allocated(macropore_result%exchange_rate_domain_cp) .or. &
            .not. allocated(macropore_result%vertical_flux%vertical_face_rate) .or. &
            macropore_result%requested_top_input_cm /= 0.0_real64 .or. &
            macropore_accepted_top_cm /= 0.0_real64 .or. macropore_result%returned_surface_cm /= 0.0_real64 .or. &
            macropore_result%covered_internal_transfer_cm /= 0.0_real64 .or. macropore_rapid_outflow_cm /= 0.0_real64) then
          self%accepted_water_flux_trace_failed = .true.
        else if (.not. append_accepted_water_flux_substep(self,request,solve_result,t0,t1, &
             macropore_result%exchange_rate_node,macropore_result%exchange_rate_domain_cp,trace_macro_water_start, &
             macropore_result%macropore_candidate%water_domain_cp, &
             macropore_result%vertical_flux%vertical_face_rate)) then
          self%accepted_water_flux_trace_failed = .true.
        end if
      else if (.not. append_accepted_water_flux_substep(self,request,solve_result,t0,t1)) then
        self%accepted_water_flux_trace_failed = .true.
      end if
    end if
    outcome%solver_ok = .true.
  end subroutine fmr_serialized_advance

  logical function append_accepted_water_flux_substep(self,request,solve_result,t0,t1,macropore_exchange, &
       macropore_exchange_domain,macropore_water_start,macropore_water_end,macropore_vertical_face_rate) result(ok)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    real(real64), intent(in) :: t0,t1
    real(real64), intent(in), optional :: macropore_exchange(:)
    real(real64), intent(in), optional :: macropore_exchange_domain(:,:)
    real(real64), intent(in), optional :: macropore_water_start(:,:),macropore_water_end(:,:)
    real(real64), intent(in), optional :: macropore_vertical_face_rate(:,:)
    type(fmr_water_flux_substep_trace_t), allocatable :: grown(:)
    type(fmr_water_flux_substep_trace_t) :: step
    integer :: n, prior

    ok = .false.
    if (.not. associated(self%qssdi) .or. .not. associated(self%qdra) .or. .not. associated(self%qrot)) return
    n = request%base_state%active_nodes
    if (n <= 0 .or. size(self%qssdi) /= n .or. size(self%qdra,2) /= n .or. size(self%qrot) /= n) return
    if (solve_result%status /= SW_SOLVE_CONVERGED .or. solve_result%candidate_state%active_nodes /= n) return
    if (.not. allocated(solve_result%candidate_state%water_content) .or. &
        .not. allocated(request%base_state%water_content)) return
    if (size(solve_result%candidate_state%water_content) /= n .or. size(request%base_state%water_content) /= n) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    if (.not. ieee_is_finite(solve_result%top_flux) .or. .not. ieee_is_finite(solve_result%bottom_flux)) return
    if (any(.not. ieee_is_finite(self%qssdi)) .or. any(.not. ieee_is_finite(self%qrot)) .or. &
        any(.not. ieee_is_finite(self%qdra))) return

    step%t0 = t0
    step%t1 = t1
    step%top_flux = solve_result%top_flux
    step%bottom_flux = solve_result%bottom_flux
    step%water_start = request%base_state%water_content
    step%water_end = solve_result%candidate_state%water_content
    step%subsurface_source = self%qssdi
    step%drainage_sink = sum(self%qdra,dim=1)
    step%drainage_sink_by_level = self%qdra
    step%root_sink = self%qrot
    allocate(step%macropore_matrix_exchange(n))
    allocate(step%macropore_matrix_exchange_domain(0,n))
    allocate(step%macropore_water_start(0,n),step%macropore_water_end(0,n))
    allocate(step%macropore_vertical_face_rate(0,n+1))
    step%macropore_matrix_exchange = 0.0_real64
    if(present(macropore_exchange_domain))then
      if(size(macropore_exchange_domain,2)/=n .or. size(macropore_exchange_domain,1)<=0 .or. &
         any(.not.ieee_is_finite(macropore_exchange_domain)))return
      if(.not.present(macropore_exchange))return
      if(.not.present(macropore_water_start).or..not.present(macropore_water_end))return
      if(.not.present(macropore_vertical_face_rate))return
      if(any(shape(macropore_water_start)/=shape(macropore_exchange_domain)) .or. &
         any(shape(macropore_water_end)/=shape(macropore_exchange_domain)))return
      if(any(shape(macropore_vertical_face_rate)/= &
           [size(macropore_exchange_domain,1),size(macropore_exchange_domain,2)+1]))return
      if(any(.not.ieee_is_finite(macropore_water_start)).or.any(.not.ieee_is_finite(macropore_water_end)))return
      if(any(.not.ieee_is_finite(macropore_vertical_face_rate)))return
      if(any(macropore_water_start<0.0_real64).or.any(macropore_water_end<0.0_real64))return
      if(maxval(abs(sum(macropore_exchange_domain,dim=1)-macropore_exchange))> &
         1.0e-12_real64*max(1.0_real64,maxval(abs(macropore_exchange))))return
      step%macropore_matrix_exchange_domain=macropore_exchange_domain
      step%macropore_water_start=macropore_water_start
      step%macropore_water_end=macropore_water_end
      step%macropore_vertical_face_rate=macropore_vertical_face_rate
      if(maxval(abs((macropore_water_end-macropore_water_start)/(t1-t0) - &
           (macropore_vertical_face_rate(:,1:n)-macropore_vertical_face_rate(:,2:n+1)- &
           macropore_exchange_domain)))>1.0e-12_real64*max(1.0_real64, &
           maxval(abs(macropore_vertical_face_rate)),maxval(abs(macropore_exchange_domain))))return
    end if
    if (present(macropore_exchange)) then
      if (size(macropore_exchange) /= n .or. any(.not. ieee_is_finite(macropore_exchange))) return
      step%macropore_matrix_exchange = macropore_exchange
    end if
    step%net_node_source = step%subsurface_source - step%drainage_sink - step%root_sink + &
         step%macropore_matrix_exchange
    if (any(.not. ieee_is_finite(step%water_start)) .or. any(.not. ieee_is_finite(step%water_end)) .or. &
        any(.not. ieee_is_finite(step%net_node_source))) return

    prior = 0
    if (allocated(self%accepted_water_flux_substeps)) prior = size(self%accepted_water_flux_substeps)
    allocate(grown(prior+1))
    if (prior > 0) grown(1:prior) = self%accepted_water_flux_substeps
    grown(prior+1) = step
    call move_alloc(grown,self%accepted_water_flux_substeps)
    ok = .true.
  end function append_accepted_water_flux_substep

  logical function accepted_water_flux_trace_covers(steps,t0,t1) result(ok)
    type(fmr_water_flux_substep_trace_t), intent(in) :: steps(:)
    real(real64), intent(in) :: t0,t1
    real(real64) :: cursor,tolerance
    integer :: i,n

    ok = .false.
    if (size(steps) <= 0 .or. .not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    cursor = t0
    tolerance = 128.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(t0),abs(t1))
    do i=1,size(steps)
      n = 0
      if (allocated(steps(i)%water_start)) n=size(steps(i)%water_start)
      if (n <= 0 .or. .not. allocated(steps(i)%water_end) .or. &
          .not. allocated(steps(i)%subsurface_source) .or. .not. allocated(steps(i)%drainage_sink) .or. &
          .not. allocated(steps(i)%drainage_sink_by_level) .or. .not. allocated(steps(i)%root_sink) .or. .not. allocated(steps(i)%macropore_matrix_exchange) .or. &
          .not. allocated(steps(i)%macropore_matrix_exchange_domain) .or. &
          .not. allocated(steps(i)%macropore_water_start) .or. .not. allocated(steps(i)%macropore_water_end) .or. &
          .not. allocated(steps(i)%macropore_vertical_face_rate) .or. &
          .not. allocated(steps(i)%net_node_source)) return
      if (size(steps(i)%water_end)/=n .or. size(steps(i)%subsurface_source)/=n .or. &
          size(steps(i)%drainage_sink)/=n .or. size(steps(i)%drainage_sink_by_level,2)/=n .or. &
          size(steps(i)%drainage_sink_by_level,1)<=0 .or. size(steps(i)%root_sink)/=n .or. &
          size(steps(i)%macropore_matrix_exchange)/=n .or. &
          size(steps(i)%macropore_matrix_exchange_domain,2)/=n .or. &
          size(steps(i)%net_node_source)/=n) return
      if(any(.not.ieee_is_finite(steps(i)%drainage_sink_by_level)))return
      if(maxval(abs(sum(steps(i)%drainage_sink_by_level,dim=1)-steps(i)%drainage_sink))> &
           1.0e-12_real64*max(1.0_real64,maxval(abs(steps(i)%drainage_sink))))return
      if(any(shape(steps(i)%macropore_water_start)/=shape(steps(i)%macropore_matrix_exchange_domain)) .or. &
         any(shape(steps(i)%macropore_water_end)/=shape(steps(i)%macropore_matrix_exchange_domain)))return
      if(any(shape(steps(i)%macropore_vertical_face_rate)/= &
           [size(steps(i)%macropore_matrix_exchange_domain,1),n+1]))return
      if(any(.not.ieee_is_finite(steps(i)%macropore_water_start)) .or. &
         any(.not.ieee_is_finite(steps(i)%macropore_water_end)) .or. &
         any(steps(i)%macropore_water_start<0.0_real64) .or. any(steps(i)%macropore_water_end<0.0_real64))return
      if(any(.not.ieee_is_finite(steps(i)%macropore_vertical_face_rate)))return
      if(size(steps(i)%macropore_matrix_exchange_domain,1)>0)then
        if(any(.not.ieee_is_finite(steps(i)%macropore_matrix_exchange_domain)))return
        if(maxval(abs(sum(steps(i)%macropore_matrix_exchange_domain,dim=1)- &
             steps(i)%macropore_matrix_exchange))>1.0e-12_real64* &
             max(1.0_real64,maxval(abs(steps(i)%macropore_matrix_exchange))))return
        if(maxval(abs((steps(i)%macropore_water_end-steps(i)%macropore_water_start)/ &
             (steps(i)%t1-steps(i)%t0) - &
             (steps(i)%macropore_vertical_face_rate(:,1:n)-steps(i)%macropore_vertical_face_rate(:,2:n+1)- &
             steps(i)%macropore_matrix_exchange_domain)))>1.0e-12_real64*max(1.0_real64, &
             maxval(abs(steps(i)%macropore_vertical_face_rate)), &
             maxval(abs(steps(i)%macropore_matrix_exchange_domain))))return
      else if(any(abs(steps(i)%macropore_matrix_exchange)>1.0e-14_real64))then
        return
      end if
      if (.not. ieee_is_finite(steps(i)%t0) .or. .not. ieee_is_finite(steps(i)%t1) .or. &
          steps(i)%t1 <= steps(i)%t0 .or. abs(steps(i)%t0-cursor)>tolerance) return
      cursor = steps(i)%t1
    end do
    ok = abs(cursor-t1) <= tolerance
  end function accepted_water_flux_trace_covers

  subroutine record_bottom_thermal_sample(self, state, t0, t1, outward_exchange, start_temperature_c, &
                                          start_temperature_available)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64), intent(in) :: t0, t1, outward_exchange, start_temperature_c
    logical, intent(in) :: start_temperature_available
    real(real64) :: end_temperature_c
    integer :: temperature_status
    logical :: appended

    if (.not. self%bottom_thermal_carrier_active .or. .not. self%bottom_thermal_carrier_valid) return
    appended = .false.
    if (outward_exchange > 0.0_real64) then
      if (.not. start_temperature_available) then
        self%bottom_thermal_carrier_valid = .false.
        return
      end if
      select type (physical => state)
      class is (fmr_b110_physical_state_t)
        if (.not. allocated(physical%soil_temperature)) then
          self%bottom_thermal_carrier_valid = .false.
          return
        end if
        call soil_temperature_at_node(physical%soil_temperature, physical%active_nodes, end_temperature_c, temperature_status)
        if (temperature_status /= SOIL_TEMP_OK) then
          self%bottom_thermal_carrier_valid = .false.
          return
        end if
      class default
        self%bottom_thermal_carrier_valid = .false.
        return
      end select
      call self%bottom_thermal_carrier%append_local(t0, t1, outward_exchange, start_temperature_c, end_temperature_c, appended)
    else if (outward_exchange < 0.0_real64) then
      call self%bottom_thermal_carrier%append_external_incomplete(t0, t1, outward_exchange, appended)
    else
      call self%bottom_thermal_carrier%append_zero(t0, t1, appended)
    end if
    if (.not. appended) self%bottom_thermal_carrier_valid = .false.
  end subroutine record_bottom_thermal_sample

  subroutine record_top_sensible_boundary_sample(self, t0, t1, top_exchange_native)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1, top_exchange_native
    logical :: appended

    if (.not. self%top_sensible_boundary_carrier_active .or. &
        .not. self%top_sensible_boundary_carrier_valid) return
    call self%top_sensible_boundary_carrier%append(t0, t1, top_exchange_native, &
         self%last_observation%soil_temperature_energy_accounting_complete, &
         self%last_observation%soil_temperature_boundary_energy_j_cm2, &
         self%last_observation%soil_temperature_storage_change_j_cm2, &
         self%last_observation%soil_temperature_energy_residual_j_cm2, appended)
    if (.not. appended) self%top_sensible_boundary_carrier_valid = .false.
  end subroutine record_top_sensible_boundary_sample

  subroutine account_external_fluxes(self, step_duration, solver_top_flux, bottom_flux, snow_event_applied, &
                                     macropore_accepted_top_cm, macropore_rapid_outflow_cm, total_in, total_out)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    real(real64), intent(in) :: step_duration, solver_top_flux, bottom_flux, macropore_accepted_top_cm, &
         macropore_rapid_outflow_cm
    logical, intent(in) :: snow_event_applied
    real(real64), intent(out) :: total_in, total_out
    integer :: i, level
    real(real64) :: value, external_top_flux
    external_top_flux = solver_top_flux
    if (self%snow_active) external_top_flux = self%base_top_flux
    total_in = max(0.0_real64, -external_top_flux) * step_duration + max(0.0_real64, bottom_flux) * step_duration + &
         macropore_accepted_top_cm
    total_out = max(0.0_real64, external_top_flux) * step_duration + max(0.0_real64, -bottom_flux) * step_duration + &
         macropore_rapid_outflow_cm
    do i = 1, size(self%qssdi)
      value = self%qssdi(i) * step_duration
      if (value >= 0.0_real64) then
        total_in = total_in + value
      else
        total_out = total_out - value
      end if
    end do
    if (self%fixed_weir_surface_water_active) then
      total_in = total_in + self%fixed_weir_surface_water_result%supply_rate * step_duration
      total_out = total_out + self%fixed_weir_surface_water_result%discharge_rate * step_duration
    else
      do level = 1, size(self%qdra,1)
        do i = 1, size(self%qdra,2)
          value = self%qdra(level,i) * step_duration
          if (value >= 0.0_real64) then
            total_out = total_out + value
          else
            total_in = total_in - value
          end if
        end do
      end do
    end if
    do i = 1, size(self%qrot)
      value = self%qrot(i) * step_duration
      if (value >= 0.0_real64) then
        total_out = total_out + value
      else
        total_in = total_in - value
      end if
    end do
    if (self%snow_active .and. snow_event_applied) then
      total_in = total_in + self%snow_diagnostics%mass%snowfall_external_in + self%snow_diagnostics%mass%rain_external_in
      total_out = total_out + self%snow_diagnostics%mass%sublimation_external_out
    end if
  end subroutine account_external_fluxes

  real(real64) function fmr_serialized_storage(self, state) result(value)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. associated(self%soil_parameters)) error stop 'F-MR06 storage requested before parameter binding'
    select type (physical => state)
    type is (fmr_b110_rfm_state_t)
      if (.not. allocated(physical%water_content)) error stop 'PPA-WU05-A20 RFM matrix storage incomplete'
      if (allocated(physical%macropore) .or. allocated(physical%snow) .or. allocated(physical%soil_temperature)) &
           error stop 'PPA-WU05-A20 RFM carrier mixed optional state'
      if (.not. physical%rfm%ready()) error stop 'PPA-WU05-A20 RFM fast storage incomplete'
      value = sum(self%soil_parameters%dz * physical%water_content) + physical%ponding_depth + &
           physical%rfm%storage_cm()
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      if (.not. self%fixed_weir_surface_water_active) error stop 'F-PM08D7 inactive model with fixed-weir state'
      if (.not. allocated(physical%water_content)) error stop 'F-MR06 physical storage state incomplete'
      if (allocated(physical%snow)) error stop 'F-PM08D7 fixed-weir state may not carry snow'
      value = sum(self%soil_parameters%dz * physical%water_content) + physical%ponding_depth + &
           physical%surface_water%storage
    class is (fmr_b110_physical_state_t)
      if (self%fixed_weir_surface_water_active) error stop 'F-PM08D7 active model missing fixed-weir state'
      if (.not. allocated(physical%water_content)) error stop 'F-MR06 physical storage state incomplete'
      if (self%macropore_active) then
        if (.not. allocated(self%macropore_config)) error stop 'F-MR06 active macropore config missing'
        if (.not. allocated(self%macropore_config%matrix_area_fraction)) error stop 'F-MR06 active macropore area fraction missing'
        value = sum(self%soil_parameters%dz * physical%water_content * self%macropore_config%matrix_area_fraction) + &
             physical%ponding_depth
      else
        value = sum(self%soil_parameters%dz * physical%water_content) + physical%ponding_depth
      end if
      if (self%macropore_active) then
        if (.not. allocated(physical%macropore) .or. .not. physical%macropore%ready()) &
             error stop 'F-MR06 active macropore storage state incomplete'
        value = value + sum(physical%macropore%water_domain_cp)
      end if
      if (self%snow_active) then
        if (.not. allocated(physical%snow)) error stop 'F-MR06 active snow storage state incomplete'
        value = value + physical%snow%process%snow_water_storage
      end if
    class default
      error stop 'F-MR06 physical storage type mismatch'
    end select
  end function fmr_serialized_storage

  subroutine fmr_serialized_storage_accounting_status(self, state, complete, missing_mask)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    if (.not. associated(self%soil_parameters)) return
    select type (physical => state)
    type is (fmr_b110_rfm_state_t)
      complete = physical%active_nodes == self%soil_parameters%active_nodes .and. &
           allocated(physical%pressure_head) .and. allocated(physical%water_content) .and. &
           .not. allocated(physical%macropore) .and. .not. allocated(physical%snow) .and. &
           .not. allocated(physical%soil_temperature) .and. physical%rfm%ready()
      if (complete) complete = size(physical%pressure_head) == physical%active_nodes .and. &
           size(physical%water_content) == physical%active_nodes
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      if (.not. self%fixed_weir_surface_water_active) return
      complete = physical%active_nodes == self%soil_parameters%active_nodes .and. allocated(physical%pressure_head) .and. &
           allocated(physical%water_content) .and. .not. allocated(physical%snow) .and. &
           ieee_is_finite(physical%surface_water%storage)
      if (complete) complete = size(physical%pressure_head) == physical%active_nodes .and. &
           size(physical%water_content) == physical%active_nodes
    class is (fmr_b110_physical_state_t)
      if (self%fixed_weir_surface_water_active) return
      complete = physical%active_nodes == self%soil_parameters%active_nodes .and. allocated(physical%pressure_head) .and. &
           allocated(physical%water_content) .and. allocated(self%soil_parameters%dz)
      if (complete) complete = size(self%soil_parameters%dz) == self%soil_parameters%active_nodes
      if (complete) complete = size(physical%pressure_head) == physical%active_nodes .and. &
           size(physical%water_content) == physical%active_nodes
      if (complete .and. self%macropore_active) then
        complete = allocated(self%macropore_config)
        if (complete) complete = allocated(self%macropore_config%matrix_area_fraction)
        if (complete) complete = size(self%macropore_config%matrix_area_fraction) == physical%active_nodes
        if (complete) complete = allocated(physical%macropore)
        if (complete) complete = physical%macropore%ready() .and. &
             physical%macropore%num_nodes == physical%active_nodes
      end if
      if (complete .and. .not. self%macropore_active) complete = .not. allocated(physical%macropore)
      if (complete .and. self%snow_active) complete = allocated(physical%snow)
      if (complete .and. .not. self%snow_active) complete = .not. allocated(physical%snow)
      if (complete .and. self%soil_temperature_active) then
        complete = allocated(self%soil_temperature_parameters)
        if (complete) complete = self%soil_temperature_parameters%ready()
        if (complete) complete = self%soil_temperature_parameters%node_count() == physical%active_nodes
        if (complete) complete = allocated(physical%soil_temperature)
        if (complete) complete = physical%soil_temperature%ready() .and. &
             physical%soil_temperature%node_count() == physical%active_nodes
      end if
      if (complete .and. .not. self%soil_temperature_active) complete = .not. allocated(physical%soil_temperature)
    class default
      complete = .false.
    end select
    if (complete) missing_mask = TX_MASS_MISSING_NONE
  end subroutine fmr_serialized_storage_accounting_status

  real(real64) function fmr_serialized_temporal_identity(self, full_state, half_state) result(value)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    logical :: same
    if (self%bottom_mode /= 7 .and. self%bottom_mode /= -2 .and. self%bottom_mode /= 5 .and. &
        self%bottom_mode /= 2 .and. self%bottom_mode /= 8) then
      value = huge(0.0_real64)
      return
    end if

    select type (full => full_state)
    type is (fmr_b110_rfm_state_t)
      value = huge(0.0_real64)
      select type (half => half_state)
      type is (fmr_b110_rfm_state_t)
        if (base_physical_states_identical(full,half) .and. full%rfm%same_values(half%rfm)) value = 0.0_real64
      class default
      end select
      return
    class default
    end select

    if (self%fixed_weir_surface_water_active) then
      value = huge(0.0_real64)
      select type (full => full_state)
      type is (fmr_b110_fixed_weir_surface_water_state_t)
        select type (half => half_state)
        type is (fmr_b110_fixed_weir_surface_water_state_t)
          same = base_physical_states_identical(full, half)
          if (same .and. ieee_is_finite(full%surface_water%storage) .and. &
              ieee_is_finite(half%surface_water%storage)) then
            value = abs(full%surface_water%storage - half%surface_water%storage)
          end if
        class default
          return
        end select
      class default
        return
      end select
      return
    end if

    if (self%macropore_active) then
      value = fmr_macropore_physical_temporal_error(self, full_state, half_state)
      return
    end if

    same = .false.
    select type (full => full_state)
    class is (fmr_b110_physical_state_t)
      select type (half => half_state)
      class is (fmr_b110_physical_state_t)
        if (full%active_nodes == half%active_nodes .and. allocated(full%pressure_head) .and. allocated(half%pressure_head) .and. &
            allocated(full%water_content) .and. allocated(half%water_content)) then
          same = size(full%pressure_head) == size(half%pressure_head) .and. size(full%water_content) == size(half%water_content)
          if (same) same = all(full%pressure_head == half%pressure_head) .and. all(full%water_content == half%water_content) .and. &
                           full%ponding_depth == half%ponding_depth .and. full%groundwater_level == half%groundwater_level
          if (same) same = allocated(full%snow) .eqv. allocated(half%snow)
          if (same) same = allocated(full%soil_temperature) .eqv. allocated(half%soil_temperature)
          if (same) same = allocated(full%macropore) .eqv. allocated(half%macropore)
          if (same .and. allocated(full%macropore)) same = full%macropore%same_values(half%macropore)
          ! F-MR39 deliberately does not introduce a new combined water/thermal
          ! timestep tolerance. Thermal temporal refinement remains qualified by
          ! F-VQ58; the existing Richards temporal acceptance route is preserved.
          if (same .and. allocated(full%snow)) then
            same = full%snow%process%snow_water_storage == half%snow%process%snow_water_storage .and. &
                   full%snow%process%liquid_water_storage == half%snow%process%liquid_water_storage .and. &
                   full%snow%event_applied .eqv. half%snow%event_applied .and. full%snow%event_t0 == half%snow%event_t0
          end if
        end if
      end select
    end select
    if (same) then
      value = 0.0_real64
    else
      value = huge(0.0_real64)
    end if
  end function fmr_serialized_temporal_identity

  real(real64) function fmr_macropore_physical_temporal_error(self, full_state, half_state) result(value)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    integer :: n

    value = huge(0.0_real64)
    if (.not. self%macropore_active .or. .not. associated(self%soil_parameters)) return

    select type (full => full_state)
    class is (fmr_b110_physical_state_t)
      select type (half => half_state)
      class is (fmr_b110_physical_state_t)
        if (full%active_nodes /= half%active_nodes .or. full%active_nodes /= self%soil_parameters%active_nodes) return
        n = full%active_nodes
        if (n <= 0) return
        if (.not. allocated(full%pressure_head) .or. .not. allocated(half%pressure_head) .or. &
            .not. allocated(full%water_content) .or. .not. allocated(half%water_content)) return
        if (size(full%pressure_head) /= n .or. size(half%pressure_head) /= n .or. &
            size(full%water_content) /= n .or. size(half%water_content) /= n) return
        if (.not. allocated(full%macropore) .or. .not. allocated(half%macropore)) return
        if (.not. full%macropore%ready() .or. .not. half%macropore%ready()) return
        if (full%macropore%num_nodes /= n .or. half%macropore%num_nodes /= n .or. &
            full%macropore%num_domains /= half%macropore%num_domains) return
        ! ICpBtDm is discrete topology, not a continuous centimetre-scale
        ! coordinate. A full/half topology mismatch therefore fails closed.
        if (any(full%macropore%icp_bottom_domain /= half%macropore%icp_bottom_domain)) return

        value = 0.0_real64
        value = max(value, maxval(abs(full%pressure_head-half%pressure_head)))
        value = max(value, abs(full%ponding_depth-half%ponding_depth))
        value = max(value, abs(full%groundwater_level-half%groundwater_level))
        if (allocated(self%macropore_config) .and. allocated(self%macropore_config%matrix_area_fraction)) then
          value = max(value, maxval(abs((full%water_content-half%water_content)*self%soil_parameters%dz * &
               self%macropore_config%matrix_area_fraction)))
        else
          value = max(value, maxval(abs((full%water_content-half%water_content)*self%soil_parameters%dz)))
        end if
        value = max(value, maxval(abs(full%macropore%water_domain_cp-half%macropore%water_domain_cp)))
        value = max(value, maxval(abs(full%macropore%volume_domain_cp-half%macropore%volume_domain_cp)))
        value = max(value, maxval(abs(full%macropore%dynamic_volume_cp-half%macropore%dynamic_volume_cp)))
      class default
        return
      end select
    class default
      return
    end select
  end function fmr_macropore_physical_temporal_error

  logical function base_physical_states_identical(full, half) result(same)
    class(fmr_b110_physical_state_t), intent(in) :: full, half
    same = .false.
    if (full%active_nodes /= half%active_nodes) return
    if (.not. allocated(full%pressure_head) .or. .not. allocated(half%pressure_head)) return
    if (.not. allocated(full%water_content) .or. .not. allocated(half%water_content)) return
    if (size(full%pressure_head) /= size(half%pressure_head) .or. &
        size(full%water_content) /= size(half%water_content)) return
    same = all(full%pressure_head == half%pressure_head) .and. &
         all(full%water_content == half%water_content) .and. &
         full%ponding_depth == half%ponding_depth .and. &
         full%groundwater_level == half%groundwater_level
    if (.not. same) return
    same = allocated(full%snow) .eqv. allocated(half%snow)
    if (same .and. allocated(full%snow)) then
      same = full%snow%process%snow_water_storage == half%snow%process%snow_water_storage .and. &
           full%snow%process%liquid_water_storage == half%snow%process%liquid_water_storage .and. &
           (full%snow%event_applied .eqv. half%snow%event_applied) .and. &
           full%snow%event_t0 == half%snow%event_t0
    end if
  end function base_physical_states_identical

  pure elemental logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits


  subroutine b110_swbotb2_initialize_sine(self, canonical_origin_time, legacy_t1900_origin, &
                                           calendar_year_start_t1900, sinave, sinamp, sinmax, status)
    class(b110_legacy_swbotb2_application_control_t), intent(inout) :: self
    real(real64), intent(in) :: canonical_origin_time, legacy_t1900_origin
    real(real64), intent(in) :: calendar_year_start_t1900(:)
    real(real64), intent(in) :: sinave, sinamp, sinmax
    integer, intent(out) :: status

    call clear_control(self)
    status = B110_SWBOTB2_INVALID_CONTROL
    if (.not. ieee_is_finite(canonical_origin_time) .or. .not. ieee_is_finite(legacy_t1900_origin)) return
    if (.not. ieee_is_finite(sinave) .or. .not. ieee_is_finite(sinamp) .or. .not. ieee_is_finite(sinmax)) return
    if (sinave < -10.0_real64 .or. sinave > 10.0_real64) return
    if (sinamp < -10.0_real64 .or. sinamp > 10.0_real64) return
    if (sinmax < 0.0_real64 .or. sinmax > 366.0_real64) return
    if (size(calendar_year_start_t1900) < 2) return
    if (any(.not. ieee_is_finite(calendar_year_start_t1900))) return
    if (.not. strictly_increasing(calendar_year_start_t1900)) return

    self%sw2 = B110_SWBOTB2_SINE
    self%canonical_origin_time = canonical_origin_time
    self%legacy_t1900_origin = legacy_t1900_origin
    self%sinave = sinave
    self%sinamp = sinamp
    self%sinmax = sinmax
    allocate(self%calendar_year_start_t1900(size(calendar_year_start_t1900)))
    self%calendar_year_start_t1900 = calendar_year_start_t1900
    self%initialized = .true.
    status = B110_SWBOTB2_OK
  end subroutine b110_swbotb2_initialize_sine

  subroutine b110_swbotb2_initialize_table(self, canonical_origin_time, legacy_t1900_origin, &
                                            table_t1900, table_qbot, status)
    class(b110_legacy_swbotb2_application_control_t), intent(inout) :: self
    real(real64), intent(in) :: canonical_origin_time, legacy_t1900_origin
    real(real64), intent(in) :: table_t1900(:), table_qbot(:)
    integer, intent(out) :: status

    call clear_control(self)
    status = B110_SWBOTB2_INVALID_CONTROL
    if (.not. ieee_is_finite(canonical_origin_time) .or. .not. ieee_is_finite(legacy_t1900_origin)) return
    if (size(table_t1900) <= 0 .or. size(table_t1900) /= size(table_qbot)) return
    if (any(.not. ieee_is_finite(table_t1900)) .or. any(.not. ieee_is_finite(table_qbot))) return
    if (size(table_t1900) > 1) then
      if (.not. strictly_increasing(table_t1900)) return
    end if
    if (any(table_qbot < -100.0_real64) .or. any(table_qbot > 100.0_real64)) return

    self%sw2 = B110_SWBOTB2_TABLE
    self%canonical_origin_time = canonical_origin_time
    self%legacy_t1900_origin = legacy_t1900_origin
    allocate(self%table_t1900(size(table_t1900)), self%table_qbot(size(table_qbot)))
    self%table_t1900 = table_t1900
    self%table_qbot = table_qbot
    self%initialized = .true.
    status = B110_SWBOTB2_OK
  end subroutine b110_swbotb2_initialize_table

  logical function b110_swbotb2_ready(self) result(ok)
    class(b110_legacy_swbotb2_application_control_t), intent(in) :: self

    ok = self%initialized .and. ieee_is_finite(self%canonical_origin_time) .and. &
         ieee_is_finite(self%legacy_t1900_origin)
    if (.not. ok) return

    select case (self%sw2)
    case (B110_SWBOTB2_SINE)
      ok = allocated(self%calendar_year_start_t1900)
      if (.not. ok) return
      ok = size(self%calendar_year_start_t1900) >= 2 .and. &
           all(ieee_is_finite(self%calendar_year_start_t1900)) .and. &
           strictly_increasing(self%calendar_year_start_t1900) .and. &
           ieee_is_finite(self%sinave) .and. ieee_is_finite(self%sinamp) .and. ieee_is_finite(self%sinmax) .and. &
           self%sinave >= -10.0_real64 .and. self%sinave <= 10.0_real64 .and. &
           self%sinamp >= -10.0_real64 .and. self%sinamp <= 10.0_real64 .and. &
           self%sinmax >= 0.0_real64 .and. self%sinmax <= 366.0_real64
    case (B110_SWBOTB2_TABLE)
      ok = allocated(self%table_t1900) .and. allocated(self%table_qbot)
      if (.not. ok) return
      ok = size(self%table_t1900) > 0 .and. size(self%table_t1900) == size(self%table_qbot) .and. &
           all(ieee_is_finite(self%table_t1900)) .and. all(ieee_is_finite(self%table_qbot)) .and. &
           all(self%table_qbot >= -100.0_real64) .and. all(self%table_qbot <= 100.0_real64)
      if (ok .and. size(self%table_t1900) > 1) ok = strictly_increasing(self%table_t1900)
    case default
      ok = .false.
    end select
  end function b110_swbotb2_ready

  subroutine b110_swbotb2_evaluate(self, substep_t0, substep_t1, bottom_pressure_head_cm, &
                                    effective_bottom_mode, bottom_flux, status)
    class(b110_legacy_swbotb2_application_control_t), intent(in) :: self
    real(real64), intent(in) :: substep_t0, substep_t1, bottom_pressure_head_cm
    integer, intent(out) :: effective_bottom_mode
    real(real64), intent(out) :: bottom_flux
    integer, intent(out) :: status

    real(real64) :: legacy_start_t1900, legacy_end_t1900, legacy_t, twopi, freq
    integer :: iyear

    effective_bottom_mode = 0
    bottom_flux = 0.0_real64
    status = B110_SWBOTB2_INVALID_CONTROL
    if (.not. self%ready()) return
    if (.not. ieee_is_finite(substep_t0) .or. .not. ieee_is_finite(substep_t1) .or. &
        substep_t1 <= substep_t0 .or. .not. ieee_is_finite(bottom_pressure_head_cm)) return

    ! Exact B1.11 BoundBottom guard. Internal -2 is derived from the current
    ! trial-start state and is deliberately not persisted as application state.
    if (bottom_pressure_head_cm < B110_SWBOTB2_DRY_HEAD_CM) then
      effective_bottom_mode = -2
      status = B110_SWBOTB2_OK
      return
    end if

    effective_bottom_mode = 2
    legacy_start_t1900 = self%legacy_t1900_origin + (substep_t0 - self%canonical_origin_time)
    legacy_end_t1900 = self%legacy_t1900_origin + (substep_t1 - self%canonical_origin_time)
    if (.not. ieee_is_finite(legacy_start_t1900) .or. .not. ieee_is_finite(legacy_end_t1900)) then
      effective_bottom_mode = 0
      status = B110_SWBOTB2_INVALID_CONTROL
      return
    end if

    select case (self%sw2)
    case (B110_SWBOTB2_SINE)
      iyear = containing_year(self%calendar_year_start_t1900, legacy_start_t1900)
      if (iyear <= 0) then
        effective_bottom_mode = 0
        status = B110_SWBOTB2_TIME_NOT_COVERED
        return
      end if
      legacy_t = legacy_start_t1900 - self%calendar_year_start_t1900(iyear)
      twopi = 8.0_real64 * atan(1.0_real64)
      freq = twopi / 365.0_real64
      bottom_flux = self%sinave + self%sinamp * cos(freq * (legacy_t - self%sinmax))
    case (B110_SWBOTB2_TABLE)
      bottom_flux = afgen_pairs(self%table_t1900, self%table_qbot, legacy_end_t1900)
    case default
      effective_bottom_mode = 0
      status = B110_SWBOTB2_INVALID_CONTROL
      return
    end select

    if (.not. ieee_is_finite(bottom_flux)) then
      effective_bottom_mode = 0
      bottom_flux = 0.0_real64
      status = B110_SWBOTB2_INVALID_CONTROL
      return
    end if
    status = B110_SWBOTB2_OK
  end subroutine b110_swbotb2_evaluate

  subroutine clear_control(self)
    class(b110_legacy_swbotb2_application_control_t), intent(inout) :: self

    self%initialized = .false.
    self%sw2 = 0
    self%canonical_origin_time = 0.0_real64
    self%legacy_t1900_origin = 0.0_real64
    self%sinave = 0.0_real64
    self%sinamp = 0.0_real64
    self%sinmax = 0.0_real64
    if (allocated(self%calendar_year_start_t1900)) deallocate(self%calendar_year_start_t1900)
    if (allocated(self%table_t1900)) deallocate(self%table_t1900)
    if (allocated(self%table_qbot)) deallocate(self%table_qbot)
  end subroutine clear_control

  pure logical function strictly_increasing(values) result(ok)
    real(real64), intent(in) :: values(:)
    integer :: i

    ok = .true.
    do i = 2, size(values)
      if (values(i) <= values(i-1)) then
        ok = .false.
        return
      end if
    end do
  end function strictly_increasing

  pure integer function containing_year(year_starts, value) result(index)
    real(real64), intent(in) :: year_starts(:), value
    integer :: i

    index = 0
    do i = 1, size(year_starts) - 1
      if (value >= year_starts(i) .and. value < year_starts(i+1)) then
        index = i
        return
      end if
    end do
  end function containing_year

  pure real(real64) function afgen_pairs(x_table, y_table, x) result(value)
    real(real64), intent(in) :: x_table(:), y_table(:), x
    real(real64) :: slope
    integer :: i

    if (x <= x_table(1) .or. size(x_table) == 1) then
      value = y_table(1)
      return
    end if
    do i = 2, size(x_table)
      if (x <= x_table(i)) then
        slope = (y_table(i) - y_table(i-1)) / (x_table(i) - x_table(i-1))
        value = y_table(i-1) + (x - x_table(i-1)) * slope
        return
      end if
    end do
    value = y_table(size(y_table))
  end function afgen_pairs

end module mod_fmr_serialized_reference_backend

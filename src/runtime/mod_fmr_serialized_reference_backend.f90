Warning: truncated output (original token count: 61368)
Total output lines: 4233

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

  ! Resolved mobile-solution concentrations at the matrix and macropore soil
  ! interfaces. The supplying boundary owner is responsible for surface-pool
  ! mixing and schedules the fixed values over this validity interval.
  type, public :: fmr_soil_salt_boundary_forcing_t
    logical :: available = .false.
    real(real64) :: matrix_top_mg_cm3 = 0.0_real64, matrix_bottom_mg_cm3 = 0.0_real64
    real(real64), allocatable :: macropore_top_mg_cm3(:), macropore_bottom_mg_cm3(:)
    real(real64) :: valid_t0 = 0.0_real64, valid_t1 = 0.0_real64
    integer(int64) :: source_id = 0_int64, revision = -1_int64
    integer :: unit_id = 0
  end type fmr_soil_salt_boundary_forcing_t

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
    type(fmr_soil_salt_boundary_forcing_t), allocatable :: soil_salt_boundary
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
  public :: fmr_soil_salt_boundary_matches_trial
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

  pure logical function fmr_soil_salt_boundary_matches_trial(forcing, forcing_handle,t0,t1,active_domains) result(valid)
    type(fmr_soil_salt_boundary_forcing_t),intent(in)::forcing
    integer(int64),intent(in)::forcing_handle
    real(real64),intent(in)::t0,t1
    integer,intent(in),optional::active_domains
    integer::nd
    valid=.false.
    if(.not.forcing%available.or.forcing%unit_id/=FMR_C_DRAIN_UNIT_MG_CM3)return
    if(forcing_handle<=0_int64.or.forcing%source_id/=forcing_handle.or.forcing%revision<0_int64)return
    if(.not.all(ieee_is_finite([forcing%matrix_top_mg_cm3,forcing%matrix_bottom_mg_cm3, &
         forcing%valid_t0,forcing%valid_t1,t0,t1])))return
    if(min(forcing%matrix_top_mg_cm3,forcing%matrix_bottom_mg_cm3)<0.0_real64)return
    if(t1<=t0.or.forcing%valid_t1<=forcing%valid_t0.or.forcing%valid_t0>t0.or.forcing%valid_t1<t1)return
    if(present(active_domains))then
      nd=active_domains
      if(nd<=0.or..not.allocated(forcing%macropore_top_mg_cm3).or. &
         .not.allocated(forcing%macropore_bottom_mg_cm3))return
      if(size(forcing%macropore_top_mg_cm3)/=nd.or.size(forcing%macropore_bottom_mg_cm3)/=nd)return
      if(any(.not.ieee_is_finite(forcing%macropore_top_mg_cm3)).or. &
         any(.not.ieee_is_finite(forcing%macropore_bottom_mg_cm3)))return
      if(any(forcing%macropore_top_mg_cm3<0.0_real64).or.any(forcing%macropore_bottom_mg_cm3<0.0_real64))return
    else
      if(allocated(forcing%macropore_top_mg_cm3).or.allocated(forcing%macropore_bottom_mg_cm3))return
    end if
    valid=.true.
  end function fmr_soil_salt_boundary_matches_trial

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
    if (parameters%prepared_default_mvg%elas…37368 tokens truncated…t_certificate_available, &
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

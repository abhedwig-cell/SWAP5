program test_ppa_free_drainage_owner
  use, intrinsic :: iso_c_binding, only: c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_commit_receipt_record_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, fmr_committed_top_state_t, FMR_APP_BOOT_OK, FMR_APP_BOOT_PROFILE_NOT_ADMITTED
  use mod_fmr_production_application_bootstrap, only: fmr_committed_hydraulic_state_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fmr_groundwater_application_c_api, only: fgc49d_context_counts_c
  use mod_ppa_atm02_typed_meteo_ingestion, only: ppa_atm02_decoded_daily_meteo_t, ppa_atm02_generic_interval_t, &
       ppa_atm02_meteo_provenance_t
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_site_t, pmdirect_swetr0_canopy_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_result_t, B110_DYN_TOP_AVAILABLE, &
       B110_DYN_TOP_REGIME_FLUX
  use mod_ppa_wu04c_dynamic_top_forcing_adapter, only: bind_ppa_wu04c_dynamic_top_to_effective_forcing, &
       PPA_WU04C_TOP_FORCING_OK, PPA_WU04C_TOP_FORCING_REJECTED
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t, vonhhbraden_parameters_t, &
       vonhhbraden_result_t, evaluate_vonhhbraden_source_window, VONHHBRADEN_AVAILABLE
  use mod_ppa_wu04c_production_forcing_adapter, only: ppa_wu04c_production_forcing_diagnostics_t, &
       materialize_ppa_wu04c_production_forcing, PPA_WU04C_PRODUCTION_FORCING_OK
  use mod_gash_interception, only: gash_parameters_t, evaluate_gash_source_window
  use mod_ppa_wu04d_production_forcing_adapter, only: ppa_wu04d_production_forcing_diagnostics_t, &
       materialize_ppa_wu04d_production_forcing, PPA_WU04D_PRODUCTION_FORCING_OK
  use mod_ppa_atm02_pmdirect_production_forcing_adapter, only: ppa_atm02_production_forcing_diagnostics_t, &
       materialize_ppa_atm02_pmdirect_production_forcing, PPA_ATM02_PRODUCTION_FORCING_OK
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_temporal_indicator_state_t
  use mod_fmr_vonhhbraden_source_window_progress, only: fmr_vonhhbraden_source_window_progress_t, &
       fmr_vonhhbraden_source_window_restart_t, fmr_initialize_vonhhbraden_source_window_progress, &
       fmr_restore_vonhhbraden_source_window_progress, FMR_VONHHBRADEN_PROGRESS_OK
  use mod_ppa_wu04c_runtime_publication, only: publish_ppa_wu04c_accepted_progress, PPA_WU04C_PUBLICATION_OK
  use mod_ppa_free_drainage_temporal_indicator, only: evaluate_free_drainage_temporal_indicator
  use mod_ppa_mvg_storage_binding, only: evaluate_mvg_storage_difference_service
  use mod_ppa_forcing_event_derivative, only: evaluate_forcing_event_derivative
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: SW_SOLVE_CONVERGED
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_runtime_core, only: FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  implicit none

  integer, parameter :: NTILE = 2
  real(real64), parameter :: T0 = 4100.1875_real64
  real(real64), parameter :: T1 = 4100.6875_real64
  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: HARD_MASS_GATE = 1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT = 1.0e-6_real64
  type(gash_parameters_t),parameter :: WINDOW_GASH = gash_parameters_t( &
       0.10_real64,0.05_real64,0.10_real64,0.05_real64,0.40_real64)

  type(fmr_production_application_config_t) :: config, root_config, gw_config, bad_config, root_bad_config, drainage_bad_config
  type(fmr_production_application_bootstrap_t) :: app, root_app, gw_app, bad_app, root_bad_app, drainage_bad_app
  type(fmr_serialized_column_result_t), allocatable :: results(:)
  type(fmr_b110_physical_forcing_t), allocatable :: atm02_forcing(:)
  type(fmr_b110_physical_forcing_t) :: wu04c_forcing
  type(b110_dynamic_top_boundary_result_t) :: wu04c_top
  type(groundwater_topology_tile_t) :: topology_tiles(NTILE)
  type(groundwater_topology_cell_t) :: topology_cells(NTILE)
  type(groundwater_topology_t) :: topology
  type(groundwater_tile_predictor_input_t) :: predictors(NTILE)
  type(groundwater_cell_area_input_t) :: areas(NTILE)
  integer(int64), allocatable :: revisions(:)
  integer(int64) :: context_handle
  integer :: i, status, topology_status
  integer(c_int) :: ncell, ntile_count, c_status
  real(real64) :: reference_head_m
  character(len=32) :: test_scope
  integer :: observed_event_calls=0
  logical :: is_gash=.false.
  logical :: capture_low_rain=.false.
  type(soil_water_solve_request_t) :: low_rain_request
  type(soil_water_temporal_indicator_request_t) :: low_rain_history

  call initialize_application_config(config)
  config%free_drainage_indicator => traced_indicator
  config%numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  config%numerical%transaction%max_retries = 16
  config%numerical%max_committed_substeps = 16384
  config%numerical%model_temporal_indicator_budget_available = .true.
  config%numerical%model_temporal_indicator_budget = 1.0e-5_real64
  do i=1,NTILE
    config%tiles(i)%parameters%max_iterations = 40
    config%tiles(i)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    allocate(config%tiles(i)%initial_right_derivative(numnod))
    config%tiles(i)%initial_right_derivative = 0.0_real64
  end do
  call get_command_argument(1,test_scope)
  if(trim(test_scope)=='--hydraulic-copy'.or.trim(test_scope)=='--irrigation-source'.or. &
       trim(test_scope)=='--irrigation-half-source') then
    if(trim(test_scope)/='--hydraulic-copy') then
      config%storage_difference => evaluate_mvg_storage_difference_service
      config%numerical%transaction%retry_scale=0.8_real64
      config%numerical%transaction%max_retries=64
      do i=1,NTILE
        config%tiles(i)%base_forcing%top_flux=0.0_real64
        call seed_initial_derivative(config%tiles(i)%parameters,config%tiles(i)%initial_state, &
             config%tiles(i)%base_forcing,config%tiles(i)%initial_right_derivative)
      end do
    end if
    call verify_hydraulic_copy(config)
    write(*,'(a)') 'PPA_OWNER_HYDRAULIC_COPY=PASS'
    stop
  end if
  if(trim(test_scope)=='--atm02'.or.trim(test_scope)=='--atm02-events'.or.trim(test_scope)=='--atm02-dense') then
    config%storage_difference => evaluate_mvg_storage_difference_service
    config%numerical%transaction%retry_scale=0.8_real64
    config%numerical%transaction%max_retries=64
    call verify_atm02_owner(config,trim(test_scope)/='--atm02')
    if(trim(test_scope)=='--atm02-dense') write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_ATM02_DENSE=PASS'
    if(trim(test_scope)=='--atm02-events') write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_ATM02_EVENTS=PASS'
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_ATM02=PASS'
    stop
  end if
  is_gash=trim(test_scope)=='--gash-windows'.or.trim(test_scope)=='--gash-branch-rejection'
  if(trim(test_scope)=='--gash-receipts') config%storage_difference => evaluate_mvg_storage_difference_service
  if(trim(test_scope)=='--stable-storage'.or.trim(test_scope)=='--stable-guards'.or.trim(test_scope)=='--stable-receipts') &
       config%storage_difference => evaluate_mvg_storage_difference_service
  if(trim(test_scope)=='--stable-windows'.or.trim(test_scope)=='--window-rejection'.or. &
       is_gash) then
    config%storage_difference => evaluate_mvg_storage_difference_service
    ! A forcing discontinuity can require smaller first steps, not a larger error budget.
    config%numerical%transaction%max_retries=24
  end if
  if(trim(test_scope)=='--guards'.or.trim(test_scope)=='--stable-guards') then
    call verify_opt_in_guards(config)
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_GUARDS=PASS'
    stop
  end if
  call verify_wu04c_production_composition(config)
  write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_COMPOSITION=PASS'
contains
  subroutine verify_hydraulic_copy(profile)
    use mod_ppa_irrigation_source_binding, only: bind_ppa_irrigation_source,evaluate_ppa_irrigation_source, &
         evaluate_ppa_profile_irrigation_source
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
    use mod_ppa_irrigation_event_state, only: ppa_irrigation_event_state_t,PPA_IRRIGATION_EVENT_LAYOUT, &
         build_irrigation_event_candidate
    use mod_fmr_serialized_reference_backend, only: fmr_b110_temporal_indicator_state_t
    use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
    use mod_transaction_reference, only: transaction_state_t
    use mod_irrigation_process
    use mod_ppa_irr_dcs1_composition, only: evaluate_profile_scheduled_irrigation
    use mod_process_hydraulic_view, only: process_hydraulic_view_t
    type(fmr_production_application_config_t),intent(in)::profile
    type(fmr_production_application_bootstrap_t)::owner,fresh_owner
    type(fmr_committed_hydraulic_state_t),allocatable::copied(:),again(:),midpoint_state(:)
    type(fmr_committed_restart_bundle_t)::bundle,midpoint_bundle
    integer::code,tile,original_status
    logical::ok
    logical::history_available,clone_history_available
    type(ppa_irrigation_event_state_t)::carrier,invalid_carrier
    type(ppa_irrigation_event_state_t),allocatable::assembled
    type(fmr_template_t)::event_template
    class(transaction_state_t),allocatable::carrier_copy
    real(real64),allocatable::history(:),clone_history(:)
    type(scheduled_irrigation_parameters_t)::irrigation
    type(scheduled_irrigation_request_t)::request
    type(irrigation_state_t)::base,candidate
    type(irrigation_flux_result_t)::flux
    type(irrigation_diagnostics_t)::diagnostics
    type(process_hydraulic_view_t)::hydraulic
    real(real64)::selected_amount(NTILE),expected,thickness
    real(real64)::midpoint,first_half_in(NTILE)
    integer::pass
    type(fmr_b110_physical_forcing_t)::irrigation_forcing(NTILE)
    type(fmr_b110_physical_forcing_t)::control_forcing(NTILE)
    type(fmr_b110_physical_forcing_t),allocatable::bound_forcing
    type(fmr_serialized_column_result_t),allocatable::irrigation_result(:)
    type(fmr_serialized_column_result_t),allocatable::continued_result(:)
    real(real64)::irrigation_dt
    irrigation_dt=1.0_real64/1024.0_real64
    if(trim(test_scope)=='--irrigation-half-source') irrigation_dt=0.5_real64*irrigation_dt
    control_forcing(1)=profile%tiles(1)%base_forcing
    control_forcing(1)%subsurface_irrigation_source=0.0_real64
    control_forcing(1)%temporal_forcing_event=.true.
    control_forcing(1)%temporal_forcing_event_time=T0
    call bind_ppa_irrigation_source(control_forcing(1),flux,diagnostics,T0,bound_forcing,ok)
    if(.not.ok) error stop 'binding same-time event rejected'
    if(.not.bound_forcing%temporal_forcing_event) error stop 'binding lost same-time unrelated event'
    call bind_ppa_irrigation_source(control_forcing(1),flux,diagnostics,T0+1.0_real64,bound_forcing,ok)
    if(.not.ok) error stop 'binding expired event rejected'
    if(bound_forcing%temporal_forcing_event) error stop 'binding replayed expired event'
    if(bound_forcing%top_flux/=control_forcing(1)%top_flux.or. &
         any(bound_forcing%root_extraction_sink/=control_forcing(1)%root_extraction_sink).or. &
         any(bound_forcing%drainage_flux_by_level/=control_forcing(1)%drainage_flux_by_level)) &
         error stop 'binding changed unrelated forcing'
    do pass=1,9
      diagnostics=irrigation_diagnostics_t()
      flux=irrigation_flux_result_t()
      control_forcing(1)%temporal_forcing_event_time=T0
      select case(pass)
      case(1)
        diagnostics%status=IRRIGATION_SPLIT_REQUIRED
      case(2)
        diagnostics%split_required=.true.
      case(3)
        control_forcing(1)%temporal_forcing_event_time=T0+1.0_real64
      case(4)
        flux%applied=.true.
        flux%application_type=IRRIGATION_APPLICATION_SSDI
      case(5)
        flux%subsurface_source=control_forcing(1)%subsurface_irrigation_source
        flux%subsurface_source(1)=ieee_value(0.0_real64,ieee_quiet_nan)
      case(6)
        flux%surface_gross_rate=0.01_real64
      case(7)
        flux%concentration=0.01_real64
      case(8)
        flux%surface_gross_rate=ieee_value(0.0_real64,ieee_quiet_nan)
      case(9)
        flux%concentration=ieee_value(0.0_real64,ieee_quiet_nan)
      end select
      call bind_ppa_irrigation_source(control_forcing(1),flux,diagnostics,T0,bound_forcing,ok)
      if(ok.or.allocated(bound_forcing)) error stop 'invalid binding retained output'
    end do
    diagnostics=irrigation_diagnostics_t()
    flux=irrigation_flux_result_t()
    control_forcing(1)%temporal_forcing_event=.false.
    control_forcing(1)%subsurface_irrigation_source=0.01_real64
    flux%applied=.true.
    flux%application_type=IRRIGATION_APPLICATION_SSDI
    flux%subsurface_source=control_forcing(1)%subsurface_irrigation_source
    flux%subsurface_source(1)=0.02_real64
    call bind_ppa_irrigation_source(control_forcing(1),flux,diagnostics,T0,bound_forcing,ok)
    if(.not.ok) error stop 'changed source rate rejected'
    if(.not.bound_forcing%temporal_forcing_event.or.bound_forcing%temporal_forcing_event_time/=T0) &
         error stop 'changed source rate not marked'
    if(any(bound_forcing%subsurface_irrigation_source/=flux%subsurface_source)) error stop 'binding changed source rate'
    bound_forcing%subsurface_irrigation_source=-1.0_real64
    if(any(control_forcing(1)%subsurface_irrigation_source/=0.01_real64)) error stop 'binding aliases previous source'
    if(flux%subsurface_source(1)/=0.02_real64) error stop 'binding aliases process source'
    flux=irrigation_flux_result_t()
    write(*,'(a)') 'PPA_IRR_SOURCE_BINDING_EVENT_LIFECYCLE_GUARDS=PASS'
    call owner%copy_committed_hydraulic_states(copied,code)
    if(code==FMR_APP_BOOT_OK.or.allocated(copied)) error stop 'uninitialized hydraulic copy'
    call owner%initialize(profile,code)
    if(code/=FMR_APP_BOOT_OK) error stop 'hydraulic copy initialize'
    call owner%copy_committed_hydraulic_states(copied,code)
    if(code/=FMR_APP_BOOT_OK) error stop 'hydraulic copy status'
    if(size(copied)/=NTILE.or..not.all(copied%available)) error stop 'hydraulic copy tiles'
    do tile=1,NTILE
      if(size(copied(tile)%water_content)/=profile%tiles(tile)%initial_state%active_nodes) &
           error stop 'hydraulic copy active size'
      if(any(abs(copied(tile)%water_content-profile%tiles(tile)%initial_state%water_content)>0.0_real64)) &
           error stop 'hydraulic copy water'
      if(any(abs(copied(tile)%pressure_head_cm-profile%tiles(tile)%initial_state%pressure_head)>0.0_real64)) &
           error stop 'hydraulic copy pressure'
    end do
    call owner%export_committed_restart(92001_int64,bundle,ok,code)
    if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'hydraulic copy export'
    select type(physical=>bundle%records(1)%physical_state)
    type is(fmr_b110_temporal_indicator_state_t)
      carrier%fmr_b110_temporal_indicator_state_t=physical
    class default
      error stop 'irrigation carrier requires temporal history'
    end select
    carrier%irrigation%active_event=.true.
    carrier%irrigation%active_event_origin=IRRIGATION_EVENT_SCHEDULED
    carrier%irrigation%active_event_start=T0
    carrier%irrigation%active_event_end=T0+0.5_real64
    carrier%irrigation%active_event_rate=0.01_real64
    event_template=profile%tiles(1)%template
    if(carrier%matches_candidate(event_template,T0)) error stop 'candidate accepts BASE identity'
    event_template%optional_state_layout_id=PPA_IRRIGATION_EVENT_LAYOUT
    if(.not.carrier%matches_candidate(event_template,T0)) error stop 'valid event candidate rejected'
    if(carrier%matches_candidate(event_template,T0-0.5_real64)) error stop 'event before start accepted'
    if(carrier%matches_candidate(event_template,T0+0.5_real64)) error stop 'ended active event accepted'
    event_template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    if(carrier%matches_candidate(event_template,T0)) error stop 'event without history layout accepted'
    event_template=profile%tiles(1)%template
    event_template%optional_state_layout_id=PPA_IRRIGATION_EVENT_LAYOUT
    if(fmr_restart_state_matches_template(carrier,event_template)) error stop 'candidate production restart admitted'
    write(*,'(a)') 'PPA_IRR_EVENT_CANDIDATE_LAYOUT_TIME_GUARDS=PASS'
    ! Restore the valid snapshot before every mutation: rejection must not rely
    ! on a preceding invalid field or leak changes into the source carrier.
    do pass=1,19
      invalid_carrier=carrier
      select case(pass)
      case(1)
        invalid_carrier%active_nodes=0
      case(2)
        deallocate(invalid_carrier%pressure_head)
      case(3)
        deallocate(invalid_carrier%water_content)
      case(4)
        invalid_carrier%water_content=[0.2_real64]
        invalid_carrier%active_nodes=2
      case(5)
        invalid_carrier%pressure_head(1)=ieee_value(0.0_real64,ieee_quiet_nan)
      case(6)
        invalid_carrier%water_content(1)=ieee_value(0.0_real64,ieee_quiet_nan)
      case(7)
        invalid_carrier%ponding_depth=ieee_value(0.0_real64,ieee_quiet_nan)
      case(8)
        invalid_carrier%groundwater_level=ieee_value(0.0_real64,ieee_quiet_nan)
      case(9)
        invalid_carrier%irrigation%next_fixed_event_index=0
      case(10)
        invalid_carrier%irrigation%active_event_origin=IRRIGATION_EVENT_NONE
      case(11)
        invalid_carrier%irrigation%active_event_index=1
      case(12)
        invalid_carrier%irrigation%active_event_start=ieee_value(0.0_real64,ieee_quiet_nan)
      case(13)
        invalid_carrier%irrigation%active_event_end=ieee_value(0.0_real64,ieee_quiet_nan)
      case(14)
        invalid_carrier%irrigation%active_event_rate=ieee_value(0.0_real64,ieee_quiet_nan)
      case(15)
        invalid_carrier%irrigation%active_event_rate=0.0_real64
      case(16)
        invalid_carrier%irrigation%active_event_end=T0
      case(17)
        invalid_carrier%irrigation%active_event_end=T0+2.0_real64
      case(18)
        invalid_carrier%irrigation%active_event=.false.
      case(19)
        invalid_carrier%irrigation%active_event=.false.
        invalid_carrier%irrigation%active_event_origin=IRRIGATION_EVENT_NONE
        invalid_carrier%irrigation%active_event_index=1
      end select
      if(invalid_carrier%matches_candidate(event_template,T0)) error stop 'invalid event carrier accepted'
      if(.not.carrier%matches_candidate(event_template,T0)) error stop 'carrier validation mutated source'
    end do
    if(carrier%matches_candidate(event_template,ieee_value(0.0_real64,ieee_quiet_nan))) &
         error stop 'nonfinite committed event time accepted'
    invalid_carrier=carrier
    invalid_carrier%irrigation=irrigation_state_t()
    if(.not.invalid_carrier%matches_candidate(event_template,T0)) error stop 'inactive event carrier rejected'
    write(*,'(a)') 'PPA_IRR_EVENT_CANDIDATE_INVALID_PAYLOAD_20=PASS'
    call carrier%clone(carrier_copy)
    select type(cloned=>carrier_copy)
    type is(ppa_irrigation_event_state_t)
      if(.not.cloned%irrigation%active_event) error stop 'carrier clone lost event'
      if(cloned%irrigation%active_event_origin/=IRRIGATION_EVENT_SCHEDULED) error stop 'carrier clone lost origin'
      if(abs(cloned%irrigation%active_event_rate-0.01_real64)>0.0_real64.or. &
           abs(cloned%irrigation%active_event_start-T0)>0.0_real64.or. &
           abs(cloned%irrigation%active_event_end-(T0+0.5_real64))>0.0_real64) error stop 'carrier clone event values'
      call carrier%temporal_history_snapshot(history,history_available)
      call cloned%temporal_history_snapshot(clone_history,clone_history_available)
      if(.not.history_available.or..not.clone_history_available) error stop 'carrier clone history missing'
      if(size(history)/=size(clone_history)) error stop 'carrier clone history shape'
      if(any(abs(history-clone_history)>0.0_real64)) error stop 'carrier clone history changed'
      if(any(abs(cloned%water_content-carrier%water_content)>0.0_real64).or. &
           any(abs(cloned%pressure_head-carrier%pressure_head)>0.0_real64)) error stop 'carrier clone physical fields'
      cloned%water_content=-1.0_real64
      cloned%irrigation%active_event_rate=99.0_real64
      if(any(abs(carrier%water_content-profile%tiles(1)%initial_state%water_content)>0.0_real64)) &
           error stop 'carrier clone aliases original'
      if(abs(carrier%irrigation%active_event_rate-0.01_real64)>0.0_real64) error stop 'carrier event aliases original'
    class default
      error stop 'carrier clone sliced dynamic type'
    end select
    if(fmr_restart_state_matches_template(carrier,profile%tiles(1)%template)) &
         error stop 'unregistered carrier admitted as BASE'
    write(*,'(a)') 'PPA_IRR_EVENT_CARRIER_CLONE_BASE_REJECTION=PASS'
    ! Exercise the actual process continuation with a detached physical snapshot.
    ! Hydraulic evolution/acceptance is not asserted by this assembly-only test.
    irrigation%scheduled_irrigation_enabled=.true.
    irrigation%active_nodes=carrier%active_nodes
    irrigation%sensor_node=1; irrigation%single_ssdi_node=1
    irrigation%tcs7_knot_count=2
    irrigation%tcs7_dvs(1:2)=[0.0_real64,2.0_real64]
    irrigation%dcs2_knot_count=2
    irrigation%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
    hydraulic%active_nodes=carrier%active_nodes
    hydraulic%pressure_head=carrier%pressure_head
    hydraulic%water_content=carrier%water_content
    base=carrier%irrigation
    control_forcing(1)=profile%tiles(1)%base_forcing
    control_forcing(1)%subsurface_irrigation_source=0.0_real64
    control_forcing(1)%temporal_forcing_event=.false.
    irrigation%dcs2_depth_cm(1:2)=0.005_real64
    irrigation%irr_rate_cm_per_day=0.01_real64
    request%selection_opportunity=.true.; request%irrigation_enabled=.true.
    request%schedule_enabled=.true.; request%crop_emerged=.true.; request%irrigation_window_open=.true.
    request%t0=T0; request%t1=T0+0.25_real64
    call evaluate_ppa_irrigation_source(irrigation,irrigation_state_t(),request,hydraulic,control_forcing(1), &
         candidate,flux,diagnostics,bound_forcing,ok)
    if(.not.ok) error stop 'new scheduled source composition failed'
    if(.not.flux%event_started.or..not.candidate%active_event) error stop 'composed selection lost new event'
    if(.not.bound_forcing%temporal_forcing_event) error stop 'new composed source unmarked'
    if(abs(flux%external_inflow_amount-0.0025_real64)>1.0e-15_real64) error stop 'composed selection amount'
    request=scheduled_irrigation_request_t()
    request%t0=T0; request%t1=T0+0.75_real64
    call evaluate_ppa_irrigation_source(irrigation,base,request,hydraulic,control_forcing(1), &
         candidate,flux,diagnostics,bound_forcing,ok)
    if(ok.or.allocated(bound_forcing).or.flux%applied) error stop 'split composition exposed source'
    if(diagnostics%status/=IRRIGATION_SPLIT_REQUIRED) error stop 'split composition lost diagnostic'
    if(.not.candidate%active_event.or.candidate%active_event_end/=base%active_event_end) &
         error stop 'split composition advanced event'
    request%t1=T0+0.5_real64
    irrigation%concentration=1.0_real64
    call evaluate_ppa_irrigation_source(irrigation,base,request,hydraulic,control_forcing(1), &
         candidate,flux,diagnostics,bound_forcing,ok)
    if(ok.or.allocated(bound_forcing).or.flux%applied) error stop 'unsupported composition exposed source'
    if(.not.candidate%active_event.or.candidate%active_event_rate/=base%active_event_rate) &
         error stop 'binding rejection cleared completed process candidate'
    irrigation%concentration=0.0_real64
    expected=0.0_real64
    do pass=1,2
      request%t0=T0+real(pass-1,real64)*0.25_real64
      request%t1=T0+real(pass,real64)*0.25_real64
      call evaluate_ppa_irrigation_source(irrigation,base,request,hydraulic,control_forcing(1), &
           candidate,flux,diagnostics,bound_forcing,ok)
      if(.not.ok) error stop 'carrier process/source composition failed'
      if(bound_forcing%temporal_forcing_event.neqv.(pass==1)) error stop 'composed source event lifecycle'
      control_forcing(1)=bound_forcing
      if(diagnostics%status/=IRRIGATION_OK) error stop 'carrier process continuation failed'
      call build_irrigation_event_candidate(carrier%fmr_b110_temporal_indicator_state_t, &
           candidate,event_template,request%t1,assembled,ok)
      if(.not.ok.or..not.allocated(assembled)) error stop 'carrier process assembly failed'
      if(assembled%irrigation%active_event.neqv.(pass==1)) error stop 'carrier process endpoint state'
      expected=expected+flux%external_inflow_amount
      call assembled%temporal_history_snapshot(clone_history,clone_history_available)
      if(.not.clone_history_available) error stop 'assembled history lost'
      if(any(clone_history/=history)) error stop 'assembled history changed'
      if(any(assembled%water_content/=carrier%water_content)) error stop 'assembled physical state changed'
      base=assembled%irrigation
    end do
    if(abs(expected-0.005_real64)>1.0e-15_real64) error stop 'carrier split gift amount'
    request%t0=T0+0.5_real64; request%t1=T0+0.75_real64
    call evaluate_ppa_irrigation_source(irrigation,base,request,hydraulic,control_forcing(1), &
         candidate,flux,diagnostics,bound_forcing,ok)
    if(.not.ok) error stop 'completed event source composition failed'
    if(.not.bound_forcing%temporal_forcing_event.or.any(bound_forcing%subsurface_irrigation_source/=0.0_real64)) &
         error stop 'completed event source not stopped'
    write(*,'(a)') 'PPA_IRR_PROCESS_SOURCE_COMPOSITION_ROLLBACK=PASS'
    if(diagnostics%status/=IRRIGATION_OK.or.flux%applied) error stop 'carrier duplicate completed gift'
    ! A failed assembly must not leave a stale previously valid output behind.
    call build_irrigation_event_candidate(carrier%fmr_b110_temporal_indicator_state_t, &
         carrier%irrigation,event_template,T0+0.5_real64,assembled,ok)
    if(ok.or.allocated(assembled)) error stop 'failed assembly retained stale candidate'
    ! A polymorphic boundary must not silently strip optional-state payloads.
    ! The caller must explicitly extract the temporal parent when appropriate.
    call build_irrigation_event_candidate(carrier,carrier%irrigation,event_template,T0,assembled,ok)
    if(ok.or.allocated(assembled)) error stop 'assembly implicitly sliced irrigation carrier'
    call build_irrigation_event_candidate(profile%tiles(1)%initial_state, &
         carrier%irrigation,event_template,T0,assembled,ok)
    if(ok.or.allocated(assembled)) error stop 'assembly admitted plain physical state'
    call build_irrigation_event_candidate(bundle%records(1)%physical_state, &
         carrier%irrigation,event_template,T0,assembled,ok)
    if(.not.ok.or..not.allocated(assembled)) error stop 'assembly rejected exact polymorphic temporal state'
    assembled%water_content=-99.0_real64
    assembled%irrigation%active_event_rate=99.0_real64
    call build_irrigation_event_candidate(bundle%records(1)%physical_state, &
         carrier%irrigation,event_template,T0,assembled,ok)
    if(.not.ok.or..not.allocated(assembled)) error stop 'assembly source reread failed'
    if(any(assembled%water_content/=carrier%water_content)) error stop 'assembly aliases restart physical source'
    if(assembled%irrigation%active_event_rate/=0.01_real64) error stop 'assembly aliases reread event source'
    if(any(carrier%water_content/=profile%tiles(1)%initial_state%water_content)) &
         error stop 'assembly aliases source physical state'
    if(carrier%irrigation%active_event_rate/=0.01_real64) error stop 'assembly aliases event source'
    if(.not.carrier%irrigation%active_event) error stop 'assembly mutated source event'
    base=irrigation_state_t()
    irrigation=scheduled_irrigation_parameters_t()
    request=scheduled_irrigation_request_t()
    write(*,'(a)') 'PPA_IRR_EVENT_PROCESS_SPLIT_ASSEMBLY_NO_DUPLICATE=PASS'
    write(*,'(a)') 'PPA_IRR_EVENT_ASSEMBLY_EXACT_TYPE_ISOLATION=PASS'
    copied(1)%water_content=-99.0_real64
    copied(1)%pressure_head_cm=99.0_real64
    call owner%copy_committed_hydraulic_states(again,code)
    if(code/=FMR_APP_BOOT_OK) error stop 'hydraulic isolation copy'
    if(any(abs(again(1)%water_content-profile%tiles(1)%initial_state%water_content)>0.0_real64)) &
         error stop 'hydraulic copy aliases water owner'
    if(any(abs(again(1)%pressure_head_cm-profile%tiles(1)%initial_state%pressure_head)>0.0_real64)) &
         error stop 'hydraulic copy aliases pressure owner'
    call owner%restore_committed_restart(bundle,92001_int64,ok,code)
    if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'hydraulic copy restore'
    call owner%copy_committed_hydraulic_states(again,code)
    if(code/=FMR_APP_BOOT_OK) error stop 'hydraulic copy again'
    ! Consume the actual owner's detached profile, before/after another restart.
    irrigation%scheduled_irrigation_enabled=.true.
    irrigation%depth_criterion=IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY
    irrigation%sensor_node=1; irrigation%single_ssdi_node=1
    irrigation%tcs7_knot_count=2
    irrigation%tcs7_dvs(1:2)=[0.0_real64,2.0_real64]
    irrigation%tcs7_pressure_head(1:2)=0.0_real64
    irrigation%dcs1_knot_count=2
    irrigation%dcs1_dvs(1:2)=[0.0_real64,2.0_real64]
    request%selection_opportunity=.true.; request%irrigation_enabled=.true.
    request%schedule_enabled=.true.; request%crop_emerged=.true.; request%irrigation_window_open=.true.
    do pass=1,2
      if(pass==2) then
        call owner%restore_committed_restart(bundle,92001_int64,ok,code)
        if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'irrigation profile restore'
        call owner%copy_committed_hydraulic_states(again,code)
        if(code/=FMR_APP_BOOT_OK) error stop 'irrigation profile recopy'
      end if
      do tile=1,NTILE
        hydraulic%active_nodes=size(again(tile)%water_content)
        hydraulic%pressure_head=again(tile)%pressure_head_cm
        hydraulic%water_content=again(tile)%water_content
        irrigation%active_nodes=hydraulic%active_nodes
        request%t0=again(tile)%committed_time; request%t1=request%t0+1.0_real64
        thickness=profile%tiles(tile)%parameters%dz(1)
        call evaluate_profile_scheduled_irrigation(irrigation,base,request,hydraulic,1,[1],[thickness], &
             [0.0_real64],thickness*0.5_real64,[0.8_real64],[0.3_real64],[0.1_real64], &
             candidate,flux,diagnostics)
        if(diagnostics%status/=IRRIGATION_OK.or..not.flux%applied) error stop 'owner profile DCS1 selection'
        expected=0.8_real64*thickness*0.5_real64-hydraulic%water_content(1)*thickness*0.5_real64
        if(abs(flux%external_inflow_amount-expected)>8.0_real64*epsilon(expected)*max(1.0_real64,expected)) &
             error stop 'owner profile DCS1 source amount'
        if(pass==1) selected_amount(tile)=flux%external_inflow_amount
        if(abs(flux%external_inflow_amount-selected_amount(tile))>0.0_real64) &
             error stop 'owner profile DCS1 restart identity'
      end do
    end do
    write(*,'(a)') 'PPA_OWNER_PROFILE_DCS1_SELECTION_RESTART_IDENTITY=PASS'
    do tile=1,NTILE
      if(any(abs(again(tile)%water_content-profile%tiles(tile)%initial_state%water_content)>0.0_real64)) &
           error stop 'hydraulic copy isolation water'
      if(any(abs(again(tile)%pressure_head_cm-profile%tiles(tile)%initial_state%pressure_head)>0.0_real64)) &
           error stop 'hydraulic copy isolation pressure'
      if(again(tile)%revision/=copied(tile)%revision) error stop 'hydraulic copy revision'
      if(abs(again(tile)%committed_time-copied(tile)%committed_time)>0.0_real64) error stop 'hydraulic copy time'
    end do
    if(trim(test_scope)=='--irrigation-source'.or.trim(test_scope)=='--irrigation-half-source') then
      irrigation%depth_limit_enabled=.true.
      irrigation%minimum_depth_mm=0.01_real64*irrigation_dt*10.0_real64
      irrigation%maximum_depth_mm=irrigation%minimum_depth_mm
      irrigation%irr_rate_cm_per_day=0.01_real64
      do tile=1,NTILE
        hydraulic%active_nodes=size(again(tile)%water_content)
        hydraulic%pressure_head=again(tile)%pressure_head_cm
        hydraulic%water_content=again(tile)%water_content
        irrigation%active_nodes=hydraulic%active_nodes
        request%t0=again(tile)%committed_time; request%t1=request%t0+irrigation_dt
        thickness=profile%tiles(tile)%parameters%dz(1)
        irrigation_forcing(tile)=profile%tiles(tile)%base_forcing
        irrigation_forcing(tile)%top_flux=0.0_real64
        call evaluate_ppa_profile_irrigation_source(irrigation,base,request,hydraulic,1,[1],[-thickness], &
             [0.0_real64],thickness*0.5_real64,[0.8_real64],[0.3_real64],[0.1_real64], &
             irrigation_forcing(tile),candidate,flux,diagnostics,bound_forcing,ok)
        if(ok.or.allocated(bound_forcing).or.flux%applied) error stop 'invalid profile exposed irrigation source'
        if(candidate%active_event.neqv.base%active_event) error stop 'invalid profile changed event'
        irrigation%concentration=1.0_real64
        call evaluate_ppa_profile_irrigation_source(irrigation,base,request,hydraulic,1,[1],[thickness], &
             [0.0_real64],thickness*0.5_real64,[0.8_real64],[0.3_real64],[0.1_real64], &
             irrigation_forcing(tile),candidate,flux,diagnostics,bound_forcing,ok)
        if(ok.or.allocated(bound_forcing).or.flux%applied) error stop 'profile solute rejection exposed source'
        if(candidate%active_event.neqv.base%active_event) error stop 'profile binding rejection changed event'
        irrigation%concentration=0.0_real64
        call evaluate_ppa_profile_irrigation_source(irrigation,base,request,hydraulic,1,[1],[thickness], &
             [0.0_real64],thickness*0.5_real64,[0.8_real64],[0.3_real64],[0.1_real64], &
             irrigation_forcing(tile),candidate,flux,diagnostics,bound_forcing,ok)
        if(.not.ok) error stop 'profile irrigation source composition'
        if(diagnostics%status/=IRRIGATION_OK.or..not.flux%event_finished) error stop 'irrigation gift selection'
        selected_amount(tile)=flux%external_inflow_amount
        irrigation_forcing(tile)=bound_forcing
        control_forcing(tile)=profile%tiles(tile)%base_forcing
        control_forcing(tile)%top_flux=0.0_real64
        irrigation%timing_criterion=IRRIGATION_TIMING_TCS8_WATER_CONTENT
        irrigation%tcs8_knot_count=2
        irrigation%tcs8_dvs(1:2)=[0.0_real64,2.0_real64]
        irrigation%tcs8_water_content(1:2)=0.0_real64
        call evaluate_ppa_profile_irrigation_source(irrigation,base,request,hydraulic,1,[1],[thickness], &
             [0.0_real64],thickness*0.5_real64,[0.8_real64],[0.3_real64],[0.1_real64], &
             control_forcing(tile),candidate,flux,diagnostics,bound_forcing,ok)
        if(.not.ok.or.flux%applied) error stop 'TCS8 wet-profile selection'
        if(any(bound_forcing%subsurface_irrigation_source/=0.0_real64)) error stop 'TCS8 wet-profile source'
        ! The source timing criterion includes equality at the moisture threshold.
        irrigation%tcs8_water_content(1:2)=hydraulic%water_content(1)
        call evaluate_ppa_profile_irrigation_source(irrigation,base,request,hydraulic,1,[1],[thickness], &
             [0.0_real64],thickness*0.5_real64,[0.8_real64],[0.3_real64],[0.1_real64], &
             control_forcing(tile),candidate,flux,diagnostics,bound_forcing,ok)
        if(.not.ok.or..not.flux%event_finished) error stop 'TCS8 threshold equality source'
        if(flux%external_inflow_amount/=selected_amount(tile)) error stop 'TCS7 TCS8 DCS1 amount differs'
        if(any(bound_forcing%subsurface_irrigation_source/=irrigation_forcing(tile)%subsurface_irrigation_source)) &
             error stop 'TCS7 TCS8 source rates differ'
        if(bound_forcing%temporal_forcing_event.neqv.irrigation_forcing(tile)%temporal_forcing_event) &
             error stop 'TCS7 TCS8 source event differs'
        irrigation_forcing(tile)=bound_forcing
        irrigation%timing_criterion=IRRIGATION_TIMING_TCS7_PRESSURE_HEAD
      end do
      write(*,'(a)') 'PPA_IRR_TCS8_PROFILE_SOURCE_THRESHOLD_IDENTITY=PASS'
      control_forcing=irrigation_forcing
      do tile=1,NTILE
        control_forcing(tile)%subsurface_irrigation_source=0.0_real64
      end do
      call owner%run_standalone_with_forcing(request%t0,request%t1,control_forcing,irrigation_result,code)
      write(*,*) 'IRRIGATION_ZERO_CONTROL_STATUS',code,irrigation_result%kernel_status,irrigation_result%accepted_substeps
      call owner%copy_committed_hydraulic_states(again,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation control outcome snapshot'
      do tile=1,NTILE
        if(irrigation_result(tile)%kernel_status/=0) then
          if(again(tile)%revision/=copied(tile)%revision) error stop 'failed tile revision published'
          if(abs(again(tile)%committed_time-copied(tile)%committed_time)>0.0_real64) &
               error stop 'failed tile time published'
          if(any(abs(again(tile)%water_content-profile%tiles(tile)%initial_state%water_content)>0.0_real64)) &
               error stop 'failed tile water published'
          if(any(abs(again(tile)%pressure_head_cm-profile%tiles(tile)%initial_state%pressure_head)>0.0_real64)) &
               error stop 'failed tile pressure published'
        else
          if(abs(again(tile)%committed_time-request%t1)>0.0_real64) error stop 'accepted tile time missing'
          if(again(tile)%revision<=copied(tile)%revision) error stop 'accepted tile revision missing'
        end if
      end do
      write(*,'(a)') 'PPA_IRRIGATION_CONTROL_PER_TILE_PUBLICATION=PASS'
      call owner%restore_committed_restart(bundle,92001_int64,ok,code)
      if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'irrigation control reset'
      call owner%copy_committed_hydraulic_states(again,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation control restored profile'
      do tile=1,NTILE
        if(again(tile)%revision/=copied(tile)%revision) error stop 'irrigation control restored revision'
        if(abs(again(tile)%committed_time-copied(tile)%committed_time)>0.0_real64) &
             error stop 'irrigation control restored time'
        if(any(abs(again(tile)%water_content-profile%tiles(tile)%initial_state%water_content)>0.0_real64)) &
             error stop 'irrigation control restored water'
        if(any(abs(again(tile)%pressure_head_cm-profile%tiles(tile)%initial_state%pressure_head)>0.0_real64)) &
             error stop 'irrigation control restored pressure'
      end do
      write(*,'(a)') 'PPA_IRRIGATION_CONTROL_COMMON_BOUNDARY=PASS'
      ! Hydraulic restart while the prescribed SSDI source remains active.
      ! Forcing is explicitly supplied again, not reconstructed from an event.
      ! Use two established-length windows for this prescribed-source gate.
      ! A half-length first window is tracked separately as a numerical failure.
      midpoint=request%t1
      call owner%run_standalone_with_forcing(request%t0,midpoint,irrigation_forcing,irrigation_result,code)
      write(*,*) 'IRRIGATION_FIRST_WINDOW',irrigation_dt,code,irrigation_result%kernel_status
      do tile=1,NTILE
        write(*,*) 'IRRIGATION_FIRST_REJECTIONS',tile,irrigation_result(tile)%accepted_substeps, &
             irrigation_result(tile)%transaction_attempts,irrigation_result(tile)%transaction_retries, &
             irrigation_result(tile)%solver_rejections,irrigation_result(tile)%temporal_rejections, &
             irrigation_result(tile)%temporal_unavailable_rejections,irrigation_result(tile)%mass_rejections
        write(*,*) 'IRRIGATION_LAST_TRIAL',tile,irrigation_result(tile)%solver_executed, &
             irrigation_result(tile)%last_solver_status,irrigation_result(tile)%last_trial_t0, &
             irrigation_result(tile)%last_trial_t1,trim(irrigation_result(tile)%solver_route)
      end do
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint interval failed'
      if(maxval(abs(irrigation_result%mass%residual))>HARD_MASS_GATE) error stop 'irrigation midpoint mass'
      first_half_in=irrigation_result%mass%total_in
      call owner%export_committed_restart(92001_int64,midpoint_bundle,ok,code)
      if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint export'
      call fresh_owner%initialize(profile,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint fresh initialize'
      call fresh_owner%restore_committed_restart(midpoint_bundle,92001_int64,ok,code)
      if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint fresh restore'
      call owner%copy_committed_hydraulic_states(midpoint_state,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint boundary copy'
      ! The rate does not change at restart; do not replay the old start event.
      control_forcing=irrigation_forcing
      do tile=1,NTILE
        flux%subsurface_source=irrigation_forcing(tile)%subsurface_irrigation_source
        call bind_ppa_irrigation_source(irrigation_forcing(tile),flux,diagnostics,midpoint,bound_forcing,ok)
        if(.not.ok) error stop 'irrigation continued source binding'
        control_forcing(tile)=bound_forcing
        if(control_forcing(tile)%temporal_forcing_event) error stop 'unchanged source falsely marked'
      end do
      call owner%run_standalone_with_forcing(midpoint,midpoint+irrigation_dt,control_forcing,irrigation_result,code)
      original_status=code
      if(original_status/=FMR_APP_BOOT_OK) error stop 'unchanged active-source continuation failed'
      call fresh_owner%run_standalone_with_forcing(midpoint,midpoint+irrigation_dt,control_forcing,continued_result,code)
      if(code/=original_status) error stop 'irrigation midpoint restart changed outcome'
      write(*,*) 'IRRIGATION_ACTIVE_SOURCE_OUTCOME',original_status,irrigation_result%kernel_status
      call owner%copy_committed_hydraulic_states(copied,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint final copy'
      call fresh_owner%copy_committed_hydraulic_states(again,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint resumed copy'
      do tile=1,NTILE
        if(continued_result(tile)%kernel_status/=irrigation_result(tile)%kernel_status) &
             error stop 'irrigation midpoint restart changed tile outcome'
        write(*,*) 'IRRIGATION_ACTIVE_REJECTIONS',tile,irrigation_result(tile)%accepted_substeps, &
             irrigation_result(tile)%transaction_attempts,irrigation_result(tile)%transaction_retries, &
             irrigation_result(tile)%solver_rejections,irrigation_result(tile)%temporal_rejections, &
             irrigation_result(tile)%temporal_unavailable_rejections,irrigation_result(tile)%mass_rejections
        if(continued_result(tile)%transaction_attempts/=irrigation_result(tile)%transaction_attempts.or. &
             continued_result(tile)%transaction_retries/=irrigation_result(tile)%transaction_retries.or. &
             continued_result(tile)%solver_rejections/=irrigation_result(tile)%solver_rejections.or. &
             continued_result(tile)%temporal_rejections/=irrigation_result(tile)%temporal_rejections.or. &
             continued_result(tile)%temporal_unavailable_rejections/=irrigation_result(tile)%temporal_unavailable_rejections.or. &
             continued_result(tile)%mass_rejections/=irrigation_result(tile)%mass_rejections) &
             error stop 'irrigation restart rejection counters differ'
        if(again(tile)%revision/=copied(tile)%revision.or. &
             again(tile)%committed_time/=copied(tile)%committed_time) error stop 'irrigation midpoint revision time'
        if(any(again(tile)%water_content/=copied(tile)%water_content).or. &
             any(again(tile)%pressure_head_cm/=copied(tile)%pressure_head_cm)) &
             error stop 'irrigation midpoint resumed profile'
        if(irrigation_result(tile)%kernel_status/=0) then
          if(copied(tile)%revision/=midpoint_state(tile)%revision.or. &
               copied(tile)%committed_time/=midpoint_state(tile)%committed_time) &
               error stop 'failed active source advanced committed clock'
          if(any(copied(tile)%water_content/=midpoint_state(tile)%water_content).or. &
               any(copied(tile)%pressure_head_cm/=midpoint_state(tile)%pressure_head_cm)) &
               error stop 'failed active source published trial profile'
          cycle
        end if
        if(abs(irrigation_result(tile)%mass%residual)>HARD_MASS_GATE.or. &
             abs(continued_result(tile)%mass%residual)>HARD_MASS_GATE) error stop 'irrigation midpoint tail mass'
        expected=2.0_real64*(selected_amount(tile)+ &
             sum(max(-irrigation_forcing(tile)%drainage_flux_by_level,0.0_real64))*irrigation_dt)
        if(abs(first_half_in(tile)+irrigation_result(tile)%mass%total_in-expected)>HARD_MASS_GATE) &
             error stop 'irrigation midpoint total inflow'
        if(continued_result(tile)%mass%total_in/=irrigation_result(tile)%mass%total_in) &
             error stop 'irrigation midpoint resumed inflow'
        if(again(tile)%revision/=copied(tile)%revision.or. &
             again(tile)%committed_time/=copied(tile)%committed_time) error stop 'irrigation midpoint revision time'
        if(copied(tile)%committed_time/=midpoint+irrigation_dt) error stop 'irrigation midpoint endpoint'
        if(any(again(tile)%water_content/=copied(tile)%water_content).or. &
             any(again(tile)%pressure_head_cm/=copied(tile)%pressure_head_cm)) &
             error stop 'irrigation midpoint resumed profile'
      end do
      ! End the prolonged prescribed source at an explicit new forcing event.
      flux=irrigation_flux_result_t()
      do tile=1,NTILE
        call bind_ppa_irrigation_source(control_forcing(tile),flux,diagnostics, &
             midpoint+irrigation_dt,bound_forcing,ok)
        if(.not.ok) error stop 'irrigation stopped source binding'
        control_forcing(tile)=bound_forcing
        if(.not.control_forcing(tile)%temporal_forcing_event) error stop 'stopped source unmarked'
      end do
      call owner%run_standalone_with_forcing(midpoint+irrigation_dt,midpoint+2.0_real64*irrigation_dt, &
           control_forcing,irrigation_result,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'active-source sequence stop failed'
      call fresh_owner%run_standalone_with_forcing(midpoint+irrigation_dt,midpoint+2.0_real64*irrigation_dt, &
           control_forcing,continued_result,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'active-source sequence resumed stop failed'
      call owner%copy_committed_hydraulic_states(copied,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'active-source sequence stop copy'
      call fresh_owner%copy_committed_hydraulic_states(again,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'active-source sequence resumed stop copy'
      do tile=1,NTILE
        expected=sum(max(-control_forcing(tile)%drainage_flux_by_level,0.0_real64))*irrigation_dt
        if(abs(irrigation_result(tile)%mass%total_in-expected)>HARD_MASS_GATE) &
             error stop 'prolonged source duplicated after stop'
        if(abs(irrigation_result(tile)%mass%residual)>HARD_MASS_GATE.or. &
             abs(continued_result(tile)%mass%residual)>HARD_MASS_GATE) error stop 'active-source stop mass'
        if(continued_result(tile)%mass%total_in/=irrigation_result(tile)%mass%total_in) &
             error stop 'active-source stop restart inflow'
        if(again(tile)%revision/=copied(tile)%revision.or. &
             again(tile)%committed_time/=copied(tile)%committed_time) error stop 'active-source stop identity'
        if(copied(tile)%committed_time/=midpoint+2.0_real64*irrigation_dt) error stop 'active-source stop endpoint'
        if(any(again(tile)%water_content/=copied(tile)%water_content).or. &
             any(again(tile)%pressure_head_cm/=copied(tile)%pressure_head_cm)) &
             error stop 'active-source stop restart profile'
      end do
      write(*,'(a)') 'PPA_IRRIGATION_START_CONTINUE_STOP_RESTART_SEQUENCE=PASS'
      call fresh_owner%close(code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint fresh close'
      call owner%restore_committed_restart(bundle,92001_int64,ok,code)
      if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'irrigation midpoint reset'
      write(*,'(a)') 'PPA_IRRIGATION_ACTIVE_SOURCE_RESTART_OUTCOME_ROLLBACK_IDENTITY=PASS'
      write(*,'(a)') 'PPA_IRRIGATION_ACTIVE_SOURCE_RESTART_ACCEPTED_IDENTITY=PASS'
      call owner%run_standalone_with_forcing(request%t0,request%t1,irrigation_forcing,irrigation_result,code)
      write(*,*) 'IRRIGATION_SOURCE_STATUS',code,irrigation_result%kernel_status,irrigation_result%accepted_substeps
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation source interval failed'
      if(maxval(abs(irrigation_result%mass%residual))>HARD_MASS_GATE) error stop 'irrigation source mass'
      do tile=1,NTILE
        expected=selected_amount(tile)+sum(max(-irrigation_forcing(tile)%drainage_flux_by_level,0.0_real64))*irrigation_dt
        write(*,*) 'IRRIGATION_INFLOW',tile,irrigation_result(tile)%mass%total_in,expected
        if(abs(irrigation_result(tile)%mass%total_in-expected)>HARD_MASS_GATE) &
             error stop 'irrigation source accepted inflow'
      end do
      write(*,'(a)') 'PPA_OWNER_DCS1_SOURCE_ACCEPTED_MASS=PASS'
      call owner%copy_committed_hydraulic_states(copied,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'accepted irrigation profile copy'
      call owner%export_committed_restart(92001_int64,bundle,ok,code)
      if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'accepted irrigation export'
      call fresh_owner%initialize(profile,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'accepted irrigation fresh initialize'
      call fresh_owner%restore_committed_restart(bundle,92001_int64,ok,code)
      if(.not.ok.or.code/=FMR_APP_BOOT_OK) error stop 'accepted irrigation fresh restore'
      call fresh_owner%copy_committed_hydraulic_states(again,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'accepted irrigation restored copy'
      do tile=1,NTILE
        if(abs(copied(tile)%committed_time-request%t1)>0.0_real64) error stop 'accepted irrigation time'
        if(again(tile)%revision/=copied(tile)%revision) error stop 'accepted irrigation restart revision'
        if(abs(again(tile)%committed_time-copied(tile)%committed_time)>0.0_real64) &
             error stop 'accepted irrigation restart time'
        if(any(abs(again(tile)%water_content-copied(tile)%water_content)>0.0_real64)) &
             error stop 'accepted irrigation restart water'
        if(any(abs(again(tile)%pressure_head_cm-copied(tile)%pressure_head_cm)>0.0_real64)) &
             error stop 'accepted irrigation restart pressure'
      end do
      ! The selected gift has finished: remove SSDI and mark that source change.
      do tile=1,NTILE
        irrigation_forcing(tile)%subsurface_irrigation_source=0.0_real64
        irrigation_forcing(tile)%temporal_forcing_event=.true.
        irrigation_forcing(tile)%temporal_forcing_event_time=request%t1
      end do
      call owner%run_standalone_with_forcing(request%t1,request%t1+irrigation_dt, &
           irrigation_forcing,irrigation_result,code)
      write(*,*) 'IRRIGATION_STOP_CONTINUATION',code,irrigation_result%kernel_status
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation stop continuation'
      call fresh_owner%run_standalone_with_forcing(request%t1,request%t1+irrigation_dt, &
           irrigation_forcing,continued_result,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation stop restart continuation'
      call owner%copy_committed_hydraulic_states(copied,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation stop copy'
      call fresh_owner%copy_committed_hydraulic_states(again,code)
      if(code/=FMR_APP_BOOT_OK) error stop 'irrigation stop restart copy'
      do tile=1,NTILE
        if(abs(irrigation_result(tile)%mass%residual)>HARD_MASS_GATE.or. &
             abs(continued_result(tile)%mass%residual)>HARD_MASS_GATE) error stop 'irrigation stop mass'
        expected=sum(max(-irrigation_forcing(tile)%drainage_flux_by_level,0.0_real64))*irrigation_dt
        if(abs(irrigation_result(tile)%mass%total_in-expected)>HARD_MASS_GATE) error stop 'finished gift repeated'
        if(abs(continued_result(tile)%mass%total_in-irrigation_result(tile)%mass%total_in)>0.0_real64) &
             error stop 'irrigation stop restart inflow'
        if(again(tile)%revision/=copied(tile)%revision) error stop 'irrigation continuation revision'
        if(abs(again(tile)%committed_time-copied(tile)%committed_time)>0.0_real64) &
             error stop 'irrigation continuation time'
        if(any(abs(again(tile)%water_content-copied(tile)%water_content)>0.0_real64).or. &
             any(abs(again(tile)%pressure_head_cm-copied(tile)%pressure_head_cm)>0.0_real64)) &
             error stop 'irrigation continuation profile'
      end do
      write(*,'(a)') 'PPA_IRRIGATION_FINISHED_GIFT_RESTART_CONTINUATION=PASS'
      call fresh_owner%close(code)
      write(*,'(a)') 'PPA_IRRIGATION_ACCEPTED_PROFILE_FRESH_RESTART=PASS'
    end if
    call owner%close(code)
    call owner%copy_committed_hydraulic_states(again,code)
    if(code==FMR_APP_BOOT_OK.or.allocated(again)) error stop 'closed hydraulic copy'
  end subroutine verify_hydraulic_copy
  subroutine verify_atm02_owner(profile,events)
    type(fmr_production_application_config_t),intent(in)::profile
    logical,intent(in)::events
    type(fmr_production_application_config_t)::active
    type(fmr_production_application_bootstrap_t)::owner,fresh
    type(fmr_committed_restart_bundle_t)::before,after,resumed
    type(fmr_committed_top_state_t),allocatable::top(:)
    type(fmr_b110_physical_forcing_t)::forcing(NTILE),previous(NTILE)
    type(fmr_serialized_column_result_t),allocatable::result(:)
    type(fmr_serialized_commit_receipt_record_t),allocatable::receipt(:)
    type(ppa_atm02_decoded_daily_meteo_t)::decoded
    type(ppa_atm02_generic_interval_t)::interval
    type(pmdirect_swetr0_site_t)::site
    type(pmdirect_swetr0_canopy_t)::canopy
    type(crop_root_uptake_input_t)::roots
    type(soil_water_parameter_set_t)::geometry
    type(b110_default_mvg_parameters_t)::hydraulics
    type(b110_dynamic_top_boundary_request_t)::request
    type(ppa_atm02_meteo_provenance_t)::provenance
    type(ppa_atm02_production_forcing_diagnostics_t)::diagnostics
    integer::window,tile,node,code,pass
    logical::ok
    active=profile
    active%tiles%parameters%root_extraction_active=.true.
    decoded%source_id=9201_int64; decoded%day_of_year=180
    decoded%radiation_j_m2_d=18.0e6_real64
    decoded%minimum_air_temperature_c=12.0_real64; decoded%maximum_air_temperature_c=24.0_real64
    decoded%vapour_pressure_kpa=1.3_real64; decoded%wind_speed_m_s=2.0_real64
    decoded%gross_rain_cm_d=0.0_real64
    site%latitude_degrees=52.0_real64; site%altitude_m=10.0_real64
    site%wind_measurement_height_m=2.0_real64; site%humidity_measurement_height_m=2.0_real64
    site%angstrom_a=0.25_real64; site%angstrom_b=0.50_real64; site%soil_surface_resistance_s_m=100.0_real64
    canopy%crop_emerged=.true.; canopy%lai=3.0_real64; canopy%vegetation_cover_fraction=0.7_real64
    canopy%cofab_cm=0.5_real64; canopy%albedo=0.23_real64
    canopy%dry_canopy_resistance_s_m=70.0_real64; canopy%wet_canopy_resistance_s_m=30.0_real64
    do window=1,merge(3,2,events)
      interval%t0=T0+real(window-1,real64)*(T1-T0); interval%t1=interval%t0+(T1-T0)
      decoded%source_record_index=43+window
      decoded%t0=interval%t0-0.25_real64; decoded%t1=interval%t1+0.25_real64
      if(events.and.window==2) decoded%radiation_j_m2_d=20.0e6_real64
      if(window>1) then
        call owner%copy_committed_top_states(top,code)
        call require(code==FMR_APP_BOOT_OK.and.all(top%available),'ATM02 committed top available')
      end if
      do tile=1,NTILE
        geometry%parameter_set_id=active%tiles(tile)%parameters%parameter_set_id
        geometry%active_nodes=active%tiles(tile)%parameters%active_nodes
        geometry%z=active%tiles(tile)%parameters%z; geometry%dz=active%tiles(tile)%parameters%dz
        geometry%node_distance=active%tiles(tile)%parameters%node_distance
        call initialize_b110_default_mvg_parameters(hydraulics,active%tiles(tile)%parameters%cofgen)
        roots%crop_emerged=.true.; roots%rooted_nodes=min(4,geometry%active_nodes)
        allocate(roots%cumulative_root_fraction(roots%rooted_nodes+1))
        do node=1,roots%rooted_nodes+1
          roots%cumulative_root_fraction(node)=real(node-1,real64)/real(roots%rooted_nodes,real64)
        end do
        request=b110_dynamic_top_boundary_request_t()
        request%conductivity_mean_method=active%tiles(tile)%parameters%swkmean
        request%pressure_head_top_cm=active%tiles(tile)%initial_state%pressure_head(1)
        request%water_content_top=active%tiles(tile)%initial_state%water_content(1)
        if(window>1) then
          request%pressure_head_top_cm=top(tile)%pressure_head_top_cm
          request%water_content_top=top(tile)%water_content_top
          request%previous_ponding_depth_cm=top(tile)%ponding_depth_cm
          request%candidate_ponding_depth_cm=top(tile)%ponding_depth_cm
        end if
        request%ponding_max_cm=2.0_real64; request%runoff_resistance_day=1.0_real64
        request%runoff_exponent=1.0_real64
        call materialize_ppa_atm02_pmdirect_production_forcing(decoded,interval,site,canopy,0.0_real64,roots, &
             geometry,hydraulics,request,active%tiles(tile)%base_forcing,forcing(tile),provenance,diagnostics)
        call require(diagnostics%status==PPA_ATM02_PRODUCTION_FORCING_OK.and.diagnostics%result_produced, &
             'ATM02 complete typed forcing')
        call require(sum(forcing(tile)%root_extraction_sink)>0.0_real64,'ATM02 nonzero prescribed transpiration')
        if(window==1) then
          call seed_initial_derivative(active%tiles(tile)%parameters,active%tiles(tile)%initial_state, &
               forcing(tile),active%tiles(tile)%initial_right_derivative)
        else if(events.and.window==2) then
          call require(forcing(tile)%top_flux/=previous(tile)%top_flux.and. &
               any(forcing(tile)%root_extraction_sink/=previous(tile)%root_extraction_sink), &
               'ATM02 changed weather changes top flux and prescribed roots')
          forcing(tile)%temporal_forcing_event=.true.
          forcing(tile)%temporal_forcing_event_time=interval%t0
        else
          call require(forcing(tile)%top_flux==previous(tile)%top_flux.and. &
               all(forcing(tile)%root_extraction_sink==previous(tile)%root_extraction_sink), &
               'ATM02 unchanged forcing needs no event reseeding')
        end if
        deallocate(roots%cumulative_root_fraction)
      end do
      previous=forcing
      if(window==1) then
        call owner%initialize(active,code)
        call require(code==FMR_APP_BOOT_OK,'ATM02 opt-in owner initializes')
      end if
      call owner%export_committed_restart(9903_int64,before,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'ATM02 pre-interval export')
      call fresh%initialize(active,code)
      call require(code==FMR_APP_BOOT_OK,'ATM02 fresh owner initializes')
      call fresh%restore_committed_restart(before,9903_int64,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'ATM02 fresh restart restores')
      do pass=1,2
        observed_event_calls=0
        capture_low_rain=events.and.window==3.and.pass==1
        if(pass==1) then
          call owner%run_standalone_with_forcing_receipts(interval%t0,interval%t1,forcing,result,receipt,code)
        else
          call fresh%run_standalone_with_forcing_receipts(interval%t0,interval%t1,forcing,result,receipt,code)
        end if
        capture_low_rain=.false.
        write(*,*) 'ATM02_OPT_IN',window,pass,code,result%kernel_status,result%accepted_substeps
        if(events.and.window==3) then
          call require(code/=FMR_APP_BOOT_OK.and.all(.not.result%committed).and.all(.not.result%completed), &
               'ATM02 third interval remains a diagnosed rejection, not continuation success')
          call require(all(result%accepted_substeps>0),'ATM02 third interval fails after internal progress')
          call require(observed_event_calls==0,'ATM02 unmarked failed continuation does not reseed')
          call require(all(.not.result%actual_transpiration_available).and. &
               all(result%actual_transpiration_amount==0.0_real64),'ATM02 failed continuation publishes no root amount')
          do tile=1,NTILE
            call require(.not.receipt(tile)%receipt%ready(),'ATM02 failed continuation has no ready receipt')
          end do
          if(pass==1) call diagnose_root_boundary(active%tiles(NTILE)%parameters,forcing(NTILE))
          cycle
        end if
        call require(code==FMR_APP_BOOT_OK.and.all(result%committed).and.all(result%completed),'ATM02 opt-in commits')
        if(events.and.window==2) then
          call require(observed_event_calls>0.and.observed_event_calls<sum(result%accepted_substeps), &
               'ATM02 root event restricted to first boundary retries')
        else
          call require(observed_event_calls==0,'ATM02 retains normal root-compatible temporal history')
        end if
        call require(maxval(abs(result%mass%residual))<=HARD_MASS_GATE,'ATM02 opt-in hard mass')
        do tile=1,NTILE
          call require(receipt(tile)%receipt%ready(),'ATM02 accepted receipt ready')
          call require(result(tile)%actual_transpiration_available,'ATM02 accepted transpiration available')
          call require(abs(result(tile)%actual_transpiration_amount- &
               sum(forcing(tile)%root_extraction_sink)*(interval%t1-interval%t0))<HARD_MASS_GATE, &
               'ATM02 accepted root amount equals prescribed interval demand')
        end do
      end do
      call owner%export_committed_restart(9903_int64,after,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'ATM02 continued export')
      call fresh%export_committed_restart(9903_int64,resumed,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'ATM02 fresh export')
      call compare_restart_bundles(after,resumed,'ATM02 exact hydraulic history restart')
      if(events.and.window==2) call verify_root_event_rollback(active,before,after,forcing,interval%t0,interval%t1)
      if(events.and.window==3) then
        call compare_restart_bundles(before,after,'ATM02 third interval exact rollback')
        write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_ATM02_UNMARKED_REJECTION_ROLLBACK=PASS'
        if(trim(test_scope)=='--atm02-dense') &
             call probe_root_retry(active,before,forcing,interval%t0,interval%t1)
      end if
      call fresh%close(code)
      call require(code==FMR_APP_BOOT_OK,'ATM02 fresh closes')
    end do
    call owner%close(code)
    call require(code==FMR_APP_BOOT_OK,'ATM02 owner closes')
  end subroutine
  subroutine verify_root_event_rollback(profile,before,expected,forcing,t_start,t_end)
    type(fmr_production_application_config_t),intent(in)::profile
    type(fmr_committed_restart_bundle_t),intent(in)::before,expected
    type(fmr_b110_physical_forcing_t),intent(in)::forcing(:)
    real(real64),intent(in)::t_start,t_end
    type(fmr_production_application_config_t)::limited
    type(fmr_production_application_bootstrap_t)::owner
    type(fmr_committed_restart_bundle_t)::after,replayed
    type(fmr_serialized_column_result_t),allocatable::result(:)
    type(fmr_serialized_commit_receipt_record_t),allocatable::receipt(:)
    integer::variant,code,tile
    logical::ok
    do variant=0,2
      limited=profile
      if(variant==0) nullify(limited%free_drainage_indicator)
      if(variant==1) limited%numerical%transaction%max_retries=0
      if(variant==2) limited%numerical%max_committed_substeps=1
      call owner%initialize(limited,code)
      call require(code==FMR_APP_BOOT_OK,'root event limited owner initializes')
      call owner%restore_committed_restart(before,9903_int64,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'root event accepted boundary restores')
      call owner%run_standalone_with_forcing_receipts(t_start,t_end,forcing,result,receipt,code)
      call require(code/=FMR_APP_BOOT_OK.and.all(.not.result%committed).and.all(.not.result%completed), &
           'root event limited interval rejects')
      if(variant==0) call require(all(result%solver_headcalc_calls==0),'unbound root event rejects before solve')
      if(variant==1) call require(all(result%solver_headcalc_calls>0).and.all(result%accepted_substeps==0), &
           'root event real failure before acceptance')
      if(variant==2) call require(all(result%accepted_substeps==1),'root event partial internal acceptance')
      call require(all(.not.result%actual_transpiration_available).and. &
           all(result%actual_transpiration_amount==0.0_real64),'failed root event publishes no transpiration')
      do tile=1,NTILE
        call require(.not.receipt(tile)%receipt%ready(),'failed root event has no ready receipt')
      end do
      call owner%export_committed_restart(9903_int64,after,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'failed root event remains exportable')
      call compare_restart_bundles(before,after,'root event exact physical history provenance rollback')
      call owner%close(code)
      call require(code==FMR_APP_BOOT_OK,'limited root event owner closes')
    end do
    ! Replay from the exported boundary after an actual partially accepted failure.
    call owner%initialize(profile,code)
    call require(code==FMR_APP_BOOT_OK,'root event replay owner initializes')
    call owner%restore_committed_restart(after,9903_int64,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'root event replay restores failed attempt boundary')
    call owner%run_standalone_with_forcing_receipts(t_start,t_end,forcing,result,receipt,code)
    call require(code==FMR_APP_BOOT_OK.and.all(result%committed).and.all(result%completed),'root event replay commits')
    call require(maxval(abs(result%mass%residual))<=HARD_MASS_GATE,'root event replay hard mass')
    do tile=1,NTILE
      call require(receipt(tile)%receipt%ready().and.result(tile)%actual_transpiration_available, &
           'root event replay publishes accepted receipt and uptake')
      call require(abs(result(tile)%actual_transpiration_amount- &
           sum(forcing(tile)%root_extraction_sink)*(t_end-t_start))<HARD_MASS_GATE,'root event replay root amount')
    end do
    call owner%export_committed_restart(9903_int64,replayed,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'root event replay exports')
    call compare_restart_bundles(expected,replayed,'root event replay equals uninterrupted owner')
    call owner%close(code)
    call require(code==FMR_APP_BOOT_OK,'root event replay closes')
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_ROOT_EVENT_ROLLBACK_REPLAY=PASS'
  end subroutine

  subroutine probe_root_retry(profile,before,forcing,t_start,t_end)
    type(fmr_production_application_config_t),intent(in)::profile
    type(fmr_committed_restart_bundle_t),intent(in)::before
    type(fmr_b110_physical_forcing_t),intent(in)::forcing(:)
    real(real64),intent(in)::t_start,t_end
    type(fmr_production_application_config_t)::dense
    type(fmr_production_application_bootstrap_t)::owner
    type(fmr_committed_restart_bundle_t)::after,expected
    type(fmr_serialized_column_result_t),allocatable::result(:)
    type(fmr_serialized_commit_receipt_record_t),allocatable::receipt(:)
    integer::code,tile,replay
    logical::ok
    dense=profile
    dense%numerical%transaction%retry_scale=0.9_real64
    dense%numerical%transaction%max_retries=128
    do replay=1,2
      call owner%initialize(dense,code)
      call require(code==FMR_APP_BOOT_OK,'dense root owner initializes')
      call owner%restore_committed_restart(before,9903_int64,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'dense root replay restores original third-period boundary')
      observed_event_calls=0
      call owner%run_standalone_with_forcing_receipts(t_start,t_end,forcing,result,receipt,code)
      write(*,*) 'ROOT_DENSE_RETRY',replay,code,result%kernel_status,result%accepted_substeps
      call require(code==FMR_APP_BOOT_OK.and.all(result%completed).and.all(result%committed), &
           'dense root full third period completes')
      call require(observed_event_calls==0,'dense root continuation never reseeds accepted history')
      call require(maxval(abs(result%mass%residual))<=HARD_MASS_GATE,'dense root hard mass')
      do tile=1,NTILE
        call require(receipt(tile)%receipt%ready().and.result(tile)%actual_transpiration_available, &
             'dense root accepted publication')
        call require(abs(result(tile)%actual_transpiration_amount- &
             sum(forcing(tile)%root_extraction_sink)*(t_end-t_start))<HARD_MASS_GATE,'dense root amount unchanged')
      end do
      call owner%export_committed_restart(9903_int64,after,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'dense root export')
      if(replay==1) expected=after
      if(replay==2) call compare_restart_bundles(expected,after,'dense root fresh restart replay exact')
      call owner%close(code)
      call require(code==FMR_APP_BOOT_OK,'dense root owner closes')
    end do
  end subroutine

  subroutine verify_opt_in_guards(valid)
    type(fmr_production_application_config_t), intent(in) :: valid
    type(fmr_production_application_config_t) :: invalid
    type(fmr_production_application_bootstrap_t) :: owner
    integer :: code,j
    if(associated(valid%storage_difference)) then
      invalid=valid
      nullify(invalid%free_drainage_indicator)
      do j=1,NTILE
        invalid%tiles(j)%parameters%bottom_mode=2
      end do
      call owner%initialize(invalid,code)
      call require(code==FMR_APP_BOOT_PROFILE_NOT_ADMITTED.and..not.owner%ready(), &
           'storage-only opt-in rejects prescribed flux')
      do j=1,NTILE
        invalid%tiles(j)%parameters%bottom_mode=5
      end do
      call owner%initialize(invalid,code)
      call require(code==FMR_APP_BOOT_PROFILE_NOT_ADMITTED.and..not.owner%ready(), &
           'storage-only opt-in rejects groundwater')
    end if
    invalid=valid
    invalid%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    deallocate(invalid%tiles(1)%initial_right_derivative)
    call owner%initialize(invalid,code)
    call require(code==FMR_APP_BOOT_PROFILE_NOT_ADMITTED.and..not.owner%ready(), &
         'opt-in requires temporal history layout for every tile')
    invalid=valid
    do j=1,NTILE
      invalid%tiles(j)%parameters%bottom_mode=2
    end do
    call owner%initialize(invalid,code)
    call require(code==FMR_APP_BOOT_PROFILE_NOT_ADMITTED.and..not.owner%ready(), &
         'free drainage opt-in cannot activate on prescribed flux')
    invalid=valid
    do j=1,NTILE
      invalid%tiles(j)%parameters%bottom_mode=5
    end do
    call owner%initialize(invalid,code)
    call require(code==FMR_APP_BOOT_PROFILE_NOT_ADMITTED.and..not.owner%ready(), &
         'free drainage opt-in cannot activate on groundwater profile')
    call owner%initialize(valid,code)
    call require(code==FMR_APP_BOOT_OK.and.owner%ready(),'failed admissions leave owner reusable')
    call owner%close(code)
    call require(code==FMR_APP_BOOT_OK.and..not.owner%ready(),'opt-in owner closes')
    invalid=valid
    nullify(invalid%free_drainage_indicator)
    nullify(invalid%storage_difference)
    call owner%initialize(invalid,code)
    call require(code==FMR_APP_BOOT_OK.and.owner%ready(),'owner reusable with default configuration')
    call owner%close(code)
    call require(code==FMR_APP_BOOT_OK,'default owner closes after opt-in')
  end subroutine
  subroutine traced_indicator(request,solution,history,certificate)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solution
    type(soil_water_temporal_indicator_request_t), intent(in) :: history
    type(soil_water_temporal_indicator_result_t), intent(out) :: certificate
    if(history%forcing_event_at_start) observed_event_calls=observed_event_calls+1
    call evaluate_free_drainage_temporal_indicator(request,solution,history,certificate)
    if(capture_low_rain) then
      ! Copy owned values only; borrowed callback pointers must not escape.
      low_rain_request%base_state=request%base_state
      low_rain_request%boundary=request%boundary
      low_rain_request%numerical=request%numerical
      low_rain_request%physical=request%physical
      low_rain_request%step_duration=request%step_duration
      low_rain_history=history
    end if
    write(*,*) 'OWNER_CERT',request%step_duration,trim(certificate%route),certificate%head_inf_bound
  end subroutine
  subroutine diagnose_low_rain_boundary(p,forcing)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),intent(in)::forcing
    type(soil_water_parameter_set_t),target::geometry
    type(b110_default_mvg_parameters_t),target::hydraulics
    type(b110_default_mvg_provider_t),target::provider
    type(b110_source_sink_provider_t),target::sink
    type(fixed_flux_top_boundary_provider_t),target::top_provider
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::workspace
    type(soil_water_solve_request_t)::request
    type(soil_water_solve_result_t)::solution
    type(soil_water_temporal_indicator_result_t)::certificate
    real(real64)::dt,ledger
    integer::level,eligible
    geometry%parameter_set_id=p%parameter_set_id
    geometry%active_nodes=p%active_nodes
    geometry%z=p%z; geometry%dz=p%dz; geometry%node_distance=p%node_distance
    call initialize_b110_default_mvg_parameters(hydraulics,p%cofgen)
    call bind_b110_source_sink_provider(sink,forcing%drainage_flux_by_level, &
         forcing%subsurface_irrigation_source,forcing%root_extraction_sink)
    request=low_rain_request
    request%parameters=>geometry
    request%evaluation%constitutive=>provider
    request%evaluation%source_sink=>sink
    request%evaluation%top_boundary=>top_provider
    request%evaluation%storage_difference=>evaluate_mvg_storage_difference_service
    call require(.not.low_rain_history%forcing_event_at_start,'low-rain diagnostic is beyond initial event')
    eligible=0
    do level=0,19
      dt=low_rain_request%step_duration/2.0_real64**level
      if(level>=10) dt=low_rain_request%step_duration*(1.0_real64-0.025_real64*real(level-9,real64))
      request%step_duration=dt
      call bind_b110_default_mvg_provider(provider,hydraulics,dt)
      call solver%solve(request,workspace,solution)
      if(level==1) call require(solution%status/=SW_SOLVE_CONVERGED,'binary halving reproduces native rejection')
      write(*,'(a,i0,a,es23.15,a,i0,a,es23.15,a,l1,a,l1)') 'LOW_RAIN_SOLVE level=',level, &
           ':dt=',dt,':status=',solution%status,':residual=',maxval(abs(workspace%richards%residual)), &
           ':balance=',any(workspace%richards%nonconverged_balance),':head=',any(workspace%richards%nonconverged_head)
      if(solution%status/=SW_SOLVE_CONVERGED) cycle
      call evaluate_free_drainage_temporal_indicator(request,solution,low_rain_history,certificate)
      ledger=sum((solution%candidate_state%water_content-request%base_state%water_content)*p%dz)+ &
           dt*(solution%top_flux-solution%bottom_flux+sum(forcing%drainage_flux_by_level)+ &
           sum(forcing%root_extraction_sink)-sum(forcing%subsurface_irrigation_source))
      write(*,'(a,i0,a,l1,2(a,es23.15))') 'LOW_RAIN_CERT level=',level,':available=',certificate%available, &
           ':bound=',certificate%head_inf_bound,':mass=',ledger
      if(level>=12.and.certificate%available.and.certificate%head_inf_bound<=1.0e-5_real64.and. &
           abs(ledger)<=HARD_MASS_GATE) eligible=eligible+1
    end do
    call require(eligible==8,'eight intermediate durations pass native temporal and mass gates')
  end subroutine
  subroutine diagnose_root_boundary(p,forcing)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),target,intent(in)::forcing
    type(soil_water_parameter_set_t),target::geometry
    type(b110_default_mvg_parameters_t),target::hydraulics
    type(b110_default_mvg_provider_t),target::provider
    type(b110_source_sink_provider_t),target::sink
    type(b110_root_sink_provider_t),target::root
    type(fixed_flux_top_boundary_provider_t),target::top_provider
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::workspace
    type(soil_water_solve_request_t)::request
    type(soil_water_solve_result_t)::solution
    type(soil_water_temporal_indicator_result_t)::certificate
    real(real64),allocatable,target::zero_root(:)
    real(real64)::dt,ledger
    integer::level,eligible
    call require(allocated(low_rain_request%base_state%pressure_head),'root diagnostic captured owned state')
    call require(.not.low_rain_history%forcing_event_at_start,'root diagnostic does not reseed history')
    geometry%parameter_set_id=p%parameter_set_id
    geometry%active_nodes=p%active_nodes
    geometry%z=p%z; geometry%dz=p%dz; geometry%node_distance=p%node_distance
    call initialize_b110_default_mvg_parameters(hydraulics,p%cofgen)
    allocate(zero_root(p%active_nodes)); zero_root=0.0_real64
    call bind_b110_source_sink_provider(sink,forcing%drainage_flux_by_level, &
         forcing%subsurface_irrigation_source,zero_root)
    call bind_b110_root_sink_provider(root,forcing%root_extraction_sink)
    request=low_rain_request
    request%parameters=>geometry
    request%evaluation%constitutive=>provider
    request%evaluation%source_sink=>sink
    request%evaluation%root_sink=>root
    request%evaluation%top_boundary=>top_provider
    request%evaluation%storage_difference=>evaluate_mvg_storage_difference_service
    eligible=0
    do level=0,59
      dt=low_rain_request%step_duration*0.8_real64**level
      if(level>=10) dt=low_rain_request%step_duration*(1.0_real64-0.01_real64*real(level-9,real64))
      if(level>=30) then
        dt=low_rain_request%step_duration*0.8_real64**(level-30)
        if(level>=40) dt=low_rain_request%step_duration*(1.0_real64-0.01_real64*real(level-39,real64))
        ! Same binary exponent as this fixture's absolute clock. This is a grid
        ! sensitivity probe, not an exact reconstruction of the retry's raw dt.
        dt=(T0+dt)-T0
      end if
      request%step_duration=dt
      call bind_b110_default_mvg_provider(provider,hydraulics,dt)
      call solver%solve(request,workspace,solution)
      write(*,'(a,i0,a,es23.15,a,i0,a,es23.15,a,l1,a,l1)') 'ROOT_CONTINUATION_SOLVE level=',level, &
           ':dt=',dt,':status=',solution%status,':residual=',maxval(abs(workspace%richards%residual)), &
           ':balance=',any(workspace%richards%nonconverged_balance),':head=',any(workspace%richards%nonconverged_head)
      if(solution%status/=SW_SOLVE_CONVERGED) cycle
      call evaluate_free_drainage_temporal_indicator(request,solution,low_rain_history,certificate)
      ledger=sum((solution%candidate_state%water_content-request%base_state%water_content)*p%dz)+ &
           dt*(solution%top_flux-solution%bottom_flux+sum(forcing%drainage_flux_by_level)+ &
           sum(forcing%root_extraction_sink)-sum(forcing%subsurface_irrigation_source))
      write(*,'(a,i0,a,l1,2(a,es23.15))') 'ROOT_CONTINUATION_CERT level=',level, &
           ':available=',certificate%available,':bound=',certificate%head_inf_bound,':mass=',ledger
      if(certificate%available.and.certificate%head_inf_bound<=1.0e-5_real64.and. &
           abs(ledger)<=HARD_MASS_GATE) eligible=eligible+1
    end do
    write(*,'(a,i0)') 'ROOT_CONTINUATION_ELIGIBLE=',eligible
  end subroutine
  subroutine probe_low_rain_retry(profile,before,forcing,t_start,t_end,amount)
    type(fmr_production_application_config_t),intent(in)::profile
    type(fmr_committed_restart_bundle_t),intent(in)::before
    type(fmr_b110_physical_forcing_t),intent(in)::forcing(:)
    real(real64),intent(in)::t_start,t_end,amount(:)
    type(fmr_production_application_config_t)::dense
    type(fmr_production_application_bootstrap_t)::owner
    type(fmr_committed_restart_bundle_t)::after,expected
    type(fmr_serialized_column_result_t),allocatable::result(:)
    type(fmr_serialized_commit_receipt_record_t),allocatable::receipt(:)
    type(fmr_vonhhbraden_source_window_progress_t)::progress
    integer::code,tile,run_code,replay
    logical::ok
    dense=profile
    dense%numerical%transaction%retry_scale=0.8_real64
    dense%numerical%transaction%max_retries=64
    do replay=1,2
    call owner%initialize(dense,code)
    call require(code==FMR_APP_BOOT_OK,'dense retry owner initialized')
    call owner%restore_committed_restart(before,9902_int64,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'dense retry starts at same accepted source boundary')
    observed_event_calls=0
    call owner%run_standalone_with_forcing_receipts(t_start,t_end,forcing,result,receipt,run_code)
    write(*,*) 'LOW_RAIN_DENSE_RETRY',run_code,result%kernel_status,result%accepted_substeps
    call require(run_code==FMR_APP_BOOT_OK.and.all(result%completed),'dense retry full low-rain window completes')
    call require(observed_event_calls>0.and.observed_event_calls<=NTILE*65.and. &
         sum(result%accepted_substeps)>observed_event_calls,'dense retry event remains initial-boundary-only')
    call owner%export_committed_restart(9902_int64,after,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'dense retry owner exportable')
    if(replay==1) expected=after
    if(replay==2) call compare_restart_bundles(expected,after,'dense retry fresh restart replay identical')
    if(run_code==FMR_APP_BOOT_OK) then
      call require(all(result%committed).and.maxval(abs(result%mass%residual))<=HARD_MASS_GATE, &
           'dense retry successful hard mass')
    else
      call require(all(.not.result%committed),'dense retry failed with no publication')
      call compare_restart_bundles(before,after,'dense retry failed state unchanged')
    end if
    do tile=1,NTILE
      call fmr_initialize_vonhhbraden_source_window_progress(int(9900+tile,int64),t_start,t_end,amount(tile), &
           progress,code,profile%tiles(tile)%tile_id,before%records(tile)%revision)
      call require(code==FMR_VONHHBRADEN_PROGRESS_OK,'dense retry source initialized')
      call publish_ppa_wu04c_accepted_progress(progress,receipt(tile)%receipt,amount(tile),code)
      if(run_code==FMR_APP_BOOT_OK) then
        call require(code==PPA_WU04C_PUBLICATION_OK.and.progress%remaining_interception()==0.0_real64, &
             'dense retry accepted aggregate consumed once')
        call publish_ppa_wu04c_accepted_progress(progress,receipt(tile)%receipt,amount(tile),code)
        call require(code/=PPA_WU04C_PUBLICATION_OK.and.progress%remaining_interception()==0.0_real64, &
             'dense retry duplicate receipt rejected')
      else
        call require(code/=PPA_WU04C_PUBLICATION_OK.and.progress%remaining_interception()==amount(tile), &
             'dense retry failed aggregate untouched')
      end if
    end do
    if(replay==2) call verify_dense_followups(owner,dense,t_end)
    call owner%close(code)
    call require(code==FMR_APP_BOOT_OK,'dense retry owner closed')
    end do
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_GASH_LOW_RAIN_DENSE_RESTART=PASS'
  end subroutine
  subroutine verify_dense_followups(owner,profile,t_begin)
    type(fmr_production_application_bootstrap_t),intent(inout)::owner
    type(fmr_production_application_config_t),intent(in)::profile
    real(real64),intent(in)::t_begin
    type(fmr_production_application_bootstrap_t)::fresh
    type(fmr_committed_restart_bundle_t)::before,after,resumed
    type(fmr_committed_top_state_t),allocatable::top(:),fresh_top(:)
    type(fmr_b110_physical_forcing_t)::forcing(NTILE),fresh_forcing(NTILE)
    type(fmr_serialized_column_result_t),allocatable::result(:),fresh_result(:)
    type(fmr_serialized_commit_receipt_record_t),allocatable::receipt(:),fresh_receipt(:)
    type(vonhhbraden_source_window_t)::source
    type(vonhhbraden_result_t)::source_result
    type(fmr_vonhhbraden_source_window_progress_t)::progress
    real(real64)::t_start,t_end,amount(NTILE),fresh_amount(NTILE)
    integer::window,tile,code,pass
    logical::ok,marked
    source%leaf_area_index=2.0_real64
    source%vegetation_cover_fraction=0.5_real64
    do window=1,3
      marked=window==2
      t_start=t_begin+real(window-1,real64)*(T1-T0)
      t_end=t_start+(T1-T0)
      source%gross_rain_cm_per_day=0.04_real64
      source%sprinkling_irrigation_cm_per_day=0.02_real64
      if(window>=2) then
        source%gross_rain_cm_per_day=0.16_real64
        source%sprinkling_irrigation_cm_per_day=0.08_real64
      end if
      call evaluate_gash_source_window(WINDOW_GASH,source, &
           source_result%source_window_interception_cm_per_day,source_result%status)
      call require(source_result%status==VONHHBRADEN_AVAILABLE,'dense successor source available')
      call owner%export_committed_restart(9902_int64,before,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'dense successor pre-window export')
      call fresh%initialize(profile,code)
      call require(code==FMR_APP_BOOT_OK,'dense successor fresh initialize')
      call fresh%restore_committed_restart(before,9902_int64,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'dense successor fresh restore')
      call owner%copy_committed_top_states(top,code)
      call require(code==FMR_APP_BOOT_OK,'dense successor owner top snapshot')
      call fresh%copy_committed_top_states(fresh_top,code)
      call require(code==FMR_APP_BOOT_OK,'dense successor restored top snapshot')
      do tile=1,NTILE
        call build_window_forcing(profile,tile,top(tile),source,source_result,forcing(tile),amount(tile))
        call build_window_forcing(profile,tile,fresh_top(tile),source,source_result,fresh_forcing(tile),fresh_amount(tile))
        call require(amount(tile)==fresh_amount(tile).and.forcing(tile)%top_flux==fresh_forcing(tile)%top_flux, &
             'dense successor forcing reproduced from restored owner')
        forcing(tile)%temporal_forcing_event=marked
        fresh_forcing(tile)%temporal_forcing_event=marked
        if(marked) then
          forcing(tile)%temporal_forcing_event_time=t_start
          fresh_forcing(tile)%temporal_forcing_event_time=t_start
        end if
      end do
      do pass=1,2
        observed_event_calls=0
        if(pass==1) then
          call owner%run_standalone_with_forcing_receipts(t_start,t_end,forcing,result,receipt,code)
        else
          call fresh%run_standalone_with_forcing_receipts(t_start,t_end,fresh_forcing,fresh_result,fresh_receipt,code)
          result=fresh_result
          receipt=fresh_receipt
        end if
        write(*,*) 'DENSE_SUCCESSOR_WINDOW',window,pass,code,result%kernel_status,result%accepted_substeps
        call require(code==FMR_APP_BOOT_OK.and.all(result%completed).and.all(result%committed), &
             'dense successor window commits')
        call require(maxval(abs(result%mass%residual))<=HARD_MASS_GATE,'dense successor hard mass')
        if(marked) then
          call require(observed_event_calls>0.and.observed_event_calls<=NTILE*65.and. &
               sum(result%accepted_substeps)>observed_event_calls,'dense successor marked boundary only')
        else
          call require(observed_event_calls==0,'dense successor unmarked continuation retains history')
        end if
        do tile=1,NTILE
          call fmr_initialize_vonhhbraden_source_window_progress(int(10000+10*window+tile,int64), &
               t_start,t_end,amount(tile),progress,code,profile%tiles(tile)%tile_id,before%records(tile)%revision)
          call require(code==FMR_VONHHBRADEN_PROGRESS_OK,'dense successor source initialized')
          call publish_ppa_wu04c_accepted_progress(progress,receipt(tile)%receipt,amount(tile),code)
          call require(code==PPA_WU04C_PUBLICATION_OK.and.progress%remaining_interception()==0.0_real64, &
               'dense successor source closes exactly once')
          call publish_ppa_wu04c_accepted_progress(progress,receipt(tile)%receipt,amount(tile),code)
          call require(code/=PPA_WU04C_PUBLICATION_OK,'dense successor duplicate receipt rejected')
        end do
      end do
      call owner%export_committed_restart(9902_int64,after,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'dense successor final export')
      call fresh%export_committed_restart(9902_int64,resumed,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'dense successor restored final export')
      call compare_restart_bundles(after,resumed,'dense successor exact full restart continuation')
      call fresh%close(code)
      call require(code==FMR_APP_BOOT_OK,'dense successor fresh closes')
    end do
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_GASH_LOW_HIGH_SEQUENCE=PASS'
  end subroutine
  subroutine initialize_application_config(value)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64) :: conductivity0
    integer :: k

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(NTILE))
    do k = 1, NTILE
      value%tiles(k)%tile_id = 610100_int64 + int(k, int64)
      value%tiles(k)%ledger_id = 710100_int64 + int(k, int64)
      value%tiles(k)%template%template_id = 610200_int64 + int(k, int64)
      value%tiles(k)%template%physics_topology_id = 610210_int64
      value%tiles(k)%template%vertical_layout_id = 610220_int64
      value%tiles(k)%template%state_layout_id = 610230_int64
      value%tiles(k)%template%solver_interface_id = 610240_int64
      value%tiles(k)%template%optional_state_layout_id = 0_int64
      value%tiles(k)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
      value%tiles(k)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      call initialize_parameters(value%tiles(k)%parameters, 620000_int64 + int(k, int64))
      call initialize_state_and_forcing(value%tiles(k)%parameters, value%tiles(k)%initial_state, &
           value%tiles(k)%base_forcing, 1.0_real64 + 0.013_real64 * real(k, real64), conductivity0)
      value%tiles(k)%initial_state%groundwater_level = -2.0_real64 - 0.007_real64 * real(k, real64)

      value%tiles(k)%groundwater_datum%available = .true.
      value%tiles(k)%groundwater_datum%datum_id = 630000_int64 + int(k, int64)
      value%tiles(k)%groundwater_datum%bottom_boundary_elevation_m = 0.0_real64
    end do
  end subroutine initialize_application_config

  subroutine initialize_parameters(p, parameter_id)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer(int64), intent(in) :: parameter_id
    integer :: k

    p%parameter_set_id = parameter_id
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

  subroutine initialize_state_and_forcing(p, state, forcing, scale, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: scale
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
      forcing%drainage_flux_by_level(1,i) = scale * 1.0e-5_real64 * real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -scale * 2.0e-6_real64 * real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
           forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine initialize_state_and_forcing

  subroutine verify_wu04c_production_composition(value)
    type(fmr_production_application_config_t), intent(in) :: value
    type(fmr_production_application_config_t) :: transient_profile
    type(soil_water_parameter_set_t) :: geometry
    type(b110_default_mvg_parameters_t) :: hydraulics
    type(b110_dynamic_top_boundary_request_t) :: request
    type(vonhhbraden_source_window_t) :: source
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_forcing_t), allocatable :: forcing_vector(:)
    type(fmr_production_application_bootstrap_t) :: production_app
    type(fmr_serialized_column_result_t), allocatable :: production_results(:)
    type(fmr_serialized_commit_receipt_record_t), allocatable :: receipts(:)
    real(real64) :: interception_by_tile(NTILE)
    type(ppa_wu04c_production_forcing_diagnostics_t) :: diagnostics
    type(ppa_wu04d_production_forcing_diagnostics_t) :: gash_diagnostics
    type(gash_parameters_t) :: gash
    real(real64) :: interception
    integer :: tile, local_status

    transient_profile = value
    geometry%parameter_set_id = value%tiles(1)%parameters%parameter_set_id
    geometry%active_nodes = value%tiles(1)%parameters%active_nodes
    allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), geometry%node_distance(geometry%active_nodes))
    geometry%z = value%tiles(1)%parameters%z
    geometry%dz = value%tiles(1)%parameters%dz
    geometry%node_distance = value%tiles(1)%parameters%node_distance
    call initialize_b110_default_mvg_parameters(hydraulics, value%tiles(1)%parameters%cofgen)
    request%conductivity_mean_method = value%tiles(1)%parameters%swkmean
    request%pressure_head_top_cm = value%tiles(1)%initial_state%pressure_head(1)
    request%water_content_top = value%tiles(1)%initial_state%water_content(1)
    request%step_duration_day = T1 - T0
    request%ponding_max_cm = 2.0_real64
    request%runoff_resistance_day = 1.0_real64
    request%runoff_exponent = 1.0_real64
    source%gross_rain_cm_per_day = 0.40_real64
    source%sprinkling_irrigation_cm_per_day = 0.20_real64
    source%leaf_area_index = 2.0_real64
    source%vegetation_cover_fraction = 0.5_real64
    call materialize_ppa_wu04c_production_forcing(value%tiles(1)%base_forcing, request, geometry, hydraulics, source, &
         0.12_real64, 0.20_real64, 0.10_real64, forcing, interception, diagnostics)
    call require(diagnostics%status == PPA_WU04C_PRODUCTION_FORCING_OK .and. diagnostics%result_produced, &
         'WU04C full forcing composition')
    call require(abs(interception - 0.06_real64) <= 1.e-14_real64 .and. forcing%top_flux == diagnostics%top_result%actual_top_flux_cm_per_day, &
         'WU04C full forcing values')
    gash%free_throughfall = 0.10_real64; gash%stemflow = 0.05_real64
    gash%canopy_storage_cm = 0.10_real64; gash%average_evaporation = 0.05_real64
    gash%average_precipitation = 0.40_real64
    call materialize_ppa_wu04d_production_forcing(value%tiles(1)%base_forcing, request, geometry, hydraulics, gash, source, &
         0.20_real64, 0.10_real64, forcing, interception, gash_diagnostics)
    call require(gash_diagnostics%status == PPA_WU04D_PRODUCTION_FORCING_OK .and. gash_diagnostics%result_produced, &
         'WU04D full forcing composition')
    deallocate(geometry%z, geometry%dz, geometry%node_distance)

    allocate(forcing_vector(NTILE))
    do tile = 1, NTILE
      geometry%parameter_set_id = value%tiles(tile)%parameters%parameter_set_id
      geometry%active_nodes = value%tiles(tile)%parameters%active_nodes
      allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), geometry%node_distance(geometry%active_nodes))
      geometry%z = value%tiles(tile)%parameters%z; geometry%dz = value%tiles(tile)%parameters%dz
      geometry%node_distance = value%tiles(tile)%parameters%node_distance
      call initialize_b110_default_mvg_parameters(hydraulics, value%tiles(tile)%parameters%cofgen)
      request = b110_dynamic_top_boundary_request_t()
      request%conductivity_mean_method = value%tiles(tile)%parameters%swkmean
      request%pressure_head_top_cm = value%tiles(tile)%initial_state%pressure_head(1)
      request%water_content_top = value%tiles(tile)%initial_state%water_content(1)
      request%step_duration_day = T1 - T0; request%ponding_max_cm = 2.0_real64
      request%runoff_resistance_day = 1.0_real64; request%runoff_exponent = 1.0_real64
      call materialize_ppa_wu04c_production_forcing(value%tiles(tile)%base_forcing, request, geometry, hydraulics, source, &
           0.12_real64, 0.20_real64, 0.10_real64, forcing_vector(tile), interception, diagnostics)
      call require(diagnostics%status == PPA_WU04C_PRODUCTION_FORCING_OK, 'WU04C tile forcing composition')
      ! The adapter returns cm/day; source progress consumes interval amounts in cm.
      interception_by_tile(tile)=interception*(T1-T0)
      call require(abs(interception_by_tile(tile)-0.03_real64)<1.0e-15_real64, &
           'WU04C half-day interception amount cm')
      call seed_initial_derivative(transient_profile%tiles(tile)%parameters, &
           transient_profile%tiles(tile)%initial_state,forcing_vector(tile), &
           transient_profile%tiles(tile)%initial_right_derivative)
      deallocate(geometry%z, geometry%dz, geometry%node_distance)
    end do
    call production_app%initialize(transient_profile, local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'WU04C production owner initialize')
    if(trim(test_scope)=='--stable-receipts') then
      call production_app%run_standalone_with_forcing_receipts(T0,T1,forcing_vector,production_results,receipts,local_status)
    else
      call production_app%run_standalone_with_forcing(T0, T1, forcing_vector, production_results, local_status)
    end if
    do tile=1,NTILE
      write(*,*) 'OWNER_DIAG',tile,local_status,production_results(tile)%kernel_status, &
           production_results(tile)%accepted_substeps,production_results(tile)%solver_headcalc_calls, &
           production_results(tile)%solver_nonlinear_iterations
    end do
    call require(local_status == FMR_APP_BOOT_OK .and. all(production_results%completed) .and. all(production_results%committed), &
         'WU04C production owner commit')
    call require(maxval(abs(production_results%mass%residual)) <= HARD_MASS_GATE, 'WU04C production hard mass')
    if(trim(test_scope)=='--stable-receipts') &
         call verify_storage_receipt_restart(production_app,transient_profile,forcing_vector,receipts,interception_by_tile)
    if(trim(test_scope)=='--stable-windows'.or.trim(test_scope)=='--window-rejection'.or. &
         is_gash) &
         call verify_changing_windows(production_app,transient_profile)
    call production_app%close(local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'WU04C production owner close')
    deallocate(forcing_vector)

    if(trim(test_scope)=='--gash-receipts') then
      ! One frozen daily source aggregate; two half-day receipts partition it.
      source%gross_rain_cm_per_day=0.20_real64
      source%sprinkling_irrigation_cm_per_day=0.10_real64
    end if
    allocate(forcing_vector(NTILE))
    do tile = 1, NTILE
      geometry%parameter_set_id = value%tiles(tile)%parameters%parameter_set_id
      geometry%active_nodes = value%tiles(tile)%parameters%active_nodes
      allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), geometry%node_distance(geometry%active_nodes))
      geometry%z = value%tiles(tile)%parameters%z; geometry%dz = value%tiles(tile)%parameters%dz
      geometry%node_distance = value%tiles(tile)%parameters%node_distance
      call initialize_b110_default_mvg_parameters(hydraulics, value%tiles(tile)%parameters%cofgen)
      request = b110_dynamic_top_boundary_request_t()
      request%conductivity_mean_method = value%tiles(tile)%parameters%swkmean
      request%pressure_head_top_cm = value%tiles(tile)%initial_state%pressure_head(1)
      request%water_content_top = value%tiles(tile)%initial_state%water_content(1)
      request%step_duration_day = T1 - T0; request%ponding_max_cm = 2.0_real64
      request%runoff_resistance_day = 1.0_real64; request%runoff_exponent = 1.0_real64
      call materialize_ppa_wu04d_production_forcing(value%tiles(tile)%base_forcing, request, geometry, hydraulics, gash, source, &
           0.20_real64, 0.10_real64, forcing_vector(tile), interception, gash_diagnostics)
      call require(gash_diagnostics%status == PPA_WU04D_PRODUCTION_FORCING_OK, 'WU04D tile forcing composition')
      interception_by_tile(tile)=interception*(T1-T0)
      if(trim(test_scope)=='--gash-receipts') &
           call require(abs(2.0_real64*interception_by_tile(tile)- &
           gash_diagnostics%source_aggregate_cm_per_day*2.0_real64*(T1-T0))<1.0e-15_real64, &
           'Gash split receipts cover the full frozen source aggregate')
      call seed_initial_derivative(transient_profile%tiles(tile)%parameters, &
           transient_profile%tiles(tile)%initial_state,forcing_vector(tile), &
           transient_profile%tiles(tile)%initial_right_derivative)
      deallocate(geometry%z, geometry%dz, geometry%node_distance)
    end do
    call production_app%initialize(transient_profile, local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'WU04D production owner initialize')
    if(trim(test_scope)=='--gash-receipts') then
      call production_app%run_standalone_with_forcing_receipts(T0,T1,forcing_vector,production_results,receipts,local_status)
    else
      call production_app%run_standalone_with_forcing(T0, T1, forcing_vector, production_results, local_status)
    end if
    call require(local_status == FMR_APP_BOOT_OK .and. all(production_results%completed) .and. all(production_results%committed), &
         'WU04D production owner commit')
    call require(maxval(abs(production_results%mass%residual)) <= HARD_MASS_GATE, 'WU04D production hard mass')
    if(trim(test_scope)=='--gash-receipts') then
      call verify_storage_receipt_restart(production_app,transient_profile,forcing_vector,receipts,interception_by_tile)
      write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_GASH_SOURCE_RECEIPT_RESTART=PASS'
    end if
    call production_app%close(local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'WU04D production owner close')
    deallocate(forcing_vector)
  end subroutine verify_wu04c_production_composition

  subroutine verify_storage_receipt_restart(owner,profile,forcing,receipts,interception)
    type(fmr_production_application_bootstrap_t),intent(inout)::owner
    type(fmr_production_application_config_t),intent(in)::profile
    type(fmr_b110_physical_forcing_t),intent(in)::forcing(:)
    type(fmr_serialized_commit_receipt_record_t),intent(in)::receipts(:)
    real(real64),intent(in)::interception(:)
    type(fmr_production_application_bootstrap_t)::fresh
    type(fmr_committed_restart_bundle_t)::bundle,continued_bundle,resumed_bundle,bad_bundle
    type(fmr_vonhhbraden_source_window_progress_t)::progress(NTILE),resumed(NTILE)
    type(fmr_vonhhbraden_source_window_restart_t)::saved(NTILE),final_progress
    type(fmr_accepted_commit_receipt_t)::unready
    type(fmr_serialized_commit_receipt_record_t),allocatable::next_receipts(:),resumed_receipts(:)
    type(fmr_serialized_column_result_t),allocatable::next_results(:),resumed_results(:)
    real(real64),allocatable::history_a(:),history_b(:)
    real(real64)::t2
    integer::tile,code
    logical::ok
    t2=T1+(T1-T0)
    call require(size(receipts)==NTILE,'one aggregate accepted receipt per tile')
    do tile=1,NTILE
      call fmr_initialize_vonhhbraden_source_window_progress(9700_int64+int(tile,int64),T0,t2, &
           2.0_real64*interception(tile),progress(tile),code,profile%tiles(tile)%tile_id,0_int64)
      call require(code==FMR_VONHHBRADEN_PROGRESS_OK,'strong source progress initialize')
      call publish_ppa_wu04c_accepted_progress(progress(tile),unready,interception(tile),code)
      call require(code/=PPA_WU04C_PUBLICATION_OK,'uncommitted progress rejected')
      call publish_ppa_wu04c_accepted_progress(progress(tile),receipts(3-tile)%receipt,interception(tile),code)
      call require(code/=PPA_WU04C_PUBLICATION_OK,'foreign tile receipt rejected')
      call require(progress(tile)%remaining_interception()==2.0_real64*interception(tile), &
           'rejected receipt leaves aggregate untouched')
      call publish_ppa_wu04c_accepted_progress(progress(tile),receipts(tile)%receipt,interception(tile),code)
      call require(code==PPA_WU04C_PUBLICATION_OK,'strong accepted source progress')
      call publish_ppa_wu04c_accepted_progress(progress(tile),receipts(tile)%receipt,interception(tile),code)
      call require(code/=PPA_WU04C_PUBLICATION_OK,'duplicate accepted receipt rejected')
      call progress(tile)%export_restart(saved(tile),ok)
      call require(ok.and.saved(tile)%accepted_through_time==T1,'source progress time persisted')
      call require(saved(tile)%accepted_interception_cm==interception(tile),'source interception not double counted')
      call fmr_restore_vonhhbraden_source_window_progress(saved(tile),resumed(tile),ok,code)
      call require(ok.and.code==FMR_VONHHBRADEN_PROGRESS_OK,'source progress restored')
      call resumed(tile)%export_restart(final_progress,ok)
      call require(ok,'restored source identity export')
      call require(final_progress%source_window_id==saved(tile)%source_window_id.and. &
           final_progress%source_t0==saved(tile)%source_t0.and. &
           final_progress%source_t1==saved(tile)%source_t1.and. &
           final_progress%aggregate_aintc_cm==saved(tile)%aggregate_aintc_cm.and. &
           final_progress%accepted_through_time==saved(tile)%accepted_through_time.and. &
           final_progress%accepted_interception_cm==saved(tile)%accepted_interception_cm.and. &
           final_progress%receipt_lineage_id==saved(tile)%receipt_lineage_id.and. &
           final_progress%expected_origin_revision==saved(tile)%expected_origin_revision.and. &
           (final_progress%receipt_binding_ready.eqv.saved(tile)%receipt_binding_ready), &
           'all partially consumed source restart fields preserved exactly')
      call require(resumed(tile)%remaining_interception()==interception(tile), &
           'restart retains exactly the unconsumed half-window aggregate')
    end do
    call owner%export_committed_restart(9901_int64,bundle,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'strong owner restart exported')
    call verify_failed_interval_replay(profile,forcing,interception,bundle,.false.)
    call verify_failed_interval_replay(profile,forcing,interception,bundle,.true.)
    call fresh%initialize(profile,code)
    call require(code==FMR_APP_BOOT_OK,'fresh owner explicit numerical bindings')
    bad_bundle=bundle
    bad_bundle%records(2)%parameter_ref=-1_int64
    call fresh%restore_committed_restart(bad_bundle,9901_int64,ok,code)
    call require(.not.ok.and.code/=FMR_APP_BOOT_OK,'late invalid restart record rejected')
    call fresh%export_committed_restart(9901_int64,resumed_bundle,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'failed restore leaves owner exportable')
    do tile=1,NTILE
      call require(resumed_bundle%records(tile)%revision==0_int64,'failed restore publishes no earlier record')
      select type(a=>resumed_bundle%records(tile)%physical_state)
      class is(fmr_b110_physical_state_t)
        call require(all(a%pressure_head==profile%tiles(tile)%initial_state%pressure_head).and. &
             all(a%water_content==profile%tiles(tile)%initial_state%water_content),'failed restore preserves physical state')
      class default
        call require(.false.,'failed restore state type preserved')
      end select
    end do
    call fresh%restore_committed_restart(bundle,9901_int64,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'fresh owner restart restored')
    call owner%run_standalone_with_forcing_receipts(T1,t2,forcing,next_results,next_receipts,code)
    call require(code==FMR_APP_BOOT_OK.and.all(next_results%committed),'continued owner commits')
    call fresh%run_standalone_with_forcing_receipts(T1,t2,forcing,resumed_results,resumed_receipts,code)
    call require(code==FMR_APP_BOOT_OK.and.all(resumed_results%committed),'restored owner commits')
    call require(maxval(abs(next_results%mass%residual))<=HARD_MASS_GATE,'continued owner hard mass')
    call require(maxval(abs(resumed_results%mass%residual))<=HARD_MASS_GATE,'restored owner hard mass')
    call owner%export_committed_restart(9901_int64,continued_bundle,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'continued state exported')
    call fresh%export_committed_restart(9901_int64,resumed_bundle,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'resumed state exported')
    call compare_restart_bundles(continued_bundle,resumed_bundle,'mid-source-window full owner restart')
    do tile=1,NTILE
      call publish_ppa_wu04c_accepted_progress(progress(tile),next_receipts(tile)%receipt,interception(tile),code)
      call require(code==PPA_WU04C_PUBLICATION_OK,'continued source progress published')
      call publish_ppa_wu04c_accepted_progress(resumed(tile),resumed_receipts(tile)%receipt,interception(tile),code)
      call require(code==PPA_WU04C_PUBLICATION_OK,'restored source progress published')
      call require(progress(tile)%remaining_interception()==0.0_real64.and. &
           resumed(tile)%remaining_interception()==0.0_real64,'source aggregate exhausted exactly once')
      call resumed(tile)%export_restart(final_progress,ok)
      call require(ok.and.final_progress%accepted_through_time==t2.and. &
           final_progress%expected_origin_revision==2_int64,'restored source lineage advances')
      call require(continued_bundle%records(tile)%revision==resumed_bundle%records(tile)%revision.and. &
           continued_bundle%records(tile)%committed_time==resumed_bundle%records(tile)%committed_time, &
           'strong owner restart provenance identical')
      select type(a=>continued_bundle%records(tile)%physical_state)
      type is(fmr_b110_temporal_indicator_state_t)
        select type(b=>resumed_bundle%records(tile)%physical_state)
        type is(fmr_b110_temporal_indicator_state_t)
          call require(all(a%pressure_head==b%pressure_head).and.all(a%water_content==b%water_content), &
               'strong owner restart full physical arrays identical')
          call a%temporal_history_snapshot(history_a,ok)
          call require(ok,'continued owner history available')
          call b%temporal_history_snapshot(history_b,ok)
          call require(ok.and.all(history_a==history_b),'strong owner restart history identical')
        class default
          call require(.false.,'restored temporal state type')
        end select
      class default
        call require(.false.,'continued temporal state type')
      end select
    end do
    call fresh%close(code)
    call require(code==FMR_APP_BOOT_OK,'fresh owner closes')
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_SOURCE_RECEIPT_RESTART=PASS'
  end subroutine verify_storage_receipt_restart

  subroutine verify_failed_interval_replay(profile,forcing,interception,expected,partial_progress)
    type(fmr_production_application_config_t),intent(in)::profile
    type(fmr_b110_physical_forcing_t),intent(in)::forcing(:)
    real(real64),intent(in)::interception(:)
    type(fmr_committed_restart_bundle_t),intent(in)::expected
    logical,intent(in)::partial_progress
    type(fmr_production_application_config_t)::limited
    type(fmr_production_application_bootstrap_t)::retry_owner
    type(fmr_committed_restart_bundle_t)::before,after,replayed
    type(fmr_serialized_column_result_t),allocatable::attempt_results(:)
    type(fmr_serialized_commit_receipt_record_t),allocatable::attempt_receipts(:)
    type(fmr_vonhhbraden_source_window_progress_t)::progress(NTILE)
    type(fmr_vonhhbraden_source_window_restart_t)::progress_record
    logical::ok
    integer::code,tile
    ! Original strong forcing and tolerances, but no controller retries: the
    ! half-day principal solve is a real, reproducible nonconverged attempt.
    limited=profile
    if(partial_progress) then
      limited%numerical%max_committed_substeps=1
    else
      limited%numerical%transaction%max_retries=0
    end if
    call retry_owner%initialize(limited,code)
    call require(code==FMR_APP_BOOT_OK,'limited retry owner initialized')
    call retry_owner%export_committed_restart(9910_int64,before,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'pre-failure state snapshot')
    do tile=1,NTILE
      call fmr_initialize_vonhhbraden_source_window_progress(9800_int64+int(tile,int64),T0,T1, &
           interception(tile),progress(tile),code,profile%tiles(tile)%tile_id,0_int64)
      call require(code==FMR_VONHHBRADEN_PROGRESS_OK,'retry source progress initialized')
    end do
    call retry_owner%run_standalone_with_forcing_receipts(T0,T1,forcing,attempt_results,attempt_receipts,code)
    call require(code/=FMR_APP_BOOT_OK,'actual strong interval exhausts execution budget')
    call require(all(.not.attempt_results%completed).and.all(.not.attempt_results%committed), &
         'failed hydraulic attempt commits no column')
    call require(all(attempt_results%solver_headcalc_calls>0),'failure exercised real HeadCalc')
    if(partial_progress) then
      call require(all(attempt_results%accepted_substeps==1),'failure after one internally accepted substep')
    else
      call require(all(attempt_results%accepted_substeps==0),'failure without accepted substep')
    end if
    call require(size(attempt_receipts)==NTILE,'failed receipt slots returned')
    do tile=1,NTILE
      call require(.not.attempt_receipts(tile)%receipt%ready(),'failed hydraulic attempt has no ready receipt')
      call publish_ppa_wu04c_accepted_progress(progress(tile),attempt_receipts(tile)%receipt,interception(tile),code)
      call require(code/=PPA_WU04C_PUBLICATION_OK,'failed hydraulic receipt cannot publish progress')
      call progress(tile)%export_restart(progress_record,ok)
      call require(ok.and.progress_record%accepted_through_time==T0.and. &
           progress_record%accepted_interception_cm==0.0_real64.and. &
           progress_record%expected_origin_revision==0_int64,'failed trial leaves all source progress unchanged')
      write(*,'(a,i0,a,i0,a,i0,a,i0)') 'PPA_FREE_DRAINAGE_OWNER_FAILED_ATTEMPT tile=',tile, &
           ' headcalc=',attempt_results(tile)%solver_headcalc_calls, &
           ' nonlinear=',attempt_results(tile)%solver_nonlinear_iterations, &
           ' accepted_internal=',attempt_results(tile)%accepted_substeps
    end do
    call retry_owner%export_committed_restart(9910_int64,after,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'failed owner remains exportable')
    call compare_restart_bundles(before,after,'failed attempt unchanged')
    call retry_owner%close(code)
    call require(code==FMR_APP_BOOT_OK,'failed owner closes')
    ! Reconfigure execution retry policy, restoring exactly the unchanged physical
    ! boundary. No physical initialisation from a rejected candidate is permitted.
    call retry_owner%initialize(profile,code)
    call require(code==FMR_APP_BOOT_OK,'retry-enabled owner initialized')
    call retry_owner%restore_committed_restart(after,9910_int64,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'retry restores unchanged accepted boundary')
    call retry_owner%run_standalone_with_forcing_receipts(T0,T1,forcing,attempt_results,attempt_receipts,code)
    call require(code==FMR_APP_BOOT_OK.and.all(attempt_results%committed),'replayed interval commits')
    call require(maxval(abs(attempt_results%mass%residual))<=HARD_MASS_GATE,'replay hard mass')
    do tile=1,NTILE
      call publish_ppa_wu04c_accepted_progress(progress(tile),attempt_receipts(tile)%receipt,interception(tile),code)
      call require(code==PPA_WU04C_PUBLICATION_OK.and.progress(tile)%remaining_interception()==0.0_real64, &
           'only accepted replay consumes source aggregate')
    end do
    call retry_owner%export_committed_restart(9901_int64,replayed,ok,code)
    call require(ok.and.code==FMR_APP_BOOT_OK,'replayed boundary exported')
    call compare_restart_bundles(expected,replayed,'retry and uninterrupted result identical')
    call retry_owner%close(code)
    call require(code==FMR_APP_BOOT_OK,'replayed owner closes')
    if(partial_progress) then
      write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_PARTIAL_REPLAY_NO_PUBLICATION=PASS'
    else
      write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_FAILED_REPLAY_NO_PUBLICATION=PASS'
    end if
  end subroutine

  subroutine verify_changing_windows(owner,profile)
    type(fmr_production_application_bootstrap_t),intent(inout)::owner
    type(fmr_production_application_config_t),intent(in)::profile
    type(fmr_production_application_bootstrap_t)::fresh
    type(fmr_committed_restart_bundle_t)::before,unchanged,continued,resumed
    type(fmr_committed_top_state_t),allocatable::top(:),restored_top(:)
    type(fmr_b110_physical_forcing_t)::forcing(NTILE),restored_forcing(NTILE)
    type(fmr_serialized_column_result_t),allocatable::result(:),restored_result(:)
    type(fmr_serialized_commit_receipt_record_t),allocatable::receipt(:),restored_receipt(:)
    type(fmr_vonhhbraden_source_window_progress_t)::progress,restored_progress
    type(vonhhbraden_source_window_t)::source
    type(vonhhbraden_parameters_t)::parameters
    type(vonhhbraden_result_t)::source_result
    real(real64)::start_time,end_time,amount(NTILE),restored_amount(NTILE),previous_flux
    integer::window,tile,code,window_count
    logical::ok,marked_window
    parameters%cofab_cm=0.5_real64
    source%leaf_area_index=2.0_real64
    source%vegetation_cover_fraction=0.5_real64
    previous_flux=0.0_real64
    window_count=3
    if(trim(test_scope)=='--gash-branch-rejection') window_count=4
    do window=1,window_count
      marked_window=window==2.or.((window==1.or.window==4).and.is_gash)
      start_time=T1+real(window-1,real64)*(T1-T0)
      end_time=start_time+(T1-T0)
      source%gross_rain_cm_per_day=0.20_real64-0.04_real64*real(min(window-1,1),real64)
      source%sprinkling_irrigation_cm_per_day=0.10_real64-0.02_real64*real(min(window-1,1),real64)
      if(window==4) then
        source%gross_rain_cm_per_day=0.04_real64
        source%sprinkling_irrigation_cm_per_day=0.02_real64
      end if
      call evaluate_vonhhbraden_source_window(parameters,source,0.1_real64,source_result)
      if(is_gash) call evaluate_gash_source_window(WINDOW_GASH,source, &
           source_result%source_window_interception_cm_per_day,source_result%status)
      call require(source_result%status==VONHHBRADEN_AVAILABLE,'changing source evaluated')
      if(window==4) call require(abs(source_result%source_window_interception_cm_per_day-0.051_real64)< &
           1.0e-15_real64,'Gash presaturation branch independent amount oracle')
      call owner%export_committed_restart(9902_int64,before,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'window boundary export')
      call fresh%initialize(profile,code)
      call require(code==FMR_APP_BOOT_OK,'window fresh initialize')
      call fresh%restore_committed_restart(before,9902_int64,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'window boundary restore')
      call owner%copy_committed_top_states(top,code)
      call require(code==FMR_APP_BOOT_OK.and.all(top%available),'window committed top')
      call fresh%copy_committed_top_states(restored_top,code)
      call require(code==FMR_APP_BOOT_OK.and.all(restored_top%available),'window restored top')
      do tile=1,NTILE
        call require(top(tile)%committed_time==start_time.and.top(tile)%revision==int(window,int64), &
             'window uses current committed boundary')
        call build_window_forcing(profile,tile,top(tile),source,source_result,forcing(tile),amount(tile))
        call build_window_forcing(profile,tile,restored_top(tile),source,source_result, &
             restored_forcing(tile),restored_amount(tile))
        call require(forcing(tile)%top_flux==restored_forcing(tile)%top_flux.and. &
             amount(tile)==restored_amount(tile),'restored window materialization identical')
      end do
      if(window==2.or.window==4) &
           call require(forcing(1)%top_flux/=previous_flux,'effective forcing changes between windows')
      if(window==3) then
        call require(forcing(1)%top_flux==previous_flux,'post-event window retains physical forcing')
        call require(all(.not.forcing%temporal_forcing_event).and.all(.not.restored_forcing%temporal_forcing_event), &
             'newly materialized forcing does not retain event marker')
      end if
      previous_flux=forcing(1)%top_flux
      if(marked_window.and.trim(test_scope)/='--window-rejection') then
        forcing%temporal_forcing_event=.true.
        forcing%temporal_forcing_event_time=start_time
        restored_forcing=forcing
        restored_forcing%temporal_forcing_event_time=end_time
        call fresh%run_standalone_with_forcing_receipts(start_time,end_time,restored_forcing, &
             restored_result,restored_receipt,code)
        call require(code/=FMR_APP_BOOT_OK.and.all(.not.restored_result%committed),'wrong event time rejected')
        call fresh%export_committed_restart(9902_int64,resumed,ok,code)
        call require(ok.and.code==FMR_APP_BOOT_OK,'wrong-time rejection exportable')
        call compare_restart_bundles(before,resumed,'wrong event time does not mutate owner')
        restored_forcing%temporal_forcing_event_time=ieee_value(0.0_real64,ieee_quiet_nan)
        call fresh%run_standalone_with_forcing_receipts(start_time,end_time,restored_forcing, &
             restored_result,restored_receipt,code)
        call require(code/=FMR_APP_BOOT_OK.and.all(.not.restored_result%committed),'nonfinite event time rejected')
        call fresh%export_committed_restart(9902_int64,resumed,ok,code)
        call require(ok.and.code==FMR_APP_BOOT_OK,'nonfinite event rejection exportable')
        call compare_restart_bundles(before,resumed,'nonfinite event time does not mutate owner')
        restored_forcing%temporal_forcing_event_time=start_time
      end if
      call owner%export_committed_restart(9902_int64,unchanged,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'materialization leaves owner exportable')
      call compare_restart_bundles(before,unchanged,'read-only window materialization')
      if(window==2.and.trim(test_scope)=='--window-rejection') then
        select type(state=>before%records(1)%physical_state)
        type is(fmr_b110_temporal_indicator_state_t)
          call diagnose_window_jump(profile%tiles(1)%parameters,state,forcing(1))
        class default
          call require(.false.,'window diagnostic requires temporal state')
        end select
      end if
      observed_event_calls=0
      capture_low_rain=window==4.and.trim(test_scope)=='--gash-branch-rejection'
      call owner%run_standalone_with_forcing_receipts(start_time,end_time,forcing,result,receipt,code)
      capture_low_rain=.false.
      write(*,*) 'CHANGING_WINDOW_DIAG',window,code,result%kernel_status,result%accepted_substeps
      if((window==2.and.trim(test_scope)=='--window-rejection').or. &
           (window==4.and.trim(test_scope)=='--gash-branch-rejection')) then
        call require(code/=FMR_APP_BOOT_OK.and.all(.not.result%committed),'forcing jump reproduces rejection')
        if(window==2) call require(all(result%accepted_substeps==0),'unmarked jump no internal accepts')
        if(window==4) call require(all(result%accepted_substeps==7),'Gash branch failure after seven internal accepts')
        if(window==4) call diagnose_low_rain_boundary(profile%tiles(NTILE)%parameters,forcing(NTILE))
        call owner%export_committed_restart(9902_int64,continued,ok,code)
        call require(ok.and.code==FMR_APP_BOOT_OK,'rejected window remains exportable')
        call compare_restart_bundles(before,continued,'forcing jump rollback')
        call fresh%run_standalone_with_forcing_receipts(start_time,end_time,restored_forcing, &
             restored_result,restored_receipt,code)
        call require(code/=FMR_APP_BOOT_OK.and.all(.not.restored_result%committed).and. &
             all(restored_result%kernel_status==result%kernel_status).and. &
             all(restored_result%solver_headcalc_calls==result%solver_headcalc_calls), &
             'restored forcing jump reproduces rejection')
        call fresh%export_committed_restart(9902_int64,resumed,ok,code)
        call require(ok.and.code==FMR_APP_BOOT_OK,'restored rejected window exportable')
        call compare_restart_bundles(before,resumed,'restored forcing jump rollback')
        do tile=1,NTILE
          call fmr_initialize_vonhhbraden_source_window_progress(int(9800+10*window+tile,int64), &
               start_time,end_time,amount(tile),progress,code,profile%tiles(tile)%tile_id,top(tile)%revision)
          call require(code==FMR_VONHHBRADEN_PROGRESS_OK,'rejected source progress initialized')
          call publish_ppa_wu04c_accepted_progress(progress,receipt(tile)%receipt,amount(tile),code)
          call require(code/=PPA_WU04C_PUBLICATION_OK,'failed jump receipt cannot publish')
          call publish_ppa_wu04c_accepted_progress(progress,restored_receipt(tile)%receipt,amount(tile),code)
          call require(code/=PPA_WU04C_PUBLICATION_OK.and.progress%remaining_interception()==amount(tile), &
               'both rejected runs leave source amount untouched')
        end do
        call fresh%close(code)
        call require(code==FMR_APP_BOOT_OK,'rejected window fresh closes')
        if(window==2) write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_WINDOW_REJECTION=PASS'
        if(window==4) write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_GASH_BRANCH_REJECTION=PASS'
        if(window==4) call probe_low_rain_retry(profile,before,forcing,start_time,end_time,amount)
        return
      end if
      call require(code==FMR_APP_BOOT_OK.and.all(result%committed),'changing window commits')
      if(marked_window) then
        call require(observed_event_calls>0.and.observed_event_calls<=NTILE*(profile%numerical%transaction%max_retries+1), &
             'event certificate bounded to initial trial retries')
        call require(sum(result%accepted_substeps)>observed_event_calls,'later accepted substeps use normal history')
      else
        call require(observed_event_calls==0,'unmarked window never uses event derivative')
      end if
      observed_event_calls=0
      call fresh%run_standalone_with_forcing_receipts(start_time,end_time,restored_forcing, &
           restored_result,restored_receipt,code)
      call require(code==FMR_APP_BOOT_OK.and.all(restored_result%committed),'restored changing window commits')
      if(.not.marked_window) call require(observed_event_calls==0,'restored unmarked window never uses event derivative')
      call require(maxval(abs(result%mass%residual))<=HARD_MASS_GATE.and. &
           maxval(abs(restored_result%mass%residual))<=HARD_MASS_GATE,'changing window hard mass')
      do tile=1,NTILE
        call fmr_initialize_vonhhbraden_source_window_progress(int(9800+10*window+tile,int64), &
             start_time,end_time,amount(tile),progress,code,profile%tiles(tile)%tile_id,top(tile)%revision)
        call require(code==FMR_VONHHBRADEN_PROGRESS_OK,'distinct window progress initialized')
        restored_progress=progress
        call publish_ppa_wu04c_accepted_progress(progress,receipt(tile)%receipt,amount(tile),code)
        call require(code==PPA_WU04C_PUBLICATION_OK,'changing window source publication')
        call publish_ppa_wu04c_accepted_progress(restored_progress,restored_receipt(tile)%receipt, &
             restored_amount(tile),code)
        call require(code==PPA_WU04C_PUBLICATION_OK,'restored changing window publication')
        call require(progress%remaining_interception()==0.0_real64.and. &
             restored_progress%remaining_interception()==0.0_real64,'distinct source amount exhausted')
      end do
      call owner%export_committed_restart(9902_int64,continued,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'window continued export')
      call fresh%export_committed_restart(9902_int64,resumed,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'window resumed export')
      call compare_restart_bundles(continued,resumed,'changing window restart equivalence')
      if(window==2.and.trim(test_scope)/='--window-rejection') &
           call verify_event_rollback(profile,before,continued,forcing,amount,start_time,end_time)
      call fresh%close(code)
      call require(code==FMR_APP_BOOT_OK,'window fresh closes')
    end do
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_CHANGING_WINDOWS=PASS'
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_EVENT_THEN_UNMARKED=PASS'
    if(is_gash) write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_GASH_WINDOWS=PASS'
  end subroutine

  subroutine verify_event_rollback(profile,before,expected,forcing,amount,t_start,t_end)
    type(fmr_production_application_config_t),intent(in)::profile
    type(fmr_committed_restart_bundle_t),intent(in)::before,expected
    type(fmr_b110_physical_forcing_t),intent(in)::forcing(:)
    real(real64),intent(in)::amount(:),t_start,t_end
    type(fmr_production_application_config_t)::limited
    type(fmr_production_application_bootstrap_t)::owner
    type(fmr_committed_restart_bundle_t)::after,replayed
    type(fmr_serialized_column_result_t),allocatable::result(:)
    type(fmr_serialized_commit_receipt_record_t),allocatable::receipt(:)
    type(fmr_vonhhbraden_source_window_progress_t)::progress(NTILE)
    integer::variant,code,tile
    logical::ok
    do variant=0,2
      limited=profile
      if(variant==0) nullify(limited%free_drainage_indicator)
      if(variant==1) limited%numerical%transaction%max_retries=0
      if(variant==2) limited%numerical%max_committed_substeps=1
      call owner%initialize(limited,code)
      call require(code==FMR_APP_BOOT_OK,'event failure owner initialize')
      call owner%restore_committed_restart(before,9902_int64,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'event failure initial boundary restored')
      do tile=1,NTILE
        call fmr_initialize_vonhhbraden_source_window_progress(int(9990+tile,int64),t_start,t_end, &
             amount(tile),progress(tile),code,profile%tiles(tile)%tile_id,before%records(tile)%revision)
        call require(code==FMR_VONHHBRADEN_PROGRESS_OK,'event failure source initialized')
      end do
      call owner%run_standalone_with_forcing_receipts(t_start,t_end,forcing,result,receipt,code)
      call require(code/=FMR_APP_BOOT_OK.and.all(.not.result%committed),'bounded event attempt rejects')
      if(variant==0) call require(all(result%solver_headcalc_calls==0),'unbound event service rejects before solve')
      if(variant==1) call require(all(result%solver_headcalc_calls>0).and. &
           all(result%accepted_substeps==0),'event real failed attempt without accepts')
      if(variant==2) call require(all(result%accepted_substeps==1),'event failure after internal acceptance')
      do tile=1,NTILE
        call publish_ppa_wu04c_accepted_progress(progress(tile),receipt(tile)%receipt,amount(tile),code)
        call require(code/=PPA_WU04C_PUBLICATION_OK.and.progress(tile)%remaining_interception()==amount(tile), &
             'failed event cannot advance source progress')
      end do
      call owner%export_committed_restart(9902_int64,after,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'event failure remains exportable')
      call compare_restart_bundles(before,after,'event rollback preserves physical history provenance')
      call owner%close(code)
      call require(code==FMR_APP_BOOT_OK,'event limited owner closes')
      call owner%initialize(profile,code)
      call require(code==FMR_APP_BOOT_OK,'event replay owner initialize')
      call owner%restore_committed_restart(after,9902_int64,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'event replay restores accepted boundary')
      call owner%run_standalone_with_forcing_receipts(t_start,t_end,forcing,result,receipt,code)
      call require(code==FMR_APP_BOOT_OK.and.all(result%committed),'event replay commits')
      call require(maxval(abs(result%mass%residual))<=HARD_MASS_GATE,'event replay hard mass')
      do tile=1,NTILE
        call publish_ppa_wu04c_accepted_progress(progress(tile),receipt(tile)%receipt,amount(tile),code)
        call require(code==PPA_WU04C_PUBLICATION_OK.and.progress(tile)%remaining_interception()==0.0_real64, &
             'accepted event replay consumes source once')
      end do
      call owner%export_committed_restart(9902_int64,replayed,ok,code)
      call require(ok.and.code==FMR_APP_BOOT_OK,'event replay export')
      call compare_restart_bundles(expected,replayed,'event retry equals uninterrupted execution')
      call owner%close(code)
      call require(code==FMR_APP_BOOT_OK,'event replay owner closes')
    end do
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_EVENT_ROLLBACK_REPLAY=PASS'
  end subroutine

  subroutine diagnose_window_jump(p,state,forcing)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_temporal_indicator_state_t),intent(in)::state
    type(fmr_b110_physical_forcing_t),target,intent(in)::forcing
    type(soil_water_parameter_set_t),target::geometry
    type(b110_default_mvg_parameters_t),target::hydraulics
    type(b110_default_mvg_provider_t),target::provider
    type(b110_source_sink_provider_t),target::sink
    type(fixed_flux_top_boundary_provider_t),target::top_provider
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::workspace
    type(soil_water_solve_request_t)::request,invalid
    type(soil_water_solve_result_t)::result
    type(soil_water_temporal_indicator_request_t)::old_history,event_history
    type(soil_water_temporal_indicator_result_t)::old_bound,event_bound
    real(real64),allocatable::history(:),event_derivative(:),heads_before(:),water_before(:),computed(:)
    real(real64)::dt,ledger
    integer::exponent,converged,rejected,event_eligible
    logical::ok
    geometry%parameter_set_id=p%parameter_set_id
    geometry%active_nodes=p%active_nodes
    geometry%z=p%z; geometry%dz=p%dz; geometry%node_distance=p%node_distance
    call initialize_b110_default_mvg_parameters(hydraulics,p%cofgen)
    call bind_b110_source_sink_provider(sink,forcing%drainage_flux_by_level, &
         forcing%subsurface_irrigation_source,forcing%root_extraction_sink)
    call state%temporal_history_snapshot(history,ok)
    call require(ok,'jump diagnostic committed history')
    allocate(event_derivative(p%active_nodes))
    call seed_initial_derivative(p,state%fmr_b110_physical_state_t,forcing,event_derivative)
    old_history%previous_right_derivative_available=.true.
    old_history%previous_right_derivative=history
    event_history%previous_right_derivative_available=.true.
    event_history%previous_right_derivative=event_derivative
    heads_before=state%pressure_head; water_before=state%water_content
    request%parameters=>geometry
    request%base_state%active_nodes=p%active_nodes
    request%base_state%pressure_head=state%pressure_head
    request%base_state%water_content=state%water_content
    request%base_state%ponding_depth=state%ponding_depth
    request%base_state%groundwater_level=state%groundwater_level
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=7
    request%boundary%top_flux=forcing%top_flux
    request%boundary%top_head=forcing%top_head
    request%boundary%bottom_flux=forcing%bottom_flux
    request%boundary%bottom_head=forcing%bottom_head
    request%numerical%max_iterations=p%max_iterations
    request%numerical%max_backtracking=p%max_backtracking
    request%numerical%conductivity_implicit_mode=p%swkimpl
    request%numerical%conductivity_mean_method=p%swkmean
    request%numerical%min_step_duration=p%min_step_duration
    request%numerical%compartment_balance_tolerance=p%compartment_balance_tolerance
    request%numerical%total_balance_tolerance=p%total_balance_tolerance
    request%numerical%head_abs_tolerance=p%head_abs_tolerance
    request%numerical%head_rel_tolerance=p%head_rel_tolerance
    request%numerical%ponding_tolerance=p%ponding_tolerance
    request%evaluation%constitutive=>provider
    request%evaluation%source_sink=>sink
    request%evaluation%top_boundary=>top_provider
    request%evaluation%storage_difference=>evaluate_mvg_storage_difference_service
    allocate(computed(p%active_nodes))
    call bind_b110_default_mvg_provider(provider,hydraulics,T1-T0)
    call evaluate_forcing_event_derivative(request,computed,ok)
    call require(ok.and.maxval(abs(computed-event_derivative))<= &
         1.0e-12_real64*max(1.0_real64,maxval(abs(event_derivative))),'guarded event derivative matches oracle')
    do exponent=1,8
      invalid=request
      select case(exponent)
      case(1)
        invalid%boundary%bottom_mode=2
      case(2)
        invalid%numerical%conductivity_mean_method=2
      case(3)
        invalid%numerical%conductivity_implicit_mode=1
      case(4)
        nullify(invalid%evaluation%constitutive)
      case(5)
        invalid%base_state%water_content(1)=nearest(invalid%base_state%water_content(1),1.0_real64)
      case(6)
        invalid%boundary%top_flux=ieee_value(0.0_real64,ieee_quiet_nan)
      case(7)
        invalid%base_state%active_nodes=0
      case(8)
        nullify(invalid%evaluation%source_sink)
      end select
      computed=12345.0_real64
      call evaluate_forcing_event_derivative(invalid,computed,ok)
      call require(.not.ok.and.all(computed==0.0_real64),'event derivative rejection is atomic')
    end do
    geometry%dz(1)=0.0_real64
    call evaluate_forcing_event_derivative(request,computed,ok)
    call require(.not.ok.and.all(computed==0.0_real64),'event derivative rejects zero geometry')
    geometry%dz=p%dz
    hydraulics%ksatexm_extension_enabled=.true.
    call evaluate_forcing_event_derivative(request,computed,ok)
    call require(.not.ok.and.all(computed==0.0_real64),'event derivative rejects extension')
    hydraulics%ksatexm_extension_enabled=.false.
    provider%step_duration=0.0_real64
    call evaluate_forcing_event_derivative(request,computed,ok)
    call require(.not.ok.and.all(computed==0.0_real64),'event derivative rejects zero provider duration')
    provider%step_duration=ieee_value(0.0_real64,ieee_quiet_nan)
    call evaluate_forcing_event_derivative(request,computed,ok)
    call require(.not.ok.and.all(computed==0.0_real64),'event derivative rejects nonfinite provider duration')
    call bind_b110_default_mvg_provider(provider,hydraulics,T1-T0)
    call evaluate_forcing_event_derivative(request,computed(1:1),ok)
    call require(.not.ok,'event derivative rejects output shape')
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_EVENT_DERIVATIVE=PASS'
    converged=0; rejected=0; event_eligible=0
    do exponent=13,23
      dt=0.5_real64/2.0_real64**exponent
      request%step_duration=dt
      call bind_b110_default_mvg_provider(provider,hydraulics,dt)
      call solver%solve(request,workspace,result)
      write(*,'(a,i0,a,i0,a,es23.15,a,l1,a,l1)') 'JUMP_SOLVE exponent=',exponent,':status=',result%status, &
           ':residual=',maxval(abs(workspace%richards%residual)), &
           ':balance=',any(workspace%richards%nonconverged_balance),':head=',any(workspace%richards%nonconverged_head)
      if(result%status==SW_SOLVE_CONVERGED) then
        converged=converged+1
        ledger=sum((result%candidate_state%water_content-state%water_content)*p%dz)+ &
             dt*(result%top_flux-result%bottom_flux+sum(forcing%drainage_flux_by_level)+ &
             sum(forcing%root_extraction_sink)-sum(forcing%subsurface_irrigation_source))
        call require(abs(ledger)<=HARD_MASS_GATE,'jump diagnostic independent mass')
        call evaluate_free_drainage_temporal_indicator(request,result,old_history,old_bound)
        call evaluate_free_drainage_temporal_indicator(request,result,event_history,event_bound)
        call require(old_bound%available.and.event_bound%available,'jump diagnostic certificates available')
        write(*,'(a,i0,2(a,es23.15))') 'JUMP_HISTORY exponent=',exponent, &
             ':committed_bound=',old_bound%head_inf_bound,':event_bound=',event_bound%head_inf_bound
        if(old_bound%head_inf_bound>1.0e-5_real64.and.event_bound%head_inf_bound<=1.0e-5_real64) &
             event_eligible=event_eligible+1
      else
        rejected=rejected+1
      end if
    end do
    call require(converged>0.and.rejected>0,'jump diagnostic both solver outcomes')
    call require(event_eligible>0,'event derivative enables bounded certificate without changing solve')
    call state%temporal_history_snapshot(event_derivative,ok)
    call require(ok.and.all(event_derivative==history).and.all(state%pressure_head==heads_before).and. &
         all(state%water_content==water_before),'jump diagnostic leaves authoritative state unchanged')
    write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_JUMP_DIAGNOSIS=PASS'
  end subroutine

  subroutine build_window_forcing(profile,tile,top,source,source_result,forcing,amount_cm)
    type(fmr_production_application_config_t),intent(in)::profile
    integer,intent(in)::tile
    type(fmr_committed_top_state_t),intent(in)::top
    type(vonhhbraden_source_window_t),intent(in)::source
    type(vonhhbraden_result_t),intent(in)::source_result
    type(fmr_b110_physical_forcing_t),intent(out)::forcing
    real(real64),intent(out)::amount_cm
    type(soil_water_parameter_set_t)::geometry
    type(b110_default_mvg_parameters_t)::hydraulics
    type(b110_dynamic_top_boundary_request_t)::request
    type(ppa_wu04c_production_forcing_diagnostics_t)::diagnostics
    type(ppa_wu04d_production_forcing_diagnostics_t)::gash_diagnostics
    real(real64)::rate
    geometry%parameter_set_id=profile%tiles(tile)%parameters%parameter_set_id
    geometry%active_nodes=profile%tiles(tile)%parameters%active_nodes
    geometry%z=profile%tiles(tile)%parameters%z
    geometry%dz=profile%tiles(tile)%parameters%dz
    geometry%node_distance=profile%tiles(tile)%parameters%node_distance
    call initialize_b110_default_mvg_parameters(hydraulics,profile%tiles(tile)%parameters%cofgen)
    request%conductivity_mean_method=profile%tiles(tile)%parameters%swkmean
    request%pressure_head_top_cm=top%pressure_head_top_cm
    request%water_content_top=top%water_content_top
    request%candidate_ponding_depth_cm=top%ponding_depth_cm
    request%previous_ponding_depth_cm=top%ponding_depth_cm
    request%step_duration_day=T1-T0
    request%ponding_max_cm=2.0_real64
    request%runoff_resistance_day=1.0_real64
    request%runoff_exponent=1.0_real64
    if(is_gash) then
      call materialize_ppa_wu04d_production_forcing(profile%tiles(tile)%base_forcing,request,geometry,hydraulics, &
           WINDOW_GASH,source,source%gross_rain_cm_per_day,source%sprinkling_irrigation_cm_per_day,forcing,rate,gash_diagnostics)
      call require(gash_diagnostics%status==PPA_WU04D_PRODUCTION_FORCING_OK,'Gash committed-top forcing composition')
    else
      call materialize_ppa_wu04c_production_forcing(profile%tiles(tile)%base_forcing,request,geometry,hydraulics, &
         source,source_result%source_window_interception_cm_per_day,source%gross_rain_cm_per_day, &
         source%sprinkling_irrigation_cm_per_day,forcing,rate,diagnostics)
      call require(diagnostics%status==PPA_WU04C_PRODUCTION_FORCING_OK,'committed-top forcing composition')
    end if
    amount_cm=rate*(T1-T0)
    call require(abs(amount_cm-source_result%source_window_interception_cm_per_day*(T1-T0))<1.0e-15_real64, &
         'whole source interval amount cm')
  end subroutine

  subroutine compare_restart_bundles(a,b,label)
    type(fmr_committed_restart_bundle_t),intent(in)::a,b
    character(len=*),intent(in)::label
    real(real64),allocatable::ha(:),hb(:)
    logical::ok
    integer::tile
    call require(size(a%records)==size(b%records),label//' record count')
    do tile=1,size(a%records)
      call require(a%records(tile)%revision==b%records(tile)%revision.and. &
           a%records(tile)%lineage_id==b%records(tile)%lineage_id.and. &
           a%records(tile)%committed_time==b%records(tile)%committed_time.and. &
           (a%records(tile)%time_bound.eqv.b%records(tile)%time_bound),label//' provenance')
      select type(sa=>a%records(tile)%physical_state)
      type is(fmr_b110_temporal_indicator_state_t)
        select type(sb=>b%records(tile)%physical_state)
        type is(fmr_b110_temporal_indicator_state_t)
          call require(all(sa%pressure_head==sb%pressure_head).and.all(sa%water_content==sb%water_content).and. &
               sa%ponding_depth==sb%ponding_depth.and.sa%groundwater_level==sb%groundwater_level,label//' physical')
          call sa%temporal_history_snapshot(ha,ok)
          call require(ok,label//' history A')
          call sb%temporal_history_snapshot(hb,ok)
          call require(ok.and.all(ha==hb),label//' history identical')
        class default
          call require(.false.,label//' state B type')
        end select
      class default
        call require(.false.,label//' state A type')
      end select
    end do
  end subroutine

  subroutine seed_initial_derivative(p,state,forcing,derivative)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    real(real64), intent(out) :: derivative(:)
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: water(p%active_nodes), k(p%active_nodes), c(p%active_nodes), dk(p%active_nodes)
    real(real64) :: flux(p%active_nodes+1)
    integer :: j,n
    n=p%active_nodes
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,T1-T0)
    call provider%evaluate(state%pressure_head,water,k,c,dk)
    flux(1)=forcing%top_flux
    do j=2,n
      flux(j)=-0.5_real64*(k(j-1)+k(j))* &
           ((state%pressure_head(j-1)-state%pressure_head(j))/p%node_distance(j)+1.0_real64)
    end do
    flux(n+1)=-k(n)
    do j=1,n
      derivative(j)=(flux(j+1)-flux(j)+forcing%subsurface_irrigation_source(j) &
           -sum(forcing%drainage_flux_by_level(:,j))-forcing%root_extraction_sink(j))/(c(j)*p%dz(j))
    end do
  end subroutine

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU01_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_free_drainage_owner

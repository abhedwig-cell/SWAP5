module mod_fwof40_restart_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_wofost_crop_owner_state
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, wofost_one_day_update_parameters_t
  use mod_wofost_rate_table
  use mod_wofost_rate_parameters
  use mod_fmr_wofost_accepted_window_lineage
  use mod_fmr_wofost_crop_transaction
  use mod_fmr_wofost_crop_event_lifecycle
  use mod_fwof34_test_model
  implicit none
  private

  public :: fwof40_require
  public :: fwof40_setup_physical_source
  public :: fwof40_build_accepted_event
  public :: fwof40_setup_crop_inputs
  public :: fwof40_initialize_crop_committed
  public :: fwof40_prepare_crop_forcing
  public :: fwof40_commit_crop_event
  public :: fwof40_retire_window

contains

  subroutine fwof40_require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine fwof40_require

  subroutine fwof40_setup_physical_source(committed, kernel, model, parameters, forcing, config, lineage, t0)
    type(kernel_committed_state_t), intent(out) :: committed
    type(kernel_executor_t), intent(out) :: kernel
    type(fwof34_model_t), target, intent(inout) :: model
    type(fwof34_parameters_t), intent(out) :: parameters
    type(fwof34_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: t0
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fwof34_state_t :: physical)
    select type (typed => physical)
    type is (fwof34_state_t)
      typed%water = 1.0_real64
    class default
      error stop 'F-WOF40 physical fixture allocation failure'
    end select
    call committed%initialize(lineage, physical, initialized, t0)
    call fwof40_require(initialized, 'physical committed initialization')

    parameters%flux_rate = 0.1_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
    call kernel%bind_model(model)
  end subroutine fwof40_setup_physical_source

  subroutine fwof40_build_accepted_event(kernel, committed, parameters, forcing, config, t0, t1, &
       actual_integral, potential_integral, window)
    type(kernel_executor_t), intent(inout) :: kernel
    type(kernel_committed_state_t), intent(inout) :: committed
    type(fwof34_parameters_t), intent(in) :: parameters
    type(fwof34_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: config
    real(real64), intent(in) :: t0, t1, actual_integral, potential_integral
    type(fmr_wofost_accepted_window_t), intent(out) :: window
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_wofost_trial_contribution_t) :: trial
    type(fmr_wofost_accepted_interval_certificate_t) :: certificate
    logical :: ok, did_commit
    integer :: status, commit_status
    real(real64) :: dt

    dt = t1 - t0
    call fwof40_require(dt > 0.0_real64, 'physical event positive dt')
    call committed%capture_checkpoint(checkpoint, ok)
    call fwof40_require(ok, 'physical checkpoint capture')
    call open_wofost_accepted_window(checkpoint, t1, window, status)
    call fwof40_require(status == FMR_WOFOST_LINEAGE_OK .and. window%ready(), 'accepted window open')
    call begin_wofost_trial_contribution(checkpoint, t1, trial, status)
    call fwof40_require(status == FMR_WOFOST_LINEAGE_OK, 'accepted trial begin')
    call accumulate_wofost_trial_process_rate(trial, t0, t1, actual_integral/dt, potential_integral/dt, status)
    call fwof40_require(status == FMR_WOFOST_LINEAGE_OK .and. trial%complete(), 'accepted trial accumulate')

    call kernel%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate, diagnostics, checkpoint)
    call fwof40_require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'physical interval completes')
    call fwof40_require(candidate%ready(), 'physical candidate ready')
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit, commit_status)
    call fwof40_require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'physical commit')

    call certify_fkt_accepted_interval(checkpoint, committed, certificate, status)
    call fwof40_require(status == FMR_WOFOST_LINEAGE_OK .and. certificate%ready(), 'accepted certificate')
    call admit_wofost_accepted_trial(window, certificate, trial, status)
    call fwof40_require(status == FMR_WOFOST_LINEAGE_OK .and. window%complete(), 'accepted trial admission')
  end subroutine fwof40_build_accepted_event

  subroutine fwof40_setup_crop_inputs(seed, parameters, config, daily_forcing)
    type(wofost_crop_owner_state_t), intent(out) :: seed
    type(fmr_wofost_crop_transaction_parameters_t), intent(out) :: parameters
    type(canonical_numerical_config_t), intent(out) :: config
    type(wofost_one_day_forcing_t), intent(out) :: daily_forcing
    type(wofost_rate_parameter_bundle_t) :: bundle
    type(wofost_one_day_update_parameters_t) :: update_parameters
    integer :: status

    call seed_active_owner(seed)
    call configure_daily_forcing(daily_forcing)
    call make_bundle(bundle)
    update_parameters%development_stage_end = 2.0_real64
    update_parameters%leaf_lifespan = 10.0_real64
    call construct_fmr_wofost_crop_transaction_parameters(bundle, update_parameters, 0.005_real64, 0.002_real64, &
         parameters, status)
    call fwof40_require(status == FMR_WOF38_OK .and. parameters%ready(), 'crop parameters ready')

    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 0.0_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 0
    config%max_committed_substeps = 1
    config%progress_tolerance = 0.0_real64
  end subroutine fwof40_setup_crop_inputs

  subroutine fwof40_initialize_crop_committed(seed, committed, lineage, t0)
    type(wofost_crop_owner_state_t), intent(in) :: seed
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: t0
    type(fmr_wofost_crop_transaction_state_t) :: initial_state
    class(transaction_state_t), allocatable :: physical
    logical :: initialized
    integer :: status

    call initialize_fmr_wofost_crop_transaction_state(seed, initial_state, status)
    call fwof40_require(status == FMR_WOF38_OK .and. initial_state%ready(), 'crop transaction initial state')
    allocate(fmr_wofost_crop_transaction_state_t :: physical)
    select type (typed => physical)
    type is (fmr_wofost_crop_transaction_state_t)
      typed = initial_state
    class default
      error stop 'F-WOF40 crop fixture allocation failure'
    end select
    call committed%initialize(lineage, physical, initialized, t0)
    call fwof40_require(initialized, 'crop committed initialization')
  end subroutine fwof40_initialize_crop_committed

  subroutine fwof40_prepare_crop_forcing(window, daily_forcing, forcing)
    type(fmr_wofost_accepted_window_t), intent(in) :: window
    type(wofost_one_day_forcing_t), intent(in) :: daily_forcing
    type(fmr_wofost_crop_event_forcing_t), intent(out) :: forcing
    integer :: status
    call prepare_fmr_wofost_crop_event_forcing(window, daily_forcing, forcing, status)
    call fwof40_require(status == FMR_WOF38_OK .and. forcing%ready(), 'crop event forcing ready')
  end subroutine fwof40_prepare_crop_forcing

  subroutine fwof40_commit_crop_event(kernel, model, parameters, config, committed, window, daily_forcing, t0, t1)
    type(kernel_executor_t), intent(inout) :: kernel
    type(fmr_wofost_crop_transaction_model_t), target, intent(inout) :: model
    type(fmr_wofost_crop_transaction_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: config
    type(kernel_committed_state_t), intent(inout) :: committed
    type(fmr_wofost_accepted_window_t), intent(in) :: window
    type(wofost_one_day_forcing_t), intent(in) :: daily_forcing
    real(real64), intent(in) :: t0, t1
    type(fmr_wofost_crop_event_forcing_t) :: event_forcing
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok, did_commit
    integer :: commit_status

    call kernel%bind_model(model)
    call fwof40_prepare_crop_forcing(window, daily_forcing, event_forcing)
    call committed%capture_checkpoint(checkpoint, ok)
    call fwof40_require(ok, 'crop checkpoint capture')
    call kernel%advance_interval(parameters, committed, event_forcing, config, t0, t1, result, candidate, diagnostics, checkpoint)
    call fwof40_require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'crop event completes')
    call fwof40_require(candidate%ready(), 'crop event candidate ready')
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit, commit_status)
    call fwof40_require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'crop event commit')
  end subroutine fwof40_commit_crop_event

  subroutine fwof40_retire_window(window, committed)
    type(fmr_wofost_accepted_window_t), intent(inout) :: window
    type(kernel_committed_state_t), intent(in) :: committed
    logical :: retired
    integer :: status

    call reconcile_committed_crop_event_receipt(window, committed, retired, status)
    call fwof40_require(status == FMR_WOF39_OK .and. retired, 'accepted window lifecycle retirement')
    call fwof40_require(window%delivery_committed(), 'retired delivery committed')
    call fwof40_require(.not. window%event_due(), 'retired event not due')
  end subroutine fwof40_retire_window

  subroutine seed_active_owner(state)
    type(wofost_crop_owner_state_t), intent(out) :: state
    state%crop_emerged = .true.
    state%development_stage = 0.5_real64
    allocate(state%biomass)
    state%biomass%root_biomass = 1000.0_real64
    state%biomass%stem_biomass = 800.0_real64
    state%biomass%storage_biomass = 100.0_real64
    state%biomass%exponential_leaf_area_index = 4.0_real64
    state%biomass%leaf_biomass = [100.0_real64, 80.0_real64]
    state%biomass%specific_leaf_area = [0.02_real64, 0.03_real64]
    state%biomass%leaf_age = [0.0_real64, 1.0_real64]
    allocate(wofost_common_evolution_continuation_t :: state%evolution_continuation)
    state%evolution_continuation%temperature_sum = 100.0_real64
    state%evolution_continuation%anthesis_reached = .false.
    state%evolution_continuation%minimum_temperature_history_count = 2
    state%evolution_continuation%minimum_temperature_history = &
         [-1.0_real64, 1.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]
    call fwof40_require(state%validate() == WOFOST_CROP_OWNER_OK, 'seed owner valid')
  end subroutine seed_active_owner

  subroutine configure_daily_forcing(value)
    type(wofost_one_day_forcing_t), intent(out) :: value
    value%minimum_temperature = -2.0_real64
    value%average_temperature = 20.0_real64
    value%daytime_average_temperature = 20.0_real64
    value%global_radiation = 2000000.0_real64
    value%daylength_hours = 12.0_real64
    value%photoperiodic_daylength_hours = 12.0_real64
    value%sinld = 0.4_real64
    value%cosld = 0.5_real64
    value%diffuse_perpendicular_radiation = 10.0_real64
    value%daily_sine_solar_elevation_integral = 30000.0_real64
    value%co2_efficiency_factor = 1.1_real64
    value%co2_amax_factor = 1.05_real64
  end subroutine configure_daily_forcing

  subroutine make_bundle(bundle)
    type(wofost_rate_parameter_bundle_t), intent(out) :: bundle
    type(wofost_rate_scalar_parameters_t) :: scalar
    type(wofost_rate_parameter_tables_t) :: tables
    integer :: status

    scalar = wofost_rate_scalar_parameters_t()
    scalar%development_daylength_mode = 1
    scalar%daylength_upper_hours = 16.0_real64
    scalar%daylength_lower_hours = 8.0_real64
    scalar%vegetative_temperature_sum_required = 1000.0_real64
    scalar%generative_temperature_sum_required = 800.0_real64
    scalar%diffuse_extinction_coefficient = 0.6_real64
    scalar%initial_light_use_efficiency = 0.45_real64
    scalar%co2_to_dry_matter_fraction = 0.4_real64
    scalar%attainable_yield_multiplier = 0.9_real64
    scalar%conversion_efficiency_root = 0.7_real64
    scalar%conversion_efficiency_stem = 0.65_real64
    scalar%conversion_efficiency_leaf = 0.72_real64
    scalar%conversion_efficiency_storage = 0.8_real64
    scalar%respiration_temperature_q10 = 2.0_real64
    scalar%maintenance_respiration_root = 0.01_real64
    scalar%maintenance_respiration_leaf = 0.02_real64
    scalar%maintenance_respiration_stem = 0.015_real64
    scalar%maintenance_respiration_storage = 0.005_real64
    scalar%maximum_leaf_relative_death_rate = 0.03_real64
    scalar%leaf_age_base_temperature = 0.0_real64
    scalar%maximum_relative_lai_growth_rate = 0.04_real64

    call constant_table(10.0_real64, tables%temperature_sum_increment)
    call constant_table(30.0_real64, tables%maximum_assimilation)
    call constant_table(1.0_real64, tables%daytime_temperature_factor)
    call constant_table(1.0_real64, tables%minimum_temperature_factor)
    call constant_table(1.0_real64, tables%maintenance_respiration_factor)
    call constant_table(0.2_real64, tables%root_partition_fraction)
    call constant_table(0.4_real64, tables%leaf_partition_fraction)
    call constant_table(0.4_real64, tables%stem_partition_fraction)
    call constant_table(0.2_real64, tables%storage_partition_fraction)
    call constant_table(0.01_real64, tables%relative_root_death_rate)
    call constant_table(0.01_real64, tables%relative_stem_death_rate)
    call constant_table(0.02_real64, tables%specific_leaf_area)

    call construct_wofost_rate_parameter_bundle(scalar, tables, bundle, status)
    call fwof40_require(status == WOFOST_RATE_PARAMETER_OK .and. bundle%ready(), 'rate parameter bundle')
  end subroutine make_bundle

  subroutine constant_table(value, table)
    real(real64), intent(in) :: value
    type(wofost_rate_table_t), intent(out) :: table
    real(real64) :: x(1), y(1)
    integer :: status
    x = [0.0_real64]
    y = [value]
    call construct_wofost_rate_table(x, y, table, status)
    call fwof40_require(status == WOFOST_RATE_TABLE_OK, 'constant rate table')
  end subroutine constant_table

end module mod_fwof40_restart_fixture

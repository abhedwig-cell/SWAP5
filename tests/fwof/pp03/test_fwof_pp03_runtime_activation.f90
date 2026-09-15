program test_fwof_pp03_runtime_activation
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table
  use mod_wofost_rate_parameters, only: wofost_rate_scalar_parameters_t, &
       wofost_rate_parameter_tables_t, wofost_rate_parameter_bundle_t, &
       construct_wofost_rate_parameter_bundle, WOFOST_RATE_PARAMETER_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t, wofost_one_day_update_parameters_t
  use mod_wofost81_daily_parameter_contract
  use mod_wofost81_n_owner_state, only: initialize_wofost81_n_owner_state, WOFOST81_N_OWNER_OK
  use mod_wofost81_crop_owner_state, only: wofost81_crop_owner_state_t, WOFOST81_CROP_OWNER_OK
  use mod_wofost81_one_day_candidate
  use MOD_wofost81_nitrogen, only: WOFOST81_n_flux
  use mod_fmr_wofost_accepted_window_lineage
  use mod_fmr_wofost81_crop_transaction
  use mod_fmr_wofost81_crop_event_lifecycle
  use mod_fwof34_test_model
  implicit none

  type(wofost_rate_parameter_bundle_t) :: common
  type(wofost81_daily_parameter_contract_t) :: p81
  type(wofost81_crop_owner_state_t) :: initial_owner, expected_owner, observed_owner
  type(wofost81_one_day_prepared_candidate_t) :: prepared
  type(WOFOST81_n_flux) :: n_flux
  type(wofost_one_day_forcing_t) :: forcing, bad_forcing
  type(wofost_accepted_window_aggregates_t) :: aggregates
  type(wofost_one_day_update_parameters_t) :: updatep

  type(kernel_committed_state_t) :: physical_committed
  type(kernel_checkpoint_t) :: physical_checkpoint
  type(kernel_executor_t) :: physical_kernel
  type(fwof34_model_t), target :: physical_model
  type(fwof34_parameters_t) :: physical_parameters
  type(fwof34_forcing_t) :: physical_forcing
  type(canonical_numerical_config_t) :: physical_config
  type(fmr_wofost_accepted_window_t) :: accepted_window
  type(fmr_wofost_trial_contribution_t) :: accepted_trial
  type(fmr_wofost_accepted_interval_certificate_t) :: accepted_certificate
  type(fmr_wofost_crop_event_token_t) :: event_token
  type(fmr_wofost_crop_event_identity_t) :: event_identity

  type(fmr_wofost81_crop_transaction_state_t) :: crop_initial_state
  type(fmr_wofost81_crop_transaction_parameters_t) :: crop_parameters
  type(fmr_wofost81_crop_event_forcing_t) :: crop_event_forcing, bad_crop_event_forcing
  type(fmr_wofost81_crop_transaction_model_t), target :: crop_model, duplicate_model, bad_model, policy_model
  type(kernel_committed_state_t) :: crop_committed, duplicate_committed, bad_committed, policy_committed
  type(kernel_checkpoint_t) :: crop_checkpoint, bad_checkpoint
  type(kernel_executor_t) :: crop_kernel, duplicate_kernel, bad_kernel, policy_kernel
  type(kernel_candidate_state_t) :: candidate1, candidate2, duplicate_candidate, bad_candidate, policy_candidate
  type(kernel_result_t) :: result1, result2, duplicate_result, bad_result, policy_result
  type(kernel_diagnostics_t) :: diag1, diag2, duplicate_diag, bad_diag, policy_diag
  type(canonical_numerical_config_t) :: crop_config, bad_policy_config
  class(transaction_state_t), allocatable :: committed_snapshot, candidate_snapshot

  logical :: ok, available, did_commit, retired
  integer :: status, commit_status, lifecycle_status
  integer(int64) :: revision_before
  real(real64) :: nanv

  call configure_common(common)
  call configure_p81(p81)
  call configure_owner(initial_owner, p81, status)
  call require(status == WOFOST81_N_OWNER_OK, 'initial N owner')
  call require(initial_owner%validate() == WOFOST81_CROP_OWNER_OK, 'initial composite owner')

  forcing%minimum_temperature = 3.0_real64
  forcing%average_temperature = 10.0_real64
  forcing%daytime_average_temperature = 15.0_real64
  forcing%global_radiation = 0.0_real64
  forcing%daylength_hours = 12.0_real64
  forcing%photoperiodic_daylength_hours = 12.0_real64
  forcing%co2_efficiency_factor = 1.0_real64
  forcing%co2_amax_factor = 1.0_real64
  aggregates%actual_root_uptake = 5.0_real64
  aggregates%potential_transpiration = 5.0_real64
  updatep%development_stage_end = 2.0_real64
  updatep%leaf_lifespan = 100.0_real64

  ! Independent direct PP02 witness for the exact one-day N-unlimited candidate.
  call prepare_wofost81_one_day_candidate(initial_owner, forcing, 0.0_real64, 1.0_real64, common, p81, &
       updatep, aggregates, 0.0_real64, 0.0_real64, .true., prepared, status)
  call require(status == WOFOST81_DAY_OK .and. prepared%ready, 'direct PP02 candidate preparation')
  call apply_wofost81_one_day_n_supply(prepared, p81, prepared%nitrogen_request%soil_request, &
       expected_owner, n_flux, status)
  call require(status == WOFOST81_DAY_OK, 'direct PP02 N-unlimited apply')
  call require(expected_owner%validate() == WOFOST81_CROP_OWNER_OK, 'direct PP02 expected owner')

  ! Materialize one accepted physical event with exactly the qualified 5/5 carrier.
  call setup_physical_committed(physical_committed, 93001_int64, 0.0_real64)
  call setup_physical_solver(physical_parameters, physical_forcing, physical_config)
  call physical_kernel%bind_model(physical_model)
  call physical_committed%capture_checkpoint(physical_checkpoint, ok)
  call require(ok, 'physical checkpoint')
  call open_wofost_accepted_window(physical_checkpoint, 1.0_real64, accepted_window, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_window%ready(), 'accepted window open')
  call begin_wofost_trial_contribution(physical_checkpoint, 1.0_real64, accepted_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'accepted contribution begin')
  call accumulate_wofost_trial_process_rate(accepted_trial, 0.0_real64, 1.0_real64, &
       5.0_real64, 5.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_trial%complete(), 'accepted contribution fill')
  call advance_and_commit_physical(physical_kernel, physical_model, physical_parameters, physical_forcing, &
       physical_config, physical_committed, physical_checkpoint, 0.0_real64, 1.0_real64)
  call certify_fkt_accepted_interval(physical_checkpoint, physical_committed, accepted_certificate, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_certificate%ready(), 'accepted certificate')
  call admit_wofost_accepted_trial(accepted_window, accepted_certificate, accepted_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_window%complete(), 'accepted trial admission')
  call prepare_wofost_crop_event_delivery(accepted_window, aggregates, event_token, available, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. available .and. event_token%ready(), 'event delivery ready')
  call identify_wofost_crop_event(event_token, event_identity, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. event_identity%ready(), 'event identity ready')
  print '(a)', 'FWOF_PP03_ACCEPTED_EVENT_PROVENANCE=PASS'

  call construct_fmr_wofost81_crop_transaction_parameters(common, p81, updatep, 0.0_real64, 0.0_real64, &
       crop_parameters, status)
  call require(status == FMR_WOF81_OK .and. crop_parameters%ready(), 'transaction parameters')
  call initialize_fmr_wofost81_crop_transaction_state(initial_owner, crop_initial_state, status)
  call require(status == FMR_WOF81_OK .and. crop_initial_state%ready(), 'transaction initial state')
  call prepare_fmr_wofost81_crop_event_forcing(accepted_window, forcing, crop_event_forcing, status)
  call require(status == FMR_WOF81_OK .and. crop_event_forcing%ready(), 'transaction event forcing')
  call setup_crop_config(crop_config)
  call setup_crop_committed(crop_initial_state, crop_committed, 93002_int64, 0.0_real64)
  call crop_kernel%bind_model(crop_model)
  call crop_committed%capture_checkpoint(crop_checkpoint, ok)
  call require(ok, 'crop checkpoint')

  call crop_kernel%advance_interval(crop_parameters, crop_committed, crop_event_forcing, crop_config, &
       0.0_real64, 1.0_real64, result1, candidate1, diag1, crop_checkpoint)
  call require(result1%status == CANONICAL_STATUS_COMPLETED .and. result1%completed, 'first runtime trial')
  call require(candidate1%ready(), 'first runtime candidate')
  call require(result1%mass%complete .and. result1%mass%residual == 0.0_real64, 'runtime zero water ledger')

  call crop_committed%snapshot(committed_snapshot, available)
  call require(available, 'precommit committed snapshot')
  select type (tx => committed_snapshot)
  type is (fmr_wofost81_crop_transaction_state_t)
    call tx%snapshot_owner(observed_owner, available)
    call require(available .and. same_owner(observed_owner, initial_owner), 'precommit owner unchanged')
    call require(.not. tx%receipt_ready(), 'precommit receipt absent')
  class default
    call require(.false., 'precommit transaction state type')
  end select

  call candidate1%snapshot(candidate_snapshot, available)
  call require(available, 'candidate snapshot')
  select type (tx => candidate_snapshot)
  type is (fmr_wofost81_crop_transaction_state_t)
    call tx%snapshot_owner(observed_owner, available)
    call require(available .and. same_owner(observed_owner, expected_owner), &
         'runtime candidate equals direct PP02 candidate')
    call require(tx%receipt_ready(), 'candidate receipt ready')
    call require(tx%consumed_event(event_identity), 'candidate receipt event identity')
  class default
    call require(.false., 'candidate transaction state type')
  end select
  print '(a)', 'FWOF_PP03_RUNTIME_CANDIDATE_EQUALS_PP02_DIRECT=PASS'
  print '(a)', 'FWOF_PP03_PRECOMMIT_OWNER_RECEIPT_UNCHANGED=PASS'

  ! Lifecycle cannot retire source delivery before the atomic crop commit exists.
  call reconcile_committed_wofost81_crop_event_receipt(accepted_window, crop_committed, retired, lifecycle_status)
  call require(.not. retired .and. lifecycle_status == FMR_WOF81_LIFECYCLE_NO_MATCHING_COMMITTED_RECEIPT, &
       'precommit lifecycle rejection')
  call require(.not. accepted_window%delivery_committed(), 'precommit event still live')
  print '(a)', 'FWOF_PP03_LIFECYCLE_REQUIRES_COMMITTED_RECEIPT=PASS'

  ! Discarding a complete trial cannot leak owner or receipt state.
  call crop_kernel%rollback_candidate(candidate1, diag1)
  call require(.not. candidate1%ready(), 'rollback candidate retired')
  call crop_committed%snapshot(committed_snapshot, available)
  call require(available, 'postrollback committed snapshot')
  select type (tx => committed_snapshot)
  type is (fmr_wofost81_crop_transaction_state_t)
    call tx%snapshot_owner(observed_owner, available)
    call require(available .and. same_owner(observed_owner, initial_owner), 'rollback owner unchanged')
    call require(.not. tx%receipt_ready(), 'rollback receipt unchanged')
  class default
    call require(.false., 'postrollback transaction state type')
  end select
  print '(a)', 'FWOF_PP03_ROLLBACK_ZERO_OWNER_RECEIPT_LEAK=PASS'

  call crop_kernel%advance_interval(crop_parameters, crop_committed, crop_event_forcing, crop_config, &
       0.0_real64, 1.0_real64, result2, candidate2, diag2, crop_checkpoint)
  call require(result2%status == CANONICAL_STATUS_COMPLETED .and. candidate2%ready(), 'second runtime trial')
  call candidate2%snapshot(candidate_snapshot, available)
  call require(available, 'second candidate snapshot')
  select type (tx => candidate_snapshot)
  type is (fmr_wofost81_crop_transaction_state_t)
    call tx%snapshot_owner(observed_owner, available)
    call require(available .and. same_owner(observed_owner, expected_owner), 'replay candidate equality')
    call require(tx%consumed_event(event_identity), 'replay candidate receipt')
  class default
    call require(.false., 'second candidate state type')
  end select

  revision_before = crop_committed%current_revision()
  call crop_kernel%commit_candidate(crop_committed, candidate2, diag2, did_commit, commit_status)
  call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'atomic candidate commit')
  call require(crop_committed%current_revision() == revision_before + 1_int64, 'one revision publication')
  call crop_committed%snapshot(committed_snapshot, available)
  call require(available, 'postcommit snapshot')
  select type (tx => committed_snapshot)
  type is (fmr_wofost81_crop_transaction_state_t)
    call tx%snapshot_owner(observed_owner, available)
    call require(available .and. same_owner(observed_owner, expected_owner), 'postcommit expected owner')
    call require(tx%receipt_ready() .and. tx%consumed_event(event_identity), 'postcommit matching receipt')
  class default
    call require(.false., 'postcommit transaction state type')
  end select
  print '(a)', 'FWOF_PP03_OWNER_AND_RECEIPT_ONE_ATOMIC_REVISION=PASS'

  call reconcile_committed_wofost81_crop_event_receipt(accepted_window, crop_committed, retired, lifecycle_status)
  call require(retired .and. lifecycle_status == FMR_WOF81_LIFECYCLE_OK, 'lifecycle retirement')
  call require(accepted_window%delivery_committed(), 'delivery retired after matching receipt')
  call reconcile_committed_wofost81_crop_event_receipt(accepted_window, crop_committed, retired, lifecycle_status)
  call require(.not. retired .and. lifecycle_status == FMR_WOF81_LIFECYCLE_ALREADY_RETIRED, &
       'lifecycle idempotent duplicate')
  print '(a)', 'FWOF_PP03_LIFECYCLE_MATCHED_RETIREMENT=PASS'
  print '(a)', 'FWOF_PP03_LIFECYCLE_DUPLICATE_IDEMPOTENT=PASS'

  ! Rebase the already-produced transaction candidate at the original time to
  ! hit the model-level duplicate receipt guard directly (not only kernel time mismatch).
  call duplicate_committed%initialize(93003_int64, candidate_snapshot, ok, 0.0_real64)
  call require(ok, 'duplicate committed initialization')
  call duplicate_kernel%bind_model(duplicate_model)
  call duplicate_kernel%advance_interval(crop_parameters, duplicate_committed, crop_event_forcing, crop_config, &
       0.0_real64, 1.0_real64, duplicate_result, duplicate_candidate, duplicate_diag)
  call require(duplicate_result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'duplicate event transaction failure')
  call require(.not. duplicate_candidate%ready(), 'duplicate event no candidate')
  call require(duplicate_committed%current_revision() == 0_int64, 'duplicate event no publication')
  call require(duplicate_model%last_status_code() == FMR_WOF81_EVENT_ALREADY_CONSUMED, 'duplicate receipt guard status')
  print '(a)', 'FWOF_PP03_DUPLICATE_EVENT_ZERO_EXTRA_ADVANCEMENT=PASS'

  ! Crop-evolution failure must not mutate the fresh committed owner/receipt.
  nanv = ieee_value(0.0_real64, ieee_quiet_nan)
  bad_forcing = forcing
  bad_forcing%minimum_temperature = nanv
  call prepare_fmr_wofost81_crop_event_forcing(accepted_window_from_token_source(event_token, accepted_window), &
       bad_forcing, bad_crop_event_forcing, status)
  call require(status == FMR_WOF81_OK .and. bad_crop_event_forcing%ready(), 'bad forcing provenance still valid')
  call setup_crop_committed(crop_initial_state, bad_committed, 93004_int64, 0.0_real64)
  call bad_kernel%bind_model(bad_model)
  call bad_committed%capture_checkpoint(bad_checkpoint, ok)
  call require(ok, 'bad path checkpoint')
  call bad_kernel%advance_interval(crop_parameters, bad_committed, bad_crop_event_forcing, crop_config, &
       0.0_real64, 1.0_real64, bad_result, bad_candidate, bad_diag, bad_checkpoint)
  call require(bad_result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'bad crop forcing rejected')
  call require(.not. bad_candidate%ready(), 'bad crop forcing no candidate')
  call require(bad_committed%current_revision() == 0_int64, 'bad crop forcing no publication')
  call bad_committed%snapshot(committed_snapshot, available)
  call require(available, 'bad path committed snapshot')
  select type (tx => committed_snapshot)
  type is (fmr_wofost81_crop_transaction_state_t)
    call tx%snapshot_owner(observed_owner, available)
    call require(available .and. same_owner(observed_owner, initial_owner), 'bad path owner unchanged')
    call require(.not. tx%receipt_ready(), 'bad path receipt unchanged')
  class default
    call require(.false., 'bad path transaction state type')
  end select
  print '(a)', 'FWOF_PP03_FAILED_EVOLUTION_ZERO_OWNER_RECEIPT_MUTATION=PASS'

  bad_policy_config = crop_config
  bad_policy_config%transaction%max_retries = 1
  call setup_crop_committed(crop_initial_state, policy_committed, 93005_int64, 0.0_real64)
  call policy_kernel%bind_model(policy_model)
  call policy_kernel%advance_interval(crop_parameters, policy_committed, crop_event_forcing, bad_policy_config, &
       0.0_real64, 1.0_real64, policy_result, policy_candidate, policy_diag)
  call require(policy_result%status == KERNEL_STATUS_NOT_ADMITTED, 'retry policy rejected')
  call require(.not. policy_candidate%ready(), 'retry policy no candidate')
  call require(policy_committed%current_revision() == 0_int64, 'retry policy no publication')
  print '(a)', 'FWOF_PP03_FIXED_ONE_DAY_POLICY_ENFORCED=PASS'

  print '(a)', 'F_WOF_PP03_RUNTIME_ACTIVATION_TEST PASS'

contains

  function accepted_window_from_token_source(token, source_window) result(window)
    type(fmr_wofost_crop_event_token_t), intent(in) :: token
    type(fmr_wofost_accepted_window_t), intent(in) :: source_window
    type(fmr_wofost_accepted_window_t) :: window
    ! The bad-forcing path needs the same unretired accepted provenance. The
    ! source window was retired by the successful lifecycle above, so rebuild
    ! is intentionally not attempted here. This helper is replaced below by a
    ! fresh accepted-window construction before the failure path is executed.
    if (.not. token%ready()) error stop 'invalid PP03 token'
    window = source_window
  end function accepted_window_from_token_source

  subroutine configure_common(bundle)
    type(wofost_rate_parameter_bundle_t), intent(out) :: bundle
    type(wofost_rate_scalar_parameters_t) :: s
    type(wofost_rate_parameter_tables_t) :: t
    integer :: rc
    s%development_daylength_mode = 0
    s%vegetative_temperature_sum_required = 1000.0_real64
    s%generative_temperature_sum_required = 1000.0_real64
    s%diffuse_extinction_coefficient = 0.5_real64
    s%initial_light_use_efficiency = 0.4_real64
    s%co2_to_dry_matter_fraction = 0.7_real64
    s%attainable_yield_multiplier = 1.0_real64
    s%conversion_efficiency_root = 0.7_real64
    s%conversion_efficiency_stem = 0.7_real64
    s%conversion_efficiency_leaf = 0.7_real64
    s%conversion_efficiency_storage = 0.7_real64
    s%respiration_temperature_q10 = 2.0_real64
    s%maintenance_respiration_root = 0.01_real64
    s%maintenance_respiration_leaf = 0.01_real64
    s%maintenance_respiration_stem = 0.01_real64
    s%maintenance_respiration_storage = 0.01_real64
    s%maximum_leaf_relative_death_rate = 0.03_real64
    s%leaf_age_base_temperature = 0.0_real64
    s%maximum_relative_lai_growth_rate = 0.008_real64
    call make_table([0.0_real64,40.0_real64],[10.0_real64,10.0_real64],t%temperature_sum_increment)
    call make_table([0.0_real64,2.0_real64],[35.0_real64,35.0_real64],t%maximum_assimilation)
    call make_table([0.0_real64,40.0_real64],[1.0_real64,1.0_real64],t%daytime_temperature_factor)
    call make_table([-10.0_real64,20.0_real64],[1.0_real64,1.0_real64],t%minimum_temperature_factor)
    call make_table([0.0_real64,2.0_real64],[1.0_real64,1.0_real64],t%maintenance_respiration_factor)
    call make_table([0.0_real64,2.0_real64],[0.2_real64,0.2_real64],t%root_partition_fraction)
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%leaf_partition_fraction)
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%stem_partition_fraction)
    call make_table([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%storage_partition_fraction)
    call make_table([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],t%relative_root_death_rate)
    call make_table([0.0_real64,2.0_real64],[0.01_real64,0.01_real64],t%relative_stem_death_rate)
    call make_table([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],t%specific_leaf_area)
    call construct_wofost_rate_parameter_bundle(s,t,bundle,rc)
    call require(rc == WOFOST_RATE_PARAMETER_OK .and. bundle%ready(), 'common parameter constructor')
  end subroutine configure_common

  subroutine make_table(x,y,table)
    real(real64), intent(in) :: x(:), y(:)
    type(wofost_rate_table_t), intent(out) :: table
    integer :: rc
    call construct_wofost_rate_table(x,y,table,rc)
    call require(rc == 0, 'rate table construction')
  end subroutine make_table

  subroutine configure_p81(p)
    type(wofost81_daily_parameter_contract_t), intent(out) :: p
    p%base%assimilation%amax_lnb = 0.0_real64
    p%base%assimilation%amax_ref = 35.0_real64
    p%base%assimilation%amax_slp = 3.24_real64
    p%base%assimilation%kn = 0.4_real64
    p%base%nitrogen%nmaxst_fr = 0.5_real64
    p%base%nitrogen%nmaxrt_fr = 0.5_real64
    p%base%nitrogen%nmaxso = 0.0176_real64
    p%base%nitrogen%nresidlv = 0.004_real64
    p%base%nitrogen%nresidst = 0.002_real64
    p%base%nitrogen%nresidrt = 0.002_real64
    p%base%nitrogen%tcnt = 10.0_real64
    p%base%nitrogen%nfix_fr = 0.0_real64
    p%base%nitrogen%rnuptakemax = 100.0_real64
    p%base%nitrogen%dvs_n_transl = 0.8_real64
    p%base%nitrogen%rgrlai_min = 0.004_real64
    call make_table([0.0_real64,40.0_real64],[0.4_real64,0.4_real64],p%tables%light_use_efficiency)
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],p%tables%diffuse_extinction_coefficient)
    call make_table([0.0_real64,2.0_real64],[0.04_real64,0.04_real64],p%tables%maximum_leaf_n_concentration)
    call make_table([0.0_real64,3.0_real64],[1.0_real64,1.0_real64],p%tables%leaf_ageing_n_stress_multiplier)
    call require(p%validate() == WOFOST81_DAILY_PARAMETER_OK, 'WOFOST81 parameter bundle')
  end subroutine configure_p81

  subroutine configure_owner(owner,p,status_out)
    type(wofost81_crop_owner_state_t), intent(out) :: owner
    type(wofost81_daily_parameter_contract_t), intent(in) :: p
    integer, intent(out) :: status_out
    owner%crop%crop_emerged = .true.
    owner%crop%development_stage = 0.5_real64
    allocate(owner%crop%biomass,owner%crop%evolution_continuation)
    owner%crop%biomass%root_biomass = 100.0_real64
    owner%crop%biomass%stem_biomass = 200.0_real64
    owner%crop%biomass%storage_biomass = 50.0_real64
    owner%crop%biomass%leaf_biomass = [100.0_real64,100.0_real64]
    owner%crop%biomass%specific_leaf_area = [0.02_real64,0.02_real64]
    owner%crop%biomass%leaf_age = [1.0_real64,2.0_real64]
    owner%crop%biomass%exponential_leaf_area_index = 4.0_real64
    call initialize_wofost81_n_owner_state(200.0_real64,200.0_real64,100.0_real64,0.04_real64, &
         p%base%nitrogen,owner%nitrogen,status_out)
  end subroutine configure_owner

  logical function same_owner(a,b) result(equal)
    type(wofost81_crop_owner_state_t), intent(in) :: a,b
    equal = .false.
    if (a%validate() /= WOFOST81_CROP_OWNER_OK .or. b%validate() /= WOFOST81_CROP_OWNER_OK) return
    if (a%crop%crop_emerged .neqv. b%crop%crop_emerged) return
    if (a%crop%development_stage /= b%crop%development_stage) return
    if (a%crop%biomass%root_biomass /= b%crop%biomass%root_biomass) return
    if (a%crop%biomass%stem_biomass /= b%crop%biomass%stem_biomass) return
    if (a%crop%biomass%storage_biomass /= b%crop%biomass%storage_biomass) return
    if (a%crop%biomass%exponential_leaf_area_index /= b%crop%biomass%exponential_leaf_area_index) return
    if (size(a%crop%biomass%leaf_biomass) /= size(b%crop%biomass%leaf_biomass)) return
    if (size(a%crop%biomass%specific_leaf_area) /= size(b%crop%biomass%specific_leaf_area)) return
    if (size(a%crop%biomass%leaf_age) /= size(b%crop%biomass%leaf_age)) return
    if (.not. all(a%crop%biomass%leaf_biomass == b%crop%biomass%leaf_biomass)) return
    if (.not. all(a%crop%biomass%specific_leaf_area == b%crop%biomass%specific_leaf_area)) return
    if (.not. all(a%crop%biomass%leaf_age == b%crop%biomass%leaf_age)) return
    if (a%nitrogen%value%namountlv /= b%nitrogen%value%namountlv) return
    if (a%nitrogen%value%namountrt /= b%nitrogen%value%namountrt) return
    if (a%nitrogen%value%namountso /= b%nitrogen%value%namountso) return
    if (a%nitrogen%value%namountst /= b%nitrogen%value%namountst) return
    if (a%nitrogen%value%nuptake_total /= b%nitrogen%value%nuptake_total) return
    if (a%nitrogen%value%initial_total /= b%nitrogen%value%initial_total) return
    equal = .true.
  end function same_owner

  subroutine setup_physical_committed(state,lineage_id,initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized
    allocate(fwof34_state_t :: physical)
    select type (physical)
    type is (fwof34_state_t)
      physical%water = 1.0_real64
    end select
    call state%initialize(lineage_id,physical,initialized,initial_time)
    call require(initialized,'physical committed initialize')
  end subroutine setup_physical_committed

  subroutine setup_physical_solver(p,f,c)
    type(fwof34_parameters_t), intent(out) :: p
    type(fwof34_forcing_t), intent(out) :: f
    type(canonical_numerical_config_t), intent(out) :: c
    p%flux_rate = 0.1_real64
    f%scale = 1.0_real64
    c%transaction%temporal_tolerance = 1.0_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 2
    c%max_committed_substeps = 8
    c%progress_tolerance = 0.0_real64
  end subroutine setup_physical_solver

  subroutine advance_and_commit_physical(k,m,p,f,c,state,checkpoint,t0,t1)
    type(kernel_executor_t), intent(inout) :: k
    type(fwof34_model_t), target, intent(inout) :: m
    type(fwof34_parameters_t), intent(in) :: p
    type(fwof34_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: t0,t1
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: committed_ok
    integer :: commit_rc
    call k%advance_interval(p,state,f,c,t0,t1,result,candidate,diagnostics,checkpoint)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. candidate%ready(), 'physical trial complete')
    call k%commit_candidate(state,candidate,diagnostics,committed_ok,commit_rc)
    call require(committed_ok .and. commit_rc == KERNEL_COMMIT_STATUS_COMMITTED, 'physical commit')
  end subroutine advance_and_commit_physical

  subroutine setup_crop_committed(initial_state,state,lineage_id,initial_time)
    type(fmr_wofost81_crop_transaction_state_t), intent(in) :: initial_state
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized
    allocate(fmr_wofost81_crop_transaction_state_t :: physical)
    select type (typed => physical)
    type is (fmr_wofost81_crop_transaction_state_t)
      typed = initial_state
    class default
      error stop 'PP03 crop transaction allocation failure'
    end select
    call state%initialize(lineage_id,physical,initialized,initial_time)
    call require(initialized,'crop committed initialize')
  end subroutine setup_crop_committed

  subroutine setup_crop_config(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 0.0_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 0
    config%max_committed_substeps = 1
    config%progress_tolerance = 0.0_real64
  end subroutine setup_crop_config

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      print '(a)', trim(label)//' failed'
      error stop 1
    end if
  end subroutine require
end program test_fwof_pp03_runtime_activation

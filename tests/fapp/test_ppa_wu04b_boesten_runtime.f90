program test_ppa_wu04b_boesten_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, &
       FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_restricted_surface_evaporation, only: boesten_evaporation_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_boesten_evaporation_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_boesten_evaporation_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_result_t
  use mod_ppa_wu04b_boesten_forcing_adapter, only: bind_ppa_wu04b_boesten_runtime_forcing, PPA_WU04B_BIND_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_TEMPLATE_MISMATCH
  implicit none

  real(real64), parameter :: T0 = 5200.125_real64
  real(real64), parameter :: TM = 5200.250_real64
  real(real64), parameter :: T1 = 5200.375_real64
  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: HARD_MASS_GATE = 1.0e-12_real64
  real(real64), parameter :: COFRED = 0.35_real64
  real(real64), parameter :: INITIAL_SPEV = 0.50_real64
  real(real64), parameter :: INITIAL_SAEV = 0.20_real64
  integer(int64), parameter :: PARAMETER_SET_IDENTITY = 404002_int64

  type(fmr_production_application_config_t) :: app_config
  type(fmr_production_application_bootstrap_t) :: app
  type(ppa_wu03_common_forcing_result_t) :: common_result
  type(fmr_b110_physical_forcing_t), allocatable :: bound_forcing(:)
  type(fmr_serialized_column_result_t), allocatable :: app_results(:)
  integer(int64), allocatable :: revisions(:)
  real(real64) :: conductivity0
  integer :: status

  call initialize_application_config(app_config, conductivity0)
  common_result%valid = .true.
  common_result%top_request%conductivity_mean_method = app_config%tiles(1)%parameters%swkmean
  common_result%top_request%pressure_head_top_cm = app_config%tiles(1)%initial_state%pressure_head(1)
  common_result%top_request%water_content_top = app_config%tiles(1)%initial_state%water_content(1)
  common_result%top_request%candidate_ponding_depth_cm = 0.0_real64
  common_result%top_request%previous_ponding_depth_cm = 0.0_real64
  common_result%top_request%step_duration_day = T1-T0
  common_result%top_request%precipitation_rate_cm_per_day = conductivity0
  common_result%top_request%irrigation_rate_cm_per_day = 0.0_real64
  common_result%top_request%snowmelt_rate_cm_per_day = 0.0_real64
  common_result%top_request%runon_rate_cm_per_day = 0.0_real64
  common_result%top_request%potential_bare_soil_evaporation_cm_per_day = 0.0_real64
  common_result%top_request%potential_pond_evaporation_cm_per_day = 0.0_real64
  common_result%top_request%ponding_max_cm = 2.0_real64
  common_result%top_request%runoff_resistance_day = 1.0_real64
  common_result%top_request%runoff_exponent = 1.0_real64

  allocate(bound_forcing(1))
  call bind_ppa_wu04b_boesten_runtime_forcing(app_config%tiles(1)%base_forcing, common_result, &
       bound_forcing(1), status)
  call require(status == PPA_WU04B_BIND_OK, 'Boesten runtime forcing binding')
  call require(allocated(bound_forcing(1)%boesten_evaporation), 'Boesten forcing allocated')
  call require(.not. allocated(bound_forcing(1)%black_evaporation), 'Black forcing absent')
  call require(bound_forcing(1)%top_flux == 0.0_real64, 'legacy fixed top flux neutralized')

  call app%initialize(app_config, status)
  call require(status == FMR_APP_BOOT_OK .and. app%ready(), 'Boesten production bootstrap')
  call app%run_standalone_with_forcing(T0, T1, bound_forcing, app_results, status)
  call require(status == FMR_APP_BOOT_OK, 'Boesten production application run')
  call require(allocated(app_results) .and. size(app_results) == 1, 'Boesten result count')
  call require(app_results(1)%completed .and. app_results(1)%committed, 'Boesten application committed')
  call require(app_results(1)%mass%complete, 'Boesten mass complete')
  call require(abs(app_results(1)%mass%residual) <= HARD_MASS_GATE, 'Boesten hard mass')
  call app%copy_committed_revisions(revisions, status)
  call require(status == FMR_APP_BOOT_OK .and. revisions(1) == 1_int64, 'Boesten one committed revision')
  call app%close(status)
  call require(status == FMR_APP_BOOT_OK, 'Boesten app close')
  print '(a)', 'PPA_WU04B_PRODUCTION_APPLICATION_REACHABLE=PASS'
  print '(a)', 'PPA_WU04B_ACTUAL_EVAPORATION_HYDRAULIC_MASS_OWNER=PASS'
  print '(a)', 'PPA_WU04B_HARD_MASS=PASS'

  call verify_transaction_retry_and_restart(app_config, bound_forcing(1))
  print '(a)', 'PPA-WU04-B BOESTEN RUNTIME TEST PASS'

contains

  subroutine verify_transaction_retry_and_restart(config_source, forcing)
    type(fmr_production_application_config_t), intent(in) :: config_source
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(fmr_serialized_reference_backend_t) :: backend, direct_backend
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(kernel_committed_state_t) :: committed, direct_committed
    type(kernel_committed_state_t), allocatable :: states(:), restored_states(:), mismatch_states(:)
    type(kernel_checkpoint_t) :: checkpoint, direct_checkpoint
    type(kernel_candidate_state_t) :: full_candidate, retry_candidate, direct_candidate
    type(kernel_result_t) :: full_result, retry_result, direct_result
    type(kernel_diagnostics_t) :: full_diag, retry_diag, direct_diag
    type(canonical_numerical_config_t) :: numerical
    type(boesten_evaporation_state_t) :: initial_pair
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:), bad_templates(:)
    type(fmr_committed_restart_bundle_t) :: bundle
    logical :: ok, did_commit, exported, restored
    integer :: commit_status, restart_status
    real(real64) :: s0, a0, sf, af, sr, ar, sd, ad, sc, ac, sx, ax

    column%column_id = 404201_int64
    column%template_id = config_source%tiles(1)%template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    template = config_source%tiles(1)%template
    parameters = config_source%tiles(1)%parameters
    numerical = config_source%numerical
    initial_pair%spev = INITIAL_SPEV
    initial_pair%saev = INITIAL_SAEV

    call fmr_new_b110_boesten_evaporation_committed_state(committed, column%column_id, &
         config_source%tiles(1)%initial_state, initial_pair, T0, ok)
    call require(ok, 'low-level Boesten committed state')
    call committed%capture_checkpoint(checkpoint, ok)
    call require(ok .and. checkpoint%ready(), 'Boesten checkpoint')
    call snapshot_pair_committed(committed, s0, a0)
    call require(same_bits(s0, INITIAL_SPEV) .and. same_bits(a0, INITIAL_SAEV), 'initial pair exact')

    call backend%initialize(top)
    call backend%run_trial(column, template, parameters, committed, forcing, numerical, T0, T1, checkpoint, &
         full_result, full_candidate, full_diag)
    call require(full_result%completed .and. full_candidate%ready(), 'full Boesten trial')
    call snapshot_pair_candidate(full_candidate, sf, af)
    call require(.not. (same_bits(sf,s0) .and. same_bits(af,a0)), 'full candidate pair advanced')

    call backend%discard_trial_candidate(full_candidate, full_diag)
    call snapshot_pair_committed(committed, sc, ac)
    call require(same_bits(sc,s0) .and. same_bits(ac,a0), 'discard leaves pair unchanged')
    call require(committed%current_revision() == 0_int64, 'discard leaves revision unchanged')

    call backend%run_trial(column, template, parameters, committed, forcing, numerical, T0, TM, checkpoint, &
         retry_result, retry_candidate, retry_diag)
    call require(retry_result%completed .and. retry_candidate%ready(), 'changed-dt retry candidate')
    call snapshot_pair_candidate(retry_candidate, sr, ar)

    call fmr_new_b110_boesten_evaporation_committed_state(direct_committed, column%column_id + 1_int64, &
         config_source%tiles(1)%initial_state, initial_pair, T0, ok)
    call require(ok, 'direct committed state')
    call direct_committed%capture_checkpoint(direct_checkpoint, ok)
    call require(ok, 'direct checkpoint')
    column%column_id = column%column_id + 1_int64
    call direct_backend%initialize(top)
    call direct_backend%run_trial(column, template, parameters, direct_committed, forcing, numerical, T0, TM, &
         direct_checkpoint, direct_result, direct_candidate, direct_diag)
    call require(direct_result%completed .and. direct_candidate%ready(), 'direct same-dt candidate')
    call snapshot_pair_candidate(direct_candidate, sd, ad)
    call require(same_bits(sr,sd) .and. same_bits(ar,ad), 'retry pair equals direct same-dt pair')
    print '(a)', 'PPA_WU04B_REJECTED_TRIAL_PAIR_IMMUTABLE=PASS'
    print '(a)', 'PPA_WU04B_CHANGED_DT_RETRY_FROM_CHECKPOINT=PASS'

    column%column_id = 404201_int64
    call backend%commit_trial_candidate(committed, retry_candidate, retry_diag, did_commit, commit_status)
    call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'retry pair commit')
    call snapshot_pair_committed(committed, sc, ac)
    call require(same_bits(sc,sr) .and. same_bits(ac,ar), 'accepted pair atomic commit')

    allocate(columns(1), templates(1), states(1), restored_states(1), mismatch_states(1), bad_templates(1))
    columns(1) = column
    templates(1) = template
    states(1) = committed
    call fmr_export_committed_restart(columns, templates, states, PARAMETER_SET_IDENTITY, bundle, exported, restart_status)
    call require(exported .and. restart_status == FMR_RESTART_OK, 'Boesten restart export')
    call fmr_restore_committed_restart(bundle, PARAMETER_SET_IDENTITY, columns, templates, restored_states, restored, &
         restart_status)
    call require(restored .and. restart_status == FMR_RESTART_OK, 'Boesten restart restore')
    call snapshot_pair_committed(restored_states(1), sx, ax)
    call require(same_bits(sx,sc) .and. same_bits(ax,ac), 'Boesten pair exact restart')

    bad_templates = templates
    bad_templates(1)%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    call fmr_restore_committed_restart(bundle, PARAMETER_SET_IDENTITY, columns, bad_templates, mismatch_states, restored, &
         restart_status)
    call require(.not. restored .and. restart_status == FMR_RESTART_TEMPLATE_MISMATCH, 'Boesten to BASE rejected')
    bad_templates = templates
    bad_templates(1)%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION
    mismatch_states = kernel_committed_state_t()
    call fmr_restore_committed_restart(bundle, PARAMETER_SET_IDENTITY, columns, bad_templates, mismatch_states, restored, &
         restart_status)
    call require(.not. restored .and. restart_status == FMR_RESTART_TEMPLATE_MISMATCH, 'Boesten to Black rejected')
    print '(a)', 'PPA_WU04B_RESTART_EXACT_PAIR_ROUNDTRIP=PASS'
    print '(a)', 'PPA_WU04B_RESTART_OPTION_LAYOUT_FAIL_CLOSED=PASS'
  end subroutine verify_transaction_retry_and_restart

  subroutine initialize_application_config(value, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(out) :: conductivity0

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 1.0e3_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 404201_int64
    value%tiles(1)%template%template_id = 404202_int64
    value%tiles(1)%template%physics_topology_id = 404210_int64
    value%tiles(1)%template%vertical_layout_id = 404220_int64
    value%tiles(1)%template%state_layout_id = 404230_int64
    value%tiles(1)%template%solver_interface_id = 404240_int64
    value%tiles(1)%template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    value%tiles(1)%initial_boesten_spev = INITIAL_SPEV
    value%tiles(1)%initial_boesten_saev = INITIAL_SAEV

    call initialize_parameters(value%tiles(1)%parameters)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 404302_int64
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
    p%black_evaporation_active = .false.
    p%boesten_evaporation_active = .true.
    allocate(p%boesten_evaporation)
    p%boesten_evaporation%cofred = COFRED
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

  subroutine snapshot_pair_committed(committed, spev, saev)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), intent(out) :: spev, saev
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call committed%snapshot(snapshot, available)
    call require(available, 'committed pair snapshot')
    select type (state => snapshot)
    type is (fmr_b110_boesten_evaporation_state_t)
      spev = state%boesten_evaporation%spev
      saev = state%boesten_evaporation%saev
    class default
      call require(.false., 'committed Boesten family')
    end select
  end subroutine snapshot_pair_committed

  subroutine snapshot_pair_candidate(candidate, spev, saev)
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64), intent(out) :: spev, saev
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call candidate%snapshot(snapshot, available)
    call require(available, 'candidate pair snapshot')
    select type (state => snapshot)
    type is (fmr_b110_boesten_evaporation_state_t)
      spev = state%boesten_evaporation%spev
      saev = state%boesten_evaporation%saev
    class default
      call require(.false., 'candidate Boesten family')
    end select
  end subroutine snapshot_pair_candidate

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
      write(*,'(a,1x,a)') 'PPA_WU04B_RUNTIME_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu04b_boesten_runtime

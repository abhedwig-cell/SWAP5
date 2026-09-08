program test_fmr06_snow_smoke
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_snow_process, only: snow_state_t
  implicit none

  real(real64), parameter :: t0 = 1400.25_real64
  real(real64), parameter :: t1 = 1401.25_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: initial_snow = 0.10_real64
  real(real64), parameter :: snowfall = 0.02_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: committed, short_committed, long_committed
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_checkpoint_t) :: checkpoint, short_checkpoint, long_checkpoint
  type(kernel_candidate_state_t) :: candidate, replay_candidate, rejected_candidate
  type(kernel_result_t) :: result, replay_result, rejected_result
  type(kernel_diagnostics_t) :: diagnostics, replay_diagnostics, rejected_diagnostics
  type(kernel_executor_t) :: transaction_control
  type(fmr_serialized_physical_observation_t) :: observation
  integer(int64) :: committed_before, candidate_fp, replay_fp
  real(real64) :: conductivity0, committed_time
  logical :: ok, did_commit, available
  integer :: commit_status

  call configure_template(template)
  call configure_parameters(parameters, initial_state, conductivity0)
  call configure_forcing(forcing, conductivity0)
  call configure_transaction(config)
  call configure_column(column, template)

  call fmr_new_b110_committed_state(committed, column%column_id, initial_state, t0, ok)
  call require(ok, 'initial committed state')
  committed_before = committed_fingerprint(committed)

  call backend%initialize(top_provider)
  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok, 'capture initial checkpoint')

  call reset_legacy_globals()
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       result, candidate, diagnostics)
  call require(result%completed, 'snow physical trial completed')
  call require(candidate%ready(), 'snow candidate ready')
  call require(result%mass%complete, 'authoritative mass complete')
  call require(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'mass missing mask zero')
  call require(abs(result%mass%residual) <= hard_mass_gate, 'authoritative mass within hard gate')
  call require(committed_fingerprint(committed) == committed_before, 'trial did not mutate committed state')

  observation = backend%observation()
  call require(observation%snow_active, 'snow observation active')
  call require(observation%snow_event_prepared, 'snow event prepared')
  call require(observation%snow_mass%available, 'snow component mass available')
  call require(same_bits(observation%snow_mass%snowfall_external_in, snowfall), 'snowfall mass preserved')
  call require(same_bits(observation%snow_mass%melt_internal_transfer, 0.0_real64), 'no melt smoke fixture')
  call require(same_bits(observation%snow_mass%sublimation_external_out, 0.0_real64), 'no sublimation smoke fixture')
  call require(same_bits(observation%snow_mass%unrounded_residual, 0.0_real64), 'snow component mass exact')

  candidate_fp = candidate_fingerprint(candidate)
  call require(candidate_snow_state(candidate, initial_snow + snowfall, .true., t0), 'candidate snow state')

  call fmr_discard_candidate(transaction_control, candidate, diagnostics)
  call require(.not. candidate%ready(), 'discard invalidates candidate')
  call require(committed_fingerprint(committed) == committed_before, 'rollback leaves committed unchanged')

  call reset_legacy_globals()
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       replay_result, replay_candidate, replay_diagnostics)
  call require(replay_result%completed .and. replay_candidate%ready(), 'replay completed')
  replay_fp = candidate_fingerprint(replay_candidate)
  call require(replay_fp == candidate_fp, 'replay candidate bitwise identity')
  call require(mass_identical(result, replay_result), 'replay authoritative mass identity')

  call fmr_commit_candidate(transaction_control, committed, replay_candidate, replay_diagnostics, did_commit, commit_status)
  call require(did_commit, 'commit accepted')
  call require(committed%current_revision() == 1_int64, 'commit revision increments')
  call committed%current_time(committed_time, available)
  call require(available .and. same_bits(committed_time, t1), 'commit advances time')
  call require(committed_snow_state(committed, initial_snow + snowfall, .true., t0), 'committed snow state published once')

  call fmr_new_b110_committed_state(short_committed, column%column_id + 1_int64, initial_state, t0, ok)
  call require(ok, 'short committed init')
  call fmr_capture_checkpoint(short_committed, short_checkpoint, ok)
  call require(ok, 'short checkpoint')
  call backend%run_trial(column, template, parameters, short_committed, forcing, config, t0, t0 + 0.5_real64, &
       short_checkpoint, rejected_result, rejected_candidate, rejected_diagnostics)
  call require(.not. rejected_result%completed .and. rejected_result%status == KERNEL_STATUS_NOT_ADMITTED, &
       'subdaily snow fail closed')
  call require(.not. rejected_candidate%ready(), 'subdaily no candidate')

  call fmr_new_b110_committed_state(long_committed, column%column_id + 2_int64, initial_state, t0, ok)
  call require(ok, 'long committed init')
  call fmr_capture_checkpoint(long_committed, long_checkpoint, ok)
  call require(ok, 'long checkpoint')
  call backend%run_trial(column, template, parameters, long_committed, forcing, config, t0, t0 + 2.0_real64, &
       long_checkpoint, rejected_result, rejected_candidate, rejected_diagnostics)
  call require(.not. rejected_result%completed .and. rejected_result%status == KERNEL_STATUS_NOT_ADMITTED, &
       'multiday snow fail closed')
  call require(.not. rejected_candidate%ready(), 'multiday no candidate')

  write(*,'(A)') 'FMR06_SNOW_ONE_CALL_DAILY_TRIAL=PASS'
  write(*,'(A)') 'FMR06_SNOW_ROLLBACK=PASS'
  write(*,'(A)') 'FMR06_SNOW_REPLAY_BITWISE=PASS'
  write(*,'(A)') 'FMR06_SNOW_COMMIT=PASS'
  write(*,'(A)') 'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS'
  write(*,'(A,ES24.17E3)') 'FMR06_SNOW_AUTHORITATIVE_MASS_RESIDUAL=', result%mass%residual
  write(*,'(A)') 'FMR06_SNOW_SUBDAILY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR06_SNOW_MULTIDAY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR06_SNOW_SMOKE_TEST PASS'

contains

  subroutine configure_column(c, tmpl)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(in) :: tmpl
    c%column_id = 606001_int64
    c%template_id = tmpl%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_template(tmpl)
    type(fmr_template_t), intent(out) :: tmpl
    tmpl%template_id = 606_int64
    tmpl%physics_topology_id = 60601_int64
    tmpl%vertical_layout_id = 60602_int64
    tmpl%state_layout_id = 60603_int64
    tmpl%solver_interface_id = 60604_int64
    tmpl%optional_state_layout_id = 60605_int64
    tmpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(p, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    p%parameter_set_id = 60601_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do i = 1, numnod
      p%cofgen(1,i) = 0.032_real64
      p%cofgen(2,i) = 0.423_real64
      p%cofgen(3,i) = 4.75_real64
      p%cofgen(4,i) = 0.0135_real64
      p%cofgen(5,i) = 0.365_real64
      p%cofgen(6,i) = 1.455_real64
      p%cofgen(7,i) = 1.0_real64 - 1.0_real64/p%cofgen(6,i)
      p%cofgen(8,i) = p%cofgen(4,i)
      p%cofgen(9,i) = 0.0_real64
      p%cofgen(10,i) = p%cofgen(3,i)
      p%cofgen(11,i) = 0.999_real64
      p%cofgen(12,i) = 0.99_real64*p%cofgen(3,i)
      p%cofgen(22,i) = -1.0e6_real64
      p%cofgen(23,i) = 1.0e-12_real64
    end do
    p%bottom_mode = 7
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .true.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    allocate(p%snow)
    p%snow%suppress_sublimation = 1
    p%snow%melt_coefficient = 0.35_real64

    call initialize_b110_default_mvg_parameters(hyd_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod), state%snow)
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    state%snow%process = snow_state_t(initial_snow, 0.0_real64)
    state%snow%event_applied = .false.
    state%snow%event_t0 = 0.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(f, conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity0
    integer :: i

    f%top_flux = -conductivity0
    f%top_head = head0
    f%bottom_flux = -conductivity0
    f%bottom_head = -100.0_real64
    allocate(f%drainage_flux_by_level(2,numnod), f%subsurface_irrigation_source(numnod), &
             f%root_extraction_sink(numnod), f%snow)
    do i = 1, numnod
      f%drainage_flux_by_level(1,i) = 1.0e-5_real64*real(i,real64)
      f%drainage_flux_by_level(2,i) = -2.0e-6_real64*real(i+1,real64)
      f%subsurface_irrigation_source(i) = f%drainage_flux_by_level(1,i) + f%drainage_flux_by_level(2,i)
      f%root_extraction_sink(i) = 0.0_real64
    end do
    f%snow%snowfall_input = snowfall
    f%snow%rain_on_snow_input = 0.0_real64
    f%snow%soil_surface_temperature = -5.0_real64
    f%snow%mean_air_temperature = -5.0_real64
    f%snow%potential_soil_evaporation = 0.0_real64
    f%snow%reduced_soil_evaporation = 0.0_real64
    f%snow%ponding_evaporation = 0.0_real64
  end subroutine configure_forcing

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 2
    cfg%max_committed_substeps = 8
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot available')
    fp = physical_fingerprint(snapshot)
  end function committed_fingerprint

  integer(int64) function candidate_fingerprint(state) result(fp)
    type(kernel_candidate_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    call require(got, 'candidate snapshot available')
    fp = physical_fingerprint(snapshot)
  end function candidate_fingerprint

  integer(int64) function physical_fingerprint(snapshot) result(fp)
    class(transaction_state_t), allocatable, intent(in) :: snapshot
    integer :: i
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = ieor(fp, int(physical%active_nodes,int64))
      do i = 1, physical%active_nodes
        fp = ieor(fp, transfer(physical%pressure_head(i),fp))
        fp = ieor(fp, transfer(physical%water_content(i),fp))
      end do
      fp = ieor(fp, transfer(physical%ponding_depth,fp))
      fp = ieor(fp, transfer(physical%groundwater_level,fp))
      call require(allocated(physical%snow), 'fingerprint snow allocated')
      fp = ieor(fp, transfer(physical%snow%process%snow_water_storage,fp))
      fp = ieor(fp, transfer(physical%snow%process%liquid_water_storage,fp))
      fp = ieor(fp, merge(1_int64,0_int64,physical%snow%event_applied))
      fp = ieor(fp, transfer(physical%snow%event_t0,fp))
    class default
      error stop 'F-MR06 unexpected physical state type'
    end select
  end function physical_fingerprint

  logical function committed_snow_state(state, expected_storage, expected_applied, expected_t0)
    type(kernel_committed_state_t), intent(in) :: state
    real(real64), intent(in) :: expected_storage, expected_t0
    logical, intent(in) :: expected_applied
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    committed_snow_state = got .and. snapshot_snow_state(snapshot, expected_storage, expected_applied, expected_t0)
  end function committed_snow_state

  logical function candidate_snow_state(state, expected_storage, expected_applied, expected_t0)
    type(kernel_candidate_state_t), intent(in) :: state
    real(real64), intent(in) :: expected_storage, expected_t0
    logical, intent(in) :: expected_applied
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    candidate_snow_state = got .and. snapshot_snow_state(snapshot, expected_storage, expected_applied, expected_t0)
  end function candidate_snow_state

  logical function snapshot_snow_state(snapshot, expected_storage, expected_applied, expected_t0)
    class(transaction_state_t), allocatable, intent(in) :: snapshot
    real(real64), intent(in) :: expected_storage, expected_t0
    logical, intent(in) :: expected_applied
    snapshot_snow_state = .false.
    if (.not. allocated(snapshot)) return
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      if (.not. allocated(physical%snow)) return
      snapshot_snow_state = same_bits(physical%snow%process%snow_water_storage, expected_storage) .and. &
           same_bits(physical%snow%process%liquid_water_storage, 0.0_real64) .and. &
           (physical%snow%event_applied .eqv. expected_applied) .and. same_bits(physical%snow%event_t0, expected_t0)
    class default
      return
    end select
  end function snapshot_snow_state

  logical function mass_identical(a,b)
    type(kernel_result_t), intent(in) :: a,b
    mass_identical = a%mass%complete .eqv. b%mass%complete
    if (.not. mass_identical) return
    mass_identical = a%mass%missing_contribution_mask == b%mass%missing_contribution_mask .and. &
         a%mass%origin_lineage_id == b%mass%origin_lineage_id .and. &
         a%mass%origin_revision == b%mass%origin_revision .and. &
         a%mass%accepted_transaction_count == b%mass%accepted_transaction_count .and. &
         same_bits(a%mass%interval_t0,b%mass%interval_t0) .and. same_bits(a%mass%interval_t1,b%mass%interval_t1) .and. &
         same_bits(a%mass%storage_start,b%mass%storage_start) .and. same_bits(a%mass%storage_end,b%mass%storage_end) .and. &
         same_bits(a%mass%storage_change,b%mass%storage_change) .and. same_bits(a%mass%total_in,b%mass%total_in) .and. &
         same_bits(a%mass%total_out,b%mass%total_out) .and. same_bits(a%mass%residual,b%mass%residual)
  end function mass_identical

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia, ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR06_SNOW_SMOKE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmr06_snow_smoke

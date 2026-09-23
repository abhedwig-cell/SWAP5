program test_fapp09_external_surface_water_profile
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_fixed_weir_surface_water_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state, fmr_new_b110_fixed_weir_surface_water_committed_state
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_fmr_surface_water_head_forcing_adapter, only: fmr_surface_water_head_forcing_materializer_t, &
       FMR_SW_HEAD_FORCING_OK, FMR_SW_HEAD_FORCING_INVALID_REQUEST, FMR_SW_HEAD_FORCING_COMPETING_DRAINAGE_INPUT, &
       FMR_SW_HEAD_FORCING_NONFINITE_HEAD
  use mod_fmr_surface_water_swap_participant, only: fmr_surface_water_swap_participant_t, fmr_surface_water_trial_t, &
       fmr_surface_water_external_profile_admitted, FMR_SW_PARTICIPANT_OK, FMR_SW_PARTICIPANT_ORIGIN_DRIFT, &
       FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 1234.125_real64
  real(real64), parameter :: t1 = 1234.375_real64
  real(real64), parameter :: initial_head = -123.0_real64
  real(real64), parameter :: initial_gwl = -2.25_real64
  real(real64), parameter :: signed_rate = 1.0e-2_real64
  real(real64), parameter :: tol = 1.0e-10_real64
  integer(int64), parameter :: column_id = 909001_int64

  call verify_materializer_guards()
  call verify_owner_xor()
  call verify_positive_mismatch_replay_commit()
  call verify_negative_commit()
  call verify_stale_origin_fail_closed()

  write(*,'(A)') 'FAPP09_EXTERNAL_SURFACE_WATER_PROFILE=PASS'

contains

  subroutine verify_materializer_guards()
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: base, competing, materialized
    type(fmr_surface_water_head_forcing_materializer_t) :: m, m_bad
    real(real64) :: heads1(1), heads2(2)
    integer :: status

    call initialize_parameters(p)
    call initialize_base_forcing(base, signed_rate)
    call m%initialize(base, p, status)
    call require(status == FMR_SW_HEAD_FORCING_OK .and. m%ready(), 'materializer initializes admitted profile')
    call require(m%level_count() == 1, 'materializer level count')

    heads2 = [-12.25_real64, -10.0_real64]
    call m%materialize(heads2, materialized, status)
    call require(status == FMR_SW_HEAD_FORCING_INVALID_REQUEST, 'wrong head vector rejected')

    heads1(1) = ieee_value(0.0_real64, ieee_quiet_nan)
    call m%materialize(heads1, materialized, status)
    call require(status == FMR_SW_HEAD_FORCING_NONFINITE_HEAD, 'nonfinite head rejected')

    competing = base
    allocate(competing%drainage_response_controls(1))
    call m_bad%initialize(competing, p, status)
    call require(status == FMR_SW_HEAD_FORCING_COMPETING_DRAINAGE_INPUT .and. .not. m_bad%ready(), &
         'competing drainage control rejected')

    write(*,'(A)') 'FAPP09_TYPED_HEAD_MATERIALIZER_GUARDS=PASS'
  end subroutine verify_materializer_guards

  subroutine verify_owner_xor()
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: base
    type(fmr_surface_water_head_forcing_materializer_t) :: m
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template, fixed_template
    type(kernel_committed_state_t) :: committed, fixed_committed
    type(fmr_b110_physical_state_t) :: state
    type(fmr_b110_fixed_weir_surface_water_state_t) :: fixed_state
    integer :: status
    logical :: ok

    call initialize_parameters(p)
    call initialize_base_forcing(base, signed_rate)
    call initialize_column_template(column, template)
    call initialize_physical_state(p, state)
    call fmr_new_b110_committed_state(committed, column_id, state, t0, ok)
    call require(ok, 'base committed state')
    call m%initialize(base, p, status)
    call require(status == FMR_SW_HEAD_FORCING_OK, 'owner guard materializer')

    call require(fmr_surface_water_external_profile_admitted(template, p, committed, m), &
         'external owner profile admitted on base state')

    fixed_template = template
    fixed_template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
    call require(.not. fmr_surface_water_external_profile_admitted(fixed_template, p, committed, m), &
         'fixed-weir optional-state template rejected')

    fixed_state%active_nodes = state%active_nodes
    allocate(fixed_state%pressure_head(size(state%pressure_head)), fixed_state%water_content(size(state%water_content)))
    fixed_state%pressure_head = state%pressure_head
    fixed_state%water_content = state%water_content
    fixed_state%ponding_depth = state%ponding_depth
    fixed_state%groundwater_level = state%groundwater_level
    fixed_state%surface_water%storage = 1.0_real64
    call fmr_new_b110_fixed_weir_surface_water_committed_state(fixed_committed, column_id+1_int64, fixed_state, t0, ok)
    call require(ok, 'fixed-weir committed carrier initialized')
    call require(.not. fmr_surface_water_external_profile_admitted(template, p, fixed_committed, m), &
         'fixed-weir committed carrier rejected')

    write(*,'(A)') 'FAPP09_SURFACE_WATER_OWNER_XOR=PASS'
  end subroutine verify_owner_xor

  subroutine verify_positive_mismatch_replay_commit()
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: base
    type(fmr_surface_water_head_forcing_materializer_t) :: m
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: trial1, trial2
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(kernel_committed_state_t) :: committed
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    class(transaction_state_t), allocatable :: snapshot
    real(real64) :: heads(1), mismatch, committed_time
    integer :: status
    logical :: ok, did_commit, available

    call initialize_case(p, base, column, template, committed, config, signed_rate)
    call backend%initialize(top)
    call m%initialize(base, p, status)
    call require(status == FMR_SW_HEAD_FORCING_OK, 'positive materializer')
    call participant%capture_origin(committed, status)
    call require(status == FMR_SW_PARTICIPANT_OK .and. participant%has_origin(), 'positive capture origin')
    call require(participant%captured_revision() == 0_int64, 'positive origin revision')

    heads(1) = -12.25_real64
    call participant%trial_from_origin(backend, column, template, p, committed, m, config, t0, t1, heads, trial1, status)
    call require(status == FMR_SW_PARTICIPANT_OK .and. trial1%valid, 'positive first trial')
    call require(trial1%accepted_substeps == 1, 'positive one accepted substep')
    call require(abs(trial1%mean_signed_soil_to_surface_rate_cm_per_day-signed_rate) <= 1.0e-12_real64, &
         'positive mean exchange rate')
    call require(committed%current_revision() == 0_int64, 'positive trial nonmutating')

    mismatch = trial1%signed_soil_to_surface_exchange_cm + 1.0e-4_real64
    call require(.not. participant%publication_ready(committed, t0, t1, mismatch, tol), 'mismatch blocks preflight')
    call participant%commit_candidate(backend, committed, t0, t1, mismatch, tol, did_commit, status)
    call require(.not. did_commit .and. status == FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH, 'mismatch blocks commit')
    call require(committed%current_revision() == 0_int64, 'mismatch leaves revision unchanged')
    call participant%discard_candidate(backend)
    call require(participant%has_origin() .and. .not. participant%has_live_candidate(), 'discard retains accepted origin')

    call participant%trial_from_origin(backend, column, template, p, committed, m, config, t0, t1, heads, trial2, status)
    call require(status == FMR_SW_PARTICIPANT_OK .and. trial2%valid, 'positive replay trial')
    call require(abs(trial2%signed_soil_to_surface_exchange_cm-trial1%signed_soil_to_surface_exchange_cm) <= &
         64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(trial1%signed_soil_to_surface_exchange_cm)), &
         'same-origin exchange replay')
    call require(participant%publication_ready(committed, t0, t1, trial2%signed_soil_to_surface_exchange_cm, tol), &
         'matching realized transfer passes preflight')
    call participant%commit_candidate(backend, committed, t0, t1, trial2%signed_soil_to_surface_exchange_cm, tol, &
         did_commit, status)
    call require(did_commit .and. status == FMR_SW_PARTICIPANT_OK, 'positive commit')
    call require(committed%current_revision() == 1_int64, 'positive single revision advance')
    call committed%current_time(committed_time, available)
    call require(available .and. abs(committed_time-t1) <= 64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(t1)), &
         'positive committed time')
    call committed%snapshot(snapshot, available)
    call require(available .and. allocated(snapshot), 'positive committed snapshot')
    select type (s => snapshot)
    type is (fmr_b110_physical_state_t)
      call require(.not. allocated(s%snow) .and. .not. allocated(s%soil_temperature), 'no optional surface-water state')
    class default
      call require(.false., 'committed carrier remains base physical state')
    end select
    call require(.not. participant%has_origin() .and. .not. participant%has_live_candidate(), 'positive participant clears after commit')

    write(*,'(A)') 'FAPP09_MISMATCH_RECOMPOSE_SAME_ORIGIN=PASS'
    write(*,'(A)') 'FAPP09_POSITIVE_DRAINAGE_KERNEL_COMMIT=PASS'
    write(*,'(A)') 'FAPP09_NO_PERSISTENT_SURFACE_WATER_STATE=PASS'
  end subroutine verify_positive_mismatch_replay_commit

  subroutine verify_negative_commit()
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: base
    type(fmr_surface_water_head_forcing_materializer_t) :: m
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: trial
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(kernel_committed_state_t) :: committed
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: heads(1)
    integer :: status
    logical :: did_commit

    call initialize_case(p, base, column, template, committed, config, -signed_rate)
    call backend%initialize(top)
    call m%initialize(base, p, status)
    call require(status == FMR_SW_HEAD_FORCING_OK, 'negative materializer')
    call participant%capture_origin(committed, status)
    call require(status == FMR_SW_PARTICIPANT_OK, 'negative capture')
    heads(1) = 7.75_real64
    call participant%trial_from_origin(backend, column, template, p, committed, m, config, t0, t1, heads, trial, status)
    call require(status == FMR_SW_PARTICIPANT_OK .and. trial%valid, 'negative trial')
    call require(abs(trial%mean_signed_soil_to_surface_rate_cm_per_day+signed_rate) <= 1.0e-12_real64, &
         'negative mean infiltration rate')
    call participant%commit_candidate(backend, committed, t0, t1, trial%signed_soil_to_surface_exchange_cm, tol, &
         did_commit, status)
    call require(did_commit .and. status == FMR_SW_PARTICIPANT_OK, 'negative commit')
    call require(committed%current_revision() == 1_int64, 'negative single revision advance')

    write(*,'(A)') 'FAPP09_NEGATIVE_INFILTRATION_KERNEL_COMMIT=PASS'
  end subroutine verify_negative_commit

  subroutine verify_stale_origin_fail_closed()
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: base
    type(fmr_surface_water_head_forcing_materializer_t) :: m
    type(fmr_surface_water_swap_participant_t) :: stale, winner
    type(fmr_surface_water_trial_t) :: trial
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(kernel_committed_state_t) :: committed
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: heads(1)
    integer :: status
    logical :: did_commit

    call initialize_case(p, base, column, template, committed, config, signed_rate)
    call backend%initialize(top)
    call m%initialize(base, p, status)
    call require(status == FMR_SW_HEAD_FORCING_OK, 'stale materializer')
    call stale%capture_origin(committed, status)
    call require(status == FMR_SW_PARTICIPANT_OK, 'stale participant capture')
    call winner%capture_origin(committed, status)
    call require(status == FMR_SW_PARTICIPANT_OK, 'winner capture')
    heads(1) = -12.25_real64
    call winner%trial_from_origin(backend, column, template, p, committed, m, config, t0, t1, heads, trial, status)
    call require(status == FMR_SW_PARTICIPANT_OK .and. trial%valid, 'winner trial')
    call winner%commit_candidate(backend, committed, t0, t1, trial%signed_soil_to_surface_exchange_cm, tol, did_commit, status)
    call require(did_commit .and. status == FMR_SW_PARTICIPANT_OK, 'winner commit')
    call stale%trial_from_origin(backend, column, template, p, committed, m, config, t0, t1, heads, trial, status)
    call require(status == FMR_SW_PARTICIPANT_ORIGIN_DRIFT .and. .not. trial%valid, 'stale origin rejected')
    call require(committed%current_revision() == 1_int64, 'stale rejection nonmutating')

    write(*,'(A)') 'FAPP09_STALE_ORIGIN_FAIL_CLOSED=PASS'
  end subroutine verify_stale_origin_fail_closed

  subroutine initialize_case(p, base, column, template, committed, config, balancing_qssdi)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_forcing_t), intent(out) :: base
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(kernel_committed_state_t), intent(out) :: committed
    type(canonical_numerical_config_t), intent(out) :: config
    real(real64), intent(in) :: balancing_qssdi
    type(fmr_b110_physical_state_t) :: state
    logical :: ok

    call initialize_parameters(p)
    call initialize_base_forcing(base, balancing_qssdi)
    call initialize_column_template(column, template)
    call initialize_config(config)
    call initialize_physical_state(p, state)
    call fmr_new_b110_committed_state(committed, column_id, state, t0, ok)
    call require(ok, 'initialize base committed state')
  end subroutine initialize_case

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 909001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
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
    p%black_evaporation_active = .false.
    p%boesten_evaporation_active = .false.
    p%drainage_response_active = .true.
    p%drainage_qbot_smooth_freatic_projection = .false.
    allocate(p%drainage_response_levels(1))
    p%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_EXTENDED_SIGNED
    p%drainage_response_levels(1)%extended%zbotdr_cm = -100.0_real64
    p%drainage_response_levels(1)%extended%drain_type = EXT_DRAIN_TUBE
    p%drainage_response_levels(1)%extended%spacing_cm = 1000.0_real64
    p%drainage_response_levels(1)%extended%rdrain_day = 1000.0_real64
    p%drainage_response_levels(1)%extended%rinfi_day = 1000.0_real64
    p%drainage_response_levels(1)%extended%rentry_day = 0.0_real64
    p%drainage_response_levels(1)%extended%rexit_day = 0.0_real64
    p%drainage_response_levels(1)%extended%gwlinf_cm = -200.0_real64
    p%drainage_response_levels(1)%extended%pondmx_cm = 1000.0_real64
    p%drainage_response_levels(1)%extended%highest_level = .false.
    p%drainage_response_levels(1)%extended%highest_surface_mode = EXT_DRAIN_TOP_NONE
  end subroutine initialize_parameters

  subroutine initialize_base_forcing(f, balancing_qssdi)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: balancing_qssdi
    f%top_flux = 0.0_real64
    f%top_head = initial_head
    f%bottom_flux = 0.0_real64
    f%bottom_head = -321.0_real64
    allocate(f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%subsurface_irrigation_source = 0.0_real64
    f%subsurface_irrigation_source(numnod) = balancing_qssdi
    f%root_extraction_sink = 0.0_real64
  end subroutine initialize_base_forcing

  subroutine initialize_column_template(c, t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id = 909001_int64
    t%physics_topology_id = 909002_int64
    t%vertical_layout_id = 909003_int64
    t%state_layout_id = 909004_int64
    t%solver_interface_id = 909005_int64
    t%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    t%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = column_id
    c%template_id = t%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance = 1.0e3_real64
    c%transaction%mass_tolerance = tol
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 2
    c%max_committed_substeps = 8
    c%progress_tolerance = 0.0_real64
  end subroutine initialize_config

  subroutine initialize_physical_state(p, state)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    heads = initial_head
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, t1-t0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = initial_gwl
  end subroutine initialize_physical_state

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FAPP09_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fapp09_external_surface_water_profile

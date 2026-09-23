program test_sw_rib_pa01_profile_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64\n  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE, &\n       FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_execute_serialized_resolved_physical_column
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &\n       fmr_drainage_response_level_control_t, FMR_DRAIN_VARIANT_LINEAR, FMR_DRAIN_VARIANT_EXTENDED_SIGNED, FMR_DRAIN_BIND_OK\n  use mod_ribasim_surface_water_profile_contract, only: RIBASIM_SW_PROFILE_OK, RIBASIM_SW_PROFILE_OWNER_CONFLICT, &\n       RIBASIM_SW_PROFILE_DUPLICATE_CONTROL, RIBASIM_SW_PROFILE_UNSUPPORTED_VARIANT, &\n       RIBASIM_SW_PROFILE_INVALID_ACCEPTED_HEAD, RIBASIM_SW_STTAB_EPSILON_M, RIBASIM_SW_GIT_SHA, &\n       RIBASIM_SW_CORE_VERSION, RIBASIM_SW_PYTHON_VERSION_AT_PIN, ribasim_surface_water_profile_status, &\n       bind_ribasim_surface_water_controls
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 9123.125_real64
  real(real64), parameter :: t1 = 9123.375_real64
  real(real64), parameter :: initial_head = -123.0_real64
  real(real64), parameter :: initial_gwl = -2.25_real64
  real(real64), parameter :: signed_rate = 1.0e-2_real64
  real(real64), parameter :: mass_gate = 1.0e-10_real64
  integer(int64), parameter :: column_id = 44001_int64

  call verify_profile_contract()\n  call verify_signed_commit(-12.25_real64, signed_rate, .true.)
  call verify_signed_commit(7.75_real64, -signed_rate, .false.)
  call verify_invalid_process_rolls_back()
  write(*,'(A)') 'SW_RIB_SWM01_Q4B_TRANSACTIONAL_RUNTIME=PASS'\n  write(*,'(A)') 'SW_RIB_PA01_CANDIDATE_RUNTIME=PASS'

contains

  subroutine verify_signed_commit(control_head, balancing_qssdi, positive)
    real(real64), intent(in) :: control_head, balancing_qssdi
    logical, intent(in) :: positive
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: expected_amount, background_amount, response_rate
    integer :: active_calls

    call initialize_case(committed, column, template, parameters, forcing, config, control_head, balancing_qssdi)
    expected_amount = signed_rate * (t1-t0)
    background_amount = max(0.0_real64, -forcing%top_flux) * (t1-t0)

    call backend%initialize(top)
    call reset_runtime_outputs(output, diagnostic, runtime, active_calls)
    call fmr_execute_serialized_resolved_physical_column(backend, tx_control, column, template, parameters, forcing, &
         committed, config, t0, t1, output, diagnostic, runtime, active_calls)
    observation = backend%observation()

    call require(output%completed .and. output%committed, 'signed extended response committed')
    call require(output%final_revision == 1_int64 .and. committed%current_revision() == 1_int64, &
         'signed extended response single commit revision')
    call require(output%mass%complete .and. output%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
         'signed extended response mass complete')
    call require(abs(output%mass%residual) <= mass_gate, 'signed extended response hard mass closure')
    call require(output%accepted_substeps == 1, 'signed extended response one accepted transaction')
    call require(observation%drainage_response_active, 'signed extended response observation active')
    call require(observation%drainage_response%status == FMR_DRAIN_BIND_OK, 'signed extended response diagnostics')
    call require(size(observation%drainage_response%level) == 1, 'signed extended response one level')
    call require(observation%drainage_response%level(1)%variant == FMR_DRAIN_VARIANT_EXTENDED_SIGNED, &
         'signed extended response variant identity')
    response_rate = observation%drainage_response%level(1)%signed_soil_to_drain_rate
    if (positive) then
      call require(abs(response_rate-signed_rate) <= 1.0e-12_real64, 'positive extended response rate')
      call require(abs((output%mass%total_out-background_amount)-expected_amount) <= mass_gate, &
           'positive extended drainage booked once as external out')
      call require(abs((output%mass%total_in-background_amount)-expected_amount) <= mass_gate, &
           'positive balancing qssdi booked once as external in')
      write(*,'(A)') 'SW_RIB_SWM01_Q4B_POSITIVE_DRAINAGE_SINGLE_BOOKING=PASS'
    else
      call require(abs(response_rate+signed_rate) <= 1.0e-12_real64, 'negative extended response rate')
      call require(abs((output%mass%total_in-background_amount)-expected_amount) <= mass_gate, &
           'negative extended infiltration booked once as external in')
      call require(abs((output%mass%total_out-background_amount)-expected_amount) <= mass_gate, &
           'negative balancing qssdi booked once as external out')
      write(*,'(A)') 'SW_RIB_SWM01_Q4B_NEGATIVE_INFILTRATION_SINGLE_BOOKING=PASS'
    end if
    call require(.not. observation%drainage_response%transfer_booked_here, 'response binding does not book mass')
    call require(observation%drainage_response_mass_accounted_in_trial, 'existing trial ledger owns signed transfer')
    call require(active_calls == 0, 'physical call counter restored')
    write(*,'(A)') 'SW_RIB_SWM01_Q4B_SIGNED_HARD_MASS_CLOSURE=PASS'
  end subroutine verify_signed_commit

  subroutine verify_invalid_process_rolls_back()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: gwl_after
    integer :: active_calls

    call initialize_case(committed, column, template, parameters, forcing, config, -12.25_real64, signed_rate)
    parameters%drainage_response_levels(1)%extended%rdrain_day = 0.0_real64

    call backend%initialize(top)
    call reset_runtime_outputs(output, diagnostic, runtime, active_calls)
    call fmr_execute_serialized_resolved_physical_column(backend, tx_control, column, template, parameters, forcing, &
         committed, config, t0, t1, output, diagnostic, runtime, active_calls)

    call require(.not. output%committed, 'invalid extended process unexpectedly committed')
    call require(committed%current_revision() == 0_int64, 'invalid extended process mutated revision')
    call snapshot_groundwater_level(committed, gwl_after)
    call require(same_bits(gwl_after, initial_gwl), 'invalid extended process mutated committed state')
    call require(diagnostic%rejected == 1, 'invalid extended process missing rejection diagnostic')
    call require(active_calls == 0, 'invalid extended process call counter restored')
    write(*,'(A)') 'SW_RIB_SWM01_Q4B_INVALID_PROCESS_ROLLBACK=PASS'
  end subroutine verify_invalid_process_rolls_back

  subroutine initialize_case(committed, column, template, parameters, forcing, config, control_head, balancing_qssdi)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    real(real64), intent(in) :: control_head, balancing_qssdi
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod), k0
    logical :: ok
    integer :: k

    parameters%parameter_set_id = 44001_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode = 7
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%drainage_response_active = .true.
    allocate(parameters%drainage_response_levels(1))
    parameters%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_EXTENDED_SIGNED
    parameters%drainage_response_levels(1)%extended%zbotdr_cm = -100.0_real64
    parameters%drainage_response_levels(1)%extended%drain_type = EXT_DRAIN_TUBE
    parameters%drainage_response_levels(1)%extended%spacing_cm = 1000.0_real64
    parameters%drainage_response_levels(1)%extended%rdrain_day = 1000.0_real64
    parameters%drainage_response_levels(1)%extended%rinfi_day = 1000.0_real64
    parameters%drainage_response_levels(1)%extended%rentry_day = 0.0_real64
    parameters%drainage_response_levels(1)%extended%rexit_day = 0.0_real64
    parameters%drainage_response_levels(1)%extended%gwlinf_cm = -200.0_real64
    parameters%drainage_response_levels(1)%extended%pondmx_cm = 1000.0_real64
    parameters%drainage_response_levels(1)%extended%highest_level = .false.
    parameters%drainage_response_levels(1)%extended%highest_surface_mode = EXT_DRAIN_TOP_NONE

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, t1-t0)
    heads = initial_head
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = initial_gwl
    call fmr_new_b110_committed_state(committed, column_id, state, t0, ok)
    call require(ok, 'committed state initialization')

    template%template_id = 4401_int64
    template%physics_topology_id = 44011_int64
    template%vertical_layout_id = 44012_int64
    template%state_layout_id = 44013_int64
    template%solver_interface_id = 44014_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    forcing%top_flux = -k0
    forcing%top_head = initial_head
    forcing%bottom_flux = -k0
    forcing%bottom_head = -321.0_real64
    allocate(forcing%subsurface_irrigation_source(numnod), forcing%root_extraction_sink(numnod))
    call bind_ribasim_surface_water_controls(template%optional_state_layout_id, parameters%drainage_response_levels, &
         [control_head], allocated(forcing%drainage_response_controls), forcing%drainage_response_controls, profile_status)
    call require(profile_status == RIBASIM_SW_PROFILE_OK, 'Ribasim profile accepted-head binding')
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%subsurface_irrigation_source(numnod) = balancing_qssdi
    forcing%root_extraction_sink = 0.0_real64

    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e3_real64
    config%transaction%mass_tolerance = mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine initialize_case

  subroutine reset_runtime_outputs(output, diagnostic, runtime, active_calls)
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_column_diagnostics_t), intent(out) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer, intent(out) :: active_calls
    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = t0
    output%requested_t1 = t1
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_calls = 0
  end subroutine reset_runtime_outputs

  subroutine snapshot_groundwater_level(committed, gwl)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), intent(out) :: gwl
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call committed%snapshot(snapshot, available)
    call require(available, 'committed snapshot available')
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      gwl = physical%groundwater_level
    class default
      error stop 'Q4B unexpected committed state type'
    end select
  end subroutine snapshot_groundwater_level

  pure logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'SW_RIB_SWM01_Q4B_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_sw_rib_pa01_profile_runtime

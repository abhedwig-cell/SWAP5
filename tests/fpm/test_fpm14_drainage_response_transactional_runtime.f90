program test_fpm14_drainage_response_transactional_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_execute_serialized_resolved_physical_column
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_LINEAR, FMR_DRAIN_BIND_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 9123.125_real64
  real(real64), parameter :: t1 = 9123.375_real64
  real(real64), parameter :: initial_head = -123.0_real64
  real(real64), parameter :: initial_gwl = -2.25_real64
  real(real64), parameter :: drain_head = -3.25_real64
  real(real64), parameter :: resistance = 100.0_real64
  real(real64), parameter :: mass_gate = 1.0e-10_real64
  integer(int64), parameter :: column_id = 14001_int64

  call verify_active_response_commits_once()
  call verify_unsupported_response_rolls_back()
  write(*,'(A)') 'FPM14_DRAINAGE_RESPONSE_TRANSACTIONAL_RUNTIME_OWNER_TEST PASS'

contains

  subroutine verify_active_response_commits_once()
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
    integer :: active_calls
    real(real64) :: expected_q, expected_amount, net_external

    call initialize_case(committed, column, template, parameters, forcing, config)
    expected_q = (initial_gwl - drain_head) / resistance
    expected_amount = expected_q * (t1 - t0)

    call backend%initialize(top)
    call reset_runtime_outputs(output, diagnostic, runtime, active_calls)
    call fmr_execute_serialized_resolved_physical_column(backend, tx_control, column, template, parameters, forcing, &
         committed, config, t0, t1, output, diagnostic, runtime, active_calls)
    observation = backend%observation()

    call require(output%completed .and. output%committed, 'active response committed')
    call require(output%final_revision == 1_int64 .and. committed%current_revision() == 1_int64, 'single commit revision')
    call require(output%mass%complete .and. output%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
         'active response mass complete')
    call require(abs(output%mass%residual) <= mass_gate, 'active response hard mass closure')
    call require(output%accepted_substeps == 1, 'large temporal tolerance accepted full candidate')
    net_external = output%mass%total_out - output%mass%total_in
    call require(abs(net_external - expected_amount) <= mass_gate, 'drainage booked exactly once in accepted full candidate')
    call require(observation%drainage_response_active, 'drainage response observation active')
    call require(observation%drainage_response_evaluations >= 1, 'drainage evaluated in transactional advance')
    call require(observation%drainage_response%status == FMR_DRAIN_BIND_OK, 'drainage response diagnostics available')
    call require(.not. observation%drainage_response%transfer_booked_here, 'response binding itself does not book mass')
    call require(observation%drainage_response_mass_accounted_in_trial, 'existing trial ledger owns response transfer')
    call require(active_calls == 0, 'physical call counter restored')
    write(*,'(A)') 'FPM14_ACTIVE_RESPONSE_SINGLE_ACCEPTED_BOOKING=PASS'
    write(*,'(A)') 'FPM14_ACTIVE_RESPONSE_HARD_MASS_CLOSURE=PASS'
  end subroutine verify_active_response_commits_once

  subroutine verify_unsupported_response_rolls_back()
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
    integer :: active_calls
    real(real64) :: gwl_after

    call initialize_case(committed, column, template, parameters, forcing, config)
    parameters%drainage_response_levels(1)%variant = 999
    call backend%initialize(top)
    call reset_runtime_outputs(output, diagnostic, runtime, active_calls)
    call fmr_execute_serialized_resolved_physical_column(backend, tx_control, column, template, parameters, forcing, &
         committed, config, t0, t1, output, diagnostic, runtime, active_calls)

    call require(.not. output%committed, 'unsupported response unexpectedly committed')
    call require(committed%current_revision() == 0_int64, 'unsupported response mutated revision')
    call snapshot_groundwater_level(committed, gwl_after)
    call require(same_bits(gwl_after, initial_gwl), 'unsupported response mutated committed physical state')
    call require(diagnostic%rejected == 1, 'unsupported response missing rejection diagnostic')
    call require(active_calls == 0, 'unsupported response physical call counter restored')
    write(*,'(A)') 'FPM14_UNSUPPORTED_RESPONSE_TRANSACTION_ROLLBACK=PASS'
  end subroutine verify_unsupported_response_rolls_back

  subroutine initialize_case(committed, column, template, parameters, forcing, config)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod), k0
    logical :: ok
    integer :: k

    parameters%parameter_set_id = 14001_int64
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
    parameters%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_LINEAR
    parameters%drainage_response_levels(1)%linear%drainage_resistance = resistance

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

    template%template_id = 1401_int64
    template%physics_topology_id = 14011_int64
    template%vertical_layout_id = 14012_int64
    template%state_layout_id = 14013_int64
    template%solver_interface_id = 14014_int64
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
    allocate(forcing%drainage_response_controls(1), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_response_controls(1)%drain_head_supplied = .true.
    forcing%drainage_response_controls(1)%drain_head = drain_head
    forcing%subsurface_irrigation_source = 0.0_real64
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
      error stop 'F-PM14 unexpected committed state type'
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
      write(*,'(A,1X,A)') 'FPM14_TRANSACTIONAL_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpm14_drainage_response_transactional_runtime

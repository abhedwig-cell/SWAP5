program test_fvq73_fpm14_drainage_response_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_execute_serialized_resolved_physical_column
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, fmr_drainage_response_diagnostics_t, &
       evaluate_fmr_drainage_response_bottom_lumped, FMR_DRAIN_VARIANT_TABULATED, &
       FMR_DRAIN_BIND_OK, FMR_DRAIN_BIND_UNSUPPORTED_VARIANT
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 287.375_real64
  real(real64), parameter :: t1 = 287.9375_real64
  real(real64), parameter :: initial_head = -117.0_real64
  real(real64), parameter :: initial_gwl = -2.5_real64
  real(real64), parameter :: level1_rate = 6.0e-3_real64
  real(real64), parameter :: level2_rate = 4.0e-3_real64
  real(real64), parameter :: total_rate = level1_rate + level2_rate
  real(real64), parameter :: mass_gate = 1.0e-10_real64
  real(real64), parameter :: value_gate = 2.0e-13_real64
  integer(int64), parameter :: column_id = 73001_int64

  call verify_two_level_binding_and_tangent()
  call verify_two_level_runtime_single_booking()
  call verify_invalid_second_level_is_atomic()
  write(*,'(A)') 'FVQ73_FPM14_DRAINAGE_RESPONSE_INDEPENDENT_RUNTIME=PASS'

contains

  subroutine verify_two_level_binding_and_tangent()
    type(process_hydraulic_view_t) :: view
    type(fmr_drainage_response_level_parameters_t), allocatable :: p(:)
    type(fmr_drainage_response_level_control_t), allocatable :: c(:)
    type(fmr_drainage_response_diagnostics_t) :: d
    real(real64), allocatable :: qdra(:,:)

    view%active_nodes = 3
    allocate(view%pressure_head(3), view%water_content(3))
    view%pressure_head = [-20.0_real64, -10.0_real64, -2.0_real64]
    view%water_content = [0.22_real64, 0.28_real64, 0.34_real64]
    view%ponding_depth = 0.0_real64
    view%groundwater_level = -2.5_real64

    allocate(p(2), c(2), qdra(2,3))
    p(1)%variant = FMR_DRAIN_VARIANT_TABULATED
    allocate(p(1)%tabulated%groundwater_depth(2), p(1)%tabulated%signed_exchange_rate(2))
    p(1)%tabulated%groundwater_depth = [1.0_real64, 4.0_real64]
    p(1)%tabulated%signed_exchange_rate = [4.0e-3_real64, 1.0e-2_real64]

    p(2)%variant = FMR_DRAIN_VARIANT_TABULATED
    allocate(p(2)%tabulated%groundwater_depth(2), p(2)%tabulated%signed_exchange_rate(2))
    p(2)%tabulated%groundwater_depth = [1.0_real64, 4.0_real64]
    p(2)%tabulated%signed_exchange_rate = [-2.0e-3_real64, 4.0e-3_real64]

    call evaluate_fmr_drainage_response_bottom_lumped(p, c, view, qdra, d)
    call require(d%status == FMR_DRAIN_BIND_OK .and. d%evaluated, 'two-level binding did not evaluate')
    call require(size(d%level) == 2, 'two-level diagnostics shape')
    call require(all(qdra(:,1:2) == 0.0_real64), 'non-bottom nodes received drainage')
    call require(close(qdra(1,3), 7.0e-3_real64), 'level 1 interpolation')
    call require(close(qdra(2,3), 1.0e-3_real64), 'level 2 interpolation')
    call require(close(d%level(1)%signed_soil_to_drain_rate, 7.0e-3_real64), 'level 1 diagnostic flux')
    call require(close(d%level(2)%signed_soil_to_drain_rate, 1.0e-3_real64), 'level 2 diagnostic flux')
    call require(d%level(1)%derivative_defined .and. d%level(2)%derivative_defined, 'per-level tangent unavailable')
    call require(close(d%level(1)%dq_dgroundwater_level, -2.0e-3_real64), 'level 1 tangent')
    call require(close(d%level(2)%dq_dgroundwater_level, -2.0e-3_real64), 'level 2 tangent')
    call require(close(d%aggregate%signed_soil_to_drain_rate, 8.0e-3_real64), 'aggregate rate')
    call require(d%aggregate%derivative_defined, 'aggregate tangent unavailable')
    call require(close(d%aggregate%dq_dgroundwater_level, -4.0e-3_real64), 'aggregate tangent sum')
    call require(d%aggregate_is_derived_view_only, 'aggregate is not declared derived-only')
    call require(d%aggregate_diagnostics%total_is_derived_view_not_additional_transfer, 'aggregate accounting contract')
    call require(.not. d%transfer_booked_here, 'binding booked transfer directly')
    call require(.not. d%persistent_process_state, 'binding claims persistent process state')
    write(*,'(A)') 'FVQ73_TWO_LEVEL_BINDING_SEPARATION_AND_TANGENT=PASS'
    write(*,'(A)') 'FVQ73_AGGREGATE_DERIVED_VIEW_NOT_TRANSFER=PASS'
  end subroutine verify_two_level_binding_and_tangent

  subroutine verify_two_level_runtime_single_booking()
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
    type(fmr_serialized_physical_observation_t) :: obs
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_calls
    real(real64) :: expected_amount, background_amount

    call initialize_runtime_case(committed, column, template, parameters, forcing, config)
    expected_amount = total_rate * (t1-t0)
    background_amount = max(0.0_real64, -forcing%top_flux) * (t1-t0)
    call backend%initialize(top)
    call reset_runtime_outputs(output, diagnostic, runtime, active_calls)
    call fmr_execute_serialized_resolved_physical_column(backend, tx_control, column, template, parameters, forcing, &
         committed, config, t0, t1, output, diagnostic, runtime, active_calls)
    obs = backend%observation()

    call require(output%completed .and. output%committed, 'two-level runtime did not commit')
    call require(output%final_revision == 1_int64 .and. committed%current_revision() == 1_int64, 'runtime commit count')
    call require(output%accepted_substeps == 1, 'accepted transaction count')
    call require(output%mass%complete .and. output%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'mass completeness')
    call require(abs(output%mass%residual) <= mass_gate, 'hard mass closure')
    call require(abs((output%mass%total_out-background_amount)-expected_amount) <= mass_gate, 'drainage external-out amount')
    call require(abs((output%mass%total_in-background_amount)-expected_amount) <= mass_gate, 'balancing source external-in amount')
    call require(obs%drainage_response_active, 'runtime response inactive')
    call require(obs%drainage_response_evaluations == 3, 'response evaluation count')
    call require(obs%drainage_response%status == FMR_DRAIN_BIND_OK, 'runtime response status')
    call require(size(obs%drainage_response%level) == 2, 'runtime two-level diagnostics shape')
    call require(close(obs%drainage_response%level(1)%signed_soil_to_drain_rate, level1_rate), 'runtime level 1 rate')
    call require(close(obs%drainage_response%level(2)%signed_soil_to_drain_rate, level2_rate), 'runtime level 2 rate')
    call require(close(obs%drainage_response%aggregate%signed_soil_to_drain_rate, total_rate), 'runtime aggregate rate')
    call require(close(obs%drainage_response_signed_exchange_native, total_rate), 'native aggregate transfer')
    call require(obs%drainage_response%aggregate_is_derived_view_only, 'runtime aggregate derived-only flag')
    call require(.not. obs%drainage_response%transfer_booked_here, 'runtime binding double-booked transfer')
    call require(obs%drainage_response_mass_accounted_in_trial, 'authoritative trial ledger did not own transfer')
    call require(active_calls == 0, 'runtime physical call counter not restored')
    write(*,'(A)') 'FVQ73_TWO_LEVEL_RUNTIME_HARD_MASS_AND_SINGLE_BOOKING=PASS'
    write(*,'(A)') 'FVQ73_GENERIC_NONCALENDAR_INTERVAL=PASS'
  end subroutine verify_two_level_runtime_single_booking

  subroutine verify_invalid_second_level_is_atomic()
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
    type(fmr_b110_physical_state_t) :: before_state, after_state
    integer :: active_calls

    call initialize_runtime_case(committed, column, template, parameters, forcing, config)
    parameters%drainage_response_levels(2)%variant = 999
    call snapshot_state(committed, before_state)
    call backend%initialize(top)
    call reset_runtime_outputs(output, diagnostic, runtime, active_calls)
    call fmr_execute_serialized_resolved_physical_column(backend, tx_control, column, template, parameters, forcing, &
         committed, config, t0, t1, output, diagnostic, runtime, active_calls)
    call snapshot_state(committed, after_state)

    call require(.not. output%committed, 'invalid second level committed')
    call require(committed%current_revision() == 0_int64, 'invalid second level mutated revision')
    call require(diagnostic%rejected == 1, 'invalid second level not rejected')
    call require(states_bit_identical(before_state, after_state), 'invalid second level mutated committed physical state')
    call require(active_calls == 0, 'invalid-route physical call counter not restored')
    call require(parameters%drainage_response_levels(2)%variant == 999, 'configuration unexpectedly repaired by runtime')
    call require(FMR_DRAIN_BIND_UNSUPPORTED_VARIANT /= FMR_DRAIN_BIND_OK, 'unsupported status constant aliases OK')
    write(*,'(A)') 'FVQ73_INVALID_SECOND_LEVEL_FAIL_CLOSED_ATOMIC=PASS'
  end subroutine verify_invalid_second_level_is_atomic

  subroutine initialize_runtime_case(committed, column, template, parameters, forcing, config)
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

    parameters%parameter_set_id = 73001_int64
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
    allocate(parameters%drainage_response_levels(2))
    parameters%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_TABULATED
    parameters%drainage_response_levels(2)%variant = FMR_DRAIN_VARIANT_TABULATED
    allocate(parameters%drainage_response_levels(1)%tabulated%groundwater_depth(1), &
         parameters%drainage_response_levels(1)%tabulated%signed_exchange_rate(1), &
         parameters%drainage_response_levels(2)%tabulated%groundwater_depth(1), &
         parameters%drainage_response_levels(2)%tabulated%signed_exchange_rate(1))
    parameters%drainage_response_levels(1)%tabulated%groundwater_depth = [20.0_real64]
    parameters%drainage_response_levels(1)%tabulated%signed_exchange_rate = [level1_rate]
    parameters%drainage_response_levels(2)%tabulated%groundwater_depth = [20.0_real64]
    parameters%drainage_response_levels(2)%tabulated%signed_exchange_rate = [level2_rate]

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

    template%template_id = 7301_int64
    template%physics_topology_id = 73011_int64
    template%vertical_layout_id = 73012_int64
    template%state_layout_id = 73013_int64
    template%solver_interface_id = 73014_int64
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
    allocate(forcing%drainage_response_controls(2), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%subsurface_irrigation_source(numnod) = total_rate
    forcing%root_extraction_sink = 0.0_real64

    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e3_real64
    config%transaction%mass_tolerance = mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine initialize_runtime_case

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

  subroutine snapshot_state(committed, state)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call committed%snapshot(snapshot, available)
    call require(available, 'committed snapshot unavailable')
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      state = physical
    class default
      error stop 'FVQ73 unexpected committed state type'
    end select
  end subroutine snapshot_state

  logical function states_bit_identical(a, b) result(same)
    type(fmr_b110_physical_state_t), intent(in) :: a, b
    same = a%active_nodes == b%active_nodes
    same = same .and. allocated(a%pressure_head) .eqv. allocated(b%pressure_head)
    same = same .and. allocated(a%water_content) .eqv. allocated(b%water_content)
    if (.not. same) return
    if (allocated(a%pressure_head)) then
      same = same .and. size(a%pressure_head) == size(b%pressure_head)
      if (.not. same) return
      same = same .and. all(same_real_bits(a%pressure_head, b%pressure_head))
    end if
    if (allocated(a%water_content)) then
      same = same .and. size(a%water_content) == size(b%water_content)
      if (.not. same) return
      same = same .and. all(same_real_bits(a%water_content, b%water_content))
    end if
    same = same .and. same_real_bits(a%ponding_depth, b%ponding_depth)
    same = same .and. same_real_bits(a%groundwater_level, b%groundwater_level)
    same = same .and. (allocated(a%snow) .eqv. allocated(b%snow))
    same = same .and. (allocated(a%soil_temperature) .eqv. allocated(b%soil_temperature))
  end function states_bit_identical

  pure elemental logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

  pure logical function close(a, b) result(ok)
    real(real64), intent(in) :: a, b
    ok = abs(a-b) <= value_gate
  end function close

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ73_INDEPENDENT_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq73_fpm14_drainage_response_independent

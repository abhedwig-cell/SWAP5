program test_fvq74_drainage_crosscutting_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, fmr_execute_serialized_resolved_physical_column, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_TABULATED
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 742.1875_real64
  real(real64), parameter :: t1 = 742.53125_real64
  real(real64), parameter :: t2 = 742.875_real64
  real(real64), parameter :: initial_head = -137.0_real64
  real(real64), parameter :: initial_gwl = -2.875_real64
  real(real64), parameter :: mass_gate = 1.0e-10_real64
  integer, parameter :: ncol = 4
  real(real64), parameter :: rates(ncol) = [7.5e-3_real64, 1.25e-2_real64, 1.75e-2_real64, 2.25e-2_real64]
  logical, parameter :: response_active(ncol) = [.true., .false., .true., .false.]

  call verify_fresh_multiswap_permutation_isolation()
  call verify_fresh_restart_continuation()
  call verify_reject_diagnostics_are_fail_closed()
  write(*,'(A)') 'FVQ74_DRAINAGE_CROSSCUTTING_INDEPENDENT=PASS'

contains

  subroutine verify_fresh_multiswap_permutation_isolation()
    type(fmr_logical_column_t) :: columns_a(ncol), columns_b(ncol)
    type(fmr_template_t) :: templates(ncol)
    type(fmr_b110_physical_parameters_t) :: parameters(ncol)
    type(fmr_b110_physical_forcing_t) :: forcings(ncol)
    type(kernel_committed_state_t) :: states_a(ncol), states_b(ncol)
    type(fmr_serialized_column_result_t), allocatable :: results_a(:), results_b(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics_a(:), diagnostics_b(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate_a, aggregate_b
    type(fmr_serialized_batch_diagnostics_t) :: runtime_a, runtime_b
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(canonical_numerical_config_t) :: config
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: conductivity0, background_amount, expected_exchange
    integer :: i, status_a, status_b

    call configure_base(initial_state, conductivity0, config)
    background_amount = conductivity0 * (t1 - t0)
    call configure_templates(templates)

    do i = 1, ncol
      call configure_parameters(parameters(i), i, rates(i), response_active(i))
      call configure_forcing(forcings(i), rates(i), response_active(i), conductivity0)
      call initialize_column_state(states_a(i), 174000_int64 + int(i,int64), initial_state, t0)
      call initialize_column_state(states_b(i), 174000_int64 + int(i,int64), initial_state, t0)

      columns_a(i)%column_id = 174000_int64 + int(i,int64)
      columns_a(i)%template_id = templates(i)%template_id
      columns_a(i)%parameter_ref = int(i,int64)
      columns_a(i)%state_handle = int(i,int64)
      columns_a(i)%forcing_handle = int(i,int64)
      columns_a(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      columns_b(i) = columns_a(i)
      columns_b(i)%template_id = templates(ncol + 1 - i)%template_id
    end do

    call fmr_run_serialized_physical_multiswap(columns_a, templates, parameters, forcings, states_a, &
         config, top, t0, t1, 3, results_a, diagnostics_a, aggregate_a, status_a, runtime_a)
    call fmr_run_serialized_physical_multiswap(columns_b, templates, parameters, forcings, states_b, &
         config, top, t0, t1, 2, results_b, diagnostics_b, aggregate_b, status_b, runtime_b)

    call require(status_a == FMR_SERIAL_DISPATCH_OK .and. status_b == FMR_SERIAL_DISPATCH_OK, 'dispatch status')
    call require(runtime_a%number_requested == ncol .and. runtime_b%number_requested == ncol, 'requested diagnostics')
    call require(runtime_a%number_admitted == ncol .and. runtime_b%number_admitted == ncol, 'admitted diagnostics')
    call require(runtime_a%number_executed == ncol .and. runtime_b%number_executed == ncol, 'executed diagnostics')
    call require(runtime_a%number_committed == ncol .and. runtime_b%number_committed == ncol, 'committed diagnostics')
    call require(runtime_a%number_rejected == 0 .and. runtime_b%number_rejected == 0, 'rejected diagnostics')
    call require(runtime_a%physical_solve_count == ncol .and. runtime_b%physical_solve_count == ncol, 'solve count')
    call require(runtime_a%deterministic_collection .and. runtime_b%deterministic_collection, 'deterministic collection')
    call require(same_bits(runtime_a%effective_t0,t0) .and. same_bits(runtime_a%effective_t1,t1), 'runtime A interval')
    call require(same_bits(runtime_b%effective_t0,t0) .and. same_bits(runtime_b%effective_t1,t1), 'runtime B interval')
    call require(runtime_a%max_simultaneous_real_physical_solves == 1 .and. &
         runtime_b%max_simultaneous_real_physical_solves == 1, 'serialized worker scratch bound')
    call require(runtime_a%authoritative_aggregate_mass%complete .and. &
         runtime_b%authoritative_aggregate_mass%complete, 'aggregate mass complete')
    call require(abs(runtime_a%authoritative_aggregate_mass%residual) <= real(ncol,real64)*mass_gate .and. &
         abs(runtime_b%authoritative_aggregate_mass%residual) <= real(ncol,real64)*mass_gate, 'aggregate hard mass')

    do i = 1, ncol
      expected_exchange = rates(i) * (t1 - t0)
      call require(results_a(i)%dispatch_ordinal == i, 'baseline dispatch order')
      call require(results_b(i)%dispatch_ordinal == ncol + 1 - i, 'permuted dispatch order')
      call require(results_a(i)%completed .and. results_b(i)%completed, 'completed both permutations')
      call require(results_a(i)%committed .and. results_b(i)%committed, 'committed both permutations')
      call require(results_a(i)%admission_assessed .and. results_a(i)%admitted, 'baseline admission diagnostics')
      call require(results_b(i)%admission_assessed .and. results_b(i)%admitted, 'permuted admission diagnostics')
      call require(trim(results_a(i)%admission_status) == 'ADMITTED' .and. &
           trim(results_b(i)%admission_status) == 'ADMITTED', 'admission status')
      call require(results_a(i)%mass%complete .and. results_b(i)%mass%complete, 'column mass complete')
      call require(results_a(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE .and. &
           results_b(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'missing-mass mask')
      call require(abs(results_a(i)%mass%residual) <= mass_gate .and. abs(results_b(i)%mass%residual) <= mass_gate, &
           'column hard mass closure')
      call require(abs((results_a(i)%mass%total_out-background_amount)-expected_exchange) <= mass_gate, &
           'baseline drainage external-out ledger')
      call require(abs((results_b(i)%mass%total_out-background_amount)-expected_exchange) <= mass_gate, &
           'permuted drainage external-out ledger')
      call require(abs((results_a(i)%mass%total_in-background_amount)-expected_exchange) <= mass_gate, &
           'baseline balancing source ledger')
      call require(abs((results_b(i)%mass%total_in-background_amount)-expected_exchange) <= mass_gate, &
           'permuted balancing source ledger')
      call require(same_bits(results_a(i)%mass%total_in,results_b(i)%mass%total_in) .and. &
           same_bits(results_a(i)%mass%total_out,results_b(i)%mass%total_out) .and. &
           same_bits(results_a(i)%mass%residual,results_b(i)%mass%residual), 'permutation mass transcript')
      call require(states_identical(states_a(i),states_b(i)), 'permutation committed state')

      call require(diagnostics_a(i)%accepted == 1 .and. diagnostics_b(i)%accepted == 1, 'accepted diagnostics')
      call require(diagnostics_a(i)%rejected == 0 .and. diagnostics_b(i)%rejected == 0, 'accepted reject counter')
      call require(trim(diagnostics_a(i)%failure_classification) == 'NONE' .and. &
           trim(diagnostics_b(i)%failure_classification) == 'NONE', 'accepted failure classification')
      call require(diagnostics_a(i)%checkpoint_captures == 1 .and. diagnostics_b(i)%checkpoint_captures == 1, &
           'checkpoint capture diagnostics')
      call require(diagnostics_a(i)%checkpoint_replays == 1 .and. diagnostics_b(i)%checkpoint_replays == 1, &
           'checkpoint replay diagnostics')
      call require(diagnostics_a(i)%runtime_attempts == 1 .and. diagnostics_b(i)%runtime_attempts == 1, &
           'runtime attempt diagnostics')
      call require(diagnostics_a(i)%attempts >= 1 .and. diagnostics_b(i)%attempts >= 1, 'solver attempt diagnostics')
      call require(diagnostics_a(i)%committed_revision == 1_int64 .and. &
           diagnostics_b(i)%committed_revision == 1_int64, 'committed revision diagnostics')
      call require(diagnostics_a(i)%committed_time_bound .and. diagnostics_b(i)%committed_time_bound, &
           'committed time bound diagnostics')
      call require(same_bits(diagnostics_a(i)%committed_time,t1) .and. &
           same_bits(diagnostics_b(i)%committed_time,t1), 'committed time diagnostics')
      call require(abs(diagnostics_a(i)%unrounded_mass_residual) <= mass_gate .and. &
           abs(diagnostics_b(i)%unrounded_mass_residual) <= mass_gate, 'diagnostic mass residual')
    end do

    call require(aggregate_a%columns == ncol .and. aggregate_b%columns == ncol, 'aggregate column count')
    call require(aggregate_a%templates == ncol .and. aggregate_b%templates == ncol, 'aggregate template count')
    call require(aggregate_a%workers == 1 .and. aggregate_b%workers == 1, 'aggregate worker count')
    call require(aggregate_a%failures == 0 .and. aggregate_b%failures == 0, 'aggregate failure count')
    call require(same_bits(aggregate_a%aggregate_unrounded_mass_residual, &
         aggregate_b%aggregate_unrounded_mass_residual), 'aggregate permutation residual')

    write(*,'(A)') 'FVQ74_MULTISWAP_ACTIVE_INACTIVE_ISOLATION=PASS'
    write(*,'(A)') 'FVQ74_MULTISWAP_EXECUTION_ORDER_INDEPENDENCE=PASS'
    write(*,'(A)') 'FVQ74_ACCEPTED_RUNTIME_DIAGNOSTICS=PASS'
  end subroutine verify_fresh_multiswap_permutation_isolation

  subroutine verify_fresh_restart_continuation()
    type(fmr_serialized_reference_backend_t) :: backend_continuous, backend_pre_restart, backend_post_restart
    type(kernel_executor_t) :: tx_continuous, tx_pre_restart, tx_post_restart
    type(kernel_committed_state_t) :: continuous, pre_restart, restarted
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: out_c1, out_c2, out_r1, out_r2
    type(fmr_column_diagnostics_t) :: diag_c1, diag_c2, diag_r1, diag_r2
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_b110_physical_state_t) :: initial_state, restart_state
    real(real64) :: conductivity0
    integer :: active_calls

    call configure_base(initial_state, conductivity0, config)
    call configure_parameters(parameters, 17, 1.625e-2_real64, .true.)
    call configure_forcing(forcing, 1.625e-2_real64, .true., conductivity0)
    call configure_one_template(template, 174901_int64)
    column%column_id = 174901_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_column_state(continuous, column%column_id, initial_state, t0)
    call initialize_column_state(pre_restart, column%column_id, initial_state, t0)

    call backend_continuous%initialize(top)
    call reset_single(out_c1,diag_c1,runtime,active_calls,column%column_id,t0,t1)
    call fmr_execute_serialized_resolved_physical_column(backend_continuous,tx_continuous,column,template,parameters, &
         forcing,continuous,config,t0,t1,out_c1,diag_c1,runtime,active_calls)
    call require(out_c1%committed .and. diag_c1%accepted == 1, 'continuous first interval')
    call reset_single(out_c2,diag_c2,runtime,active_calls,column%column_id,t1,t2)
    call fmr_execute_serialized_resolved_physical_column(backend_continuous,tx_continuous,column,template,parameters, &
         forcing,continuous,config,t1,t2,out_c2,diag_c2,runtime,active_calls)
    call require(out_c2%committed .and. diag_c2%accepted == 1, 'continuous second interval')

    call backend_pre_restart%initialize(top)
    call reset_single(out_r1,diag_r1,runtime,active_calls,column%column_id,t0,t1)
    call fmr_execute_serialized_resolved_physical_column(backend_pre_restart,tx_pre_restart,column,template,parameters, &
         forcing,pre_restart,config,t0,t1,out_r1,diag_r1,runtime,active_calls)
    call require(out_r1%committed .and. diag_r1%accepted == 1, 'pre-restart first interval')
    call snapshot_physical_state(pre_restart,restart_state)
    call require(.not. allocated(restart_state%snow), 'restart state unexpectedly contains snow')
    call require(.not. allocated(restart_state%soil_temperature), 'restart state unexpectedly contains soil temperature')
    call initialize_column_state(restarted,column%column_id,restart_state,t1)

    call backend_post_restart%initialize(top)
    call reset_single(out_r2,diag_r2,runtime,active_calls,column%column_id,t1,t2)
    call fmr_execute_serialized_resolved_physical_column(backend_post_restart,tx_post_restart,column,template,parameters, &
         forcing,restarted,config,t1,t2,out_r2,diag_r2,runtime,active_calls)
    call require(out_r2%committed .and. diag_r2%accepted == 1, 'post-restart second interval')

    call require(states_identical(continuous,restarted), 'restart physical continuation equivalence')
    call require(same_bits(out_c2%mass%total_in,out_r2%mass%total_in) .and. &
         same_bits(out_c2%mass%total_out,out_r2%mass%total_out) .and. &
         same_bits(out_c2%mass%residual,out_r2%mass%residual), 'restart mass transcript equivalence')
    call require(abs(out_c2%mass%residual) <= mass_gate .and. abs(out_r2%mass%residual) <= mass_gate, &
         'restart hard mass closure')
    call require(continuous%current_revision() == 2_int64, 'continuous revision count')
    call require(restarted%current_revision() == 1_int64, 'restarted revision count')
    call require(diag_c2%committed_time_bound .and. diag_r2%committed_time_bound, 'restart committed time bound')
    call require(same_bits(diag_c2%committed_time,t2) .and. same_bits(diag_r2%committed_time,t2), &
         'restart committed time equivalence')
    call require(diag_c2%attempts == diag_r2%attempts .and. diag_c2%retries == diag_r2%retries, &
         'restart solver cost diagnostics equivalence')
    call require(trim(diag_c2%failure_classification) == 'NONE' .and. &
         trim(diag_r2%failure_classification) == 'NONE', 'restart diagnostic classification')

    write(*,'(A)') 'FVQ74_RESTART_NO_ADDITIONAL_DRAINAGE_STATE=PASS'
    write(*,'(A)') 'FVQ74_RESTART_CONTINUATION_EQUIVALENCE=PASS'
  end subroutine verify_fresh_restart_continuation

  subroutine verify_reject_diagnostics_are_fail_closed()
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
    type(fmr_b110_physical_state_t) :: initial_state, before_state, after_state
    real(real64) :: conductivity0, committed_time
    logical :: available
    integer :: active_calls

    call configure_base(initial_state,conductivity0,config)
    call configure_parameters(parameters,29,9.25e-3_real64,.true.)
    call configure_forcing(forcing,9.25e-3_real64,.true.,conductivity0)
    parameters%drainage_response_levels(1)%variant = 999
    call configure_one_template(template,174999_int64)
    column%column_id = 174999_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call initialize_column_state(committed,column%column_id,initial_state,t0)
    call snapshot_physical_state(committed,before_state)

    call backend%initialize(top)
    call reset_single(output,diagnostic,runtime,active_calls,column%column_id,t0,t1)
    call fmr_execute_serialized_resolved_physical_column(backend,tx_control,column,template,parameters,forcing, &
         committed,config,t0,t1,output,diagnostic,runtime,active_calls)
    call snapshot_physical_state(committed,after_state)
    call committed%current_time(committed_time,available)

    call require(.not. output%completed .and. .not. output%committed, 'unsupported route committed')
    call require(committed%current_revision() == 0_int64, 'unsupported route changed revision')
    call require(available .and. same_bits(committed_time,t0), 'unsupported route changed committed time')
    call require(states_bit_identical(before_state,after_state), 'unsupported route changed committed state')
    call require(diagnostic%accepted == 0 .and. diagnostic%rejected == 1, 'reject counters')
    call require(trim(diagnostic%failure_classification) /= 'NONE', 'reject classification absent')
    call require(diagnostic%committed_revision == 0_int64, 'reject diagnostic revision')
    call require(diagnostic%committed_time_bound .and. same_bits(diagnostic%committed_time,t0), &
         'reject diagnostic committed time')
    call require(active_calls == 0, 'reject physical call counter leak')

    write(*,'(A)') 'FVQ74_REJECT_DIAGNOSTICS_FAIL_CLOSED=PASS'
  end subroutine verify_reject_diagnostics_are_fail_closed

  subroutine configure_base(initial_state,conductivity0,config)
    type(fmr_b110_physical_state_t), intent(out) :: initial_state
    real(real64), intent(out) :: conductivity0
    type(canonical_numerical_config_t), intent(out) :: config
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: cofgen(24,numnod), heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    call fill_cofgen(cofgen)
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(provider,hp,t1-t0)
    heads = initial_head
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    conductivity0 = conductivity(1)

    initial_state%active_nodes = numnod
    allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
    initial_state%pressure_head = heads
    initial_state%water_content = water
    initial_state%ponding_depth = 0.0_real64
    initial_state%groundwater_level = initial_gwl

    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e3_real64
    config%transaction%mass_tolerance = mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_base

  subroutine configure_parameters(parameters,ordinal,rate,active_response)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    integer, intent(in) :: ordinal
    real(real64), intent(in) :: rate
    logical, intent(in) :: active_response
    integer :: k

    parameters%parameter_set_id = 174000_int64 + int(ordinal,int64)
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod),parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    call fill_cofgen(parameters%cofgen)
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
    parameters%drainage_response_active = active_response
    if (active_response) then
      allocate(parameters%drainage_response_levels(1))
      parameters%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_TABULATED
      allocate(parameters%drainage_response_levels(1)%tabulated%groundwater_depth(1), &
           parameters%drainage_response_levels(1)%tabulated%signed_exchange_rate(1))
      parameters%drainage_response_levels(1)%tabulated%groundwater_depth(1) = 25.0_real64
      parameters%drainage_response_levels(1)%tabulated%signed_exchange_rate(1) = rate
    end if
  end subroutine configure_parameters

  subroutine configure_forcing(forcing,rate,active_response,conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: rate, conductivity0
    logical, intent(in) :: active_response

    forcing%top_flux = -conductivity0
    forcing%top_head = initial_head
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -411.0_real64
    allocate(forcing%subsurface_irrigation_source(numnod),forcing%root_extraction_sink(numnod))
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%subsurface_irrigation_source(numnod) = rate
    forcing%root_extraction_sink = 0.0_real64
    if (active_response) then
      allocate(forcing%drainage_response_controls(1))
    else
      allocate(forcing%drainage_flux_by_level(1,numnod))
      forcing%drainage_flux_by_level = 0.0_real64
      forcing%drainage_flux_by_level(1,numnod) = rate
    end if
  end subroutine configure_forcing

  subroutine configure_templates(templates)
    type(fmr_template_t), intent(out) :: templates(ncol)
    integer :: i
    do i = 1, ncol
      call configure_one_template(templates(i),174100_int64 + int(i,int64))
    end do
  end subroutine configure_templates

  subroutine configure_one_template(template,id)
    type(fmr_template_t), intent(out) :: template
    integer(int64), intent(in) :: id
    template%template_id = id
    template%physics_topology_id = 174201_int64
    template%vertical_layout_id = 174202_int64
    template%state_layout_id = 174203_int64
    template%solver_interface_id = 174204_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_one_template

  subroutine fill_cofgen(cofgen)
    real(real64), intent(out) :: cofgen(24,numnod)
    integer :: k
    cofgen = 0.0_real64
    do k = 1, numnod
      cofgen(1,k)=0.032_real64; cofgen(2,k)=0.423_real64; cofgen(3,k)=4.75_real64
      cofgen(4,k)=0.0135_real64; cofgen(5,k)=0.365_real64; cofgen(6,k)=1.455_real64
      cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k); cofgen(8,k)=cofgen(4,k)
      cofgen(9,k)=0.0_real64; cofgen(10,k)=cofgen(3,k); cofgen(11,k)=0.999_real64
      cofgen(12,k)=0.99_real64*cofgen(3,k); cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
    end do
  end subroutine fill_cofgen

  subroutine initialize_column_state(committed,lineage_id,state,time0)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: time0
    logical :: ok
    call fmr_new_b110_committed_state(committed,lineage_id,state,time0,ok)
    call require(ok,'committed-state initialization')
  end subroutine initialize_column_state

  subroutine reset_single(output,diagnostic,runtime,active_calls,column_id,ta,tb)
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_column_diagnostics_t), intent(out) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer, intent(out) :: active_calls
    integer(int64), intent(in) :: column_id
    real(real64), intent(in) :: ta,tb
    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = ta
    output%requested_t1 = tb
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_calls = 0
  end subroutine reset_single

  subroutine snapshot_physical_state(committed,state)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call committed%snapshot(snapshot,available)
    call require(available,'snapshot available')
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      state = physical
    class default
      error stop 'F-VQ74 unexpected physical state type'
    end select
  end subroutine snapshot_physical_state

  logical function states_identical(left,right) result(same)
    type(kernel_committed_state_t), intent(in) :: left,right
    type(fmr_b110_physical_state_t) :: a,b
    call snapshot_physical_state(left,a)
    call snapshot_physical_state(right,b)
    same = states_bit_identical(a,b)
  end function states_identical

  logical function states_bit_identical(a,b) result(same)
    type(fmr_b110_physical_state_t), intent(in) :: a,b
    integer :: i
    same = a%active_nodes == b%active_nodes .and. same_bits(a%ponding_depth,b%ponding_depth) .and. &
         same_bits(a%groundwater_level,b%groundwater_level)
    if (.not. same) return
    if (allocated(a%snow) .neqv. allocated(b%snow)) then
      same = .false.; return
    end if
    if (allocated(a%soil_temperature) .neqv. allocated(b%soil_temperature)) then
      same = .false.; return
    end if
    if (.not. allocated(a%pressure_head) .or. .not. allocated(b%pressure_head) .or. &
        .not. allocated(a%water_content) .or. .not. allocated(b%water_content)) then
      same = .false.; return
    end if
    if (size(a%pressure_head) /= size(b%pressure_head) .or. size(a%water_content) /= size(b%water_content)) then
      same = .false.; return
    end if
    do i = 1,size(a%pressure_head)
      if (.not. same_bits(a%pressure_head(i),b%pressure_head(i))) then
        same = .false.; return
      end if
    end do
    do i = 1,size(a%water_content)
      if (.not. same_bits(a%water_content(i),b%water_content(i))) then
        same = .false.; return
      end if
    end do
  end function states_bit_identical

  pure logical function same_bits(a,b) result(equal)
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
      write(*,'(A,1X,A)') 'FVQ74_CROSSCUTTING_TEST_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq74_drainage_crosscutting_independent

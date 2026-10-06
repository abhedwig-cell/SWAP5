program test_fvq74_drainage_cross_cutting_independent
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

  real(real64), parameter :: t0 = 9182.3125_real64
  real(real64), parameter :: t1 = 9182.6875_real64
  real(real64), parameter :: t2 = 9183.0625_real64
  real(real64), parameter :: initial_head = -141.0_real64
  real(real64), parameter :: initial_gwl = -2.85_real64
  real(real64), parameter :: mass_gate = 1.0e-10_real64
  integer, parameter :: ncol = 4
  real(real64), parameter :: rates(ncol) = [4.0e-3_real64, 1.1e-2_real64, 7.0e-3_real64, 1.5e-2_real64]
  logical, parameter :: response_active(ncol) = [.true., .false., .true., .false.]

  call verify_multiswap_isolation_order_and_diagnostics()
  call verify_restart_continuation_without_drainage_state()
  call verify_rejected_response_diagnostics_and_atomicity()
  write(*,'(A)') 'FVQ74_DRAINAGE_CROSS_CUTTING_INDEPENDENT=PASS'

contains

  subroutine verify_multiswap_isolation_order_and_diagnostics()
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
    real(real64) :: conductivity0, background_amount
    integer :: i, status_a, status_b

    call configure_base(initial_state, conductivity0, config)
    background_amount = conductivity0 * (t1 - t0)
    call configure_templates(templates)

    do i = 1, ncol
      call configure_parameters(parameters(i), i, rates(i), response_active(i))
      call configure_forcing(forcings(i), rates(i), response_active(i), conductivity0)
      call initialize_column_state(states_a(i), 74000_int64 + int(i,int64), initial_state, t0)
      call initialize_column_state(states_b(i), 74000_int64 + int(i,int64), initial_state, t0)

      columns_a(i)%column_id = 74000_int64 + int(i,int64)
      columns_a(i)%template_id = templates(i)%template_id
      columns_a(i)%parameter_ref = int(i,int64)
      columns_a(i)%state_handle = int(i,int64)
      columns_a(i)%forcing_handle = int(i,int64)
      columns_a(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      columns_b(i) = columns_a(i)
      columns_b(i)%template_id = templates(ncol + 1 - i)%template_id
    end do

    call fmr_run_serialized_physical_multiswap(columns_a, templates, parameters, forcings, states_a, config, top, &
         t0, t1, 3, results_a, diagnostics_a, aggregate_a, status_a, runtime_a)
    call fmr_run_serialized_physical_multiswap(columns_b, templates, parameters, forcings, states_b, config, top, &
         t0, t1, 2, results_b, diagnostics_b, aggregate_b, status_b, runtime_b)

    call require(status_a == FMR_SERIAL_DISPATCH_OK .and. status_b == FMR_SERIAL_DISPATCH_OK, 'batch dispatch')
    call require(runtime_a%number_requested == ncol .and. runtime_b%number_requested == ncol, 'requested diagnostics')
    call require(runtime_a%number_admitted == ncol .and. runtime_b%number_admitted == ncol, 'admitted diagnostics')
    call require(runtime_a%number_executed == ncol .and. runtime_b%number_executed == ncol, 'executed diagnostics')
    call require(runtime_a%number_committed == ncol .and. runtime_b%number_committed == ncol, 'committed diagnostics')
    call require(runtime_a%number_rejected == 0 .and. runtime_b%number_rejected == 0, 'rejected diagnostics')
    call require(runtime_a%deterministic_collection .and. runtime_b%deterministic_collection, 'deterministic collection')
    call require(same_bits(runtime_a%effective_t0,t0) .and. same_bits(runtime_a%effective_t1,t1), 'runtime interval A')
    call require(same_bits(runtime_b%effective_t0,t0) .and. same_bits(runtime_b%effective_t1,t1), 'runtime interval B')
    call require(runtime_a%max_abs_column_mass_residual <= mass_gate .and. &
         runtime_b%max_abs_column_mass_residual <= mass_gate, 'runtime hard mass residual')

    do i = 1, ncol
      call require(results_a(i)%committed .and. results_b(i)%committed, 'column committed')
      call require(results_a(i)%mass%complete .and. results_b(i)%mass%complete, 'column mass complete')
      call require(results_a(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE .and. &
           results_b(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'column missing mass mask')
      call require(abs(results_a(i)%mass%residual) <= mass_gate .and. &
           abs(results_b(i)%mass%residual) <= mass_gate, 'column hard mass closure')
      call require(abs((results_a(i)%mass%total_out-background_amount)-rates(i)*(t1-t0)) <= mass_gate, &
           'A exact drainage amount')
      call require(abs((results_b(i)%mass%total_out-background_amount)-rates(i)*(t1-t0)) <= mass_gate, &
           'B exact drainage amount')
      call require(same_bits(results_a(i)%mass%total_in,results_b(i)%mass%total_in) .and. &
           same_bits(results_a(i)%mass%total_out,results_b(i)%mass%total_out) .and. &
           same_bits(results_a(i)%mass%residual,results_b(i)%mass%residual), 'order independent ledger')
      call require(states_identical(states_a(i),states_b(i)), 'order independent committed state')

      call require(diagnostics_a(i)%accepted == 1 .and. diagnostics_b(i)%accepted == 1, 'accepted diagnostic')
      call require(diagnostics_a(i)%rejected == 0 .and. diagnostics_b(i)%rejected == 0, 'no rejection diagnostic')
      call require(trim(diagnostics_a(i)%failure_classification) == 'NONE' .and. &
           trim(diagnostics_b(i)%failure_classification) == 'NONE', 'failure classification')
      call require(diagnostics_a(i)%checkpoint_captures == 1 .and. diagnostics_b(i)%checkpoint_captures == 1, &
           'checkpoint capture diagnostic')
      call require(diagnostics_a(i)%checkpoint_replays == 1 .and. diagnostics_b(i)%checkpoint_replays == 1, &
           'checkpoint replay diagnostic')
      call require(diagnostics_a(i)%runtime_attempts == 1 .and. diagnostics_b(i)%runtime_attempts == 1, &
           'runtime attempt diagnostic')
      call require(diagnostics_a(i)%attempts >= 1 .and. diagnostics_b(i)%attempts >= 1, 'solver attempt diagnostic')
      call require(diagnostics_a(i)%committed_revision == 1_int64 .and. &
           diagnostics_b(i)%committed_revision == 1_int64, 'committed revision diagnostic')
      call require(diagnostics_a(i)%committed_time_bound .and. diagnostics_b(i)%committed_time_bound, &
           'committed time bound diagnostic')
      call require(same_bits(diagnostics_a(i)%committed_time,t1) .and. &
           same_bits(diagnostics_b(i)%committed_time,t1), 'committed time diagnostic')
      call require(allocated(diagnostics_a(i)%worker_assignments) .and. &
           allocated(diagnostics_b(i)%worker_assignments), 'worker assignment allocation')
      call require(all(diagnostics_a(i)%worker_assignments == 1) .and. &
           all(diagnostics_b(i)%worker_assignments == 1), 'worker assignment diagnostic')
    end do

    call require(aggregate_a%columns == ncol .and. aggregate_b%columns == ncol, 'aggregate columns')
    call require(aggregate_a%workers == 1 .and. aggregate_b%workers == 1, 'aggregate workers')
    call require(aggregate_a%failures == 0 .and. aggregate_b%failures == 0, 'aggregate failures')
    call require(aggregate_a%attempts == sum(diagnostics_a%attempts) .and. &
         aggregate_b%attempts == sum(diagnostics_b%attempts), 'aggregate attempts')
    call require(aggregate_a%retries == sum(diagnostics_a%retries) .and. &
         aggregate_b%retries == sum(diagnostics_b%retries), 'aggregate retries')
    call require(same_bits(aggregate_a%aggregate_unrounded_mass_residual, &
         aggregate_b%aggregate_unrounded_mass_residual), 'aggregate order-independent residual')

    write(*,'(A)') 'FVQ74_MULTISWAP_ACTIVE_PRECOMPUTED_ISOLATION=PASS'
    write(*,'(A)') 'FVQ74_MULTISWAP_ORDER_INDEPENDENCE=PASS'
    write(*,'(A)') 'FVQ74_ACCEPTED_RUNTIME_DIAGNOSTICS=PASS'
  end subroutine verify_multiswap_isolation_order_and_diagnostics

  subroutine verify_restart_continuation_without_drainage_state()
    type(fmr_serialized_reference_backend_t) :: backend_cont, backend_pre, backend_post
    type(kernel_executor_t) :: tx_cont, tx_pre, tx_post
    type(kernel_committed_state_t) :: continuous, before_restart, restarted
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: c1, c2, r1, r2
    type(fmr_column_diagnostics_t) :: diag
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_b110_physical_state_t) :: initial_state, restart_state
    real(real64) :: conductivity0
    integer :: active_calls

    call configure_base(initial_state,conductivity0,config)
    call configure_parameters(parameters,11,8.5e-3_real64,.true.)
    call configure_forcing(forcing,8.5e-3_real64,.true.,conductivity0)
    call configure_one_template(template,74111_int64)
    column%column_id = 741110_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_column_state(continuous,column%column_id,initial_state,t0)
    call initialize_column_state(before_restart,column%column_id,initial_state,t0)

    call backend_cont%initialize(top)
    call reset_single(c1,diag,runtime,active_calls,column%column_id,t0,t1)
    call fmr_execute_serialized_resolved_physical_column(backend_cont,tx_cont,column,template,parameters,forcing, &
         continuous,config,t0,t1,c1,diag,runtime,active_calls)
    call require(c1%committed,'continuous interval one commit')
    call reset_single(c2,diag,runtime,active_calls,column%column_id,t1,t2)
    call fmr_execute_serialized_resolved_physical_column(backend_cont,tx_cont,column,template,parameters,forcing, &
         continuous,config,t1,t2,c2,diag,runtime,active_calls)
    call require(c2%committed,'continuous interval two commit')

    call backend_pre%initialize(top)
    call reset_single(r1,diag,runtime,active_calls,column%column_id,t0,t1)
    call fmr_execute_serialized_resolved_physical_column(backend_pre,tx_pre,column,template,parameters,forcing, &
         before_restart,config,t0,t1,r1,diag,runtime,active_calls)
    call require(r1%committed,'pre-restart interval commit')
    call snapshot_physical_state(before_restart,restart_state)
    call require(.not. allocated(restart_state%snow) .and. .not. allocated(restart_state%soil_temperature), &
         'drainage allocated optional persistent state')
    call initialize_column_state(restarted,column%column_id,restart_state,t1)

    call backend_post%initialize(top)
    call reset_single(r2,diag,runtime,active_calls,column%column_id,t1,t2)
    call fmr_execute_serialized_resolved_physical_column(backend_post,tx_post,column,template,parameters,forcing, &
         restarted,config,t1,t2,r2,diag,runtime,active_calls)
    call require(r2%committed,'post-restart interval commit')
    call require(diag%accepted == 1 .and. diag%rejected == 0,'restart accepted diagnostic')
    call require(trim(diag%failure_classification) == 'NONE','restart failure classification')
    call require(diag%committed_time_bound .and. same_bits(diag%committed_time,t2),'restart committed time diagnostic')
    call require(states_identical(continuous,restarted),'restart physical continuation equivalence')
    call require(same_bits(c2%mass%total_in,r2%mass%total_in) .and. &
         same_bits(c2%mass%total_out,r2%mass%total_out) .and. &
         same_bits(c2%mass%residual,r2%mass%residual),'restart mass transcript equivalence')
    call require(abs(r2%mass%residual) <= mass_gate,'restart hard mass closure')

    write(*,'(A)') 'FVQ74_RESTART_NO_ADDITIONAL_DRAINAGE_STATE=PASS'
    write(*,'(A)') 'FVQ74_RESTART_CONTINUATION_EQUIVALENCE=PASS'
  end subroutine verify_restart_continuation_without_drainage_state

  subroutine verify_rejected_response_diagnostics_and_atomicity()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diag
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_b110_physical_state_t) :: initial_state, before_state, after_state
    real(real64) :: conductivity0
    integer :: active_calls

    call configure_base(initial_state,conductivity0,config)
    call configure_parameters(parameters,12,9.0e-3_real64,.true.)
    parameters%drainage_response_levels(1)%variant = 999
    call configure_forcing(forcing,9.0e-3_real64,.true.,conductivity0)
    call configure_one_template(template,74112_int64)
    column%column_id = 741120_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call initialize_column_state(committed,column%column_id,initial_state,t0)
    call snapshot_physical_state(committed,before_state)

    call backend%initialize(top)
    call reset_single(output,diag,runtime,active_calls,column%column_id,t0,t1)
    call fmr_execute_serialized_resolved_physical_column(backend,tx,column,template,parameters,forcing,committed, &
         config,t0,t1,output,diag,runtime,active_calls)
    call snapshot_physical_state(committed,after_state)

    call require(.not. output%committed .and. .not. output%completed,'unsupported response committed')
    call require(committed%current_revision() == 0_int64,'unsupported response changed revision')
    call require(diag%accepted == 0 .and. diag%rejected == 1,'unsupported response rejection diagnostic')
    call require(trim(diag%failure_classification) == 'KERNEL_REJECTED','unsupported failure classification')
    call require(diag%checkpoint_captures == 1 .and. diag%runtime_attempts == 1,'unsupported attempt diagnostics')
    call require(diag%committed_time_bound .and. same_bits(diag%committed_time,t0),'unsupported committed time diagnostic')
    call require(physical_states_identical(before_state,after_state),'unsupported response mutated committed state')
    call require(active_calls == 0,'unsupported response active call counter')

    write(*,'(A)') 'FVQ74_REJECTED_RUNTIME_DIAGNOSTICS=PASS'
    write(*,'(A)') 'FVQ74_REJECTED_RUNTIME_ATOMICITY=PASS'
  end subroutine verify_rejected_response_diagnostics_and_atomicity

  subroutine configure_base(initial_state,conductivity0,config)
    type(fmr_b110_physical_state_t), intent(out) :: initial_state
    real(real64), intent(out) :: conductivity0
    type(canonical_numerical_config_t), intent(out) :: config
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: cofgen(24,numnod), heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    cofgen = 0.0_real64
    do k = 1, numnod
      cofgen(1,k)=0.032_real64; cofgen(2,k)=0.423_real64; cofgen(3,k)=4.75_real64
      cofgen(4,k)=0.0135_real64; cofgen(5,k)=0.365_real64; cofgen(6,k)=1.455_real64
      cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k); cofgen(8,k)=cofgen(4,k)
      cofgen(9,k)=0.0_real64; cofgen(10,k)=cofgen(3,k); cofgen(11,k)=0.999_real64
      cofgen(12,k)=0.99_real64*cofgen(3,k); cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
    end do
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

    parameters%parameter_set_id = 94000_int64 + int(ordinal,int64)
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod),parameters%cofgen(24,numnod))
    parameters%z = z; parameters%dz = dz; parameters%node_distance = disnod(1:numnod); parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode = 7; parameters%swkimpl = 0; parameters%swkmean = 1; parameters%swsophy = 0
    parameters%root_extraction_active = .false.; parameters%macropore_active = .false.; parameters%snow_active = .false.
    parameters%hysteresis_active = .false.; parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.; parameters%frost_active = .false.
    parameters%drainage_response_active = active_response
    if (active_response) then
      allocate(parameters%drainage_response_levels(1))
      parameters%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_TABULATED
      allocate(parameters%drainage_response_levels(1)%tabulated%groundwater_depth(1), &
           parameters%drainage_response_levels(1)%tabulated%signed_exchange_rate(1))
      parameters%drainage_response_levels(1)%tabulated%groundwater_depth(1) = 20.0_real64
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
    forcing%bottom_head = -321.0_real64
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
      call configure_one_template(templates(i), 74600_int64 + int(i,int64))
    end do
  end subroutine configure_templates

  subroutine configure_one_template(template,id)
    type(fmr_template_t), intent(out) :: template
    integer(int64), intent(in) :: id
    template%template_id = id
    template%physics_topology_id = 74610_int64
    template%vertical_layout_id = 74620_int64
    template%state_layout_id = 74630_int64
    template%solver_interface_id = 74640_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_one_template

  subroutine initialize_column_state(committed,lineage_id,state,time0)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: time0
    logical :: ok
    call fmr_new_b110_committed_state(committed,lineage_id,state,time0,ok)
    call require(ok,'committed state initialization')
  end subroutine initialize_column_state

  subroutine reset_single(output,diagnostic,runtime,active_calls,column_id,ta,tb)
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_column_diagnostics_t), intent(out) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer, intent(out) :: active_calls
    integer(int64), intent(in) :: column_id
    real(real64), intent(in) :: ta,tb
    output = fmr_serialized_column_result_t()
    output%column_id = column_id; output%requested_t0 = ta; output%requested_t1 = tb
    diagnostic = fmr_column_diagnostics_t(); diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t(); active_calls = 0
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
    same = physical_states_identical(a,b)
  end function states_identical

  logical function physical_states_identical(a,b) result(same)
    type(fmr_b110_physical_state_t), intent(in) :: a,b
    integer :: i
    same = a%active_nodes == b%active_nodes .and. same_bits(a%ponding_depth,b%ponding_depth) .and. &
         same_bits(a%groundwater_level,b%groundwater_level)
    if (.not. same) return
    if (allocated(a%snow) .neqv. allocated(b%snow)) then; same=.false.; return; end if
    if (allocated(a%soil_temperature) .neqv. allocated(b%soil_temperature)) then; same=.false.; return; end if
    if (.not. allocated(a%pressure_head) .or. .not. allocated(b%pressure_head) .or. &
        .not. allocated(a%water_content) .or. .not. allocated(b%water_content)) then
      same=.false.; return
    end if
    if (size(a%pressure_head) /= size(b%pressure_head) .or. size(a%water_content) /= size(b%water_content)) then
      same=.false.; return
    end if
    do i=1,size(a%pressure_head)
      if (.not. same_bits(a%pressure_head(i),b%pressure_head(i))) then; same=.false.; return; end if
    end do
    do i=1,size(a%water_content)
      if (.not. same_bits(a%water_content(i),b%water_content(i))) then; same=.false.; return; end if
    end do
  end function physical_states_identical

  pure logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ74_DRAINAGE_CROSS_CUTTING_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq74_drainage_cross_cutting_independent

program test_fpm14_multiswap_restart_isolation
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

  real(real64), parameter :: t0 = 4567.125_real64
  real(real64), parameter :: t1 = 4567.375_real64
  real(real64), parameter :: t2 = 4567.625_real64
  real(real64), parameter :: initial_head = -123.0_real64
  real(real64), parameter :: initial_gwl = -2.25_real64
  real(real64), parameter :: mass_gate = 1.0e-10_real64
  integer, parameter :: ncol = 3
  real(real64), parameter :: rates(ncol) = [1.0e-2_real64, 2.0e-2_real64, 3.0e-2_real64]

  call verify_multiswap_worker_isolation_and_order_independence()
  call verify_restart_without_drainage_process_state()
  write(*,'(A)') 'FPM14_MULTISWAP_RESTART_ISOLATION_OWNER_TEST PASS'

contains

  subroutine verify_multiswap_worker_isolation_and_order_independence()
    type(fmr_logical_column_t) :: columns_forward(ncol), columns_reverse(ncol)
    type(fmr_template_t) :: templates(ncol)
    type(fmr_b110_physical_parameters_t) :: parameters(ncol)
    type(fmr_b110_physical_forcing_t) :: forcings(ncol)
    type(kernel_committed_state_t) :: states_forward(ncol), states_reverse(ncol)
    type(fmr_serialized_column_result_t), allocatable :: results_forward(:), results_reverse(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics_forward(:), diagnostics_reverse(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate_forward, aggregate_reverse
    type(fmr_serialized_batch_diagnostics_t) :: runtime_forward, runtime_reverse
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(canonical_numerical_config_t) :: config
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: conductivity0, background_amount
    integer :: i, status_forward, status_reverse

    call configure_base(initial_state, conductivity0, config)
    background_amount = conductivity0 * (t1 - t0)
    call configure_templates(templates)
    do i = 1, ncol
      call configure_parameters(parameters(i), i, rates(i), i /= 2)
      call configure_forcing(forcings(i), rates(i), i /= 2, conductivity0)
      call initialize_column_state(states_forward(i), 7000_int64 + int(i,int64), initial_state, t0)
      call initialize_column_state(states_reverse(i), 7000_int64 + int(i,int64), initial_state, t0)

      columns_forward(i)%column_id = 7000_int64 + int(i,int64)
      columns_forward(i)%template_id = templates(i)%template_id
      columns_forward(i)%parameter_ref = int(i,int64)
      columns_forward(i)%state_handle = int(i,int64)
      columns_forward(i)%forcing_handle = int(i,int64)
      columns_forward(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      columns_reverse(i) = columns_forward(i)
      columns_reverse(i)%template_id = templates(ncol + 1 - i)%template_id
    end do

    call fmr_run_serialized_physical_multiswap(columns_forward, templates, parameters, forcings, states_forward, &
         config, top, t0, t1, 2, results_forward, diagnostics_forward, aggregate_forward, status_forward, runtime_forward)
    call fmr_run_serialized_physical_multiswap(columns_reverse, templates, parameters, forcings, states_reverse, &
         config, top, t0, t1, 2, results_reverse, diagnostics_reverse, aggregate_reverse, status_reverse, runtime_reverse)

    call require(status_forward == FMR_SERIAL_DISPATCH_OK .and. status_reverse == FMR_SERIAL_DISPATCH_OK, &
         'MultiSWAP dispatch status')
    call require(runtime_forward%number_committed == ncol .and. runtime_reverse%number_committed == ncol, &
         'all MultiSWAP columns committed')
    call require(runtime_forward%max_simultaneous_real_physical_solves == 1 .and. &
         runtime_reverse%max_simultaneous_real_physical_solves == 1, 'serialized worker bound')

    do i = 1, ncol
      call require(results_forward(i)%committed .and. results_reverse(i)%committed, 'column committed both orders')
      call require(results_forward(i)%mass%complete .and. results_reverse(i)%mass%complete, 'column mass complete')
      call require(results_forward(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE .and. &
           results_reverse(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'column missing-mass mask')
      call require(abs(results_forward(i)%mass%residual) <= mass_gate .and. &
           abs(results_reverse(i)%mass%residual) <= mass_gate, 'column hard mass closure')
      call require(abs((results_forward(i)%mass%total_out-background_amount) - rates(i)*(t1-t0)) <= mass_gate, &
           'forward order exact drainage external-out ledger')
      call require(abs((results_forward(i)%mass%total_in-background_amount) - rates(i)*(t1-t0)) <= mass_gate, &
           'forward order balancing qssdi external-in ledger')
      call require(abs((results_reverse(i)%mass%total_out-background_amount) - rates(i)*(t1-t0)) <= mass_gate, &
           'reverse order exact drainage external-out ledger')
      call require(abs((results_reverse(i)%mass%total_in-background_amount) - rates(i)*(t1-t0)) <= mass_gate, &
           'reverse order balancing qssdi external-in ledger')
      call require(same_bits(results_forward(i)%mass%total_in, results_reverse(i)%mass%total_in) .and. &
           same_bits(results_forward(i)%mass%total_out, results_reverse(i)%mass%total_out) .and. &
           same_bits(results_forward(i)%mass%residual, results_reverse(i)%mass%residual), &
           'order-independent per-column mass transcript')
      call require(states_identical(states_forward(i), states_reverse(i)), 'order-independent committed physical state')
    end do

    call require(same_bits(aggregate_forward%aggregate_unrounded_mass_residual, &
         aggregate_reverse%aggregate_unrounded_mass_residual), 'order-independent aggregate residual')
    write(*,'(A)') 'FPM14_MULTISWAP_ACTIVE_INACTIVE_ACTIVE_ISOLATION=PASS'
    write(*,'(A)') 'FPM14_MULTISWAP_EXECUTION_ORDER_INDEPENDENCE=PASS'
  end subroutine verify_multiswap_worker_isolation_and_order_independence

  subroutine verify_restart_without_drainage_process_state()
    type(fmr_serialized_reference_backend_t) :: backend_continuous, backend_pre_restart, backend_post_restart
    type(kernel_executor_t) :: tx_continuous, tx_pre_restart, tx_post_restart
    type(kernel_committed_state_t) :: continuous, pre_restart, restarted
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: out_c1, out_c2, out_r1, out_r2
    type(fmr_column_diagnostics_t) :: diag
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_b110_physical_state_t) :: initial_state, restart_state
    real(real64) :: conductivity0
    integer :: active_calls

    call configure_base(initial_state, conductivity0, config)
    call configure_parameters(parameters, 1, 1.5e-2_real64, .true.)
    call configure_forcing(forcing, 1.5e-2_real64, .true., conductivity0)
    call configure_one_template(template, 8101_int64)
    column%column_id = 81001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_column_state(continuous, column%column_id, initial_state, t0)
    call initialize_column_state(pre_restart, column%column_id, initial_state, t0)

    call backend_continuous%initialize(top)
    call reset_single(out_c1, diag, runtime, active_calls, column%column_id, t0, t1)
    call fmr_execute_serialized_resolved_physical_column(backend_continuous, tx_continuous, column, template, parameters, &
         forcing, continuous, config, t0, t1, out_c1, diag, runtime, active_calls)
    call require(out_c1%committed, 'continuous first interval commit')
    call reset_single(out_c2, diag, runtime, active_calls, column%column_id, t1, t2)
    call fmr_execute_serialized_resolved_physical_column(backend_continuous, tx_continuous, column, template, parameters, &
         forcing, continuous, config, t1, t2, out_c2, diag, runtime, active_calls)
    call require(out_c2%committed, 'continuous second interval commit')

    call backend_pre_restart%initialize(top)
    call reset_single(out_r1, diag, runtime, active_calls, column%column_id, t0, t1)
    call fmr_execute_serialized_resolved_physical_column(backend_pre_restart, tx_pre_restart, column, template, parameters, &
         forcing, pre_restart, config, t0, t1, out_r1, diag, runtime, active_calls)
    call require(out_r1%committed, 'pre-restart first interval commit')
    call snapshot_physical_state(pre_restart, restart_state)
    call require(.not. allocated(restart_state%snow) .and. .not. allocated(restart_state%soil_temperature), &
         'drainage response adds no optional persistent state')
    call initialize_column_state(restarted, column%column_id, restart_state, t1)

    call backend_post_restart%initialize(top)
    call reset_single(out_r2, diag, runtime, active_calls, column%column_id, t1, t2)
    call fmr_execute_serialized_resolved_physical_column(backend_post_restart, tx_post_restart, column, template, parameters, &
         forcing, restarted, config, t1, t2, out_r2, diag, runtime, active_calls)
    call require(out_r2%committed, 'post-restart second interval commit')

    call require(states_identical(continuous, restarted), 'restart/no-state physical equivalence')
    call require(same_bits(out_c2%mass%total_in, out_r2%mass%total_in) .and. &
         same_bits(out_c2%mass%total_out, out_r2%mass%total_out) .and. &
         same_bits(out_c2%mass%residual, out_r2%mass%residual), 'restart/no-state second-interval mass equivalence')
    call require(abs(out_r2%mass%residual) <= mass_gate, 'restart route hard mass closure')
    write(*,'(A)') 'FPM14_RESTART_NO_ADDITIONAL_DRAINAGE_STATE=PASS'
    write(*,'(A)') 'FPM14_RESTART_CONTINUATION_EQUIVALENCE=PASS'
  end subroutine verify_restart_without_drainage_process_state

  subroutine configure_base(initial_state, conductivity0, config)
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
    call initialize_b110_default_mvg_parameters(hp, cofgen)
    call bind_b110_default_mvg_provider(provider, hp, t1-t0)
    heads = initial_head
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    initial_state%active_nodes = numnod
    allocate(initial_state%pressure_head(numnod), initial_state%water_content(numnod))
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

  subroutine configure_parameters(parameters, ordinal, rate, active_response)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    integer, intent(in) :: ordinal
    real(real64), intent(in) :: rate
    logical, intent(in) :: active_response
    integer :: k

    parameters%parameter_set_id = 9000_int64 + int(ordinal,int64)
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
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

  subroutine configure_forcing(forcing, rate, active_response, conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: rate, conductivity0
    logical, intent(in) :: active_response
    forcing%top_flux = -conductivity0
    forcing%top_head = initial_head
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -321.0_real64
    allocate(forcing%subsurface_irrigation_source(numnod), forcing%root_extraction_sink(numnod))
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
      call configure_one_template(templates(i), 6000_int64 + int(i,int64))
    end do
  end subroutine configure_templates

  subroutine configure_one_template(template, id)
    type(fmr_template_t), intent(out) :: template
    integer(int64), intent(in) :: id
    template%template_id = id
    template%physics_topology_id = 6101_int64
    template%vertical_layout_id = 6102_int64
    template%state_layout_id = 6103_int64
    template%solver_interface_id = 6104_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_one_template

  subroutine initialize_column_state(committed, lineage_id, state, time0)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: time0
    logical :: ok
    call fmr_new_b110_committed_state(committed, lineage_id, state, time0, ok)
    call require(ok, 'committed-state initialization')
  end subroutine initialize_column_state

  subroutine reset_single(output, diagnostic, runtime, active_calls, column_id, ta, tb)
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_column_diagnostics_t), intent(out) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer, intent(out) :: active_calls
    integer(int64), intent(in) :: column_id
    real(real64), intent(in) :: ta, tb
    output = fmr_serialized_column_result_t()
    output%column_id = column_id; output%requested_t0 = ta; output%requested_t1 = tb
    diagnostic = fmr_column_diagnostics_t(); diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t(); active_calls = 0
  end subroutine reset_single

  subroutine snapshot_physical_state(committed, state)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call committed%snapshot(snapshot, available)
    call require(available, 'snapshot available')
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      state = physical
    class default
      error stop 'F-PM14 unexpected physical state type'
    end select
  end subroutine snapshot_physical_state

  logical function states_identical(left, right) result(same)
    type(kernel_committed_state_t), intent(in) :: left, right
    type(fmr_b110_physical_state_t) :: a, b
    integer :: i
    call snapshot_physical_state(left, a)
    call snapshot_physical_state(right, b)
    same = a%active_nodes == b%active_nodes .and. same_bits(a%ponding_depth,b%ponding_depth) .and. &
         same_bits(a%groundwater_level,b%groundwater_level)
    if (.not. same) return
    if (.not. allocated(a%pressure_head) .or. .not. allocated(b%pressure_head) .or. &
        .not. allocated(a%water_content) .or. .not. allocated(b%water_content)) then
      same = .false.; return
    end if
    if (size(a%pressure_head) /= size(b%pressure_head) .or. size(a%water_content) /= size(b%water_content)) then
      same = .false.; return
    end if
    do i = 1, size(a%pressure_head)
      if (.not. same_bits(a%pressure_head(i),b%pressure_head(i))) then
        same = .false.; return
      end if
    end do
    do i = 1, size(a%water_content)
      if (.not. same_bits(a%water_content(i),b%water_content(i))) then
        same = .false.; return
      end if
    end do
  end function states_identical

  pure logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a, ia); ib = transfer(b, ib); equal = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM14_MULTISWAP_RESTART_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpm14_multiswap_restart_isolation

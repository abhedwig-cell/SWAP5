program test_fmq26_parallel_v1_admission
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK, &
       FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 4100.1875_real64
  real(real64), parameter :: t1 = 4100.6875_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: ncases = 14
  integer, parameter :: case_n(ncases) = [2,2,7,7,7,8,8,17,17,31,31,32,32,32]
  integer, parameter :: case_batch(ncases) = [1,2,2,3,7,3,5,4,9,7,16,8,9,17]
  integer :: k

  do k = 1, ncases
    call run_positive_case(case_n(k), case_batch(k), mod(k-1,4))
    write(*,'(A,I0,A,I0,A,I0,A)') 'FMQ26_POSITIVE_N',case_n(k),'_B',case_batch(k),'_O',mod(k-1,4),'=PASS'
  end do

  call run_order_independence_case(17, 4)
  write(*,'(A)') 'FMQ26_INPUT_ORDER_INDEPENDENCE=PASS'

  call run_rejection_isolation_case(17, 4, [4], 4)
  write(*,'(A)') 'FMQ26_REJECTION_AT_BATCH_BOUNDARY=PASS'
  call run_rejection_isolation_case(17, 9, [7], 4)
  write(*,'(A)') 'FMQ26_REJECTION_INTERIOR=PASS'
  call run_rejection_isolation_case(31, 7, [3,4], 4)
  write(*,'(A)') 'FMQ26_TWO_WORKER_SEPARATED_REJECTIONS=PASS'

  call run_unsupported_profile_matrix()
  write(*,'(A)') 'FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS'

  call run_overlap_control()
  write(*,'(A)') 'FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS'

  write(*,'(A)') 'FMQ26_HARD_MASS_ALL_CASES=PASS'
  write(*,'(A)') 'FMQ26_WORKER_COUNT_INDEPENDENCE=PASS'
  write(*,'(A)') 'FMQ26_DETERMINISTIC_REPLAY=PASS'
  write(*,'(A)') 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'

contains

  subroutine run_positive_case(n, batch_size, order_code)
    integer, intent(in) :: n, batch_size, order_code
    type(fmr_logical_column_t), allocatable :: base_columns(:), columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1), parameters_before(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: s_serial(:), s2a(:), s4(:), s2b(:)
    type(fmr_serialized_column_result_t), allocatable :: r_serial(:), r2a(:), r4(:), r2b(:)
    type(fmr_column_diagnostics_t), allocatable :: d_serial(:), d2a(:), d4(:), d2b(:)
    type(fmr_aggregate_diagnostics_t) :: a_serial, a2a, a4, a2b
    type(fmr_serialized_batch_diagnostics_t) :: rt_serial, rt2a, rt4, rt2b
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: serial_status, dispatch_status, pool_status

    call build_fixture(n, base_columns, templates, parameters, forcings, seed, conductivity0)
    parameters_before = parameters
    call permute_columns(base_columns, order_code, columns)
    call configure_transaction(config)
    call initialize_states(s_serial, base_columns, seed)
    call initialize_states(s2a, base_columns, seed)
    call initialize_states(s4, base_columns, seed)
    call initialize_states(s2b, base_columns, seed)

    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, s_serial, config, top_provider, &
         t0, t1, batch_size, r_serial, d_serial, a_serial, serial_status, rt_serial)
    call require(serial_status == FMR_SERIAL_DISPATCH_OK .and. all_committed(r_serial), 'serialized reference')
    call require(max_abs_residual(r_serial) <= hard_mass_gate, 'serialized hard mass')

    call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, s2a, config, top_provider, &
         t0, t1, batch_size, 2, r2a, d2a, a2a, dispatch_status, pool_status, rt2a)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, '2 worker status')
    call require(all_committed(r2a) .and. max_abs_residual(r2a) <= hard_mass_gate, '2 worker mass/commit')

    call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, s4, config, top_provider, &
         t0, t1, batch_size, 4, r4, d4, a4, dispatch_status, pool_status, rt4)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, '4 worker status')
    call require(all_committed(r4) .and. max_abs_residual(r4) <= hard_mass_gate, '4 worker mass/commit')

    call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, s2b, config, top_provider, &
         t0, t1, batch_size, 2, r2b, d2b, a2b, dispatch_status, pool_status, rt2b)
    call require(pool_status == FMR_PARALLEL_POOL_OK, '2 worker replay status')

    call require(result_sets_by_id_identical(r_serial,r2a), 'serial vs 2 results')
    call require(result_sets_by_id_identical(r_serial,r4), 'serial vs 4 results')
    call require(result_sets_by_id_identical(r2a,r4), '2 vs 4 results')
    call require(diagnostics_by_id_semantically_identical(d_serial,d2a), 'serial vs 2 diagnostics')
    call require(diagnostics_by_id_semantically_identical(d_serial,d4), 'serial vs 4 diagnostics')
    call require(states_identical(s_serial,s2a) .and. states_identical(s_serial,s4), 'parallel state identity')
    call require(aggregate_semantically_identical(a_serial,a2a) .and. aggregate_semantically_identical(a_serial,a4), &
         'aggregate semantic identity')
    call require(runtime_semantically_identical(rt_serial,rt2a) .and. runtime_semantically_identical(rt_serial,rt4), &
         'runtime semantic identity')

    call require(result_sets_by_id_identical(r2a,r2b), 'A/B/A result replay')
    call require(diagnostics_by_id_fully_identical(d2a,d2b), 'A/B/A diagnostic replay')
    call require(states_identical(s2a,s2b), 'A/B/A state replay')
    call require(aggregate_fully_identical(a2a,a2b), 'A/B/A aggregate replay')
    call require(runtime_semantically_identical(rt2a,rt2b), 'A/B/A runtime replay')
    call require(parameters_identical(parameters,parameters_before), 'shared parameters immutable')
  end subroutine run_positive_case

  subroutine run_order_independence_case(n, batch_size)
    integer, intent(in) :: n, batch_size
    type(fmr_logical_column_t), allocatable :: base_columns(:), cols(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: s_ref(:), s(:)
    type(fmr_serialized_column_result_t), allocatable :: r_ref(:), r(:)
    type(fmr_column_diagnostics_t), allocatable :: d_ref(:), d(:)
    type(fmr_aggregate_diagnostics_t) :: a_ref, a
    type(fmr_serialized_batch_diagnostics_t) :: rt_ref, rt
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: order_code, dispatch_status, pool_status

    call build_fixture(n, base_columns, templates, parameters, forcings, seed, conductivity0)
    call configure_transaction(config)
    call initialize_states(s_ref, base_columns, seed)
    call permute_columns(base_columns,0,cols)
    call fmr_run_parallel_physical_multiswap(cols,templates,parameters,forcings,s_ref,config,top_provider,t0,t1,batch_size,4, &
         r_ref,d_ref,a_ref,dispatch_status,pool_status,rt_ref)
    call require(pool_status == FMR_PARALLEL_POOL_OK, 'order reference status')

    do order_code = 1, 3
      call initialize_states(s, base_columns, seed)
      call permute_columns(base_columns,order_code,cols)
      call fmr_run_parallel_physical_multiswap(cols,templates,parameters,forcings,s,config,top_provider,t0,t1,batch_size,4, &
           r,d,a,dispatch_status,pool_status,rt)
      call require(pool_status == FMR_PARALLEL_POOL_OK, 'order variant status')
      call require(result_sets_by_id_identical(r_ref,r), 'order result identity')
      call require(diagnostics_by_id_fully_identical(d_ref,d), 'order diagnostic identity')
      call require(states_identical(s_ref,s), 'order state identity')
      call require(aggregate_fully_identical(a_ref,a), 'order aggregate identity')
      call require(runtime_semantically_identical(rt_ref,rt), 'order runtime identity')
    end do
  end subroutine run_order_independence_case

  subroutine run_rejection_isolation_case(n, batch_size, rejected_positions, workers)
    integer, intent(in) :: n, batch_size, rejected_positions(:), workers
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), bad_forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: s_ref(:), s_bad(:), s_initial(:)
    type(fmr_serialized_column_result_t), allocatable :: r_ref(:), r_bad(:)
    type(fmr_column_diagnostics_t), allocatable :: d_ref(:), d_bad(:)
    type(fmr_aggregate_diagnostics_t) :: a_ref, a_bad
    type(fmr_serialized_batch_diagnostics_t) :: rt_ref, rt_bad
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: dispatch_status, pool_status, j, pos, idx
    logical :: should_reject

    call build_fixture(n, columns, templates, parameters, forcings, seed, conductivity0)
    bad_forcings = forcings
    do j = 1, size(rejected_positions)
      pos = rejected_positions(j)
      call require(pos >= 1 .and. pos <= n, 'rejection position valid')
      bad_forcings(pos)%top_flux = 0.95_real64*bad_forcings(pos)%top_flux
    end do
    call configure_transaction(config)
    call initialize_states(s_ref, columns, seed)
    call initialize_states(s_bad, columns, seed)
    call initialize_states(s_initial, columns, seed)

    call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,s_ref,config,top_provider,t0,t1,batch_size,workers, &
         r_ref,d_ref,a_ref,dispatch_status,pool_status,rt_ref)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. all_committed(r_ref), 'isolation reference')

    call fmr_run_parallel_physical_multiswap(columns,templates,parameters,bad_forcings,s_bad,config,top_provider,t0,t1,batch_size,workers, &
         r_bad,d_bad,a_bad,dispatch_status,pool_status,rt_bad)
    call require(pool_status == FMR_PARALLEL_POOL_OK, 'isolation perturbed status')
    call require(rt_bad%number_rejected == size(rejected_positions), 'rejection cardinality')
    call require(max_abs_residual(r_bad) <= hard_mass_gate, 'isolation committed mass')

    do j = 1, n
      should_reject = any(rejected_positions == j)
      idx = find_result_index(r_bad, columns(j)%column_id)
      call require(idx > 0, 'bad result id lookup')
      if (should_reject) then
        call require(.not. r_bad(idx)%committed, 'target rejected')
        call require(committed_state_identical(s_bad(j),s_initial(j)), 'rejected target rollback')
      else
        call require(r_bad(idx)%committed, 'unaffected target committed')
        call require(column_result_identical(r_ref(find_result_index(r_ref,columns(j)%column_id)),r_bad(idx)), 'unaffected result isolation')
        call require(committed_state_identical(s_ref(j),s_bad(j)), 'unaffected state isolation')
      end if
    end do
  end subroutine run_rejection_isolation_case

  subroutine run_unsupported_profile_matrix()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1), bad_templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1), bad_parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: states(:), initial(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: mode, workers, dispatch_status, pool_status

    call build_fixture(7, columns, templates, parameters, forcings, seed, conductivity0)
    call configure_transaction(config)
    do mode = 1, 5
      do workers = 2, 4, 2
        bad_parameters = parameters
        bad_templates = templates
        select case(mode)
        case(1)
          bad_parameters(1)%root_extraction_active = .true.
        case(2)
          bad_parameters(1)%snow_active = .true.
        case(3)
          bad_parameters(1)%bottom_mode = 5
        case(4)
          bad_templates(1)%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
        case(5)
          bad_parameters(1)%macropore_active = .true.
        end select
        call initialize_states(states,columns,seed)
        call initialize_states(initial,columns,seed)
        call fmr_run_parallel_physical_multiswap(columns,bad_templates,bad_parameters,forcings,states,config,top_provider,t0,t1,3,workers, &
             results,diagnostics,aggregate,dispatch_status,pool_status,runtime)
        call require(pool_status == FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED, 'unsupported profile pool status')
        call require(dispatch_status == -1, 'unsupported no serialized fallback')
        call require(runtime%physical_solve_count == 0 .and. runtime%number_committed == 0, 'unsupported zero physical solves')
        call require(all_no_solver_execution(results), 'unsupported solver not executed')
        call require(states_identical(states,initial), 'unsupported state nonmutation')
      end do
    end do
  end subroutine run_unsupported_profile_matrix

  subroutine run_overlap_control()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: dispatch_status, pool_status, workers

    call build_fixture(32,columns,templates,parameters,forcings,seed,conductivity0)
    call configure_transaction(config)
    do workers = 2, 4, 2
      call initialize_states(states,columns,seed)
      call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,states,config,top_provider,t0,t1,17,workers, &
           results,diagnostics,aggregate,dispatch_status,pool_status,runtime)
      call require(pool_status == FMR_PARALLEL_POOL_OK, 'overlap status')
      call require(runtime%max_simultaneous_real_physical_solves >= 2, 'real physical overlap observed')
      call require(runtime%max_simultaneous_real_physical_solves <= workers, 'overlap worker bound')
    end do
  end subroutine run_overlap_control

  subroutine build_fixture(n, columns, templates, parameters, forcings, seed, conductivity0)
    integer, intent(in) :: n
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), intent(out) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    type(fmr_b110_physical_state_t), intent(out) :: seed
    real(real64), intent(out) :: conductivity0
    integer :: j
    allocate(columns(n),forcings(n))
    call configure_template(templates(1))
    call configure_parameters(parameters(1),seed,conductivity0)
    do j = 1, n
      columns(j)%column_id = 926000_int64 + int(37*j,int64)
      columns(j)%template_id = templates(1)%template_id
      columns(j)%parameter_ref = 1_int64
      columns(j)%state_handle = int(j,int64)
      columns(j)%forcing_handle = int(j,int64)
      columns(j)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(forcings(j),conductivity0,1.0_real64+0.013_real64*real(j,real64))
    end do
  end subroutine build_fixture

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 9260_int64
    template%physics_topology_id = 926001_int64
    template%vertical_layout_id = 926002_int64
    template%state_layout_id = 926003_int64
    template%solver_interface_id = 926004_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(value,state,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: j
    value%parameter_set_id = 926001_int64
    value%active_nodes = numnod
    allocate(value%z(numnod),value%dz(numnod),value%node_distance(numnod),value%cofgen(24,numnod))
    value%z=z; value%dz=dz; value%node_distance=disnod(1:numnod); value%cofgen=0.0_real64
    do j=1,numnod
      value%cofgen(1,j)=0.032_real64; value%cofgen(2,j)=0.423_real64; value%cofgen(3,j)=4.75_real64
      value%cofgen(4,j)=0.0135_real64; value%cofgen(5,j)=0.365_real64; value%cofgen(6,j)=1.455_real64
      value%cofgen(7,j)=1.0_real64-1.0_real64/value%cofgen(6,j); value%cofgen(8,j)=value%cofgen(4,j)
      value%cofgen(10,j)=value%cofgen(3,j); value%cofgen(11,j)=0.999_real64; value%cofgen(12,j)=0.99_real64*value%cofgen(3,j)
      value%cofgen(22,j)=-1.0e6_real64; value%cofgen(23,j)=1.0e-12_real64
    end do
    value%bottom_mode=7; value%swkimpl=0; value%swkmean=1; value%swsophy=0
    value%root_extraction_active=.false.; value%macropore_active=.false.; value%snow_active=.false.
    value%hysteresis_active=.false.; value%tabulated_hydraulics_active=.false.; value%elasticity_active=.false.; value%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hyd_parameters,value%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hyd_parameters,t1-t0)
    heads=head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    conductivity0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing,conductivity0,scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0, scale
    integer :: j
    forcing%top_flux=-conductivity0; forcing%top_head=head0; forcing%bottom_flux=-conductivity0; forcing%bottom_head=-100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod),forcing%subsurface_irrigation_source(numnod),forcing%root_extraction_sink(numnod))
    do j=1,numnod
      forcing%drainage_flux_by_level(1,j)=scale*1.0e-5_real64*real(j,real64)
      forcing%drainage_flux_by_level(2,j)=-scale*2.0e-6_real64*real(j+1,real64)
      forcing%subsurface_irrigation_source(j)=forcing%drainage_flux_by_level(1,j)+forcing%drainage_flux_by_level(2,j)
      forcing%root_extraction_sink(j)=0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(value)
    type(canonical_numerical_config_t), intent(out) :: value
    value%transaction%temporal_tolerance=0.0_real64; value%transaction%mass_tolerance=hard_mass_gate
    value%transaction%retry_scale=0.5_real64; value%transaction%max_retries=2
    value%max_committed_substeps=8; value%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine initialize_states(states,base_columns,seed)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(fmr_logical_column_t), intent(in) :: base_columns(:)
    type(fmr_b110_physical_state_t), intent(in) :: seed
    type(fmr_b110_physical_state_t) :: state
    logical :: ok
    integer :: j
    allocate(states(size(base_columns)))
    do j=1,size(base_columns)
      state=seed
      state%groundwater_level=-2.0_real64-0.007_real64*real(j,real64)
      call fmr_new_b110_committed_state(states(j),base_columns(j)%column_id,state,t0,ok)
      call require(ok,'initialize committed state')
    end do
  end subroutine initialize_states

  subroutine permute_columns(base,code,ordered)
    type(fmr_logical_column_t), intent(in) :: base(:)
    integer, intent(in) :: code
    type(fmr_logical_column_t), allocatable, intent(out) :: ordered(:)
    integer, allocatable :: p(:)
    integer :: n,j,k,shift
    n=size(base); allocate(ordered(n),p(n))
    select case(code)
    case(0)
      p=[(j,j=1,n)]
    case(1)
      p=[(j,j=n,1,-1)]
    case(2)
      k=0
      do j=1,n,2; k=k+1; p(k)=j; end do
      do j=2,n,2; k=k+1; p(k)=j; end do
    case default
      shift=min(3,max(1,n-1))
      do j=1,n; p(j)=mod(j-1+shift,n)+1; end do
    end select
    ordered=base(p)
  end subroutine permute_columns

  logical function all_committed(results) result(ok)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    ok=.true.
    do j=1,size(results)
      if (.not.results(j)%completed .or. .not.results(j)%committed .or. .not.results(j)%mass%complete) then; ok=.false.; return; end if
    end do
  end function all_committed

  logical function all_no_solver_execution(results) result(ok)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    ok=.true.
    do j=1,size(results)
      if (results(j)%solver_executed .or. results(j)%committed) then; ok=.false.; return; end if
    end do
  end function all_no_solver_execution

  real(real64) function max_abs_residual(results) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    value=0.0_real64
    do j=1,size(results); if(results(j)%committed)value=max(value,abs(results(j)%mass%residual)); end do
  end function max_abs_residual

  integer function find_result_index(values,column_id) result(index)
    type(fmr_serialized_column_result_t), intent(in) :: values(:)
    integer(int64), intent(in) :: column_id
    integer :: j
    index=0
    do j=1,size(values); if(values(j)%column_id==column_id)then; index=j; return; end if; end do
  end function find_result_index

  integer function find_diag_index(values,column_id) result(index)
    type(fmr_column_diagnostics_t), intent(in) :: values(:)
    integer(int64), intent(in) :: column_id
    integer :: j
    index=0
    do j=1,size(values); if(values(j)%column_id==column_id)then; index=j; return; end if; end do
  end function find_diag_index

  logical function result_sets_by_id_identical(left,right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:),right(:)
    integer :: i,j
    equal=size(left)==size(right); if(.not.equal)return
    do i=1,size(left); j=find_result_index(right,left(i)%column_id); if(j<=0 .or. .not.column_result_identical(left(i),right(j)))then; equal=.false.; return; end if; end do
  end function result_sets_by_id_identical

  logical function column_result_identical(left,right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left,right
    equal=left%column_id==right%column_id .and. left%dispatch_ordinal==right%dispatch_ordinal .and. &
      same_bits(left%requested_t0,right%requested_t0) .and. same_bits(left%requested_t1,right%requested_t1) .and. &
      (left%admission_assessed.eqv.right%admission_assessed) .and. (left%admitted.eqv.right%admitted) .and. &
      trim(left%admission_status)==trim(right%admission_status) .and. left%kernel_status==right%kernel_status .and. &
      left%commit_status==right%commit_status .and. (left%completed.eqv.right%completed) .and. &
      (left%committed.eqv.right%committed) .and. (left%solver_executed.eqv.right%solver_executed) .and. &
      trim(left%solver_route)==trim(right%solver_route) .and. left%solver_iterations==right%solver_iterations .and. &
      left%accepted_substeps==right%accepted_substeps .and. left%solver_nonlinear_iterations==right%solver_nonlinear_iterations .and. &
      left%solver_internal_retries==right%solver_internal_retries .and. left%solver_headcalc_calls==right%solver_headcalc_calls .and. &
      left%solver_jacobian_builds==right%solver_jacobian_builds .and. left%solver_linear_solves==right%solver_linear_solves .and. &
      left%solver_backtracking_attempts==right%solver_backtracking_attempts .and. &
      left%solver_alternative_solver_calls==right%solver_alternative_solver_calls .and. &
      left%initial_revision==right%initial_revision .and. left%final_revision==right%final_revision .and. &
      same_bits(left%final_committed_time,right%final_committed_time) .and. &
      (left%final_committed_time_bound.eqv.right%final_committed_time_bound) .and. mass_identical(left%mass,right%mass)
  end function column_result_identical

  logical function mass_identical(left,right) result(equal)
    type(canonical_mass_accounting_t), intent(in) :: left,right
    equal=(left%complete.eqv.right%complete) .and. left%missing_contribution_mask==right%missing_contribution_mask .and. &
      left%origin_lineage_id==right%origin_lineage_id .and. left%origin_revision==right%origin_revision .and. &
      left%accepted_transaction_count==right%accepted_transaction_count .and. same_bits(left%interval_t0,right%interval_t0) .and. &
      same_bits(left%interval_t1,right%interval_t1) .and. same_bits(left%storage_start,right%storage_start) .and. &
      same_bits(left%storage_end,right%storage_end) .and. same_bits(left%storage_change,right%storage_change) .and. &
      same_bits(left%total_in,right%total_in) .and. same_bits(left%total_out,right%total_out) .and. same_bits(left%residual,right%residual)
  end function mass_identical

  logical function diagnostics_by_id_semantically_identical(left,right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left(:),right(:)
    integer :: i,j
    equal=size(left)==size(right); if(.not.equal)return
    do i=1,size(left); j=find_diag_index(right,left(i)%column_id); if(j<=0 .or. .not.diagnostic_semantic(left(i),right(j)))then; equal=.false.; return; end if; end do
  end function diagnostics_by_id_semantically_identical

  logical function diagnostics_by_id_fully_identical(left,right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left(:),right(:)
    integer :: i,j
    equal=diagnostics_by_id_semantically_identical(left,right); if(.not.equal)return
    do i=1,size(left)
      j=find_diag_index(right,left(i)%column_id)
      if(allocated(left(i)%worker_assignments).neqv.allocated(right(j)%worker_assignments))then; equal=.false.; return; end if
      if(allocated(left(i)%worker_assignments))then
        if(size(left(i)%worker_assignments)/=size(right(j)%worker_assignments))then; equal=.false.; return; end if
        if(any(left(i)%worker_assignments/=right(j)%worker_assignments))then; equal=.false.; return; end if
      end if
    end do
  end function diagnostics_by_id_fully_identical

  logical function diagnostic_semantic(left,right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left,right
    equal=left%column_id==right%column_id .and. left%template_id==right%template_id .and. left%backend==right%backend .and. &
      left%execution_class==right%execution_class .and. left%committed_revision==right%committed_revision .and. &
      same_bits(left%committed_time,right%committed_time) .and. (left%committed_time_bound.eqv.right%committed_time_bound) .and. &
      left%checkpoint_captures==right%checkpoint_captures .and. left%checkpoint_replays==right%checkpoint_replays .and. &
      left%runtime_attempts==right%runtime_attempts .and. left%attempts==right%attempts .and. left%retries==right%retries .and. &
      left%accepted==right%accepted .and. left%rejected==right%rejected .and. left%synthetic_cost==right%synthetic_cost .and. &
      trim(left%failure_classification)==trim(right%failure_classification) .and. &
      same_bits(left%unrounded_mass_residual,right%unrounded_mass_residual)
  end function diagnostic_semantic

  logical function aggregate_semantically_identical(left,right) result(equal)
    type(fmr_aggregate_diagnostics_t), intent(in) :: left,right
    equal=left%columns==right%columns .and. left%templates==right%templates .and. left%batches==right%batches .and. &
      left%attempts==right%attempts .and. left%retries==right%retries .and. left%failures==right%failures .and. &
      left%max_cost==right%max_cost .and. same_bits(left%mean_cost,right%mean_cost) .and. same_bits(left%p95_cost,right%p95_cost) .and. &
      same_bits(left%aggregate_unrounded_mass_residual,right%aggregate_unrounded_mass_residual)
  end function aggregate_semantically_identical

  logical function aggregate_fully_identical(left,right) result(equal)
    type(fmr_aggregate_diagnostics_t), intent(in) :: left,right
    equal=aggregate_semantically_identical(left,right) .and. left%workers==right%workers; if(.not.equal)return
    if(allocated(left%work_distribution).neqv.allocated(right%work_distribution))then; equal=.false.; return; end if
    if(allocated(left%work_distribution))then
      if(size(left%work_distribution)/=size(right%work_distribution))then; equal=.false.; return; end if
      equal=all(left%work_distribution==right%work_distribution)
    end if
  end function aggregate_fully_identical

  logical function runtime_semantically_identical(left,right) result(equal)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: left,right
    equal=left%number_requested==right%number_requested .and. left%number_admitted==right%number_admitted .and. &
      left%number_executed==right%number_executed .and. left%number_committed==right%number_committed .and. &
      left%number_rejected==right%number_rejected .and. left%physical_solve_count==right%physical_solve_count .and. &
      (left%deterministic_collection.eqv.right%deterministic_collection) .and. same_bits(left%effective_t0,right%effective_t0) .and. &
      same_bits(left%effective_t1,right%effective_t1) .and. same_bits(left%max_abs_column_mass_residual,right%max_abs_column_mass_residual) .and. &
      mass_identical(left%authoritative_aggregate_mass,right%authoritative_aggregate_mass)
  end function runtime_semantically_identical

  logical function states_identical(left,right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left(:),right(:)
    integer :: j
    equal=size(left)==size(right); if(.not.equal)return
    do j=1,size(left); if(.not.committed_state_identical(left(j),right(j)))then; equal=.false.; return; end if; end do
  end function states_identical

  logical function committed_state_identical(left,right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left,right
    real(real64) :: lt,rt
    logical :: la,ra
    equal=left%current_lineage_id()==right%current_lineage_id() .and. left%current_revision()==right%current_revision() .and. &
      committed_fingerprint(left)==committed_fingerprint(right); if(.not.equal)return
    call left%current_time(lt,la); call right%current_time(rt,ra)
    equal=(la.eqv.ra); if(equal.and.la)equal=same_bits(lt,rt)
  end function committed_state_identical

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: j
    call state%snapshot(snapshot,got); call require(got,'snapshot state')
    fp=1469598103934665603_int64
    select type(physical=>snapshot)
    class is(fmr_b110_physical_state_t)
      fp=ieor(fp,int(physical%active_nodes,int64))
      do j=1,physical%active_nodes
        fp=ieor(fp,transfer(physical%pressure_head(j),fp)); fp=ieor(fp,transfer(physical%water_content(j),fp))
      end do
      fp=ieor(fp,transfer(physical%ponding_depth,fp)); fp=ieor(fp,transfer(physical%groundwater_level,fp))
    class default
      error stop 'FMQ26 unexpected physical state type'
    end select
  end function committed_fingerprint

  logical function parameters_identical(left,right) result(equal)
    type(fmr_b110_physical_parameters_t), intent(in) :: left(:),right(:)
    equal=size(left)==size(right); if(.not.equal)return
    equal=left(1)%parameter_set_id==right(1)%parameter_set_id .and. left(1)%active_nodes==right(1)%active_nodes .and. &
      left(1)%bottom_mode==right(1)%bottom_mode .and. left(1)%swkimpl==right(1)%swkimpl .and. left(1)%swsophy==right(1)%swsophy .and. &
      (left(1)%root_extraction_active.eqv.right(1)%root_extraction_active) .and. &
      (left(1)%snow_active.eqv.right(1)%snow_active) .and. (left(1)%macropore_active.eqv.right(1)%macropore_active) .and. &
      all(left(1)%z==right(1)%z) .and. all(left(1)%dz==right(1)%dz) .and. &
      all(left(1)%node_distance==right(1)%node_distance) .and. all(left(1)%cofgen==right(1)%cofgen)
  end function parameters_identical

  logical function same_bits(left,right) result(equal)
    real(real64), intent(in) :: left,right
    equal=transfer(left,0_int64)==transfer(right,0_int64)
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
      write(*,'(A)') 'FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmq26_parallel_v1_admission

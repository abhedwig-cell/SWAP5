program test_fvq17_snow_multiswap_reference
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_snow_process, only: snow_state_t, snow_flux_result_t, snow_diagnostics_t, &
       evaluate_snow_reference_call, SNOW_OK
  implicit none

  integer, parameter :: PROFILE_INACTIVE = 0
  integer, parameter :: PROFILE_ACTIVE = 1
  integer, parameter :: PROFILE_MIXED = 2
  real(real64), parameter :: t0 = 2300.375_real64
  real(real64), parameter :: t1 = 2301.375_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  call verify_profile_matrix(PROFILE_INACTIVE, 'ALL_INACTIVE')
  call verify_profile_matrix(PROFILE_ACTIVE, 'ALL_ACTIVE')
  call verify_profile_matrix(PROFILE_MIXED, 'MIXED')
  call verify_order_case(17, PROFILE_ACTIVE, 'ACTIVE_REVERSE')
  call verify_order_case(17, PROFILE_MIXED, 'MIXED_REVERSE')
  call verify_repeat_case(2, PROFILE_ACTIVE, 'ACTIVE_ABA')
  call verify_repeat_case(17, PROFILE_MIXED, 'MIXED_ABA')
  call verify_runtime_fail_closed(0.5_real64, 'SUBDAILY')
  call verify_runtime_fail_closed(2.0_real64, 'MULTIDAY')

  write(*,'(A)') 'FVQ17_PROFILE_ALL_INACTIVE_1_2_17_31=PASS'
  write(*,'(A)') 'FVQ17_PROFILE_ALL_ACTIVE_1_2_17_31=PASS'
  write(*,'(A)') 'FVQ17_PROFILE_MIXED_1_2_17_31=PASS'
  write(*,'(A)') 'FVQ17_DIRECT_FVQ16_SNOW_STATE_IDENTITY=PASS'
  write(*,'(A)') 'FVQ17_NONZERO_MELT_INTERNAL_TRANSFER=PASS'
  write(*,'(A)') 'FVQ17_SNOW_INACTIVE_ZERO_STATE=PASS'
  write(*,'(A)') 'FVQ17_REVERSE_ORDER_COLUMN_IDENTITY=PASS'
  write(*,'(A)') 'FVQ17_REVERSE_ORDER_AGGREGATE_MASS_IDENTITY=PASS'
  write(*,'(A)') 'FVQ17_A_B_A_EXACT=PASS'
  write(*,'(A)') 'FVQ17_AUTHORITATIVE_MASS_COMPLETE=PASS'
  write(*,'(A)') 'FVQ17_SUBDAILY_RUNTIME_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ17_MULTIDAY_RUNTIME_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ17_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1'
  write(*,'(A)') 'FVQ17_INDEPENDENT_SNOW_MULTISWAP_REFERENCE PASS'

contains

  subroutine verify_profile_matrix(profile, label)
    integer, intent(in) :: profile
    character(len=*), intent(in) :: label
    call verify_profile_case(1, 1, profile, trim(label)//'_N1')
    call verify_profile_case(2, 2, profile, trim(label)//'_N2')
    call verify_profile_case(17, 7, profile, trim(label)//'_N17')
    call verify_profile_case(31, 11, profile, trim(label)//'_N31')
  end subroutine verify_profile_matrix

  subroutine verify_profile_case(n, batch_size, profile, label)
    integer, intent(in) :: n, batch_size, profile
    character(len=*), intent(in) :: label
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(snow_state_t), allocatable :: expected_snow(:)
    type(snow_flux_result_t), allocatable :: expected_flux(:)
    logical, allocatable :: active(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime_diag
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer :: dispatch_status, i, j

    call setup_case(n, profile, columns, templates, parameters, forcings, states, expected_snow, expected_flux, active)
    call configure_transaction(config)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &
         t0, t1, batch_size, results, diagnostics, aggregate, dispatch_status, runtime_diag)

    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, trim(label)//':dispatch')
    call require(runtime_diag%number_requested == n .and. runtime_diag%number_admitted == n, trim(label)//':admission counts')
    call require(runtime_diag%number_executed == n .and. runtime_diag%number_committed == n, trim(label)//':execution counts')
    call require(runtime_diag%number_rejected == 0, trim(label)//':rejected count')
    call require(runtime_diag%physical_solve_count == n, trim(label)//':physical solve count')
    call require(runtime_diag%max_simultaneous_real_physical_solves == 1, trim(label)//':serialized physical')
    call require(runtime_diag%deterministic_collection, trim(label)//':deterministic collection')
    call require(runtime_diag%authoritative_aggregate_mass%complete, trim(label)//':aggregate complete')
    call require(runtime_diag%authoritative_aggregate_mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
         trim(label)//':aggregate missing mask')
    call require(abs(runtime_diag%authoritative_aggregate_mass%residual) <= hard_mass_gate*real(max(1,n),real64), &
         trim(label)//':aggregate hard mass gate')
    call require(aggregate_matches_by_id(runtime_diag%authoritative_aggregate_mass, results, n), &
         trim(label)//':independent canonical aggregate')

    do i = 1, n
      j = result_index(results, column_id_for(i))
      call require(j > 0, trim(label)//':id binding')
      call require(results(j)%completed .and. results(j)%committed .and. results(j)%solver_executed, &
           trim(label)//':column completed')
      call require(results(j)%mass%complete .and. results(j)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
           trim(label)//':column mass complete')
      call require(abs(results(j)%mass%residual) <= hard_mass_gate, trim(label)//':column hard mass gate')
      call require(results(j)%final_revision == 1_int64 .and. results(j)%final_committed_time_bound, &
           trim(label)//':committed provenance')
      call require(same_bits(results(j)%final_committed_time,t1), trim(label)//':committed time')
      if (active(i)) then
        call require(state_matches_snow(states(i), expected_snow(i), t0), trim(label)//':direct snow state')
        if (i == 1) call require(expected_flux(i)%melt > 0.0_real64, trim(label)//':nonzero melt')
      else
        call require(state_has_no_snow(states(i)), trim(label)//':inactive no snow state')
      end if
    end do
  end subroutine verify_profile_case

  subroutine verify_order_case(n, profile, label)
    integer, intent(in) :: n, profile
    character(len=*), intent(in) :: label
    type(fmr_logical_column_t), allocatable :: columns_a(:), columns_b(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states_a(:), states_b(:)
    type(snow_state_t), allocatable :: expected_snow(:)
    type(snow_flux_result_t), allocatable :: expected_flux(:)
    logical, allocatable :: active(:)
    type(fmr_serialized_column_result_t), allocatable :: results_a(:), results_b(:)
    type(fmr_column_diagnostics_t), allocatable :: diag_a(:), diag_b(:)
    type(fmr_aggregate_diagnostics_t) :: agg_a, agg_b
    type(fmr_serialized_batch_diagnostics_t) :: run_a, run_b
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer :: status_a, status_b, i, ia, ib

    call setup_case_pair(n, profile, columns_a, templates, parameters, forcings, states_a, states_b, &
         expected_snow, expected_flux, active)
    allocate(columns_b(n))
    columns_b = columns_a(n:1:-1)
    call configure_transaction(config)

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns_a, templates, parameters, forcings, states_a, config, top_provider, &
         t0, t1, 7, results_a, diag_a, agg_a, status_a, run_a)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns_b, templates, parameters, forcings, states_b, config, top_provider, &
         t0, t1, 7, results_b, diag_b, agg_b, status_b, run_b)

    call require(status_a == FMR_SERIAL_DISPATCH_OK .and. status_b == FMR_SERIAL_DISPATCH_OK, trim(label)//':dispatch')
    call require(run_a%number_committed == n .and. run_b%number_committed == n, trim(label)//':commit counts')
    call require(run_a%max_simultaneous_real_physical_solves == 1 .and. &
         run_b%max_simultaneous_real_physical_solves == 1, trim(label)//':serialized')
    do i = 1, n
      ia = result_index(results_a, column_id_for(i))
      ib = result_index(results_b, column_id_for(i))
      call require(ia > 0 .and. ib > 0, trim(label)//':id lookup')
      call require(column_result_identical(results_a(ia),results_b(ib)), trim(label)//':result identity')
      call require(committed_fingerprint(states_a(i)) == committed_fingerprint(states_b(i)), trim(label)//':state identity')
    end do
    call require(mass_identical(run_a%authoritative_aggregate_mass,run_b%authoritative_aggregate_mass), &
         trim(label)//':aggregate mass identity')
    call require(aggregate_matches_by_id(run_a%authoritative_aggregate_mass, results_a, n), trim(label)//':aggregate A')
    call require(aggregate_matches_by_id(run_b%authoritative_aggregate_mass, results_b, n), trim(label)//':aggregate B')
  end subroutine verify_order_case

  subroutine verify_repeat_case(n, profile, label)
    integer, intent(in) :: n, profile
    character(len=*), intent(in) :: label
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states_a(:), states_b(:)
    type(snow_state_t), allocatable :: expected_snow(:)
    type(snow_flux_result_t), allocatable :: expected_flux(:)
    logical, allocatable :: active(:)
    type(fmr_serialized_column_result_t), allocatable :: results_a(:), results_b(:)
    type(fmr_column_diagnostics_t), allocatable :: diag_a(:), diag_b(:)
    type(fmr_aggregate_diagnostics_t) :: agg_a, agg_b
    type(fmr_serialized_batch_diagnostics_t) :: run_a, run_b
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer :: status_a, status_b, i, ia, ib

    call setup_case_pair(n, profile, columns, templates, parameters, forcings, states_a, states_b, &
         expected_snow, expected_flux, active)
    call configure_transaction(config)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states_a, config, top_provider, &
         t0, t1, max(1,min(7,n)), results_a, diag_a, agg_a, status_a, run_a)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states_b, config, top_provider, &
         t0, t1, max(1,min(7,n)), results_b, diag_b, agg_b, status_b, run_b)

    call require(status_a == FMR_SERIAL_DISPATCH_OK .and. status_b == FMR_SERIAL_DISPATCH_OK, trim(label)//':dispatch')
    do i = 1, n
      ia = result_index(results_a, column_id_for(i))
      ib = result_index(results_b, column_id_for(i))
      call require(column_result_identical(results_a(ia),results_b(ib)), trim(label)//':result identity')
      call require(committed_fingerprint(states_a(i)) == committed_fingerprint(states_b(i)), trim(label)//':state identity')
    end do
    call require(mass_identical(run_a%authoritative_aggregate_mass,run_b%authoritative_aggregate_mass), &
         trim(label)//':aggregate identity')
  end subroutine verify_repeat_case

  subroutine verify_runtime_fail_closed(dt, label)
    real(real64), intent(in) :: dt
    character(len=*), intent(in) :: label
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(snow_state_t), allocatable :: expected_snow(:)
    type(snow_flux_result_t), allocatable :: expected_flux(:)
    logical, allocatable :: active(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime_diag
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    integer :: dispatch_status
    integer(int64) :: before_fp, after_fp

    call setup_case(1, PROFILE_ACTIVE, columns, templates, parameters, forcings, states, &
         expected_snow, expected_flux, active)
    call configure_transaction(config)
    before_fp = committed_fingerprint(states(1))
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &
         t0, t0+dt, 1, results, diagnostics, aggregate, dispatch_status, runtime_diag)
    after_fp = committed_fingerprint(states(1))
    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, trim(label)//':dispatcher stays valid')
    call require(size(results) == 1 .and. .not. results(1)%committed, trim(label)//':not committed')
    call require(runtime_diag%number_committed == 0 .and. runtime_diag%number_rejected == 1, trim(label)//':rejected')
    call require(before_fp == after_fp, trim(label)//':committed state unchanged')
  end subroutine verify_runtime_fail_closed

  subroutine setup_case(n, profile, columns, templates, parameters, forcings, states, expected_snow, expected_flux, active)
    integer, intent(in) :: n, profile
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), intent(out) :: templates(1)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(snow_state_t), allocatable, intent(out) :: expected_snow(:)
    type(snow_flux_result_t), allocatable, intent(out) :: expected_flux(:)
    logical, allocatable, intent(out) :: active(:)
    type(fmr_b110_physical_state_t) :: initial_state
    type(snow_diagnostics_t) :: snow_diag
    real(real64) :: conductivity0
    logical :: ok
    integer :: i

    allocate(columns(n),parameters(n),forcings(n),states(n),expected_snow(n),expected_flux(n),active(n))
    call configure_template(templates(1))
    do i = 1, n
      active(i) = profile_active(profile,i)
      call configure_parameters(parameters(i),initial_state,conductivity0,active(i),i)
      call configure_forcing(forcings(i),conductivity0,active(i),i)
      if (active(i)) then
        call evaluate_snow_reference_call(parameters(i)%snow, initial_state%snow%process, forcings(i)%snow, &
             t0, t1, expected_snow(i), expected_flux(i), snow_diag)
        call require(snow_diag%status == SNOW_OK .and. snow_diag%mass%available, 'setup direct F-VQ16 snow')
        call balance_melt_top_flux(parameters(i),initial_state,forcings(i),conductivity0)
      end if
      call configure_column(columns(i),templates(1),i)
      call fmr_new_b110_committed_state(states(i),columns(i)%column_id,initial_state,t0,ok)
      call require(ok,'setup committed state')
    end do
  end subroutine setup_case

  subroutine setup_case_pair(n, profile, columns, templates, parameters, forcings, states_a, states_b, &
                             expected_snow, expected_flux, active)
    integer, intent(in) :: n, profile
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), intent(out) :: templates(1)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states_a(:), states_b(:)
    type(snow_state_t), allocatable, intent(out) :: expected_snow(:)
    type(snow_flux_result_t), allocatable, intent(out) :: expected_flux(:)
    logical, allocatable, intent(out) :: active(:)
    type(fmr_b110_physical_state_t) :: initial_state
    type(snow_diagnostics_t) :: snow_diag
    real(real64) :: conductivity0
    logical :: ok
    integer :: i

    allocate(columns(n),parameters(n),forcings(n),states_a(n),states_b(n),expected_snow(n),expected_flux(n),active(n))
    call configure_template(templates(1))
    do i = 1, n
      active(i) = profile_active(profile,i)
      call configure_parameters(parameters(i),initial_state,conductivity0,active(i),i)
      call configure_forcing(forcings(i),conductivity0,active(i),i)
      if (active(i)) then
        call evaluate_snow_reference_call(parameters(i)%snow,initial_state%snow%process,forcings(i)%snow, &
             t0,t1,expected_snow(i),expected_flux(i),snow_diag)
        call require(snow_diag%status == SNOW_OK .and. snow_diag%mass%available,'pair direct F-VQ16 snow')
        call balance_melt_top_flux(parameters(i),initial_state,forcings(i),conductivity0)
      end if
      call configure_column(columns(i),templates(1),i)
      call fmr_new_b110_committed_state(states_a(i),columns(i)%column_id,initial_state,t0,ok)
      call require(ok,'pair state A')
      call fmr_new_b110_committed_state(states_b(i),columns(i)%column_id,initial_state,t0,ok)
      call require(ok,'pair state B')
    end do
  end subroutine setup_case_pair

  logical function profile_active(profile,i) result(active)
    integer, intent(in) :: profile, i
    select case(profile)
    case(PROFILE_INACTIVE)
      active = .false.
    case(PROFILE_ACTIVE)
      active = .true.
    case(PROFILE_MIXED)
      active = mod(i,2) == 1
    case default
      active = .false.
    end select
  end function profile_active

  integer(int64) function column_id_for(i) result(id)
    integer, intent(in) :: i
    id = 717000_int64 + int(i,int64)
  end function column_id_for

  subroutine configure_column(c, tmpl, i)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(in) :: tmpl
    integer, intent(in) :: i
    c%column_id = column_id_for(i)
    c%template_id = tmpl%template_id
    c%parameter_ref = int(i,int64)
    c%state_handle = int(i,int64)
    c%forcing_handle = int(i,int64)
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_template(tmpl)
    type(fmr_template_t), intent(out) :: tmpl
    tmpl%template_id = 717_int64
    tmpl%physics_topology_id = 71701_int64
    tmpl%vertical_layout_id = 71702_int64
    tmpl%state_layout_id = 71703_int64
    tmpl%solver_interface_id = 71704_int64
    tmpl%optional_state_layout_id = 71705_int64
    tmpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(p,state,conductivity0,active,i)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    logical, intent(in) :: active
    integer, intent(in) :: i
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id = 71700_int64 + int(i,int64)
    p%active_nodes = numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=active
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    if (active) then
      allocate(p%snow)
      if (i == 1) then
        p%snow%suppress_sublimation=0; p%snow%melt_coefficient=0.15_real64
      else
        p%snow%suppress_sublimation=1; p%snow%melt_coefficient=0.12_real64
      end if
    end if

    call initialize_b110_default_mvg_parameters(hyd_parameters,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hyd_parameters,t1-t0)
    heads=head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    conductivity0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    if (active) then
      allocate(state%snow)
      if (i == 1) then
        state%snow%process=snow_state_t(3.0_real64,0.1_real64)
      else
        state%snow%process=snow_state_t(1.5_real64,0.05_real64)
      end if
      state%snow%event_applied=.false.; state%snow%event_t0=0.0_real64
    end if
  end subroutine configure_parameters

  subroutine configure_forcing(f,conductivity0,active,i)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity0
    logical, intent(in) :: active
    integer, intent(in) :: i
    integer :: k
    f%top_flux=-conductivity0; f%top_head=head0; f%bottom_flux=-conductivity0; f%bottom_head=-100.0_real64
    allocate(f%drainage_flux_by_level(2,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    do k=1,numnod
      f%drainage_flux_by_level(1,k)=1.0e-5_real64*real(k,real64)
      f%drainage_flux_by_level(2,k)=-2.0e-6_real64*real(k+1,real64)
      f%subsurface_irrigation_source(k)=f%drainage_flux_by_level(1,k)+f%drainage_flux_by_level(2,k)
      f%root_extraction_sink(k)=0.0_real64
    end do
    if (active) then
      allocate(f%snow)
      if (i == 1) then
        f%snow%snowfall_input=0.4_real64; f%snow%rain_on_snow_input=0.1_real64
        f%snow%soil_surface_temperature=0.0_real64; f%snow%mean_air_temperature=2.0_real64
        f%snow%potential_soil_evaporation=0.2_real64; f%snow%reduced_soil_evaporation=0.15_real64
        f%snow%ponding_evaporation=0.25_real64
      else
        f%snow%snowfall_input=0.2_real64; f%snow%rain_on_snow_input=0.15_real64
        f%snow%soil_surface_temperature=0.0_real64; f%snow%mean_air_temperature=1.5_real64
        f%snow%potential_soil_evaporation=0.3_real64; f%snow%reduced_soil_evaporation=0.2_real64
        f%snow%ponding_evaporation=0.1_real64
      end if
    end if
  end subroutine configure_forcing

  subroutine balance_melt_top_flux(p,state,f,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(fmr_b110_physical_forcing_t), intent(inout) :: f
    real(real64), intent(in) :: conductivity0
    type(snow_state_t) :: candidate
    type(snow_flux_result_t) :: fluxes
    type(snow_diagnostics_t) :: diagnostics
    call evaluate_snow_reference_call(p%snow,state%snow%process,f%snow,t0,t1,candidate,fluxes,diagnostics)
    call require(diagnostics%status == SNOW_OK .and. diagnostics%mass%available,'balance direct snow')
    f%top_flux = -conductivity0 + fluxes%melt/(t1-t0)
  end subroutine balance_melt_top_flux

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=2
    cfg%max_committed_substeps=8
    cfg%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra=12345.0_real64
    legacy_qssdi=-54321.0_real64
    legacy_qrot=0.0_real64
    swmacro=0
    legacy_melt=0.0_real64
  end subroutine reset_legacy_globals

  integer function result_index(results,id) result(idx)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: id
    integer :: i
    idx=0
    do i=1,size(results)
      if(results(i)%column_id == id) then
        idx=i
        return
      end if
    end do
  end function result_index

  logical function state_matches_snow(state,expected,expected_t0) result(matches)
    type(kernel_committed_state_t), intent(in) :: state
    type(snow_state_t), intent(in) :: expected
    real(real64), intent(in) :: expected_t0
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot,got)
    matches=.false.
    if(.not.got) return
    select type(p=>snapshot)
    type is(fmr_b110_physical_state_t)
      if(.not.allocated(p%snow)) return
      matches=same_bits(p%snow%process%snow_water_storage,expected%snow_water_storage) .and. &
           same_bits(p%snow%process%liquid_water_storage,expected%liquid_water_storage) .and. &
           p%snow%event_applied .and. same_bits(p%snow%event_t0,expected_t0)
    end select
  end function state_matches_snow

  logical function state_has_no_snow(state) result(no_snow)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot,got)
    no_snow=.false.
    if(.not.got) return
    select type(p=>snapshot)
    type is(fmr_b110_physical_state_t)
      no_snow=.not.allocated(p%snow)
    end select
  end function state_has_no_snow

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: i
    call state%snapshot(snapshot,got)
    call require(got,'fingerprint snapshot')
    fp=1469598103934665603_int64
    select type(p=>snapshot)
    type is(fmr_b110_physical_state_t)
      do i=1,p%active_nodes
        fp=ieor(fp,transfer(p%pressure_head(i),fp))
        fp=ieor(fp,transfer(p%water_content(i),fp))
      end do
      fp=ieor(fp,transfer(p%ponding_depth,fp))
      fp=ieor(fp,transfer(p%groundwater_level,fp))
      if(allocated(p%snow)) then
        fp=ieor(fp,transfer(p%snow%process%snow_water_storage,fp))
        fp=ieor(fp,transfer(p%snow%process%liquid_water_storage,fp))
        fp=ieor(fp,merge(1_int64,0_int64,p%snow%event_applied))
        fp=ieor(fp,transfer(p%snow%event_t0,fp))
      end if
    class default
      error stop 'FVQ17 unexpected committed state type'
    end select
  end function committed_fingerprint

  logical function aggregate_matches_by_id(agg,results,n) result(matches)
    type(canonical_mass_accounting_t), intent(in) :: agg
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer, intent(in) :: n
    type(canonical_mass_accounting_t) :: expected
    integer :: i,j
    expected=canonical_mass_accounting_t()
    expected%complete=.true.
    expected%missing_contribution_mask=TX_MASS_MISSING_NONE
    expected%interval_t0=t0
    expected%interval_t1=t1
    do i=1,n
      j=result_index(results,column_id_for(i))
      if(j <= 0 .or. .not.results(j)%committed) then
        matches=.false.
        return
      end if
      expected%accepted_transaction_count=expected%accepted_transaction_count+results(j)%mass%accepted_transaction_count
      expected%storage_start=expected%storage_start+results(j)%mass%storage_start
      expected%storage_end=expected%storage_end+results(j)%mass%storage_end
      expected%storage_change=expected%storage_change+results(j)%mass%storage_change
      expected%total_in=expected%total_in+results(j)%mass%total_in
      expected%total_out=expected%total_out+results(j)%mass%total_out
      expected%residual=expected%residual+results(j)%mass%residual
    end do
    matches=agg%complete .and. agg%missing_contribution_mask==TX_MASS_MISSING_NONE .and. &
         agg%accepted_transaction_count==expected%accepted_transaction_count .and. &
         same_bits(agg%storage_start,expected%storage_start) .and. same_bits(agg%storage_end,expected%storage_end) .and. &
         same_bits(agg%storage_change,expected%storage_change) .and. same_bits(agg%total_in,expected%total_in) .and. &
         same_bits(agg%total_out,expected%total_out) .and. same_bits(agg%residual,expected%residual)
  end function aggregate_matches_by_id

  logical function column_result_identical(a,b) result(same)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    same=a%column_id==b%column_id .and. a%admission_assessed.eqv.b%admission_assessed .and. &
         a%admitted.eqv.b%admitted .and. trim(a%admission_status)==trim(b%admission_status) .and. &
         a%kernel_status==b%kernel_status .and. a%commit_status==b%commit_status .and. &
         a%completed.eqv.b%completed .and. a%committed.eqv.b%committed .and. &
         a%solver_executed.eqv.b%solver_executed .and. trim(a%solver_route)==trim(b%solver_route) .and. &
         a%solver_iterations==b%solver_iterations .and. a%initial_revision==b%initial_revision .and. &
         a%final_revision==b%final_revision .and. a%final_committed_time_bound.eqv.b%final_committed_time_bound .and. &
         same_bits(a%final_committed_time,b%final_committed_time) .and. mass_identical(a%mass,b%mass)
  end function column_result_identical

  logical function mass_identical(a,b) result(same)
    type(canonical_mass_accounting_t), intent(in) :: a,b
    same=a%complete.eqv.b%complete .and. a%missing_contribution_mask==b%missing_contribution_mask .and. &
         a%accepted_transaction_count==b%accepted_transaction_count .and. same_bits(a%interval_t0,b%interval_t0) .and. &
         same_bits(a%interval_t1,b%interval_t1) .and. same_bits(a%storage_start,b%storage_start) .and. &
         same_bits(a%storage_end,b%storage_end) .and. same_bits(a%storage_change,b%storage_change) .and. &
         same_bits(a%total_in,b%total_in) .and. same_bits(a%total_out,b%total_out) .and. same_bits(a%residual,b%residual)
  end function mass_identical

  logical function same_bits(a,b) result(same)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    same=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'FVQ17_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq17_snow_multiswap_reference

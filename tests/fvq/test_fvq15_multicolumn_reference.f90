program test_fvq15_multicolumn_reference
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: ncases = 4
  integer, parameter :: cases(ncases) = [1, 2, 17, 31]

  type(fmr_serialized_column_result_t), allocatable :: canonical_results(:), reverse_results(:), a_again(:)
  type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate
  type(fmr_serialized_batch_diagnostics_t) :: runtime_diag
  type(kernel_committed_state_t), allocatable :: states(:)
  integer :: k, status, n

  do k = 1, ncases
    n = cases(k)
    call run_multi_case(n, .false., n, canonical_results, diagnostics, aggregate, runtime_diag, states, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'canonical dispatch status')
    call validate_runtime_batch(canonical_results, runtime_diag, n)
    call verify_all_against_direct(canonical_results, states, n)

    call run_multi_case(n, .true., 1, reverse_results, diagnostics, aggregate, runtime_diag, states, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'reverse dispatch status')
    call validate_runtime_batch(reverse_results, runtime_diag, n)
    call verify_all_against_direct(reverse_results, states, n)
    call require(result_sets_identical(canonical_results, reverse_results), 'canonical/reverse result identity')

    write(*,'(A,I0,A)') 'FVQ15_DIRECT_REFERENCE_COLUMNS_', n, '=PASS'
    write(*,'(A,I0,A)') 'FVQ15_REVERSE_ORDER_COLUMNS_', n, '=PASS'
  end do

  call run_multi_case(2, .false., 2, canonical_results, diagnostics, aggregate, runtime_diag, states, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'A/B repeatability baseline')
  call run_multi_case(1, .false., 1, a_again, diagnostics, aggregate, runtime_diag, states, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'A repeat')
  call require(column_results_identical(result_for_id(canonical_results, 505001_int64), a_again(1)), &
       'A/B/A exact repeatability')

  write(*,'(A)') 'FVQ15_A_B_A_EXACT=PASS'
  write(*,'(A)') 'FVQ15_GENERIC_TIME_1000_125_TO_1000_625=PASS'
  write(*,'(A)') 'FVQ15_MAX_SCIENTIFIC_DIFFERENCE=0.0'
  write(*,'(A)') 'FVQ15_MULTICOLUMN_DIRECT_REFERENCE_TEST PASS'

contains

  subroutine run_multi_case(n, reverse_order, batch_size, results, diag, agg, rdiag, states_out, dispatch_status)
    integer, intent(in) :: n, batch_size
    logical, intent(in) :: reverse_order
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diag(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: agg
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: rdiag
    type(kernel_committed_state_t), allocatable, intent(out) :: states_out(:)
    integer, intent(out) :: dispatch_status

    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(fmr_logical_column_t) :: tmp
    real(real64) :: conductivity0
    logical :: ok
    integer :: i, left, right

    call configure_template(templates(1))
    call configure_parameters(parameters(1), initial_state, conductivity0)
    call configure_transaction(config)
    allocate(columns(n), forcings(n), states_out(n))

    do i = 1, n
      columns(i)%column_id = 505000_int64 + int(i,int64)
      columns(i)%template_id = templates(1)%template_id
      columns(i)%parameter_ref = 1_int64
      columns(i)%state_handle = int(i,int64)
      columns(i)%forcing_handle = int(i,int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
      call fmr_new_b110_committed_state(states_out(i), columns(i)%column_id, initial_state, t0, ok)
      call require(ok, 'multi committed state init')
    end do

    if (reverse_order) then
      do left = 1, n/2
        right = n + 1 - left
        tmp = columns(left)
        columns(left) = columns(right)
        columns(right) = tmp
      end do
    end if

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states_out, config, &
         top_provider, t0, t1, batch_size, results, diag, agg, dispatch_status, rdiag)
  end subroutine run_multi_case

  subroutine validate_runtime_batch(results, rdiag, n)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: rdiag
    integer, intent(in) :: n
    type(canonical_mass_accounting_t) :: expected
    integer :: i

    call require(size(results) == n, 'result count')
    call require(rdiag%number_requested == n, 'requested count')
    call require(rdiag%number_admitted == n, 'admitted count')
    call require(rdiag%number_executed == n, 'executed count')
    call require(rdiag%number_committed == n, 'committed count')
    call require(rdiag%number_rejected == 0, 'rejected count')
    call require(rdiag%physical_solve_count == n, 'physical solve count')
    call require(rdiag%max_simultaneous_real_physical_solves == 1, 'max simultaneous physical solves')
    call require(rdiag%deterministic_collection, 'deterministic collection')
    call require(same_bits(rdiag%effective_t0,t0) .and. same_bits(rdiag%effective_t1,t1), 'generic interval')
    call require(rdiag%authoritative_aggregate_mass%complete, 'aggregate mass complete')
    call require(rdiag%authoritative_aggregate_mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
         'aggregate missing mask zero')
    call require(rdiag%max_abs_column_mass_residual <= hard_mass_gate, 'aggregate maximum residual hard gate')

    call expected_aggregate(results, expected)
    call require(aggregate_mass_identical(rdiag%authoritative_aggregate_mass, expected), &
         'aggregate authoritative unrounded terms exact')

    do i = 1, size(results)
      call require(results(i)%admission_assessed .and. results(i)%admitted, 'column admitted')
      call require(results(i)%completed .and. results(i)%committed, 'column committed')
      call require(results(i)%solver_executed, 'column real solver executed')
      call require(trim(results(i)%solver_route) == 'legacy-reference-bound', 'column solver route')
      call require(results(i)%mass%complete, 'column mass complete')
      call require(results(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'column missing mask zero')
      call require(abs(results(i)%mass%residual) <= hard_mass_gate, 'column residual hard gate')
      call require(same_bits(results(i)%mass%interval_t0,t0) .and. same_bits(results(i)%mass%interval_t1,t1), &
           'column mass interval')
    end do
  end subroutine validate_runtime_batch

  subroutine verify_all_against_direct(multires, multistates, n)
    type(fmr_serialized_column_result_t), intent(in) :: multires(:)
    type(kernel_committed_state_t), intent(in) :: multistates(:)
    integer, intent(in) :: n

    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(kernel_committed_state_t), allocatable :: direct_states(:)
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr_serialized_physical_observation_t) :: observation
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: direct_result
    type(kernel_diagnostics_t) :: direct_diag
    type(kernel_executor_t) :: tx
    type(fmr_logical_column_t) :: column
    real(real64) :: conductivity0
    logical :: ok, did_commit
    integer :: i, j, commit_status

    call configure_template(template)
    call configure_parameters(parameters, initial_state, conductivity0)
    call configure_transaction(config)
    allocate(direct_states(n))

    do i = 1, n
      column = fmr_logical_column_t()
      column%column_id = 505000_int64 + int(i,int64)
      column%template_id = template%template_id
      column%parameter_ref = 1_int64
      column%state_handle = int(i,int64)
      column%forcing_handle = int(i,int64)
      column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(forcing, conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
      call fmr_new_b110_committed_state(direct_states(i), column%column_id, initial_state, t0, ok)
      call require(ok, 'direct committed state init')
      call reset_legacy_globals()
      call backend%initialize(top_provider)
      call fmr_capture_checkpoint(direct_states(i), checkpoint, ok)
      call require(ok, 'direct checkpoint')
      call backend%run_trial(column, template, parameters, direct_states(i), forcing, config, t0, t1, checkpoint, &
           direct_result, candidate, direct_diag)
      call require(direct_result%completed .and. candidate%ready(), 'direct physical trial')
      observation = backend%observation()
      call require(observation%solver_executed, 'direct real solver executed')
      call fmr_commit_candidate(tx, direct_states(i), candidate, direct_diag, did_commit, commit_status)
      call require(did_commit, 'direct commit')

      j = result_index(multires, column%column_id)
      call require(j > 0, 'multicolumn result id binding')
      call require(multires(j)%kernel_status == direct_result%status, 'direct kernel status identity')
      call require(multires(j)%commit_status == commit_status, 'direct commit status identity')
      call require(trim(multires(j)%solver_route) == trim(observation%solver_diagnostics%route), &
           'direct solver route identity')
      call require(multires(j)%solver_iterations == observation%solver_diagnostics%nonlinear_iterations, &
           'direct solver iteration identity')
      call require(mass_identical(multires(j)%mass, direct_result%mass), 'direct canonical mass bitwise identity')
      call require(committed_fingerprint(multistates(i)) == committed_fingerprint(direct_states(i)), &
           'direct committed physical state bitwise identity')
      call require(multistates(i)%current_revision() == direct_states(i)%current_revision(), &
           'direct revision identity')
    end do
  end subroutine verify_all_against_direct

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 505_int64
    template%physics_topology_id = 50501_int64
    template%vertical_layout_id = 50502_int64
    template%state_layout_id = 50503_int64
    template%solver_interface_id = 50504_int64
    template%optional_state_layout_id = 0_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(p, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    p%parameter_set_id = 50501_int64
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
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)
    call require(all(conductivity == conductivity0), 'uniform conductivity fixture')

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing, conductivity0, scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0, scale
    integer :: i

    forcing%top_flux = -conductivity0
    forcing%top_head = head0
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = scale*1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -scale*2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
                                                forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals

  subroutine expected_aggregate(results, mass)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(canonical_mass_accounting_t), intent(out) :: mass
    integer :: i

    mass = canonical_mass_accounting_t()
    mass%complete = .true.
    mass%interval_t0 = t0
    mass%interval_t1 = t1
    mass%missing_contribution_mask = TX_MASS_MISSING_NONE
    do i = 1, size(results)
      if (.not. results(i)%committed) cycle
      mass%accepted_transaction_count = mass%accepted_transaction_count + results(i)%mass%accepted_transaction_count
      mass%storage_start = mass%storage_start + results(i)%mass%storage_start
      mass%storage_end = mass%storage_end + results(i)%mass%storage_end
      mass%storage_change = mass%storage_change + results(i)%mass%storage_change
      mass%total_in = mass%total_in + results(i)%mass%total_in
      mass%total_out = mass%total_out + results(i)%mass%total_out
      mass%residual = mass%residual + results(i)%mass%residual
    end do
  end subroutine expected_aggregate

  logical function aggregate_mass_identical(a,b)
    type(canonical_mass_accounting_t), intent(in) :: a,b
    aggregate_mass_identical = a%complete .eqv. b%complete
    if (.not. aggregate_mass_identical) return
    aggregate_mass_identical = a%missing_contribution_mask == b%missing_contribution_mask .and. &
         a%accepted_transaction_count == b%accepted_transaction_count .and. &
         same_bits(a%interval_t0,b%interval_t0) .and. same_bits(a%interval_t1,b%interval_t1) .and. &
         same_bits(a%storage_start,b%storage_start) .and. same_bits(a%storage_end,b%storage_end) .and. &
         same_bits(a%storage_change,b%storage_change) .and. same_bits(a%total_in,b%total_in) .and. &
         same_bits(a%total_out,b%total_out) .and. same_bits(a%residual,b%residual)
  end function aggregate_mass_identical

  logical function mass_identical(a,b)
    type(canonical_mass_accounting_t), intent(in) :: a,b
    mass_identical = a%complete .eqv. b%complete
    if (.not. mass_identical) return
    mass_identical = a%missing_contribution_mask == b%missing_contribution_mask .and. &
         a%origin_lineage_id == b%origin_lineage_id .and. a%origin_revision == b%origin_revision .and. &
         a%accepted_transaction_count == b%accepted_transaction_count .and. &
         same_bits(a%interval_t0,b%interval_t0) .and. same_bits(a%interval_t1,b%interval_t1) .and. &
         same_bits(a%storage_start,b%storage_start) .and. same_bits(a%storage_end,b%storage_end) .and. &
         same_bits(a%storage_change,b%storage_change) .and. same_bits(a%total_in,b%total_in) .and. &
         same_bits(a%total_out,b%total_out) .and. same_bits(a%residual,b%residual)
  end function mass_identical

  logical function result_sets_identical(left,right)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: i, j
    result_sets_identical = size(left) == size(right)
    if (.not. result_sets_identical) return
    do i = 1, size(left)
      j = result_index(right,left(i)%column_id)
      if (j == 0 .or. .not. column_results_identical(left(i),right(j))) then
        result_sets_identical = .false.
        return
      end if
    end do
  end function result_sets_identical

  logical function column_results_identical(a,b)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    column_results_identical = a%column_id == b%column_id .and. a%kernel_status == b%kernel_status .and. &
         a%commit_status == b%commit_status .and. a%completed .eqv. b%completed .and. &
         a%committed .eqv. b%committed .and. a%solver_executed .eqv. b%solver_executed .and. &
         trim(a%solver_route) == trim(b%solver_route) .and. a%solver_iterations == b%solver_iterations .and. &
         a%initial_revision == b%initial_revision .and. a%final_revision == b%final_revision .and. &
         same_bits(a%final_committed_time,b%final_committed_time) .and. mass_identical(a%mass,b%mass)
  end function column_results_identical

  function result_for_id(results,id) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: id
    type(fmr_serialized_column_result_t) :: value
    integer :: j
    j = result_index(results,id)
    call require(j > 0, 'result id lookup')
    value = results(j)
  end function result_for_id

  integer function result_index(results,id)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: id
    integer :: i
    result_index = 0
    do i = 1, size(results)
      if (results(i)%column_id == id) then
        result_index = i
        return
      end if
    end do
  end function result_index

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: i

    call state%snapshot(snapshot,got)
    call require(got,'state snapshot')
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = ieor(fp,int(physical%active_nodes,int64))
      do i = 1, physical%active_nodes
        fp = ieor(fp,transfer(physical%pressure_head(i),fp))
        fp = ieor(fp,transfer(physical%water_content(i),fp))
      end do
      fp = ieor(fp,transfer(physical%ponding_depth,fp))
      fp = ieor(fp,transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-VQ15 unexpected physical state type'
    end select
  end function committed_fingerprint

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
      write(*,'(A,1X,A)') 'FVQ15_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq15_multicolumn_reference

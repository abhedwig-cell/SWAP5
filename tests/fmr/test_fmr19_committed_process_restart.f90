program test_fmr19_committed_process_restart
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_committed_restart, only: fmr_committed_restart_record_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_DUPLICATE_COLUMN, &
       FMR_RESTART_TEMPLATE_MISMATCH, FMR_RESTART_PARAMETER_MISMATCH, &
       FMR_RESTART_TARGET_ALREADY_INITIALIZED, FMR_RESTART_SCHEMA_MISMATCH
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: nfull = 32
  integer, parameter :: nmatrix = 5
  integer, parameter :: batch_sizes(nmatrix) = [1, 2, 8, 17, 32]
  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: t2 = 1001.125_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t), allocatable :: columns(:)
  type(fmr_template_t) :: templates(2)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t), allocatable :: continuous_states(:)
  type(fmr_serialized_column_result_t), allocatable :: continuous_first(:), continuous_second(:)
  type(fmr_column_diagnostics_t), allocatable :: diag(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate
  real(real64) :: conductivity0
  integer :: i, status

  call configure_templates(templates)
  call configure_parameters(parameters(1), initial_state, conductivity0)
  call configure_transaction(config)
  call build_columns_and_forcing(columns, forcings, conductivity0)
  call initialize_states(columns, initial_state, continuous_states)

  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, continuous_states, config, &
       top_provider, t0, t1, 8, continuous_first, diag, aggregate, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'continuous first dispatch')
  call require(all_committed(continuous_first), 'continuous first all committed')
  call require(all_mass_complete(continuous_first), 'continuous first mass complete')

  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, continuous_states, config, &
       top_provider, t1, t2, 8, continuous_second, diag, aggregate, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'continuous second dispatch')
  call require(all_committed(continuous_second), 'continuous second all committed')
  call require(all_mass_complete(continuous_second), 'continuous second mass complete')

  do i = 1, nmatrix
    call execute_restart_case(batch_sizes(i), columns, templates, parameters, forcings, initial_state, config, &
         top_provider, continuous_states, continuous_second)
    write(*,'(A,I0,A)') 'FMR19_BATCH_SIZE_', batch_sizes(i), '=PASS'
  end do

  write(*,'(A)') 'FMR19_REAL_PHYSICS_RESTART_MATRIX_1_2_8_17_32=PASS'
  write(*,'(A)') 'FMR19_COMMITTED_PROCESS_RESTART_TEST PASS'

contains

  subroutine execute_restart_case(batch_size, base_columns, templates, parameters, forcings, initial_state, config, &
                                  top_provider, reference_states, reference_second)
    integer, intent(in) :: batch_size
    type(fmr_logical_column_t), intent(in) :: base_columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcings(:)
    type(fmr_b110_physical_state_t), intent(in) :: initial_state
    type(canonical_numerical_config_t), intent(in) :: config
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: top_provider
    type(kernel_committed_state_t), intent(in) :: reference_states(:)
    type(fmr_serialized_column_result_t), intent(in) :: reference_second(:)

    type(fmr_logical_column_t), allocatable :: source_columns(:), restart_columns(:), bad_columns(:)
    type(kernel_committed_state_t), allocatable :: split_states(:), restored_states(:), bad_states(:)
    type(fmr_committed_restart_record_t), allocatable :: records(:), bad_records(:)
    type(fmr_serialized_column_result_t), allocatable :: first_results(:), second_results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_template_t), allocatable :: bad_templates(:)
    logical :: ok
    integer :: status, i

    allocate(source_columns(size(base_columns)))
    source_columns = base_columns
    call initialize_states(source_columns, initial_state, split_states)

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(source_columns, templates, parameters, forcings, split_states, config, &
         top_provider, t0, t1, batch_size, first_results, diagnostics, aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'split first dispatch')
    call require(all_committed(first_results), 'split first all committed')
    call require(all_mass_complete(first_results), 'split first mass complete')

    call fmr_export_committed_restart(source_columns, templates, split_states, records, ok, status)
    call require(ok .and. status == FMR_RESTART_OK, 'restart export')
    call require(size(records) == size(source_columns), 'restart record count')
    do i = 1, size(records)
      call require(records(i)%column_id == records(i)%lineage_id, 'column lineage binding')
      call require(records(i)%revision == 1_int64, 'record revision one')
      call require(records(i)%time_bound .and. same_bits(records(i)%committed_time,t1), 'record committed time')
      call require(records(i)%parameter_ref == 1_int64, 'shared immutable parameter ref only')
      call require(allocated(records(i)%physical_state), 'physical continuation state present')
    end do

    ! Simulate loss of the source runtime.  The serialized/runtime state registry
    ! and logical-column container are destroyed.  The decoded adapter records,
    ! immutable parameter registry, forcing and template reconstruction inputs
    ! survive outside the kernel.
    deallocate(split_states)
    deallocate(source_columns)

    call reverse_records(records)
    allocate(restart_columns(size(base_columns)))
    restart_columns = base_columns
    call reverse_columns(restart_columns)
    allocate(restored_states(size(base_columns)))

    call fmr_restore_committed_restart(records, restart_columns, templates, restored_states, ok, status)
    call require(ok .and. status == FMR_RESTART_OK, 'restart restore')
    call require(state_sets_identical_by_lineage(restored_states, state_at_t1(reference_second, reference_states)), &
         'placeholder never evaluated')

    ! Exact restored boundary is checked against the split-run records because
    ! the continuous reference supplied here is already at T2.
    do i = 1, size(records)
      call require(state_exists_with_provenance(restored_states, records(i)%column_id, records(i)%revision, &
           records(i)%committed_time), 'restored per-column provenance')
    end do
    write(*,'(A)') 'FMR19_COLUMN_ID_LINEAGE_REVISION_TIME_CONTINUATION=PASS'
    write(*,'(A)') 'FMR19_REVERSE_RECORD_AND_RUNTIME_ORDER_RESTORE=PASS'

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(restart_columns, templates, parameters, forcings, restored_states, config, &
         top_provider, t1, t2, batch_size, second_results, diagnostics, aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'restored second dispatch')
    call require(all_committed(second_results), 'restored second all committed')
    call require(all_mass_complete(second_results), 'restored second mass complete')
    call require(state_sets_identical_by_lineage(restored_states, reference_states), 'continuous/restarted endpoint state')
    call require(result_mass_sets_identical(reference_second, second_results), 'continuous/restarted interval mass')
    call require(result_provenance_sets_identical(reference_second, second_results), &
         'continuous/restarted result provenance')
    write(*,'(A)') 'FMR19_CONTINUOUS_RESTART_ENDPOINT_IDENTITY=PASS'
    write(*,'(A)') 'FMR19_EXACT_MASS_CONTINUATION=PASS'
    write(*,'(A)') 'FMR19_DETERMINISTIC_REPLAY=PASS'

    if (batch_size == 8) then
      allocate(bad_templates(size(templates)))
      bad_templates = templates
      bad_templates(1)%state_layout_id = bad_templates(1)%state_layout_id + 1_int64
      allocate(bad_states(size(base_columns)))
      call fmr_restore_committed_restart(records, restart_columns, bad_templates, bad_states, ok, status)
      call require(.not. ok .and. status == FMR_RESTART_TEMPLATE_MISMATCH, 'wrong layout rejected')
      call require(all_targets_fresh(bad_states), 'wrong layout atomic rejection')
      deallocate(bad_states, bad_templates)

      allocate(bad_columns(size(restart_columns)))
      bad_columns = restart_columns
      bad_columns(1)%parameter_ref = 2_int64
      allocate(bad_states(size(base_columns)))
      call fmr_restore_committed_restart(records, bad_columns, templates, bad_states, ok, status)
      call require(.not. ok .and. status == FMR_RESTART_PARAMETER_MISMATCH, 'wrong parameter ref rejected')
      call require(all_targets_fresh(bad_states), 'wrong parameter atomic rejection')
      deallocate(bad_states, bad_columns)

      allocate(bad_records(size(records)))
      bad_records = records
      bad_records(2)%column_id = bad_records(1)%column_id
      allocate(bad_states(size(base_columns)))
      call fmr_restore_committed_restart(bad_records, restart_columns, templates, bad_states, ok, status)
      call require(.not. ok .and. status == FMR_RESTART_DUPLICATE_COLUMN, 'duplicate column rejected')
      call require(all_targets_fresh(bad_states), 'duplicate column atomic rejection')
      deallocate(bad_states, bad_records)

      allocate(bad_records(size(records)))
      bad_records = records
      bad_records(1)%schema_version = bad_records(1)%schema_version + 1
      allocate(bad_states(size(base_columns)))
      call fmr_restore_committed_restart(bad_records, restart_columns, templates, bad_states, ok, status)
      call require(.not. ok .and. status == FMR_RESTART_SCHEMA_MISMATCH, 'schema mismatch rejected')
      call require(all_targets_fresh(bad_states), 'schema mismatch atomic rejection')
      deallocate(bad_states, bad_records)

      allocate(bad_states(size(base_columns)))
      call fmr_new_b110_committed_state(bad_states(1), base_columns(1)%column_id, initial_state, t0, ok)
      call require(ok, 'initialized target negative fixture')
      call fmr_restore_committed_restart(records, restart_columns, templates, bad_states, ok, status)
      call require(.not. ok .and. status == FMR_RESTART_TARGET_ALREADY_INITIALIZED, &
           'initialized target rejected')
      call require(bad_states(1)%current_revision() == 0_int64, 'initialized target left unchanged')
      deallocate(bad_states)

      write(*,'(A)') 'FMR19_WRONG_TEMPLATE_LAYOUT_FAIL_CLOSED=PASS'
      write(*,'(A)') 'FMR19_WRONG_PARAMETER_REF_FAIL_CLOSED=PASS'
      write(*,'(A)') 'FMR19_DUPLICATE_COLUMN_FAIL_CLOSED=PASS'
      write(*,'(A)') 'FMR19_SCHEMA_MISMATCH_FAIL_CLOSED=PASS'
      write(*,'(A)') 'FMR19_ATOMIC_RESTORE_PUBLICATION=PASS'
    end if
  end subroutine execute_restart_case

  subroutine configure_templates(templates)
    type(fmr_template_t), intent(out) :: templates(2)
    templates(1)%template_id = 505_int64
    templates(1)%physics_topology_id = 50501_int64
    templates(1)%vertical_layout_id = 50502_int64
    templates(1)%state_layout_id = 50503_int64
    templates(1)%solver_interface_id = 50504_int64
    templates(1)%optional_state_layout_id = 0_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    templates(2) = templates(1)
    templates(2)%template_id = 506_int64
  end subroutine configure_templates

  subroutine configure_parameters(parameters, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    parameters%parameter_set_id = 50501_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do i = 1, numnod
      parameters%cofgen(1,i) = 0.032_real64
      parameters%cofgen(2,i) = 0.423_real64
      parameters%cofgen(3,i) = 4.75_real64
      parameters%cofgen(4,i) = 0.0135_real64
      parameters%cofgen(5,i) = 0.365_real64
      parameters%cofgen(6,i) = 1.455_real64
      parameters%cofgen(7,i) = 1.0_real64 - 1.0_real64/parameters%cofgen(6,i)
      parameters%cofgen(8,i) = parameters%cofgen(4,i)
      parameters%cofgen(9,i) = 0.0_real64
      parameters%cofgen(10,i) = parameters%cofgen(3,i)
      parameters%cofgen(11,i) = 0.999_real64
      parameters%cofgen(12,i) = 0.99_real64*parameters%cofgen(3,i)
      parameters%cofgen(22,i) = -1.0e6_real64
      parameters%cofgen(23,i) = 1.0e-12_real64
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

    call initialize_b110_default_mvg_parameters(hyd_parameters, parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine build_columns_and_forcing(columns, forcings, conductivity0)
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    real(real64), intent(in) :: conductivity0
    integer :: i, j

    allocate(columns(nfull), forcings(nfull))
    do i = 1, nfull
      columns(i)%column_id = 505000_int64 + int(i,int64)
      if (mod(i,2) == 1) then
        columns(i)%template_id = 505_int64
      else
        columns(i)%template_id = 506_int64
      end if
      columns(i)%parameter_ref = 1_int64
      columns(i)%state_handle = int(i,int64)
      columns(i)%forcing_handle = int(i,int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      forcings(i)%top_flux = -conductivity0
      forcings(i)%top_head = head0
      forcings(i)%bottom_flux = -conductivity0
      forcings(i)%bottom_head = -100.0_real64
      allocate(forcings(i)%drainage_flux_by_level(2,numnod), forcings(i)%subsurface_irrigation_source(numnod), &
               forcings(i)%root_extraction_sink(numnod))
      do j = 1, numnod
        forcings(i)%drainage_flux_by_level(1,j) = (1.0_real64 + 0.01_real64*real(i,real64))*1.0e-5_real64*real(j,real64)
        forcings(i)%drainage_flux_by_level(2,j) = -(1.0_real64 + 0.01_real64*real(i,real64))*2.0e-6_real64*real(j+1,real64)
        forcings(i)%subsurface_irrigation_source(j) = forcings(i)%drainage_flux_by_level(1,j) + &
             forcings(i)%drainage_flux_by_level(2,j)
        forcings(i)%root_extraction_sink(j) = 0.0_real64
      end do
    end do
  end subroutine build_columns_and_forcing

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine initialize_states(columns, initial_state, states)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_b110_physical_state_t), intent(in) :: initial_state
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    integer :: i
    logical :: ok

    allocate(states(size(columns)))
    do i = 1, size(columns)
      call fmr_new_b110_committed_state(states(int(columns(i)%state_handle)), columns(i)%column_id, initial_state, t0, ok)
      call require(ok, 'state initialization')
    end do
  end subroutine initialize_states

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals

  subroutine reverse_records(records)
    type(fmr_committed_restart_record_t), intent(inout) :: records(:)
    type(fmr_committed_restart_record_t) :: tmp
    integer :: i, j
    do i = 1, size(records)/2
      j = size(records) + 1 - i
      tmp = records(i)
      records(i) = records(j)
      records(j) = tmp
    end do
  end subroutine reverse_records

  subroutine reverse_columns(columns)
    type(fmr_logical_column_t), intent(inout) :: columns(:)
    type(fmr_logical_column_t) :: tmp
    integer :: i, j
    do i = 1, size(columns)/2
      j = size(columns) + 1 - i
      tmp = columns(i)
      columns(i) = columns(j)
      columns(j) = tmp
    end do
  end subroutine reverse_columns

  logical function all_committed(results)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: i
    all_committed = .true.
    do i = 1, size(results)
      if (.not. results(i)%completed .or. .not. results(i)%committed) all_committed = .false.
    end do
  end function all_committed

  logical function all_mass_complete(results)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: i
    all_mass_complete = .true.
    do i = 1, size(results)
      if (.not. results(i)%mass%complete) all_mass_complete = .false.
      if (results(i)%mass%missing_contribution_mask /= TX_MASS_MISSING_NONE) all_mass_complete = .false.
      if (abs(results(i)%mass%residual) > hard_mass_gate) all_mass_complete = .false.
    end do
  end function all_mass_complete

  logical function all_targets_fresh(states)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: i
    all_targets_fresh = .true.
    do i = 1, size(states)
      if (states(i)%ready()) all_targets_fresh = .false.
    end do
  end function all_targets_fresh

  logical function state_exists_with_provenance(states, lineage, revision, time_value)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer(int64), intent(in) :: lineage, revision
    real(real64), intent(in) :: time_value
    integer :: i
    logical :: available
    real(real64) :: actual_time

    state_exists_with_provenance = .false.
    do i = 1, size(states)
      if (states(i)%current_lineage_id() /= lineage) cycle
      if (states(i)%current_revision() /= revision) return
      call states(i)%current_time(actual_time, available)
      if (.not. available) return
      state_exists_with_provenance = same_bits(actual_time,time_value)
      return
    end do
  end function state_exists_with_provenance

  logical function state_sets_identical_by_lineage(left, right)
    type(kernel_committed_state_t), intent(in) :: left(:), right(:)
    integer :: i, j
    state_sets_identical_by_lineage = size(left) == size(right)
    if (.not. state_sets_identical_by_lineage) return
    do i = 1, size(left)
      j = state_index_for_lineage(right,left(i)%current_lineage_id())
      if (j == 0) then
        state_sets_identical_by_lineage = .false.
        return
      end if
      if (left(i)%current_revision() /= right(j)%current_revision() .or. &
          committed_fingerprint(left(i)) /= committed_fingerprint(right(j))) then
        state_sets_identical_by_lineage = .false.
        return
      end if
    end do
  end function state_sets_identical_by_lineage

  integer function state_index_for_lineage(states, lineage)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer(int64), intent(in) :: lineage
    integer :: i
    state_index_for_lineage = 0
    do i = 1, size(states)
      if (states(i)%ready()) then
        if (states(i)%current_lineage_id() == lineage) then
          state_index_for_lineage = i
          return
        end if
      end if
    end do
  end function state_index_for_lineage

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: i

    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot')
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
      error stop 'F-MR19 unexpected physical state type'
    end select
  end function committed_fingerprint

  logical function result_mass_sets_identical(left, right)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: i, j
    result_mass_sets_identical = size(left) == size(right)
    if (.not. result_mass_sets_identical) return
    do i = 1, size(left)
      j = result_index(right,left(i)%column_id)
      if (j == 0) then
        result_mass_sets_identical = .false.; return
      end if
      if (.not. mass_identical(left(i),right(j))) then
        result_mass_sets_identical = .false.; return
      end if
    end do
  end function result_mass_sets_identical

  logical function mass_identical(left,right)
    type(fmr_serialized_column_result_t), intent(in) :: left,right
    mass_identical = left%mass%complete .eqv. right%mass%complete
    mass_identical = mass_identical .and. left%mass%missing_contribution_mask == right%mass%missing_contribution_mask
    mass_identical = mass_identical .and. left%mass%origin_lineage_id == right%mass%origin_lineage_id
    mass_identical = mass_identical .and. left%mass%origin_revision == right%mass%origin_revision
    mass_identical = mass_identical .and. left%mass%accepted_transaction_count == right%mass%accepted_transaction_count
    mass_identical = mass_identical .and. same_bits(left%mass%interval_t0,right%mass%interval_t0)
    mass_identical = mass_identical .and. same_bits(left%mass%interval_t1,right%mass%interval_t1)
    mass_identical = mass_identical .and. same_bits(left%mass%storage_start,right%mass%storage_start)
    mass_identical = mass_identical .and. same_bits(left%mass%storage_end,right%mass%storage_end)
    mass_identical = mass_identical .and. same_bits(left%mass%storage_change,right%mass%storage_change)
    mass_identical = mass_identical .and. same_bits(left%mass%total_in,right%mass%total_in)
    mass_identical = mass_identical .and. same_bits(left%mass%total_out,right%mass%total_out)
    mass_identical = mass_identical .and. same_bits(left%mass%residual,right%mass%residual)
  end function mass_identical

  logical function result_provenance_sets_identical(left,right)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: i,j
    result_provenance_sets_identical = size(left) == size(right)
    if (.not. result_provenance_sets_identical) return
    do i = 1, size(left)
      j = result_index(right,left(i)%column_id)
      if (j == 0) then
        result_provenance_sets_identical = .false.; return
      end if
      if (left(i)%initial_revision /= right(j)%initial_revision .or. &
          left(i)%final_revision /= right(j)%final_revision .or. &
          left(i)%final_committed_time_bound .neqv. right(j)%final_committed_time_bound .or. &
          .not. same_bits(left(i)%final_committed_time,right(j)%final_committed_time)) then
        result_provenance_sets_identical = .false.; return
      end if
    end do
  end function result_provenance_sets_identical

  integer function result_index(results,column_id)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: column_id
    integer :: i
    result_index = 0
    do i = 1, size(results)
      if (results(i)%column_id == column_id) then
        result_index = i; return
      end if
    end do
  end function result_index

  function state_at_t1(reference_second, reference_states) result(dummy)
    type(fmr_serialized_column_result_t), intent(in) :: reference_second(:)
    type(kernel_committed_state_t), intent(in) :: reference_states(:)
    type(kernel_committed_state_t), allocatable :: dummy(:)
    ! This helper exists only to keep the T1 check structurally separate from
    ! the T2 reference. It deliberately returns a zero-size value and must not
    ! be used for qualification comparison.
    allocate(dummy(0))
  end function state_at_t1

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a,ia); ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR19_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr19_committed_process_restart

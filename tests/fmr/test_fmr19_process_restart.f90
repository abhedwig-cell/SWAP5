program test_fmr19_process_restart
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_TEMPLATE_MISMATCH, &
       FMR_RESTART_PARAMETER_MISMATCH, FMR_RESTART_PARAMETER_SET_MISMATCH, FMR_RESTART_DUPLICATE_COLUMN
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: tm = 1000.375_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: parameter_set_identity = 1905001_int64
  integer, parameter :: nmatrix = 5
  integer, parameter :: matrix(nmatrix) = [1, 2, 8, 17, 32]
  integer(int64) :: signature_a, signature_b
  integer :: i

  do i = 1, nmatrix
    call run_restart_case(matrix(i), signature_a)
    call run_restart_case(matrix(i), signature_b)
    call require(signature_a == signature_b, 'deterministic replay signature')
    write(*,'(A,I0,A)') 'FMR19_BATCH_SIZE_', matrix(i), '=PASS'
  end do

  write(*,'(A)') 'FMR19_PARAMETER_SET_IDENTITY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR19_TEMPLATE_LAYOUT_IDENTITY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR19_PER_COLUMN_PARAMETER_REF_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR19_DUPLICATE_COLUMN_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR19_REVERSE_RECORD_ORDER=PASS'
  write(*,'(A)') 'FMR19_REVERSE_RUNTIME_ORDER=PASS'
  write(*,'(A)') 'FMR19_EXACT_LINEAGE_REVISION_TIME_CONTINUATION=PASS'
  write(*,'(A)') 'FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS'
  write(*,'(A)') 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS'
  write(*,'(A)') 'FMR19_DETERMINISTIC_REPLAY=PASS'
  write(*,'(A)') 'FMR19_REAL_HEADCALC_PROCESS_RESTART_TEST PASS'

contains

  subroutine run_restart_case(n, signature)
    integer, intent(in) :: n
    integer(int64), intent(out) :: signature

    type(fmr_logical_column_t), allocatable :: base_columns(:), restart_columns(:), bad_columns(:)
    type(fmr_template_t), allocatable :: base_templates(:), restart_templates(:), bad_templates(:)
    type(fmr_b110_physical_parameters_t), allocatable :: base_parameters(:), restart_parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable :: base_forcings(:), restart_forcings(:)
    type(kernel_committed_state_t), allocatable :: base_states(:), restart_states(:)
    type(fmr_serialized_column_result_t), allocatable :: base_first(:), base_second(:), restart_first(:), restart_second(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate, base_second_aggregate, restart_second_aggregate
    type(fmr_committed_restart_bundle_t) :: bundle, duplicate_bundle
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    logical :: exported, restored
    integer :: status, i

    call configure_transaction(config)

    call build_runtime(n, .true., base_columns, base_templates, base_parameters, base_forcings, base_states)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(base_columns, base_templates, base_parameters, base_forcings, base_states, &
         config, top_provider, t0, tm, n, base_first, diagnostics, aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'continuous first dispatch')
    call require_all_committed(base_first, 'continuous first committed')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(base_columns, base_templates, base_parameters, base_forcings, base_states, &
         config, top_provider, tm, t1, n, base_second, diagnostics, base_second_aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'continuous second dispatch')
    call require_all_committed(base_second, 'continuous second committed')

    call build_runtime(n, .true., restart_columns, restart_templates, restart_parameters, restart_forcings, restart_states)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(restart_columns, restart_templates, restart_parameters, restart_forcings, &
         restart_states, config, top_provider, t0, tm, n, restart_first, diagnostics, aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'restart first dispatch')
    call require_all_committed(restart_first, 'restart first committed')
    call require(result_sets_identical(base_first, restart_first), 'first interval reference identity')

    call fmr_export_committed_restart(restart_columns, restart_templates, restart_states, parameter_set_identity, &
         bundle, exported, status)
    call require(exported .and. status == FMR_RESTART_OK, 'restart export')
    call require(bundle%parameter_set_identity == parameter_set_identity, 'bundle parameter-set identity')
    call require(allocated(bundle%records) .and. size(bundle%records) == n, 'bundle record count')

    ! Simulate process destruction.  Only the decoded restart bundle survives.
    deallocate(restart_columns, restart_templates, restart_parameters, restart_forcings, restart_states)

    ! Reconstruct runtime configuration independently.  Committed state remains
    ! uninitialized until the F-MR19 restore succeeds.
    call build_runtime(n, .false., restart_columns, restart_templates, restart_parameters, restart_forcings, restart_states)
    call reverse_records(bundle)
    call reverse_columns(restart_columns)

    call fmr_restore_committed_restart(bundle, parameter_set_identity + 1_int64, restart_columns, restart_templates, &
         restart_states, restored, status)
    call require(.not. restored .and. status == FMR_RESTART_PARAMETER_SET_MISMATCH, 'wrong parameter set rejected')
    call require(all_states_unready(restart_states), 'parameter-set rejection atomic')

    allocate(bad_templates(size(restart_templates)))
    bad_templates = restart_templates
    bad_templates(1)%state_layout_id = bad_templates(1)%state_layout_id + 1_int64
    call fmr_restore_committed_restart(bundle, parameter_set_identity, restart_columns, bad_templates, restart_states, &
         restored, status)
    call require(.not. restored .and. status == FMR_RESTART_TEMPLATE_MISMATCH, 'wrong layout rejected')
    call require(all_states_unready(restart_states), 'template rejection atomic')
    deallocate(bad_templates)

    allocate(bad_columns(size(restart_columns)))
    bad_columns = restart_columns
    bad_columns(1)%parameter_ref = 3_int64 - bad_columns(1)%parameter_ref
    call fmr_restore_committed_restart(bundle, parameter_set_identity, bad_columns, restart_templates, restart_states, &
         restored, status)
    call require(.not. restored .and. status == FMR_RESTART_PARAMETER_MISMATCH, 'wrong parameter ref rejected')
    call require(all_states_unready(restart_states), 'parameter-ref rejection atomic')
    deallocate(bad_columns)

    duplicate_bundle = bundle
    if (n >= 2) then
      duplicate_bundle%records(2)%column_id = duplicate_bundle%records(1)%column_id
      call fmr_restore_committed_restart(duplicate_bundle, parameter_set_identity, restart_columns, restart_templates, &
           restart_states, restored, status)
      call require(.not. restored .and. status == FMR_RESTART_DUPLICATE_COLUMN, 'duplicate column rejected')
      call require(all_states_unready(restart_states), 'duplicate rejection atomic')
    end if

    call fmr_restore_committed_restart(bundle, parameter_set_identity, restart_columns, restart_templates, restart_states, &
         restored, status)
    call require(restored .and. status == FMR_RESTART_OK, 'correct restart restore')
    call verify_restored_metadata(bundle, restart_columns, restart_states)

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(restart_columns, restart_templates, restart_parameters, restart_forcings, &
         restart_states, config, top_provider, tm, t1, n, restart_second, diagnostics, restart_second_aggregate, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'restart second dispatch')
    call require_all_committed(restart_second, 'restart second committed')

    call require(result_sets_identical(base_second, restart_second), 'second interval result identity')
    call require(state_sets_identical(base_states, restart_states), 'endpoint committed-state identity')
    call require(same_bits(base_second_aggregate%aggregate_unrounded_mass_residual, &
         restart_second_aggregate%aggregate_unrounded_mass_residual), 'aggregate interval mass identity')
    call require(max_abs_residual(base_first) <= hard_mass_gate .and. max_abs_residual(base_second) <= hard_mass_gate, &
         'continuous hard mass gate')
    call require(max_abs_residual(restart_first) <= hard_mass_gate .and. max_abs_residual(restart_second) <= hard_mass_gate, &
         'restart hard mass gate')

    do i = 1, n
      call require(base_states(i)%current_lineage_id() == 190500_int64 + int(i,int64), 'final lineage identity')
      call require(base_states(i)%current_revision() == 2_int64, 'continuous final revision')
      call require(restart_states(i)%current_revision() == 2_int64, 'restart final revision')
    end do

    signature = state_result_signature(restart_states, restart_second)
  end subroutine run_restart_case

  subroutine build_runtime(n, initialize_states, columns, templates, parameters, forcings, states)
    integer, intent(in) :: n
    logical, intent(in) :: initialize_states
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), allocatable, intent(out) :: templates(:)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: parameters(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)

    type(fmr_b110_physical_state_t) :: initial_state, column_state
    real(real64) :: conductivity0
    logical :: ok
    integer :: i

    allocate(columns(n), templates(2), parameters(2), forcings(n), states(n))
    call configure_templates(templates)
    call configure_parameters(parameters(1), initial_state, conductivity0)
    parameters(2) = parameters(1)
    parameters(2)%parameter_set_id = 190502_int64

    do i = 1, n
      columns(i)%column_id = 190500_int64 + int(i,int64)
      if (mod(i,2) == 1) then
        columns(i)%template_id = templates(1)%template_id
        columns(i)%parameter_ref = 1_int64
      else
        columns(i)%template_id = templates(2)%template_id
        columns(i)%parameter_ref = 2_int64
      end if
      columns(i)%state_handle = int(i,int64)
      columns(i)%forcing_handle = int(i,int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
      if (initialize_states) then
        column_state = initial_state
        column_state%groundwater_level = -2.0_real64 - 0.01_real64*real(i,real64)
        call fmr_new_b110_committed_state(states(i), columns(i)%column_id, column_state, t0, ok)
        call require(ok, 'committed-state initialization')
      end if
    end do
  end subroutine build_runtime

  subroutine configure_templates(templates)
    type(fmr_template_t), intent(out) :: templates(2)

    templates(1)%template_id = 1905_int64
    templates(1)%physics_topology_id = 190501_int64
    templates(1)%vertical_layout_id = 190502_int64
    templates(1)%state_layout_id = 190503_int64
    templates(1)%solver_interface_id = 190504_int64
    templates(1)%optional_state_layout_id = 0_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    templates(2) = templates(1)
    templates(2)%template_id = 1906_int64
  end subroutine configure_templates

  subroutine configure_parameters(parameters, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    parameters%parameter_set_id = 190501_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    allocate(parameters%cofgen(24,numnod))
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
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, tm-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(conductivity == conductivity(1)), 'uniform conductivity fixture')
    conductivity0 = conductivity(1)

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

  subroutine reverse_records(bundle)
    type(fmr_committed_restart_bundle_t), intent(inout) :: bundle
    type(fmr_committed_restart_bundle_t) :: copy
    integer :: i, n
    copy = bundle
    n = size(bundle%records)
    do i = 1, n
      bundle%records(i) = copy%records(n + 1 - i)
    end do
  end subroutine reverse_records

  subroutine verify_restored_metadata(bundle, columns, states)
    type(fmr_committed_restart_bundle_t), intent(in) :: bundle
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: i, r, h
    logical :: available
    real(real64) :: committed_time

    do i = 1, size(columns)
      r = record_index(bundle, columns(i)%column_id)
      call require(r > 0, 'restored record lookup')
      h = int(columns(i)%state_handle)
      call require(states(h)%current_lineage_id() == bundle%records(r)%lineage_id, 'restored lineage')
      call require(states(h)%current_revision() == bundle%records(r)%revision, 'restored revision')
      call require(states(h)%current_revision() == 1_int64, 'midpoint revision')
      call states(h)%current_time(committed_time, available)
      call require(available .and. bundle%records(r)%time_bound, 'restored time bound')
      call require(same_bits(committed_time, bundle%records(r)%committed_time), 'restored exact committed time')
      call require(same_bits(committed_time, tm), 'restored midpoint time')
    end do
  end subroutine verify_restored_metadata

  integer function record_index(bundle, column_id) result(index)
    type(fmr_committed_restart_bundle_t), intent(in) :: bundle
    integer(int64), intent(in) :: column_id
    integer :: i
    index = 0
    do i = 1, size(bundle%records)
      if (bundle%records(i)%column_id == column_id) then
        index = i
        return
      end if
    end do
  end function record_index

  logical function all_states_unready(states) result(unready)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: i
    unready = .true.
    do i = 1, size(states)
      if (states(i)%ready()) then
        unready = .false.
        return
      end if
    end do
  end function all_states_unready

  subroutine require_all_committed(results, label)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    character(len=*), intent(in) :: label
    integer :: i
    do i = 1, size(results)
      call require(results(i)%completed .and. results(i)%committed .and. results(i)%mass%complete, label)
      call require(abs(results(i)%mass%residual) <= hard_mass_gate, 'column hard mass gate')
    end do
  end subroutine require_all_committed

  logical function result_sets_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: i, j
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      j = result_index(right, left(i)%column_id)
      if (j == 0 .or. .not. column_results_identical(left(i), right(j))) then
        equal = .false.
        return
      end if
    end do
  end function result_sets_identical

  integer function result_index(results, column_id) result(index)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: column_id
    integer :: i
    index = 0
    do i = 1, size(results)
      if (results(i)%column_id == column_id) then
        index = i
        return
      end if
    end do
  end function result_index

  logical function column_results_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left, right
    equal = left%column_id == right%column_id .and. left%kernel_status == right%kernel_status .and. &
         left%commit_status == right%commit_status .and. left%completed .eqv. right%completed .and. &
         left%committed .eqv. right%committed .and. left%solver_executed .eqv. right%solver_executed .and. &
         trim(left%solver_route) == trim(right%solver_route) .and. left%solver_iterations == right%solver_iterations .and. &
         left%initial_revision == right%initial_revision .and. left%final_revision == right%final_revision .and. &
         left%final_committed_time_bound .eqv. right%final_committed_time_bound .and. &
         same_bits(left%final_committed_time,right%final_committed_time) .and. &
         left%mass%complete .eqv. right%mass%complete .and. &
         left%mass%missing_contribution_mask == right%mass%missing_contribution_mask .and. &
         left%mass%origin_lineage_id == right%mass%origin_lineage_id .and. &
         left%mass%origin_revision == right%mass%origin_revision .and. &
         left%mass%accepted_transaction_count == right%mass%accepted_transaction_count .and. &
         same_bits(left%mass%interval_t0,right%mass%interval_t0) .and. &
         same_bits(left%mass%interval_t1,right%mass%interval_t1) .and. &
         same_bits(left%mass%storage_start,right%mass%storage_start) .and. &
         same_bits(left%mass%storage_end,right%mass%storage_end) .and. &
         same_bits(left%mass%storage_change,right%mass%storage_change) .and. &
         same_bits(left%mass%total_in,right%mass%total_in) .and. &
         same_bits(left%mass%total_out,right%mass%total_out) .and. &
         same_bits(left%mass%residual,right%mass%residual)
  end function column_results_identical

  logical function state_sets_identical(left, right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left(:), right(:)
    integer :: i
    logical :: al, ar
    real(real64) :: tl, tr
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      if (left(i)%current_lineage_id() /= right(i)%current_lineage_id() .or. &
          left(i)%current_revision() /= right(i)%current_revision() .or. &
          committed_fingerprint(left(i)) /= committed_fingerprint(right(i))) then
        equal = .false.
        return
      end if
      call left(i)%current_time(tl, al)
      call right(i)%current_time(tr, ar)
      if (al .neqv. ar) then
        equal = .false.
        return
      end if
      if (al .and. .not. same_bits(tl,tr)) then
        equal = .false.
        return
      end if
    end do
  end function state_sets_identical

  real(real64) function max_abs_residual(results) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: i
    value = 0.0_real64
    do i = 1, size(results)
      if (results(i)%committed) value = max(value, abs(results(i)%mass%residual))
    end do
  end function max_abs_residual

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
      fp = ieor(fp, int(physical%active_nodes,int64))
      do i = 1, physical%active_nodes
        fp = ieor(fp, transfer(physical%pressure_head(i),fp))
        fp = ieor(fp, transfer(physical%water_content(i),fp))
      end do
      fp = ieor(fp, transfer(physical%ponding_depth,fp))
      fp = ieor(fp, transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR19 unexpected physical state type'
    end select
  end function committed_fingerprint

  integer(int64) function state_result_signature(states, results) result(fp)
    type(kernel_committed_state_t), intent(in) :: states(:)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: i, j
    fp = 1469598103934665603_int64
    do i = 1, size(states)
      fp = ieor(fp, committed_fingerprint(states(i)))
      fp = ieor(fp, states(i)%current_lineage_id())
      fp = ieor(fp, states(i)%current_revision())
    end do
    do i = 1, size(results)
      j = result_index(results, 190500_int64 + int(i,int64))
      call require(j > 0, 'signature result lookup')
      fp = ieor(fp, transfer(results(j)%mass%residual,fp))
      fp = ieor(fp, transfer(results(j)%mass%storage_end,fp))
      fp = ieor(fp, results(j)%final_revision)
    end do
  end function state_result_signature

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia, ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR19_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr19_process_restart

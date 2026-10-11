program test_fci81_rossfast_application_composition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_EXECUTION_EASY
  use mod_fmr_serialized_kernel_backend, only: FMR_SERIALIZED_KERNEL_OK
  use mod_fmr_rossfast_application_selection, only: fmr_rossfast_application_column_t, &
       FMR_APPLICATION_MODEL_ROSSFAST_D3R
  use mod_fmr_rossfast_application_config, only: fmr_rossfast_application_config_t, &
       FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL, FMR_ROSSFAST_CONFIG_OK, &
       FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, fmr_bind_rossfast_application_config
  use mod_fmr_rossfast_registry_dispatch, only: fmr_rossfast_registry_dispatcher_t, &
       fmr_rossfast_dispatch_result_t, FMR_ROSSFAST_DISPATCH_OK, &
       FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED, FMR_ROSSFAST_COLUMN_OK, &
       FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED
  use mod_fmr_rossfast_application_runtime, only: fmr_rossfast_application_outcome_t, &
       fmr_run_rossfast_application, FMR_ROSSFAST_APPLICATION_OK, &
       FMR_ROSSFAST_APPLICATION_CONFIG_REJECTED, FMR_ROSSFAST_APPLICATION_ASSET_PROVIDER_REJECTED
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_state_t, &
       rossfast_d3r_forcing_t, rossfast_d3r_material_from_id, ROSSFAST_D3R_N_CELLS, &
       ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_kernel_model_adapter, only: rossfast_d3r_kernel_parameters_t
  implicit none

  character(len=3), parameter :: MATERIALS(6) = &
       [character(len=3) :: 'B01', 'B12', 'O01', 'O05', 'O14', 'O18']
  character(len=512) :: asset_root
  integer :: failures

  call get_command_argument(1, asset_root)
  if (len_trim(asset_root) == 0) error stop 'usage: test_fci81 ASSET_ROOT'

  failures = 0
  call test_composed_route_equals_direct_authority_route(trim(asset_root), failures)
  call test_reference_model_is_not_captured(trim(asset_root), failures)
  call test_missing_asset_batch_preflight(failures)

  if (failures /= 0) then
    write(*,'(a,i0)') 'FCI81_INDEPENDENT_ROSSFAST_APPLICATION_COMPOSITION FAIL failures=', failures
    error stop 1
  end if
  write(*,'(a)') 'FCI81_INDEPENDENT_ROSSFAST_APPLICATION_COMPOSITION PASS'

contains

  subroutine test_composed_route_equals_direct_authority_route(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:), direct_templates(:)
    type(fmr_logical_column_t), allocatable :: direct_columns(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: composed_states(:), direct_states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: composed_results(:), direct_results(:)
    type(fmr_rossfast_application_config_t) :: app_config
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(fmr_rossfast_registry_dispatcher_t) :: direct_dispatcher
    type(canonical_numerical_config_t) :: numerical
    logical :: valid
    integer :: config_status, dispatch_status, i

    call initialize_application(columns, templates, parameters, forcings, composed_states, direct_states, numerical, failures)
    call valid_application_config(app_config)

    call fmr_run_rossfast_application(app_config, root, columns, templates, parameters, forcings, composed_states, &
         numerical, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, composed_results, outcome)

    call fmr_bind_rossfast_application_config(app_config, columns, templates, direct_columns, direct_templates, config_status)
    call expect_true(config_status == FMR_ROSSFAST_CONFIG_OK, 'direct config bind', failures)
    call direct_dispatcher%initialize(root, valid)
    call expect_true(valid, 'direct dispatcher registry bound', failures)
    call direct_dispatcher%execute_batch(direct_columns, direct_templates, parameters, forcings, direct_states, numerical, &
         0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, direct_results, dispatch_status)

    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_OK, 'composed outcome', failures)
    call expect_true(outcome%dispatch_status == FMR_ROSSFAST_DISPATCH_OK, 'composed dispatch', failures)
    call expect_true(dispatch_status == FMR_ROSSFAST_DISPATCH_OK, 'direct dispatch', failures)
    call expect_true(size(composed_results) == size(MATERIALS) .and. size(direct_results) == size(MATERIALS), &
         'result counts', failures)

    do i = 1, size(MATERIALS)
      call expect_true(composed_results(i)%status == FMR_ROSSFAST_COLUMN_OK .and. &
           direct_results(i)%status == FMR_ROSSFAST_COLUMN_OK, trim(MATERIALS(i))//' column status', failures)
      call expect_true(composed_results(i)%dispatch_ordinal == direct_results(i)%dispatch_ordinal, &
           trim(MATERIALS(i))//' dispatch ordinal', failures)
      call expect_true(composed_results(i)%execution%status == FMR_SERIALIZED_KERNEL_OK .and. &
           direct_results(i)%execution%status == FMR_SERIALIZED_KERNEL_OK, &
           trim(MATERIALS(i))//' execution status', failures)
      call expect_true(composed_results(i)%execution%diagnostics%linear_solves == &
           direct_results(i)%execution%diagnostics%linear_solves, trim(MATERIALS(i))//' linear solves', failures)
      call expect_true(composed_results(i)%execution%diagnostics%attempts == &
           direct_results(i)%execution%diagnostics%attempts, trim(MATERIALS(i))//' attempts', failures)
      call expect_true(composed_states(i)%current_revision() == 1_int64 .and. &
           direct_states(i)%current_revision() == 1_int64, trim(MATERIALS(i))//' revision', failures)
      call compare_committed_states(composed_states(i), direct_states(i), trim(MATERIALS(i)), failures)
      write(*,'(a,1x,a,1x,i0,1x,i0)') 'FCI81_EQUIV', trim(MATERIALS(i)), &
           composed_results(i)%execution%diagnostics%linear_solves, &
           composed_results(i)%execution%diagnostics%attempts
    end do
  end subroutine test_composed_route_equals_direct_authority_route

  subroutine test_reference_model_is_not_captured(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:), unused_states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_application_config_t) :: app_config
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(canonical_numerical_config_t) :: numerical

    call initialize_application(columns, templates, parameters, forcings, states, unused_states, numerical, failures)
    app_config%supplied = .true.
    app_config%key = FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL
    app_config%value = 'REFERENCE_RICHARDS'
    call fmr_run_rossfast_application(app_config, root, columns, templates, parameters, forcings, states, numerical, &
         0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, outcome)

    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_CONFIG_REJECTED, &
         'reference model rejected by composition', failures)
    call expect_true(outcome%config_status == FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, &
         'reference model rejected by F-ROSS09 authority', failures)
    call expect_true(.not. outcome%asset_registry_bound .and. .not. outcome%dispatch_invoked, &
         'reference model cannot reach dispatcher', failures)
    call expect_true(size(results) == 0, 'reference model no results', failures)
    call expect_all_unpublished(states, 'reference model no state mutation', failures)
    write(*,'(a)') 'FCI81_REFERENCE_REJECT PASS'
  end subroutine test_reference_model_is_not_captured

  subroutine test_missing_asset_batch_preflight(failures)
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:), unused_states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_application_config_t) :: app_config
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(canonical_numerical_config_t) :: numerical
    integer :: i

    call initialize_application(columns, templates, parameters, forcings, states, unused_states, numerical, failures)
    call valid_application_config(app_config)
    call fmr_run_rossfast_application(app_config, 'fci81-missing-assets', columns, templates, parameters, forcings, &
         states, numerical, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, outcome)

    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_ASSET_PROVIDER_REJECTED, &
         'missing asset overall status', failures)
    call expect_true(outcome%dispatch_status == FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED, &
         'missing asset dispatch status', failures)
    call expect_true(size(results) == size(MATERIALS), 'missing asset batch results', failures)
    do i = 1, size(results)
      call expect_true(results(i)%status == FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED, &
           'missing asset column preflight status', failures)
    end do
    call expect_all_unpublished(states, 'missing assets no physical state mutation', failures)
    write(*,'(a)') 'FCI81_MISSING_ASSET_PREFLIGHT PASS'
  end subroutine test_missing_asset_batch_preflight

  subroutine compare_committed_states(left, right, label, failures)
    type(kernel_committed_state_t), intent(in) :: left, right
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: left_snapshot, right_snapshot
    logical :: left_ok, right_ok

    call left%snapshot(left_snapshot, left_ok)
    call right%snapshot(right_snapshot, right_ok)
    call expect_true(left_ok .and. right_ok, trim(label)//' snapshots available', failures)
    if (.not. left_ok .or. .not. right_ok) return

    select type(ls => left_snapshot)
    type is (rossfast_d3r_state_t)
      select type(rs => right_snapshot)
      type is (rossfast_d3r_state_t)
        call expect_true(ls%active_nodes == rs%active_nodes, trim(label)//' active nodes', failures)
        call expect_true(allocated(ls%pressure_head_cm) .and. allocated(rs%pressure_head_cm), &
             trim(label)//' pressure arrays allocated', failures)
        call expect_true(allocated(ls%water_content) .and. allocated(rs%water_content), &
             trim(label)//' water arrays allocated', failures)
        if (allocated(ls%pressure_head_cm) .and. allocated(rs%pressure_head_cm)) then
          call expect_true(size(ls%pressure_head_cm) == size(rs%pressure_head_cm), &
               trim(label)//' pressure size', failures)
          if (size(ls%pressure_head_cm) == size(rs%pressure_head_cm)) &
               call expect_true(all(ls%pressure_head_cm == rs%pressure_head_cm), &
               trim(label)//' pressure exact equivalence', failures)
        end if
        if (allocated(ls%water_content) .and. allocated(rs%water_content)) then
          call expect_true(size(ls%water_content) == size(rs%water_content), trim(label)//' water size', failures)
          if (size(ls%water_content) == size(rs%water_content)) &
               call expect_true(all(ls%water_content == rs%water_content), &
               trim(label)//' water exact equivalence', failures)
        end if
      class default
        call expect_true(.false., trim(label)//' direct snapshot type', failures)
      end select
    class default
      call expect_true(.false., trim(label)//' composed snapshot type', failures)
    end select
  end subroutine compare_committed_states

  subroutine valid_application_config(config)
    type(fmr_rossfast_application_config_t), intent(out) :: config
    config = fmr_rossfast_application_config_t()
    config%supplied = .true.
    config%key = FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL
    config%value = FMR_APPLICATION_MODEL_ROSSFAST_D3R
  end subroutine valid_application_config

  subroutine initialize_application(columns, templates, parameters, forcings, left_states, right_states, numerical, failures)
    type(fmr_rossfast_application_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), allocatable, intent(out) :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable, intent(out) :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: left_states(:), right_states(:)
    type(canonical_numerical_config_t), intent(out) :: numerical
    integer, intent(inout) :: failures
    type(rossfast_d3r_material_t) :: material
    class(transaction_state_t), allocatable :: initial_state
    real(real64) :: k
    logical :: found, ok_left, ok_right
    integer :: i

    allocate(columns(size(MATERIALS)), templates(1), parameters(size(MATERIALS)), forcings(size(MATERIALS)), &
         left_states(size(MATERIALS)), right_states(size(MATERIALS)))
    templates(1) = fmr_template_t()
    templates(1)%template_id = 8181_int64
    templates(1)%physics_topology_id = 818101_int64
    templates(1)%vertical_layout_id = 818102_int64
    templates(1)%state_layout_id = 818103_int64
    templates(1)%solver_interface_id = 818104_int64
    templates(1)%compatible_backend_id = 0

    do i = 1, size(MATERIALS)
      call rossfast_d3r_material_from_id(MATERIALS(i), material, found)
      call expect_true(found, trim(MATERIALS(i))//' material found', failures)
      parameters(i) = rossfast_d3r_kernel_parameters_t()
      parameters(i)%material = material
      parameters(i)%equal_internal_substeps = 8

      k = conductivity_from_head(-101.0_real64, material)
      forcings(i) = rossfast_d3r_forcing_t()
      forcings(i)%top_flux_cm_per_day = 0.01_real64 * k
      forcings(i)%bottom_flux_upward_cm_per_day = -0.004_real64 * k

      if (allocated(initial_state)) deallocate(initial_state)
      allocate(rossfast_d3r_state_t :: initial_state)
      select type(state => initial_state)
      type is (rossfast_d3r_state_t)
        state%active_nodes = ROSSFAST_D3R_N_CELLS
        allocate(state%pressure_head_cm(ROSSFAST_D3R_N_CELLS), state%water_content(ROSSFAST_D3R_N_CELLS))
        state%pressure_head_cm = -101.0_real64
        state%water_content = theta_from_head(-101.0_real64, material)
      class default
        error stop 281
      end select
      call left_states(i)%initialize(818100_int64 + int(i, int64), initial_state, ok_left, 0.0_real64)
      call right_states(i)%initialize(828100_int64 + int(i, int64), initial_state, ok_right, 0.0_real64)
      call expect_true(ok_left .and. ok_right, trim(MATERIALS(i))//' twin states initialized', failures)

      columns(i) = fmr_rossfast_application_column_t()
      columns(i)%column_id = 81800_int64 + int(i, int64)
      columns(i)%template_id = templates(1)%template_id
      columns(i)%parameter_ref = int(i, int64)
      columns(i)%forcing_handle = int(i, int64)
      columns(i)%state_handle = int(i, int64)
      columns(i)%execution_class = FMR_EXECUTION_EASY
    end do
    if (allocated(initial_state)) deallocate(initial_state)

    numerical = canonical_numerical_config_t()
    numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    numerical%transaction%mass_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    call apply_rossfast_d3r_retry_policy(numerical)
    numerical%max_committed_substeps = 32
    numerical%progress_tolerance = 0.0_real64
  end subroutine initialize_application

  subroutine expect_all_unpublished(states, label, failures)
    type(kernel_committed_state_t), intent(in) :: states(:)
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    integer :: i
    do i = 1, size(states)
      call expect_true(states(i)%current_revision() == 0_int64, label, failures)
    end do
  end subroutine expect_all_unpublished

  pure real(real64) function theta_from_head(head_cm, material) result(theta)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m, s
    m = 1.0_real64 - 1.0_real64 / material%n
    s = (1.0_real64 + abs(material%alpha_per_cm * head_cm)**material%n)**(-m)
    theta = material%theta_r + (material%theta_s - material%theta_r) * s
  end function theta_from_head

  pure real(real64) function conductivity_from_head(head_cm, material) result(conductivity)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m, s, term
    m = 1.0_real64 - 1.0_real64 / material%n
    s = (1.0_real64 + abs(material%alpha_per_cm * head_cm)**material%n)**(-m)
    term = (1.0_real64 - s**(1.0_real64 / m))**m
    conductivity = material%ksatfit_cm_per_day * s**material%lambda * (1.0_real64 - term)**2
  end function conductivity_from_head

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(a,a)') 'FAIL ', trim(label)
    end if
  end subroutine expect_true

end program test_fci81_rossfast_application_composition

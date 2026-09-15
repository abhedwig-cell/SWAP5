program test_ross11_in_memory_application_composition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_EXECUTION_EASY
  use mod_fmr_serialized_kernel_backend, only: FMR_SERIALIZED_KERNEL_OK
  use mod_fmr_rossfast_application_selection, only: fmr_rossfast_application_column_t, &
       FMR_APPLICATION_MODEL_ROSSFAST_D3R
  use mod_fmr_rossfast_application_config, only: fmr_rossfast_application_config_t, &
       FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL, FMR_ROSSFAST_CONFIG_MISSING, &
       FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, FMR_ROSSFAST_CONFIG_COLUMN_CONFLICT
  use mod_fmr_rossfast_registry_dispatch, only: fmr_rossfast_dispatch_result_t, &
       FMR_ROSSFAST_DISPATCH_OK, FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED, &
       FMR_ROSSFAST_COLUMN_OK, FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED
  use mod_fmr_rossfast_application_runtime, only: fmr_rossfast_application_outcome_t, &
       fmr_run_rossfast_application, FMR_ROSSFAST_APPLICATION_OK, &
       FMR_ROSSFAST_APPLICATION_CONFIG_REJECTED, FMR_ROSSFAST_APPLICATION_ASSET_PROVIDER_REJECTED
  use mod_rossfast_application_config_file_adapter, only: fmr_read_rossfast_application_config_file, &
       FMR_ROSSFAST_CONFIG_FILE_OK
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_state_t, &
       rossfast_d3r_forcing_t, rossfast_d3r_material_from_id, ROSSFAST_D3R_N_CELLS, &
       ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_kernel_model_adapter, only: rossfast_d3r_kernel_parameters_t
  implicit none

  character(len=3), parameter :: MATERIALS(6) = &
       [character(len=3) :: 'B01', 'B12', 'O01', 'O05', 'O14', 'O18']
  character(len=512) :: asset_root, config_file
  integer :: failures

  call get_command_argument(1, asset_root)
  call get_command_argument(2, config_file)
  if (len_trim(asset_root) == 0 .or. len_trim(config_file) == 0) &
       error stop 'usage: test_ross11 ASSET_ROOT CONFIG_FILE'

  failures = 0
  call test_typed_six_material_application(trim(asset_root), failures)
  call test_external_file_adapter_composes_to_runtime(trim(asset_root), trim(config_file), failures)
  call test_missing_config_fails_before_dispatch(trim(asset_root), failures)
  call test_unsupported_model_fails_before_dispatch(trim(asset_root), failures)
  call test_prebound_column_conflict_fails_before_dispatch(trim(asset_root), failures)
  call test_empty_asset_root_fails_before_dispatch(failures)
  call test_missing_assets_fail_in_batch_preflight(failures)

  if (failures /= 0) then
    write(*,'(a,i0)') 'ROSS11_IN_MEMORY_APPLICATION_COMPOSITION FAIL failures=', failures
    error stop 1
  end if
  write(*,'(a)') 'ROSS11_IN_MEMORY_APPLICATION_COMPOSITION PASS'

contains

  subroutine test_typed_six_material_application(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_application_config_t) :: app_config
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(canonical_numerical_config_t) :: numerical
    integer :: i

    call initialize_application_batch(columns, templates, parameters, forcings, states, numerical, failures)
    call valid_application_config(app_config)
    call fmr_run_rossfast_application(app_config, root, columns, templates, parameters, forcings, states, &
         numerical, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, outcome)

    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_OK, 'typed application status', failures)
    call expect_true(outcome%dispatch_status == FMR_ROSSFAST_DISPATCH_OK, 'typed dispatch status', failures)
    call expect_true(outcome%asset_registry_bound .and. outcome%dispatch_invoked, &
         'typed route reached dispatcher', failures)
    call expect_true(size(results) == size(MATERIALS), 'typed result count', failures)
    do i = 1, min(size(results), size(MATERIALS))
      call expect_true(results(i)%status == FMR_ROSSFAST_COLUMN_OK, &
           trim(MATERIALS(i))//' column status', failures)
      call expect_true(results(i)%execution%status == FMR_SERIALIZED_KERNEL_OK .and. &
           results(i)%execution%completed .and. results(i)%execution%committed, &
           trim(MATERIALS(i))//' committed', failures)
      call expect_true(states(i)%current_revision() == 1_int64, &
           trim(MATERIALS(i))//' exactly one publish', failures)
      call expect_true(results(i)%execution%diagnostics%linear_solves >= 24 .and. &
           mod(results(i)%execution%diagnostics%linear_solves, 24) == 0, &
           trim(MATERIALS(i))//' real D3R kernel reached', failures)
      write(*,'(a,1x,a,1x,i0)') 'ROSS11_MATERIAL', trim(MATERIALS(i)), &
           results(i)%execution%diagnostics%linear_solves
    end do
  end subroutine test_typed_six_material_application

  subroutine test_external_file_adapter_composes_to_runtime(root, path, failures)
    character(len=*), intent(in) :: root, path
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_application_config_t) :: app_config
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(canonical_numerical_config_t) :: numerical
    integer :: file_status

    call initialize_application_batch(columns, templates, parameters, forcings, states, numerical, failures)
    call fmr_read_rossfast_application_config_file(path, app_config, file_status)
    call expect_true(file_status == FMR_ROSSFAST_CONFIG_FILE_OK, 'file adapter status', failures)
    call fmr_run_rossfast_application(app_config, root, columns(1:1), templates, parameters(1:1), &
         forcings(1:1), states(1:1), numerical, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, outcome)
    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_OK, 'file-to-runtime application status', failures)
    call expect_true(size(results) == 1 .and. states(1)%current_revision() == 1_int64, &
         'file-to-runtime exactly one publish', failures)
    write(*,'(a)') 'ROSS11_FILE_ADAPTER_TO_TYPED_RUNTIME PASS'
  end subroutine test_external_file_adapter_composes_to_runtime

  subroutine test_missing_config_fails_before_dispatch(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_config_t) :: app_config
    call run_rejected_config_case(root, app_config, FMR_ROSSFAST_CONFIG_MISSING, 'missing config', failures)
  end subroutine test_missing_config_fails_before_dispatch

  subroutine test_unsupported_model_fails_before_dispatch(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_config_t) :: app_config
    app_config%supplied = .true.
    app_config%key = FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL
    app_config%value = 'REFERENCE_RICHARDS'
    call run_rejected_config_case(root, app_config, FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, &
         'unsupported model', failures)
  end subroutine test_unsupported_model_fails_before_dispatch

  subroutine test_prebound_column_conflict_fails_before_dispatch(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_application_config_t) :: app_config
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(canonical_numerical_config_t) :: numerical

    call initialize_application_batch(columns, templates, parameters, forcings, states, numerical, failures)
    call valid_application_config(app_config)
    columns(1)%model_key = FMR_APPLICATION_MODEL_ROSSFAST_D3R
    call fmr_run_rossfast_application(app_config, root, columns, templates, parameters, forcings, states, &
         numerical, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, outcome)
    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_CONFIG_REJECTED .and. &
         outcome%config_status == FMR_ROSSFAST_CONFIG_COLUMN_CONFLICT, &
         'prebound config conflict rejected', failures)
    call expect_true(.not. outcome%asset_registry_bound .and. .not. outcome%dispatch_invoked, &
         'prebound conflict stops before registry/dispatch', failures)
    call expect_true(size(results) == 0, 'prebound conflict no results', failures)
    call expect_all_unpublished(states, 'prebound conflict no state mutation', failures)
  end subroutine test_prebound_column_conflict_fails_before_dispatch

  subroutine test_empty_asset_root_fails_before_dispatch(failures)
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_application_config_t) :: app_config
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(canonical_numerical_config_t) :: numerical

    call initialize_application_batch(columns, templates, parameters, forcings, states, numerical, failures)
    call valid_application_config(app_config)
    call fmr_run_rossfast_application(app_config, '', columns, templates, parameters, forcings, states, numerical, &
         0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, outcome)
    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_ASSET_PROVIDER_REJECTED, &
         'empty asset root rejected', failures)
    call expect_true(.not. outcome%asset_registry_bound .and. .not. outcome%dispatch_invoked, &
         'empty asset root stops before dispatch', failures)
    call expect_true(size(results) == 0, 'empty asset root no results', failures)
    call expect_all_unpublished(states, 'empty asset root no state mutation', failures)
  end subroutine test_empty_asset_root_fails_before_dispatch

  subroutine test_missing_assets_fail_in_batch_preflight(failures)
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_application_config_t) :: app_config
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(canonical_numerical_config_t) :: numerical
    integer :: i

    call initialize_application_batch(columns, templates, parameters, forcings, states, numerical, failures)
    call valid_application_config(app_config)
    call fmr_run_rossfast_application(app_config, 'definitely-missing-rossfast-assets', columns, templates, &
         parameters, forcings, states, numerical, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, outcome)
    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_ASSET_PROVIDER_REJECTED .and. &
         outcome%dispatch_status == FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED, &
         'missing assets mapped to provider rejection', failures)
    call expect_true(outcome%asset_registry_bound .and. outcome%dispatch_invoked, &
         'missing assets reached batch preflight', failures)
    call expect_true(size(results) == size(MATERIALS), 'missing assets full batch result', failures)
    do i = 1, size(results)
      call expect_true(results(i)%status == FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED, &
           'missing assets provider status', failures)
    end do
    call expect_all_unpublished(states, 'missing assets no physical state mutation', failures)
  end subroutine test_missing_assets_fail_in_batch_preflight

  subroutine run_rejected_config_case(root, app_config, expected_config_status, label, failures)
    character(len=*), intent(in) :: root, label
    type(fmr_rossfast_application_config_t), intent(in) :: app_config
    integer, intent(in) :: expected_config_status
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_application_outcome_t) :: outcome
    type(canonical_numerical_config_t) :: numerical

    call initialize_application_batch(columns, templates, parameters, forcings, states, numerical, failures)
    call fmr_run_rossfast_application(app_config, root, columns, templates, parameters, forcings, states, &
         numerical, 0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, outcome)
    call expect_true(outcome%status == FMR_ROSSFAST_APPLICATION_CONFIG_REJECTED .and. &
         outcome%config_status == expected_config_status, trim(label)//' status', failures)
    call expect_true(.not. outcome%asset_registry_bound .and. .not. outcome%dispatch_invoked, &
         trim(label)//' stops before registry/dispatch', failures)
    call expect_true(size(results) == 0, trim(label)//' no results', failures)
    call expect_all_unpublished(states, trim(label)//' no state mutation', failures)
  end subroutine run_rejected_config_case

  subroutine valid_application_config(config)
    type(fmr_rossfast_application_config_t), intent(out) :: config
    config = fmr_rossfast_application_config_t()
    config%supplied = .true.
    config%key = FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL
    config%value = FMR_APPLICATION_MODEL_ROSSFAST_D3R
  end subroutine valid_application_config

  subroutine initialize_application_batch(columns, templates, parameters, forcings, states, numerical, failures)
    type(fmr_rossfast_application_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), allocatable, intent(out) :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable, intent(out) :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(canonical_numerical_config_t), intent(out) :: numerical
    integer, intent(inout) :: failures
    type(rossfast_d3r_material_t) :: material
    class(transaction_state_t), allocatable :: initial_state
    real(real64) :: k
    logical :: found, ok
    integer :: i

    allocate(columns(size(MATERIALS)), parameters(size(MATERIALS)), forcings(size(MATERIALS)), &
         states(size(MATERIALS)), templates(1))
    templates(1) = fmr_template_t()
    templates(1)%template_id = 7811_int64
    templates(1)%physics_topology_id = 81101_int64
    templates(1)%vertical_layout_id = 81102_int64
    templates(1)%state_layout_id = 81103_int64
    templates(1)%solver_interface_id = 81104_int64
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
        allocate(state%pressure_head_cm(ROSSFAST_D3R_N_CELLS))
        allocate(state%water_content(ROSSFAST_D3R_N_CELLS))
        state%pressure_head_cm = -101.0_real64
        state%water_content = theta_from_head(-101.0_real64, material)
      class default
        error stop 211
      end select
      call states(i)%initialize(781100_int64 + int(i, int64), initial_state, ok, 0.0_real64)
      call expect_true(ok, trim(MATERIALS(i))//' state initialized', failures)

      columns(i) = fmr_rossfast_application_column_t()
      columns(i)%column_id = 71100_int64 + int(i, int64)
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
  end subroutine initialize_application_batch

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

end program test_ross11_in_memory_application_composition

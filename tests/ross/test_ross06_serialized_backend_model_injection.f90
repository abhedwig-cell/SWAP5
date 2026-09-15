program test_ross06_serialized_backend_model_injection
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_INVALID_REQUEST
  use mod_kernel_transactions, only: kernel_committed_state_t, KERNEL_STATUS_NOT_ADMITTED, &
       KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_kernel_backend, only: fmr_serialized_kernel_backend_t, &
       fmr_serialized_kernel_execution_result_t, FMR_BACKEND_SERIALIZED_INJECTED_KERNEL, &
       FMR_SERIALIZED_KERNEL_OK, FMR_SERIALIZED_KERNEL_ROUTING_REJECTED, &
       FMR_SERIALIZED_KERNEL_TRIAL_REJECTED
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       rossfast_d3r_select_transaction_window, ROSSFAST_D3R_OUTER_HORIZON_DAY, &
       ROSSFAST_D3R_MIN_FULL_DURATION_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_state_t, &
       rossfast_d3r_forcing_t, rossfast_d3r_material_from_id, ROSSFAST_D3R_N_CELLS, &
       ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t
  use mod_rossfast_d3r_table_provider, only: rossfast_d3r_table_registry_t, &
       bind_rossfast_d3r_table_registry, ROSSFAST_TABLE_PROVIDER_OK
  use mod_rossfast_d3r_kernel_model_adapter, only: rossfast_d3r_kernel_parameters_t, &
       rossfast_d3r_kernel_model_adapter_t
  implicit none

  character(len=3), parameter :: MATERIALS(6) = &
       [character(len=3) :: 'B01', 'B12', 'O01', 'O05', 'O14', 'O18']
  character(len=512) :: asset_root
  integer :: i, failures

  call get_command_argument(1, asset_root)
  if (len_trim(asset_root) == 0) error stop 'usage: test_ross06 ASSET_ROOT'

  failures = 0
  do i = 1, size(MATERIALS)
    call test_material(trim(MATERIALS(i)), trim(asset_root), failures)
  end do
  call test_routing_mismatch_fail_closed('O14', trim(asset_root), failures)
  call test_wrong_substeps_fail_closed('O14', trim(asset_root), failures)
  call test_off_grid_fail_closed('O14', trim(asset_root), failures)

  if (failures /= 0) then
    write(*,'(a,i0)') 'ROSS06_SERIALIZED_BACKEND_MODEL_INJECTION FAIL failures=', failures
    error stop 1
  end if
  write(*,'(a)') 'ROSS06_SERIALIZED_BACKEND_MODEL_INJECTION PASS'

contains

  subroutine test_material(material_id, root, failures)
    character(len=*), intent(in) :: material_id, root
    integer, intent(inout) :: failures
    type(rossfast_d3r_material_t) :: material
    type(rossfast_d3r_table_kernel_t), target :: trial_kernel

    call load_kernel(material_id, root, material, trial_kernel)
    call run_positive_route(material, trial_kernel, .false., failures)
    call run_positive_route(material, trial_kernel, .true., failures)
    write(*,'(a,1x,a,1x,a)') 'ROSS06_MATERIAL', trim(material_id), 'SERIALIZED_PRODUCTION_AND_CHAIN_PASS'
  end subroutine test_material

  subroutine run_positive_route(material, trial_kernel, force_chain, failures)
    type(rossfast_d3r_material_t), intent(in) :: material
    type(rossfast_d3r_table_kernel_t), target, intent(in) :: trial_kernel
    logical, intent(in) :: force_chain
    integer, intent(inout) :: failures
    type(rossfast_d3r_kernel_model_adapter_t), target :: model
    type(fmr_serialized_kernel_backend_t) :: backend
    type(kernel_committed_state_t) :: committed
    type(rossfast_d3r_kernel_parameters_t) :: parameters
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_serialized_kernel_execution_result_t) :: result
    integer :: min_transactions

    call initialize_case(material, trial_kernel, 8, model, backend, committed, parameters, forcing, &
         config, column, template, failures)

    if (force_chain) then
      call backend%execute(column, template, parameters, forcing, committed, config, 0.0_real64, &
           ROSSFAST_D3R_OUTER_HORIZON_DAY, result, ross06_two_half_selector)
      min_transactions = 2
    else
      call backend%execute(column, template, parameters, forcing, committed, config, 0.0_real64, &
           ROSSFAST_D3R_OUTER_HORIZON_DAY, result, rossfast_d3r_select_transaction_window)
      min_transactions = 1
    end if

    call expect_true(result%status == FMR_SERIALIZED_KERNEL_OK, trim(material%material_id)//' backend status', failures)
    call expect_true(result%admission_assessed .and. result%admitted, &
         trim(material%material_id)//' admitted', failures)
    call expect_true(result%completed .and. result%committed, trim(material%material_id)//' committed', failures)
    call expect_true(result%kernel%status == CANONICAL_STATUS_COMPLETED .and. result%kernel%completed, &
         trim(material%material_id)//' kernel completed', failures)
    call expect_close(result%kernel%completed_t, ROSSFAST_D3R_OUTER_HORIZON_DAY, 1.0e-15_real64, &
         trim(material%material_id)//' kernel endpoint', failures)
    call expect_true(result%diagnostics%transaction_calls >= min_transactions, &
         trim(material%material_id)//' transaction count', failures)
    call expect_true(result%diagnostics%accepted_substeps == result%diagnostics%transaction_calls, &
         trim(material%material_id)//' accepted transactions', failures)
    call expect_true(result%diagnostics%attempts >= result%diagnostics%transaction_calls, &
         trim(material%material_id)//' attempts cover transactions', failures)
    call expect_true(result%diagnostics%retries == &
         result%diagnostics%attempts - result%diagnostics%transaction_calls, &
         trim(material%material_id)//' retry accounting', failures)
    call expect_true(result%diagnostics%linear_solves >= 24 * result%diagnostics%accepted_substeps, &
         trim(material%material_id)//' real table kernel executed', failures)
    call expect_true(mod(result%diagnostics%linear_solves, 24) == 0, &
         trim(material%material_id)//' certificate solve granularity', failures)
    call expect_true(result%kernel%mass%complete, trim(material%material_id)//' mass complete', failures)
    call expect_true(result%kernel%mass%accepted_transaction_count == result%diagnostics%accepted_substeps, &
         trim(material%material_id)//' mass transaction count', failures)
    call expect_true(result%initial_revision == 0_int64 .and. result%final_revision == 1_int64, &
         trim(material%material_id)//' exactly one serialized publish', failures)
    call expect_true(result%commit_status == KERNEL_COMMIT_STATUS_COMMITTED, &
         trim(material%material_id)//' commit status', failures)
    call expect_true(result%final_committed_time_bound, trim(material%material_id)//' final time bound', failures)
    call expect_close(result%final_committed_time, ROSSFAST_D3R_OUTER_HORIZON_DAY, 1.0e-15_real64, &
         trim(material%material_id)//' final committed time', failures)
  end subroutine run_positive_route

  subroutine test_routing_mismatch_fail_closed(material_id, root, failures)
    character(len=*), intent(in) :: material_id, root
    integer, intent(inout) :: failures
    type(rossfast_d3r_material_t) :: material
    type(rossfast_d3r_table_kernel_t), target :: trial_kernel
    type(rossfast_d3r_kernel_model_adapter_t), target :: model
    type(fmr_serialized_kernel_backend_t) :: backend
    type(kernel_committed_state_t) :: committed
    type(rossfast_d3r_kernel_parameters_t) :: parameters
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_serialized_kernel_execution_result_t) :: result

    call load_kernel(material_id, root, material, trial_kernel)
    call initialize_case(material, trial_kernel, 8, model, backend, committed, parameters, forcing, config, &
         column, template, failures)
    column%backend_id = 2
    call backend%execute(column, template, parameters, forcing, committed, config, 0.0_real64, &
         ROSSFAST_D3R_OUTER_HORIZON_DAY, result, rossfast_d3r_select_transaction_window)

    call expect_true(result%status == FMR_SERIALIZED_KERNEL_ROUTING_REJECTED, 'routing mismatch rejected', failures)
    call expect_true(.not. result%admission_assessed .and. .not. result%committed, &
         'routing mismatch never reaches physical admission', failures)
    call expect_true(result%final_revision == 0_int64 .and. committed%current_revision() == 0_int64, &
         'routing mismatch state untouched', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'routing mismatch no transaction', failures)
  end subroutine test_routing_mismatch_fail_closed

  subroutine test_wrong_substeps_fail_closed(material_id, root, failures)
    character(len=*), intent(in) :: material_id, root
    integer, intent(inout) :: failures
    type(rossfast_d3r_material_t) :: material
    type(rossfast_d3r_table_kernel_t), target :: trial_kernel
    type(rossfast_d3r_kernel_model_adapter_t), target :: model
    type(fmr_serialized_kernel_backend_t) :: backend
    type(kernel_committed_state_t) :: committed
    type(rossfast_d3r_kernel_parameters_t) :: parameters
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_serialized_kernel_execution_result_t) :: result

    call load_kernel(material_id, root, material, trial_kernel)
    call initialize_case(material, trial_kernel, 4, model, backend, committed, parameters, forcing, config, &
         column, template, failures)
    call backend%execute(column, template, parameters, forcing, committed, config, 0.0_real64, &
         ROSSFAST_D3R_OUTER_HORIZON_DAY, result, rossfast_d3r_select_transaction_window)

    call expect_true(result%status == FMR_SERIALIZED_KERNEL_TRIAL_REJECTED, 'wrong substeps trial rejected', failures)
    call expect_true(result%kernel%status == KERNEL_STATUS_NOT_ADMITTED, 'wrong substeps kernel not admitted', failures)
    call expect_true(result%admission_assessed .and. .not. result%admitted, 'wrong substeps admission false', failures)
    call expect_true(result%diagnostics%admission_rejections == 1 .and. &
         result%diagnostics%transaction_calls == 0, 'wrong substeps rejected before transaction', failures)
    call expect_true(result%final_revision == 0_int64 .and. committed%current_revision() == 0_int64, &
         'wrong substeps state untouched', failures)
  end subroutine test_wrong_substeps_fail_closed

  subroutine test_off_grid_fail_closed(material_id, root, failures)
    character(len=*), intent(in) :: material_id, root
    integer, intent(inout) :: failures
    type(rossfast_d3r_material_t) :: material
    type(rossfast_d3r_table_kernel_t), target :: trial_kernel
    type(rossfast_d3r_kernel_model_adapter_t), target :: model
    type(fmr_serialized_kernel_backend_t) :: backend
    type(kernel_committed_state_t) :: committed
    type(rossfast_d3r_kernel_parameters_t) :: parameters
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_serialized_kernel_execution_result_t) :: result
    real(real64) :: off_grid_t1

    call load_kernel(material_id, root, material, trial_kernel)
    call initialize_case(material, trial_kernel, 8, model, backend, committed, parameters, forcing, config, &
         column, template, failures)
    off_grid_t1 = ROSSFAST_D3R_OUTER_HORIZON_DAY - 0.1_real64 * ROSSFAST_D3R_MIN_FULL_DURATION_DAY
    call backend%execute(column, template, parameters, forcing, committed, config, 0.0_real64, off_grid_t1, &
         result, rossfast_d3r_select_transaction_window)

    call expect_true(result%status == FMR_SERIALIZED_KERNEL_TRIAL_REJECTED, 'off-grid trial rejected', failures)
    call expect_true(result%kernel%status == CANONICAL_STATUS_INVALID_REQUEST, 'off-grid kernel invalid request', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'off-grid rejected before transaction', failures)
    call expect_true(result%final_revision == 0_int64 .and. committed%current_revision() == 0_int64, &
         'off-grid state untouched', failures)
  end subroutine test_off_grid_fail_closed

  subroutine load_kernel(material_id, root, material, trial_kernel)
    character(len=*), intent(in) :: material_id, root
    type(rossfast_d3r_material_t), intent(out) :: material
    type(rossfast_d3r_table_kernel_t), target, intent(out) :: trial_kernel
    type(rossfast_d3r_table_registry_t) :: registry
    logical :: found, valid
    integer :: provider_status

    call rossfast_d3r_material_from_id(material_id, material, found)
    if (.not. found) error stop 101
    call bind_rossfast_d3r_table_registry(registry, root, valid)
    if (.not. valid) error stop 102
    call registry%initialize_kernel(trial_kernel, material, valid, provider_status)
    if (.not. valid .or. provider_status /= ROSSFAST_TABLE_PROVIDER_OK) error stop 103
  end subroutine load_kernel

  subroutine initialize_case(material, trial_kernel, substeps, model, backend, committed, parameters, forcing, &
                             config, column, template, failures)
    type(rossfast_d3r_material_t), intent(in) :: material
    type(rossfast_d3r_table_kernel_t), target, intent(in) :: trial_kernel
    integer, intent(in) :: substeps
    type(rossfast_d3r_kernel_model_adapter_t), target, intent(out) :: model
    type(fmr_serialized_kernel_backend_t), intent(out) :: backend
    type(kernel_committed_state_t), intent(out) :: committed
    type(rossfast_d3r_kernel_parameters_t), intent(out) :: parameters
    type(rossfast_d3r_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: initial_state
    real(real64) :: k
    logical :: valid, ok

    call model%bind_trial_kernel(trial_kernel, valid)
    call expect_true(valid, trim(material%material_id)//' adapter bind', failures)
    call backend%initialize(model, valid)
    call expect_true(valid, trim(material%material_id)//' serialized backend bind', failures)

    parameters = rossfast_d3r_kernel_parameters_t()
    parameters%material = material
    parameters%equal_internal_substeps = substeps

    allocate(rossfast_d3r_state_t :: initial_state)
    select type(state => initial_state)
    type is (rossfast_d3r_state_t)
      state%active_nodes = ROSSFAST_D3R_N_CELLS
      allocate(state%pressure_head_cm(ROSSFAST_D3R_N_CELLS))
      allocate(state%water_content(ROSSFAST_D3R_N_CELLS))
      state%pressure_head_cm = -101.0_real64
      state%water_content = theta_from_head(-101.0_real64, material)
    class default
      error stop 201
    end select
    call committed%initialize(606_int64, initial_state, ok, 0.0_real64)
    call expect_true(ok, trim(material%material_id)//' committed init', failures)

    k = conductivity_from_head(-101.0_real64, material)
    forcing%top_flux_cm_per_day = 0.01_real64 * k
    forcing%bottom_flux_upward_cm_per_day = -0.004_real64 * k

    config = canonical_numerical_config_t()
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%mass_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    call apply_rossfast_d3r_retry_policy(config)
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64

    column = fmr_logical_column_t()
    column%column_id = 606_int64
    column%template_id = 6606_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
    template = fmr_template_t()
    template%template_id = column%template_id
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
  end subroutine initialize_case

  subroutine ross06_two_half_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    real(real64) :: capped_t1

    capped_t1 = min(requested_t1, cursor + 0.5_real64 * ROSSFAST_D3R_OUTER_HORIZON_DAY)
    call rossfast_d3r_select_transaction_window(cursor, capped_t1, target_t1, max_retries_cap, valid)
  end subroutine ross06_two_half_selector

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

  subroutine expect_close(actual, expected, tolerance, label, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call expect_true(abs(actual - expected) <= tolerance, label, failures)
  end subroutine expect_close

end program test_ross06_serialized_backend_model_injection

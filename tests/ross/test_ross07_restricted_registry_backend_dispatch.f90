program test_ross07_restricted_registry_backend_dispatch
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_kernel_backend, only: FMR_BACKEND_SERIALIZED_INJECTED_KERNEL, &
       FMR_SERIALIZED_KERNEL_OK
  use mod_fmr_rossfast_registry_dispatch, only: fmr_rossfast_registry_dispatcher_t, &
       fmr_rossfast_dispatch_result_t, FMR_ROSSFAST_DISPATCH_OK, &
       FMR_ROSSFAST_DISPATCH_ROUTING_REJECTED, FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED, &
       FMR_ROSSFAST_COLUMN_OK, FMR_ROSSFAST_COLUMN_ROUTING_REJECTED, &
       FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED
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
  if (len_trim(asset_root) == 0) error stop 'usage: test_ross07 ASSET_ROOT'

  failures = 0
  call test_six_material_registry_dispatch(trim(asset_root), failures)
  call test_mixed_backend_rejected_before_commit(trim(asset_root), failures)
  call test_duplicate_state_handle_rejected_before_commit(trim(asset_root), failures)
  call test_missing_asset_root_rejected_before_commit(trim(asset_root), failures)

  if (failures /= 0) then
    write(*,'(a,i0)') 'ROSS07_RESTRICTED_REGISTRY_BACKEND_DISPATCH FAIL failures=', failures
    error stop 1
  end if
  write(*,'(a)') 'ROSS07_RESTRICTED_REGISTRY_BACKEND_DISPATCH PASS'

contains

  subroutine test_six_material_registry_dispatch(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_registry_dispatcher_t) :: dispatcher
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(canonical_numerical_config_t) :: config
    logical :: valid
    integer :: dispatch_status, i

    call initialize_batch(columns, templates, parameters, forcings, states, config, failures)
    call dispatcher%initialize(root, valid)
    call expect_true(valid, 'dispatcher bind', failures)
    call dispatcher%execute_batch(columns, templates, parameters, forcings, states, config, &
         0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, dispatch_status)

    call expect_true(dispatch_status == FMR_ROSSFAST_DISPATCH_OK, 'six-material dispatch status', failures)
    call expect_true(size(results) == size(MATERIALS), 'six-material result size', failures)
    do i = 1, size(MATERIALS)
      call expect_true(results(i)%status == FMR_ROSSFAST_COLUMN_OK, &
           trim(MATERIALS(i))//' registry column status', failures)
      call expect_true(results(i)%provider_status == 0, trim(MATERIALS(i))//' provider status', failures)
      call expect_true(results(i)%dispatch_ordinal == size(MATERIALS) + 1 - i, &
           trim(MATERIALS(i))//' deterministic ordinal', failures)
      call expect_true(results(i)%execution%status == FMR_SERIALIZED_KERNEL_OK, &
           trim(MATERIALS(i))//' serialized backend status', failures)
      call expect_true(results(i)%execution%completed .and. results(i)%execution%committed, &
           trim(MATERIALS(i))//' serialized committed', failures)
      call expect_true(results(i)%execution%initial_revision == 0_int64 .and. &
           results(i)%execution%final_revision == 1_int64, &
           trim(MATERIALS(i))//' exactly one publish', failures)
      call expect_true(states(i)%current_revision() == 1_int64, &
           trim(MATERIALS(i))//' registry state revision', failures)
      call expect_true(results(i)%execution%diagnostics%transaction_calls >= 1, &
           trim(MATERIALS(i))//' transaction reached', failures)
      call expect_true(results(i)%execution%diagnostics%linear_solves >= 24, &
           trim(MATERIALS(i))//' real kernel reached', failures)
      call expect_true(mod(results(i)%execution%diagnostics%linear_solves, 24) == 0, &
           trim(MATERIALS(i))//' certificate solve granularity', failures)
      call expect_true(results(i)%execution%kernel%mass%complete, &
           trim(MATERIALS(i))//' mass complete', failures)
      call expect_true(results(i)%execution%final_committed_time_bound, &
           trim(MATERIALS(i))//' committed time bound', failures)
      call expect_close(results(i)%execution%final_committed_time, ROSSFAST_D3R_OUTER_HORIZON_DAY, &
           1.0e-15_real64, trim(MATERIALS(i))//' committed endpoint', failures)
      write(*,'(a,1x,a,1x,i0,1x,i0)') 'ROSS07_MATERIAL', trim(MATERIALS(i)), &
           results(i)%dispatch_ordinal, results(i)%execution%diagnostics%linear_solves
    end do
  end subroutine test_six_material_registry_dispatch

  subroutine test_mixed_backend_rejected_before_commit(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_registry_dispatcher_t) :: dispatcher
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(canonical_numerical_config_t) :: config
    logical :: valid
    integer :: dispatch_status, i

    call initialize_batch(columns, templates, parameters, forcings, states, config, failures)
    columns(3)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call dispatcher%initialize(root, valid)
    call expect_true(valid, 'mixed dispatcher bind', failures)
    call dispatcher%execute_batch(columns, templates, parameters, forcings, states, config, &
         0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, dispatch_status)

    call expect_true(dispatch_status == FMR_ROSSFAST_DISPATCH_ROUTING_REJECTED, &
         'mixed backend batch rejected', failures)
    do i = 1, size(states)
      call expect_true(results(i)%status == FMR_ROSSFAST_COLUMN_ROUTING_REJECTED, &
           'mixed backend result rejected', failures)
      call expect_true(states(i)%current_revision() == 0_int64, &
           'mixed backend no state mutation', failures)
    end do
  end subroutine test_mixed_backend_rejected_before_commit

  subroutine test_duplicate_state_handle_rejected_before_commit(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_registry_dispatcher_t) :: dispatcher
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(canonical_numerical_config_t) :: config
    logical :: valid
    integer :: dispatch_status, i

    call initialize_batch(columns, templates, parameters, forcings, states, config, failures)
    columns(2)%state_handle = columns(1)%state_handle
    call dispatcher%initialize(root, valid)
    call expect_true(valid, 'duplicate-state dispatcher bind', failures)
    call dispatcher%execute_batch(columns, templates, parameters, forcings, states, config, &
         0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, dispatch_status)

    call expect_true(dispatch_status == FMR_ROSSFAST_DISPATCH_ROUTING_REJECTED, &
         'duplicate state batch rejected', failures)
    do i = 1, size(states)
      call expect_true(states(i)%current_revision() == 0_int64, &
           'duplicate state no mutation', failures)
    end do
  end subroutine test_duplicate_state_handle_rejected_before_commit

  subroutine test_missing_asset_root_rejected_before_commit(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_registry_dispatcher_t) :: dispatcher
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(canonical_numerical_config_t) :: config
    character(len=:), allocatable :: missing_root
    logical :: valid
    integer :: dispatch_status, i

    call initialize_batch(columns, templates, parameters, forcings, states, config, failures)
    missing_root = trim(root)//'/definitely-missing'
    call dispatcher%initialize(missing_root, valid)
    call expect_true(valid, 'missing-root configuration binds', failures)
    call dispatcher%execute_batch(columns, templates, parameters, forcings, states, config, &
         0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, dispatch_status)

    call expect_true(dispatch_status == FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED, &
         'missing asset preflight rejected', failures)
    do i = 1, size(states)
      call expect_true(results(i)%status == FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED, &
           'missing asset result rejected', failures)
      call expect_true(states(i)%current_revision() == 0_int64, &
           'missing asset no partial commit', failures)
    end do
  end subroutine test_missing_asset_root_rejected_before_commit

  subroutine initialize_batch(columns, templates, parameters, forcings, states, config, failures)
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), allocatable, intent(out) :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable, intent(out) :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(canonical_numerical_config_t), intent(out) :: config
    integer, intent(inout) :: failures
    type(rossfast_d3r_material_t) :: material
    class(transaction_state_t), allocatable :: initial_state
    real(real64) :: k
    logical :: found, ok
    integer :: i

    allocate(columns(size(MATERIALS)), parameters(size(MATERIALS)), forcings(size(MATERIALS)), &
         states(size(MATERIALS)), templates(1))

    templates(1) = fmr_template_t()
    templates(1)%template_id = 7707_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_INJECTED_KERNEL

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
        error stop 201
      end select
      call states(i)%initialize(77000_int64 + int(i, int64), initial_state, ok, 0.0_real64)
      call expect_true(ok, trim(MATERIALS(i))//' state initialized', failures)

      columns(i) = fmr_logical_column_t()
      columns(i)%column_id = 607_int64 - int(i, int64)
      columns(i)%template_id = templates(1)%template_id
      columns(i)%parameter_ref = int(i, int64)
      columns(i)%forcing_handle = int(i, int64)
      columns(i)%state_handle = int(i, int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
    end do
    if (allocated(initial_state)) deallocate(initial_state)

    config = canonical_numerical_config_t()
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%mass_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    call apply_rossfast_d3r_retry_policy(config)
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
  end subroutine initialize_batch

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

end program test_ross07_restricted_registry_backend_dispatch

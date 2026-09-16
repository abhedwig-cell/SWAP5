program test_ross08_explicit_application_model_selection
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_EXECUTION_EASY
  use mod_fmr_serialized_kernel_backend, only: FMR_BACKEND_SERIALIZED_INJECTED_KERNEL, &
       FMR_SERIALIZED_KERNEL_OK
  use mod_fmr_rossfast_application_selection, only: fmr_rossfast_application_column_t, &
       FMR_APPLICATION_MODEL_ROSSFAST_D3R, FMR_ROSSFAST_SELECTION_OK, &
       FMR_ROSSFAST_SELECTION_INVALID_REQUEST, FMR_ROSSFAST_SELECTION_UNSUPPORTED_MODEL, &
       FMR_ROSSFAST_SELECTION_TEMPLATE_CONFLICT, fmr_materialize_rossfast_d3r_registry
  use mod_fmr_rossfast_registry_dispatch, only: fmr_rossfast_registry_dispatcher_t, &
       fmr_rossfast_dispatch_result_t, FMR_ROSSFAST_DISPATCH_OK, FMR_ROSSFAST_COLUMN_OK
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
  if (len_trim(asset_root) == 0) error stop 'usage: test_ross08 ASSET_ROOT'

  failures = 0
  call test_explicit_six_material_selection_and_dispatch(trim(asset_root), failures)
  call test_unknown_model_rejected_atomically(failures)
  call test_mixed_model_batch_rejected_atomically(failures)
  call test_prebound_template_rejected_atomically(failures)
  call test_invalid_handle_rejected_atomically(failures)

  if (failures /= 0) then
    write(*,'(a,i0)') 'ROSS08_EXPLICIT_APPLICATION_MODEL_SELECTION FAIL failures=', failures
    error stop 1
  end if
  write(*,'(a)') 'ROSS08_EXPLICIT_APPLICATION_MODEL_SELECTION PASS'

contains

  subroutine test_explicit_six_material_selection_and_dispatch(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: application_columns(:)
    type(fmr_template_t), allocatable :: application_templates(:), runtime_templates(:)
    type(fmr_logical_column_t), allocatable :: runtime_columns(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_rossfast_dispatch_result_t), allocatable :: results(:)
    type(fmr_rossfast_registry_dispatcher_t) :: dispatcher
    type(canonical_numerical_config_t) :: config
    logical :: valid
    integer :: selection_status, dispatch_status, i

    call initialize_application_batch(application_columns, application_templates, parameters, &
         forcings, states, config, failures)
    call fmr_materialize_rossfast_d3r_registry(application_columns, application_templates, &
         runtime_columns, runtime_templates, selection_status)

    call expect_true(selection_status == FMR_ROSSFAST_SELECTION_OK, 'selection status', failures)
    call expect_true(allocated(runtime_columns) .and. allocated(runtime_templates), &
         'runtime registry materialized', failures)
    if (.not. allocated(runtime_columns) .or. .not. allocated(runtime_templates)) return
    call expect_true(size(runtime_columns) == size(MATERIALS), 'runtime column count', failures)
    call expect_true(size(runtime_templates) == 1, 'runtime template count', failures)
    call expect_true(runtime_templates(1)%compatible_backend_id == FMR_BACKEND_SERIALIZED_INJECTED_KERNEL, &
         'template backend mapped', failures)
    call expect_true(runtime_templates(1)%physics_topology_id == 80801_int64 .and. &
         runtime_templates(1)%vertical_layout_id == 80802_int64 .and. &
         runtime_templates(1)%state_layout_id == 80803_int64 .and. &
         runtime_templates(1)%solver_interface_id == 80804_int64, &
         'template metadata preserved', failures)

    do i = 1, size(runtime_columns)
      call expect_true(runtime_columns(i)%backend_id == FMR_BACKEND_SERIALIZED_INJECTED_KERNEL, &
           trim(MATERIALS(i))//' backend mapped', failures)
      call expect_true(runtime_columns(i)%column_id == application_columns(i)%column_id .and. &
           runtime_columns(i)%template_id == application_columns(i)%template_id .and. &
           runtime_columns(i)%parameter_ref == application_columns(i)%parameter_ref .and. &
           runtime_columns(i)%forcing_handle == application_columns(i)%forcing_handle .and. &
           runtime_columns(i)%state_handle == application_columns(i)%state_handle, &
           trim(MATERIALS(i))//' handles preserved', failures)
    end do

    call dispatcher%initialize(root, valid)
    call expect_true(valid, 'dispatcher initialized', failures)
    call dispatcher%execute_batch(runtime_columns, runtime_templates, parameters, forcings, states, config, &
         0.0_real64, ROSSFAST_D3R_OUTER_HORIZON_DAY, results, dispatch_status)
    call expect_true(dispatch_status == FMR_ROSSFAST_DISPATCH_OK, 'dispatch status', failures)

    do i = 1, size(MATERIALS)
      call expect_true(results(i)%status == FMR_ROSSFAST_COLUMN_OK, &
           trim(MATERIALS(i))//' result status', failures)
      call expect_true(results(i)%execution%status == FMR_SERIALIZED_KERNEL_OK .and. &
           results(i)%execution%completed .and. results(i)%execution%committed, &
           trim(MATERIALS(i))//' real backend committed', failures)
      call expect_true(results(i)%execution%initial_revision == 0_int64 .and. &
           results(i)%execution%final_revision == 1_int64 .and. states(i)%current_revision() == 1_int64, &
           trim(MATERIALS(i))//' exactly one external publish', failures)
      call expect_true(results(i)%execution%diagnostics%linear_solves >= 24 .and. &
           mod(results(i)%execution%diagnostics%linear_solves, 24) == 0, &
           trim(MATERIALS(i))//' real D3R kernel reached', failures)
      write(*,'(a,1x,a,1x,i0,1x,i0)') 'ROSS08_MATERIAL', trim(MATERIALS(i)), &
           results(i)%dispatch_ordinal, results(i)%execution%diagnostics%linear_solves
    end do
  end subroutine test_explicit_six_material_selection_and_dispatch

  subroutine test_unknown_model_rejected_atomically(failures)
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: application_columns(:)
    type(fmr_template_t), allocatable :: application_templates(:), runtime_templates(:)
    type(fmr_logical_column_t), allocatable :: runtime_columns(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(canonical_numerical_config_t) :: config
    integer :: status

    call initialize_application_batch(application_columns, application_templates, parameters, &
         forcings, states, config, failures)
    application_columns(1)%model_key = 'REFERENCE_RICHARDS'
    call fmr_materialize_rossfast_d3r_registry(application_columns, application_templates, &
         runtime_columns, runtime_templates, status)
    call expect_true(status == FMR_ROSSFAST_SELECTION_UNSUPPORTED_MODEL, &
         'reference model not captured by RossFast selection', failures)
    call expect_true(.not. allocated(runtime_columns) .and. .not. allocated(runtime_templates), &
         'unknown model no partial routing materialization', failures)
    call expect_all_unpublished(states, 'unknown model no state mutation', failures)
  end subroutine test_unknown_model_rejected_atomically

  subroutine test_mixed_model_batch_rejected_atomically(failures)
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: application_columns(:)
    type(fmr_template_t), allocatable :: application_templates(:), runtime_templates(:)
    type(fmr_logical_column_t), allocatable :: runtime_columns(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(canonical_numerical_config_t) :: config
    integer :: status

    call initialize_application_batch(application_columns, application_templates, parameters, &
         forcings, states, config, failures)
    application_columns(4)%model_key = 'rossfast_d3r'
    call fmr_materialize_rossfast_d3r_registry(application_columns, application_templates, &
         runtime_columns, runtime_templates, status)
    call expect_true(status == FMR_ROSSFAST_SELECTION_UNSUPPORTED_MODEL, &
         'mixed or normalized model key rejected', failures)
    call expect_true(.not. allocated(runtime_columns) .and. .not. allocated(runtime_templates), &
         'mixed model no partial routing materialization', failures)
    call expect_all_unpublished(states, 'mixed model no state mutation', failures)
  end subroutine test_mixed_model_batch_rejected_atomically

  subroutine test_prebound_template_rejected_atomically(failures)
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: application_columns(:)
    type(fmr_template_t), allocatable :: application_templates(:), runtime_templates(:)
    type(fmr_logical_column_t), allocatable :: runtime_columns(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(canonical_numerical_config_t) :: config
    integer :: status

    call initialize_application_batch(application_columns, application_templates, parameters, &
         forcings, states, config, failures)
    application_templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_materialize_rossfast_d3r_registry(application_columns, application_templates, &
         runtime_columns, runtime_templates, status)
    call expect_true(status == FMR_ROSSFAST_SELECTION_TEMPLATE_CONFLICT, &
         'prebound template conflict rejected', failures)
    call expect_true(.not. allocated(runtime_columns) .and. .not. allocated(runtime_templates), &
         'prebound template no partial routing materialization', failures)
    call expect_all_unpublished(states, 'prebound template no state mutation', failures)
  end subroutine test_prebound_template_rejected_atomically

  subroutine test_invalid_handle_rejected_atomically(failures)
    integer, intent(inout) :: failures
    type(fmr_rossfast_application_column_t), allocatable :: application_columns(:)
    type(fmr_template_t), allocatable :: application_templates(:), runtime_templates(:)
    type(fmr_logical_column_t), allocatable :: runtime_columns(:)
    type(rossfast_d3r_kernel_parameters_t), allocatable :: parameters(:)
    type(rossfast_d3r_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(canonical_numerical_config_t) :: config
    integer :: status

    call initialize_application_batch(application_columns, application_templates, parameters, &
         forcings, states, config, failures)
    application_columns(2)%forcing_handle = 0_int64
    call fmr_materialize_rossfast_d3r_registry(application_columns, application_templates, &
         runtime_columns, runtime_templates, status)
    call expect_true(status == FMR_ROSSFAST_SELECTION_INVALID_REQUEST, &
         'invalid handle rejected', failures)
    call expect_true(.not. allocated(runtime_columns) .and. .not. allocated(runtime_templates), &
         'invalid handle no partial routing materialization', failures)
    call expect_all_unpublished(states, 'invalid handle no state mutation', failures)
  end subroutine test_invalid_handle_rejected_atomically

  subroutine initialize_application_batch(application_columns, application_templates, parameters, &
                                          forcings, states, config, failures)
    type(fmr_rossfast_application_column_t), allocatable, intent(out) :: application_columns(:)
    type(fmr_template_t), allocatable, intent(out) :: application_templates(:)
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

    allocate(application_columns(size(MATERIALS)), parameters(size(MATERIALS)), &
         forcings(size(MATERIALS)), states(size(MATERIALS)), application_templates(1))

    application_templates(1) = fmr_template_t()
    application_templates(1)%template_id = 7808_int64
    application_templates(1)%physics_topology_id = 80801_int64
    application_templates(1)%vertical_layout_id = 80802_int64
    application_templates(1)%state_layout_id = 80803_int64
    application_templates(1)%solver_interface_id = 80804_int64
    application_templates(1)%compatible_backend_id = 0

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
        error stop 208
      end select
      call states(i)%initialize(78000_int64 + int(i, int64), initial_state, ok, 0.0_real64)
      call expect_true(ok, trim(MATERIALS(i))//' state initialized', failures)

      application_columns(i) = fmr_rossfast_application_column_t()
      application_columns(i)%model_key = FMR_APPLICATION_MODEL_ROSSFAST_D3R
      application_columns(i)%column_id = 608_int64 - int(i, int64)
      application_columns(i)%template_id = application_templates(1)%template_id
      application_columns(i)%parameter_ref = int(i, int64)
      application_columns(i)%forcing_handle = int(i, int64)
      application_columns(i)%state_handle = int(i, int64)
      application_columns(i)%execution_class = FMR_EXECUTION_EASY
    end do
    if (allocated(initial_state)) deallocate(initial_state)

    config = canonical_numerical_config_t()
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%mass_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    call apply_rossfast_d3r_retry_policy(config)
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
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

end program test_ross08_explicit_application_model_selection

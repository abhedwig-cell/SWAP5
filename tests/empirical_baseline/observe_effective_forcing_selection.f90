program observe_effective_forcing_selection
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_boundary_conditions_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: eb_r03_probe_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_physical_column, &
       fmr_execute_serialized_resolved_physical_column
  implicit none

  real(real64), parameter :: t0 = 3100.0_real64
  real(real64), parameter :: t1 = 3100.5_real64

  type, extends(top_boundary_provider_t) :: probe_top_provider_t
  contains
    procedure :: evaluate => probe_top_evaluate
  end type probe_top_provider_t

  write(*,'(A)') 'case_id,route,forcing_handle,effective_scale,committed,admission_status,total_in,storage_change,final_revision,active_calls'
  call run_registry_case('registry_a', 1_int64, 1.0_real64)
  call run_registry_case('registry_b', 2_int64, 2.5_real64)
  call run_registry_case('registry_a_replay', 1_int64, 1.0_real64)
  call run_resolved_case('resolved_b_with_handle_a', 1_int64, 2.5_real64)
  call run_registry_case('invalid_handle', 3_int64, -1.0_real64)

contains

  subroutine configure_common(column, template, parameters, forcings, config)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters(1)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcings(2)
    type(canonical_numerical_config_t), intent(out) :: config

    template%template_id = 3101_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    column%column_id = 31001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    parameters(1)%admitted = .true.
    parameters(1)%transfer_rate = 0.2_real64
    parameters(1)%active_nodes = 0
    parameters(1)%root_extraction_active = .false.

    forcings(1)%scale = 1.0_real64
    forcings(2)%scale = 2.5_real64

    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_common

  subroutine initialize_state(state)
    type(kernel_committed_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: physical
    logical :: ok

    allocate(eb_r03_probe_state_t :: physical)
    select type (physical)
    type is (eb_r03_probe_state_t)
      physical%storage_value = 1.0_real64
    end select
    call state%initialize(31001_int64, physical, ok, t0)
    if (.not. ok) error stop 'EB-R03 committed-state initialization failed'
  end subroutine initialize_state

  subroutine run_registry_case(case_id, forcing_handle, expected_scale)
    character(len=*), intent(in) :: case_id
    integer(int64), intent(in) :: forcing_handle
    real(real64), intent(in) :: expected_scale
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t) :: forcings(2)
    type(kernel_committed_state_t) :: states(1)
    type(canonical_numerical_config_t) :: config
    type(probe_top_provider_t), target :: top
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: transaction_control
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    integer :: active_calls

    call configure_common(column, templates(1), parameters, forcings, config)
    column%forcing_handle = forcing_handle
    call initialize_state(states(1))
    call backend%initialize(top)
    output = fmr_serialized_column_result_t()
    diagnostic = fmr_column_diagnostics_t()
    runtime = fmr_serialized_batch_diagnostics_t()
    active_calls = 0

    call fmr_execute_serialized_physical_column(backend, transaction_control, column, templates, parameters, &
         forcings, states, config, t0, t1, output, diagnostic, runtime, active_calls)
    call print_row(case_id, 'registry', forcing_handle, expected_scale, output, active_calls)
  end subroutine run_registry_case

  subroutine run_resolved_case(case_id, retained_handle, explicit_scale)
    character(len=*), intent(in) :: case_id
    integer(int64), intent(in) :: retained_handle
    real(real64), intent(in) :: explicit_scale
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t) :: forcings(2)
    type(kernel_committed_state_t) :: state
    type(canonical_numerical_config_t) :: config
    type(probe_top_provider_t), target :: top
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: transaction_control
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    integer :: active_calls

    call configure_common(column, template, parameters, forcings, config)
    column%forcing_handle = retained_handle
    forcings(2)%scale = explicit_scale
    call initialize_state(state)
    call backend%initialize(top)
    output = fmr_serialized_column_result_t()
    diagnostic = fmr_column_diagnostics_t()
    runtime = fmr_serialized_batch_diagnostics_t()
    active_calls = 0

    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters(1), &
         forcings(2), state, config, t0, t1, output, diagnostic, runtime, active_calls)
    call print_row(case_id, 'resolved', retained_handle, explicit_scale, output, active_calls)
  end subroutine run_resolved_case

  subroutine print_row(case_id, route, forcing_handle, effective_scale, output, active_calls)
    character(len=*), intent(in) :: case_id, route
    integer(int64), intent(in) :: forcing_handle
    real(real64), intent(in) :: effective_scale
    type(fmr_serialized_column_result_t), intent(in) :: output
    integer, intent(in) :: active_calls

    write(*,'(A,",",A,",",I0,",",F8.4,",",L1,",",A,2(",",ES25.17E3),",",I0,",",I0)') &
      trim(case_id), trim(route), forcing_handle, effective_scale, output%committed, trim(output%admission_status), &
      output%mass%total_in, output%mass%storage_change, output%final_revision, active_calls
  end subroutine print_row

  subroutine probe_top_evaluate(self, pressure_head_top, water_content_top, requested, actual_top_flux, surface_head, runoff_flux)
    class(probe_top_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux

    if (.not. same_type_as(self, self)) error stop 'EB-R03 unreachable top provider type'
    if (.not. ieee_is_finite(pressure_head_top) .or. .not. ieee_is_finite(water_content_top)) &
         error stop 'EB-R03 nonfinite top boundary input'
    actual_top_flux = requested%top_flux
    surface_head = 0.0_real64
    runoff_flux = 0.0_real64
  end subroutine probe_top_evaluate

end program observe_effective_forcing_selection

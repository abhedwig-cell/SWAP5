module mod_fmr_fixed_weir_serialized_runtime
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_restricted_fixed_weir_surface_water, only: fixed_weir_surface_water_parameters_t, &
       fixed_weir_surface_water_forcing_t, fixed_weir_surface_water_numerical_config_t
  implicit none
  private

  integer, parameter, public :: FMR_FIXED_WEIR_CONTEXT_OK = 0
  integer, parameter, public :: FMR_FIXED_WEIR_CONTEXT_REJECTED = 1

  public :: fmr_execute_serialized_fixed_weir_resolved_column

contains

  subroutine fmr_execute_serialized_fixed_weir_resolved_column(backend, transaction_control, column, template, &
       parameters, effective_forcing, committed_state, numerical_config, surface_water_parameters, &
       surface_water_forcing, surface_water_numerical, t0, t1, output, diagnostic, runtime, &
       active_physical_calls, context_status)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_executor_t), intent(inout) :: transaction_control
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    type(fixed_weir_surface_water_parameters_t), intent(in) :: surface_water_parameters
    type(fixed_weir_surface_water_forcing_t), intent(in) :: surface_water_forcing
    type(fixed_weir_surface_water_numerical_config_t), intent(in) :: surface_water_numerical
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls
    integer, intent(out) :: context_status
    logical :: configured

    call backend%configure_fixed_weir_surface_water(surface_water_parameters, surface_water_forcing, &
         surface_water_numerical, configured)
    if (configured) then
      context_status = FMR_FIXED_WEIR_CONTEXT_OK
    else
      context_status = FMR_FIXED_WEIR_CONTEXT_REJECTED
    end if

    ! Even a rejected context uses the existing resolved executor.  With the
    ! D7 optional-state template and no active context, backend admission then
    ! fails before a physical solve while retaining the normal provenance and
    ! diagnostic path.  No second commit authority exists here.
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         effective_forcing, committed_state, numerical_config, t0, t1, output, diagnostic, runtime, &
         active_physical_calls)

    call backend%clear_fixed_weir_surface_water()
  end subroutine fmr_execute_serialized_fixed_weir_resolved_column

end module mod_fmr_fixed_weir_serialized_runtime

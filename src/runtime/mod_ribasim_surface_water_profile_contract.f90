module mod_ribasim_surface_water_profile_contract
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  implicit none
  private

  integer, parameter, public :: RIBASIM_SW_PROFILE_OK = 0
  integer, parameter, public :: RIBASIM_SW_PROFILE_OWNER_CONFLICT = 1
  integer, parameter, public :: RIBASIM_SW_PROFILE_DUPLICATE_CONTROL = 2
  integer, parameter, public :: RIBASIM_SW_PROFILE_SHAPE_MISMATCH = 3
  integer, parameter, public :: RIBASIM_SW_PROFILE_UNSUPPORTED_VARIANT = 4
  integer, parameter, public :: RIBASIM_SW_PROFILE_INVALID_ACCEPTED_HEAD = 5
  integer, parameter, public :: RIBASIM_SW_PROFILE_UNSUPPORTED_OPTIONAL_STATE_LAYOUT = 6

  real(real64), parameter, public :: RIBASIM_SW_STTAB_EPSILON_M = 1.0e-5_real64
  character(len=*), parameter, public :: RIBASIM_SW_GIT_SHA = &
       'e7fc8ade52a4bedeec10e508d2065577f33eb76a'
  character(len=*), parameter, public :: RIBASIM_SW_CORE_VERSION = '2026.1.1'
  character(len=*), parameter, public :: RIBASIM_SW_PYTHON_VERSION_AT_PIN = '2026.1.0'

  public :: ribasim_surface_water_profile_status
  public :: bind_ribasim_surface_water_controls
  public :: fmr_execute_serialized_ribasim_surface_water_resolved_column

contains

  integer function ribasim_surface_water_profile_status(optional_state_layout_id, parameters, accepted_heads_cm, &
       controls_already_supplied) result(status)
    integer(int64), intent(in) :: optional_state_layout_id
    type(fmr_drainage_response_level_parameters_t), intent(in) :: parameters(:)
    real(real64), intent(in) :: accepted_heads_cm(:)
    logical, intent(in) :: controls_already_supplied
    integer :: i

    status = RIBASIM_SW_PROFILE_SHAPE_MISMATCH

    if (optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER) then
      status = RIBASIM_SW_PROFILE_OWNER_CONFLICT
      return
    end if
    if (optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE) then
      status = RIBASIM_SW_PROFILE_UNSUPPORTED_OPTIONAL_STATE_LAYOUT
      return
    end if
    if (controls_already_supplied) then
      status = RIBASIM_SW_PROFILE_DUPLICATE_CONTROL
      return
    end if
    if (size(parameters) <= 0 .or. size(accepted_heads_cm) /= size(parameters)) return

    do i = 1, size(parameters)
      if (parameters(i)%variant /= FMR_DRAIN_VARIANT_EXTENDED_SIGNED) then
        status = RIBASIM_SW_PROFILE_UNSUPPORTED_VARIANT
        return
      end if
      if (.not. ieee_is_finite(accepted_heads_cm(i))) then
        status = RIBASIM_SW_PROFILE_INVALID_ACCEPTED_HEAD
        return
      end if
    end do

    status = RIBASIM_SW_PROFILE_OK
  end function ribasim_surface_water_profile_status

  subroutine bind_ribasim_surface_water_controls(optional_state_layout_id, parameters, accepted_heads_cm, &
       controls_already_supplied, controls, status)
    integer(int64), intent(in) :: optional_state_layout_id
    type(fmr_drainage_response_level_parameters_t), intent(in) :: parameters(:)
    real(real64), intent(in) :: accepted_heads_cm(:)
    logical, intent(in) :: controls_already_supplied
    type(fmr_drainage_response_level_control_t), allocatable, intent(out) :: controls(:)
    integer, intent(out) :: status
    integer :: i

    status = ribasim_surface_water_profile_status(optional_state_layout_id, parameters, accepted_heads_cm, &
         controls_already_supplied)
    if (status /= RIBASIM_SW_PROFILE_OK) return

    allocate(controls(size(parameters)))
    do i = 1, size(parameters)
      controls(i)%drain_head_supplied = .false.
      controls(i)%drain_head = 0.0_real64
      controls(i)%resolved_surface_water_head_supplied = .true.
      controls(i)%resolved_surface_water_head_cm = accepted_heads_cm(i)
    end do
  end subroutine bind_ribasim_surface_water_controls

  subroutine fmr_execute_serialized_ribasim_surface_water_resolved_column(backend, transaction_control, column, &
       template, parameters, effective_forcing, committed_state, numerical_config, accepted_surface_water_heads_cm, &
       t0, t1, output, diagnostic, runtime, active_physical_calls, context_status)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_executor_t), intent(inout) :: transaction_control
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: accepted_surface_water_heads_cm(:)
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls
    integer, intent(out) :: context_status

    type(fmr_b110_physical_forcing_t) :: coupled_forcing
    type(fmr_drainage_response_level_control_t), allocatable :: external_controls(:)

    context_status = RIBASIM_SW_PROFILE_SHAPE_MISMATCH
    if (.not. parameters%drainage_response_active .or. .not. allocated(parameters%drainage_response_levels)) then
      call mark_profile_rejected(column, committed_state, t0, t1, output, diagnostic, context_status)
      return
    end if

    call bind_ribasim_surface_water_controls(template%optional_state_layout_id, parameters%drainage_response_levels, &
         accepted_surface_water_heads_cm, allocated(effective_forcing%drainage_response_controls), &
         external_controls, context_status)
    if (context_status /= RIBASIM_SW_PROFILE_OK) then
      call mark_profile_rejected(column, committed_state, t0, t1, output, diagnostic, context_status)
      return
    end if

    ! Deep-copy the interval forcing so accepted external heads remain
    ! call-local forcing authority. No Ribasim level/storage is persisted in SWAP.
    coupled_forcing = effective_forcing
    coupled_forcing%drainage_response_controls = external_controls

    ! Deliberately use the ordinary serialized executor. This wrapper never
    ! configures or clears the internal fixed-weir surface-water context.
    ! A stale/conflicting internal fixed-weir context therefore remains subject
    ! to the executor's existing fail-closed template/layout admission.
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         coupled_forcing, committed_state, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls)
  end subroutine fmr_execute_serialized_ribasim_surface_water_resolved_column

  subroutine mark_profile_rejected(column, committed_state, t0, t1, output, diagnostic, context_status)
    type(fmr_logical_column_t), intent(in) :: column
    type(kernel_committed_state_t), intent(in) :: committed_state
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    integer, intent(in) :: context_status

    output = fmr_serialized_column_result_t()
    output%column_id = column%column_id
    output%requested_t0 = t0
    output%requested_t1 = t1
    output%admission_assessed = .true.
    output%admitted = .false.
    write(output%admission_status,'(A,I0)') 'RIBASIM_PROFILE_REJECTED_', context_status
    output%completed = .false.
    output%committed = .false.
    output%solver_executed = .false.
    output%initial_revision = committed_state%current_revision()
    output%final_revision = output%initial_revision

    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column%column_id
    diagnostic%rejected = 1
    diagnostic%failure_classification = 'RIBASIM_PROFILE_REJECTED'
    diagnostic%committed_revision = output%final_revision
  end subroutine mark_profile_rejected

end module mod_ribasim_surface_water_profile_contract
